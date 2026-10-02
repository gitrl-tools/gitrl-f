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

private static Gtk.CheckButton check_of(Gittree.Window window, string short_name)
{
	return (Gtk.CheckButton)find_all(row(window.history.paned.refs_list, short_name), typeof(Gtk.CheckButton))[0];
}

private static void choose_split(Gittree.Window window, string from, string other)
{
	click_widget(row(window.history.paned.refs_list, from), 3);
	settle(300);

	var item = menu_item("Go to where it splits from");

	assert_nonnull(item);

	foreach (var child in ((Gtk.Menu)item.submenu).get_children())
	{
		if (((Gtk.MenuItem)child).label == other)
		{
			((Gtk.MenuItem)child).activate();
		}
	}

	((Gtk.Menu)item.get_parent()).popdown();
	settle(500);
}

private static void click_row(Gittree.Window window, int row, int count = 1)
{
	var view = window.history.paned.commit_list_view;
	Gdk.Rectangle cell;
	int x;
	int y;

	view.get_cell_area(new Gtk.TreePath.from_indices(row), view.get_column(0), out cell);
	view.get_bin_window().get_origin(out x, out y);

	click_at(x + cell.x + cell.width / 2, y + cell.y + cell.height / 2, count);
	settle(300);
}

private static Gtk.Widget close_button(Gtk.SearchBar bar, Gtk.Widget field)
{
	var row = field.get_ancestor(typeof(Gtk.ScrolledWindow));

	foreach (var widget in find_all(bar, typeof(Gtk.Button)))
	{
		if (!widget.is_ancestor(row) && widget.get_mapped())
		{
			return widget;
		}
	}

	error("no close button");
}

private static void commit_two_files(Repo repo, string subject) throws Error
{
	FileUtils.set_contents(repo.path.get_child("c").get_path(), subject + "\n");
	repo.commit_bytes(subject, "b", (subject + "\n").data);
}

private static bool details_shown(Gittree.Window window)
{
	return window.history.paned.box_details.get_mapped();
}

private static void drain()
{
	while (Gtk.events_pending())
	{
		Gtk.main_iteration();
	}
}

private static int label_x(Gittree.Window window, int row, string name)
{
	var view = window.history.paned.commit_list_view;
	var column = view.get_column(0);
	var width = column.get_width();
	var first = -1;
	var last = -1;
	Gtk.TreeIter iter;
	int hot_x;

	assert_true(view.model.iter_nth_child(out iter, null, row));
	column.cell_set_cell_data(view.model, iter, false, false);

	for (var x = 0; x < width; x++)
	{
		var label = window.history.paned.renderer_subject.get_ref_at_pos(view, x, width, out hot_x);

		if (label != null && label.parsed_name.shortname == name)
		{
			first = first < 0 ? x : first;
			last = x;
		}
	}

	assert_cmpint(first, CompareOperator.GE, 0);

	return (first + last) / 2;
}

private static string labels(Gittree.HistoryActivity activity, int row)
{
	return string.joinv(",", activity.labels_for(activity.rows()[row]));
}

private static uint lane_of(Gittree.Window window, string subject)
{
	foreach (var commit in window.history.rows())
	{
		if (commit.get_subject() == subject)
		{
			return commit.mylane;
		}
	}

	assert_not_reached();
}

private static void lift_hidden(Gittree.Window window)
{
	foreach (var widget in find_all(window.history.widget, typeof(Gtk.Button)))
	{
		if (((Gtk.Button)widget).label == "Show every commit" && widget.get_mapped())
		{
			((Gtk.Button)widget).clicked();
		}
	}

	settle(400);
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/history-activity/a-row-is-lit-only-once-the-user-picks-it", test_a_row_is_lit_only_once_the_user_picks_it);
	Test.add_func("/gittree/ui/history-activity/a-row-is-plain-again-under-a-theme-that-paints-the-selection", test_a_row_is_plain_again_under_a_theme_that_paints_the_selection);
	Test.add_func("/gittree/ui/history-activity/back-arrow-steps-back-from-the-full-diff", test_back_arrow_steps_back_from_the_full_diff);
	Test.add_func("/gittree/ui/history-activity/bottom-pane-is-hidden-at-the-start", test_bottom_pane_is_hidden_at_the_start);
	Test.add_func("/gittree/ui/history-activity/bottom-pane-spans-the-refs-panel-and-the-list", test_bottom_pane_spans_the_refs_panel_and_the_list);
	Test.add_func("/gittree/ui/history-activity/bytes-that-are-not-utf8-show-as-replacements", test_bytes_that_are_not_utf8_show_as_replacements);
	Test.add_func("/gittree/ui/history-activity/click-on-a-file-fills-the-window-and-escape-steps-back", test_click_on_a_file_fills_the_window_and_escape_steps_back);
	Test.add_func("/gittree/ui/history-activity/click-on-a-one-file-commit-shows-the-pane-and-enter-fills-the-window", test_click_on_a_one_file_commit_shows_the_pane_and_enter_fills_the_window);
	Test.add_func("/gittree/ui/history-activity/click-on-expand-all-fills-the-window", test_click_on_expand_all_fills_the_window);
	Test.add_func("/gittree/ui/history-activity/click-shows-the-pane-and-on-its-row-hides-it", test_click_shows_the_pane_and_on_its_row_hides_it);
	Test.add_func("/gittree/ui/history-activity/click-that-closes-a-file-keeps-the-refs-and-the-list", test_click_that_closes_a_file_keeps_the_refs_and_the_list);
	Test.add_func("/gittree/ui/history-activity/close-button-steps-back-from-the-full-diff", test_close_button_steps_back_from_the_full_diff);
	Test.add_func("/gittree/ui/history-activity/columns-are-subject-hash-author-and-date", test_columns_are_subject_hash_author_and_date);
	Test.add_func("/gittree/ui/history-activity/dates-use-gitgs-wording", test_dates_use_gitgs_wording);
	Test.add_func("/gittree/ui/history-activity/detached-head-label-comes-first", test_detached_head_label_comes_first);
	Test.add_func("/gittree/ui/history-activity/double-click-shows-and-hides-the-pane", test_double_click_shows_and_hides_the_pane);
	Test.add_func("/gittree/ui/history-activity/enter-shows-the-pane-at-the-middle-and-hides-it", test_enter_shows_the_pane_at_the_middle_and_hides_it);
	Test.add_func("/gittree/ui/history-activity/escape-closes-the-pane-then-the-search-bar", test_escape_closes_the_pane_then_the_search_bar);
	Test.add_func("/gittree/ui/history-activity/escape-closes-the-pane-when-nothing-has-the-focus", test_escape_closes_the_pane_when_nothing_has_the_focus);
	Test.add_func("/gittree/ui/history-activity/hash-column-shows-the-short-hash", test_hash_column_shows_the_short_hash);
	Test.add_func("/gittree/ui/history-activity/history-settings-keep-the-top-row", test_history_settings_keep_the_top_row);
	Test.add_func("/gittree/ui/history-activity/history-settings-redraw-the-list", test_history_settings_redraw_the_list);
	Test.add_func("/gittree/ui/history-activity/left-pane-is-never-cut-off", test_left_pane_is_never_cut_off);
	Test.add_func("/gittree/ui/history-activity/path-bar-and-path-notice", test_path_bar_and_path_notice);
	Test.add_func("/gittree/ui/history-activity/refs-filter-waits-for-enter", test_refs_filter_waits_for_enter);
	Test.add_func("/gittree/ui/history-activity/refs-that-cannot-be-read-leave-no-old-rows", test_refs_that_cannot_be_read_leave_no_old_rows);
	Test.add_func("/gittree/ui/history-activity/right-click-on-a-label-copies-its-name", test_right_click_on_a_label_copies_its_name);
	Test.add_func("/gittree/ui/history-activity/right-click-on-the-hash-copies-the-full-hash", test_right_click_on_the_hash_copies_the_full_hash);
	Test.add_func("/gittree/ui/history-activity/row-is-drawn-before-its-diff-is-built", test_row_is_drawn_before_its_diff_is_built);
	Test.add_func("/gittree/ui/history-activity/selection-is-kept-across-a-tick", test_selection_is_kept_across_a_tick);
	Test.add_func("/gittree/ui/history-activity/selection-with-the-pane-hidden-builds-no-diff", test_selection_with_the_pane_hidden_builds_no_diff);
	Test.add_func("/gittree/ui/history-activity/sidebar-layout", test_sidebar_layout);
	Test.add_func("/gittree/ui/history-activity/sidebar-position-is-kept", test_sidebar_position_is_kept);
	Test.add_func("/gittree/ui/history-activity/summary-counts-rows-of-commits", test_summary_counts_rows_of_commits);
	Test.add_func("/gittree/ui/history-activity/the-commit-menu-lists-the-branches-and-tags-with-it", test_the_commit_menu_lists_the_branches_and_tags_with_it);
	Test.add_func("/gittree/ui/history-activity/the-commit-menu-names-the-first-tag", test_the_commit_menu_names_the_first_tag);
	Test.add_func("/gittree/ui/history-activity/the-commit-menu-names-the-merge-that-brought-it-in", test_the_commit_menu_names_the_merge_that_brought_it_in);
	Test.add_func("/gittree/ui/history-activity/the-commit-menu-opens-on-every-column", test_the_commit_menu_opens_on_every_column);
	Test.add_func("/gittree/ui/history-activity/the-ref-menu-goes-to-where-two-refs-split", test_the_ref_menu_goes_to_where_two_refs_split);
	Test.add_func("/gittree/ui/history-activity/the-search-bars-meet-without-a-border", test_the_search_bars_meet_without_a_border);
	Test.add_func("/gittree/ui/history-activity/tick-at-the-very-top-stays-at-the-top", test_tick_at_the_very_top_stays_at_the_top);
	Test.add_func("/gittree/ui/history-activity/tick-keeps-the-top-row-in-place", test_tick_keeps_the_top_row_in_place);
	Test.add_func("/gittree/ui/history-activity/ticks-given-at-the-start-are-not-kept", test_ticks_given_at_the_start_are_not_kept);
	Test.add_func("/gittree/ui/history-activity/two-quick-ticks-keep-the-top-row", test_two_quick_ticks_keep_the_top_row);
	Test.add_func("/gittree/ui/history-activity/two-refs-that-share-no-commit-say-so", test_two_refs_that_share_no_commit_say_so);
	Test.add_func("/gittree/ui/history-activity/untick-of-the-top-row-puts-the-next-shown-row-at-the-top", test_untick_of_the_top_row_puts_the_next_shown_row_at_the_top);
	Test.add_func("/gittree/ui/history-activity/where-two-refs-split-can-be-hidden-by-the-filter", test_where_two_refs_split_can_be_hidden_by_the_filter);
	Test.add_func("/gittree/ui/history-activity/window-jump-shows-the-tip-in-a-scrolled-list", test_window_jump_shows_the_tip_in_a_scrolled_list);
	Test.add_func("/gittree/ui/history-activity/window-jump-ticks-an-unticked-ref-and-selects-its-tip", test_window_jump_ticks_an_unticked_ref_and_selects_its_tip);
	Test.add_func("/gittree/ui/history-activity/window-labels-only-ticked-refs", test_window_labels_only_ticked_refs);
	Test.add_func("/gittree/ui/history-activity/window-with-nothing-ticked-shows-the-empty-notice", test_window_with_nothing_ticked_shows_the_empty_notice);

	return Test.run();
}

private static Gtk.Border line(Gtk.Widget close)
{
	var box = ((Gtk.Bin)close.get_ancestor(typeof(Gtk.Revealer))).get_child();

	return box.get_style_context().get_border(box.get_state_flags());
}

private static bool only_details_shown(Gittree.Window window)
{
	return details_shown(window) && !window.history.paned.commit_list_view.get_mapped() && !window.history.paned.refs_list.get_mapped();
}

private static Gittree.Window opened(Repo repo, string[] ticked, string[] paths = {}) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gittree.Window(application());
	window.open_repository(Gittree.Application.discover_repository(repo.path), ticks, paths, repo.path);
	window.show();
	drain();

	return window;
}

private static Gee.List<string> painted(Gittree.Window window, out ulong handler)
{
	var tops = new Gee.ArrayList<string>();

	handler = window.history.paned.commit_list_view.get_frame_clock().after_paint.connect(() => {
		tops.add(top_row(window));
	});

	return tops;
}

private static void right_click(Gittree.Window window, int row, int column, int x)
{
	var view = window.history.paned.commit_list_view;
	Gdk.Rectangle cell;
	int origin_x;
	int origin_y;

	view.get_background_area(new Gtk.TreePath.from_indices(row), view.get_column(column), out cell);
	view.get_bin_window().get_origin(out origin_x, out origin_y);

	click_at(origin_x + cell.x + x, origin_y + cell.y + cell.height / 2, 1, 3);
	settle(300);
}

private static int row_of(Gittree.Window window, string subject)
{
	var rows = window.history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == subject)
		{
			return i;
		}
	}

	error("no row %s", subject);
}

private static string row_strip(Gittree.Window window, int row, int from, int to)
{
	var view = window.history.paned.commit_list_view;
	var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, view.get_allocated_width(), view.get_allocated_height());
	var text = new StringBuilder();
	Gdk.Rectangle area;
	int x;
	int y;

	view.draw(new Cairo.Context(surface));
	surface.flush();
	view.get_background_area(new Gtk.TreePath.from_indices(row), view.get_column(0), out area);
	view.convert_bin_window_to_widget_coords(area.x, area.y, out x, out y);

	var data = (uint8*)surface.get_data();

	for (var j = y; j < y + area.height; j++)
	{
		for (var i = x + from; i < x + to; i++)
		{
			text.append("%06x".printf(*(uint32*)(data + j * surface.get_stride() + i * 4) & 0xffffff));
		}
	}

	return text.str;
}

private static void settle(int milliseconds)
{
	for (var i = 0; i < milliseconds / 10; i++)
	{
		drain();
		Thread.usleep(10000);
	}
}

private static Repo side_branch() throws Error
{
	var repo = Repo.create();

	for (var i = 0; i < 50; i++)
	{
		repo.commit("base %d".printf(i));
	}

	repo.git({"checkout", "--quiet", "-b", "side"});

	for (var i = 0; i < 10; i++)
	{
		repo.commit("side %d".printf(i), "side");
	}

	repo.checkout("master");

	for (var i = 0; i < 10; i++)
	{
		repo.commit("tail %d".printf(i));
	}

	repo.git({"checkout", "--quiet", "-b", "newer"});

	for (var i = 0; i < 3; i++)
	{
		repo.commit("newer %d".printf(i), "newer");
	}

	repo.checkout("master");

	return repo;
}

private static string subjects_of(Gittree.Window window)
{
	var names = new string[0];

	foreach (var commit in window.history.rows())
	{
		names += commit.get_subject();
	}

	return string.joinv(",", names);
}

private static void test_a_row_is_lit_only_once_the_user_picks_it()
{
	try
	{
		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");
		commit_two_files(repo, "third");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		settle(300);

		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "");

		click_row(window, 1);

		assert_true(details_shown(window));
		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "second");

		click_row(window, 1);

		assert_false(details_shown(window));
		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "");

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Down, 0);
		settle(100);

		assert_false(details_shown(window));
		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "first");

		window.history.paned.details_visible = true;
		settle(100);
		window.history.escape();
		settle(100);

		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "");

		window.history.jump("refs/heads/master");
		settle(100);

		assert_false(details_shown(window));
		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "third");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_row_is_plain_again_under_a_theme_that_paints_the_selection()
{
	try
	{
		var theme = new Gtk.CssProvider();
		var screen = Gdk.Screen.get_default();

		theme.load_from_data(".cell:selected { background-image: linear-gradient(#ff0000, #ff0000); }");
		Gtk.StyleContext.add_provider_for_screen(screen, theme, Gtk.STYLE_PROVIDER_PRIORITY_THEME);

		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");

		var window = opened(repo, {"refs/heads/master"});

		settle(300);
		click_row(window, 1);

		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "first");

		click_row(window, 1);

		assert_false(details_shown(window));
		assert_cmpstr(lit_rows(window), CompareOperator.EQ, "");

		var middle = label_x(window, 0, "master");

		click_row(window, 0);
		click_row(window, 0);

		var unlit = row_strip(window, 0, middle - 8, middle + 8);

		click_row(window, 1);

		assert_cmpstr(row_strip(window, 0, middle - 8, middle + 8), CompareOperator.EQ, unlit);

		window.destroy();
		repo.remove();
		Gtk.StyleContext.remove_provider_for_screen(screen, theme);
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_back_arrow_steps_back_from_the_full_diff()
{
	try
	{
		var repo = two_files();
		var window = opened(repo, {"refs/heads/master"});
		Gtk.Button? back = null;

		foreach (var widget in find_all(window, typeof(Gtk.Button)))
		{
			if (((Gtk.Button)widget).action_name == "win.dash")
			{
				back = (Gtk.Button)widget;
			}
		}

		var tooltip = back.tooltip_text;

		click_row(window, 0);
		click_widget(label_with(window.history.diff_view, "b"));
		settle(300);

		assert_true(only_details_shown(window));
		assert_cmpstr(back.tooltip_text, CompareOperator.EQ, "Show the refs and the list");

		window.activate_action("dash", null);
		settle(100);

		assert_true(details_shown(window));
		assert_true(window.history.paned.commit_list_view.get_mapped());
		assert_nonnull(window.repository);
		assert_cmpstr(back.tooltip_text, CompareOperator.EQ, tooltip);

		window.activate_action("dash", null);
		settle(100);

		assert_null(window.repository);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_bottom_pane_is_hidden_at_the_start()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var window = opened(repo, {"refs/heads/master"});
		var panels = window.history.paned.paned_panels;

		assert_false(details_shown(window));
		assert_cmpint(panels.get_allocated_height(), CompareOperator.GT, 300);
		assert_cmpint(window.history.paned.stack_list.get_allocated_height(), CompareOperator.GE, panels.get_allocated_height() - 2);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_bottom_pane_spans_the_refs_panel_and_the_list()
{
	try
	{
		var repo = two_files();

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;
		var refs = window.history.paned.refs_list.get_ancestor(typeof(Gtk.ScrolledWindow));
		var list = window.history.paned.stack_list;
		var pane = window.history.paned.box_details;

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		assert_true(details_shown(window));

		int refs_x;
		int refs_y;
		int list_x;
		int list_y;
		int pane_x;
		int pane_y;
		refs.translate_coordinates(window, 0, 0, out refs_x, out refs_y);
		list.translate_coordinates(window, 0, 0, out list_x, out list_y);
		pane.translate_coordinates(window, 0, 0, out pane_x, out pane_y);

		assert_cmpint(pane_x, CompareOperator.EQ, refs_x);
		assert_cmpint(pane_x + pane.get_allocated_width(), CompareOperator.EQ, list_x + list.get_allocated_width());
		assert_cmpint(pane_y, CompareOperator.GE, refs_y + refs.get_allocated_height());
		assert_cmpint(pane_y, CompareOperator.GE, list_y + list.get_allocated_height());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_bytes_that_are_not_utf8_show_as_replacements()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var message = repo.path.get_parent().get_child(repo.path.get_basename() + "-message");
		message.replace_contents("caf\xe9 au lait\n".data, null, false, FileCreateFlags.NONE, null);
		repo.git({"-c", "user.name=Fran\xe7ois", "commit", "--quiet", "--allow-empty", "-F", message.get_path()});

		var window = opened(repo, {"refs/heads/master"});
		var model = window.history.paned.commit_list_view.model;
		Gtk.TreeIter iter;

		assert_true(model.get_iter_first(out iter));

		Value subject;
		Value author;
		model.get_value(iter, Gitg.CommitModelColumns.SUBJECT, out subject);
		model.get_value(iter, Gitg.CommitModelColumns.AUTHOR_NAME, out author);

		assert_true(subject.get_string().validate());
		assert_true(author.get_string().validate());
		assert_true(subject.get_string().has_prefix("caf"));
		assert_true(subject.get_string().has_suffix(" au lait"));

		window.destroy();
		message.delete();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_click_on_a_file_fills_the_window_and_escape_steps_back()
{
	try
	{
		var repo = two_files();
		var settings = new Settings(Gittree.Config.APPLICATION_ID + ".preferences.interface");

		foreach (var orientation in new string[] { "vertical", "horizontal" })
		{
			settings.set_string("orientation", orientation);

			var window = opened(repo, {"refs/heads/master"});
			var paned = window.history.paned;

			click_row(window, 0);
			click_widget(label_with(window.history.diff_view, "two files"));
			settle(300);

			assert_true(details_shown(window));
			assert_false(only_details_shown(window));

			var name = label_with(window.history.diff_view, "b");

			click_widget(name);
			settle(300);

			assert_true(only_details_shown(window));
			assert_true(((Gtk.Expander)name.get_ancestor(typeof(Gtk.Expander))).expanded);
			assert_cmpint(paned.box_details.get_allocated_width(), CompareOperator.EQ, paned.get_allocated_width());
			assert_cmpint(paned.box_details.get_allocated_height(), CompareOperator.EQ, paned.get_allocated_height());

			press_key("Escape");
			settle(100);

			assert_true(details_shown(window));
			assert_true(paned.commit_list_view.get_mapped());
			assert_true(paned.refs_list.get_mapped());

			press_key("Escape");
			settle(100);

			assert_false(details_shown(window));

			window.destroy();
		}

		settings.reset("orientation");
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_click_on_a_one_file_commit_shows_the_pane_and_enter_fills_the_window()
{
	try
	{
		var repo = two_files();
		repo.commit("one file", "b", "more");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		click_row(window, 0);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "one file");
		assert_true(details_shown(window));
		assert_false(only_details_shown(window));

		click_row(window, 1);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "two files");
		assert_true(details_shown(window));
		assert_false(only_details_shown(window));

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Up, 0);
		settle(300);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "one file");
		assert_false(only_details_shown(window));

		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		assert_false(details_shown(window));

		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(300);

		assert_true(only_details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_click_on_expand_all_fills_the_window()
{
	try
	{
		var repo = two_files();
		var window = opened(repo, {"refs/heads/master"});

		click_row(window, 0);
		click_widget(label_with(window.history.diff_view, "Expand all"));
		settle(300);

		assert_true(only_details_shown(window));
		assert_true(((Gtk.Expander)label_with(window.history.diff_view, "c").get_ancestor(typeof(Gtk.Expander))).expanded);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_click_shows_the_pane_and_on_its_row_hides_it()
{
	try
	{
		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");
		commit_two_files(repo, "third");

		var window = opened(repo, {"refs/heads/master"});

		click_row(window, 0);
		assert_true(details_shown(window));

		click_row(window, 0);
		assert_false(details_shown(window));

		click_row(window, 1);
		assert_true(details_shown(window));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "second");

		click_row(window, 2);
		assert_true(details_shown(window));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "first");

		click_row(window, 2);
		assert_false(details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_click_that_closes_a_file_keeps_the_refs_and_the_list()
{
	try
	{
		var repo = two_files();
		repo.commit("one file", "b", "more");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		click_row(window, 1);
		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Up, 0);
		settle(300);

		var name = label_with(window.history.diff_view, "b");
		var expander = (Gtk.Expander)name.get_ancestor(typeof(Gtk.Expander));

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "one file");
		assert_true(expander.expanded);
		assert_false(only_details_shown(window));

		click_widget(name);
		settle(300);

		assert_false(expander.expanded);
		assert_true(details_shown(window));
		assert_false(only_details_shown(window));

		click_widget(name);
		settle(300);

		assert_true(expander.expanded);
		assert_true(only_details_shown(window));

		press_key("Escape");
		settle(100);
		Gtk.test_widget_send_key(view, Gdk.Key.Down, 0);
		settle(300);
		click_widget(label_with(window.history.diff_view, "Expand all"));
		settle(300);

		assert_true(only_details_shown(window));

		press_key("Escape");
		settle(100);
		click_widget(label_with(window.history.diff_view, "Collapse all"));
		settle(300);

		assert_false(((Gtk.Expander)label_with(window.history.diff_view, "c").get_ancestor(typeof(Gtk.Expander))).expanded);
		assert_true(details_shown(window));
		assert_false(only_details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_close_button_steps_back_from_the_full_diff()
{
	try
	{
		var repo = two_files();
		var window = opened(repo, {"refs/heads/master"});
		var paned = window.history.paned;
		Gtk.Button? close = null;

		foreach (var widget in find_all(paned.box_details, typeof(Gtk.Button)))
		{
			if (((Gtk.Button)widget).tooltip_text == "Show the refs and the list (Escape)")
			{
				close = (Gtk.Button)widget;
			}
		}

		assert_nonnull(close);

		click_row(window, 0);

		assert_true(details_shown(window));
		assert_false(close.get_mapped());

		click_widget(label_with(window.history.diff_view, "b"));
		settle(300);

		assert_true(only_details_shown(window));
		assert_true(close.get_mapped());

		click_widget(close);
		settle(100);

		assert_true(details_shown(window));
		assert_true(paned.commit_list_view.get_mapped());
		assert_true(paned.refs_list.get_mapped());
		assert_false(close.get_mapped());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_columns_are_subject_hash_author_and_date()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var window = opened(repo, {"refs/heads/master"});
		var titles = new string[0];

		foreach (var column in window.history.paned.commit_list_view.get_columns())
		{
			titles += column.title;
		}

		assert_cmpstr(string.joinv(",", titles), CompareOperator.EQ, "Subject,Hash,Author,Date");
		assert_false(window.history.paned.commit_list_view.headers_visible);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_dates_use_gitgs_wording()
{
	try
	{
		var repo = Repo.create();
		var now = "@%lld +0000".printf(new DateTime.now_utc().to_unix());
		var env = Environ.set_variable(Environ.get(), "GIT_AUTHOR_DATE", now, true);
		env = Environ.set_variable(env, "GIT_COMMITTER_DATE", now, true);
		env = Environ.set_variable(env, "GIT_CONFIG_GLOBAL", "/dev/null", true);

		string[] argv = { "git", "-C", repo.path.get_path(), "-c", "user.name=T", "-c", "user.email=t@e", "commit", "--quiet", "--allow-empty", "-m", "just now" };
		Process.spawn_sync(null, argv, env, SpawnFlags.SEARCH_PATH, null, null, null, null);

		var window = opened(repo, {"refs/heads/master"});
		var model = window.history.paned.commit_list_view.model;
		Gtk.TreeIter iter;
		Value date;

		assert_true(model.get_iter_first(out iter));
		model.get_value(iter, Gitg.CommitModelColumns.AUTHOR_DATE, out date);

		assert_cmpstr(date.get_string(), CompareOperator.EQ, "Now");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_detached_head_label_comes_first()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.git({"checkout", "--quiet", "--detach", "master"});

		var window = opened(repo, {"HEAD", "refs/heads/master"});

		assert_cmpstr(labels(window.history, 0), CompareOperator.EQ, "HEAD,master");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_double_click_shows_and_hides_the_pane()
{
	try
	{
		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");

		var window = opened(repo, {"refs/heads/master"});

		click_row(window, 0);
		assert_true(details_shown(window));

		click_row(window, 1, 2);
		assert_false(details_shown(window));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "first");

		click_row(window, 1, 2);
		assert_false(details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_enter_shows_the_pane_at_the_middle_and_hides_it()
{
	try
	{
		var repo = two_files();

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;
		var panels = window.history.paned.paned_panels;

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		assert_true(details_shown(window));
		assert_cmpint((panels.position - panels.get_allocated_height() / 2).abs(), CompareOperator.LE, 4);

		panels.position = 100;
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		assert_false(details_shown(window));

		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		assert_true(details_shown(window));
		assert_cmpint((panels.position - panels.get_allocated_height() / 2).abs(), CompareOperator.LE, 4);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_closes_the_pane_then_the_search_bar()
{
	try
	{
		var repo = two_files();

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(100);

		window.history.search_visible = true;
		view.grab_focus();
		settle(50);

		Gtk.test_widget_send_key(view, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(details_shown(window));
		assert_true(window.history.search_visible);

		Gtk.test_widget_send_key(view, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(window.history.search_visible);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_closes_the_pane_when_nothing_has_the_focus()
{
	try
	{
		var repo = two_files();

		var window = opened(repo, {"refs/heads/master"});

		click_row(window, 0);
		window.history.paned.paned_panels.position = 0;
		settle(100);

		assert_true(details_shown(window));
		assert_null(window.get_focus());

		press_key("Escape");
		settle(100);

		assert_false(details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_hash_column_shows_the_short_hash()
{
	try
	{
		var repo = Repo.create();
		var sha = repo.commit("first");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;
		var column = view.get_column(1);
		var cell = (Gtk.CellRendererText)column.get_cells().data;
		Gtk.TreeIter iter;

		assert_true(view.model.get_iter_first(out iter));
		column.cell_set_cell_data(view.model, iter, false, false);

		assert_cmpstr(cell.text, CompareOperator.EQ, sha.substring(0, 7));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_history_settings_keep_the_top_row()
{
	try
	{
		var repo = side_branch();
		var settings = new Settings(Gittree.Config.APPLICATION_ID + ".preferences.history");
		var window = opened(repo, {"refs/heads/master"});

		scroll_to_row(window, "base 30", 10);
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");

		settings.set_boolean("mainline-head", false);
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");

		settings.set_boolean("topological-order", true);
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");

		settings.reset("mainline-head");
		settings.reset("topological-order");
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_history_settings_redraw_the_list()
{
	try
	{
		var repo = Repo.create();
		repo.commit("base");
		repo.commit("master one");
		repo.git({"checkout", "--quiet", "-b", "side", "master~1"});
		repo.commit("side one", "side");
		repo.commit("side two", "side");
		repo.checkout("master");
		repo.commit("master two");
		repo.checkout("side");

		var settings = new Settings(Gittree.Config.APPLICATION_ID + ".preferences.history");
		var window = opened(repo, {"refs/heads/master", "refs/heads/side"});
		var by_time = subjects_of(window);

		assert_cmpstr(by_time, CompareOperator.EQ, "master two,side two,side one,master one,base");
		assert_cmpuint(lane_of(window, "side two"), CompareOperator.EQ, 0);

		settings.set_boolean("mainline-head", false);
		drain();
		assert_cmpuint(lane_of(window, "side two"), CompareOperator.EQ, 1);

		settings.set_boolean("topological-order", true);
		drain();
		assert_cmpstr(subjects_of(window), CompareOperator.NE, by_time);

		settings.reset("mainline-head");
		settings.reset("topological-order");
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_left_pane_is_never_cut_off()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		window.history.paned.paned_sidebar.position = 40;

		for (var i = 0; i < 20; i++)
		{
			drain();
			Thread.usleep(10000);
		}

		int x;
		int y;
		window.history.paned.filter.translate_coordinates(window, 0, 0, out x, out y);

		assert_cmpint(x, CompareOperator.GE, 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_path_bar_and_path_notice()
{
	try
	{
		var repo = Repo.create();
		repo.commit("a one", "a");
		repo.git({"checkout", "--quiet", "--orphan", "lonely"});
		repo.git({"rm", "--quiet", "-rf", "."});
		repo.commit("b only", "b");
		repo.checkout("master");

		var window = opened(repo, {"refs/heads/lonely"}, {"a", "b c"});

		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change a, b c");

		window.destroy();

		window = opened(repo, {"refs/heads/lonely"}, {"a"});

		for (var i = 0; i < 300 && window.history.notice_text.has_prefix("Reading"); i++)
		{
			drain();
			Thread.usleep(10000);
		}

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(window.history.notice_text, CompareOperator.EQ, "No ticked ref reaches a commit that changes a.");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_refs_filter_waits_for_enter()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var window = opened(repo, {"refs/heads/master"});
		var filter = window.history.paned.filter;
		var master = row(window.history.paned.refs_list, "master");

		filter.text = "zzz";
		settle(400);

		assert_true(master.get_child_visible());

		filter.activate();
		settle(400);

		assert_false(master.get_child_visible());

		filter.text = "";
		settle(400);

		assert_false(master.get_child_visible());

		filter.activate();
		settle(400);

		assert_true(master.get_child_visible());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_refs_that_cannot_be_read_leave_no_old_rows()
{
	try
	{
		var first = Repo.create();
		first.branched();

		var broken = Repo.create();
		broken.commit("first");
		broken.branch("other");
		broken.git({"pack-refs", "--all"});
		FileUtils.set_contents(broken.path.get_child(".git").get_child("packed-refs").get_path(), "garbage\n");

		var window = opened(first, {"refs/heads/master"});
		window.open_repository(Gittree.Application.discover_repository(broken.path));
		drain();

		assert_cmpint(window.history.rows().length, CompareOperator.EQ, 0);
		assert_true(window.error_shown);

		window.destroy();
		first.remove();
		broken.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_right_click_on_a_label_copies_its_name()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.branch("feature/scan");

		var window = opened(repo, {"refs/heads/master", "refs/heads/feature/scan"});
		var clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD);
		var width = window.history.paned.commit_list_view.get_column(0).get_width();

		right_click(window, 0, 0, width - 10);
		assert_cmpstr(copy_item().label, CompareOperator.EQ, "Copy hash");
		((Gtk.Menu)copy_item().get_parent()).popdown();
		settle(100);

		right_click(window, 0, 0, label_x(window, 0, "feature/scan"));

		var item = copy_item();
		assert_nonnull(item);
		assert_cmpstr(item.label, CompareOperator.EQ, "Copy name");

		item.activate();
		((Gtk.Menu)item.get_parent()).popdown();
		settle(100);

		assert_cmpstr(clipboard.wait_for_text(), CompareOperator.EQ, "feature/scan");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_right_click_on_the_hash_copies_the_full_hash()
{
	try
	{
		var repo = Repo.create();
		var sha = repo.commit("first");
		repo.commit("second");

		var window = opened(repo, {"refs/heads/master"});
		var clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD);
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "second");

		right_click(window, 1, 1, 20);

		var item = copy_item();
		assert_nonnull(item);
		assert_cmpstr(item.label, CompareOperator.EQ, "Copy hash");

		item.activate();
		((Gtk.Menu)item.get_parent()).popdown();
		settle(100);

		assert_cmpstr(clipboard.wait_for_text(), CompareOperator.EQ, sha);
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "second");
		assert_false(details_shown(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_row_is_drawn_before_its_diff_is_built()
{
	try
	{
		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(300);

		assert_true(details_shown(window));
		assert_cmpstr(window.history.diff_view.commit.get_subject(), CompareOperator.EQ, "second");

		string? shown_at_draw = null;

		view.draw.connect_after(() => {
			if (shown_at_draw == null)
			{
				shown_at_draw = window.history.diff_view.commit.get_subject();
			}

			return false;
		});

		view.set_cursor(new Gtk.TreePath.from_indices(1), null, false);
		settle(300);

		assert_cmpstr(shown_at_draw, CompareOperator.EQ, "second");
		assert_cmpstr(window.history.diff_view.commit.get_subject(), CompareOperator.EQ, "first");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_selection_is_kept_across_a_tick()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		var activity = window.history;

		activity.jump("refs/heads/fix/stamp");
		assert_cmpstr(activity.selected.get_subject(), CompareOperator.EQ, "fix two");

		var ticks = activity.ticks;
		ticks.add("refs/heads/feature/scan");
		activity.set_ticks(ticks);
		assert_cmpstr(activity.selected.get_subject(), CompareOperator.EQ, "fix two");

		activity.jump("refs/heads/feature/scan");
		assert_cmpstr(activity.selected.get_subject(), CompareOperator.EQ, "feature one");

		ticks = activity.ticks;
		ticks.remove("refs/heads/feature/scan");
		activity.set_ticks(ticks);
		assert_cmpstr(activity.selected.get_subject(), CompareOperator.EQ, "master four");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_selection_with_the_pane_hidden_builds_no_diff()
{
	try
	{
		var repo = Repo.create();
		commit_two_files(repo, "first");
		commit_two_files(repo, "second");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;

		view.set_cursor(new Gtk.TreePath.from_indices(1), null, false);
		settle(300);

		assert_false(details_shown(window));
		assert_null(window.history.diff_view.commit);

		view.grab_focus();
		Gtk.test_widget_send_key(view, Gdk.Key.Return, 0);
		settle(300);

		assert_true(details_shown(window));
		assert_cmpstr(window.history.diff_view.commit.get_subject(), CompareOperator.EQ, "first");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_sidebar_layout()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var window = opened(repo, {"refs/heads/master"});
		var sidebar = (Gtk.Box)window.history.paned.paned_sidebar.get_child1();
		var kinds = new string[0];

		foreach (var child in sidebar.get_children())
		{
			kinds += child.get_type().name();
		}

		assert_cmpstr(string.joinv(",", kinds), CompareOperator.EQ, "GtkBox,GtkSeparator,GtkScrolledWindow,GtkSeparator,GtkLabel");

		var controls = ((Gtk.Box)sidebar.get_children().nth_data(0)).get_children();
		var buttons = ((Gtk.Box)controls.nth_data(1)).get_children();

		assert_true(controls.nth_data(0) is Gtk.SearchEntry);
		assert_cmpstr(((Gtk.Button)buttons.nth_data(0)).label, CompareOperator.EQ, "All");
		assert_cmpstr(((Gtk.Button)buttons.nth_data(1)).label, CompareOperator.EQ, "None");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_sidebar_position_is_kept()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var settings = new Settings(Gittree.Config.APPLICATION_ID + ".state.history");
		settings.set_int("paned-sidebar-position", 231);

		var window = opened(repo, {"refs/heads/master"});

		assert_cmpint(window.history.paned.paned_sidebar.position, CompareOperator.EQ, 231);

		window.history.paned.paned_sidebar.position = 250;
		assert_cmpint(settings.get_int("paned-sidebar-position"), CompareOperator.EQ, 250);

		settings.reset("paned-sidebar-position");
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_summary_counts_rows_of_commits()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/feature/scan"});

		assert_cmpstr(window.history.summary_text, CompareOperator.EQ, "Showing 3 of 8 commits");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_commit_menu_lists_the_branches_and_tags_with_it()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		right_click(window, row_of(window, "base one"), 1, 10);

		var item = menu_item("Branches and tags with this commit");

		assert_nonnull(item);
		assert_cmpstr(submenu_labels(item), CompareOperator.EQ, "feature/scan,fix/stamp,*master,origin/master,v1");

		foreach (var child in ((Gtk.Menu)item.submenu).get_children())
		{
			if (((Gtk.MenuItem)child).label == "fix/stamp")
			{
				((Gtk.MenuItem)child).activate();
			}
		}

		((Gtk.Menu)item.get_parent()).popdown();
		settle(300);

		assert_true(window.history.ticks.contains("refs/heads/fix/stamp"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_commit_menu_names_the_first_tag()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		right_click(window, row_of(window, "base one"), 1, 10);
		settle(500);

		var item = menu_item_starting("First tag with this commit");

		assert_cmpstr(item.label, CompareOperator.EQ, "First tag with this commit: v1");
		assert_true(item.sensitive);

		item.activate();
		((Gtk.Menu)item.get_parent()).popdown();
		settle(300);

		assert_true(window.history.ticks.contains("refs/tags/v1"));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "base two");

		right_click(window, row_of(window, "master four"), 1, 10);
		settle(500);
		item = menu_item_starting("No tag holds");

		assert_cmpstr(item.label, CompareOperator.EQ, "No tag holds this commit yet");
		assert_false(item.sensitive);

		((Gtk.Menu)item.get_parent()).popdown();
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_commit_menu_names_the_merge_that_brought_it_in()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master", "refs/heads/fix/stamp", "refs/heads/feature/scan"});
		var merge = repo.git({"rev-parse", "--short", "master~1"}).strip();

		right_click(window, row_of(window, "fix one"), 1, 10);
		settle(500);

		var item = menu_item_starting("Merged into");

		assert_cmpstr(item.label, CompareOperator.EQ, "Merged into master by %s".printf(merge));

		item.activate();
		((Gtk.Menu)item.get_parent()).popdown();
		settle(300);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");

		right_click(window, row_of(window, "master three"), 1, 10);
		settle(500);
		item = menu_item_starting("Made on");

		assert_cmpstr(item.label, CompareOperator.EQ, "Made on master");
		assert_false(item.sensitive);

		((Gtk.Menu)item.get_parent()).popdown();
		settle(100);
		right_click(window, row_of(window, "feature one"), 1, 10);
		settle(500);

		assert_null(menu_item_starting("Merged into"));
		assert_null(menu_item_starting("Made on"));

		((Gtk.Menu)copy_item().get_parent()).popdown();
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_commit_menu_opens_on_every_column()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.commit("second");

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;
		int width;
		int height;

		window.get_size(out width, out height);
		window.resize(1200, 800);
		settle(300);

		for (var column = 0; column < (int)view.get_n_columns(); column++)
		{
			right_click(window, 1, column, 10);

			var item = copy_item();

			assert_nonnull(item);
			assert_cmpstr(item.label, CompareOperator.EQ, "Copy hash");
			assert_nonnull(menu_item("Branches and tags with this commit"));

			((Gtk.Menu)item.get_parent()).popdown();
			settle(100);
		}

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "second");

		window.resize(width, height);
		settle(300);
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_ref_menu_goes_to_where_two_refs_split()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master", "refs/heads/feature/scan", "refs/heads/fix/stamp", "refs/remotes/origin/master"});
		var expected = new string[0];

		foreach (var child in window.history.paned.refs_list.get_children())
		{
			var candidate = child as Gittree.RefsRow;

			if (candidate != null && candidate.ticked && candidate.reference.short_name != "feature/scan")
			{
				expected += candidate.reference.short_name;
			}
		}

		click_widget(row(window.history.paned.refs_list, "feature/scan"), 3);
		settle(300);

		var item = menu_item("Go to where it splits from");

		assert_nonnull(item);
		assert_cmpstr(submenu_labels(item), CompareOperator.EQ, string.joinv(",", expected));
		assert_true("master" in expected);
		assert_false("v1" in expected);

		((Gtk.Menu)item.get_parent()).popdown();
		settle(100);
		choose_split(window, "feature/scan", "master");

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "base two");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_search_bars_meet_without_a_border()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.commit("second");

		var window = opened(repo, {"refs/heads/master"});
		var history = window.history;
		var list_bar = (Gtk.SearchBar)history.search_field.get_ancestor(typeof(Gtk.SearchBar));
		int bar_y;
		int close_y;
		int x;

		history.search_visible = true;
		history.paned.details_visible = true;
		settle(300);
		history.paned.details_only = true;
		history.find_bar.search_mode_enabled = true;
		settle(600);

		var close = close_button(list_bar, history.search_field);

		list_bar.translate_coordinates(window, 0, 0, out x, out bar_y);
		close.translate_coordinates(window, 0, 0, out x, out close_y);

		assert_cmpint(close_y + close.get_allocated_height() + line(close).bottom, CompareOperator.EQ, bar_y + list_bar.get_allocated_height());

		close = close_button(history.find_bar, history.find_bar.field);

		history.find_bar.translate_coordinates(window, 0, 0, out x, out bar_y);
		close.translate_coordinates(window, 0, 0, out x, out close_y);

		assert_cmpint(close_y, CompareOperator.EQ, bar_y + line(close).top);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_tick_at_the_very_top_stays_at_the_top()
{
	try
	{
		var repo = side_branch();
		var window = opened(repo, {"refs/heads/master"});

		assert_cmpstr(top_row(window), CompareOperator.EQ, "tail 9 0");

		check_of(window, "newer").clicked();
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "newer 2 0");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_tick_keeps_the_top_row_in_place()
{
	try
	{
		var repo = side_branch();
		var window = opened(repo, {"refs/heads/master"});

		scroll_to_row(window, "base 30", 10);
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");

		ulong handler;
		var tops = painted(window, out handler);

		check_of(window, "side").clicked();
		settle(100);
		window.history.paned.commit_list_view.get_frame_clock().disconnect(handler);

		assert_true(window.history.ticks.contains("refs/heads/side"));
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");
		assert_false(tops.is_empty);

		foreach (var top in tops)
		{
			assert_cmpstr(top, CompareOperator.EQ, "base 30 -10");
		}

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticks_given_at_the_start_are_not_kept()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var first = opened(repo, {"refs/heads/fix/stamp", "refs/tags/v1"});
		first.close();
		drain();

		assert_false(ticks_file(repo).query_exists());

		var second = new Gittree.Window(application());
		second.open_repository(Gittree.Application.discover_repository(repo.path));
		second.show();
		drain();

		var ticked = new Gee.ArrayList<string>();
		ticked.add_all(second.history.ticks);
		ticked.sort();

		assert_cmpstr(string.joinv(",", ticked.to_array()), CompareOperator.EQ, "refs/heads/feature/scan,refs/heads/fix/stamp,refs/heads/master,refs/remotes/origin/master,refs/tags/v1");

		second.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_two_quick_ticks_keep_the_top_row()
{
	try
	{
		var repo = side_branch();
		var window = opened(repo, {"refs/heads/master"});

		scroll_to_row(window, "base 30", 10);
		settle(100);

		check_of(window, "side").clicked();
		check_of(window, "newer").clicked();
		settle(100);

		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 30 -10");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_two_refs_that_share_no_commit_say_so()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.git({"checkout", "--quiet", "--orphan", "lonely"});
		repo.git({"rm", "--quiet", "-rf", "."});
		repo.commit("alone", "other");
		repo.checkout("master");

		var window = opened(repo, {"refs/heads/master", "refs/heads/lonely"});

		choose_split(window, "lonely", "master");

		assert_cmpstr(window.history.hidden_text, CompareOperator.EQ, "lonely and master share no commit.");

		foreach (var widget in find_all(window.history.widget, typeof(Gtk.Button)))
		{
			if (((Gtk.Button)widget).label == "Show every commit")
			{
				assert_false(widget.get_mapped());
			}
		}

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_untick_of_the_top_row_puts_the_next_shown_row_at_the_top()
{
	try
	{
		var repo = side_branch();
		var window = opened(repo, {"refs/heads/master", "refs/heads/side"});

		scroll_to_row(window, "side 5", 10);
		settle(100);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "side 5 -10");

		ulong handler;
		var tops = painted(window, out handler);

		check_of(window, "side").clicked();
		settle(100);
		window.history.paned.commit_list_view.get_frame_clock().disconnect(handler);

		assert_false(window.history.ticks.contains("refs/heads/side"));
		assert_cmpstr(top_row(window), CompareOperator.EQ, "base 49 0");
		assert_false(tops.is_empty);

		foreach (var top in tops)
		{
			assert_cmpstr(top, CompareOperator.EQ, "base 49 0");
		}

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_where_two_refs_split_can_be_hidden_by_the_filter()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master", "refs/heads/feature/scan"});
		var base_two = repo.git({"rev-parse", "--short", "v1"}).strip();

		window.history.only_matches = true;
		window.history.apply_filter("fix", false);
		settle(800);
		choose_split(window, "feature/scan", "master");

		assert_cmpstr(window.history.hidden_text, CompareOperator.EQ, "%s is where they split. The search hides it.".printf(base_two));

		lift_hidden(window);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "base two");
		assert_false(window.history.only_matches);
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Marked: commits that add or remove fix");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_window_jump_shows_the_tip_in_a_scrolled_list()
{
	try
	{
		var repo = side_branch();
		var window = opened(repo, {"refs/heads/master"});

		scroll_to_row(window, "base 30", 10);
		settle(100);

		window.history.jump("refs/heads/newer");
		settle(100);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "newer 2");
		assert_cmpstr(top_row(window), CompareOperator.EQ, "newer 2 0");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_window_jump_ticks_an_unticked_ref_and_selects_its_tip()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		window.history.jump("refs/heads/feature/scan");

		assert_true(window.history.ticks.contains("refs/heads/feature/scan"));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "feature one");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_window_labels_only_ticked_refs()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		var activity = window.history;

		assert_cmpstr(labels(activity, 0), CompareOperator.EQ, "master");
		assert_cmpstr(labels(activity, 1), CompareOperator.EQ, "");

		var ticks = activity.ticks;
		ticks.add("refs/remotes/origin/master");
		activity.set_ticks(ticks);

		assert_cmpstr(labels(activity, 1), CompareOperator.EQ, "origin/master");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_window_with_nothing_ticked_shows_the_empty_notice()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		window.history.set_ticks(new Gee.HashSet<string>());

		assert_cmpint(window.history.rows().length, CompareOperator.EQ, 0);
		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(window.history.notice_text, CompareOperator.EQ, "Nothing is ticked. Tick a branch, a remote branch or a tag on the left.");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static File ticks_file(Repo repo)
{
	return repo.path.get_child(".git").get_child("git-tree-ticks");
}

private static Repo two_files() throws Error
{
	var repo = Repo.create();
	commit_two_files(repo, "two files");

	return repo;
}

}
