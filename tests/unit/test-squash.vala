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

private static int gone_process() throws Error
{
	var process = new Subprocess.newv({"true"}, SubprocessFlags.NONE);
	var pid = int.parse(process.get_identifier());

	process.wait();

	return pid;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/squash/a-pick-that-deletes-a-file-a-skipped-commit-changed-deletes-it", test_a_pick_that_deletes_a_file_a_skipped_commit_changed_deletes_it);
	Test.add_func("/gitrlf/squash/a-pick-that-edits-a-file-a-skipped-commit-added-adds-it", test_a_pick_that_edits_a_file_a_skipped_commit_added_adds_it);
	Test.add_func("/gitrlf/squash/a-pick-that-edits-a-file-a-skipped-commit-renamed-adds-it", test_a_pick_that_edits_a_file_a_skipped_commit_renamed_adds_it);
	Test.add_func("/gitrlf/squash/a-store-of-a-gone-process-is-cleared", test_a_store_of_a_gone_process_is_cleared);

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

private static File store_of(int pid) throws Error
{
	return File.new_for_path(DirUtils.make_tmp(
		"%s%d-XXXXXX".printf(Gitrlf.Squash.PREFIX, pid)));
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

private static void test_a_store_of_a_gone_process_is_cleared()
{
	try
	{
		var repo = Repo.create();
		var gone = store_of(gone_process());
		var live = store_of(Posix.getpid());
		var squash = new Gitrlf.Squash(Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path)));

		squash.open();

		assert_false(gone.query_exists());
		assert_true(live.query_exists());

		squash.remove();
		DirUtils.remove(live.get_path());
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
