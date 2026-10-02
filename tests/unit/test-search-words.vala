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

private static Gitg.Commit s_commit;

private static Repo s_repo;

private static bool holds(string text, bool match_case = false, bool regex = false)
{
	return new Gitrlf.SearchQuery(text, match_case, regex).matches(s_commit);
}

public static int main(string[] args)
{
	Environment.set_variable("TZ", "UTC", true);
	Test.init(ref args);

	try
	{
		s_repo = Repo.create();
		s_repo.git({"-c", "user.name=Ada Lovelace", "-c", "user.email=ada@engine.org", "commit", "--quiet", "--allow-empty", "-m", "Analytical subject\n\nThe body mentions Bernoulli."});

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(s_repo.path));

		s_commit = repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(s_repo.git({"rev-parse", "HEAD"}).strip()));
	}
	catch (Error e)
	{
		error("%s", e.message);
	}

	Test.add_func("/gitrlf/search-words/a-bad-date-is-a-problem", test_a_bad_date_is_a_problem);
	Test.add_func("/gitrlf/search-words/dates-keep-the-start-of-a-year-month-or-day", test_dates_keep_the_start_of_a_year_month_or_day);
	Test.add_func("/gitrlf/search-words/every-part-must-hold", test_every_part_must_hold);
	Test.add_func("/gitrlf/search-words/marks-go-to-their-columns", test_marks_go_to_their_columns);
	Test.add_func("/gitrlf/search-words/text-with-no-word-is-plain", test_text_with_no_word_is_plain);
	Test.add_func("/gitrlf/search-words/the-switches-apply-to-the-values", test_the_switches_apply_to_the_values);
	Test.add_func("/gitrlf/search-words/unknown-words-are-plain-text", test_unknown_words_are_plain_text);
	Test.add_func("/gitrlf/search-words/words-look-in-their-own-field", test_words_look_in_their_own_field);

	var status = Test.run();

	s_repo.remove();

	return status;
}

private static void test_a_bad_date_is_a_problem()
{
	foreach (var text in new string[] { "after:2026-13", "before:yesterday", "after:2026-02-30", "before:26" })
	{
		var query = new Gitrlf.SearchQuery(text, false, false);

		assert_cmpstr(query.problem, CompareOperator.EQ, "Bad date");
		assert_false(query.matches(s_commit));
	}

	assert_cmpstr(new Gitrlf.SearchQuery("(", false, true).problem, CompareOperator.EQ, "Bad regex");
	assert_null(new Gitrlf.SearchQuery("after:2026-01", false, false).problem);
}

private static void test_dates_keep_the_start_of_a_year_month_or_day()
{
	assert_true(holds("after:2026"));
	assert_true(holds("after:2026-01"));
	assert_true(holds("after:2026-01-01"));
	assert_false(holds("after:2026-01-02"));
	assert_true(holds("after:2025-12"));
	assert_true(holds("before:2026-01-02"));
	assert_true(holds("before:2027"));
	assert_false(holds("before:2026"));
	assert_false(holds("before:2026-01-01"));
	assert_true(holds("after:2026-01 before:2026-02"));
}

private static void test_every_part_must_hold()
{
	assert_true(holds("author:ada after:2026-01 Analytical"));
	assert_false(holds("author:babbage Analytical"));
	assert_false(holds("author:ada Difference"));
	assert_true(holds("author:ada author:lovelace"));
	assert_false(holds("author:ada author:babbage"));
}

private static void test_marks_go_to_their_columns()
{
	var query = new Gitrlf.SearchQuery("author:love message:body Analytic", false, false);
	var mark = "<span background=\"#fce94f\" foreground=\"#1a1a1a\">%s</span>";

	assert_cmpstr(Gitrlf.Search.marked("Ada Lovelace", query.author_marks()), CompareOperator.EQ, "Ada " + mark.printf("Love") + "lace");
	assert_cmpstr(Gitrlf.Search.marked("Analytical subject", query.subject_marks()), CompareOperator.EQ, mark.printf("Analytic") + "al subject");
	assert_cmpstr(Gitrlf.Search.marked("Analytical body", query.subject_marks()), CompareOperator.EQ, mark.printf("Analytic") + "al " + mark.printf("body"));
	assert_cmpstr(Gitrlf.Search.marked("abc", new Gitrlf.SearchQuery("hash:abc", false, false).hash_marks()), CompareOperator.EQ, "abc");
}

private static void test_text_with_no_word_is_plain()
{
	var query = new Gitrlf.SearchQuery("analytical  subject", false, false);

	assert_false(query.is_empty);
	assert_false(query.matches(s_commit));
	assert_true(holds("analytical subject"));
	assert_true(new Gitrlf.SearchQuery("", false, false).is_empty);
	assert_true(new Gitrlf.SearchQuery("   ", false, false).is_empty);
	assert_false(new Gitrlf.SearchQuery("after:2026", false, false).is_empty);
}

private static void test_the_switches_apply_to_the_values()
{
	assert_true(holds("author:lovelace"));
	assert_false(holds("author:lovelace", true));
	assert_true(holds("author:Lovelace", true));
	assert_true(holds("message:\"^the body\"", false, true));
	assert_true(holds("author:\"Ada Lovelace\""));
}

private static void test_unknown_words_are_plain_text()
{
	assert_false(holds("foo:bar"));
	assert_true(holds("subject"));
	assert_true(new Gitrlf.SearchQuery("http://example.org", false, false).author_marks().length == 1);

	var colon = new Gitrlf.SearchQuery("ada@engine.org", false, false);

	assert_true(colon.matches(s_commit));
}

private static void test_words_look_in_their_own_field()
{
	var hash = s_commit.get_id().to_string();

	assert_true(holds("author:lovelace"));
	assert_true(holds("author:engine.org"));
	assert_false(holds("author:Bernoulli"));
	assert_true(holds("message:Bernoulli"));
	assert_true(holds("message:Analytical"));
	assert_false(holds("message:lovelace"));
	assert_true(holds("hash:" + hash.substring(0, 8)));
	assert_false(holds("hash:lovelace"));
}

}
