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

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/squash/a-pick-that-deletes-a-file-a-skipped-commit-changed-deletes-it", test_a_pick_that_deletes_a_file_a_skipped_commit_changed_deletes_it);
	Test.add_func("/gitrlf/squash/a-pick-that-edits-a-file-a-skipped-commit-added-adds-it", test_a_pick_that_edits_a_file_a_skipped_commit_added_adds_it);
	Test.add_func("/gitrlf/squash/a-pick-that-edits-a-file-a-skipped-commit-renamed-adds-it", test_a_pick_that_edits_a_file_a_skipped_commit_renamed_adds_it);
	Test.add_func("/gitrlf/squash/a-store-of-a-gone-repository-leaves-no-folder", test_a_store_of_a_gone_repository_leaves_no_folder);
	Test.add_func("/gitrlf/squash/a-store-reads-the-settings-of-the-repository", test_a_store_reads_the_settings_of_the_repository);
	Test.add_func("/gitrlf/squash/a-store-that-failed-lets-the-next-one-open", test_a_store_that_failed_lets_the_next_one_open);
	Test.add_func("/gitrlf/squash/a-store-that-no-window-holds-is-cleared", test_a_store_that_no_window_holds_is_cleared);

	return Test.run();
}

private static string replayed(Repo repo, string[] ids) throws Error
{
	var repository = Gitrlf.Repository.open(
		Gitrlf.Application.discover_repository(repo.path));
	var squash = new Gitrlf.Squash(repository);
	var picked = new Gitg.Commit[0];
	var lines = new string[0];

	foreach (var id in ids)
	{
		picked += repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(id));
	}

	var diff = squash.diff(picked, null);

	for (size_t i = 0; i < diff.get_num_deltas(); i++)
	{
		var delta = diff.get_delta(i);
		var file = delta.get_new_file();
		var line = new StringBuilder(
			delta.get_status().to_string().replace("GGIT_DELTA_", ""));

		line.append(" " + file.get_path());

		if (!file.get_oid().is_zero())
		{
			var data = squash.open().lookup<Ggit.Blob>(file.get_oid())
				.get_raw_content();

			line.append_c(' ');
			line.append_len((string)data, data.length - 1);
		}

		lines += line.str;
	}

	squash.remove();

	return string.joinv(",", lines);
}

private static void test_a_pick_that_deletes_a_file_a_skipped_commit_changed_deletes_it()
{
	try
	{
		var repo = Repo.create();

		repo.commit_bytes("root", "g", "one\n".data);

		var a = repo.commit("A", "a.txt", "a");

		repo.commit_bytes("B", "g", "two\n".data);
		repo.git({"rm", "--quiet", "g"});
		repo.git({"commit", "--quiet", "-m", "C"});

		var c = repo.git({"rev-parse", "HEAD"}).strip();

		assert_cmpstr(replayed(repo, {c, a}), CompareOperator.EQ,
		              "ADDED a.txt a,DELETED g");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_pick_that_edits_a_file_a_skipped_commit_added_adds_it()
{
	try
	{
		var repo = Repo.create();

		repo.commit("root", "r.txt", "r");

		var a = repo.commit("A", "a.txt", "a");

		repo.commit_bytes("B", "g", "one\n".data);

		var c = repo.commit_bytes("C", "g", "two\n".data);

		assert_cmpstr(replayed(repo, {c, a}), CompareOperator.EQ,
		              "ADDED a.txt a,ADDED g two");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_pick_that_edits_a_file_a_skipped_commit_renamed_adds_it()
{
	try
	{
		var repo = Repo.create();

		repo.commit_bytes("root", "f", "one\n".data);

		var a = repo.commit("A", "a.txt", "a");

		repo.git({"mv", "f", "g"});
		repo.git({"commit", "--quiet", "-m", "B"});

		var c = repo.commit_bytes("C", "g", "two\n".data);

		assert_cmpstr(replayed(repo, {c, a}), CompareOperator.EQ,
		              "ADDED a.txt a,ADDED g two");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_store_of_a_gone_repository_leaves_no_folder()
{
	try
	{
		var repo = Repo.create();
		var squash = new Gitrlf.Squash(Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path)));
		var folder = Gitrlf.Squash.folder();
		var stores = 0;

		repo.remove();

		try
		{
			squash.open();
		}
		catch (Error e)
		{
		}

		DirUtils.create_with_parents(folder.get_path(), 0700);

		var children = folder.enumerate_children(
			"standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
		FileInfo? info;

		while ((info = children.next_file()) != null)
		{
			stores += info.get_name().has_prefix("store-") ? 1 : 0;
		}

		assert_cmpint(stores, CompareOperator.EQ, 0);
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_store_reads_the_settings_of_the_repository()
{
	try
	{
		var repo = Repo.create();

		repo.commit("root", "f.y", "y");
		repo.git({"config", "diff.words.textconv", "strings"});
		FileUtils.set_contents(repo.path.get_child(".git").get_child("info")
			.get_child("attributes").get_path(), "*.y diff=words\n");

		var repository = Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path));
		var squash = new Gitrlf.Squash(repository);
		var store = squash.open();
		var flags = Ggit.AttributeCheckFlags.FILE_THEN_INDEX;
		var config = store.get_config().snapshot();

		assert_cmpstr(store.get_attribute("f.y", "diff", flags),
		              CompareOperator.EQ,
		              repository.get_attribute("f.y", "diff", flags));
		assert_cmpstr(config.get_string("diff.words.textconv"),
		              CompareOperator.EQ, "strings");

		squash.remove();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_store_that_failed_lets_the_next_one_open()
{
	try
	{
		var repo = Repo.create();
		var repository = Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path));
		var folder = Gitrlf.Squash.folder().get_path();
		var failed = new Gitrlf.Squash(repository);
		var next = new Gitrlf.Squash(repository);

		DirUtils.create_with_parents(folder, 0700);
		FileUtils.chmod(folder, 0500);

		try
		{
			failed.open();
		}
		catch (Error e)
		{
		}

		FileUtils.chmod(folder, 0700);

		assert_true(next.open().get_location().query_exists());

		next.remove();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_store_that_no_window_holds_is_cleared()
{
	try
	{
		var repo = Repo.create();
		var repository = Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path));
		var stale = Gitrlf.Squash.folder().get_child("store-stale");
		var first = new Gitrlf.Squash(repository);
		var second = new Gitrlf.Squash(repository);

		DirUtils.create_with_parents(stale.get_path(), 0700);

		var held = first.open().get_location();

		second.open();

		assert_false(stale.query_exists());
		assert_true(held.query_exists());

		first.remove();
		second.remove();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
