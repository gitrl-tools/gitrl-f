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

private static string[] all_names(Gee.List<Gitrlf.Ref> refs)
{
	var names = new string[0];

	foreach (var reference in refs)
	{
		names += reference.name;
	}

	return names;
}

private static string[] args_with_paths(string[] arguments, string[] paths)
{
	var all = arguments;

	all += "--";

	foreach (var path in paths)
	{
		all += path;
	}

	return all;
}

private static void check(Repo repo, Gitrlf.History history, Gee.List<Gitrlf.Ref> refs, Gee.Set<string> found, string[] paths, string drawn) throws Error
{
	var rows = ticked(history, refs, all_names(refs));
	var shown = new Gee.HashSet<string>();

	foreach (var commit in rows)
	{
		shown.add(commit.get_id().to_string());
	}

	assert_cmpint(history.size, CompareOperator.EQ, found.size);
	assert_true(shown.size == found.size && shown.contains_all(found));
	assert_cmpstr(lines_of(history, rows), CompareOperator.EQ, joined(repo, paths, found));
	assert_cmpstr(lines_of(history, rows), CompareOperator.EQ, drawn);
}

private static Gitrlf.History filtered(Repo repo, string text, bool ignore_case, string[] paths, out Gee.List<Gitrlf.Ref> refs, out Gee.Set<string> found) throws Error
{
	var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));

	refs = Gitrlf.Refs.read(repository);

	var base_history = paths.length > 0 ? new Gitrlf.History.with_paths(repository, refs, paths, repo.path, false)
	                                    : new Gitrlf.History(repository, refs, false);
	string[] search = { "log", "--branches", "--tags", "--remotes", "--format=%H", "-S" + text };

	if (ignore_case)
	{
		search += "-i";
	}

	var matches = Gitrlf.History.id_set();

	found = new Gee.HashSet<string>();

	foreach (var line in repo.git(args_with_paths(search, paths)).split("\n"))
	{
		if (line != "")
		{
			matches.add(new Ggit.OId.from_string(line));
			found.add(line);
		}
	}

	return new Gitrlf.History.filtered(base_history, matches, refs);
}

private static string joined(Repo repo, string[] paths, Gee.Set<string> found) throws Error
{
	var order = new string[0];
	var parents = new Gee.HashMap<string, string>();
	var subjects = new Gee.HashMap<string, string>();
	string[] log = { "log", "--parents", "--date-order", "--format=%H %P%x1f%s", "--branches", "--tags", "--remotes" };

	foreach (var line in repo.git(args_with_paths(log, paths)).split("\n"))
	{
		if (line == "")
		{
			continue;
		}

		var fields = line.split("\x1f");
		var ids = fields[0].strip().split(" ");

		order += ids[0];
		parents[ids[0]] = string.joinv(" ", ids[1:ids.length]);
		subjects[ids[0]] = fields[1];
	}

	var near = new Gee.HashMap<string, Gee.ArrayList<string>>();

	for (var i = order.length - 1; i >= 0; i--)
	{
		var list = new Gee.ArrayList<string>();

		if (order[i] in found)
		{
			list.add(order[i]);
		}
		else
		{
			list = union_of(parents[order[i]].split(" "), near);
		}

		near[order[i]] = list;
	}

	var lines = new string[0];

	foreach (var id in order)
	{
		if (!(id in found))
		{
			continue;
		}

		var kept = new string[0];
		var through = union_of(parents[id].split(" "), near);

		foreach (var a in through)
		{
			var covered = false;

			foreach (var b in through)
			{
				if (b != a && reaches(b, a, parents, near, found))
				{
					covered = true;
				}
			}

			if (!covered)
			{
				kept += subjects[a];
			}
		}

		lines += "%s>%s".printf(subjects[id], string.joinv(",", kept));
	}

	return string.joinv(" ", lines);
}

private static string lines_of(Gitrlf.History history, Gitg.Commit[] rows)
{
	var lines = new string[0];

	foreach (var commit in rows)
	{
		var names = new string[0];

		foreach (var parent in history.parents_of(commit))
		{
			names += history.lookup(parent).get_subject();
		}

		lines += "%s>%s".printf(commit.get_subject(), string.joinv(",", names));
	}

	return string.joinv(" ", lines);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/filter-history/a-commit-that-only-moves-the-text-is-not-shown", test_a_commit_that_only_moves_the_text_is_not_shown);
	Test.add_func("/gitrlf/filter-history/a-merge-tip-starts-from-the-matches-of-both-sides", test_a_merge_tip_starts_from_the_matches_of_both_sides);
	Test.add_func("/gitrlf/filter-history/a-path-limit-applies-as-well", test_a_path_limit_applies_as_well);
	Test.add_func("/gitrlf/filter-history/a-side-branch-with-no-match-draws-no-second-line", test_a_side_branch_with_no_match_draws_no_second_line);
	Test.add_func("/gitrlf/filter-history/a-straight-line-joins-across-the-commits-left-out", test_a_straight_line_joins_across_the_commits_left_out);
	Test.add_func("/gitrlf/filter-history/case-is-matched-unless-it-is-ignored", test_case_is_matched_unless_it_is_ignored);
	Test.add_func("/gitrlf/filter-history/path-limit-starts-stay-lists-of-one", test_path_limit_starts_stay_lists_of_one);

	return Test.run();
}

private static bool reaches(string from, string target, Gee.HashMap<string, string> parents, Gee.HashMap<string, Gee.ArrayList<string>> near, Gee.Set<string> found)
{
	var stack = new Gee.ArrayList<string>();
	var seen = new Gee.HashSet<string>();

	stack.add(from);

	while (stack.size > 0)
	{
		var id = stack.remove_at(stack.size - 1);

		foreach (var next in union_of(parents[id].split(" "), near))
		{
			if (next == target)
			{
				return true;
			}

			if (seen.add(next))
			{
				stack.add(next);
			}
		}
	}

	return false;
}

private static void set_file(Repo repo, string name, string text, string subject) throws Error
{
	FileUtils.set_contents(repo.path.get_child(name).get_path(), text);
	repo.git({"add", name});
	repo.git({"commit", "--quiet", "-m", subject});
}

private static void test_a_commit_that_only_moves_the_text_is_not_shown()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		set_file(repo, "f", "needle\nplain\n", "a");
		set_file(repo, "f", "plain\nneedle\n", "b");

		var history = filtered(repo, "needle", false, {}, out refs, out found);

		check(repo, history, refs, found, {}, "a>");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_merge_tip_starts_from_the_matches_of_both_sides()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		repo.commit("r", "f", "needle");
		repo.git({"checkout", "--quiet", "-b", "b"});
		repo.commit("b1", "g", "needle");
		repo.checkout("master");
		repo.commit("a1", "h", "needle");
		repo.merge("b");

		var history = filtered(repo, "needle", false, {}, out refs, out found);
		var master = new Ggit.OId.from_string(repo.git({"rev-parse", "master"}).strip());

		check(repo, history, refs, found, {}, "a1>r b1>r r>");
		assert_cmpstr(lines_of(history, ticked(history, refs, {"refs/heads/master"})), CompareOperator.EQ, "a1>r b1>r r>");
		assert_cmpstr(lines_of(history, ticked(history, refs, {"refs/heads/b"})), CompareOperator.EQ, "b1>r r>");
		assert_cmpstr(history.lookup(history.start_of(master)).get_subject(), CompareOperator.EQ, "a1");
		assert_cmpint(history.starts_of(master).length, CompareOperator.EQ, 2);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_path_limit_applies_as_well()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		repo.commit("a", "p", "needle");
		repo.commit("b", "q", "needle");
		repo.commit("c", "p", "plain");
		repo.commit("d", "p", "needle");
		repo.commit("e", "q", "plain");

		var history = filtered(repo, "needle", false, {"p"}, out refs, out found);
		var master = new Ggit.OId.from_string(repo.git({"rev-parse", "master"}).strip());

		check(repo, history, refs, found, {"p"}, "d>a a>");
		assert_cmpstr(history.lookup(history.start_of(master)).get_subject(), CompareOperator.EQ, "d");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_side_branch_with_no_match_draws_no_second_line()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		repo.commit("m1", "f", "needle");
		repo.git({"checkout", "--quiet", "-b", "side"});
		repo.commit("s", "g", "plain");
		repo.checkout("master");
		repo.commit("m2", "f", "needle");
		repo.merge("side");
		repo.commit("t", "f", "needle");

		var history = filtered(repo, "needle", false, {}, out refs, out found);
		var side = new Ggit.OId.from_string(repo.git({"rev-parse", "side"}).strip());

		check(repo, history, refs, found, {}, "t>m2 m2>m1 m1>");
		assert_cmpstr(lines_of(history, ticked(history, refs, {"refs/heads/side"})), CompareOperator.EQ, "m1>");
		assert_cmpstr(history.lookup(history.start_of(side)).get_subject(), CompareOperator.EQ, "m1");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_straight_line_joins_across_the_commits_left_out()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		repo.commit("a", "f", "needle");
		repo.commit("b", "f", "plain");
		repo.commit("c", "f", "needle");
		repo.commit("d", "f", "plain");

		var history = filtered(repo, "needle", false, {}, out refs, out found);
		var master = new Ggit.OId.from_string(repo.git({"rev-parse", "master"}).strip());

		check(repo, history, refs, found, {}, "c>a a>");
		assert_cmpstr(history.lookup(history.start_of(master)).get_subject(), CompareOperator.EQ, "c");
		assert_cmpint(history.position(master), CompareOperator.EQ, 0);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_case_is_matched_unless_it_is_ignored()
{
	try
	{
		var repo = Repo.create();
		Gee.List<Gitrlf.Ref> refs;
		Gee.Set<string> found;

		repo.commit("c1", "f", "Needle");
		repo.commit("c2", "f", "needle");

		var exact = filtered(repo, "needle", false, {}, out refs, out found);

		check(repo, exact, refs, found, {}, "c2>");

		var loose = filtered(repo, "needle", true, {}, out refs, out found);

		check(repo, loose, refs, found, {}, "c2>c1 c1>");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_path_limit_starts_stay_lists_of_one()
{
	try
	{
		var repo = Repo.create();

		repo.commit("a", "p", "one");
		repo.commit("b", "q", "two");

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));
		var refs = Gitrlf.Refs.read(repository);
		var history = new Gitrlf.History.with_paths(repository, refs, {"p"}, repo.path, false);
		var master = new Ggit.OId.from_string(repo.git({"rev-parse", "master"}).strip());

		assert_cmpint(history.starts_of(master).length, CompareOperator.EQ, 1);
		assert_cmpstr(history.lookup(history.start_of(master)).get_subject(), CompareOperator.EQ, "a");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static Gitg.Commit[] ticked(Gitrlf.History history, Gee.List<Gitrlf.Ref> refs, string[] names)
{
	var tips = new Ggit.OId[0];

	foreach (var reference in refs)
	{
		if (reference.name in names)
		{
			tips += reference.target;
		}
	}

	return history.tick(tips, {});
}

private static Gee.ArrayList<string> union_of(string[] parents, Gee.HashMap<string, Gee.ArrayList<string>> near)
{
	var list = new Gee.ArrayList<string>();

	foreach (var parent in parents)
	{
		if (!near.has_key(parent))
		{
			continue;
		}

		foreach (var id in near[parent])
		{
			if (!list.contains(id))
			{
				list.add(id);
			}
		}
	}

	return list;
}

}
