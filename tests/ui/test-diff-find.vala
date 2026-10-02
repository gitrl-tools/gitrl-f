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

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/diff-find/a-bad-expression-turns-the-field-red", test_a_bad_expression_turns_the_field_red);
	Test.add_func("/gittree/ui/diff-find/a-match-in-a-folded-file-unfolds-it-and-shows", test_a_match_in_a_folded_file_unfolds_it_and_shows);
	Test.add_func("/gittree/ui/diff-find/a-regex-narrows-the-marks", test_a_regex_narrows_the_marks);
	Test.add_func("/gittree/ui/diff-find/a-switch-to-split-searches-again", test_a_switch_to_split_searches_again);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-in-the-pane-opens-and-closes-the-diff-bar", test_ctrl_f_in_the_pane_opens_and_closes_the_diff_bar);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-leaves-a-selection-over-two-lines", test_ctrl_f_leaves_a_selection_over_two_lines);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-takes-a-selection-on-one-line", test_ctrl_f_takes_a_selection_on_one_line);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-with-the-diff-filling-the-window", test_ctrl_f_with_the_diff_filling_the_window);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-with-the-pane-open-finds-in-the-diff-from-the-list", test_ctrl_f_with_the_pane_open_finds_in_the_diff_from_the_list);
	Test.add_func("/gittree/ui/diff-find/ctrl-f-with-the-pane-shut-opens-the-list-bar", test_ctrl_f_with_the_pane_shut_opens_the_list_bar);
	Test.add_func("/gittree/ui/diff-find/escape-after-ctrl-f-in-the-list-gives-the-focus-back-to-the-list", test_escape_after_ctrl_f_in_the_list_gives_the_focus_back_to_the_list);
	Test.add_func("/gittree/ui/diff-find/escape-in-the-field-closes-the-bar-and-keeps-the-text", test_escape_in_the_field_closes_the_bar_and_keeps_the_text);
	Test.add_func("/gittree/ui/diff-find/next-and-previous-cross-files-and-wrap", test_next_and_previous_cross_files_and_wrap);
	Test.add_func("/gittree/ui/diff-find/no-match-turns-the-field-red", test_no_match_turns_the_field_red);
	Test.add_func("/gittree/ui/diff-find/one-bar-at-the-bottom-scrolls-the-file-of-the-current-match", test_one_bar_at_the_bottom_scrolls_the_file_of_the_current_match);
	Test.add_func("/gittree/ui/diff-find/the-bar-closes-with-the-pane", test_the_bar_closes_with_the_pane);
	Test.add_func("/gittree/ui/diff-find/the-close-button-closes-the-bar-and-keeps-the-text", test_the_close_button_closes_the_bar_and_keeps_the_text);
	Test.add_func("/gittree/ui/diff-find/the-count-stands-apart-from-the-switches", test_the_count_stands_apart_from_the_switches);
	Test.add_func("/gittree/ui/diff-find/the-scroll-bar-follows-the-file-in-the-middle-of-the-pane", test_the_scroll_bar_follows_the_file_in_the_middle_of_the_pane);
	Test.add_func("/gittree/ui/diff-find/the-switches-say-what-they-do", test_the_switches_say_what_they_do);
	Test.add_func("/gittree/ui/diff-find/the-text-is-kept-from-commit-to-commit", test_the_text_is_kept_from_commit_to_commit);
	Test.add_func("/gittree/ui/diff-find/typing-marks-every-match-and-moves-nothing", test_typing_marks_every_match_and_moves_nothing);

	return Test.run();
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

private static Gittree.DiffScrollBar pane_bar(Gittree.Window window)
{
	return (Gittree.DiffScrollBar)find_all(window.history.paned.box_details, typeof(Gittree.DiffScrollBar))[0];
}

private static Gtk.ScrolledWindow pane_of(Gittree.Window window)
{
	return (Gtk.ScrolledWindow)find_all(window.history.diff_view, typeof(Gtk.ScrolledWindow))[0];
}

private static Gtk.ScrolledWindow scroller(Gitg.DiffViewFile file)
{
	return (Gtk.ScrolledWindow)file.get_text_views()[0].get_parent();
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

private static void select_text(Gittree.Window window, int file, string text)
{
	var view = window.history.diff_view.get_files()[file].get_text_views()[0];
	Gtk.TextIter start;
	Gtk.TextIter found;
	Gtk.TextIter end;

	view.buffer.get_start_iter(out start);
	assert_true(start.forward_search(text, 0, out found, out end, null));
	view.buffer.select_range(found, end);
	view.grab_focus();
	settle(100);
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

private static void test_a_bad_expression_turns_the_field_red()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		check_labelled(bar, "Regex").active = true;
		search_for(window, "(");

		assert_cmpstr(bar.count, CompareOperator.EQ, "Bad regex");
		assert_true(bar.field.get_style_context().has_class("error"));

		unfold_all(window);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
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

private static void test_a_regex_narrows_the_marks()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		unfold_all(window);
		check_labelled(bar, "Regex").active = true;
		search_for(window, "^needle in [a-z]");

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:Needle in a|2:needle in c");

		bar.match_case = true;
		settle(200);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "2:needle in c");

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
		assert_cmpstr(bar.field.placeholder_text, CompareOperator.EQ, "Find in the changed lines of this commit");
		assert_cmpstr(bar.field.tooltip_text, CompareOperator.EQ, "Searches the added, removed and unchanged lines of every file in the commit shown below, folded files too");
		assert_false(bar.match_case);

		bar.field.text = "needle";
		settle(400);
		window.activate_action("search", null);
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "needle");
		assert_true(focus_in(window, window.history.diff_view));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_f_leaves_a_selection_over_two_lines()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "keep");
		bar.search_mode_enabled = false;
		settle(100);
		unfold_all(window);
		select_text(window, 2, "c\nkeep");
		window.activate_action("search", null);
		settle(300);

		assert_true(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "keep");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_f_takes_a_selection_on_one_line()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		unfold_all(window);
		select_text(window, 2, "needle");
		window.activate_action("search", null);
		settle(400);

		assert_true(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "needle");
		assert_cmpstr(bar.count, CompareOperator.EQ, "2 of 2");
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "2:needle");

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

private static void test_ctrl_f_with_the_pane_open_finds_in_the_diff_from_the_list()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");

		window.history.paned.commit_list_view.grab_focus();
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

private static void test_ctrl_f_with_the_pane_shut_opens_the_list_bar()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");

		window.history.paned.details_visible = false;
		settle(100);
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

private static void test_escape_after_ctrl_f_in_the_list_gives_the_focus_back_to_the_list()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		window.history.paned.commit_list_view.grab_focus();
		window.activate_action("search", null);
		settle(100);

		assert_true(bar.field.has_focus);

		Gtk.test_widget_send_key(bar.field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_true(window.history.paned.commit_list_view.has_focus);
		assert_cmpstr(selected_label_text(window.history.diff_view), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_in_the_field_closes_the_bar_and_keeps_the_text()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;
		var before = window.get_focus();

		search_for(window, "keep");
		unfold_all(window);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:keep|1:keep|2:keep");

		bar.field.grab_focus();
		Gtk.test_widget_send_key(bar.field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "keep");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "");
		assert_nonnull(before);
		assert_true(window.get_focus() == before);

		window.activate_action("search", null);
		settle(300);

		int start;
		int end;

		assert_true(bar.search_mode_enabled);
		assert_true(bar.field.get_selection_bounds(out start, out end));
		assert_cmpint(end - start, CompareOperator.EQ, 4);
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:keep|1:keep|2:keep");

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

		Gtk.test_widget_send_key(bar.field, Gdk.Key.g, Gdk.ModifierType.CONTROL_MASK);
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 of 2");

		Gtk.test_widget_send_key(bar.field, Gdk.Key.G, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK);
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

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 matches");
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

private static void test_one_bar_at_the_bottom_scrolls_the_file_of_the_current_match()
{
	try
	{
		var repo = wide_files();
		var window = opened(repo, "wide");

		unfold_all(window);
		search_for(window, "needle");
		window.history.find_bar.step(1);
		settle(300);

		var files = window.history.diff_view.get_files();
		var bar = pane_bar(window);
		var box = window.history.paned.box_details;
		int x;
		int y;

		assert_true(bar.get_mapped());
		assert_true(bar.adjustment == scroller(files[1]).hadjustment);
		assert_cmpfloat(bar.adjustment.value, CompareOperator.GT, 0);

		foreach (var file in files)
		{
			assert_false(scroller(file).get_hscrollbar().get_mapped());
		}

		bar.translate_coordinates(box, 0, 0, out x, out y);

		assert_cmpint(y + bar.get_allocated_height(), CompareOperator.EQ, box.get_allocated_height());

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

private static void test_the_close_button_closes_the_bar_and_keeps_the_text()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;
		var row = bar.field.get_parent();
		Gtk.Button? close = null;

		search_for(window, "keep");

		foreach (var widget in find_all(bar, typeof(Gtk.Button)))
		{
			if (!widget.is_ancestor(row) && widget.get_mapped())
			{
				close = (Gtk.Button)widget;
			}
		}

		assert_nonnull(close);

		close.clicked();
		settle(100);

		assert_false(bar.search_mode_enabled);
		assert_cmpstr(bar.field.text, CompareOperator.EQ, "keep");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_count_stands_apart_from_the_switches()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		search_for(window, "zzz");

		Gtk.Allocation check;
		Gtk.Allocation count;

		check_labelled(bar, "Regex").get_allocation(out check);
		label_with(bar, "No match").get_allocation(out count);

		assert_cmpint(count.x - (check.x + check.width), CompareOperator.GE, 18);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_scroll_bar_follows_the_file_in_the_middle_of_the_pane()
{
	try
	{
		var repo = wide_files();
		var window = opened(repo, "wide");

		unfold_all(window);

		var files = window.history.diff_view.get_files();
		var bar = pane_bar(window);
		var vertical = pane_of(window).vadjustment;

		vertical.value = top_of(window, files[0]) + 40 - vertical.page_size / 2;
		settle(200);

		assert_false(bar.get_mapped());

		vertical.value = vertical.upper - vertical.page_size;
		settle(200);

		assert_true(bar.get_mapped());
		assert_true(bar.adjustment == scroller(files[2]).hadjustment);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_switches_say_what_they_do()
{
	try
	{
		var repo = three_files();
		var window = opened(repo, "change");
		var bar = window.history.find_bar;

		assert_cmpstr(check_labelled(bar, "Match case").tooltip_text, CompareOperator.EQ, "Tell capital and small letters apart");
		assert_cmpstr(check_labelled(bar, "Regex").tooltip_text, CompareOperator.EQ, "Read the text as a regex, a POSIX extended regular expression, as git log -G does");

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

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 of 2");

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

		assert_cmpstr(bar.count, CompareOperator.EQ, "2 matches");

		foreach (var file in files)
		{
			assert_false(file.expanded);
		}

		unfold_all(window);

		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "0:Needle|2:needle");
		assert_cmpstr(marks(window, "diff-find-current"), CompareOperator.EQ, "");

		bar.match_case = true;
		settle(100);

		assert_cmpstr(bar.count, CompareOperator.EQ, "1 match");
		assert_cmpstr(marks(window, "diff-find-match"), CompareOperator.EQ, "2:needle");

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

private static int top_of(Gittree.Window window, Gtk.Widget widget)
{
	var content = ((Gtk.Bin)pane_of(window).get_child()).get_child();
	int x;
	int y;

	widget.translate_coordinates(content, 0, 0, out x, out y);

	return y;
}

private static void unfold_all(Gittree.Window window)
{
	foreach (var file in window.history.diff_view.get_files())
	{
		file.expanded = true;
	}

	settle(300);
}

private static Repo wide_files() throws Error
{
	var repo = Repo.create();
	var filler = new StringBuilder();
	var lines = new StringBuilder();

	for (var i = 0; i < 60; i++)
	{
		filler.append("filler ");
	}

	for (var i = 0; i < 40; i++)
	{
		lines.append("line %d\n".printf(i));
	}

	foreach (var name in new string[] { "a.txt", "b.txt", "c.txt" })
	{
		FileUtils.set_contents(repo.path.get_child(name).get_path(), "keep\n");
	}

	repo.git({"add", "--all"});
	repo.git({"commit", "--quiet", "-m", "start"});

	FileUtils.set_contents(repo.path.get_child("a.txt").get_path(), "keep\n" + lines.str);
	FileUtils.set_contents(repo.path.get_child("b.txt").get_path(), "keep\n" + lines.str + filler.str + "needle\n");
	FileUtils.set_contents(repo.path.get_child("c.txt").get_path(), "keep\n" + lines.str + filler.str + "wide\n");
	repo.git({"commit", "--quiet", "-am", "wide"});

	return repo;
}

}
