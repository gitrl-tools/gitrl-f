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

private const string FILE_RECORD = "{ stat -c %A \"$LOCAL\" \"$REMOTE\"; "
	+ "cat \"$LOCAL\"; echo --; cat \"$REMOTE\"; }";

private const string FOLDER_RECORD = "{ basename \"$LOCAL\"; "
	+ "cd \"$LOCAL\" && find . -printf '%M %p\\n' | LC_ALL=C sort -k2; "
	+ "echo --; basename \"$REMOTE\"; "
	+ "cd \"$REMOTE\" && find . -printf '%M %p\\n' | LC_ALL=C sort -k2; }";

private class Fixture : Object
{
	public Repo repo;
	public Gitg.Repository repository;
	public File record;

	public Fixture(string command) throws Error
	{
		repo = Repo.create();
		record = repo.path.get_parent().get_child(
			repo.path.get_basename() + ".record");
		repo.git({"config", "diff.tool", "record"});
		repo.git({"config", "difftool.record.cmd",
		          command + " > '" + record.get_path() + "'; "
		          + "dirname \"$LOCAL\" >> '" + record.get_path() + "'"});
	}

	public Gitg.Commit commit(string id) throws Error
	{
		return repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(id));
	}

	public void open() throws Error
	{
		repository = Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path));
	}

	public string[] read() throws Error
	{
		uint8[] contents;

		record.load_contents(null, out contents, null);

		return ((string)contents).strip().split("\n");
	}

	public void remove()
	{
		repo.remove();
		FileUtils.unlink(record.get_path());
	}
}

private static void compare_commit(Fixture fixture, Gitg.Commit commit)
{
	var loop = new MainLoop();

	Gitrlf.DiffTool.compare_commit.begin(fixture.repository, fixture.repo.path,
	                                      commit, (obj, res) => {
		try
		{
			Gitrlf.DiffTool.compare_commit.end(res);
		}
		catch (Error e)
		{
			Test.fail_printf("compare failed: %s", e.message);
		}

		loop.quit();
	});
	loop.run();
}

private static void compare_delta(Fixture fixture, Ggit.DiffDelta delta,
                                  string before, string after, bool worktree)
{
	var loop = new MainLoop();

	Gitrlf.DiffTool.compare_file.begin(fixture.repository, fixture.repo.path,
	                                    before, after, delta, worktree,
	                                    (obj, res) => {
		try
		{
			Gitrlf.DiffTool.compare_file.end(res);
		}
		catch (Error e)
		{
			Test.fail_printf("compare failed: %s", e.message);
		}

		loop.quit();
	});
	loop.run();
}

private static void compare_file(Fixture fixture, Gitg.Commit commit)
{
	compare_delta(fixture, commit.get_diff(null, 0).get_delta(0), "before",
	              "after", false);
}

private static string lines(string[] record, int from, int to)
{
	return string.joinv("\n", record[from:to]);
}

public static int main(string[] args)
{
	Environment.set_variable("GIT_CONFIG_GLOBAL", "/dev/null", true);
	Environment.set_variable("GIT_CONFIG_SYSTEM", "/dev/null", true);
	Test.init(ref args);

	Test.add_func("/gitrlf/diff-tool/a-commit-opens-as-two-locked-folders",
	              test_a_commit_opens_as_two_locked_folders);
	Test.add_func("/gitrlf/diff-tool/a-file-opens-as-two-locked-files",
	              test_a_file_opens_as_two_locked_files);
	Test.add_func(
		"/gitrlf/diff-tool/a-first-commit-opens-beside-an-empty-folder",
		test_a_first_commit_opens_beside_an_empty_folder);
	Test.add_func(
		"/gitrlf/diff-tool/a-new-file-in-the-tree-opens-beside-nothing",
		test_a_new_file_in_the_tree_opens_beside_nothing);
	Test.add_func("/gitrlf/diff-tool/a-staged-file-opens-against-head",
	              test_a_staged_file_opens_against_head);
	Test.add_func("/gitrlf/diff-tool/an-added-file-opens-beside-an-empty-file",
	              test_an_added_file_opens_beside_an_empty_file);
	Test.add_func("/gitrlf/diff-tool/an-unstaged-file-opens-as-a-locked-copy",
	              test_an_unstaged_file_opens_as_a_locked_copy);
	Test.add_func("/gitrlf/diff-tool/the-copies-go-when-the-tool-closes",
	              test_the_copies_go_when_the_tool_closes);

	return Test.run();
}

private static void stage_and_edit(Fixture fixture) throws Error
{
	var notes = fixture.repo.path.get_child("notes").get_path();

	fixture.repo.commit("one", "notes");
	FileUtils.set_contents(notes, "staged\n");
	fixture.repo.git({"add", "notes"});
	FileUtils.set_contents(notes, "later\n");
	fixture.open();
}

private static void test_a_commit_opens_as_two_locked_folders()
{
	try
	{
		var fixture = new Fixture(FOLDER_RECORD);
		var first = fixture.repo.commit("one", "notes");

		FileUtils.set_contents(fixture.repo.path.get_child("notes").get_path(),
		                       "one\nthree\n");
		fixture.repo.git({"add", "notes"});

		var second = fixture.repo.commit("two", "dir/extra");

		fixture.open();
		compare_commit(fixture, fixture.commit(second));

		var record = fixture.read();

		assert_cmpstr(lines(record, 0, 3), CompareOperator.EQ,
		              first.substring(0, 7) + "\n"
		              + "dr-xr-xr-x .\n"
		              + "-r--r--r-- ./notes");
		assert_cmpstr(lines(record, 4, 9), CompareOperator.EQ,
		              second.substring(0, 7) + "\n"
		              + "dr-xr-xr-x .\n"
		              + "dr-xr-xr-x ./dir\n"
		              + "-r--r--r-- ./dir/extra\n"
		              + "-r--r--r-- ./notes");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_file_opens_as_two_locked_files()
{
	try
	{
		var fixture = new Fixture(FILE_RECORD);

		fixture.repo.commit("one", "notes");

		var second = fixture.repo.commit("two", "notes");

		fixture.open();
		compare_file(fixture, fixture.commit(second));

		assert_cmpstr(lines(fixture.read(), 0, 6), CompareOperator.EQ,
		              "-r--r--r--\n"
		              + "-r--r--r--\n"
		              + "one\n"
		              + "--\n"
		              + "one\n"
		              + "two");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_first_commit_opens_beside_an_empty_folder()
{
	try
	{
		var fixture = new Fixture(FOLDER_RECORD);
		var first = fixture.repo.commit("one", "notes");

		fixture.open();
		compare_commit(fixture, fixture.commit(first));

		assert_cmpstr(lines(fixture.read(), 0, 6), CompareOperator.EQ,
		              "empty\n"
		              + "dr-xr-xr-x .\n"
		              + "--\n"
		              + first.substring(0, 7) + "\n"
		              + "dr-xr-xr-x .\n"
		              + "-r--r--r-- ./notes");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_new_file_in_the_tree_opens_beside_nothing()
{
	try
	{
		var fixture = new Fixture(FILE_RECORD);

		fixture.repo.commit("one", "notes");
		FileUtils.set_contents(fixture.repo.path.get_child("fresh").get_path(),
		                       "new\n");
		fixture.open();

		var delta = Gitrlf.Changes.unstaged(fixture.repository, 3).get_delta(0);

		compare_delta(fixture, delta, "staged", "working-tree", true);

		assert_cmpstr(lines(fixture.read(), 0, 4), CompareOperator.EQ,
		              "-r--r--r--\n"
		              + "-r--r--r--\n"
		              + "--\n"
		              + "new");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_staged_file_opens_against_head()
{
	try
	{
		var fixture = new Fixture(FILE_RECORD);

		stage_and_edit(fixture);

		var delta = Gitrlf.Changes.staged(fixture.repository, 3).get_delta(0);

		compare_delta(fixture, delta, "HEAD", "staged", false);

		assert_cmpstr(lines(fixture.read(), 0, 5), CompareOperator.EQ,
		              "-r--r--r--\n"
		              + "-r--r--r--\n"
		              + "one\n"
		              + "--\n"
		              + "staged");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_added_file_opens_beside_an_empty_file()
{
	try
	{
		var fixture = new Fixture(FILE_RECORD);

		fixture.repo.commit("one", "notes");

		var second = fixture.repo.commit("two", "extra");

		fixture.open();
		compare_file(fixture, fixture.commit(second));

		assert_cmpstr(lines(fixture.read(), 0, 4), CompareOperator.EQ,
		              "-r--r--r--\n"
		              + "-r--r--r--\n"
		              + "--\n"
		              + "two");
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_unstaged_file_opens_as_a_locked_copy()
{
	try
	{
		var fixture = new Fixture(FILE_RECORD);

		stage_and_edit(fixture);

		var delta = Gitrlf.Changes.unstaged(fixture.repository, 3).get_delta(0);

		compare_delta(fixture, delta, "staged", "working-tree", true);

		var info = fixture.repo.path.get_child("notes").query_info(
			FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE);

		assert_cmpstr(lines(fixture.read(), 0, 5), CompareOperator.EQ,
		              "-r--r--r--\n"
		              + "-r--r--r--\n"
		              + "staged\n"
		              + "--\n"
		              + "later");
		assert_true(info.get_attribute_boolean(FileAttribute.ACCESS_CAN_WRITE));
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_copies_go_when_the_tool_closes()
{
	try
	{
		var fixture = new Fixture(FOLDER_RECORD);

		fixture.repo.commit("one", "notes");

		var second = fixture.repo.commit("two", "notes");

		fixture.open();
		compare_commit(fixture, fixture.commit(second));

		var record = fixture.read();
		var copies = File.new_for_path(record[record.length - 1]);

		assert_false(copies.query_exists());
		fixture.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
