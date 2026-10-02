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
 */namespace GitrlfTest
{

private static void activate(string prefix)
{
	var item = menu_item_starting(prefix);

	if (item != null)
	{
		item.activate();
		((Gtk.Menu)item.get_parent()).popdown();
	}

	settle(800);
}

private static Gitrlf.Application application()
{
	var app = GLib.Application.get_default() as Gitrlf.Application;

	if (app == null)
	{
		app = new Gitrlf.Application();

		try
		{
			app.register();
		}
		catch (Error e)
		{
			Test.fail_printf("could not register: %s", e.message);
		}
	}

	return app;
}

private static string differences(File a, File b) throws Error
{
	return run({ "diff", "-r", "--no-dereference", a.get_path(), b.get_path() });
}

private static void every_row(Gitrlf.Window window)
{
	var rows = window.history.rows().length;

	for (var i = 0; i < rows; i++)
	{
		window.history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
		settle(120);
	}
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/session/a-session-changes-nothing", test_a_session_changes_nothing);

	return Test.run();
}

private static void right_click_row(Gitrlf.Window window, int row)
{
	var view = window.history.paned.commit_list_view;
	Gdk.Rectangle cell;
	int origin_x;
	int origin_y;

	view.get_background_area(new Gtk.TreePath.from_indices(row), view.get_column(1), out cell);
	view.get_bin_window().get_origin(out origin_x, out origin_y);
	click_at(origin_x + cell.x + 10, origin_y + cell.y + cell.height / 2, 1, 3);
	settle(600);
}

private static void right_click_text(Gitrlf.Window window, string text)
{
	foreach (var file in window.history.diff_view.get_files())
	{
		file.expanded = true;
	}

	settle(400);

	foreach (var file in window.history.diff_view.get_files())
	{
		foreach (var view in file.get_text_views())
		{
			Gtk.TextIter start;
			Gtk.TextIter found;
			Gtk.TextIter end;
			Gdk.Rectangle location;
			int x;
			int y;
			int top_x;
			int top_y;
			int origin_x;
			int origin_y;

			view.buffer.get_start_iter(out start);

			if (!start.forward_search(text, 0, out found, out end, null))
			{
				continue;
			}

			view.get_iter_location(found, out location);
			view.buffer_to_window_coords(Gtk.TextWindowType.WIDGET, location.x + 1, location.y + location.height / 2, out x, out y);
			view.translate_coordinates(view.get_toplevel(), x, y, out top_x, out top_y);
			view.get_toplevel().get_window().get_origin(out origin_x, out origin_y);
			click_at(origin_x + top_x, origin_y + top_y, 1, 3);
			settle(300);
			return;
		}
	}
}

private static string run(string[] argv) throws Error
{
	string output;
	string errors;
	int status;

	Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, out output, out errors, out status);

	return output + errors;
}

private static void settle(int milliseconds)
{
	for (var i = 0; i < milliseconds / 10; i++)
	{
		while (Gtk.events_pending())
		{
			Gtk.main_iteration();
		}

		Thread.usleep(10000);
	}
}

private static void stage_four(File location, Repo repo)
{
	var window = new Gitrlf.Window(application());
	var history = window.history;
	var bar = history.search_field.get_parent();

	window.set_default_size(1000, 800);
	window.open_repository(location, null, {}, repo.path);
	window.show();
	settle(300);

	history.search_visible = true;

	foreach (var label in new string[] { "Match case", "Regex", "Display matches only" })
	{
		check_labelled(bar, label).active = true;
		history.search_field.text = "f[a-z]+";
		settle(300);
		check_labelled(bar, label).active = false;
	}

	history.search_field.text = "author:tester after:2026-01 fix";
	settle(300);

	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/feature/scan");
	history.set_ticks(ticks);
	history.search_field.text = "fix two";
	settle(300);

	foreach (var widget in find_all(bar, typeof(Gtk.Button)))
	{
		if (((Gtk.Button)widget).label == "Tick and show")
		{
			((Gtk.Button)widget).clicked();
		}
	}

	settle(300);
	history.search_visible = false;
	history.paned.refs_list.tick_all();
	settle(200);

	history.apply("fix|base", true, true, {});
	settle(800);
	history.apply("", true, false, { "fix" });
	settle(800);
	history.lift_filter();
	settle(300);

	var rows = history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == "fix two")
		{
			history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
			right_click_row(window, i);
			activate("Merged into");
			right_click_row(window, i);
			activate("First tag");
		}
	}

	rows = history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == "fix two")
		{
			history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
		}
	}

	history.paned.details_visible = true;
	history.paned.details_only = true;
	settle(600);
	right_click_text(window, "fix one");
	activate("Go to the commit");
	right_click_text(window, "fix");
	activate("Show history of");
	history.paned.path_bar.response(Gtk.ResponseType.CLOSE);
	history.paned.details_only = false;
	settle(300);

	click_widget(row(history.paned.refs_list, "feature/scan"), 3);
	settle(300);

	var split = menu_item("Go to where it splits from");

	if (split != null)
	{
		foreach (var child in ((Gtk.Menu)split.submenu).get_children())
		{
			if (((Gtk.MenuItem)child).label == "master")
			{
				((Gtk.MenuItem)child).activate();
			}
		}

		((Gtk.Menu)split.get_parent()).popdown();
	}

	settle(500);
	window.activate_action("reload", null);
	settle(500);
	window.close();
	settle(100);
}

private static void test_a_session_changes_nothing()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.git({"tag", "-a", "-m", "annotated", "v2", "master"});
		repo.commit("binary", "blob.bin", "\x01\x02");
		repo.commit("image", "dot.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2\" height=\"2\"/>");
		FileUtils.set_contents(repo.path.get_child("file").get_path(), "uncommitted change\n");
		FileUtils.set_contents(repo.path.get_child("untracked").get_path(), "untracked\n");

		var copy = repo.path.get_parent().get_child(repo.path.get_basename() + "-copy");
		run({ "cp", "-a", repo.path.get_path(), copy.get_path() });

		var location = Gitrlf.Application.discover_repository(repo.path);
		var window = new Gitrlf.Window(application());
		window.set_default_size(1000, 800);
		window.open_repository(location, null, {}, repo.path);
		window.show();
		settle(200);

		var refs = window.history.paned.refs_list;

		refs.tick_all();
		every_row(window);
		refs.tick_none();
		refs.tick_all();
		window.history.jump("refs/tags/v2");
		window.history.search_visible = true;
		window.history.search_field.text = "fix";
		settle(300);
		window.history.step(1);
		window.history.step(-1);
		window.activate_action("reload", null);
		settle(200);
		window.close();
		settle(100);

		var limited = new Gitrlf.Window(application());
		limited.set_default_size(1000, 800);
		limited.open_repository(location, null, {"fix"}, repo.path);
		limited.show();
		settle(200);
		every_row(limited);
		limited.close();
		settle(100);

		foreach (var path in new string[] { "", "fix" })
		{
			var filtered = new Gitrlf.Window(application());
			filtered.set_default_size(1000, 800);
			filtered.open_repository(location, null, path != "" ? new string[] { path } : new string[0], repo.path, "fix", false);
			filtered.show();
			settle(800);

			assert_true("add or remove fix" in filtered.history.path_bar_text);
			assert_cmpint(filtered.history.rows().length, CompareOperator.GT, 0);

			filtered.history.paned.details_visible = true;
			every_row(filtered);
			filtered.history.find_bar.search_mode_enabled = true;
			filtered.history.find_bar.field.text = "fix";
			settle(300);
			filtered.history.find_bar.step(1);
			filtered.history.find_bar.step(-1);
			filtered.history.apply_filter("FIX", true);
			settle(800);
			filtered.activate_action("reload", null);
			settle(800);
			filtered.history.lift_filter();
			settle(200);
			filtered.close();
			settle(100);
		}

		stage_four(location, repo);

		assert_cmpstr(differences(copy, repo.path), CompareOperator.EQ, "");

		run({ "rm", "-rf", copy.get_path() });
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
