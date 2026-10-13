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

private static string counts(Repo repo, string[] shas)
{
	var ids = new Ggit.OId[0];
	var loop = new MainLoop();
	Gee.Map<Ggit.OId, string>? found = null;

	foreach (var sha in shas)
	{
		ids += new Ggit.OId.from_string(sha);
	}

	Gitrlf.LineCounts.count.begin(repo.path, ids, new Cancellable(), (obj, res) => {
		try
		{
			found = Gitrlf.LineCounts.count.end(res);
		}
		catch (Error e)
		{
			Test.fail_printf("%s", e.message);
		}

		loop.quit();
	});

	loop.run();

	var texts = new string[0];

	foreach (var id in ids)
	{
		texts += found[id];
	}

	return string.joinv(",", texts);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/line-counts/a-merge-counts-against-its-first-parent", test_a_merge_counts_against_its_first_parent);
	Test.add_func("/gitrlf/line-counts/a-rename-or-a-binary-file-adds-no-lines", test_a_rename_or_a_binary_file_adds_no_lines);
	Test.add_func("/gitrlf/line-counts/a-root-commit-adds-all-its-lines", test_a_root_commit_adds_all_its_lines);
	Test.add_func("/gitrlf/line-counts/a-rewrite-adds-and-removes-lines", test_a_rewrite_adds_and_removes_lines);

	return Test.run();
}

private static void test_a_merge_counts_against_its_first_parent()
{
	try
	{
		var repo = Repo.create();

		repo.branched();

		var merge = repo.git({"rev-parse", "master~1"}).strip();

		assert_cmpint(repo.git({"log", "-1", "--format=%P", merge}).strip().split(" ").length, CompareOperator.EQ, 2);
		assert_cmpstr(counts(repo, {merge}), CompareOperator.EQ, "+2/-0");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_rename_or_a_binary_file_adds_no_lines()
{
	try
	{
		var repo = Repo.create();

		repo.commit("first");
		repo.git({"mv", "file", "moved"});
		repo.git({"commit", "--quiet", "-m", "rename"});

		var rename = repo.git({"rev-parse", "HEAD"}).strip();
		var binary = repo.commit_bytes("binary", "blob.bin", { 0, 1, 2, 0 });

		assert_cmpstr(counts(repo, {rename, binary}), CompareOperator.EQ, "+0/-0,+0/-0");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_root_commit_adds_all_its_lines()
{
	try
	{
		var repo = Repo.create();
		var root = repo.commit_bytes("root", "file", "a\nb\nc\n".data);

		assert_cmpstr(counts(repo, {root}), CompareOperator.EQ, "+3/-0");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_rewrite_adds_and_removes_lines()
{
	try
	{
		var repo = Repo.create();
		var first = repo.commit("first");
		var rewrite = repo.commit_bytes("rewrite", "file", "a\nb\nc\n".data);

		assert_cmpstr(counts(repo, {first, rewrite}), CompareOperator.EQ, "+1/-0,+3/-1");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
