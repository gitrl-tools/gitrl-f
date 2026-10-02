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

private static Repo beyond_fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("base one");
	repo.branch("elsewhere");
	repo.commit("master only");
	repo.checkout("elsewhere");
	repo.commit("secret work", "secret");
	repo.git({"tag", "v9"});
	repo.git({"checkout", "--quiet", "--detach"});
	repo.commit("remote thing", "remote");
	repo.git({"update-ref", "refs/remotes/origin/thing", "HEAD"});
	repo.git({"tag", "t1"});
	repo.checkout("master");

	return repo;
}

private static Gtk.Button button(Gitrlf.Window window, string tooltip)
{
	foreach (var widget in find_all(window.history.widget, typeof(Gtk.Button)))
	{
		if (widget.tooltip_text == tooltip)
		{
			return (Gtk.Button)widget;
		}
	}

	error("no button %s", tooltip);
}

private static Gtk.Button button_labelled(Gtk.Widget root, string label)
{
	foreach (var widget in find_all(root, typeof(Gtk.Button)))
	{
		if (((Gtk.Button)widget).label == label)
		{
			return (Gtk.Button)widget;
		}
	}

	error("no button %s", label);
}

private static Repo four_subjects() throws Error
{
	var repo = Repo.create();

	repo.commit("Parser fix");
	repo.commit("parser tidy");
	repo.commit("prefix work");
	repo.commit("issue 42");

	return repo;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/search/a-bad-expression-turns-the-field-red", test_a_bad_expression_turns_the_field_red);
	Test.add_func("/gitrlf/ui/search/a-hash-on-an-unticked-ref-is-found", test_a_hash_on_an_unticked_ref_is_found);
	Test.add_func("/gitrlf/ui/search/a-match-on-an-unticked-ref-is-offered", test_a_match_on_an_unticked_ref_is_offered);
	Test.add_func("/gitrlf/ui/search/a-messages-search-makes-each-matching-row-bold", test_a_messages_search_makes_each_matching_row_bold);
	Test.add_func("/gitrlf/ui/search/a-messages-search-waits-for-enter", test_a_messages_search_waits_for_enter);
	Test.add_func("/gitrlf/ui/search/bar-opens-from-the-shortcut-and-the-toggle", test_bar_opens_from_the_shortcut_and_the_toggle);
	Test.add_func("/gitrlf/ui/search/closing-the-bar-lifts-the-search-and-keeps-the-text", test_closing_the_bar_lifts_the_search_and_keeps_the_text);
	Test.add_func("/gitrlf/ui/search/display-matches-only-and-a-changed-lines-search-both-hold", test_display_matches_only_and_a_changed_lines_search_both_hold);
	Test.add_func("/gitrlf/ui/search/escape-lifts-the-search-keeps-the-text-and-gives-the-focus-back", test_escape_lifts_the_search_keeps_the_text_and_gives_the_focus_back);
	Test.add_func("/gitrlf/ui/search/marks-show-in-the-subject-hash-and-author-columns", test_marks_show_in_the_subject_hash_and_author_columns);
	Test.add_func("/gitrlf/ui/search/next-and-previous-wrap-and-count", test_next_and_previous_wrap_and_count);
	Test.add_func("/gitrlf/ui/search/no-match-turns-the-field-red", test_no_match_turns_the_field_red);
	Test.add_func("/gitrlf/ui/search/only-matches-keeps-the-selection-out-of-the-list", test_only_matches_keeps_the_selection_out_of_the_list);
	Test.add_func("/gitrlf/ui/search/only-matches-narrows-with-each-search", test_only_matches_narrows_with_each_search);
	Test.add_func("/gitrlf/ui/search/only-matches-with-nothing-shows-a-notice", test_only_matches_with_nothing_shows_a_notice);
	Test.add_func("/gitrlf/ui/search/opening-again-selects-the-kept-text", test_opening_again_selects_the_kept_text);
	Test.add_func("/gitrlf/ui/search/search-words-narrow-the-list", test_search_words_narrow_the_list);
	Test.add_func("/gitrlf/ui/search/switches-keep-their-state-when-the-bar-closes", test_switches_keep_their_state_when_the_bar_closes);
	Test.add_func("/gitrlf/ui/search/switches-are-push-buttons", test_switches_are_push_buttons);
	Test.add_func("/gitrlf/ui/search/switches-narrow-the-matches", test_switches_narrow_the_matches);
	Test.add_func("/gitrlf/ui/search/switches-say-what-they-do", test_switches_say_what_they_do);
	Test.add_func("/gitrlf/ui/search/the-close-button-closes-the-bar-and-lifts-the-search", test_the_close_button_closes_the_bar_and_lifts_the_search);
	Test.add_func("/gitrlf/ui/search/the-count-stands-apart-from-the-switches", test_the_count_stands_apart_from_the_switches);
	Test.add_func("/gitrlf/ui/search/the-field-sits-at-the-centre-of-the-bar", test_the_field_sits_at_the_centre_of_the_bar);
	Test.add_func("/gitrlf/ui/search/the-field-stays-put-when-the-count-changes", test_the_field_stays_put_when_the_count_changes);
	Test.add_func("/gitrlf/ui/search/tick-and-show-prefers-heads-branch-then-remotes-then-tags", test_tick_and_show_prefers_heads_branch_then_remotes_then_tags);
	Test.add_func("/gitrlf/ui/search/tick-searches-again", test_tick_searches_again);
	Test.add_func("/gitrlf/ui/search/ticking-nothing-counts-no-match", test_ticking_nothing_counts_no_match);
	Test.add_func("/gitrlf/ui/search/two-clicks-on-a-switch-leave-it-as-it-was", test_two_clicks_on_a_switch_leave_it_as_it_was);
	Test.add_func("/gitrlf/ui/search/typing-moves-nothing", test_typing_moves_nothing);

	return Test.run();
}

private static int marked_pixels(Gitrlf.Window window, int index)
{
	var view = window.history.paned.commit_list_view;
	var column = view.get_column(index);
	var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, view.get_allocated_width(), view.get_allocated_height());
	var context = new Cairo.Context(surface);

	view.draw(context);
	surface.flush();

	var data = (uint8*)surface.get_data();
	var stride = surface.get_stride();
	var end = int.min(column.get_x_offset() + column.get_width(), surface.get_width());
	var count = 0;

	for (var y = 0; y < surface.get_height(); y++)
	{
		for (var x = column.get_x_offset(); x < end; x++)
		{
			var pixel = data + y * stride + x * 4;

			if (pixel[2] == 0xfc && pixel[1] == 0xe9 && pixel[0] == 0x4f)
			{
				count++;
			}
		}
	}

	return count;
}

private static Gitrlf.Window opened(Repo repo) throws Error
{
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/master");
	ticks.add("refs/heads/feature/scan");

	var window = new Gitrlf.Window(application());
	window.open_repository(Gitrlf.Application.discover_repository(repo.path), ticks, {}, repo.path);
	window.set_default_size(1000, 600);
	window.show();
	settle(100);

	return window;
}

private static Gitrlf.Window opened_with(Repo repo, string[] ticked) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gitrlf.Window(application());
	window.open_repository(Gitrlf.Application.discover_repository(repo.path), ticks, {}, repo.path);
	window.set_default_size(1000, 600);
	window.show();
	settle(100);

	return window;
}

private static void search_for(Gitrlf.Window window, string text)
{
	window.history.search_visible = true;
	window.history.search_field.text = text;
	window.history.search_field.activate();
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

private static string subjects(Gitrlf.Window window)
{
	var names = new string[0];

	foreach (var commit in window.history.rows())
	{
		names += commit.get_subject();
	}

	return string.joinv(",", names);
}

private static void test_a_bad_expression_turns_the_field_red()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		search_for(window, "(");
		toggle_labelled(list_bar(window), "Regex").active = true;
		settle(200);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Bad regex");
		assert_cmpstr(label_with(list_bar(window), "Bad regex").tooltip_text, CompareOperator.EQ, "Unmatched ( or \\(");
		assert_true(window.history.search_field.get_style_context().has_class("error"));
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_hash_on_an_unticked_ref_is_found()
{
	try
	{
		var repo = beyond_fixture();
		var window = opened_with(repo, {"refs/heads/master"});
		var hash = repo.git({"rev-parse", "--short", "v9"}).strip();

		search_for(window, hash);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match in the ticked refs. 1 in others");

		button_labelled(list_bar(window), "Tick and show").clicked();
		settle(300);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "secret work");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_match_on_an_unticked_ref_is_offered()
{
	try
	{
		var repo = beyond_fixture();
		var window = opened_with(repo, {"refs/heads/master"});
		var button = button_labelled(list_bar(window), "Tick and show");

		assert_false(button.get_visible());

		search_for(window, "secret");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match in the ticked refs. 1 in others");
		assert_true(button.get_visible());
		assert_cmpstr(button.tooltip_text, CompareOperator.EQ, "Tick a ref that holds the newest of them, and select it");

		button.clicked();
		settle(300);

		assert_true(window.history.ticks.contains("refs/heads/elsewhere"));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "secret work");
		assert_false(button.get_visible());

		search_for(window, "zzz");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");
		assert_false(button.get_visible());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_messages_search_makes_each_matching_row_bold()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var paned = window.history.paned;
		var subject = ink(window, paned.column_subject);
		var hash = hash_ink(window);
		var author = ink(window, paned.column_author);
		var date = ink(window, paned.column_date);

		search_for(window, "fix");

		assert_cmpstr(bold_rows(window, paned.column_subject, subject), CompareOperator.EQ, "prefix work,Parser fix");
		assert_cmpstr(bold_hashes(window, hash), CompareOperator.EQ, "prefix work,Parser fix");
		assert_cmpstr(bold_rows(window, paned.column_author, author), CompareOperator.EQ, "prefix work,Parser fix");
		assert_cmpstr(bold_rows(window, paned.column_date, date), CompareOperator.EQ, "prefix work,Parser fix");
		assert_cmpstr(marked_rows(window, paned.column_hash), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_messages_search_waits_for_enter()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var history = window.history;
		var messages = choice_box(window, "Messages");

		history.search_visible = true;
		history.search_field.text = "parser";
		settle(400);

		assert_cmpstr(history.search_count, CompareOperator.EQ, "Enter to search");
		assert_true(messages.inconsistent);
		assert_cmpstr(ticked_choices(window), CompareOperator.EQ, "");

		history.search_field.activate();
		settle(400);

		assert_false(messages.inconsistent);
		assert_cmpstr(ticked_choices(window), CompareOperator.EQ, "Messages");

		toggle_labelled(list_bar(window), "Match case").active = true;
		settle(400);

		assert_cmpstr(history.search_count, CompareOperator.EQ, "Enter to search");
		assert_true(messages.inconsistent);

		history.search_field.activate();
		settle(400);

		assert_false(messages.inconsistent);
		assert_cmpstr(ticked_choices(window), CompareOperator.EQ, "Messages");

		history.search_field.text = "";
		settle(400);

		assert_cmpstr(history.search_count, CompareOperator.EQ, "Enter to search");
		assert_cmpstr(ticked_choices(window), CompareOperator.EQ, "Messages");

		history.search_field.activate();
		settle(400);

		assert_cmpstr(history.search_count, CompareOperator.EQ, "");
		assert_cmpstr(ticked_choices(window), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_bar_opens_from_the_shortcut_and_the_toggle()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		Gtk.ToggleButton? toggle = null;

		foreach (var child in ((Gtk.HeaderBar)window.get_titlebar()).get_children())
		{
			if (child is Gtk.ToggleButton && child.tooltip_text == "Search the history")
			{
				toggle = (Gtk.ToggleButton)child;
			}
		}

		assert_false(window.history.search_visible);

		window.activate_action("search", null);
		assert_true(window.history.search_visible);
		assert_true(toggle.active);

		window.activate_action("search", null);
		assert_false(window.history.search_visible);

		toggle.active = true;
		assert_true(window.history.search_visible);

		assert_cmpstr(window.history.search_field.placeholder_text, CompareOperator.EQ, "Search commit messages, authors and hashes");
		assert_cmpstr(string.joinv(",", application().get_accels_for_action("win.search")), CompareOperator.EQ, "<Primary>f");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_closing_the_bar_lifts_the_search_and_keeps_the_text()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		search_for(window, "parser");
		toggle_labelled(list_bar(window), "Display matches only").active = true;
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "parser tidy,Parser fix");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.history.search_visible = false;
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42,prefix work,parser tidy,Parser fix");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.history.search_visible = true;
		settle(200);

		assert_true(toggle_labelled(list_bar(window), "Display matches only").active);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "parser");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42,prefix work,parser tidy,Parser fix");

		window.history.search_field.activate();
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "parser tidy,Parser fix");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_display_matches_only_and_a_changed_lines_search_both_hold()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		var plain = hash_ink(window);

		window.history.apply_filter("fix", false);
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42,prefix work,parser tidy,Parser fix");
		assert_cmpstr(bold_hashes(window, plain), CompareOperator.EQ, "prefix work,Parser fix");

		search_for(window, "parser");
		toggle_labelled(list_bar(window), "Display matches only").active = true;
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "Parser fix");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_lifts_the_search_keeps_the_text_and_gives_the_focus_back()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		search_for(window, "fix");

		assert_true(marked_pixels(window, 0) > 0);

		window.history.search_field.grab_focus();
		settle(50);

		Gtk.test_widget_send_key(window.history.search_field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(window.history.search_visible);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "fix");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");
		assert_true(window.history.paned.commit_list_view.has_focus);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_marks_show_in_the_subject_hash_and_author_columns()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var sha = window.history.rows()[0].get_id().to_string();

		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		search_for(window, "fix");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.GT, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		search_for(window, sha.substring(0, 7));
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.GT, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		search_for(window, "tester");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.GT, 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_next_and_previous_wrap_and_count()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var next = button(window, "Next match (Enter)");
		var previous = button(window, "Previous match (Shift+Enter)");

		search_for(window, "FIX");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 matches");

		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 of 3");

		next.clicked();
		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "fix one");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 of 3");

		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");

		previous.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "fix one");

		window.history.search_field.activate();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");

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
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		search_for(window, "zzz");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		search_for(window, "base");

		assert_false(window.history.search_field.get_style_context().has_class("error"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_only_matches_keeps_the_selection_out_of_the_list()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		window.history.paned.details_visible = true;
		settle(300);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "issue 42");

		toggle_labelled(list_bar(window), "Display matches only").active = true;
		search_for(window, "parser");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "parser tidy,Parser fix");
		assert_null(window.history.selected);
		assert_cmpstr(window.history.diff_view.commit.get_subject(), CompareOperator.EQ, "issue 42");

		search_for(window, "42");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42");
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "issue 42");

		search_for(window, "parser");
		window.history.step(1);
		settle(200);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "parser tidy");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_only_matches_narrows_with_each_search()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var toggle = toggle_labelled(list_bar(window), "Display matches only");

		assert_cmpstr(toggle.tooltip_text, CompareOperator.EQ, "Hide the commits that do not match");

		search_for(window, "parser");
		toggle.active = true;
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "parser tidy,Parser fix");
		assert_cmpstr(window.history.summary_text, CompareOperator.EQ, "Showing 2 of 4 commits");

		search_for(window, "fix");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "prefix work,Parser fix");

		search_for(window, "");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42,prefix work,parser tidy,Parser fix");

		search_for(window, "fix");
		toggle.active = false;
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "issue 42,prefix work,parser tidy,Parser fix");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_only_matches_with_nothing_shows_a_notice()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		toggle_labelled(list_bar(window), "Display matches only").active = true;
		search_for(window, "zzz");

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(window.history.notice_text, CompareOperator.EQ, "No commit in the ticked refs matches zzz.");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_opening_again_selects_the_kept_text()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		int start;
		int end;

		search_for(window, "fix");

		var count = window.history.search_count;

		window.history.search_visible = false;
		settle(100);
		window.activate_action("search", null);
		settle(300);

		assert_true(window.history.search_visible);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "fix");
		assert_true(window.history.search_field.has_focus);
		assert_true(window.history.search_field.get_selection_bounds(out start, out end));
		assert_cmpint(start, CompareOperator.EQ, 0);
		assert_cmpint(end, CompareOperator.EQ, 3);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);

		window.history.search_field.activate();
		settle(200);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, count);
		assert_cmpstr(count, CompareOperator.EQ, "3 matches");
		assert_true(marked_pixels(window, 0) > 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_search_words_narrow_the_list()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		assert_cmpstr(window.history.search_field.tooltip_text, CompareOperator.EQ, "Searches the subject and the body of each commit message, the name and the email of the author, and the hash, in the commits of the list. It does not search the changed files: pick Changed lines or Files for that.\nNarrow with author:, message:, hash:, before: and after:, as in author:\"Jane Doe\" after:2026-01. Enter searches");

		search_for(window, "author:tester parser");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "2 matches");

		search_for(window, "author:nobody parser");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");

		search_for(window, "message:tidy");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		search_for(window, "parser after:2026-13");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Bad date");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		toggle_labelled(list_bar(window), "Display matches only").active = true;
		search_for(window, "author:tester fix before:2027");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "prefix work,Parser fix");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_keep_their_state_when_the_bar_closes()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		search_for(window, "parser");
		toggle_labelled(list_bar(window), "Match case").active = true;
		window.history.search_visible = false;
		settle(100);
		window.history.search_visible = true;
		settle(100);

		assert_true(toggle_labelled(list_bar(window), "Match case").active);
		assert_false(toggle_labelled(list_bar(window), "Regex").active);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_are_push_buttons()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window);

		assert_false(toggle_labelled(bar, "Match case") is Gtk.CheckButton);
		assert_false(toggle_labelled(bar, "Regex") is Gtk.CheckButton);
		assert_false(toggle_labelled(bar, "Display matches only") is Gtk.CheckButton);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_narrow_the_matches()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window);

		search_for(window, "parser");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "2 matches");

		toggle_labelled(bar, "Match case").active = true;
		window.history.search_field.activate();
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		toggle_labelled(bar, "Match case").active = false;
		search_for(window, "issue [0-9]+");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");

		toggle_labelled(bar, "Regex").active = true;
		window.history.search_field.activate();
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 of 1");
		assert_true(marked_pixels(window, 0) > 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_say_what_they_do()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window);

		assert_cmpstr(toggle_labelled(bar, "Match case").tooltip_text, CompareOperator.EQ, "Tell capital and small letters apart");
		assert_cmpstr(toggle_labelled(bar, "Regex").tooltip_text, CompareOperator.EQ, "Read the text as a regex, a POSIX extended regular expression, as git log -G does");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_close_button_closes_the_bar_and_lifts_the_search()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window).get_ancestor(typeof(Gtk.SearchBar));
		Gtk.Button? close = null;

		search_for(window, "parser");

		foreach (var widget in find_all(bar, typeof(Gtk.Button)))
		{
			if (!widget.is_ancestor(list_bar(window)) && widget.get_mapped())
			{
				close = (Gtk.Button)widget;
			}
		}

		assert_nonnull(close);

		close.clicked();
		settle(200);

		assert_false(window.history.search_visible);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "parser");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);

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
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		search_for(window, "zzz");

		Gtk.Allocation check;
		Gtk.Allocation count;

		toggle_labelled(list_bar(window), "Display matches only").get_allocation(out check);
		label_with(list_bar(window), "No match").get_allocation(out count);

		assert_cmpint(count.x - (check.x + check.width), CompareOperator.GE, 18);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_field_sits_at_the_centre_of_the_bar()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var field = window.history.search_field;
		var last = toggle_labelled(list_bar(window), "Display matches only");
		int x;
		int y;
		int right;

		window.history.search_visible = true;
		window.resize(1700, 800);
		settle(400);
		field.translate_coordinates(window.history.widget, field.get_allocated_width() / 2, 0, out x, out y);

		assert_true((x - window.history.widget.get_allocated_width() / 2).abs() <= 2);

		window.resize(1000, 800);
		settle(400);
		field.translate_coordinates(window.history.widget, field.get_allocated_width() / 2, 0, out x, out y);
		last.translate_coordinates(window.history.widget, last.get_allocated_width(), 0, out right, out y);

		assert_true(x < window.history.widget.get_allocated_width() / 2);
		assert_true(right <= window.history.widget.get_allocated_width());

		int minimum;
		int natural;

		window.history.widget.get_preferred_width(out minimum, out natural);

		assert_true(minimum < 400);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_field_stays_put_when_the_count_changes()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var field = window.history.search_field;
		var settings = Gtk.Settings.get_default();
		var font = settings.gtk_font_name;
		int waiting;
		int counted;
		int y;

		settings.gtk_font_name = "DejaVu Sans 11";
		window.history.search_visible = true;
		window.resize(1642, 1022);
		field.text = "fix";
		settle(400);
		field.translate_coordinates(window.history.widget, 0, 0, out waiting, out y);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");

		field.activate();
		settle(400);
		field.translate_coordinates(window.history.widget, 0, 0, out counted, out y);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "2 matches");
		assert_cmpint(counted, CompareOperator.EQ, waiting);

		settings.gtk_font_name = font;
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_tick_and_show_prefers_heads_branch_then_remotes_then_tags()
{
	try
	{
		var repo = beyond_fixture();
		var window = opened_with(repo, {"refs/heads/elsewhere"});

		search_for(window, "master only");
		button_labelled(list_bar(window), "Tick and show").clicked();
		settle(300);

		assert_true(window.history.ticks.contains("refs/heads/master"));

		search_for(window, "remote thing");
		button_labelled(list_bar(window), "Tick and show").clicked();
		settle(300);

		assert_true(window.history.ticks.contains("refs/remotes/origin/thing"));
		assert_false(window.history.ticks.contains("refs/tags/t1"));
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "remote thing");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_tick_searches_again()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		search_for(window, "feature");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		var ticks = window.history.ticks;
		ticks.remove("refs/heads/feature/scan");
		window.history.set_ticks(ticks);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match in the ticked refs. 1 in others");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticking_nothing_counts_no_match()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		search_for(window, "fix");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 matches");

		window.history.set_ticks(new Gee.HashSet<string>());

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match in the ticked refs. 3 in others");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_two_clicks_on_a_switch_leave_it_as_it_was()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		window.history.search_visible = true;
		settle(300);

		foreach (var label in new string[] { "Match case", "Regex", "Display matches only" })
		{
			var button = toggle_labelled(list_bar(window), label);

			click_widget(button);
			settle(200);
			click_widget(button);
			settle(300);

			assert_false(button.active);
			assert_false(button.has_focus);
		}

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_typing_moves_nothing()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var before = window.history.selected.get_subject();

		search_for(window, "fix one");

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, before);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}


}
