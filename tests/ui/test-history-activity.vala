/*
 * This file is part of gitree
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gitree is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gitree is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gitree. If not, see <http://www.gnu.org/licenses/>.
 */namespace GitreeTest
{

private static Gitree.Application application()
{
	var app = GLib.Application.get_default() as Gitree.Application;

	if (app == null)
	{
		app = new Gitree.Application();

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

private static void drain()
{
	while (Gtk.events_pending())
	{
		Gtk.main_iteration();
	}
}

private static uint lane_of(Gitree.Window window, string subject)
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

private static string labels(Gitree.HistoryActivity activity, int row)
{
	return string.joinv(",", activity.labels_for(activity.rows()[row]));
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitree/ui/history-activity/bytes-that-are-not-utf8-show-as-replacements", test_bytes_that_are_not_utf8_show_as_replacements);
	Test.add_func("/gitree/ui/history-activity/history-settings-redraw-the-list", test_history_settings_redraw_the_list);
	Test.add_func("/gitree/ui/history-activity/path-bar-and-path-notice", test_path_bar_and_path_notice);
	Test.add_func("/gitree/ui/history-activity/refs-that-cannot-be-read-leave-the-ticks-alone", test_refs_that_cannot_be_read_leave_the_ticks_alone);
	Test.add_func("/gitree/ui/history-activity/selection-is-kept-across-a-tick", test_selection_is_kept_across_a_tick);
	Test.add_func("/gitree/ui/history-activity/summary-counts-rows-of-commits", test_summary_counts_rows_of_commits);
	Test.add_func("/gitree/ui/history-activity/ticks-are-kept-when-the-window-closes", test_ticks_are_kept_when_the_window_closes);
	Test.add_func("/gitree/ui/history-activity/ticks-are-not-written-again-after-leaving-for-the-chooser", test_ticks_are_not_written_again_after_leaving_for_the_chooser);
	Test.add_func("/gitree/ui/history-activity/window-jump-ticks-an-unticked-ref-and-selects-its-tip", test_window_jump_ticks_an_unticked_ref_and_selects_its_tip);
	Test.add_func("/gitree/ui/history-activity/window-labels-only-ticked-refs", test_window_labels_only_ticked_refs);
	Test.add_func("/gitree/ui/history-activity/window-with-nothing-ticked-shows-the-empty-notice", test_window_with_nothing_ticked_shows_the_empty_notice);

	Test.add_func("/gitree/ui/history-activity/columns-are-subject-author-and-date", test_columns_are_subject_author_and_date);
	Test.add_func("/gitree/ui/history-activity/dates-use-gitgs-wording", test_dates_use_gitgs_wording);
	Test.add_func("/gitree/ui/history-activity/detached-head-label-comes-first", test_detached_head_label_comes_first);
	Test.add_func("/gitree/ui/history-activity/pane-positions-are-kept", test_pane_positions_are_kept);
	Test.add_func("/gitree/ui/history-activity/sidebar-layout", test_sidebar_layout);
	Test.add_func("/gitree/ui/history-activity/ticks-are-kept-when-leaving-for-the-chooser", test_ticks_are_kept_when_leaving_for_the_chooser);
	return Test.run();
}

private static Gitree.Window opened(Repo repo, string[] ticked, string[] paths = {}) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gitree.Window(application());
	window.open_repository(Gitree.Application.discover_repository(repo.path), ticks, paths, repo.path);
	window.show();
	drain();

	return window;
}

private static string subjects_of(Gitree.Window window)
{
	var names = new string[0];

	foreach (var commit in window.history.rows())
	{
		names += commit.get_subject();
	}

	return string.joinv(",", names);
}

private static File ticks_file(Repo repo)
{
	return repo.path.get_child(".git").get_child("git-tree-ticks");
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

		var settings = new Settings(Gitree.Config.APPLICATION_ID + ".preferences.history");
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

private static void test_refs_that_cannot_be_read_leave_the_ticks_alone()
{
	try
	{
		var first = Repo.create();
		first.branched();

		var broken = Repo.create();
		broken.commit("first");
		broken.branch("other");
		broken.git({"pack-refs", "--all"});

		var kept = "+ refs/heads/master\n- refs/heads/other\n";
		FileUtils.set_contents(ticks_file(broken).get_path(), kept);
		FileUtils.set_contents(broken.path.get_child(".git").get_child("packed-refs").get_path(), "garbage\n");

		var window = opened(first, {"refs/heads/master"});
		window.open_repository(Gitree.Application.discover_repository(broken.path));
		drain();

		assert_cmpint(window.history.rows().length, CompareOperator.EQ, 0);

		window.close();
		drain();

		string contents;
		FileUtils.get_contents(ticks_file(broken).get_path(), out contents);
		assert_cmpstr(contents, CompareOperator.EQ, kept);

		first.remove();
		broken.remove();
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

private static void test_ticks_are_kept_when_the_window_closes()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/fix/stamp", "refs/tags/v1"});
		window.close();
		drain();

		string contents;
		FileUtils.get_contents(repo.path.get_child(".git").get_child("git-tree-ticks").get_path(), out contents);

		assert_cmpstr(contents, CompareOperator.EQ, string.joinv("\n", {
			"- refs/heads/master",
			"- refs/heads/feature/scan",
			"+ refs/heads/fix/stamp",
			"- refs/remotes/origin/master",
			"+ refs/tags/v1",
			"",
		}));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticks_are_not_written_again_after_leaving_for_the_chooser()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		window.show_dash();
		drain();

		var changed = "+ refs/heads/feature/scan\n";
		FileUtils.set_contents(ticks_file(repo).get_path(), changed);

		window.close();
		drain();

		string contents;
		FileUtils.get_contents(ticks_file(repo).get_path(), out contents);
		assert_cmpstr(contents, CompareOperator.EQ, changed);

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


private static void test_columns_are_subject_author_and_date()
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

		assert_cmpstr(string.joinv(",", titles), CompareOperator.EQ, "Subject,Author,Date");
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

private static void test_pane_positions_are_kept()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var settings = new Settings(Gitree.Config.APPLICATION_ID + ".state.history");
		settings.set_int("paned-sidebar-position", 231);
		settings.set_int("paned-panels-position", 123);

		var window = opened(repo, {"refs/heads/master"});

		assert_cmpint(window.history.paned.position, CompareOperator.EQ, 231);
		assert_cmpint(window.history.paned.paned_panels.position, CompareOperator.EQ, 123);

		window.history.paned.paned_panels.position = 150;
		assert_cmpint(settings.get_int("paned-panels-position"), CompareOperator.EQ, 150);

		settings.reset("paned-sidebar-position");
		settings.reset("paned-panels-position");
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
		var sidebar = (Gtk.Box)window.history.paned.get_child1();
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

private static void test_ticks_are_kept_when_leaving_for_the_chooser()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/tags/v1"});
		window.show_dash();

		string contents;
		FileUtils.get_contents(repo.path.get_child(".git").get_child("git-tree-ticks").get_path(), out contents);

		assert_true("+ refs/tags/v1\n" in contents);
		assert_true("- refs/heads/master\n" in contents);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}
}
