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

	Test.add_func("/gitrlf/ticks/a-new-local-branch-is-ticked-and-other-new-refs-are-not", test_a_new_local_branch_is_ticked_and_other_new_refs_are_not);
	Test.add_func("/gitrlf/ticks/detached-head-argument-ticks-the-head-row", test_detached_head_argument_ticks_the_head_row);
	Test.add_func("/gitrlf/ticks/first-run-ticks-every-ref", test_first_run_ticks_every_ref);
	Test.add_func("/gitrlf/ticks/glob-ticks-every-matching-branch", test_glob_ticks_every_matching_branch);
	Test.add_func("/gitrlf/ticks/globs-follow-python", test_globs_follow_python);
	Test.add_func("/gitrlf/ticks/head-on-a-branch-ticks-that-branch", test_head_on_a_branch_ticks_that_branch);
	Test.add_func("/gitrlf/ticks/options-add-up", test_options_add_up);
	Test.add_func("/gitrlf/ticks/unknown-ref-stops-before-the-window-opens", test_unknown_ref_stops_before_the_window_opens);

	return Test.run();
}

private static string names(Gee.List<Gitrlf.Ref> refs, Gee.Set<string>? ticks)
{
	var shorts = new Gee.ArrayList<string>();

	foreach (var reference in refs)
	{
		if (ticks.contains(reference.name))
		{
			shorts.add(reference.short_name);
		}
	}

	shorts.sort();

	return string.joinv(",", shorts.to_array());
}

private static Gee.List<Gitrlf.Ref> refs_of(Repo repo) throws Error
{
	var location = Gitrlf.Application.discover_repository(repo.path);

	return Gitrlf.Refs.read(Gitrlf.Repository.open(location));
}

private static void test_a_new_local_branch_is_ticked_and_other_new_refs_are_not()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var known = new Gee.HashSet<string>();
		var ticked = new Gee.HashSet<string>();

		foreach (var reference in refs_of(repo))
		{
			known.add(reference.name);
		}

		ticked.add("refs/heads/master");
		ticked.add("refs/tags/v1");
		repo.branch("late");
		repo.git({"tag", "v2"});
		repo.git({"update-ref", "refs/remotes/origin/late", "master"});
		repo.git({"tag", "--delete", "v1"});

		var refs = refs_of(repo);

		assert_cmpstr(names(refs, Gitrlf.Ticks.carry(ticked, known, refs)), CompareOperator.EQ, "late,master");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_detached_head_argument_ticks_the_head_row()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.git({"checkout", "--quiet", "--detach", "master~1"});

		assert_cmpstr(ticks_for(repo, {"HEAD"}), CompareOperator.EQ, "HEAD");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_first_run_ticks_every_ref()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		assert_cmpstr(ticks_for(repo, {}), CompareOperator.EQ, "feature/scan,fix/stamp,master,origin/master,v1");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_glob_ticks_every_matching_branch()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.branch("feature/lidar");

		assert_cmpstr(ticks_for(repo, {"feature/*"}), CompareOperator.EQ, "feature/lidar,feature/scan");
		assert_cmpstr(ticks_for(repo, {"refs/tags/v*"}), CompareOperator.EQ, "v1");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_globs_follow_python()
{
	string[,] cases = {
		{ "feature/*", "feature/a/b", "yes" },
		{ "f?x/*", "fix/stamp", "yes" },
		{ "v[0-9]*", "v1.0", "yes" },
		{ "v[!0-9]*", "v1.0", "no" },
		{ "v[!0-9]*", "vx", "yes" },
		{ "v[^1]*", "v2", "no" },
		{ "v[^1]*", "v^2", "yes" },
		{ "a[b", "a[b", "yes" },
		{ "a\\*", "a\\x", "yes" },
		{ "[]]", "]", "yes" },
		{ "[!]]", "a", "yes" },
		{ "a.b", "axb", "no" },
		{ "*", "", "yes" },
		{ "master", "Master", "no" },
	};

	for (var i = 0; i < cases.length[0]; i++)
	{
		var matched = Gitrlf.Ticks.glob_match(cases[i, 0], cases[i, 1]);

		if (matched != (cases[i, 2] == "yes"))
		{
			Test.fail_printf("glob %s against %s", cases[i, 0], cases[i, 1]);
		}
	}
}

private static void test_head_on_a_branch_ticks_that_branch()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		assert_cmpstr(ticks_for(repo, {"HEAD"}), CompareOperator.EQ, "master");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_options_add_up()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		assert_cmpstr(ticks_for(repo, {"-l", "origin/master"}), CompareOperator.EQ, "feature/scan,fix/stamp,master,origin/master");
		assert_cmpstr(ticks_for(repo, {"-t", "master"}), CompareOperator.EQ, "master,v1");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_unknown_ref_stops_before_the_window_opens()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		string[] argv = { Environment.get_variable("GITRLF_BINARY"), "nope" };
		var env = Environ.unset_variable(Environ.get(), "DISPLAY");
		string output;
		string errors;
		int status;

		Process.spawn_sync(repo.path.get_path(), argv, env, 0, null, out output, out errors, out status);

		assert_cmpint(Process.exit_status(status), CompareOperator.EQ, 1);
		assert_cmpstr(errors, CompareOperator.EQ, "gitrlf: no ref matches 'nope'\n");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static string ticks_for(Repo repo, string[] arguments) throws Error
{
	var refs = refs_of(repo);

	return names(refs, Gitrlf.Ticks.resolve(new Gitrlf.CommandLine(arguments), refs));
}

}
