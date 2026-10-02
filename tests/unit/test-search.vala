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

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/search/count-wording", test_count_wording);
	Test.add_func("/gitrlf/search/each-field-matches-without-regard-to-case", test_each_field_matches_without_regard_to_case);
	Test.add_func("/gitrlf/search/marks-follow-the-switches", test_marks_follow_the_switches);
	Test.add_func("/gitrlf/search/marks-keep-the-case-of-the-text", test_marks_keep_the_case_of_the_text);
	Test.add_func("/gitrlf/search/the-switches-narrow-the-fields", test_the_switches_narrow_the_fields);
	Test.add_func("/gitrlf/search/next-and-previous-wrap", test_next_and_previous_wrap);

	return Test.run();
}

private static Gitrlf.TextMatch plain(string text)
{
	return new Gitrlf.TextMatch(text, false, false);
}

private static void test_count_wording()
{
	assert_cmpstr(Gitrlf.Search.count_text({}, 0, true, null), CompareOperator.EQ, "");
	assert_cmpstr(Gitrlf.Search.count_text({}, 0, false, null), CompareOperator.EQ, "No match");
	assert_cmpstr(Gitrlf.Search.count_text({ 3 }, 0, false, null), CompareOperator.EQ, "1 match");
	assert_cmpstr(Gitrlf.Search.count_text({ 3, 5 }, 0, false, null), CompareOperator.EQ, "2 matches");
	assert_cmpstr(Gitrlf.Search.count_text({ 3, 5 }, 5, false, null), CompareOperator.EQ, "2 of 2");
	assert_cmpstr(Gitrlf.Search.count_text({ 3, 5 }, 3, false, null), CompareOperator.EQ, "1 of 2");
	assert_cmpstr(Gitrlf.Search.count_text({}, 0, false, "Bad regex"), CompareOperator.EQ, "Bad regex");
}

private static void test_each_field_matches_without_regard_to_case()
{
	try
	{
		var repo = Repo.create();
		repo.git({"-c", "user.name=Ada Lovelace", "-c", "user.email=ada@engine.org", "commit", "--quiet", "--allow-empty", "-m", "Analytical subject\n\nThe body mentions Bernoulli."});

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));
		var commit = repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(repo.git({"rev-parse", "HEAD"}).strip()));
		var hash = commit.get_id().to_string();

		foreach (var needle in new string[] { "analytical", "BERNOULLI", "ada love", "engine.ORG", hash.substring(10, 12), hash.up() })
		{
			assert_true(Gitrlf.Search.matches(commit, plain(needle)));
		}

		assert_false(Gitrlf.Search.matches(commit, plain("babbage")));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_marks_follow_the_switches()
{
	var mark = "<span background=\"#fce94f\" foreground=\"#1a1a1a\">%s</span>";

	assert_cmpstr(Gitrlf.Search.marked("a1 <b22>", { new Gitrlf.TextMatch("[0-9]+", true, true) }), CompareOperator.EQ,
	              "a" + mark.printf("1") + " &lt;b" + mark.printf("22") + "&gt;");
	assert_cmpstr(Gitrlf.Search.marked("Fix fix", { new Gitrlf.TextMatch("fix", true, false) }), CompareOperator.EQ,
	              "Fix " + mark.printf("fix"));
}

private static void test_marks_keep_the_case_of_the_text()
{
	assert_cmpstr(Gitrlf.Search.marked("Fix the FIX & fix", { plain("fix") }), CompareOperator.EQ,
	              "<span background=\"#fce94f\" foreground=\"#1a1a1a\">Fix</span> the "
	              + "<span background=\"#fce94f\" foreground=\"#1a1a1a\">FIX</span> &amp; "
	              + "<span background=\"#fce94f\" foreground=\"#1a1a1a\">fix</span>");
	assert_cmpstr(Gitrlf.Search.marked("a <b>", { plain("") }), CompareOperator.EQ, "a &lt;b&gt;");
}

private static void test_next_and_previous_wrap()
{
	int[] matches = { 2, 5, 9 };

	assert_cmpint(Gitrlf.Search.step(matches, 0, 1), CompareOperator.EQ, 2);
	assert_cmpint(Gitrlf.Search.step(matches, 2, 1), CompareOperator.EQ, 5);
	assert_cmpint(Gitrlf.Search.step(matches, 9, 1), CompareOperator.EQ, 2);
	assert_cmpint(Gitrlf.Search.step(matches, 5, -1), CompareOperator.EQ, 2);
	assert_cmpint(Gitrlf.Search.step(matches, 2, -1), CompareOperator.EQ, 9);
	assert_cmpint(Gitrlf.Search.step(matches, 0, -1), CompareOperator.EQ, 9);
	assert_cmpint(Gitrlf.Search.step({}, 0, 1), CompareOperator.EQ, -1);
}

private static void test_the_switches_narrow_the_fields()
{
	try
	{
		var repo = Repo.create();
		repo.git({"-c", "user.name=Ada Lovelace", "-c", "user.email=ada@engine.org", "commit", "--quiet", "--allow-empty", "-m", "Analytical subject\n\nThe body mentions Bernoulli."});

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));
		var commit = repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(repo.git({"rev-parse", "HEAD"}).strip()));

		assert_true(Gitrlf.Search.matches(commit, new Gitrlf.TextMatch("Analytical", true, false)));
		assert_false(Gitrlf.Search.matches(commit, new Gitrlf.TextMatch("analytical", true, false)));
		assert_true(Gitrlf.Search.matches(commit, new Gitrlf.TextMatch("^the body", false, true)));
		assert_false(Gitrlf.Search.matches(commit, new Gitrlf.TextMatch("subject.the", false, true)));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
