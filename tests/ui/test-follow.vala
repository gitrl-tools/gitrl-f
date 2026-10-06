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

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/follow/a-commit-under-a-filter-searches-again", test_a_commit_under_a_filter_searches_again);
	Test.add_func("/gitrlf/ui/follow/an-edit-shows-in-the-changes-on-the-next-check", test_an_edit_shows_in_the_changes_on_the_next_check);
	Test.add_func("/gitrlf/ui/follow/deleted-repository-shows-an-error-and-keeps-the-history", test_deleted_repository_shows_an_error_and_keeps_the_history);
	Test.add_func("/gitrlf/ui/follow/f5-reloads-at-once", test_f5_reloads_at_once);
	Test.add_func("/gitrlf/ui/follow/monitoring-off-stops-the-poll", test_monitoring_off_stops_the_poll);
	Test.add_func("/gitrlf/ui/follow/new-commit-keeps-the-top-row-in-place", test_new_commit_keeps_the_top_row_in_place);
	Test.add_func("/gitrlf/ui/follow/poll-finds-a-new-commit", test_poll_finds_a_new_commit);
	Test.add_func("/gitrlf/ui/follow/selection-and-scroll-are-kept", test_selection_and_scroll_are_kept);
	Test.add_func("/gitrlf/ui/follow/snapshot-changes-when-a-branch-appears", test_snapshot_changes_when_a_branch_appears);
	Test.add_func("/gitrlf/ui/follow/window-reload-ticks-a-new-local-branch-but-not-a-new-remote-one", test_window_reload_ticks_a_new_local_branch_but_not_a_new_remote_one);

	return Test.run();
}

private static Gitrlf.Window opened(Repo repo, string[] ticked) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gitrlf.Window(application());
	window.set_default_size(900, 300);
	window.open_repository(Gitrlf.Application.discover_repository(repo.path), ticks, {}, repo.path);
	window.show();
	settle(100);

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

private static void test_a_commit_under_a_filter_searches_again()
{
	try
	{
		var repo = Repo.create();
		repo.commit("one", "f", "needle");
		repo.commit("two", "f", "plain");

		var ticks = new Gee.HashSet<string>();
		ticks.add("refs/heads/master");

		var window = new Gitrlf.Window(application());
		window.set_default_size(900, 300);
		window.open_repository(Gitrlf.Application.discover_repository(repo.path), ticks, {}, repo.path, "needle", false);
		window.show();
		settle(500);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "one");

		repo.commit("three", "f", "needle");
		settle(3000);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "three");
		assert_cmpint(window.history.rows().length, CompareOperator.EQ, 2);

		var settings = new Settings(Gitrlf.Config.APPLICATION_ID + ".preferences.interface");

		settings.set_boolean("enable-monitoring", false);
		settle(20);
		repo.commit("four", "f", "needle");
		settle(2500);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "three");

		window.activate_action("reload", null);
		settle(500);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "four");

		settings.reset("enable-monitoring");
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_edit_shows_in_the_changes_on_the_next_check()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");

		var window = opened(repo, {"refs/heads/master"});
		var paned = window.history.paned;

		assert_false(paned.changes.visible);

		FileUtils.set_contents(repo.path.get_child("notes").get_path(), "edited\n");
		settle(2600);

		assert_true(paned.changes.visible);
		assert_false(paned.staged_row.visible);
		assert_cmpstr(paned.unstaged_count.label, CompareOperator.EQ, "1 file");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_deleted_repository_shows_an_error_and_keeps_the_history()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});
		var rows = window.history.rows().length;

		repo.remove();
		window.activate_action("reload", null);
		settle(100);

		assert_true(window.error_shown);
		assert_cmpint(window.history.rows().length, CompareOperator.EQ, rows);

		window.destroy();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_f5_reloads_at_once()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		repo.commit("master five");
		window.activate_action("reload", null);
		settle(50);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "master five");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_monitoring_off_stops_the_poll()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var settings = new Settings(Gitrlf.Config.APPLICATION_ID + ".preferences.interface");
		var window = opened(repo, {"refs/heads/master"});

		assert_true(window.polling);

		settings.set_boolean("enable-monitoring", false);
		settle(20);
		assert_false(window.polling);

		repo.commit("unseen");
		settle(2500);
		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "master four");

		settings.reset("enable-monitoring");
		settle(20);
		assert_true(window.polling);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_new_commit_keeps_the_top_row_in_place()
{
	try
	{
		var repo = Repo.create();

		for (var i = 0; i < 80; i++)
		{
			repo.commit("commit %d".printf(i));
		}

		var window = opened(repo, {"refs/heads/master"});

		scroll_to_row(window, "commit 30", 10);
		settle(50);
		assert_cmpstr(top_row(window), CompareOperator.EQ, "commit 30 -10");

		repo.commit("commit 80");
		window.activate_action("reload", null);
		settle(100);

		assert_cmpstr(top_row(window), CompareOperator.EQ, "commit 30 -10");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_poll_finds_a_new_commit()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		repo.commit("master five");
		settle(2600);

		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "master five");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_selection_and_scroll_are_kept()
{
	try
	{
		var repo = Repo.create();

		for (var i = 0; i < 80; i++)
		{
			repo.commit("commit %d".printf(i));
		}

		var window = opened(repo, {"refs/heads/master"});
		var view = window.history.paned.commit_list_view;
		var adjustment = window.history.paned.scrolled_window_commit_list.vadjustment;

		view.get_selection().select_path(new Gtk.TreePath.from_indices(40));
		adjustment.value = adjustment.upper / 2;
		settle(50);

		var scroll = adjustment.value;

		repo.branch("elsewhere");
		window.activate_action("reload", null);
		settle(100);

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "commit 39");
		assert_cmpfloat(adjustment.value, CompareOperator.EQ, scroll);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_snapshot_changes_when_a_branch_appears()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));
		var before = Gitrlf.Poll.snapshot(repository);

		assert_cmpstr(Gitrlf.Poll.snapshot(repository), CompareOperator.EQ, before);

		repo.branch("another");

		assert_cmpstr(Gitrlf.Poll.snapshot(repository), CompareOperator.NE, before);

		var moved = Gitrlf.Poll.snapshot(repository);
		repo.checkout("another");

		assert_cmpstr(Gitrlf.Poll.snapshot(repository), CompareOperator.NE, moved);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_window_reload_ticks_a_new_local_branch_but_not_a_new_remote_one()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		repo.commit("master five");
		repo.branch("fresh");
		repo.git({"update-ref", "refs/remotes/origin/fresh", "feature/scan"});
		window.history.refresh();

		assert_true(window.history.ticks.contains("refs/heads/fresh"));
		assert_false(window.history.ticks.contains("refs/remotes/origin/fresh"));
		assert_cmpstr(window.history.rows()[0].get_subject(), CompareOperator.EQ, "master five");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
