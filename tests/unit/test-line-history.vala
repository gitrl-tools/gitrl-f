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
 */

namespace GittreeTest
{

private const Ggit.DiffLineType ADDED = Ggit.DiffLineType.ADDITION;
private const Ggit.DiffLineType CONTEXT = Ggit.DiffLineType.CONTEXT;
private const Ggit.DiffLineType REMOVED = Ggit.DiffLineType.DELETION;

private const Ggit.DiffLineType[] ORIGINS = { CONTEXT, REMOVED, ADDED, ADDED, CONTEXT };
private const int[] OLD_NUMBERS = { 1, 2, -1, -1, 3 };
private const int[] NEW_NUMBERS = { 1, -1, 2, 3, 4 };

private static string range(Gittree.LineHistory? lines)
{
	if (lines == null)
	{
		return "none";
	}

	return "%d-%d%s".printf(lines.start, lines.end, lines.from_parent ? " parent" : "");
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gittree/line-history/a-click-takes-the-line-under-it", test_a_click_takes_the_line_under_it);
	Test.add_func("/gittree/line-history/each-half-of-the-split-view-takes-its-own-side", test_each_half_of_the_split_view_takes_its_own_side);
	Test.add_func("/gittree/line-history/removed-lines-alone-dig-from-the-parent", test_removed_lines_alone_dig_from_the_parent);
	Test.add_func("/gittree/line-history/the-commits-are-those-of-git-log-l", test_the_commits_are_those_of_git_log_l);
	Test.add_func("/gittree/line-history/the-new-side-wins-in-the-unified-view", test_the_new_side_wins_in_the_unified_view);

	return Test.run();
}

private static void test_a_click_takes_the_line_under_it()
{
	int[] offsets = { 0, 10, 20, 30, 40 };

	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 25, 25, 0, false)), CompareOperator.EQ, "2-2");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 40, 40, 0, false)), CompareOperator.EQ, "4-4");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 99, 99, 0, false)), CompareOperator.EQ, "4-4");
}

private static void test_each_half_of_the_split_view_takes_its_own_side()
{
	int[] left = { 0, 10, -1, -1, 20 };
	int[] right = { 0, -1, 10, 20, 30 };

	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, left, 0, 25, 0, true)), CompareOperator.EQ, "1-3 parent");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, right, 10, 15, 1, true)), CompareOperator.EQ, "2-2");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, right, 0, 5, 1, true)), CompareOperator.EQ, "1-1");
}

private static void test_removed_lines_alone_dig_from_the_parent()
{
	int[] offsets = { 0, 10, 20, 30, 40 };

	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 12, 18, 0, false)), CompareOperator.EQ, "2-2 parent");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 12, 12, 0, false)), CompareOperator.EQ, "2-2 parent");
}

private static void test_the_commits_are_those_of_git_log_l()
{
	try
	{
		var repo = Repo.create();

		repo.commit_bytes("one", "f.c", "a\nb\nc\nd\n".data);
		repo.commit_bytes("two", "f.c", "a\nB\nc\nd\n".data);
		repo.commit_bytes("three", "f.c", "a\nB\nc\nD\n".data);
		repo.commit_bytes("four", "g.c", "x\n".data);
		repo.git({"mv", "f.c", "h.c"});
		repo.git({"commit", "--quiet", "-m", "five"});

		var head = repo.git({"rev-parse", "HEAD"}).strip();
		var expected = repo.git({"log", "--format=%s", "-s", "-L2,2:h.c", head}).strip().replace("\n", ",");
		var loop = new MainLoop();
		Gee.Set<Ggit.OId>? found = null;

		Gittree.LineHistory.run.begin(repo.path, new Ggit.OId.from_string(head), "h.c", 2, 2, new Cancellable(), (obj, res) => {
			try
			{
				found = Gittree.LineHistory.run.end(res);
			}
			catch (Error e)
			{
				Test.fail_printf("%s", e.message);
			}

			loop.quit();
		});

		loop.run();

		var subjects = new string[0];

		foreach (var line in repo.git({"log", "--format=%H %s", head}).strip().split("\n"))
		{
			if (found.contains(new Ggit.OId.from_string(line.substring(0, 40))))
			{
				subjects += line.substring(41);
			}
		}

		assert_cmpstr(string.joinv(",", subjects), CompareOperator.EQ, expected);
		assert_cmpstr(expected, CompareOperator.EQ, "two,one");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_new_side_wins_in_the_unified_view()
{
	int[] offsets = { 0, 10, 20, 30, 40 };

	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 5, 35, 0, false)), CompareOperator.EQ, "1-3");
	assert_cmpstr(range(Gittree.LineHistory.of_view(ORIGINS, OLD_NUMBERS, NEW_NUMBERS, offsets, 0, 45, 0, false)), CompareOperator.EQ, "1-4");
}

}
