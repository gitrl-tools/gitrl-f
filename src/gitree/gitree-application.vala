/*
 * This file is part of gitree
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gitree is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gitree is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gitree. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitree
{

public class Application : Gtk.Application
{
	private const ActionEntry[] s_action_entries = {
		{"about", on_about_activated},
		{"new-window", on_new_window_activated},
		{"quit", on_quit_activated},
	};

	private string[] d_arguments;
	private File? d_directory;
	private File? d_location;
	private string[] d_paths;
	private Gee.Set<string>? d_ticks;

	public Application()
	{
		Object(application_id: Config.APPLICATION_ID,
		       flags: ApplicationFlags.NON_UNIQUE);
	}

	protected override void activate()
	{
		create_window(d_location, d_ticks, d_paths, d_directory);

		base.activate();
	}

	public void create_window(File? location, Gee.Set<string>? ticks = null, string[] paths = {}, File? directory = null)
	{
		var window = new Window(this);

		if (location != null)
		{
			window.open_repository(location, ticks, paths, directory);
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
			stderr.printf("%sgit tree: error: %s\n", CommandLine.USAGE, command_line.error);
			exit_status = 2;
			return true;
		}

		if (command_line.help)
		{
			stdout.printf("%s", CommandLine.HELP);
			exit_status = 0;
			return true;
		}

		d_directory = File.new_for_path(Environment.get_current_dir());
		d_paths = command_line.paths;

		var location = discover_repository(d_directory);

		if (location == null && !command_line.is_empty)
		{
			stderr.printf("git tree: not a git repository\n");
			exit_status = 1;
			return true;
		}

		if (location != null)
		{
			try
			{
				var repository = Repository.open(location);
				var refs = Refs.read(repository);

				d_ticks = Ticks.resolve(command_line, refs, Ticks.load(Ticks.file_for(repository), refs));
			}
			catch (TicksError.NO_MATCH e)
			{
				stderr.printf("git tree: no ref matches '%s'\n", e.message);
				exit_status = 1;
				return true;
			}
			catch (Error e)
			{
				stderr.printf("git tree: %s\n", e.message);
				exit_status = 1;
				return true;
			}
		}

		d_location = location;
		d_arguments = { arguments[0] };
		arguments = d_arguments;

		return base.local_command_line(ref arguments, out exit_status);
	}

	private static void on_about_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gitree.Application;

		string[] authors = {"alexandros filotheou"};

		Gtk.show_about_dialog(app.get_active_window(),
		                      "program-name", "gitree",
		                      "version", Config.PACKAGE_VERSION,
		                      "comments", _("The history of the refs you tick"),
		                      "copyright", "Copyright \xc2\xa9 2026 alexandros filotheou",
		                      "license-type", Gtk.License.GPL_2_0,
		                      "authors", authors,
		                      null);
	}

	private static void on_new_window_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gitree.Application;
		app.create_window(null);
	}

	private static void on_quit_activated(SimpleAction action, Variant? parameter)
	{
		var app = GLib.Application.get_default() as Gitree.Application;

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
			var provider = new Gtk.CssProvider();
			provider.load_from_resource("/io/github/li9i/gitree/ui/style.css");
			Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		}

		add_action_entries(s_action_entries, this);

		set_accels_for_action("app.quit", {"<Primary>q"});
		set_accels_for_action("win.reload", {"F5"});
		set_accels_for_action("win.search", {"<Primary>f"});
	}
}

}
