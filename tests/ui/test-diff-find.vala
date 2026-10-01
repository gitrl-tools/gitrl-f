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
 */namespace GittreeTest
{

private static Gittree.Application application()
{
	var app = GLib.Application.get_default() as Gittree.Application;

	if (app == null)
	{
		app = new Gittree.Application();

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

private static Gtk.Button button(Gittree.DiffFindBar bar, string tooltip)
{
	foreach (var widget in find_all(bar, typeof(Gtk.Button)))
	{
		if (widget.tooltip_text == tooltip)
		{
			return (Gtk.Button)widget;
		}
	}

	error("no button %s", tooltip);
}

private static bool focus_in(Gittree.Window window, Gtk.Widget area)
{
	var focus = window.get_focus();

	return focus != null && (focus == area || focus.is_ancestor(area));
}

private static Repo many_files() throws Error
{
	var repo = Repo.create();

	for (var i = 0; i < 12; i++)
	{
		FileUtils.set_contents(repo.path.get_child("f%02d.txt".printf(i)).get_path(), "keep\n");
	}

	repo.git({"add", "--all"});
	repo.git({"commit", "--quiet", "-m", "start"});

	for (var i = 0; i < 12; i++)
	{
		var text = new StringBuilder("keep\n");

		for (var line = 0; line < 30; line++)
		{
			text.append(i == 11 && line == 29 ? "the needle\n" : "line %d\n".printf(line));
		}

		FileUtils.set_contents(repo.path.get_child("f%02d.txt".printf(i)).get_path(), text.str);
	}

	repo.git({"commit", "--quiet", "-am", "many"});

	return repo;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/diff-find/a-match-in-a-folded-file-unfolds-it-and-shows", test_a_match_in_a_folded_file_unfolds_it_and_shows);
	Test.add_func("/gittree/ui/diff-find/a-switch-to-split-searches-again", test_a_switch_to_split_searches_again);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-in-the-list-opens-the-list-bar", test_ctrl_f_in_the_list_opens_the_list_bar);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-in-the-pane-opens-and-closes-the-diff-bar", test_ctrl_f_in_the_pane_opens_and_closes_the_diff_bar);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-with-the-diff-filling-the-window", test_ctrl_f_with_the_diff_filling_the_window);
	Test.add_func("/gittree/ui/diff-find/escape-in-the-field-closes-the-bar-and-clears-the-marks", test_escape_in_the_field_closes_the_bar_and_clears_the_marks);
	Test.add_func("/gittree/ui/diff-find/next-and-previous-cross-files-and-wrap", test_next_and_previous_cross_files_and_wrap);
	Test.add_func("/gittree/ui/diff-find/no-match-turns-the-field-red", test_no_match_turns_the_field_red);
	Test.add_func("/gittree/ui/diff-find/the-bar-closes-with-the-pane", test_the_bar_closes_with_the_pane);
	Test.add_func("/gittree/ui/diff-find/the-text-is-kept-from-commit-to-commit", test_the_text_is_kept_from_commit_to_commit);
	Test.add_func("/gittree/ui/diff-find/typing-marks-every-match-and-moves-nothing", test_typing_marks_every_match_and_moves_nothing);

	return Test.run();
}

private static string marks(Gittree.Window window, string tag_name)
{
	var words = new string[0];
	var files = window.history.diff_view.get_files();

	for (var i = 0; i < files.size; i++)
	{
		foreach (var view in files[i].get_text_views())
		{
			var tag = view.buffer.tag_table.lookup(tag_name);

			if (tag == null)
			{
				continue;
			}

			Gtk.TextIter iter;
			view.buffer.get_start_iter(out iter);

			while (iter.forward_to_tag_toggle(tag))
			{
				if (!iter.starts_tag(tag))
				{
					continue;
				}

				var end = iter;
				end.forward_to_tag_toggle(tag);
				words += "%d:%s".printf(i, iter.get_text(end));
				iter = end;
			}
		}
	}

	return string.joinv("|", words);
}

private static Gittree.Window opened(Repo repo, string subject) throws Error
{
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/master");

	var window = new Gittree.Window(application());
	window.set_default_size(1200, 900);
	window.open_repository(Gittree.Application.discover_repository(repo.path), ticks, {}, repo.path);
	window.show();
	settle(300);
	window.history.paned.details_visible = true;
	settle(100);
	select_subject(window, subject);

	return window;
}

private static void search_for(Gittree.Window window, string text)
{
	window.history.find_bar.search_mode_enabled = true;
	window.history.find_bar.field.text = text;
	settle(400);
}

private static void select_subject(Gittree.Window window, string subject)
{
	var rows = window.history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == subject)
		{
			window.history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
		}
	}

	settle(400);
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

private static Repo three_files() throws Error
{
	var repo = Repo.create();

	foreach (var name in new string[] { "a.txt", "b.txt", "c.txt" })
	{
		FileUtils.set_contents(repo.path.get_child(name).get_path(), "keep\n");
	}

	repo.git({"add", "--all"});
	repo.git({"commit", "--quiet", "-m", "start"});

	FileUtils.set_contents(repo.path.get_child("a.txt").get_path(), "keep\nNeedle in a\n");
	FileUtils.set_contents(repo.path.get_child("b.txt").get_path(), "keep\nno match here\n");
	FileUtils.set_contents(repo.path.get_child("c.txt").get_path(), "needle in c\nkeep\n");
	repo.git({"commit", "--quiet", "-am", "change"});

	FileUtils.set_contents(repo.path.get_child("b.txt").get_path(), "keep\nneedle in b\nneedle again\n");
	repo.git({"commit", "--quiet", "-am", "later"});

	return repo;
}

private static void unfold_all(Gittree.Window window)
{
	foreach (var file in window.history.diff_view.get_files())
	{
		file.expanded = true;
	}

	settle(300);
}

private static void test_a_match_in_a_folded_file_unfolds_it_and_shows()
{
	try
	{
		var repo = many_files();
		var window = opened(repo, "many");
		var bar = window.history.find_bar;
		var files = window.history.diff_view.get_files();

		search_for(window, "needle");

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 match");
		assert_false(files[11].expanded);

		bar.step(1);
		settle(500);

		assert_true(files[11].expanded);
		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 1");
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "11:needle");

		var view = files[11].get_text_views()[0];
		Gtk.ScrolledWindow? outer = null;

		for (var widget = view.get_parent(); widget != null; widget = widget.get_parent())
		{
			var scrolled = widget as Gtk.ScrolledWindow;

			if (scrolled != null && scrolled.vscrollbar_policy != Gtk.PolicyType.NEVER)
			{
				outer = scrolled;
				break;
			}
		}

		Gtk.TextIter iter;
		Gdk.Rectangle location;
		int x;
		int y;
		int shown_x;
		int shown_y;

		view.buffer.get_end_iter(out iter);
		iter.backward_chars(1);
		view.get_iter_location(iter, out location);
		view.buffer_to_window_coords(Gtk.TextWindowType.WIDGET, location.x, location.y, out x, out y);
		view.translate_coordinates(outer, x, y, out shown_x, out shown_y);

		assert_true(outer.vadjustment.value > 0);
		assert_cmpint(shown_y, CompareOperator.GE, 0);
		assert_cmpint(shown_y + location.height, CompareOperator.LE, outer.get_allocated_height());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_switch_to_split_searches_again()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "keep");
		unfold_all(window);

		assert_cmpstr(bar.count, CompareOperator.EQ, "3 matches");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:keep|1:keep|2:keep");

		foreach (var widget in find_all(window.history.diff_view.get_files()[0], typeof(Gtk.ToggleButton)))
		{
			var label = ((Gtk.ToggleButton)widget).get_child() as Gtk.Label;

			if (label != null && label.label == "Split")
			{
				((Gtk.ToggleButton)widget).active = true;
			}
		}

		settle(300);

		assert_true(window.history.diff_view.get_files()[0].split);
		assert_cmpstr(bar.count, CompareOperator.EQ, "4 matches");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:keep|0:keep|1:keep|2:keep");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_f_in_the_list_opens_the_list_bar()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");

		window.history.paned.commit_list_view.grab_focus();
		window.activate_action("search", null);
		settle(100);

		assert_true(window.history.search_visible);
		assert_false(window.history.find_bar.search_mode_enabled);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_f_in_the_pane_opens_and_closes_the_diff_bar()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		find_all(window.history.diff_view, typeof(Gtk.Expander))[0].grab_focus();
		window.activate_action("search", null);
		settle(100);

		assert_true(bar.search_mode_enabled);
		assert_false(window.history.search_visible);
		assert_true(bar.field.has_focus);
		assert_cmpstr(bar.field.placeholder_text, CompareOperator.EQ, "Find in the diff");
		assert_true(bar.match_case);

		bar.field.text = "needle";
		settle(400);
		window.activate_action("search", null);
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "");
		assert_true(focus_in(window, window.history.diff_view));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_f_with_the_diff_filling_the_window()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");

		window.history.paned.commit_list_view.grab_focus();
		window.history.paned.details_only = true;
		settle(100);
		window.activate_action("search", null);
		settle(100);

		assert_true(window.history.find_bar.search_mode_enabled);
		assert_false(window.history.search_visible);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_in_the_field_closes_the_bar_and_clears_the_marks()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "keep");
		unfold_all(window);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:keep|1:keep|2:keep");

		bar.field.grab_focus();
		Gtk.test_widget_send_key(bar.field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "");
		assert_true(focus_in(window, window.history.diff_view));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_next_and_previous_cross_files_and_wrap()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;
		var files = window.history.diff_view.get_files();
		var next = button(bar, "Next match (Enter)");
		var previous = button(bar, "Previous match (Shift+Enter)");

		search_for(window, "needle");
		bar.match_case = false;
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 matches");

		next.clicked();
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 2");
		assert_true(files[0].expanded);
		assert_false(files[2].expanded);
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "0:Needle");

		bar.field.activate();
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 of 2");
		assert_true(files[2].expanded);
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "2:needle");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:Needle");

		next.clicked();
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 2");
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "0:Needle");

		previous.clicked();
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 of 2");

		bar.field.grab_focus();
		Gtk.test_widget_send_key(bar.field, Gdk.Key.Return, Gdk.ModifierType.SHIFT_MASK);
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 2");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_no_match_turns_the_field_red()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "zzz");

		assert_cmpstr(bar.count, CompareOperator.EQ, "No match");
		assert_true(bar.field.get_style_context().has_class("error"));

		search_for(window, "needle");

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 match");
		assert_false(bar.field.get_style_context().has_class("error"));

		search_for(window, "");

		assert_cmpstr(bar.count, CompareOperator.EQ, "");
		assert_false(bar.field.get_style_context().has_class("error"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_bar_closes_with_the_pane()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");

		search_for(window, "needle");
		window.history.paned.details_visible = false;
		settle(100);

		assert_false(window.history.find_bar.search_mode_enabled);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_text_is_kept_from_commit_to_commit()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "needle");
		bar.step(1);
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 1");

		select_subject(window, "later");

		assert_cmpstr(bar.field.text, CompareOperator.EQ, "needle");
		assert_cmpstr(bar.count, CompareOperator.EQ, "2 matches");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_typing_marks_every_match_and_moves_nothing()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;
		var files = window.history.diff_view.get_files();

		search_for(window, "needle");

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 match");

		foreach (var file in files)
		{
			assert_false(file.expanded);
		}

		bar.match_case = false;
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 matches");

		unfold_all(window);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:Needle|2:needle");
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "");

		var tag = files[0].get_text_views()[0].buffer.tag_table.lookup("diff-find-match");
		var current = files[0].get_text_views()[0].buffer.tag_table.lookup("diff-find-current");

		assert_cmpstr(tag.background_rgba.to_string(), CompareOperator.EQ, "rgb(252,233,79)");
		assert_cmpstr(tag.foreground_rgba.to_string(), CompareOperator.EQ, "rgb(26,26,26)");
		assert_cmpstr(current.background_rgba.to_string(), CompareOperator.EQ, "rgb(245,121,0)");
		assert_cmpstr(current.foreground_rgba.to_string(), CompareOperator.EQ, "rgb(26,26,26)");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
