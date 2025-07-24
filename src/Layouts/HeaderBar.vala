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

public class Sequeler.Layouts.HeaderBar : Gtk.HeaderBar {
    public weak Sequeler.Window window { get; construct; }

    private Gtk.Button logout_button;
    private Gtk.Button new_db_button;
    private Gtk.Button delete_db_button;
    private Gtk.Button edit_db_button;
    private Gtk.Popover menu_popover;

    public bool logged_out { get; set; }

    public HeaderBar (Sequeler.Window main_window) {
        Object (
            window: main_window,
            logged_out: true
        );

        set_title (APP_NAME);
        set_show_close_button (true);

        build_ui ();
        toggle_logout.begin ();
    }

    private void build_ui () {
        logout_button = header_button ("application-logout");
        logout_button.action_name =
            Sequeler.Services.ActionManager.ACTION_PREFIX
            + Sequeler.Services.ActionManager.ACTION_LOGOUT;
        logout_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Control>Escape"}, _("Logout"));

        new_db_button = header_button ("office-database-new");
        new_db_button.tooltip_markup = Granite.markup_accel_tooltip (
            {"<Control><Shift>N"},
            _("Create a new database")
        );
        new_db_button.action_name =
            Sequeler.Services.ActionManager.ACTION_PREFIX
            + Sequeler.Services.ActionManager.ACTION_NEW_DB;

        delete_db_button = header_button ("office-database-remove");
        delete_db_button.tooltip_markup = Granite.markup_accel_tooltip (
            {"<Control><Shift>D"},
            _("Delete database")
        );
        delete_db_button.action_name =
            Sequeler.Services.ActionManager.ACTION_PREFIX
            + Sequeler.Services.ActionManager.ACTION_DELETE_DB;

        edit_db_button = header_button ("office-database-edit");
        edit_db_button.tooltip_markup = Granite.markup_accel_tooltip (
            {"<Control><Shift>P"},
            _("Database properties")
        );
        edit_db_button.action_name =
            Sequeler.Services.ActionManager.ACTION_PREFIX
            + Sequeler.Services.ActionManager.ACTION_EDIT_DB;

        new_db_button.visible = false;
        new_db_button.no_show_all = true;
        edit_db_button.visible = false;
        edit_db_button.no_show_all = true;
        delete_db_button.visible = false;
        delete_db_button.no_show_all = true;

        var new_window_item = new_menuitem (_("New Window"), "<Control>n");
        new_window_item.action_name = Sequeler.Services.ActionManager.ACTION_PREFIX + Sequeler.Services.ActionManager.ACTION_NEW_WINDOW;

        var new_connection_item = new_menuitem (_("New Connection"), "<Control><Shift>n");
        new_connection_item.action_name = Sequeler.Services.ActionManager.ACTION_PREFIX + Sequeler.Services.ActionManager.ACTION_NEW_CONNECTION;

        var quit_item = new_menuitem (_("Quit"), "<Control>q");
        quit_item.action_name = Sequeler.Services.ActionManager.ACTION_PREFIX + Sequeler.Services.ActionManager.ACTION_QUIT;

        var menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        menu_separator.margin_top = 6;
        menu_separator.margin_bottom = 6;

        var menu_grid = new Gtk.Grid ();
        menu_grid.expand = true;
        menu_grid.margin_top = menu_grid.margin_bottom = 6;
        menu_grid.orientation = Gtk.Orientation.VERTICAL;

        menu_grid.attach (new_window_item, 0, 1, 1, 1);
        menu_grid.attach (new_connection_item, 0, 2, 1, 1);
        menu_grid.attach (menu_separator, 0, 3, 1, 1);
        menu_grid.attach (quit_item, 0, 4, 1, 1);
        menu_grid.show_all ();

        var open_menu = new Gtk.MenuButton ();
        open_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
        open_menu.tooltip_text = _("Menu");

        menu_popover = new Gtk.Popover (open_menu);
        menu_popover.add (menu_grid);

        open_menu.popover = menu_popover;
        open_menu.valign = Gtk.Align.CENTER;

        pack_start (logout_button);
        pack_start (headerbar_separator ());
        pack_start (new_db_button);
        pack_start (edit_db_button);
        pack_start (headerbar_separator ());
        pack_start (delete_db_button);

        pack_end (open_menu);
    }

    private Gtk.ModelButton new_menuitem (string label, string accels) {
        var button = new Gtk.ModelButton ();
        button.get_child ().destroy ();
        button.add (new Granite.AccelLabel (label, accels));

        return button;
    }

    private Gtk.Button header_button (string image) {
        var button = new Gtk.Button.from_icon_name (image, Gtk.IconSize.LARGE_TOOLBAR);
        button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        button.valign = Gtk.Align.CENTER;
        button.can_focus = false;

        return button;
    }

    private Gtk.Separator headerbar_separator () {
        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
        separator.get_style_context ().add_class ("headerbar-separator");

        return separator;
    }

    public async void toggle_logout () {
        logged_out = !logged_out;

        logout_button.visible = logged_out;
        logout_button.no_show_all = !logged_out;

        if (
            window.data_manager != null &&
            (
                window.data_manager.data["type"] == "MySQL"
                || window.data_manager.data["type"] == "MariaDB"
            )
        ) {
            new_db_button.visible = logged_out;
            new_db_button.no_show_all = !logged_out;
            edit_db_button.visible = logged_out;
            edit_db_button.no_show_all = !logged_out;
            delete_db_button.visible = logged_out;
            delete_db_button.no_show_all = !logged_out;
        }
    }
}
