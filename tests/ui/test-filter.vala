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

private static string s_log;

private static string s_wrapper_directory;

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

private static Gtk.Button button_tooltipped(Gtk.Widget root, string tooltip)
{
	foreach (var widget in find_all(root, typeof(Gtk.Button)))
	{
		if (widget.tooltip_text == tooltip)
		{
			return (Gtk.Button)widget;
		}
	}

	error("no button %s", tooltip);
}

private static void choose(Gittree.Window window, Gittree.SearchChoice choice)
{
	window.history.search_visible = true;
	window.history.search_choice = choice;
}

private static void filter_paths(Gittree.Window window, string text, string paths)
{
	var history = window.history;

	history.only_matches = true;
	choose(window, Gittree.SearchChoice.FILES);
	history.search_field.text = paths;
	history.search_field.activate();
	settle(800);
	choose(window, Gittree.SearchChoice.LINES);
	history.search_field.text = text;
	history.search_field.activate();
	settle(800);
}

private static void filter_with(Gittree.Window window, string text, bool regex)
{
	var history = window.history;

	history.only_matches = true;
	choose(window, Gittree.SearchChoice.LINES);
	history.search_field.text = text;
	check_labelled(list_bar(window), "Regex").active = regex;
	history.search_field.activate();
	settle(800);
}

private static Repo fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("a", "p/x", "needle");
	repo.commit("b", "q", "plain");
	repo.branch("side");
	repo.checkout("side");
	repo.commit("s1", "q", "more plain");
	repo.checkout("master");
	repo.commit("c", "q", "needle");
	repo.commit("d", "p/x", "plain");
	repo.commit("e", "q", "NEEDLE");
	repo.git({"checkout", "--quiet", "--orphan", "lonely"});
	repo.git({"rm", "--quiet", "-r", "-f", "."});
	repo.commit("z", "r", "plain");
	repo.checkout("master");

	return repo;
}

private static int git_calls(string? word = null)
{
	string text;

	try
	{
		FileUtils.get_contents(s_log, out text);
	}
	catch (FileError e)
	{
		return 0;
	}

	var count = 0;

	foreach (var line in text.split("\n"))
	{
		if (line != "" && (word == null || word in line))
		{
			count++;
		}
	}

	return count;
}

private static void install_wrapper()
{
	try
	{
		s_wrapper_directory = DirUtils.make_tmp("gittree-git-XXXXXX");
	}
	catch (FileError e)
	{
		error("%s", e.message);
	}

	s_log = Path.build_filename(s_wrapper_directory, "calls");

	var script = """#!/bin/sh
echo "$*" >> "%s"
case "$*" in
*" -S"* | *" -G"* | *" --parents "*)
	sleep "${GITTREE_TEST_GIT_DELAY:-0}"
	if [ -n "$GITTREE_TEST_GIT_FAIL" ]; then
		echo "$GITTREE_TEST_GIT_FAIL" >&2
		exit 128
	fi
	;;
esac
exec "%s" "$@"
""".printf(s_log, Environment.find_program_in_path("git"));
	var path = Path.build_filename(s_wrapper_directory, "git");

	try
	{
		FileUtils.set_contents(path, script);
	}
	catch (FileError e)
	{
		error("%s", e.message);
	}

	FileUtils.chmod(path, 0755);
	Environment.set_variable("PATH", s_wrapper_directory + ":" + Environment.get_variable("PATH"), true);
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);
	install_wrapper();

	Test.add_func("/gittree/ui/filter/a-bad-expression-in-the-bar-applies-nothing", test_a_bad_expression_in_the_bar_applies_nothing);
	Test.add_func("/gittree/ui/filter/a-bare-repository-opened-from-the-list-can-be-filtered", test_a_bare_repository_opened_from_the_list_can_be_filtered);
	Test.add_func("/gittree/ui/filter/a-close-by-the-user-keeps-the-diff-bar-closed-until-the-filter-changes", test_a_close_by_the_user_keeps_the_diff_bar_closed_until_the_filter_changes);
	Test.add_func("/gittree/ui/filter/a-failed-search-shows-git-and-the-plain-history", test_a_failed_search_shows_git_and_the_plain_history);
	Test.add_func("/gittree/ui/filter/a-filter-after-a-failed-open-does-nothing", test_a_filter_after_a_failed_open_does_nothing);
	Test.add_func("/gittree/ui/filter/a-launch-puts-its-text-and-case-in-changed-lines", test_a_launch_puts_its_text_and_case_in_changed_lines);
	Test.add_func("/gittree/ui/filter/a-launch-with-a-regex-filters-by-changed-lines", test_a_launch_with_a_regex_filters_by_changed_lines);
	Test.add_func("/gittree/ui/filter/a-launch-with-a-text-shows-the-notice-until-the-search-ends", test_a_launch_with_a_text_shows_the_notice_until_the_search_ends);
	Test.add_func("/gittree/ui/filter/a-new-filter-puts-its-text-in-the-diff-bar", test_a_new_filter_puts_its_text_in_the_diff_bar);
	Test.add_func("/gittree/ui/filter/a-new-filter-stops-the-search-before-it", test_a_new_filter_stops_the_search_before_it);
	Test.add_func("/gittree/ui/filter/a-path-outside-the-repository-shows-git-and-keeps-the-filter", test_a_path_outside_the_repository_shows_git_and_keeps_the_filter);
	Test.add_func("/gittree/ui/filter/a-regex-filter-fills-the-diff-bar-with-its-switch", test_a_regex_filter_fills_the_diff_bar_with_its_switch);
	Test.add_func("/gittree/ui/filter/a-reload-during-a-slow-search-stops-it-first", test_a_reload_during_a_slow_search_stops_it_first);
	Test.add_func("/gittree/ui/filter/a-reload-or-a-new-filter-keeps-the-launch-notice", test_a_reload_or_a_new_filter_keeps_the_launch_notice);
	Test.add_func("/gittree/ui/filter/a-selection-in-the-diff-bar-is-kept-across-commits", test_a_selection_in_the_diff_bar_is_kept_across_commits);
	Test.add_func("/gittree/ui/filter/a-tick-under-a-filter-asks-git-nothing", test_a_tick_under_a_filter_asks_git_nothing);
	Test.add_func("/gittree/ui/filter/a-typed-path-draws-what-the-command-line-draws", test_a_typed_path_draws_what_the_command_line_draws);
	Test.add_func("/gittree/ui/filter/closing-the-bar-lifts-the-filter-and-keeps-the-text", test_closing_the_bar_lifts_the_filter_and_keeps_the_text);
	Test.add_func("/gittree/ui/filter/closing-with-the-pane-is-not-a-close-by-the-user", test_closing_with_the_pane_is_not_a_close_by_the_user);
	Test.add_func("/gittree/ui/filter/ctrl-shift-f-opens-the-bar-on-changed-lines", test_ctrl_shift_f_opens_the_bar_on_changed_lines);
	Test.add_func("/gittree/ui/filter/ctrl-shift-f-takes-a-selection-and-applies-nothing", test_ctrl_shift_f_takes_a_selection_and_applies_nothing);
	Test.add_func("/gittree/ui/filter/display-matches-only-hides-and-shows-without-git", test_display_matches_only_hides_and_shows_without_git);
	Test.add_func("/gittree/ui/filter/each-choice-keeps-its-own-text-and-switches", test_each_choice_keeps_its_own_text_and_switches);
	Test.add_func("/gittree/ui/filter/enter-applies-changed-lines-and-typing-does-not", test_enter_applies_changed_lines_and_typing_does_not);
	Test.add_func("/gittree/ui/filter/enter-on-an-empty-field-lifts-the-filter", test_enter_on_an_empty_field_lifts_the_filter);
	Test.add_func("/gittree/ui/filter/escape-closes-in-order-and-lifts-the-filter-with-the-bar", test_escape_closes_in_order_and_lifts_the_filter_with_the_bar);
	Test.add_func("/gittree/ui/filter/escape-in-a-filled-diff-bar-selects-no-text", test_escape_in_a_filled_diff_bar_selects_no_text);
	Test.add_func("/gittree/ui/filter/escape-in-the-field-closes-from-the-bottom-up-and-keeps-the-focus", test_escape_in_the_field_closes_from_the_bottom_up_and_keeps_the_focus);
	Test.add_func("/gittree/ui/filter/globs-and-quoted-paths-work-in-the-field", test_globs_and_quoted_paths_work_in_the_field);
	Test.add_func("/gittree/ui/filter/no-ticked-ref-reaching-a-match-shows-a-notice", test_no_ticked_ref_reaching_a_match_shows_a_notice);
	Test.add_func("/gittree/ui/filter/the-choices-stack-and-the-list-shows-each-text", test_the_choices_stack_and_the_list_shows_each_text);
	Test.add_func("/gittree/ui/filter/the-close-button-lifts-every-search", test_the_close_button_lifts_every_search);
	Test.add_func("/gittree/ui/filter/the-diff-bar-opens-with-the-text-and-the-case-of-the-filter", test_the_diff_bar_opens_with_the_text_and_the_case_of_the_filter);
	Test.add_func("/gittree/ui/filter/the-diff-of-a-commit-the-files-search-does-not-match-is-whole", test_the_diff_of_a_commit_the_files_search_does_not_match_is_whole);
	Test.add_func("/gittree/ui/filter/the-files-choice-holds-the-command-line-paths", test_the_files_choice_holds_the_command_line_paths);
	Test.add_func("/gittree/ui/filter/the-list-answers-while-a-search-runs", test_the_list_answers_while_a_search_runs);
	Test.add_func("/gittree/ui/filter/the-paths-are-read-in-the-background", test_the_paths_are_read_in_the_background);
	Test.add_func("/gittree/ui/filter/the-regex-switch-filters-by-changed-lines", test_the_regex_switch_filters_by_changed_lines);
	Test.add_func("/gittree/ui/filter/the-users-own-text-in-the-diff-bar-is-kept-across-commits", test_the_users_own_text_in_the_diff_bar_is_kept_across_commits);
	Test.add_func("/gittree/ui/filter/the-yellow-bar-names-the-paths-and-the-case", test_the_yellow_bar_names_the_paths_and_the_case);

	return Test.run();
}

private static Repo moved_fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("one", "f", "alpha needle");
	repo.commit_bytes("two", "f", "alpha needle beta\n".data);
	repo.commit("three", "g", "plain");

	return repo;
}

private static Gittree.Window opened(Repo repo, string[] ticked, string[] paths, string? text, bool ignore_case) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gittree.Window(application());

	window.set_default_size(1200, 800);
	window.open_repository(Gittree.Application.discover_repository(repo.path), ticks, paths, repo.path, text, ignore_case);
	window.show();

	return window;
}

private static void pick(Gittree.Window window, string label)
{
	var button = (Gtk.MenuButton)find_all(list_bar(window), typeof(Gtk.MenuButton))[0];

	foreach (var child in button.popup.get_children())
	{
		if (((Gtk.MenuItem)child).label.has_prefix(label))
		{
			((Gtk.MenuItem)child).activate();
		}
	}

	settle(100);
}

private static void select_in_diff(Gittree.Window window, string text)
{
	foreach (var file in window.history.diff_view.get_files())
	{
		file.expanded = true;
	}

	settle(300);

	foreach (var file in window.history.diff_view.get_files())
	{
		foreach (var view in file.get_text_views())
		{
			Gtk.TextIter start;
			Gtk.TextIter found;
			Gtk.TextIter end;

			view.buffer.get_start_iter(out start);

			if (start.forward_search(text, 0, out found, out end, null))
			{
				view.buffer.select_range(found, end);
				view.grab_focus();
				settle(100);
				return;
			}
		}
	}

	error("no %s in the diff", text);
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

	settle(200);
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

private static string subjects(Gittree.Window window)
{
	var names = new string[0];

	foreach (var commit in window.history.rows())
	{
		names += commit.get_subject();
	}

	return string.joinv(",", names);
}

private static void test_a_bad_expression_in_the_bar_applies_nothing()
{
	try
	{
		var repo = moved_fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var field = window.history.search_field;

		settle(300);
		filter_with(window, "(", true);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "three,two,one");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");
		assert_true(field.get_style_context().has_class("error"));
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Bad regex");
		assert_cmpint(git_calls("-G("), CompareOperator.EQ, 0);

		field.text = "needle";
		settle(300);

		assert_false(field.get_style_context().has_class("error"));
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_bare_repository_opened_from_the_list_can_be_filtered()
{
	try
	{
		var repo = fixture();
		var bare = File.new_for_path(repo.path.get_path() + ".git");

		repo.git({"clone", "--quiet", "--bare", repo.path.get_path(), bare.get_path()});

		var ticks = new Gee.HashSet<string>();
		ticks.add("refs/heads/master");

		var window = new Gittree.Window(application());

		window.open_repository(Gittree.Application.discover_repository(bare), ticks);
		window.show();
		settle(300);
		window.history.only_matches = true;
		window.history.apply_filter("needle", false);
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");

		window.destroy();
		new Repo(bare).remove();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_close_by_the_user_keeps_the_diff_bar_closed_until_the_filter_changes()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		settle(400);

		assert_true(history.find_bar.search_mode_enabled);

		history.find_bar.field.grab_focus();
		window.activate_action("search", null);
		settle(100);

		assert_false(history.find_bar.search_mode_enabled);

		select_subject(window, "a");
		settle(300);

		assert_false(history.find_bar.search_mode_enabled);

		history.find_bar.search_mode_enabled = true;
		settle(100);
		history.paned.commit_list_view.grab_focus();
		history.escape();
		settle(100);
		select_subject(window, "c");
		settle(300);

		assert_false(history.find_bar.search_mode_enabled);

		history.apply_filter("plain", false);
		settle(800);

		assert_true(history.find_bar.search_mode_enabled);
		assert_cmpstr(history.find_bar.field.text, CompareOperator.EQ, "plain");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_failed_search_shows_git_and_the_plain_history()
{
	try
	{
		var repo = fixture();

		Environment.set_variable("GITTREE_TEST_GIT_FAIL", "fatal: the search broke", true);

		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);

		settle(500);
		Environment.unset_variable("GITTREE_TEST_GIT_FAIL");

		assert_true(window.error_shown);
		assert_cmpstr(window.error_text, CompareOperator.EQ, "fatal: the search broke");
		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "list");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_filter_after_a_failed_open_does_nothing()
{
	try
	{
		var repo = fixture();

		FileUtils.set_contents(repo.path.get_child(".git").get_child("packed-refs").get_path(), "garbage line\n");

		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);

		assert_true(window.error_shown);

		window.history.apply_filter("needle", false);
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_launch_puts_its_text_and_case_in_changed_lines()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", true);

		settle(800);

		assert_true(window.history.search_visible);
		assert_true(window.history.search_choice == Gittree.SearchChoice.LINES);
		assert_true(window.history.only_matches);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "needle");
		assert_false(check_labelled(list_bar(window), "Match case").active);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_launch_with_a_regex_filters_by_changed_lines()
{
	try
	{
		var repo = moved_fixture();
		var ticks = new Gee.HashSet<string>();
		ticks.add("refs/heads/master");

		var window = new Gittree.Window(application());

		window.set_default_size(1200, 800);
		window.open_repository(Gittree.Application.discover_repository(repo.path), ticks, {}, repo.path, "needle", false, true);
		window.show();
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "two,one");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits whose added or removed lines match needle");

		choose(window, Gittree.SearchChoice.LINES);

		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "needle");
		assert_true(check_labelled(list_bar(window), "Regex").active);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_launch_with_a_text_shows_the_notice_until_the_search_ends()
{
	try
	{
		var repo = fixture();

		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1.5", true);

		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);

		settle(300);

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(window.history.notice_text, CompareOperator.EQ, "Searching the changes for needle...");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Searching the changes for needle...");
		assert_true(window.history.paned.path_spinner.get_mapped());
		assert_cmpstr(window.history.summary_text, CompareOperator.EQ, "");

		var ticks = window.history.ticks;

		ticks.add("refs/heads/side");
		window.history.set_ticks(ticks);
		settle(100);

		assert_true(window.history.ticks.contains("refs/heads/side"));
		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");

		settle(2000);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "list");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");
		assert_cmpstr(window.history.summary_text, CompareOperator.EQ, "Showing 2 of 2 commits");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that add or remove needle");
		assert_false(window.history.paned.path_spinner.get_mapped());
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "c");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_new_filter_puts_its_text_in_the_diff_bar()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		settle(400);
		history.find_bar.field.text = "q";
		settle(300);
		history.apply_filter("NEEDLE", false);
		settle(800);

		assert_cmpstr(history.find_bar.field.text, CompareOperator.EQ, "NEEDLE");
		assert_true(history.find_bar.match_case);
		assert_cmpstr(history.find_bar.count, CompareOperator.EQ, "1 of 1");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_new_filter_stops_the_search_before_it()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var field = window.history.search_field;

		settle(300);
		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1", true);
		window.history.only_matches = true;
		choose(window, Gittree.SearchChoice.LINES);
		check_labelled(list_bar(window), "Match case").active = true;
		field.text = "needle";
		field.activate();
		settle(300);
		field.text = "NEEDLE";
		field.activate();
		settle(1500);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that add or remove NEEDLE");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_path_outside_the_repository_shows_git_and_keeps_the_filter()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {"p"}, null, false);

		settle(300);
		choose(window, Gittree.SearchChoice.FILES);
		window.history.search_field.text = "../elsewhere";
		window.history.search_field.activate();
		settle(800);

		assert_true(window.error_shown);
		assert_true("outside repository" in window.error_text);
		assert_cmpstr(subjects(window), CompareOperator.EQ, "d,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change p");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_regex_filter_fills_the_diff_bar_with_its_switch()
{
	try
	{
		var repo = moved_fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var find_bar = window.history.find_bar;

		settle(300);
		filter_with(window, "need+le", true);
		window.history.paned.details_visible = true;
		settle(400);

		assert_true(find_bar.search_mode_enabled);
		assert_cmpstr(find_bar.field.text, CompareOperator.EQ, "need+le");
		assert_true(find_bar.regex);
		assert_false(find_bar.match_case);
		assert_cmpstr(find_bar.count, CompareOperator.EQ, "1 of 2");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_reload_during_a_slow_search_stops_it_first()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1", true);

		var before = git_calls(" -S");

		window.history.only_matches = true;
		window.history.apply_filter("needle", false);
		settle(300);
		repo.commit("f", "q", "needle again");
		window.activate_action("reload", null);
		settle(1500);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpint(git_calls(" -S"), CompareOperator.EQ, before + 2);
		assert_cmpstr(subjects(window), CompareOperator.EQ, "f,c,a");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_reload_or_a_new_filter_keeps_the_launch_notice()
{
	try
	{
		var repo = fixture();

		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1", true);

		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);

		settle(300);
		window.activate_action("reload", null);
		settle(200);

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "");

		window.history.apply_filter("NEEDLE", false);
		settle(200);

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(window.history.notice_text, CompareOperator.EQ, "Searching the changes for NEEDLE...");

		settle(1500);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpstr(window.history.list_page, CompareOperator.EQ, "list");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_selection_in_the_diff_bar_is_kept_across_commits()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		select_subject(window, "c");
		history.paned.details_visible = true;
		settle(400);
		history.find_bar.search_mode_enabled = false;
		settle(100);
		select_in_diff(window, "needle");
		window.activate_action("search", null);
		settle(300);

		assert_cmpstr(history.find_bar.field.text, CompareOperator.EQ, "needle");

		history.find_bar.field.text = "need";
		settle(300);
		select_in_diff(window, "need");
		window.activate_action("search", null);
		settle(300);
		select_subject(window, "a");
		settle(300);

		assert_true(history.find_bar.search_mode_enabled);
		assert_cmpstr(history.find_bar.field.text, CompareOperator.EQ, "need");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_tick_under_a_filter_asks_git_nothing()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {"p"}, "needle", false);

		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "a");

		var before = git_calls();
		var ticks = window.history.ticks;

		ticks.add("refs/heads/side");
		window.history.set_ticks(ticks);
		ticks.remove("refs/heads/master");
		window.history.set_ticks(ticks);
		settle(100);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "a");
		assert_cmpint(git_calls(), CompareOperator.EQ, before);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_typed_path_draws_what_the_command_line_draws()
{
	try
	{
		var repo = fixture();
		var typed = opened(repo, {"refs/heads/master"}, {}, null, false);
		var given = opened(repo, {"refs/heads/master"}, {"p"}, null, false);

		settle(300);
		choose(typed, Gittree.SearchChoice.FILES);

		assert_cmpstr(typed.history.search_field.placeholder_text, CompareOperator.EQ, "Files or folders, split by spaces");
		assert_cmpstr(typed.history.search_field.tooltip_text, CompareOperator.EQ, "Files or folders, split by spaces. Globs such as '*.yaml' work. Enter searches");

		filter_paths(typed, "", "p");

		assert_cmpstr(subjects(typed), CompareOperator.EQ, subjects(given));
		assert_cmpstr(subjects(typed), CompareOperator.EQ, "d,a");
		assert_cmpstr(typed.history.path_bar_text, CompareOperator.EQ, "Only commits that change p");
		assert_cmpstr(typed.history.summary_text, CompareOperator.EQ, given.history.summary_text);

		filter_paths(typed, "needle", "p");

		assert_cmpstr(subjects(typed), CompareOperator.EQ, "a");
		assert_cmpstr(typed.history.path_bar_text, CompareOperator.EQ, "Only commits that change p and add or remove needle, ignoring case");

		filter_paths(typed, "", "");

		assert_cmpstr(subjects(typed), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(typed.history.path_bar_text, CompareOperator.EQ, "");

		typed.destroy();
		given.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_closing_the_bar_lifts_the_filter_and_keeps_the_text()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		window.history.only_matches = true;
		choose(window, Gittree.SearchChoice.LINES);
		check_labelled(list_bar(window), "Match case").active = true;
		window.history.search_field.text = "needle";
		window.history.search_field.activate();
		settle(600);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");

		window.history.search_visible = false;
		settle(300);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.history.search_visible = true;
		settle(100);

		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "needle");
		assert_true(check_labelled(list_bar(window), "Match case").active);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");

		window.history.search_field.activate();
		settle(600);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_closing_with_the_pane_is_not_a_close_by_the_user()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		settle(400);

		assert_true(history.find_bar.search_mode_enabled);

		history.paned.details_visible = false;
		settle(100);

		assert_false(history.find_bar.search_mode_enabled);

		history.paned.details_visible = true;
		settle(400);

		assert_true(history.find_bar.search_mode_enabled);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_shift_f_opens_the_bar_on_changed_lines()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var history = window.history;

		settle(300);

		foreach (var child in ((Gtk.HeaderBar)window.get_titlebar()).get_children())
		{
			assert_false(child.tooltip_text != null && "Ctrl+Shift+F" in child.tooltip_text);
		}

		assert_cmpstr(string.joinv(",", application().get_accels_for_action("win.filter")), CompareOperator.EQ, "<Primary><Shift>f");
		assert_false(history.search_visible);

		window.activate_action("filter", null);
		settle(100);

		assert_true(history.search_visible);
		assert_true(history.search_choice == Gittree.SearchChoice.LINES);
		assert_true(history.search_field.has_focus);
		assert_cmpstr(history.search_field.placeholder_text, CompareOperator.EQ, "Lines that commits added or removed");
		assert_false(check_labelled(list_bar(window), "Match case").active);

		window.activate_action("filter", null);
		settle(100);

		assert_false(history.search_visible);

		history.search_choice = Gittree.SearchChoice.MESSAGES;
		window.activate_action("search", null);
		settle(100);
		window.activate_action("filter", null);
		settle(100);

		assert_true(history.search_visible);
		assert_true(history.search_choice == Gittree.SearchChoice.LINES);

		history.search_field.text = "kept";
		Gtk.test_widget_send_key(history.search_field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(history.search_visible);
		assert_cmpstr(history.search_field.text, CompareOperator.EQ, "kept");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ctrl_shift_f_takes_a_selection_and_applies_nothing()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var history = window.history;

		settle(300);
		select_subject(window, "c");
		history.paned.details_visible = true;
		settle(400);
		select_in_diff(window, "needle");
		window.activate_action("filter", null);
		settle(300);

		assert_true(history.search_visible);
		assert_true(history.search_choice == Gittree.SearchChoice.LINES);
		assert_cmpstr(history.search_field.text, CompareOperator.EQ, "needle");
		assert_cmpstr(history.path_bar_text, CompareOperator.EQ, "");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_display_matches_only_hides_and_shows_without_git()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		choose(window, Gittree.SearchChoice.LINES);
		window.history.search_field.text = "needle";
		window.history.search_field.activate();
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(marked_rows(window, window.history.paned.column_hash), CompareOperator.EQ, "e,c,a");

		var before = git_calls();

		window.history.only_matches = true;
		settle(100);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,c,a");
		assert_cmpstr(marked_rows(window, window.history.paned.column_hash), CompareOperator.EQ, "");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that add or remove needle, ignoring case");

		window.history.only_matches = false;
		settle(100);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Marked: commits that add or remove needle, ignoring case");
		assert_cmpint(git_calls(), CompareOperator.EQ, before);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_each_choice_keeps_its_own_text_and_switches()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var history = window.history;
		var field = history.search_field;
		var buttons = find_all(list_bar(window), typeof(Gtk.MenuButton));
		var match_case = check_labelled(list_bar(window), "Match case");
		var regex = check_labelled(list_bar(window), "Regex");
		int button_x;
		int field_x;
		int y;

		history.search_visible = true;
		settle(300);

		assert_cmpint(buttons.length, CompareOperator.EQ, 1);

		buttons[0].translate_coordinates(list_bar(window), 0, 0, out button_x, out y);
		field.translate_coordinates(list_bar(window), 0, 0, out field_x, out y);

		assert_cmpint(button_x, CompareOperator.LT, field_x);
		assert_cmpstr(choice_labels(window), CompareOperator.EQ, "Messages, authors and hashes,Changed lines,Files");
		assert_cmpstr(((Gtk.Label)find_all(buttons[0], typeof(Gtk.Label))[0]).label, CompareOperator.EQ, "Messages");

		field.text = "fix";
		settle(300);
		pick(window, "Changed lines");

		assert_true(history.search_choice == Gittree.SearchChoice.LINES);
		assert_cmpstr(field.text, CompareOperator.EQ, "");
		assert_cmpstr(((Gtk.Label)find_all(buttons[0], typeof(Gtk.Label))[0]).label, CompareOperator.EQ, "Changed lines");

		field.text = "needle";
		match_case.active = true;
		pick(window, "Files");

		assert_cmpstr(field.text, CompareOperator.EQ, "");
		assert_false(match_case.sensitive);
		assert_false(regex.sensitive);

		pick(window, "Messages, authors and hashes");

		assert_cmpstr(field.text, CompareOperator.EQ, "fix");
		assert_false(match_case.active);
		assert_true(match_case.sensitive);

		pick(window, "Changed lines");

		assert_cmpstr(field.text, CompareOperator.EQ, "needle");
		assert_true(match_case.active);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_enter_applies_changed_lines_and_typing_does_not()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var field = window.history.search_field;

		settle(300);
		choose(window, Gittree.SearchChoice.LINES);

		var before = git_calls(" -S");

		field.text = "needle";
		settle(500);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpint(git_calls(" -S"), CompareOperator.EQ, before);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");

		field.activate();
		settle(600);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(marked_rows(window, window.history.paned.column_hash), CompareOperator.EQ, "e,c,a");
		assert_cmpstr(marked_rows(window, window.history.paned.column_subject), CompareOperator.EQ, "");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 of 3");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Marked: commits that add or remove needle, ignoring case");
		assert_true(window.history.search_visible);

		field.activate();
		settle(100);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "c");

		check_labelled(list_bar(window), "Match case").active = true;
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Enter to search");

		button_tooltipped(list_bar(window), "Next match (Enter)").clicked();
		settle(600);

		assert_cmpstr(marked_rows(window, window.history.paned.column_hash), CompareOperator.EQ, "c,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Marked: commits that add or remove needle");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_enter_on_an_empty_field_lifts_the_filter()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);

		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");

		choose(window, Gittree.SearchChoice.LINES);
		window.history.search_field.text = "";
		window.history.search_field.activate();
		settle(200);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_closes_in_order_and_lifts_the_filter_with_the_bar()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		history.paned.details_only = true;
		history.find_bar.search_mode_enabled = true;
		history.search_visible = true;
		settle(200);
		history.paned.commit_list_view.grab_focus();

		assert_true(history.escape());
		assert_false(history.find_bar.search_mode_enabled);
		assert_true(history.paned.details_only);

		assert_true(history.escape());
		assert_false(history.paned.details_only);
		assert_true(history.paned.details_visible);

		assert_true(history.escape());
		assert_false(history.paned.details_visible);
		assert_true(history.search_visible);

		assert_true(history.escape());
		assert_false(history.search_visible);
		assert_cmpstr(history.path_bar_text, CompareOperator.EQ, "");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");

		assert_false(history.escape());

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_in_a_filled_diff_bar_selects_no_text()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		settle(400);

		assert_true(history.find_bar.search_mode_enabled);

		history.find_bar.field.grab_focus();
		Gtk.test_widget_send_key(history.find_bar.field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(history.find_bar.search_mode_enabled);
		assert_true(window.get_focus().is_ancestor(history.diff_view));
		assert_cmpstr(selected_label_text(history.diff_view), CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_in_the_field_closes_from_the_bottom_up_and_keeps_the_focus()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;
		var field = history.search_field;

		settle(800);
		history.paned.details_visible = true;
		history.search_visible = true;
		history.find_bar.search_mode_enabled = true;
		settle(200);
		field.grab_focus();
		settle(50);

		Gtk.test_widget_send_key(field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(history.find_bar.search_mode_enabled);
		assert_true(history.paned.details_visible);
		assert_true(field.has_focus);

		Gtk.test_widget_send_key(field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(history.paned.details_visible);
		assert_true(history.search_visible);
		assert_true(field.has_focus);

		Gtk.test_widget_send_key(field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(history.search_visible);
		assert_cmpstr(history.path_bar_text, CompareOperator.EQ, "");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_globs_and_quoted_paths_work_in_the_field()
{
	try
	{
		var repo = Repo.create();

		repo.commit("top", "top.yaml", "one");
		repo.commit("deep", "a b/c/deep.yaml", "two");
		repo.commit("text", "notes.txt", "three");
		repo.commit("spaced", "a b/notes.txt", "four");

		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		filter_paths(window, "", "'*.yaml'");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "deep,top");

		filter_paths(window, "", "\"a b\"");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "spaced,deep");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change a b");

		filter_paths(window, "", "notes.txt top.yaml");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "text,top");

		choose(window, Gittree.SearchChoice.FILES);
		window.history.search_field.text = "'a b";
		settle(300);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "A quote is not closed");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		window.history.search_field.activate();
		settle(300);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "text,top");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_no_ticked_ref_reaching_a_match_shows_a_notice()
{
	try
	{
		var repo = fixture();
		var plain = opened(repo, {"refs/heads/lonely"}, {}, "needle", false);
		var limited = opened(repo, {"refs/heads/lonely"}, {"p"}, "needle", false);

		settle(800);

		assert_cmpstr(plain.history.list_page, CompareOperator.EQ, "notice");
		assert_cmpstr(plain.history.notice_text, CompareOperator.EQ, "No ticked ref reaches a commit that adds or removes needle.");
		assert_cmpstr(limited.history.notice_text, CompareOperator.EQ, "No ticked ref reaches a commit that changes p and adds or removes needle.");

		plain.destroy();
		limited.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_choices_stack_and_the_list_shows_each_text()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);
		var hash = repo.git({"rev-parse", "--short", "master"}).strip();

		settle(300);
		filter_paths(window, "needle", "q");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,c");

		choose(window, Gittree.SearchChoice.MESSAGES);
		window.history.search_field.text = hash;
		settle(400);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e");
		assert_cmpstr(choice_labels(window), CompareOperator.EQ, "Messages, authors and hashes: %s,Changed lines: needle,Files: q".printf(hash));
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that match %s in the message, author or hash, change q and add or remove needle, following renames, ignoring case".printf(hash));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_close_button_lifts_every_search()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);

		settle(800);
		select_subject(window, "a");

		assert_true(window.history.paned.path_bar.show_close_button);

		var before = git_calls();

		window.history.paned.path_bar.response(Gtk.ResponseType.CLOSE);
		settle(100);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "");
		assert_cmpint(git_calls(), CompareOperator.EQ, before);

		choose(window, Gittree.SearchChoice.LINES);

		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "");

		var limited = opened(repo, {"refs/heads/master"}, {"p"}, null, false);

		settle(300);

		assert_true(limited.history.paned.path_bar.show_close_button);

		limited.history.paned.path_bar.response(Gtk.ResponseType.CLOSE);
		settle(300);

		assert_cmpstr(subjects(limited), CompareOperator.EQ, "e,d,c,b,a");
		assert_cmpstr(limited.history.path_bar_text, CompareOperator.EQ, "");

		choose(limited, Gittree.SearchChoice.FILES);

		assert_cmpstr(limited.history.search_field.text, CompareOperator.EQ, "");

		limited.destroy();
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_diff_bar_opens_with_the_text_and_the_case_of_the_filter()
{
	try
	{
		var repo = fixture();
		var exact = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var loose = opened(repo, {"refs/heads/master"}, {}, "needle", true);

		settle(800);

		assert_false(exact.history.find_bar.search_mode_enabled);

		exact.history.paned.commit_list_view.grab_focus();
		exact.history.paned.details_visible = true;
		loose.history.paned.details_visible = true;
		settle(400);

		assert_true(exact.history.find_bar.search_mode_enabled);
		assert_cmpstr(exact.history.find_bar.field.text, CompareOperator.EQ, "needle");
		assert_true(exact.history.find_bar.match_case);
		assert_cmpstr(exact.history.find_bar.count, CompareOperator.EQ, "1 of 1");
		assert_true(exact.get_focus() == exact.history.paned.commit_list_view);
		assert_false(loose.history.find_bar.match_case);

		select_subject(exact, "a");
		settle(300);

		assert_cmpstr(exact.history.find_bar.count, CompareOperator.EQ, "1 of 1");

		exact.destroy();
		loose.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_diff_of_a_commit_the_files_search_does_not_match_is_whole()
{
	try
	{
		var repo = Repo.create();

		repo.commit("first", "p/x", "one");
		repo.commit("only q", "q", "two");
		FileUtils.set_contents(repo.path.get_child("q").get_path(), "two\nthree\n");
		repo.commit_bytes("both", "p/x", "one\nfour\n".data);

		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		choose(window, Gittree.SearchChoice.FILES);
		window.history.search_field.text = "p";
		window.history.search_field.activate();
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "both,only q,first");
		assert_cmpstr(marked_rows(window, window.history.paned.column_hash), CompareOperator.EQ, "both,first");

		select_subject(window, "both");
		window.history.paned.details_visible = true;
		settle(400);

		assert_cmpint((int)window.history.diff_view.diff.get_num_deltas(), CompareOperator.EQ, 1);
		assert_cmpstr(window.history.diff_view.diff.get_delta(0).get_new_file().get_path(), CompareOperator.EQ, "p/x");

		select_subject(window, "only q");
		settle(400);

		assert_cmpint((int)window.history.diff_view.diff.get_num_deltas(), CompareOperator.EQ, 1);
		assert_cmpstr(window.history.diff_view.diff.get_delta(0).get_new_file().get_path(), CompareOperator.EQ, "q");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_files_choice_holds_the_command_line_paths()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {"p", "a b"}, null, false);

		settle(300);
		choose(window, Gittree.SearchChoice.FILES);

		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "p 'a b'");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_list_answers_while_a_search_runs()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		window.history.paned.details_visible = true;
		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1.5", true);
		window.history.only_matches = true;
		choose(window, Gittree.SearchChoice.LINES);
		check_labelled(list_bar(window), "Match case").active = true;
		window.history.search_field.text = "needle";
		window.history.search_field.activate();
		settle(300);

		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Searching the changes for needle...");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");

		select_subject(window, "b");
		settle(200);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "b");
		assert_cmpstr(window.history.diff_view.commit.get_subject(), CompareOperator.EQ, "b");

		settle(1800);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "c,a");
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "c");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_paths_are_read_in_the_background()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		Environment.set_variable("GITTREE_TEST_GIT_DELAY", "1", true);
		window.history.only_matches = true;
		choose(window, Gittree.SearchChoice.FILES);
		window.history.search_field.text = "p";
		window.history.search_field.activate();
		settle(300);
		Environment.unset_variable("GITTREE_TEST_GIT_DELAY");

		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Reading the history of p...");
		assert_cmpstr(subjects(window), CompareOperator.EQ, "e,d,c,b,a");

		select_subject(window, "c");

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "c");

		settle(1500);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "d,a");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change p");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_regex_switch_filters_by_changed_lines()
{
	try
	{
		var repo = moved_fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, null, false);

		settle(300);
		choose(window, Gittree.SearchChoice.LINES);

		assert_cmpstr(window.history.search_field.placeholder_text, CompareOperator.EQ, "Lines that commits added or removed");
		assert_cmpstr(window.history.search_field.tooltip_text, CompareOperator.EQ, "Searches the lines that each commit added or removed, in every file of every ref, as git log -S does, or git log -G with Regex. Enter searches");
		assert_cmpstr(check_labelled(list_bar(window), "Regex").tooltip_text, CompareOperator.EQ, "Read the text as a regex, a POSIX extended regular expression, as git log -G does");

		filter_with(window, "needle", false);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "one");

		filter_with(window, "needle", true);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "two,one");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits whose added or removed lines match needle, ignoring case");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_users_own_text_in_the_diff_bar_is_kept_across_commits()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"refs/heads/master"}, {}, "needle", false);
		var history = window.history;

		settle(800);
		history.paned.details_visible = true;
		settle(400);
		history.find_bar.field.text = "needle";
		history.find_bar.match_case = false;
		history.find_bar.field.text = "Needle";
		settle(300);
		select_subject(window, "a");
		settle(300);

		assert_cmpstr(history.find_bar.field.text, CompareOperator.EQ, "Needle");
		assert_false(history.find_bar.match_case);
		assert_cmpstr(history.find_bar.count, CompareOperator.EQ, "1 of 1");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_yellow_bar_names_the_paths_and_the_case()
{
	try
	{
		var repo = fixture();
		var loose = opened(repo, {"refs/heads/master"}, {}, "needle", true);
		var limited = opened(repo, {"refs/heads/master"}, {"p"}, "needle", false);

		settle(800);

		assert_cmpstr(loose.history.path_bar_text, CompareOperator.EQ, "Only commits that add or remove needle, ignoring case");
		assert_cmpstr(subjects(loose), CompareOperator.EQ, "e,c,a");
		assert_cmpstr(limited.history.path_bar_text, CompareOperator.EQ, "Only commits that change p and add or remove needle");
		assert_cmpstr(limited.history.summary_text, CompareOperator.EQ, "Showing 1 of 1 commits");

		limited.history.paned.details_visible = true;
		settle(400);

		assert_cmpint((int)limited.history.diff_view.diff.get_num_deltas(), CompareOperator.EQ, 1);
		assert_cmpstr(limited.history.diff_view.diff.get_delta(0).get_new_file().get_path(), CompareOperator.EQ, "p/x");

		loose.destroy();
		limited.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
