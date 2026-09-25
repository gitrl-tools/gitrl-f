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

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/search/count-wording", test_count_wording);
	Test.add_func("/gitree/search/each-field-matches-without-regard-to-case", test_each_field_matches_without_regard_to_case);
	Test.add_func("/gitree/search/marks-keep-the-case-of-the-text", test_marks_keep_the_case_of_the_text);
	Test.add_func("/gitree/search/next-and-previous-wrap", test_next_and_previous_wrap);

	return Test.run();
}

private static void test_count_wording()
{
	assert_cmpstr(Gitree.Search.count_text({}, 0, ""), CompareOperator.EQ, "");
	assert_cmpstr(Gitree.Search.count_text({}, 0, "x"), CompareOperator.EQ, "No match");
	assert_cmpstr(Gitree.Search.count_text({ 3 }, 0, "x"), CompareOperator.EQ, "1 match");
	assert_cmpstr(Gitree.Search.count_text({ 3, 5 }, 0, "x"), CompareOperator.EQ, "2 matches");
	assert_cmpstr(Gitree.Search.count_text({ 3, 5 }, 5, "x"), CompareOperator.EQ, "2 of 2");
	assert_cmpstr(Gitree.Search.count_text({ 3, 5 }, 3, "x"), CompareOperator.EQ, "1 of 2");
}

private static void test_each_field_matches_without_regard_to_case()
{
	try
	{
		var repo = Repo.create();
		repo.git({"-c", "user.name=Ada Lovelace", "-c", "user.email=ada@engine.org", "commit", "--quiet", "--allow-empty", "-m", "Analytical subject\n\nThe body mentions Bernoulli."});

		var repository = Gitree.Repository.open(Gitree.Application.discover_repository(repo.path));
		var commit = repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(repo.git({"rev-parse", "HEAD"}).strip()));
		var hash = commit.get_id().to_string();

		foreach (var needle in new string[] { "analytical", "BERNOULLI", "ada love", "engine.ORG", hash.substring(10, 12), hash.up() })
		{
			assert_true(Gitree.Search.matches(commit, needle));
		}

		assert_false(Gitree.Search.matches(commit, "babbage"));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_marks_keep_the_case_of_the_text()
{
	assert_cmpstr(Gitree.Search.marked("Fix the FIX & fix", "fix"), CompareOperator.EQ,
	              "<span background=\"#fce94f\" foreground=\"#1a1a1a\">Fix</span> the "
	              + "<span background=\"#fce94f\" foreground=\"#1a1a1a\">FIX</span> &amp; "
	              + "<span background=\"#fce94f\" foreground=\"#1a1a1a\">fix</span>");
	assert_cmpstr(Gitree.Search.marked("a <b>", ""), CompareOperator.EQ, "a &lt;b&gt;");
}

private static void test_next_and_previous_wrap()
{
	int[] matches = { 2, 5, 9 };

	assert_cmpint(Gitree.Search.step(matches, 0, 1), CompareOperator.EQ, 2);
	assert_cmpint(Gitree.Search.step(matches, 2, 1), CompareOperator.EQ, 5);
	assert_cmpint(Gitree.Search.step(matches, 9, 1), CompareOperator.EQ, 2);
	assert_cmpint(Gitree.Search.step(matches, 5, -1), CompareOperator.EQ, 2);
	assert_cmpint(Gitree.Search.step(matches, 2, -1), CompareOperator.EQ, 9);
	assert_cmpint(Gitree.Search.step(matches, 0, -1), CompareOperator.EQ, 9);
	assert_cmpint(Gitree.Search.step({}, 0, 1), CompareOperator.EQ, -1);
}

}
