/*
* Copyright (c) 2011-2018 Alecaddd (http://alecaddd.com)
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

namespace Sequeler {
    public Sequeler.Services.Settings settings;
    public Sequeler.Services.PasswordManager password_mngr;
    public Sequeler.Services.UpgradeManager upgrade_mngr;
    public Secret.Schema schema;
}

public class Sequeler.Application : Gtk.Application {
    public GLib.List <Window> windows;

    construct {
        application_id = Constants.PROJECT_NAME;
        flags |= ApplicationFlags.HANDLES_OPEN;

        GLib.Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, Constants.LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (Constants.GETTEXT_PACKAGE);

        schema = new Secret.Schema (Constants.PROJECT_NAME, Secret.SchemaFlags.NONE,
                                 "id", Secret.SchemaAttributeType.INTEGER,
                                 "schema", Secret.SchemaAttributeType.STRING);

        settings = new Sequeler.Services.Settings ();
        password_mngr = new Sequeler.Services.PasswordManager ();
        upgrade_mngr = new Sequeler.Services.UpgradeManager ();

        windows = new GLib.List <Window> ();
    }

    public void new_window () {
        new Sequeler.Window (this).present ();
    }

    public override void window_added (Gtk.Window window) {
        windows.append (window as Window);
        base.window_added (window);
    }

    protected override void open (File[] files, string hint) {
        foreach (var file in files) {
            var type = file.query_file_type (FileQueryInfoFlags.NONE);

            switch (type) {
                case FileType.DIRECTORY: // File handle represents a directory.
                    critical (_("Directories are not supported"));
                    continue;

                case FileType.UNKNOWN:   // File's type is unknown
                case FileType.SPECIAL:   // File is a "special" file, such as a socket, fifo, block device, or character device.
                case FileType.MOUNTABLE: // File is a mountable location.
                    critical (_("Don't know what to do"));
                    continue;

                case FileType.REGULAR:       // File handle represents a regular file.
                case FileType.SYMBOLIC_LINK: // File handle represents a symbolic link (Unix systems).
                case FileType.SHORTCUT:      // File is a shortcut (Windows systems).
                    var window = this.add_new_window ();

                    window.main.library.check_open_sqlite_file (file.get_uri (), file.get_basename ());
                    break;

                default:
                    error (_("Something completely unexpected happened"));
            }
        }
    }

    public override void window_removed (Gtk.Window window) {
        windows.remove (window as Window);
        base.window_removed (window);
    }

    private Sequeler.Window add_new_window () {
        var window = new Sequeler.Window (this);
        this.add_window (window);

        return window;
    }

    private static bool granite_color_scheme_to_gtk_dark_theme (Binding binding, Value granite_prop, ref Value gtk_prop) {
        gtk_prop.set_boolean ((Granite.Settings.ColorScheme) granite_prop == Granite.Settings.ColorScheme.DARK);
        return true;
    }

    protected override void startup () {
        base.startup ();

        // Follow OS-wide dark preference
        unowned var granite_settings = Granite.Settings.get_default ();
        unowned var gtk_settings = Gtk.Settings.get_default ();

        granite_settings.bind_property ("prefers-color-scheme", gtk_settings, "gtk-application-prefer-dark-theme",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
            // FIXME: Using the lambda expression here causes Window not being freed when it's destroyed.
            // Maybe due to this issue in vala: https://gitlab.gnome.org/GNOME/vala/-/issues/957
            (BindingTransformFunc) granite_color_scheme_to_gtk_dark_theme
        );
    }

    protected override void activate () {
        this.add_new_window ();
    }
}
