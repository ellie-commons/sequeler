/*
* Copyright (c) 2017-2020 Alecaddd (https://alecaddd.com)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alessandro "Alecaddd" Castellani <castellani.ale@gmail.com>
*/

public class Sequeler.Services.Settings : GLib.Settings {
        public int pos_x {
        get { return get_int ("pos-x"); }
        set { set_int ("pos-x", value); }
    }
    public int pos_y {
        get { return get_int ("pos-y"); }
        set { set_int ("pos-y", value); }
    }
    public int window_width {
        get { return get_int ("window-width"); }
        set { set_int ("window-width", value); }
    }
    public int window_height {
        get { return get_int ("window-height"); }
        set { set_int ("window-height", value); }
    }
    public int sidebar_width {
        get { return get_int ("sidebar-width"); }
        set { set_int ("sidebar-width", value); }
    }
    public string[] saved_connections {
        owned get { return get_strv ("saved-connections"); }
        set { set_strv ("saved-connections", value); }
    }
    public int tot_connections {
        get { return get_int ("tot-connections"); }
        set { set_int ("tot-connections", value); }
    }
    public int limit_results {
        get { return get_int ("limit-results"); }
        set { set_int ("limit-results", value); }
    }
    public bool save_quick {
        get { return get_boolean ("save-quick"); }
        set { set_boolean ("save-quick", value); }
    }
    public string version {
        owned get { return get_string ("version"); }
        set { set_string ("version", value); }
    }
    public bool use_system_font {
        get { return get_boolean ("use-system-font"); }
        set { set_boolean ("use-system-font", value); }
    }
    public string font {
        owned get { return get_string ("font"); }
        set { set_string ("font", value); }
    }
    public string style_scheme {
        owned get { return get_string ("style-scheme"); }
        set { set_string ("style-scheme", value); }
    }
    public int query_area {
        get { return get_int ("query-area"); }
        set { set_int ("query-area", value); }
    }

    public Settings () {
        Object (schema_id: Constants.PROJECT_NAME);
    }

    public void add_connection (Gee.HashMap<string, string> data) {
        if (data["type"] != "SQLite") {
            update_password.begin (data);
            data.unset ("password");
            data.unset ("ssh_password");
        }

        var conns = get_strv ("saved-connections");
        conns += stringify_data (data);
        set_strv ("saved-connections", conns);
        tot_connections = tot_connections + 1;
    }

    public async void duplicate_connection (Gee.HashMap<string, string> data) {
        data["id"] = tot_connections.to_string ();
        data["title"] = _("%s (copy)").printf (data["title"]);
        add_connection (data);
    }

    public void edit_connection (Gee.HashMap<string, string> new_data, string old_data) {
        var position = 0;
        Gee.List<string> existing_connections = new Gee.ArrayList<string> ();
        existing_connections.add_all_array (saved_connections);

        if (existing_connections.contains (old_data)) {
            position = existing_connections.index_of (old_data);
            existing_connections.remove (old_data);
        }

        if (new_data["type"] != "SQLite") {
            update_password.begin (new_data);
            new_data.unset ("password");

            if (new_data["has_ssh"] == "true" && new_data["ssh_password"] != null) {
                update_ssh_password.begin (new_data);
                new_data.unset ("ssh_password");
            }
        }

        existing_connections.insert (position, stringify_data (new_data));

        string[] new_conns = {};
        foreach (var conn in existing_connections.to_array ()) {
            new_conns += conn;
        }

        set_strv ("saved-connections", new_conns);
    }

    public void delete_connection (Gee.HashMap<string, string> data) {
        string[] new_conns = {};
        var conns = get_strv ("saved-connections");

        if (data["type"] != "SQLite") {
            delete_password.begin (data);
        }

        foreach (var conn in conns) {
            var check = arraify_data (conn);
            if (check["id"] == data["id"]) {
                continue;
            }
            new_conns += conn;
        }

        set_strv ("saved-connections", new_conns);
    }

    public void clear_connections () {
        string[] empty = {};
        set_strv ("saved-connections", empty);
        tot_connections = 0;

        delete_all_passwords.begin ();
    }

    public void reorder_connection (Gee.HashMap<string, string> source, int position) {
        Gee.ArrayList<string> existing_connections = new Gee.ArrayList<string> ();
        existing_connections.add_all_array (saved_connections);

        foreach (var conn in saved_connections) {
            var check = arraify_data (conn);
            if (check["id"] == source["id"]) {
                existing_connections.remove (conn);
            }
        }

        existing_connections.insert (position, stringify_data (source));

        string[] new_conns = {};
        foreach (var conn in existing_connections.to_array ()) {
            new_conns += conn;
        }

        set_strv ("saved-connections", new_conns);
    }

    public string stringify_data (Gee.HashMap<string, string> data) {
        string result = "";

        foreach (var entry in data.entries) {
            string values = "%s=%s\n".printf (entry.key, entry.value);
            result = result + values;
        }

        return result;
    }

    public Gee.HashMap<string, string> arraify_data (string connection) {
        var array = new Gee.HashMap<string, string> ();
        var data = connection.split ("\n");

        foreach (var d in data) {
            var d2 = d.split ("=", 2);

            if (d2[0] == null) {
                continue;
            }

            array.set (d2[0], d2[1]);
        }

        return array;
    }

    public async void update_password (Gee.HashMap<string, string> data) throws Error {
        yield password_mngr.store_password_async (data["id"], data["password"]);
    }

    public async void update_ssh_password (Gee.HashMap<string, string> data) throws Error {
        yield password_mngr.store_password_async (data["id"] + "9999", data["ssh_password"]);
    }

    public async void delete_password (Gee.HashMap<string, string> data) throws Error {
        yield password_mngr.clear_password_async (data["id"]);

        if (data["has_ssh"] == "true" && data["ssh_password"] != null) {
            yield password_mngr.clear_password_async (data["id"] + "9999");
        }
    }

    public async void delete_all_passwords () throws Error {
        yield password_mngr.clear_all_passwords_async ();
    }
}
