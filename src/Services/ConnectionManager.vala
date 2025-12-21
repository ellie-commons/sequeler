/*
* Copyright (c) 2011-2019 Alecaddd (http://alecaddd.com)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alessandro "Alecaddd" Castellani <castellani.ale@gmail.com>
*/

public class Sequeler.Services.ConnectionManager : Object {
    public weak Sequeler.Window window { get; construct; }
    public Gee.HashMap<string, string> data { get; construct; }
    private Object _db_type;

    public signal void ssh_tunnel_ready ();
    public signal void query_error (string error);

    public Object db_type {
        get { return _db_type; }
        set { _db_type = value; }
    }

    public Gda.Connection? connection { get; set; default = null; }
    public Gda.DataModel? output_select;

    public SSH2.Session session;
    int sock;
    int listensock;
    int forwardsock;
    bool ssh_tunnel_alive = false;

    [Flags]
    enum Auth {
        NONE,
        PASSWORD,
        PUBLICKEY
    }

    public ConnectionManager (Sequeler.Window window, Gee.HashMap<string, string> data) {
        Object (
            window: window,
            data: data
        );
    }

    construct {
        switch (data["type"]) {
            case "MySQL":
                db_type = new Sequeler.Services.Types.MySQL ();
            break;
            case "MariaDB":
                db_type = new Sequeler.Services.Types.MySQL ();
            break;
            case "PostgreSQL":
                db_type = new Sequeler.Services.Types.PostgreSQL ();
            break;
            case "SQLite":
                db_type = new Sequeler.Services.Types.SQLite ();
            break;
        }

        fetch_password ();
    }

    public void fetch_password () {
        if (data["password"] == null) {
            data["password"] = "";

            var loop = new MainLoop ();
            password_mngr.get_password_async.begin (data["id"], (obj, res) => {
                try {
                    data["password"] = password_mngr.get_password_async.end (res);
                } catch (Error e) {
                    debug ("Unable to get the password from libsecret");
                }
                loop.quit ();
            });

            loop.run ();
        }

        if (data["has_ssh"] == "true") {
            data["ssh_password"] = "";

            var ssh_loop = new MainLoop ();
            password_mngr.get_password_async.begin (data["id"] + "9999", (obj, res) => {
                try {
                    data["ssh_password"] = password_mngr.get_password_async.end (res);
                } catch (Error e) {
                    debug ("Unable to get the SSH password from libsecret");
                }
                ssh_loop.quit ();
            });

            ssh_loop.run ();
        }
    }

    public void test () throws Error {
        if (data["password"] == null) {
            fetch_password ();
        }

        var connection_string = (db_type as DataBaseType).connection_string (data);
        debug ("connection string %s", connection_string);

        try {
            connection = Gda.Connection.open_from_string (null, connection_string, null, Gda.ConnectionOptions.NONE);
        } catch (Error e) {
            throw e;
        }

        if (connection.is_opened ()) {
            connection.close ();
        }
    }

    public void open () throws Error {
        if (data["password"] == null) {
            fetch_password ();
        }

        var connection_string = (db_type as DataBaseType).connection_string (data);
        debug ("connection string %s", connection_string);

        try {
            connection = Gda.Connection.open_from_string (null, connection_string, null, Gda.ConnectionOptions.NONE);
        } catch (Error e) {
            throw e;
        }
        debug ("open ends");
    }

    public void ssh_tunnel_init (bool is_real) throws Error {
        try {
            ssh_tunnel_open (is_real);
        } catch (Error e) {
            debug (e.message);
            throw e;
        }
    }

    private void ssh_tunnel_open (bool is_real) throws Error {
        debug ("Opening tunnel %p", Thread.self<bool> ());

        ssh_tunnel_alive = true;

        Quark q = Quark.from_string ("ssh-error-str");
        var home_dir = Environment.get_home_dir ();

        // private key file
        var keyfile2 = home_dir + "/.ssh/id_rsa";
        if (data.has_key ("ssh_identity_file") && data["ssh_identity_file"] != "") {
            keyfile2 = data["ssh_identity_file"];
        }

        // public key file
        var keyfile1 = home_dir + "/.ssh/id_rsa.pub";
        if (data.has_key ("ssh_pubkey_file") && data["ssh_pubkey_file"] != "") {
            keyfile1 = data["ssh_pubkey_file"];
        }

        // SSH credentials if password authentication is required
        var username = data["ssh_username"];
        var password = data["ssh_password"];

        // SSH HOST address and Port
        var server_ip = data["ssh_host"];
        var server_port = data["ssh_port"] != "" ? (uint16) int.parse (data["ssh_port"]) : 22;

        // The IP address where the DB is available on your SSH
        var local_listenip = "127.0.0.1";

        // The Port used by the DB on your SSH host
        uint16 local_listenport = 9000;

        // Default vars for TCPIP Tunnelling
        var remote_desthost = data["host"] != "" ? data["host"] : "127.0.0.1";
        var remote_destport = data["port"] != "" ? int.parse (data["port"]) : 3306;

        var rc = SSH2.init (0);
        if (rc != SSH2.Error.NONE) {
            debug ("libssh2 initialization failed (%d)", rc);
            throw new Error.literal (q, 1, _("Libssh2 initialization failed (%d)").printf (rc));
        }

        debug ("Socket params: %s %d", server_ip, server_port);

        /* Connect to SSH server */
        sock = Posix.socket (Posix.AF_INET, Posix.SOCK_STREAM, Posix.IPProto.TCP);
        if (sock == -1) {
            debug ("Failed to open socket");
            throw new Error.literal (q, 1, _("Failed to open socket"));
        }

        Posix.SockAddrIn sin = Posix.SockAddrIn ();
        sin.sin_family = Posix.AF_INET;
        sin.sin_addr.s_addr = Posix.inet_addr (server_ip);
        sin.sin_port = Posix.htons (server_port);
        if (Posix.connect (sock, &sin, sizeof (Posix.SockAddrIn)) != 0) {
            debug ("Failed to connect!");
            throw new Error.literal (q, 1, _("Failed to connect!"));
        }

        /* Create a session instance */
        session = SSH2.Session.create<bool> ();

        /* …start it up. This will trade welcome banners, exchange keys,
        * and setup crypto, compression, and MAC layers
        */
        rc = session.handshake (sock);
        if (rc != SSH2.Error.NONE) {
            debug ("Error when starting up SSH session: %d", rc);
            throw new Error.literal (q, 1, _("Error when starting up SSH session: %d").printf (rc));
        }

        /* check what authentication methods are available */
        int auth_pw = 0;
        var userauthlist = session.list_authentication (username.data);
        debug ("Authentication methods: %s", userauthlist);
        if ("password" in userauthlist) {
            auth_pw |= Auth.PASSWORD;
        }

        if ("publickey" in userauthlist) {
            auth_pw |= Auth.PUBLICKEY;
        }

        if ((auth_pw & Auth.PASSWORD) != 0) {
            if (session.auth_password (username, password) != SSH2.Error.NONE) {
                debug ("Authentication by password failed.");
                ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                throw new Error.literal (q, 1, _("Authentication by password failed!"));
            }
        } else if ((auth_pw & Auth.PUBLICKEY) != 0) {
            if (session.auth_publickey_from_file (username,
                                                keyfile1,
                                                keyfile2,
                                                password
                                            ) != SSH2.Error.NONE) {
                debug ("Authentication by public key failed!");
                ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                throw new Error.literal (q, 1, _("Authentication by public key failed!"));
            }

            debug ("Authentication by public key succeeded.");
        } else {
            debug ("No supported authentication methods found!");
            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
            throw new Error.literal (q, 1, _("No supported authentication methods found!"));
        }

        listensock = Posix.socket (Posix.AF_INET, Posix.SOCK_STREAM, Posix.IPProto.TCP);
        if (listensock == -1) {
            debug ("failed to open listen socket");
            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
            throw new Error.literal (q, 1, _("Failed to open listen socket"));
        }

        debug ("listensock %d", listensock);

        sin = Posix.SockAddrIn ();
        sin.sin_family = Posix.AF_INET;
        sin.sin_addr.s_addr = Posix.inet_addr (local_listenip);
        sin.sin_port = Posix.htons (local_listenport);

        var sockopt = 1;
        Posix.setsockopt (listensock, Linux.Socket.SOL_SOCKET, Linux.Socket.SO_REUSEADDR, &sockopt, (Posix.socklen_t) sizeof (int));
        if (Posix.bind (listensock, &sin, sizeof (Posix.SockAddrIn)) == -1) {
            debug ("Failed to bind!");
            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
            throw new Error.literal (q, 1, _("Failed to bind. Your Database Port may be wrong!"));
        }

        if (Posix.listen (listensock, 2) == -1) {
            debug ("Failed to listen!");
            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
            throw new Error.literal (q, 1, _("Failed to listen!"));
        }

        debug ("Waiting for TCP connection on %s:%d…", local_listenip, local_listenport);

        bool signal_launched = false;
        while (ssh_tunnel_alive) {

            if (!signal_launched) {
                signal_launched = true;
                ssh_tunnel_ready ();
            } else {
                if (!is_real) {
                    ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                    return;
                }
            }

            debug ("Waiting for remote connection %p", Thread.self<bool> ());

            forwardsock = Posix.accept (listensock, null, null);

            debug ("forwardsock %d", forwardsock);

            if (forwardsock == -1) {
                debug ("Failed to accept!");
                ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                throw new Error.literal (q, 1, _("Failed to accept remote connection!"));
            }

            debug ("Forwarding connection from %s:%d here to remote %s:%d", local_listenip, local_listenport, remote_desthost, remote_destport);

            var channel = session.direct_tcpip (remote_desthost, remote_destport, local_listenip, local_listenport);
            if (channel == null) {
                debug ("Could not open the direct-tcpip channel! (Note that this can be a problem at the server! Please review the server logs.)");
                ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                throw new Error.literal (q, 1, _("Could not open the direct-tcpip channel! (Note that this can be a problem at the server! Please review the server logs.)"));
            }

            session.blocking = false;

            uint8[] buf = new uint8[16384];
            while (ssh_tunnel_alive) {
                Posix.fd_set fds;
                Posix.FD_ZERO (out fds);
                Posix.FD_SET (forwardsock, ref fds);
                Posix.timeval tv = {0, 100000};
                var res = Posix.select (forwardsock + 1, &fds, null, null, tv);

                if (-1 == res) {
                    debug ("Error on select!");
                    if (is_real) {
                        ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                    }
                    //  direct_shutdown ();
                    break;
                }

                if (res > 0 && Posix.FD_ISSET (forwardsock, fds) > 0) {
                    var len = Posix.recv (forwardsock, buf, 16384, 0);
                    if (len < 0) {
                        debug ("Error reading from the forwardsock!");
                        ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                        break;
                    } else if (0 == len) {
                        debug ("The client at %s:%d disconnected!", local_listenip, local_listenport);
                        debug ("connection manager %p", this);
                        if (is_real) {
                            direct_shutdown ();
                        }
                        break;
                    }
                    ssize_t wr = 0;
                    ssize_t i = 0;
                    do {
                        i = channel.write (buf[wr:len]);
                        if (i < 0) {
                            debug ("Error writing on the SSH channel: %s", i.to_string ());
                            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                            //  direct_shutdown ();
                            break;
                        }
                        wr += i;
                    } while (i > 0 && wr < len);
                }

                while (ssh_tunnel_alive) {
                    ssize_t len = channel.read (buf);
                    if (SSH2.Error.AGAIN == len)
                        break;
                    else if (len < 0) {
                        debug ("Error reading from the SSH channel: %d", (int) len);
                        ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                        //  direct_shutdown ();
                        break;
                    }
                    ssize_t wr = 0;
                    while (wr < len) {
                        ssize_t i = Posix.send (forwardsock, buf[wr:buf.length], len - wr, 0);
                        if (i <= 0) {
                            debug ("Error writing on the forwardsock!");
                            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                            //  direct_shutdown ();
                            break;
                        }
                        wr += i;
                    }
                    if (channel.eof () != SSH2.Error.NONE) {
                        debug ("The remote client at %s:%d disconnected!", remote_desthost, remote_destport);
                        if (is_real) {
                            ssh_tunnel_close (Log.FILE + ":" + Log.LINE.to_string ());
                            //  direct_shutdown ();
                        }
                        break;
                    }
                }
            }
        }
    }

    public void ssh_tunnel_close (string from = "Unknown") {
        debug ("closing ssh tunnel from: %s %p", from, Thread.self<bool> ());
        ssh_tunnel_alive = false;

        //  debug ("closing listensock: %d", listensock);
        Posix.close (listensock);
        listensock = -1;
        //  debug ("listensock closed: %d", listensock);
        //  debug ("closing forwardsock: %d", forwardsock);
        Posix.close (forwardsock);
        forwardsock = -1;
        //  debug ("forwardsock closed: %d", forwardsock);

        if (session != null) {
            session.disconnect ("Client disconnecting normally");
            session.blocking = false;
            session = null;
        }

        Posix.close (sock);
        sock = -1;
        SSH2.exit ();
    }

    private void direct_shutdown () {
        session.blocking = true;
        Posix.close (forwardsock);
        forwardsock = -1;
    }

    public async int run_query (string query) throws Error requires (connection.is_opened ()) {
        return connection.execute_non_select_command (query);
    }

    public async string run_silent_statement (Gda.Statement statement, Gda.Set? params) throws Error requires (connection.is_opened ()) {
        var result = connection.statement_execute_non_select (statement, params, null);
        return result.to_string ();
    }
    public Gda.DataModel? run_silent_select_statement (Gda.Statement statement, Gda.Set? params) throws Error requires (connection.is_opened ()) {
        return connection.statement_execute_select (statement, params);
    }

    public Gda.DataModel? run_select (string query) throws Error {
        return connection.execute_select_command (query);
    }

    public async Gee.HashMap<string, string> init_connection () throws ThreadError {
        var output = new Gee.HashMap<string, string> ();
        output["status"] = "false";
        bool result = true;
        string msg = "";

        SourceFunc callback = init_connection.callback;
        new Thread<void*> (null, () => {
            try {
                debug ("pass init connection");
                open ();
            } catch (Error e) {
                result = false;
                msg = e.message;
            }

            Idle.add ((owned) callback);
            Thread.exit (null);

            return null;
        });

        yield;

        output["msg"] = msg;
        output["status"] = result.to_string ();

        return output;
    }

    public Gda.Statement parse_sql_string (string sql, out Gda.Set @params) throws Error {
        return connection.parse_sql_string (sql, out params);
    }

    public async Gda.DataModel? init_select_query (string query) {
        Gda.DataModel? result = null;
        var error = "";

        SourceFunc callback = init_select_query.callback;
        new Thread <void*> (null, () => {
            try {
                result = run_select (query);
            } catch (Error e) {
                error = e.message;
                result = null;
            }
            Idle.add ((owned) callback);
            Thread.exit (null);

            return null;
        });

        yield;

        if (error != "") {
            query_warning (error);
            return null;
        }

        return result;
    }

    public async Gee.HashMap<Gda.DataModel?, string> init_silent_select_statement (Gda.Statement statement, Gda.Set? params) {
        var result = new Gee.HashMap<Gda.DataModel?, string> ();
        Gda.DataModel? data = null;
        var error = "";

        SourceFunc callback = init_silent_select_statement.callback;
        new Thread <void*> (null, () => {
            try {
                data = run_silent_select_statement (statement, params);
            } catch (Error e) {
                error = e.message;
                data = null;
            }
            Idle.add ((owned) callback);
            Thread.exit (null);

            return null;
        });

        yield;

        result.@set (data, error);
        return result;
    }

    public async int? init_query (string query) {
        int result = 0;
        var error = "";

        try {
            result = yield run_query (query);
        } catch (Error e) {
            error = e.message;
        }

        if (error != "") {
            query_warning (error);
            return null;
        }

        return result;
    }

    public async Gee.HashMap<string?, string> init_silent_statement (Gda.Statement statement, Gda.Set? params) {
        var result = new Gee.HashMap<string?, string> ();
        string? data = null;
        var error = "";

        try {
            data = yield run_silent_statement (statement, params);
        } catch (Error e) {
            error = e.message;
        }

        if (error != "") {
            data = null;
        }

        result.@set (data, error);
        return result;
    }

    public void query_warning (string message) {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Error!"), message, "dialog-error", Gtk.ButtonsType.NONE);
        message_dialog.transient_for = window;

        var suggested_button = new Gtk.Button.with_label ("Close");
        message_dialog.add_action_widget (suggested_button, Gtk.ResponseType.ACCEPT);

        message_dialog.show_all ();
        if (message_dialog.run () == Gtk.ResponseType.ACCEPT) {}

        message_dialog.destroy ();
    }
}
