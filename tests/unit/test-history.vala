/*
 * This file is part of gittree
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gittree is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gittree is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gittree. If not, see <http://www.gnu.org/licenses/>.
 */namespace GittreeTest
{

private class Opened : Object
{
	public Gittree.History history;
	public Gee.List<Gittree.Ref> refs;
	public Gitg.Repository repository;
}

private static Gitg.Commit[] gitg_rows(Gitg.Repository repository, Ggit.OId[] include, Ggit.OId[] permanent, Ggit.SortMode mode)
{
	var model = new Gitg.CommitModel(repository);
	var loop = new MainLoop();

	model.sort_mode = mode;
	model.set_include(include);
	model.set_permanent_lanes(permanent);
	model.finished.connect(() => loop.quit());
	model.reload();
	loop.run();

	var rows = new Gitg.Commit[0];

	for (uint i = 0; i < model.size(); i++)
	{
		rows += model[i];
	}

	return rows;
}

private static string ids(Ggit.OId[] oids)
{
	var parts = new string[0];

	foreach (var oid in oids)
	{
		parts += oid.to_string();
	}

	return string.joinv(",", parts);
}

private static string lanes_of(Gitg.Commit[] rows)
{
	var text = new StringBuilder();

	foreach (var commit in rows)
	{
		text.append_printf("%s %u:", commit.get_id().to_string(), commit.mylane);

		foreach (var lane in commit.get_lanes())
		{
			text.append_printf(" %u,%d", lane.color.idx, (int)lane.tag);

			foreach (var from in lane.from)
			{
				text.append_printf(",%d", from);
			}
		}

		text.append("\n");
	}

	return text.str;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gittree/history/commits-a-ticked-branch-shares-with-an-unticked-one-are-drawn", test_commits_a_ticked_branch_shares_with_an_unticked_one_are_drawn);
	Test.add_func("/gittree/history/count-is-rows-of-commits", test_count_is_rows_of_commits);
	Test.add_func("/gittree/history/graph-lines-join-from-row-to-row", test_graph_lines_join_from_row_to_row);
	Test.add_func("/gittree/history/lanes-are-gitgs", test_lanes_are_gitgs);
	Test.add_func("/gittree/history/long-history-folds-a-lane", test_long_history_folds_a_lane);
	Test.add_func("/gittree/history/mainline-is-gitgs", test_mainline_is_gitgs);
	Test.add_func("/gittree/history/merge-sends-a-line-to-each-parent", test_merge_sends_a_line_to_each_parent);
	Test.add_func("/gittree/history/only-commits-that-a-ticked-ref-reaches-are-drawn", test_only_commits_that_a_ticked_ref_reaches_are_drawn);
	Test.add_func("/gittree/history/order-is-git-logs", test_order_is_git_logs);
	Test.add_func("/gittree/history/shallow-boundary-ends-the-history", test_shallow_boundary_ends_the_history);
	Test.add_func("/gittree/history/ticking-does-not-read-the-repository-again", test_ticking_does_not_read_the_repository_again);
	Test.add_func("/gittree/history/topological-order-keeps-children-above-parents", test_topological_order_keeps_children_above_parents);

	return Test.run();
}

private static Opened open(File path, bool topological = false) throws Error
{
	var opened = new Opened();

	opened.repository = Gittree.Repository.open(Gittree.Application.discover_repository(path));
	opened.refs = Gittree.Refs.read(opened.repository);
	opened.history = new Gittree.History(opened.repository, opened.refs, topological);

	return opened;
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

private static void test_commits_a_ticked_branch_shares_with_an_unticked_one_are_drawn()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var shown = subjects(opened.history.tick(tips(opened, {"master"}), {}));

		assert_true("fix one" in shown);
		assert_true("fix two" in shown);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_count_is_rows_of_commits()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);

		assert_cmpint(opened.history.size, CompareOperator.EQ, int.parse(repo.git({"rev-list", "--count", "--all"}).strip()));
		assert_cmpint(opened.history.tick(tips(opened, {"feature/scan"}), {}).length, CompareOperator.EQ, 3);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_graph_lines_join_from_row_to_row()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var rows = opened.history.tick(tips(opened, {"master", "feature/scan", "fix/stamp", "origin/master", "v1"}), {});

		foreach (var lane in rows[0].get_lanes())
		{
			assert_cmpint((int)lane.from.length(), CompareOperator.EQ, 0);
		}

		for (var i = 0; i + 1 < rows.length; i++)
		{
			var above = rows[i].get_lanes().length();
			var arriving = new Gee.HashSet<int>();

			foreach (var lane in rows[i + 1].get_lanes())
			{
				foreach (var from in lane.from)
				{
					assert_cmpint(from, CompareOperator.LT, (int)above);
					arriving.add(from);
				}
			}

			var index = 0;

			foreach (var lane in rows[i].get_lanes())
			{
				var ends = (lane.tag & Gitg.LaneTag.END) != 0;
				var root = index == rows[i].mylane && rows[i].get_parents().size == 0;

				if (!ends && !root)
				{
					assert_true(arriving.contains(index));
				}

				index++;
			}

			assert_cmpuint(rows[i].mylane, CompareOperator.LT, above);
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_lanes_are_gitgs()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.checkout("feature/scan");

		var opened = open(repo.path);
		var mainline = Gittree.History.mainline(opened.repository, true);

		string[] ticks = {
			"master,feature/scan,fix/stamp,origin/master,v1",
			"feature/scan",
			"fix/stamp",
			"v1",
			"master",
		};

		foreach (var names in ticks)
		{
			var chosen = tips(opened, names.split(","));
			var ours = lanes_of(opened.history.tick(chosen, mainline));
			var gitgs = lanes_of(gitg_rows(opened.repository, chosen, mainline, Ggit.SortMode.TOPOLOGICAL | Ggit.SortMode.TIME));

			assert_cmpstr(ours, CompareOperator.EQ, gitgs);
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_long_history_folds_a_lane()
{
	try
	{
		var repo = Repo.create();
		repo.commit("base");
		repo.branch("side");

		for (var i = 0; i < 60; i++)
		{
			repo.commit("master %d".printf(i));
		}

		repo.checkout("side");
		repo.commit("side one", "side");
		repo.checkout("master");

		var opened = open(repo.path);
		var chosen = tips(opened, {"master", "side"});
		var mainline = Gittree.History.mainline(opened.repository, true);
		var rows = opened.history.tick(chosen, mainline);
		var folded = false;

		foreach (var commit in rows)
		{
			foreach (var lane in commit.get_lanes())
			{
				folded = folded || (lane.tag & Gitg.LaneTag.END) != 0;
			}
		}

		assert_true(folded);
		assert_cmpstr(lanes_of(rows), CompareOperator.EQ,
		              lanes_of(gitg_rows(opened.repository, chosen, mainline, Ggit.SortMode.TOPOLOGICAL | Ggit.SortMode.TIME)));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_mainline_is_gitgs()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.checkout("feature/scan");

		var opened = open(repo.path);
		var head = repo.git({"rev-parse", "HEAD"}).strip();
		var master = repo.git({"rev-parse", "master"}).strip();
		var fix = repo.git({"rev-parse", "fix/stamp"}).strip();

		assert_cmpstr(ids(Gittree.History.mainline(opened.repository, true)), CompareOperator.EQ, head);
		assert_cmpstr(ids(Gittree.History.mainline(opened.repository, false)), CompareOperator.EQ, "");

		repo.git({"config", "init.defaultBranch", "master"});
		assert_cmpstr(ids(Gittree.History.mainline(opened.repository, true)), CompareOperator.EQ, master + "," + head);

		repo.git({"config", "gitg.mainline", "refs/heads/fix/stamp,refs/heads/nope,refs/heads/master"});
		assert_cmpstr(ids(Gittree.History.mainline(opened.repository, true)), CompareOperator.EQ, fix + "," + master + "," + head);

		repo.checkout("master");
		assert_cmpstr(ids(Gittree.History.mainline(opened.repository, true)), CompareOperator.EQ, fix + "," + master);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_merge_sends_a_line_to_each_parent()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var rows = opened.history.tick(tips(opened, {"master"}), {});
		var found = false;

		for (var i = 0; i + 1 < rows.length; i++)
		{
			if (rows[i].get_parents().size != 2)
			{
				continue;
			}

			var lines = 0;

			foreach (var lane in rows[i + 1].get_lanes())
			{
				foreach (var from in lane.from)
				{
					if (from == rows[i].mylane)
					{
						lines++;
					}
				}
			}

			assert_cmpint(lines, CompareOperator.EQ, 2);
			found = true;
		}

		assert_true(found);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_only_commits_that_a_ticked_ref_reaches_are_drawn()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var mainline = Gittree.History.mainline(opened.repository, true);

		assert_false("feature one" in subjects(opened.history.tick(tips(opened, {"master"}), mainline)));
		assert_cmpstr(subjects(opened.history.tick(tips(opened, {"feature/scan"}), mainline)), CompareOperator.EQ,
		              "feature one,base two,base one");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_order_is_git_logs()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var rows = opened.history.tick(tips(opened, {"master", "feature/scan", "fix/stamp", "origin/master", "v1"}), {});
		var ours = new string[0];

		foreach (var commit in rows)
		{
			ours += commit.get_id().to_string();
		}

		var theirs = repo.git({"log", "--date-order", "--format=%H", "--branches", "--remotes", "--tags"}).strip();

		assert_cmpstr(string.joinv("\n", ours), CompareOperator.EQ, theirs);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_shallow_boundary_ends_the_history()
{
	try
	{
		var repo = Repo.create();
		repo.commit("one");
		repo.commit("two");
		repo.git({"clone", "--quiet", "--depth", "1", "file://" + repo.path.get_path(), "shallow"});

		var opened = open(repo.path.get_child("shallow"));
		var rows = opened.history.tick(tips(opened, {"master"}), {});

		assert_cmpstr(subjects(rows), CompareOperator.EQ, "two");
		assert_cmpint(opened.history.size, CompareOperator.EQ, 1);
		assert_cmpint(opened.history.parents_of(rows[0]).length, CompareOperator.EQ, 0);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticking_does_not_read_the_repository_again()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var opened = open(repo.path);
		var moved = repo.path.get_parent().get_child(repo.path.get_basename() + "-moved");

		repo.path.move(moved, FileCopyFlags.NONE);

		var shown = subjects(opened.history.tick(tips(opened, {"master", "feature/scan"}), {}));

		moved.move(repo.path, FileCopyFlags.NONE);

		assert_true("feature one" in shown);
		assert_true("master four" in shown);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_topological_order_keeps_children_above_parents()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.checkout("feature/scan");
		repo.commit("feature two", "feature");
		repo.checkout("master");
		repo.git({"commit", "--quiet", "--allow-empty", "--date=@1", "-m", "old date on top"});

		var timed = open(repo.path, false);
		var topological = open(repo.path, true);
		var all = "master,feature/scan,fix/stamp,origin/master,v1".split(",");
		var rows = topological.history.tick(tips(topological, all), {});
		var seen = new Gee.HashSet<string>();

		foreach (var commit in rows)
		{
			foreach (var parent in topological.history.parents_of(commit))
			{
				assert_false(seen.contains(parent.to_string()));
			}

			seen.add(commit.get_id().to_string());
		}

		assert_cmpint(rows.length, CompareOperator.EQ, timed.history.tick(tips(timed, all), {}).length);

		repo.remove();

		var interleaved = Repo.create();
		interleaved.commit("base");
		interleaved.commit("master one");
		interleaved.git({"checkout", "--quiet", "-b", "side", "master~1"});
		interleaved.commit("side one", "side");
		interleaved.commit("side two", "side");
		interleaved.checkout("master");
		interleaved.commit("master two");

		var by_time = open(interleaved.path, false);
		var by_parents = open(interleaved.path, true);
		string[] both = {"master", "side"};

		assert_cmpstr(subjects(by_time.history.tick(tips(by_time, both), {})), CompareOperator.EQ, "master two,side two,side one,master one,base");
		assert_cmpstr(subjects(by_parents.history.tick(tips(by_parents, both), {})), CompareOperator.NE, "master two,side two,side one,master one,base");

		interleaved.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static Ggit.OId[] tips(Opened opened, string[] shorts)
{
	var ret = new Ggit.OId[0];

	foreach (var reference in opened.refs)
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
