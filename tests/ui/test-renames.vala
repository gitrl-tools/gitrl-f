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

namespace GitrlfTest
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

private static string diff_paths(Gitrlf.Window window)
{
	var names = new string[0];
	var diff = window.history.diff_view.diff;

	for (var i = 0; diff != null && i < diff.get_num_deltas(); i++)
	{
		var delta = diff.get_delta(i);
		var old_path = delta.get_old_file().get_path();
		var new_path = delta.get_new_file().get_path();

		names += old_path == new_path ? new_path : old_path + ">" + new_path;
	}

	return string.joinv(",", names);
}

private static Repo fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("add old", "old.c", "l1");
	repo.commit("edit old", "old.c", "l2");
	repo.git({"mv", "old.c", "new.c"});
	repo.git({"commit", "--quiet", "-m", "rename"});
	repo.commit("edit new", "new.c", "l3");
	repo.commit("unrelated", "other.txt", "x");
	repo.commit("add dir", "dir/f.txt", "y");
	repo.commit("add gone", "gone.txt", "z");
	repo.git({"rm", "--quiet", "gone.txt"});
	repo.git({"commit", "--quiet", "-m", "remove gone"});

	return repo;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/renames/a-file-deleted-at-head-is-followed", test_a_file_deleted_at_head_is_followed);
	Test.add_func("/gitrlf/ui/renames/a-folder-and-a-glob-are-not-followed", test_a_folder_and_a_glob_are_not_followed);
	Test.add_func("/gitrlf/ui/renames/a-text-filter-works-on-a-followed-file", test_a_text_filter_works_on_a_followed_file);
	Test.add_func("/gitrlf/ui/renames/a-typed-file-is-followed-too", test_a_typed_file_is_followed_too);
	Test.add_func("/gitrlf/ui/renames/merges-are-not-shown-when-following", test_merges_are_not_shown_when_following);
	Test.add_func("/gitrlf/ui/renames/one-file-is-followed-through-its-renames", test_one_file_is_followed_through_its_renames);
	Test.add_func("/gitrlf/ui/renames/the-diff-shows-the-file-under-its-name-then", test_the_diff_shows_the_file_under_its_name_then);

	return Test.run();
}

private static Gitrlf.Window opened(Repo repo, string[] paths, string? text = null) throws Error
{
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/master");

	var window = new Gitrlf.Window(application());

	window.set_default_size(1200, 800);
	window.open_repository(Gitrlf.Application.discover_repository(repo.path), ticks, paths, repo.path, text, true);
	window.show();
	settle(800);

	return window;
}

private static void select_subject(Gitrlf.Window window, string subject)
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

private static string subjects(Gitrlf.Window window)
{
	var names = new string[0];

	foreach (var commit in window.history.rows())
	{
		names += commit.get_subject();
	}

	return string.joinv(",", names);
}

private static void test_a_file_deleted_at_head_is_followed()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"gone.txt"});

		assert_cmpstr(subjects(window), CompareOperator.EQ, "remove gone,add gone");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change gone.txt, following renames");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_folder_and_a_glob_are_not_followed()
{
	try
	{
		var repo = fixture();
		var folder = opened(repo, {"dir"});
		var glob = opened(repo, {"*.c"});

		assert_cmpstr(subjects(folder), CompareOperator.EQ, "add dir");
		assert_cmpstr(folder.history.path_bar_text, CompareOperator.EQ, "Only commits that change dir");
		assert_cmpstr(subjects(glob), CompareOperator.EQ, "edit new,rename,edit old,add old");
		assert_cmpstr(glob.history.path_bar_text, CompareOperator.EQ, "Only commits that change *.c");

		folder.destroy();
		glob.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_text_filter_works_on_a_followed_file()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"new.c"}, "l2");

		assert_cmpstr(subjects(window), CompareOperator.EQ, "edit old");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change new.c and add or remove l2, following renames, ignoring case");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_typed_file_is_followed_too()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {});

		window.history.only_matches = true;
		window.history.search_visible = true;
		window.history.search_choice = Gitrlf.SearchChoice.FILES;
		window.history.search_field.text = "new.c";
		window.history.search_field.activate();
		settle(800);

		assert_cmpstr(subjects(window), CompareOperator.EQ, "edit new,rename,edit old,add old");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change new.c, following renames");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_merges_are_not_shown_when_following()
{
	try
	{
		var repo = fixture();

		repo.branch("side");
		repo.checkout("side");
		repo.commit_bytes("side edit", "new.c", "S1\nl2\nl3\n".data);
		repo.checkout("master");
		repo.commit_bytes("main edit", "new.c", "l1\nl2\nl3\nm4\n".data);
		repo.merge("side");

		var plain = opened(repo, {"new.c", "other.txt"});
		var followed = opened(repo, {"new.c"});

		assert_true("Merge branch 'side'" in subjects(plain));
		assert_false("Merge" in subjects(followed));
		assert_true("side edit" in subjects(followed));

		plain.destroy();
		followed.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_one_file_is_followed_through_its_renames()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"new.c"});

		assert_cmpstr(subjects(window), CompareOperator.EQ, "edit new,rename,edit old,add old");
		assert_cmpstr(window.history.path_bar_text, CompareOperator.EQ, "Only commits that change new.c, following renames");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_diff_shows_the_file_under_its_name_then()
{
	try
	{
		var repo = fixture();
		var window = opened(repo, {"new.c"});

		window.history.paned.details_visible = true;
		select_subject(window, "edit old");

		assert_cmpstr(diff_paths(window), CompareOperator.EQ, "old.c");

		select_subject(window, "rename");

		assert_cmpstr(diff_paths(window), CompareOperator.EQ, "old.c>new.c");

		select_subject(window, "edit new");

		assert_cmpstr(diff_paths(window), CompareOperator.EQ, "new.c");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
