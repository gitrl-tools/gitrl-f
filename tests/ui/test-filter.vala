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

private static int git_calls()
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

	return text.split("\n").length - 1;
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
*" -S"*)
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

	Test.add_func("/gittree/ui/filter/a-failed-search-shows-git-and-the-plain-history", test_a_failed_search_shows_git_and_the_plain_history);
	Test.add_func("/gittree/ui/filter/a-launch-with-a-text-shows-the-notice-until-the-search-ends", test_a_launch_with_a_text_shows_the_notice_until_the_search_ends);
	Test.add_func("/gittree/ui/filter/a-tick-under-a-filter-asks-git-nothing", test_a_tick_under_a_filter_asks_git_nothing);
	Test.add_func("/gittree/ui/filter/no-ticked-ref-reaching-a-match-shows-a-notice", test_no_ticked_ref_reaching_a_match_shows_a_notice);
	Test.add_func("/gittree/ui/filter/the-yellow-bar-names-the-paths-and-the-case", test_the_yellow_bar_names_the_paths_and_the_case);

	return Test.run();
}

private static Gittree.Window opened(Repo repo, string[] ticked, string[] paths, string text, bool ignore_case) throws Error
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
		assert_cmpstr(limited.history.notice_text, CompareOperator.EQ, "No ticked ref reaches a commit that adds or removes needle in p.");

		plain.destroy();
		limited.destroy();
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
