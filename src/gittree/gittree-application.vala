/*
 * This file is part of gittree
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gittree is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gittree is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gittree. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gittree
{

public class Application : Gtk.Application
{
	private const ActionEntry[] s_action_entries = {
		{"about", on_about_activated},
		{"new-window", on_new_window_activated},
		{"quit", on_quit_activated},
	};

	private File? d_directory;
	private bool d_ignore_case;
	private File? d_location;
	private string[] d_paths;
	private bool d_regex;
	private string? d_text;
	private Gee.Set<string>? d_ticks;

	public Application()
	{
		Object(application_id: Config.APPLICATION_ID,
		       flags: ApplicationFlags.NON_UNIQUE);
	}

	protected override void activate()
	{
		create_window(d_location, d_ticks, d_paths, d_directory, d_text, d_ignore_case, d_regex);

		base.activate();
	}

	public void create_window(File? location, Gee.Set<string>? ticks = null, string[] paths = {}, File? directory = null, string? text = null, bool ignore_case = false, bool regex = false)
	{
		var window = new Window(this);

		if (location != null)
		{
			window.open_repository(location, ticks, paths, directory, text, ignore_case, regex);
		}

		window.present();
	}

	public static File? discover_repository(File location)
	{
		Ggit.init();

		try
		{
			return Ggit.Repository.discover(location);
		}
		catch (Error e)
		{
			return null;
		}
	}

	protected override bool local_command_line([CCode (array_length = false, array_null_terminated = true)] ref unowned string[] arguments, out int exit_status)
	{
		var command_line = new CommandLine(arguments[1:arguments.length]);

		if (command_line.error != null)
		{
			stderr.printf("%sgittree: error: %s\n", CommandLine.USAGE, command_line.error);
			exit_status = 2;
			return true;
		}

		if (command_line.help)
		{
			stdout.printf("%s", CommandLine.HELP);
			exit_status = 0;
			return true;
		}

		if (command_line.version)
		{
			stdout.printf("gittree %s\n", Config.PACKAGE_VERSION);
			exit_status = 0;
			return true;
		}

		if (command_line.no_wd && !command_line.is_empty)
		{
			stderr.printf("%sgittree: error: --no-wd takes no ref, no path, no text, no regex and no tick option\n", CommandLine.USAGE);
			exit_status = 2;
			return true;
		}

		if (command_line.text == "")
		{
			stderr.printf("%sgittree: error: argument -S/--text: the text is empty\n", CommandLine.USAGE);
			exit_status = 2;
			return true;
		}

		if (command_line.regex == "")
		{
			stderr.printf("%sgittree: error: argument -G/--regex: the regex is empty\n", CommandLine.USAGE);
			exit_status = 2;
			return true;
		}

		var expression = new TextMatch(command_line.regex != null ? command_line.regex : "", true, false, true);

		if (expression.error != null)
		{
			stderr.printf("%sgittree: error: argument -G/--regex: bad regular expression: %s\n", CommandLine.USAGE, expression.error);
			exit_status = 2;
			return true;
		}

		if (command_line.ignore_case && command_line.text == null && command_line.regex == null)
		{
			stderr.printf("%sgittree: error: argument -i/--ignore-case: needs -S or -G\n", CommandLine.USAGE);
			exit_status = 2;
			return true;
		}

		d_directory = File.new_for_path(Environment.get_current_dir());
		d_paths = command_line.paths;
		d_regex = command_line.regex != null;
		d_text = d_regex ? command_line.regex : command_line.text;
		d_ignore_case = command_line.ignore_case;

		var location = command_line.no_wd ? null : discover_repository(d_directory);

		if (location == null && !command_line.is_empty)
		{
			stderr.printf("gittree: not a git repository\n");
			exit_status = 1;
			return true;
		}

		if (location != null)
		{
			try
			{
				var repository = Repository.open(location);
				var refs = Refs.read(repository);

				d_ticks = Ticks.resolve(command_line, refs);
			}
			catch (TicksError.NO_MATCH e)
			{
				stderr.printf("gittree: no ref matches '%s'\n", e.message);
				exit_status = 1;
				return true;
			}
			catch (Error e)
			{
				stderr.printf("gittree: %s\n", e.message);
				exit_status = 1;
				return true;
			}
		}

		d_location = location;

		try
		{
			register();
		}
		catch (Error e)
		{
			stderr.printf("gittree: %s\n", e.message);
			exit_status = 1;
			return true;
		}

		activate();
		exit_status = 0;
		return true;
	}

	private static void on_about_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gittree.Application;

		string[] authors = {"alexandros filotheou"};

		string[] artists = {
			"alexandros filotheou",
			"Git logo by Jason Long, CC BY 3.0",
		};

		Gtk.show_about_dialog(app.get_active_window(),
		                      "program-name", "gittree",
		                      "version", Config.PACKAGE_VERSION,
		                      "comments", _("The history of the refs you tick"),
		                      "copyright", "Copyright \xc2\xa9 2026 alexandros filotheou",
		                      "license-type", Gtk.License.GPL_2_0,
		                      "logo-icon-name", Config.APPLICATION_ID,
		                      "authors", authors,
		                      "artists", artists,
		                      "website", Config.PACKAGE_URL,
		                      null);
	}

	private static void on_new_window_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gittree.Application;
		app.create_window(null);
	}

	private static void on_quit_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gittree.Application;

		foreach (var window in app.get_windows())
		{
			window.close();
		}
	}

	protected override void startup()
	{
		base.startup();

		try
		{
			Gitg.init();
		}
		catch (Error e)
		{
			critical("failed to initialise: %s", e.message);
		}

		var screen = Gdk.Screen.get_default();

		if (screen != null)
		{
			var gitg_provider = Gitg.Resource.load_css("libgitg-style.css");

			if (gitg_provider != null)
			{
				Gtk.StyleContext.add_provider_for_screen(screen, gitg_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			}

			var provider = new Gtk.CssProvider();
			provider.load_from_resource("/io/github/li9i/gittree/ui/style.css");
			Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		}

		Gtk.Window.set_default_icon_name(Config.APPLICATION_ID);

		add_action_entries(s_action_entries, this);

		set_accels_for_action("app.quit", {"<Primary>q"});
		set_accels_for_action("win.reload", {"F5"});
		set_accels_for_action("win.search", {"<Primary>f"});
		set_accels_for_action("win.filter", {"<Primary><Shift>f"});
	}
}

}
