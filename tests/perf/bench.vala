/*
 * This file is part of gitrl-f
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gitrl-f is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gitrl-f is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gitrl-f. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitrlf
{

public class Bench : Object
{
	private static void drain()
	{
		while (Gtk.events_pending())
		{
			Gtk.main_iteration();
		}
	}

	private static void filtered(Window window, string text, Gee.Set<string> every, string[] only, string path)
	{
		var timer = new Timer();

		window.open_repository(File.new_for_path(path), null, {}, File.new_for_path(path), text, false);

		while (!window.history.path_bar_text.has_prefix("Only") && timer.elapsed() < 600)
		{
			drain();
			Thread.usleep(1000);
		}

		stdout.printf("window open with -S %s %.3f s, %s\n", text, timer.elapsed(), window.history.summary_text);

		timer.start();
		window.history.set_ticks(every);
		drain();

		stdout.printf("window tick under the filter, every ref ticked: %.3f s\n", timer.elapsed());

		foreach (var name in only)
		{
			var ticks = new Gee.HashSet<string>();
			ticks.add(name);

			timer.start();
			window.history.set_ticks(ticks);
			drain();

			stdout.printf("window tick under the filter, only %s: %.3f s\n", name, timer.elapsed());
		}
	}

	public static int main(string[] args)
	{
		if (args.length < 2)
		{
			stderr.printf("usage: %s <repository> [<full ref name>...]\n       %s --window <repository> [--text <text>] [--search <text>] [--picks <rows>] [<full ref name>...]\n", args[0], args[0]);
			return 2;
		}

		if (args[1] == "--window")
		{
			Gtk.init(ref args);

			return window(args[2], args[3:args.length]);
		}

		try
		{
			Gitg.init();

			var timer = new Timer();
			var repository = Repository.open(Application.discover_repository(File.new_for_path(args[1])));
			var refs = Refs.read(repository);
			var history = new History(repository, refs, false);
			var mainline = History.mainline(repository, true);

			stdout.printf("commits %d, refs %d, open %.3f s\n", history.size, refs.size, timer.elapsed());
			stdout.flush();

			var every = new Ggit.OId[0];

			foreach (var reference in refs)
			{
				every += reference.target;
			}

			tick(history, mainline, "every ref ticked", every);

			for (var i = 2; i < args.length; i++)
			{
				foreach (var reference in refs)
				{
					if (reference.name == args[i])
					{
						tick(history, mainline, "only " + args[i], { reference.target });
					}
				}
			}

			timer.start();

			for (var i = 0; i < 20; i++)
			{
				Poll.snapshot(repository);
			}

			stdout.printf("poll snapshot %.2f ms\n", timer.elapsed() * 1000 / 20);
			stdout.printf("peak resident memory %.0f MiB\n", peak_memory());
		}
		catch (Error e)
		{
			stderr.printf("%s\n", e.message);
			return 1;
		}

		return 0;
	}

	private static double peak_memory()
	{
		string status;

		try
		{
			FileUtils.get_contents("/proc/self/status", out status);
		}
		catch
		{
			return 0;
		}

		foreach (var line in status.split("\n"))
		{
			if (line.has_prefix("VmHWM:"))
			{
				var kib = line.substring(6).strip().split(" ");
				return double.parse(kib[0]) / 1024;
			}
		}

		return 0;
	}

	private static void picked(Window window, int count)
	{
		var selection = window.history.paned.commit_list_view.get_selection();
		var total = new Timer();
		var slowest = 0.0;
		var slowest_row = 0;

		window.history.paned.details_visible = true;
		selection.unselect_all();
		selection.select_path(new Gtk.TreePath.from_indices(0));
		drain();
		total.start();

		for (var i = 1; i < count; i++)
		{
			var step = new Timer();

			selection.select_path(new Gtk.TreePath.from_indices(i));
			shown(window, i + 1);
			if (step.elapsed() > slowest)
			{
				slowest = step.elapsed();
				slowest_row = i;
			}
		}

		stdout.printf("picks grown one row at a time to %d: %.3f s, slowest step %.3f s at row %d\n",
		              count, total.elapsed(), slowest, slowest_row);

		selection.unselect_all();
		drain();
		window.history.diff_view.message_view.buffer.text = "";
		total.start();
		selection.select_range(new Gtk.TreePath.from_indices(0),
		                       new Gtk.TreePath.from_indices(count - 1));
		shown(window, count);

		stdout.printf("picks %d at once: %.3f s\n", count, total.elapsed());

		try
		{
			var squash = new Squash(window.repository);

			squash.open();
			total.start();
			squash.diff(window.history.picks(), null);
			stdout.printf("replay alone of %d picks: %.3f s\n", count, total.elapsed());
			squash.remove();
		}
		catch (Error e)
		{
			stderr.printf("%s\n", e.message);
		}
		stdout.printf("scratch store %s\n", store_size());
		stdout.flush();
	}

	private static void searched(Window window, string text, Gee.Set<string> every, string[] only)
	{
		var timer = new Timer();
		Gtk.CheckButton? narrow = null;

		foreach (var widget in widgets(window.history.widget))
		{
			var check = widget as Gtk.CheckButton;

			if (check != null && check.label == "Display matches only")
			{
				narrow = check;
			}
		}

		window.history.set_ticks(every);
		drain();
		window.history.search_visible = true;
		window.history.search_field.text = text;

		timer.start();
		window.history.search_field.search_changed();
		drain();

		stdout.printf("window search %s, every ref ticked: %.3f s, %s\n", text, timer.elapsed(), window.history.search_count);

		timer.start();
		narrow.active = true;
		drain();

		stdout.printf("window only matches %s: %.3f s, %d rows\n", text, timer.elapsed(), window.history.rows().length);

		narrow.active = false;
		drain();

		foreach (var name in only)
		{
			var ticks = new Gee.HashSet<string>();
			ticks.add(name);
			window.history.set_ticks(ticks);
			drain();

			timer.start();
			window.history.search_field.search_changed();
			drain();

			stdout.printf("window search %s beyond the ticks, only %s: %.3f s, %s\n", text, name, timer.elapsed(), window.history.search_count);
		}

		window.history.search_visible = false;
		drain();
	}

	private static void shown(Window window, int count)
	{
		var heading = ngettext("%d commit", "%d commits", count).printf(count) + "\n";
		var buffer = window.history.diff_view.message_view.buffer;
		var timer = new Timer();

		while (!buffer.text.has_prefix(heading) && timer.elapsed() < 600)
		{
			drain();
			Thread.usleep(1000);
		}
	}

	private static string store_size()
	{
		var mine = "%s%d-".printf(Squash.PREFIX, Posix.getpid());
		string output = "";

		try
		{
			Process.spawn_sync(Environment.get_tmp_dir(),
			                   {"sh", "-c", "du -sh " + mine + "*"}, null,
			                   SpawnFlags.SEARCH_PATH, null, out output);
		}
		catch (Error e)
		{
			return e.message;
		}

		return output.strip();
	}

	private static void tick(History history, Ggit.OId[] mainline, string label, Ggit.OId[] tips)
	{
		var timer = new Timer();
		var rows = history.tick(tips, mainline);
		var lanes = timer.elapsed();
		var model = new HistoryModel();

		model.set_rows(rows);

		stdout.printf("tick, %s: %.3f s, of which lanes %.3f s, %d rows\n", label, timer.elapsed(), lanes, rows.length);
		stdout.flush();
	}

	private static Gtk.Widget[] widgets(Gtk.Widget root)
	{
		var found = new Gtk.Widget[] { root };
		var container = root as Gtk.Container;

		if (container != null)
		{
			foreach (var child in container.get_children())
			{
				foreach (var inner in widgets(child))
				{
					found += inner;
				}
			}
		}

		return found;
	}

	private static int window(string path, string[] arguments)
	{
		var only = new string[0];
		var picks = 0;
		string? text = null;
		string? search = null;

		for (var i = 0; i < arguments.length; i++)
		{
			if (arguments[i] == "--text" && i + 1 < arguments.length)
			{
				text = arguments[++i];
			}
			else if (arguments[i] == "--search" && i + 1 < arguments.length)
			{
				search = arguments[++i];
			}
			else if (arguments[i] == "--picks" && i + 1 < arguments.length)
			{
				picks = int.parse(arguments[++i]);
			}
			else
			{
				only += arguments[i];
			}
		}

		var app = new Application();

		try
		{
			app.register();
		}
		catch (Error e)
		{
			stderr.printf("%s\n", e.message);
			return 1;
		}

		var window = new Window(app);
		window.show();
		drain();

		var timer = new Timer();
		window.open_repository(File.new_for_path(path));
		drain();

		stdout.printf("window open %.3f s\n", timer.elapsed());
		stdout.flush();

		var every = new Gee.HashSet<string>();

		try
		{
			foreach (var reference in Refs.read(window.repository))
			{
				every.add(reference.name);
			}
		}
		catch (Error e)
		{
			stderr.printf("%s\n", e.message);
			return 1;
		}

		timer.start();
		window.history.set_ticks(every);
		drain();

		stdout.printf("window tick, every ref ticked: %.3f s\n", timer.elapsed());

		foreach (var name in only)
		{
			var ticks = new Gee.HashSet<string>();
			ticks.add(name);

			timer.start();
			window.history.set_ticks(ticks);
			drain();

			stdout.printf("window tick, only %s: %.3f s\n", name, timer.elapsed());
		}

		timer.start();
		window.activate_action("reload", null);
		drain();

		stdout.printf("window reload %.3f s\n", timer.elapsed());

		if (picks > 0)
		{
			picked(window, picks);
		}

		if (search != null)
		{
			searched(window, search, every, only);
		}

		stdout.printf("peak resident memory %.0f MiB\n", peak_memory());

		if (text != null)
		{
			filtered(window, text, every, only, path);
			stdout.printf("peak resident memory after the filter %.0f MiB\n", peak_memory());
		}

		window.destroy();

		return 0;
	}
}

}
