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

private static string git_log(Repo repo, string directory, string[] paths) throws Error
{
	string[] argv = { "log", "--parents", "--date-order", "--format=%H %P", "--branches", "--remotes", "--tags", "--" };

	foreach (var path in paths)
	{
		argv += directory == "" ? path : directory + "/" + path;
	}

	return repo.git(argv).strip();
}

private static Gitree.History history_for(Repo repo, string directory, string[] paths, out Gee.List<Gitree.Ref> refs) throws Error
{
	var repository = Gitree.Repository.open(Gitree.Application.discover_repository(repo.path));
	var start = directory == "" ? repo.path : repo.path.resolve_relative_path(directory);

	refs = Gitree.Refs.read(repository);

	return new Gitree.History.with_paths(repository, refs, paths, start, false);
}

private static string logged(Gitree.History history, Gitg.Commit[] rows)
{
	var lines = new string[0];

	foreach (var commit in rows)
	{
		var line = commit.get_id().to_string();

		foreach (var parent in history.parents_of(commit))
		{
			line += " " + parent.to_string();
		}

		lines += line;
	}

	return string.joinv("\n", lines);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/path-history/commits-and-parents-are-git-logs", test_commits_and_parents_are_git_logs);
	Test.add_func("/gitree/path-history/history-with-a-path-is-freed", test_history_with_a_path_is_freed);
	Test.add_func("/gitree/path-history/parent-link-under-a-path-limit-goes-to-a-shown-commit", test_parent_link_under_a_path_limit_goes_to_a_shown_commit);
	Test.add_func("/gitree/path-history/path-keeps-only-commits-that-change-it-and-joins-the-graph", test_path_keeps_only_commits_that_change_it_and_joins_the_graph);
	Test.add_func("/gitree/path-history/path-limit-ticks-a-branch-whose-tip-misses-the-path", test_path_limit_ticks_a_branch_whose_tip_misses_the_path);
	Test.add_func("/gitree/path-history/ref-with-nothing-under-the-path-adds-nothing", test_ref_with_nothing_under_the_path_adds_nothing);

	return Test.run();
}

private static string subjects(Gitg.Commit[] rows)
{
	var parts = new string[0];

	foreach (var commit in rows)
	{
		parts += commit.get_subject();
	}

	return string.joinv(",", parts);
}

private static void test_commits_and_parents_are_git_logs()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.commit("sub one", "sub/a");
		repo.commit("sub other", "sub/b");
		repo.commit("sub a again", "sub/a");

		string[] cases = { "|file", "|fix", "|sub", "|file,fix", "sub|a" };

		foreach (var row in cases)
		{
			var parts = row.split("|");
			var paths = parts[1].split(",");
			Gee.List<Gitree.Ref> refs;
			var history = history_for(repo, parts[0], paths, out refs);
			var every = new Ggit.OId[0];

			foreach (var reference in refs)
			{
				every += reference.target;
			}

			var rows = history.tick(every, {});
			var expected = git_log(repo, parts[0], paths);

			assert_cmpstr(logged(history, rows), CompareOperator.EQ, expected);
			assert_cmpint(history.size, CompareOperator.EQ, expected.split("\n").length);
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_history_with_a_path_is_freed()
{
	try
	{
		var repo = Repo.create();
		repo.commit("a one", "a");

		Gee.List<Gitree.Ref> refs;
		Gitree.History? history = history_for(repo, "", {"a"}, out refs);
		var freed = false;

		history.weak_ref(() => { freed = true; });
		history = null;

		assert_true(freed);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_parent_link_under_a_path_limit_goes_to_a_shown_commit()
{
	try
	{
		var repo = Repo.create();
		repo.commit("sub one", "sub/a");
		repo.commit("other", "b");
		repo.commit("sub two", "sub/a");

		Gee.List<Gitree.Ref> refs;
		var history = history_for(repo, "", {"sub"}, out refs);
		var rows = history.tick(tips(refs, {"master"}), {});

		assert_cmpstr(subjects(rows), CompareOperator.EQ, "sub two,sub one");
		assert_cmpint(history.parents_of(rows[0]).length, CompareOperator.EQ, 1);
		assert_true(history.parents_of(rows[0])[0].equal(rows[1].get_id()));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_path_keeps_only_commits_that_change_it_and_joins_the_graph()
{
	try
	{
		var repo = Repo.create();
		repo.commit("touch a", "a");
		repo.commit("touch b", "b");
		repo.commit("touch a again", "a");

		Gee.List<Gitree.Ref> refs;
		var history = history_for(repo, "", {"a"}, out refs);
		var rows = history.tick(tips(refs, {"master"}), Gitree.History.mainline(Gitree.Repository.open(Gitree.Application.discover_repository(repo.path)), true));

		assert_cmpstr(subjects(rows), CompareOperator.EQ, "touch a again,touch a");
		assert_true(history.parents_of(rows[0])[0].equal(rows[1].get_id()));

		var joined = false;

		foreach (var lane in rows[1].get_lanes())
		{
			foreach (var from in lane.from)
			{
				joined = joined || from == rows[0].mylane;
			}
		}

		assert_true(joined);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_path_limit_ticks_a_branch_whose_tip_misses_the_path()
{
	try
	{
		var repo = Repo.create();
		repo.commit("a one", "a");
		repo.commit("b one", "b");
		repo.git({"checkout", "--quiet", "-b", "side"});
		repo.commit("a two", "a");
		repo.commit("b two", "b");

		Gee.List<Gitree.Ref> refs;
		var history = history_for(repo, "", {"a"}, out refs);

		assert_cmpstr(subjects(history.tick(tips(refs, {"master"}), {})), CompareOperator.EQ, "a one");
		assert_cmpstr(subjects(history.tick(tips(refs, {"master", "side"}), {})), CompareOperator.EQ, "a two,a one");

		var start = history.start_of(tips(refs, {"side"})[0]);

		assert_nonnull(start);
		assert_cmpstr(history.lookup(start).get_subject(), CompareOperator.EQ, "a two");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ref_with_nothing_under_the_path_adds_nothing()
{
	try
	{
		var repo = Repo.create();
		repo.commit("a one", "a");
		repo.git({"checkout", "--quiet", "--orphan", "lonely"});
		repo.git({"rm", "--quiet", "-rf", "."});
		repo.commit("b only", "b");
		repo.checkout("master");

		Gee.List<Gitree.Ref> refs;
		var history = history_for(repo, "", {"a"}, out refs);
		var lonely = tips(refs, {"lonely"})[0];

		assert_null(history.start_of(lonely));
		assert_cmpint(history.tick({ lonely }, {}).length, CompareOperator.EQ, 0);
		assert_cmpstr(subjects(history.tick(tips(refs, {"master", "lonely"}), {})), CompareOperator.EQ, "a one");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static Ggit.OId[] tips(Gee.List<Gitree.Ref> refs, string[] shorts)
{
	var ret = new Ggit.OId[0];

	foreach (var reference in refs)
	{
		foreach (var name in shorts)
		{
			if (reference.short_name == name)
			{
				ret += reference.target;
			}
		}
	}

	return ret;
}

}
