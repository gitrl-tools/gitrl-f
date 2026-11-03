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

private const string LISTING = "find . -printf '%M %p\\n' | LC_ALL=C sort -k2";

private static File copy(Repo repo, string id) throws Error
{
	var repository = Gitrlf.Repository.open(
		Gitrlf.Application.discover_repository(repo.path));
	var commit = repository.lookup<Gitg.Commit>(
		new Ggit.OId.from_string(id));

	return Gitrlf.CommitFiles.copy(repository, commit);
}

private static void discard(File folder) throws Error
{
	shell("chmod -R u+w . && rm -rf -- \"$PWD\"", folder.get_parent());
}

private static string listing(File folder) throws Error
{
	return shell(LISTING, folder).strip();
}

public static int main(string[] args)
{
	Environment.set_variable("GIT_CONFIG_GLOBAL", "/dev/null", true);
	Environment.set_variable("GIT_CONFIG_SYSTEM", "/dev/null", true);
	Test.init(ref args);

	Test.add_func(
		"/gitrlf/commit-files/a-commit-opens-as-a-locked-copy-of-its-tree",
		test_a_commit_opens_as_a_locked_copy_of_its_tree);
	Test.add_func("/gitrlf/commit-files/a-submodule-opens-as-an-empty-folder",
	              test_a_submodule_opens_as_an_empty_folder);
	Test.add_func(
		"/gitrlf/commit-files/the-same-commit-opens-the-same-copy-again",
		test_the_same_commit_opens_the_same_copy_again);

	return Test.run();
}

private static string read(File file) throws Error
{
	string contents;

	FileUtils.get_contents(file.get_path(), out contents);

	return contents;
}

private static string shell(string command, File folder) throws Error
{
	string output;
	int status;

	Process.spawn_sync(folder.get_path(), {"sh", "-c", command}, null,
	                   SpawnFlags.SEARCH_PATH, null, out output, null,
	                   out status);
	Process.check_wait_status(status);

	return output;
}

private static void test_a_commit_opens_as_a_locked_copy_of_its_tree()
{
	try
	{
		var repo = Repo.create();
		var first = repo.commit("one", "notes");
		var second = repo.commit("two", "dir/extra");
		var before = copy(repo, first);
		var after = copy(repo, second);

		assert_cmpstr(before.get_basename(), CompareOperator.EQ,
		              first.substring(0, 7));
		assert_cmpstr(listing(before), CompareOperator.EQ,
		              "dr-xr-xr-x .\n"
		              + "-r--r--r-- ./notes");
		assert_cmpstr(after.get_basename(), CompareOperator.EQ,
		              second.substring(0, 7));
		assert_cmpstr(listing(after), CompareOperator.EQ,
		              "dr-xr-xr-x .\n"
		              + "dr-xr-xr-x ./dir\n"
		              + "-r--r--r-- ./dir/extra\n"
		              + "-r--r--r-- ./notes");
		assert_cmpstr(read(after.get_child("notes")), CompareOperator.EQ,
		              "one\n");
		assert_cmpstr(read(after.resolve_relative_path("dir/extra")),
		              CompareOperator.EQ, "two\n");
		discard(before);
		discard(after);
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_submodule_opens_as_an_empty_folder()
{
	try
	{
		var repo = Repo.create();
		var inner = repo.commit("inner", "notes");

		repo.git({"update-index", "--add", "--cacheinfo",
		          "160000," + inner + ",sub"});
		repo.git({"commit", "--quiet", "-m", "outer"});

		var folder = copy(repo, repo.git({"rev-parse", "HEAD"}).strip());

		assert_cmpstr(listing(folder), CompareOperator.EQ,
		              "dr-xr-xr-x .\n"
		              + "-r--r--r-- ./notes\n"
		              + "dr-xr-xr-x ./sub");
		discard(folder);
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_same_commit_opens_the_same_copy_again()
{
	try
	{
		var repo = Repo.create();
		var first = repo.commit("alpha", "readme");
		var second = repo.commit("beta", "readme");
		var once = copy(repo, first);
		var again = copy(repo, first);
		var other = copy(repo, second);

		assert_cmpstr(again.get_path(), CompareOperator.EQ, once.get_path());
		assert_cmpstr(other.get_path(), CompareOperator.NE, once.get_path());
		discard(once);
		discard(other);
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
