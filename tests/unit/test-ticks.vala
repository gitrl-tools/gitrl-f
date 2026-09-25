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

private static string names(Gee.List<Gitree.Ref> refs, Gee.Set<string>? ticks)
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

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/ticks/detached-head-argument-ticks-the-head-row", test_detached_head_argument_ticks_the_head_row);
	Test.add_func("/gitree/ticks/first-run-ticks-every-local-branch-and-nothing-else", test_first_run_ticks_every_local_branch_and_nothing_else);
	Test.add_func("/gitree/ticks/garbled-lines-are-ignored", test_garbled_lines_are_ignored);
	Test.add_func("/gitree/ticks/glob-ticks-every-matching-branch", test_glob_ticks_every_matching_branch);
	Test.add_func("/gitree/ticks/globs-follow-python", test_globs_follow_python);
	Test.add_func("/gitree/ticks/head-on-a-branch-ticks-that-branch", test_head_on_a_branch_ticks_that_branch);
	Test.add_func("/gitree/ticks/kept-ticks-come-back-with-new-local-branches-ticked", test_kept_ticks_come_back_with_new_local_branches_ticked);
	Test.add_func("/gitree/ticks/missing-ticks-file-means-first-run", test_missing_ticks_file_means_first_run);
	Test.add_func("/gitree/ticks/options-add-up", test_options_add_up);
	Test.add_func("/gitree/ticks/unknown-ref-stops-before-the-window-opens", test_unknown_ref_stops_before_the_window_opens);
	Test.add_func("/gitree/ticks/unreadable-file-means-first-run", test_unreadable_file_means_first_run);

	return Test.run();
}

private static Gee.List<Gitree.Ref> refs_of(Repo repo) throws Error
{
	var location = Gitree.Application.discover_repository(repo.path);

	return Gitree.Refs.read(Gitree.Repository.open(location));
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

private static void test_first_run_ticks_every_local_branch_and_nothing_else()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		assert_cmpstr(ticks_for(repo, {}), CompareOperator.EQ, "feature/scan,fix/stamp,master");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_garbled_lines_are_ignored()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var file = repo.path.get_child(".git").get_child("git-tree-ticks");
		FileUtils.set_contents(file.get_path(), "+refs/heads/master\n* refs/heads/master\n- refs/heads/master\nnonsense\n\n");

		var refs = refs_of(repo);

		assert_cmpstr(names(refs, Gitree.Ticks.load(file, refs)), CompareOperator.EQ, "feature/scan,fix/stamp");

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
		var matched = Gitree.Ticks.glob_match(cases[i, 0], cases[i, 1]);

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

private static void test_kept_ticks_come_back_with_new_local_branches_ticked()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var refs = refs_of(repo);
		var kept = new Gee.HashSet<string>();

		foreach (var reference in refs)
		{
			if (reference.short_name == "master" || reference.short_name == "origin/master")
			{
				kept.add(reference.name);
			}
		}

		var file = repo.path.get_child(".git").get_child("git-tree-ticks");
		Gitree.Ticks.save(file, refs, kept);

		repo.branch("new-local");
		repo.git({"update-ref", "refs/remotes/origin/new-remote", "master"});
		repo.delete_branch("fix/stamp");

		refs = refs_of(repo);

		assert_cmpstr(names(refs, Gitree.Ticks.load(file, refs)), CompareOperator.EQ, "master,new-local,origin/master");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_missing_ticks_file_means_first_run()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var refs = refs_of(repo);

		assert_null(Gitree.Ticks.load(repo.path.get_child(".git").get_child("git-tree-ticks"), refs));

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

private static string ticks_for(Repo repo, string[] arguments) throws Error
{
	var refs = refs_of(repo);

	return names(refs, Gitree.Ticks.resolve(new Gitree.CommandLine(arguments), refs, null));
}

private static void test_unknown_ref_stops_before_the_window_opens()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		string[] argv = { Environment.get_variable("GITREE_BINARY"), "nope" };
		var env = Environ.unset_variable(Environ.get(), "DISPLAY");
		string output;
		string errors;
		int status;

		Process.spawn_sync(repo.path.get_path(), argv, env, 0, null, out output, out errors, out status);

		assert_cmpint(Process.exit_status(status), CompareOperator.EQ, 1);
		assert_cmpstr(errors, CompareOperator.EQ, "git tree: no ref matches 'nope'\n");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_unreadable_file_means_first_run()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var file = repo.path.get_child(".git").get_child("git-tree-ticks");
		file.make_directory();

		var refs = refs_of(repo);

		assert_null(Gitree.Ticks.load(file, refs));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
