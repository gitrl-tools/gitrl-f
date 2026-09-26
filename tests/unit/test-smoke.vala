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
 */
namespace GitreeTest
{

private static string history(Repo repo) throws Error
{
	repo.commit("first");
	repo.branch("feature");
	repo.checkout("feature");
	repo.commit("on feature", "feature.txt");
	repo.checkout("master");
	repo.commit("on main", "main.txt");
	repo.merge("feature");

	return repo.git({"log", "--all", "--format=%H"});
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/smoke/fixture-builds-history", test_fixture_builds_history);
	Test.add_func("/gitree/smoke/fixture-is-deterministic", test_fixture_is_deterministic);
	Test.add_func("/gitree/smoke/home-is-not-the-users", test_home_is_not_the_users);
	Test.add_func("/gitree/smoke/vendored-library-links", test_vendored_library_links);

	return Test.run();
}

private static void test_fixture_builds_history()
{
	try
	{
		var repo = Repo.create();

		history(repo);

		var branches = repo.git({"for-each-ref", "--format=%(refname:short)", "refs/heads"});
		assert_true("feature" in branches);
		assert_true("master" in branches);

		FileUtils.set_contents(repo.path.get_child("file").get_path(), "dirty\n");
		repo.stash("wip");

		var stash = repo.git({"stash", "list"});
		assert_true("wip" in stash);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("fixture failed: %s", e.message);
	}
}

private static void test_fixture_is_deterministic()
{
	try
	{
		var a = Repo.create();
		var b = Repo.create();

		assert_cmpstr(history(a), CompareOperator.EQ, history(b));

		a.remove();
		b.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("fixture failed: %s", e.message);
	}
}

private static void test_home_is_not_the_users()
{
	var home = Environment.get_variable("HOME");
	unowned Posix.Passwd? user = Posix.getpwuid(Posix.getuid());

	assert_nonnull(home);

	if (user != null)
	{
		assert_cmpstr(home, CompareOperator.NE, user.pw_dir);
	}

	foreach (var name in new string[] { "XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME" })
	{
		var dir = Environment.get_variable(name);

		assert_nonnull(dir);
		assert_true(dir.has_prefix(home + "/"));
	}
}

private static void test_vendored_library_links()
{
	try
	{
		Gitg.init();
	}
	catch (Error e)
	{
		Test.fail_printf("Gitg.init() failed: %s", e.message);
	}
}

}
