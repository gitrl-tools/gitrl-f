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
	private const int FIND_STEPS = 5;

	private const ulong SETTLE_WAIT = 2000;

	private static void changes(Gitg.Repository repository) throws Error
	{
		var context = new Ggit.DiffOptions().n_context_lines;
		var timer = new Timer();
		var staged = Changes.staged(repository, context);
		var unstaged = Changes.unstaged(repository, context);
		var read = timer.elapsed();

		timer.start();
		Changes.key(repository, staged);
		Changes.key(repository, unstaged);
		var keys = timer.elapsed();

		timer.start();
		var staged_lines = Changes.lines(staged);
		var unstaged_lines = Changes.lines(unstaged);

		stdout.printf("uncommitted changes: read %.3f s, keys %.3f s, line counts %.3f s, staged %u files %s, unstaged %u files %s\n",
		              read, keys, timer.elapsed(), (uint)staged.get_num_deltas(),
		              staged_lines, (uint)unstaged.get_num_deltas(), unstaged_lines);
	}

	private static void detailed(Window window, string commit, string? word, int limit)
	{
		var history = window.history;
		var diff = history.diff_view;
		var id = new Ggit.OId.from_string(commit);
		var rows = history.rows();
		var row = 0;

		while (row < rows.length && !rows[row].get_id().equal(id))
		{
			row++;
		}

		if (row == rows.length)
		{
			stderr.printf("%s is not in the list\n", commit);
			return;
		}

		var path = new Gtk.TreePath.from_indices(row);
		var view = history.paned.commit_list_view;
		var added = 0;

		foreach (var widget in widgets(diff))
		{
			if (widget is Gtk.Grid && ((Gtk.Buildable)widget).get_name() == "grid_files")
			{
				((Gtk.Grid)widget).add.connect_after(() => added++);
			}
		}

		history.paned.details_visible = false;
		view.get_selection().unselect_all();
		view.get_selection().select_path(path);
		view.scroll_to_cell(path, null, false, 0, 0);
		settle();

		var timer = new Timer();
		var first = -1.0;
		var handler = diff.files_changed.connect(() => {
			first = first < 0 ? timer.elapsed() : first;
		});

		history.paned.details_visible = true;

		while (diff.diff == null || added < int.min(limit, (int)diff.diff.get_num_deltas()))
		{
			if (Gtk.events_pending())
			{
				Gtk.main_iteration();
			}
			else
			{
				Thread.usleep(1000);
			}
		}

		diff.disconnect(handler);

		if (added < diff.diff.get_num_deltas())
		{
			stdout.printf("diff of %s, %d of %d files: first files %.3f s, %d files %.3f s\n",
			              commit, added, (int)diff.diff.get_num_deltas(), first, added, timer.elapsed());
			return;
		}

		settle();

		stdout.printf("diff of %s, %d files: first files %.3f s, every file %.3f s\n",
		              commit, added, first, timer.elapsed());
		stdout.flush();

		if (word == null)
		{
			return;
		}

		var field = history.find_bar.field;

		timer.start();
		window.activate_action("search", null);
		settle();

		stdout.printf("find bar opened: %.3f s\n", timer.elapsed());

		field.text = word;
		settle();

		timer.start();
		field.activate();
		settle();

		stdout.printf("find %s, Enter: %.3f s, %s\n", word, timer.elapsed(), history.find_bar.count);

		for (var i = 0; i < FIND_STEPS; i++)
		{
			timer.start();
			field.activate();
			settle();

			stdout.printf("find %s, Enter to the next match: %.3f s, %s\n", word, timer.elapsed(), history.find_bar.count);
		}

		stdout.flush();
	}

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

	private static void grouped(Window window, string[] keys)
	{
		var timer = new Timer();

		foreach (var key in keys)
		{
			Gtk.CheckButton? box = null;

			foreach (var child in window.history.paned.refs_list.get_children())
			{
				var header = child as RefsHeader;

				if (header == null || header.key != key)
				{
					continue;
				}

				foreach (var widget in widgets(header))
				{
					if (box == null && widget is Gtk.CheckButton)
					{
						box = (Gtk.CheckButton)widget;
					}
				}
			}

			for (var i = 0; i < 2; i++)
			{
				var before = window.history.ticks.size;

				timer.start();
				box.clicked();
				drain();

				var after = window.history.ticks.size;

				stdout.printf("window group box %s, %s %d refs: %.3f s\n", key,
				              after > before ? "ticks" : "unticks",
				              (after - before).abs(), timer.elapsed());
			}
		}
	}

	public static int main(string[] args)
	{
		if (args.length < 2)
		{
			stderr.printf("usage: %s <repository> [<full ref name>...]\n       %s --window <repository> [--text <text>] [--search <text>] [--picks <rows>] [--group <key>] [--diff <commit> [--find <text>] [--rows <files>]] [<full ref name>...]\n", args[0], args[0]);
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
			changes(repository);
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

	private static void settle()
	{
		do
		{
			drain();
			Thread.usleep(SETTLE_WAIT);
		}
		while (Gtk.events_pending());
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
		string output = "";

		try
		{
			Process.spawn_sync(Squash.folder().get_path(), {"du", "-sh", "."},
			                   null, SpawnFlags.SEARCH_PATH, null, out output);
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
		var groups = new string[0];
		var only = new string[0];
		var picks = 0;
		string? text = null;
		string? search = null;
		string? commit = null;
		string? word = null;
		var rows = int.MAX;

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
			else if (arguments[i] == "--group" && i + 1 < arguments.length)
			{
				groups += arguments[++i];
			}
			else if (arguments[i] == "--diff" && i + 1 < arguments.length)
			{
				commit = arguments[++i];
			}
			else if (arguments[i] == "--find" && i + 1 < arguments.length)
			{
				word = arguments[++i];
			}
			else if (arguments[i] == "--rows" && i + 1 < arguments.length)
			{
				rows = int.parse(arguments[++i]);
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

		grouped(window, groups);

		timer.start();
		window.activate_action("reload", null);
		drain();

		stdout.printf("window reload %.3f s\n", timer.elapsed());

		if (commit != null)
		{
			detailed(window, commit, word, rows);
		}

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
