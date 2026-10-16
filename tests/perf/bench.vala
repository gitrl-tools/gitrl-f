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
	private const uint PROBE = 10;
	private const double QUIET = 1.0;

	private const ulong SETTLE_WAIT = 2000;

	private static double[] s_frames;
	private static double s_painted;

	private delegate bool Done();

	private static Gtk.Menu? attached(Gtk.Widget widget)
	{
		foreach (var menu in Gtk.Menu.get_for_attach_widget(widget))
		{
			return (Gtk.Menu)menu;
		}

		return null;
	}

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

	private static double click(Gdk.Window target, double x, double y)
	{
		var timer = new Timer();
		var time = (uint32)(get_monotonic_time() / 1000);
		var pointer = target.get_display().get_default_seat().get_pointer();
		var longest = 0.0;
		int root_x;
		int root_y;

		target.get_root_coords((int)x, (int)y, out root_x, out root_y);

		foreach (var type in new Gdk.EventType[] { Gdk.EventType.BUTTON_PRESS, Gdk.EventType.BUTTON_RELEASE })
		{
			var event = new Gdk.Event(type);

			target.ref();
			event.button.window = target;
			event.button.button = Gdk.BUTTON_SECONDARY;
			event.button.time = time;
			event.button.x = x;
			event.button.y = y;
			event.button.x_root = root_x;
			event.button.y_root = root_y;
			event.set_device(pointer);
			event.set_source_device(pointer);

			timer.start();
			Gtk.main_do_event(event);
			longest = double.max(longest, timer.elapsed());
		}

		return longest;
	}

	private static double[] cpu_times()
	{
		string stat;

		try
		{
			FileUtils.get_contents("/proc/self/stat", out stat);
		}
		catch
		{
			return { 0, 0 };
		}

		var fields = stat.substring(stat.last_index_of(")") + 2).split(" ");
		var tick = (double)Posix.sysconf(Posix._SC_CLK_TCK);

		return { (double.parse(fields[11]) + double.parse(fields[12])) / tick,
		         (double.parse(fields[13]) + double.parse(fields[14])) / tick };
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

	private static Gitg.DiffViewFile? diff_file(Window window, Ggit.OId id, string path)
	{
		var shown = window.history.diff_view.commit;

		if (shown == null || !shown.get_id().equal(id))
		{
			return null;
		}

		foreach (var file in window.history.diff_view.get_files())
		{
			if (file.info != null && file.info.delta.get_new_file().get_path() == path)
			{
				return file;
			}
		}

		return null;
	}

	private static void drain()
	{
		while (Gtk.events_pending())
		{
			Gtk.main_iteration();
		}
	}

	private static void entered(Window window, SearchChoice choice, string text, bool regex, Gee.Set<string> every, string[] only)
	{
		var history = window.history;
		var kind = choice == SearchChoice.FILES ? "Files" : (regex ? "Changed lines, regex," : "Changed lines");
		var sets = new Gee.ArrayList<Gee.Set<string>>();

		sets.add(every);

		foreach (var name in only)
		{
			var ticks = new Gee.HashSet<string>();
			ticks.add(name);
			sets.add(ticks);
		}

		foreach (var ticks in sets)
		{
			var timer = new Timer();

			history.set_ticks(ticks);
			history.search_visible = true;
			history.search_choice = choice;
			drain();

			foreach (var widget in widgets(history.widget))
			{
				var toggle = widget as Gtk.ToggleButton;

				if (toggle != null && toggle.label == "Regex")
				{
					toggle.active = regex;
				}
			}

			history.search_field.text = text;
			drain();

			timer.start();
			history.search_field.activate();

			while ((history.path_bar_text.has_prefix("Searching") || history.path_bar_text.has_prefix("Reading")) && timer.elapsed() < 600)
			{
				drain();
				Thread.usleep(1000);
			}

			drain();

			stdout.printf("window enter in %s %s, %s: %.3f s, %s, %s\n", kind, text, ticks == every ? "every ref ticked" : "only " + ticks.to_array()[0], timer.elapsed(), history.summary_text, history.search_count);
			stdout.flush();

			history.search_visible = false;
			drain();
		}
	}

	private static void expanded(Window window)
	{
		foreach (var widget in widgets(window.history.paned.refs_list))
		{
			var header = widget as RefsHeader;

			if (header == null || header.parent_group != null)
			{
				continue;
			}

			var open = header.expanded;

			for (var i = 0; i < 2; i++)
			{
				quiet();

				var main = thread_seconds();
				var count = s_frames.length;
				var timer = new Timer();

				header.expanded = !header.expanded;

				var wait = frame(count, timer);
				var last = quiet();

				stdout.printf("refs panel %s %s: painted after %.1f ms, main thread %.1f ms, last frame %.1f ms after\n",
				              header.expanded ? "expand" : "fold", header.title,
				              wait * 1000, (s_painted - main) * 1000, last * 1000);
			}

			header.expanded = open;
			quiet();
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

	private static double frame(int count, Timer timer)
	{
		while (s_frames.length == count && timer.elapsed() < QUIET)
		{
			drain();
			Thread.usleep(100);
		}

		return timer.elapsed();
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

	private static void idled(Window window, int seconds)
	{
		var done = false;
		var frames = s_frames.length;
		var start = cpu_times();
		var main = thread_seconds();
		var probe = new Timer();
		var last = 0.0;
		var stall = 0.0;

		Timeout.add_seconds(seconds, () => {
			done = true;
			return false;
		});
		Timeout.add(PROBE, () => {
			stall = double.max(stall, probe.elapsed() - last);
			last = probe.elapsed();
			return !done;
		});

		while (!done)
		{
			Gtk.main_iteration();
		}

		var end = cpu_times();

		stdout.printf("idle %d s, polling %s: process %.3f s, main thread %.3f s, children %.3f s, %d frames, "
		              + "longest gap between %u ms probes %.1f ms\n",
		              seconds, window.polling ? "on" : "off", end[0] - start[0],
		              thread_seconds() - main, end[1] - start[1],
		              s_frames.length - frames, PROBE, stall * 1000);
	}

	private static Gtk.MenuItem? item(Gtk.Menu menu, string prefix)
	{
		foreach (var child in menu.get_children())
		{
			var found = child as Gtk.MenuItem;

			if (found != null && found.label != null && found.label.has_prefix(prefix))
			{
				return found;
			}
		}

		return null;
	}

	private static Gtk.Menu? line_menu(Window window, Ggit.OId id, string path, int line)
	{
		var history = window.history;
		var selection = history.paned.commit_list_view.get_selection();
		var rows = history.rows();
		Gitg.DiffViewFile? file = null;
		Gtk.Menu? menu = null;
		var longest = 0.0;
		var changed = false;

		history.paned.details_visible = true;
		selection.unselect_all();
		waited(new Timer(), () => history.diff_view.commit == null, ref longest);

		var handler = history.diff_view.files_changed.connect(() => {
			changed = true;
		});

		for (var i = 0; i < rows.length; i++)
		{
			if (rows[i].get_id().equal(id))
			{
				selection.select_path(new Gtk.TreePath.from_indices(i));
			}
		}

		waited(new Timer(), () => changed && (file = diff_file(window, id, path)) != null, ref longest);
		history.diff_view.disconnect(handler);

		if (file == null)
		{
			return null;
		}

		file.expanded = true;
		waited(new Timer(), () => file.get_text_views().length > 0 && file.get_lines().size > 0, ref longest);
		drain();

		var view = file.get_text_views()[0];
		var lines = file.get_lines();

		for (var i = 0; i < lines.size; i++)
		{
			if (lines[i].get_new_lineno() == line)
			{
				Gtk.TextIter iter;
				Gdk.Rectangle location;
				int x;
				int y;

				view.buffer.get_iter_at_offset(out iter, file.get_line_offset(view, i));
				view.buffer.place_cursor(iter);
				view.get_iter_location(iter, out location);
				view.buffer_to_window_coords(Gtk.TextWindowType.TEXT, location.x + 1, location.y + location.height / 2, out x, out y);
				click(view.get_window(Gtk.TextWindowType.TEXT), x, y);
				waited(new Timer(), () => (menu = attached(view)) != null && menu.visible, ref longest);
			}
		}

		return menu;
	}

	private static void lines(Window window, Gee.Set<string> every, string commit, string path, int line)
	{
		var history = window.history;
		var id = new Ggit.OId.from_string(commit);
		var timer = new Timer();

		history.set_ticks(every);
		drain();

		var menu = line_menu(window, id, path, line);
		var show = menu != null ? item(menu, "Show history of this line") : null;

		if (show == null)
		{
			stdout.printf("lines %s:%d: no line history item\n", path, line);
			return;
		}

		var longest = 0.0;

		timer.start();
		show.activate();
		menu.popdown();

		var done = waited(timer, () => history.paned.path_label.get_text().has_prefix("History of line"), ref longest);

		stdout.printf("line history %s:%d from %s: %.3f s, longest stall %.3f s, %d rows\n",
		              path, line, commit.substring(0, 7), done, longest, history.rows().length);

		history.paned.path_bar.response(Gtk.ResponseType.CLOSE);
		drain();
		menu = line_menu(window, id, path, line);

		var blame = menu != null ? item(menu, "Go to the commit that last changed") : null;

		if (blame == null)
		{
			stdout.printf("blame %s:%d: no blame item\n", path, line);
			return;
		}

		longest = 0.0;
		timer.start();
		blame.activate();
		menu.popdown();
		done = waited(timer, () => history.hidden_text != "" || (history.selected != null && !history.selected.get_id().equal(id)), ref longest);

		stdout.printf("blame %s:%d from %s: %.3f s, longest stall %.3f s, went to %s\n",
		              path, line, commit.substring(0, 7), done, longest,
		              history.selected != null ? history.selected.get_id().to_string().substring(0, 7) : history.hidden_text);
	}

	public static int main(string[] args)
	{
		if (args.length < 2)
		{
			stderr.printf("usage: %s <repository> [<full ref name>...]\n       %s --window <repository> [--text <text>] [--search <text>] [--picks <rows>] [--group <key>] [--diff <commit> [--find <text>] [--rows <files>]] [--menu <commit>] [--glance <commit>] [--lines <commit> <path> <line>] [--split <full ref name> <full ref name>] [--changed <text>] [--files <paths>] [--regex] [--scroll <pages>] [--idle <seconds>] [<full ref name>...]\n", args[0], args[0]);
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

	private static void menu(Window window, Gee.Set<string> every, string commit, bool open)
	{
		var history = window.history;
		var view = history.paned.commit_list_view;
		var id = new Ggit.OId.from_string(commit);
		var row = -1;

		history.set_ticks(every);
		drain();

		var rows = history.rows();

		for (var i = 0; i < rows.length; i++)
		{
			if (rows[i].get_id().equal(id))
			{
				row = i;
			}
		}

		if (row < 0)
		{
			stdout.printf("menu on %s: not in the list\n", commit);
			return;
		}

		var path = new Gtk.TreePath.from_indices(row);
		var copy = attached(view);
		var timer = new Timer();
		var shown = -1.0;
		Gdk.Rectangle cell;

		view.scroll_to_cell(path, null, true, 0.5f, 0);
		drain();
		view.get_background_area(path, view.get_column(1), out cell);

		var handler = copy.draw.connect(() => {
			if (shown < 0)
			{
				shown = timer.elapsed();
			}

			return false;
		});

		timer.start();

		var longest = click(view.get_bin_window(), cell.x + 10, cell.y + cell.height / 2);
		var blocked = longest;
		var tag = item(copy, "First tag");
		var merge = item(copy, "Merged into");
		var holders = item(copy, "Branches and tags");
		var held = 0;

		waited(timer, () => shown >= 0, ref longest);

		var tagged = waited(timer, () => tag.label != "First tag with this commit...", ref longest);
		var merged = waited(timer, () => merge == null || !merge.visible || merge.label != "Merged into...", ref longest);

		stdout.printf("menu on %s: shown %.3f s, click blocked %.3f s, first tag %.3f s (%s), merge %.3f s (%s), longest stall %.3f s",
		              commit.substring(0, 7), shown, blocked, tagged, tag.label, merged,
		              merge == null ? "none" : merge.visible ? merge.label : "hidden", longest);

		if (open)
		{
			timer.start();
			copy.select_item(holders);

			var opened = timer.elapsed();

			foreach (var child in ((Gtk.Menu)holders.submenu).get_children())
			{
				if (child is Gtk.CheckMenuItem)
				{
					held++;
				}
			}

			copy.deselect();
			stdout.printf(", %d holders opened in %.3f s", held, opened);
		}

		stdout.printf("\n");

		copy.disconnect(handler);
		copy.popdown();
		drain();
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

	private static double quiet()
	{
		var timer = new Timer();
		var count = s_frames.length;
		var last = 0.0;

		while (timer.elapsed() - last < QUIET)
		{
			drain();

			if (s_frames.length != count)
			{
				count = s_frames.length;
				last = timer.elapsed();
			}

			Thread.usleep(1000);
		}

		return last;
	}

	private static void scrolled(Window window, int pages)
	{
		var settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");
		var list = window.history.paned.scrolled_window_commit_list.vadjustment;
		var panel = (Gtk.ScrolledWindow)window.history.paned.refs_list.get_ancestor(typeof(Gtk.ScrolledWindow));
		var refs = panel.vadjustment;

		settings.set_boolean("enable-monitoring", false);
		stepped(list, "list page by page", pages, list.page_size);
		stepped(list, "list jump to the end", 1, list.upper);
		stepped(list, "list jump to the top", 1, -list.upper);
		stepped(refs, "refs panel page by page", pages, refs.page_size);
		expanded(window);
		settings.set_boolean("enable-monitoring", true);
	}

	private static void searched(Window window, string text, Gee.Set<string> every, string[] only)
	{
		var timer = new Timer();

		window.history.set_ticks(every);
		drain();
		window.history.search_visible = true;
		drain();
		typed(window, text);

		timer.start();
		window.history.search_field.activate();
		drain();

		stdout.printf("window search %s, every ref ticked: %.3f s, %s\n", text, timer.elapsed(), window.history.search_count);

		timer.start();
		window.history.only_matches = true;
		drain();

		stdout.printf("window only matches %s: %.3f s, %d rows\n", text, timer.elapsed(), window.history.rows().length);

		window.history.only_matches = false;
		drain();

		foreach (var name in only)
		{
			var ticks = new Gee.HashSet<string>();
			ticks.add(name);
			window.history.search_field.text = "";
			window.history.search_field.activate();
			window.history.set_ticks(ticks);
			window.history.search_field.text = text;
			drain();

			timer.start();
			window.history.search_field.activate();
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

	private static void split(Window window, Gee.Set<string> every, string name, string other)
	{
		var history = window.history;
		var list = history.paned.refs_list;
		var timer = new Timer();
		var shown = -1.0;
		RefsRow? row = null;
		string? label = null;

		history.set_ticks(every);
		drain();

		foreach (var child in list.get_children())
		{
			var candidate = child as RefsRow;

			if (candidate != null && candidate.reference.name == name)
			{
				row = candidate;
			}
		}

		foreach (var reference in list.refs_in_order())
		{
			if (reference.name == other)
			{
				label = reference.short_name;
			}
		}

		if (row == null || label == null)
		{
			stdout.printf("split %s from %s: no such ref\n", name, other);
			return;
		}

		Gtk.Allocation allocation;
		var copy = attached(list);

		row.get_allocation(out allocation);

		var handler = copy.draw.connect(() => {
			if (shown < 0)
			{
				shown = timer.elapsed();
			}

			return false;
		});

		timer.start();

		var longest = click(list.get_window(), 10, allocation.y + allocation.height / 2);
		var blocked = longest;

		waited(timer, () => shown >= 0, ref longest);
		copy.disconnect(handler);

		var splits = item(copy, "Go to where it splits from");
		var entries = (Gtk.Menu)splits.submenu;
		var menu_stall = longest;

		timer.start();
		copy.select_item(splits);

		var opened = timer.elapsed();
		var count = entries.get_children().length();
		var entry = item(entries, label);

		copy.deselect();

		history.paned.commit_list_view.get_selection().unselect_all();
		drain();
		longest = 0.0;
		timer.start();
		entry.activate();
		copy.popdown();

		var done = waited(timer, () => history.selected != null || history.hidden_text != "", ref longest);

		stdout.printf("split menu on %s: shown %.3f s, click blocked %.3f s, longest stall %.3f s, %u entries opened in %.3f s\n",
		              name, shown, blocked, menu_stall, count, opened);
		stdout.printf("split %s from %s: %.3f s, longest stall %.3f s, went to %s\n",
		              name, other, done, longest,
		              history.selected != null ? history.selected.get_id().to_string().substring(0, 7) : history.hidden_text);
	}

	private static void stepped(Gtk.Adjustment adjustment, string label, int pages, double step)
	{
		quiet();

		var first = s_frames.length;
		var start = cpu_times();
		var main = thread_seconds();
		var steps = 0;
		var slowest = 0.0;

		while (steps < pages)
		{
			var before = adjustment.value;
			var count = s_frames.length;
			var timer = new Timer();

			adjustment.value += step;

			if (adjustment.value == before)
			{
				break;
			}

			slowest = double.max(slowest, frame(count, timer));
			steps++;
		}

		if (steps == 0)
		{
			stdout.printf("%s: nothing to scroll\n", label);
			return;
		}

		var stepping = s_frames.length;
		var last = quiet();
		var end = cpu_times();
		double[] frames = s_frames[first:stepping];

		Posix.qsort(frames, frames.length, sizeof(double), (a, b) => {
			var x = *(double *)a;
			var y = *(double *)b;
			return x < y ? -1 : (x > y ? 1 : 0);
		});

		stdout.printf("%s, %d steps: frame median %.1f ms, slowest %.1f ms, scroll to painted slowest %.1f ms, "
		              + "main thread %.3f s, children %.3f s, %d frames after the last step, last %.3f s after\n",
		              label, steps, frames[frames.length / 2] * 1000,
		              frames[frames.length - 1] * 1000, slowest * 1000,
		              s_painted - main, end[1] - start[1],
		              s_frames.length - stepping, last);
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

	private static double thread_seconds()
	{
		string stat;

		try
		{
			FileUtils.get_contents("/proc/thread-self/schedstat", out stat);
		}
		catch
		{
			return 0;
		}

		return double.parse(stat.split(" ")[0]) / 1e9;
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

	private static void typed(Window window, string text)
	{
		var field = window.history.search_field;
		var timer = new Timer();
		var slowest = 0.0;
		var keys = 0;
		var index = 0;
		unichar key;

		field.text = "";
		drain();
		timer.start();

		while (text.get_next_char(ref index, out key))
		{
			var step = new Timer();

			field.text = text.substring(0, index);
			drain();
			slowest = double.max(slowest, step.elapsed());
			keys++;
		}

		stdout.printf("window typing %s, %d keys: %.3f s, slowest key %.3f s\n", text, keys, timer.elapsed(), slowest);
	}

	private static double waited(Timer timer, Done done, ref double longest)
	{
		var step = new Timer();
		var start = timer.elapsed();

		while (!done() && timer.elapsed() - start < 60)
		{
			if (!Gtk.events_pending())
			{
				Thread.usleep(500);
				continue;
			}

			step.start();
			Gtk.main_iteration();
			longest = double.max(longest, step.elapsed());
		}

		return timer.elapsed();
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
		var menus = new string[0];
		var opens = new bool[0];
		var lined = new string[0];
		var splits = new string[0];
		var picks = 0;
		string? text = null;
		string? search = null;
		string? commit = null;
		string? word = null;
		var rows = int.MAX;
		var pages = 0;
		var idle = 0;
		string? changed = null;
		string? files = null;
		var regex = false;

		for (var i = 0; i < arguments.length; i++)
		{
			if ((arguments[i] == "--menu" || arguments[i] == "--glance") && i + 1 < arguments.length)
			{
				opens += arguments[i] == "--menu";
				menus += arguments[++i];
			}
			else if (arguments[i] == "--lines" && i + 3 < arguments.length)
			{
				lined += arguments[++i];
				lined += arguments[++i];
				lined += arguments[++i];
			}
			else if (arguments[i] == "--split" && i + 2 < arguments.length)
			{
				splits += arguments[++i];
				splits += arguments[++i];
			}
			else if (arguments[i] == "--text" && i + 1 < arguments.length)
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
			else if (arguments[i] == "--scroll" && i + 1 < arguments.length)
			{
				pages = int.parse(arguments[++i]);
			}
			else if (arguments[i] == "--idle" && i + 1 < arguments.length)
			{
				idle = int.parse(arguments[++i]);
			}
			else if (arguments[i] == "--changed" && i + 1 < arguments.length)
			{
				changed = arguments[++i];
			}
			else if (arguments[i] == "--files" && i + 1 < arguments.length)
			{
				files = arguments[++i];
			}
			else if (arguments[i] == "--regex")
			{
				regex = true;
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

		var painting = new Timer();

		s_frames = new double[0];
		window.get_frame_clock().before_paint.connect(() => painting.start());
		window.get_frame_clock().after_paint.connect(() => {
			s_frames += painting.elapsed();
			s_painted = thread_seconds();
		});
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

		for (var i = 0; i < menus.length; i++)
		{
			menu(window, every, menus[i], opens[i]);
		}

		for (var i = 0; i + 2 < lined.length; i += 3)
		{
			lines(window, every, lined[i], lined[i + 1], int.parse(lined[i + 2]));
		}

		for (var i = 0; i + 1 < splits.length; i += 2)
		{
			split(window, every, splits[i], splits[i + 1]);
		}

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

		if (pages > 0)
		{
			scrolled(window, pages);
		}

		if (idle > 0)
		{
			idled(window, idle);
		}

		if (changed != null)
		{
			entered(window, SearchChoice.LINES, changed, regex, every, only);
		}

		if (files != null)
		{
			entered(window, SearchChoice.FILES, files, regex, every, only);
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
