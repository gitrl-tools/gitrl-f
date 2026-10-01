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

private static string changed_lines(Repo repo, string commit) throws Error
{
	var lines = new string[0];

	foreach (var line in repo.git({"show", "--format=", "-U0", commit}).split("\n"))
	{
		if ((line.has_prefix("+") || line.has_prefix("-")) && !line.has_prefix("+++") && !line.has_prefix("---"))
		{
			lines += line.substring(1);
		}
	}

	return string.joinv("\n", lines);
}

private static string found(Gittree.TextMatch match, string haystack)
{
	var parts = new string[0];

	foreach (var span in match.find(haystack))
	{
		parts += "%d+%d".printf(span.start, span.length);
	}

	return string.joinv(" ", parts);
}

public static int main(string[] args)
{
	Test.init(ref args);
	Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");

	Test.add_func("/gittree/text-match/a-bad-expression-gives-the-library-message", test_a_bad_expression_gives_the_library_message);
	Test.add_func("/gittree/text-match/a-match-of-no-characters-is-not-a-match", test_a_match_of_no_characters_is_not_a_match);
	Test.add_func("/gittree/text-match/an-empty-text-matches-nothing", test_an_empty_text_matches_nothing);
	Test.add_func("/gittree/text-match/case-is-ignored-unless-matched", test_case_is_ignored_unless_matched);
	Test.add_func("/gittree/text-match/expressions-find-what-git-log-g-finds", test_expressions_find_what_git_log_g_finds);
	Test.add_func("/gittree/text-match/expressions-read-posix-extended", test_expressions_read_posix_extended);
	Test.add_func("/gittree/text-match/expressions-work-line-by-line", test_expressions_work_line_by_line);
	Test.add_func("/gittree/text-match/offsets-count-characters", test_offsets_count_characters);
	Test.add_func("/gittree/text-match/whole-word-needs-an-edge-on-each-side", test_whole_word_needs_an_edge_on_each_side);

	return Test.run();
}

private static void test_a_bad_expression_gives_the_library_message()
{
	var match = new Gittree.TextMatch("(", false, false, true);

	assert_cmpstr(match.error, CompareOperator.EQ, "Unmatched ( or \\(");
	assert_cmpstr(found(match, "("), CompareOperator.EQ, "");

	assert_null(new Gittree.TextMatch("(", false, false, false).error);
	assert_null(new Gittree.TextMatch("a(b)", false, false, true).error);
}

private static void test_a_match_of_no_characters_is_not_a_match()
{
	var match = new Gittree.TextMatch("x*", true, false, true);

	assert_cmpstr(found(match, "abc"), CompareOperator.EQ, "");
	assert_cmpstr(found(match, "axxbx"), CompareOperator.EQ, "1+2 4+1");
	assert_false(match.matches("abc"));
	assert_true(match.matches("abx"));
}

private static void test_an_empty_text_matches_nothing()
{
	foreach (var regex in new bool[] { false, true })
	{
		var match = new Gittree.TextMatch("", false, false, regex);

		assert_true(match.is_empty);
		assert_null(match.error);
		assert_cmpstr(found(match, "anything"), CompareOperator.EQ, "");
	}

	assert_false(new Gittree.TextMatch("a", false, false, false).is_empty);
}

private static void test_case_is_ignored_unless_matched()
{
	var text = "Parser parser PARSER";

	assert_cmpstr(found(new Gittree.TextMatch("parser", false, false, false), text), CompareOperator.EQ, "0+6 7+6 14+6");
	assert_cmpstr(found(new Gittree.TextMatch("parser", true, false, false), text), CompareOperator.EQ, "7+6");
	assert_cmpstr(found(new Gittree.TextMatch("p[a-z]+r", false, false, true), text), CompareOperator.EQ, "0+6 7+6 14+6");
	assert_cmpstr(found(new Gittree.TextMatch("P[a-z]+r", true, false, true), text), CompareOperator.EQ, "0+6");
}

private static void test_expressions_find_what_git_log_g_finds()
{
	try
	{
		var repo = Repo.create();
		var commits = new string[0];

		commits += repo.commit("one", "f", "alpha 12");
		commits += repo.commit("two", "f", "beta");
		commits += repo.commit("three", "g", "Gamma word");
		commits += repo.commit_bytes("four", "f", "alpha 12\nbeta\nsubword\n".data);
		commits += repo.commit("five", "h", "x");
		commits += repo.commit_bytes("six", "f", "alpha 12\nsubword\n".data);

		string[] expressions = { "\\bword\\b", "[0-9]+", "alpha|gamma", "^beta$", "sub[a-z]+", "Gamma" };

		foreach (var expression in expressions)
		{
			foreach (var match_case in new bool[] { true, false })
			{
				string[] argv = { "log", "--format=%s", "-G" + expression };

				if (!match_case)
				{
					argv += "-i";
				}

				var from_git = repo.git(argv).strip().replace("\n", ",");
				var match = new Gittree.TextMatch(expression, match_case, false, true);
				var ours = new string[0];

				for (var i = commits.length - 1; i >= 0; i--)
				{
					if (match.matches(changed_lines(repo, commits[i])))
					{
						ours += repo.git({"log", "-1", "--format=%s", commits[i]}).strip();
					}
				}

				assert_cmpstr(string.joinv(",", ours), CompareOperator.EQ, from_git);
			}
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_expressions_read_posix_extended()
{
	assert_cmpstr(found(new Gittree.TextMatch("[0-9]+", true, false, true), "a 12 b 345"), CompareOperator.EQ, "2+2 7+3");
	assert_cmpstr(found(new Gittree.TextMatch("cat|dog", true, false, true), "dog and cat"), CompareOperator.EQ, "0+3 8+3");
	assert_cmpstr(found(new Gittree.TextMatch("\\bend\\b", true, false, true), "end bend end"), CompareOperator.EQ, "0+3 9+3");
	assert_cmpstr(found(new Gittree.TextMatch("\\d", true, false, true), "a 1"), CompareOperator.EQ, "");
	assert_cmpstr(found(new Gittree.TextMatch("a.c", true, false, false), "abc a.c"), CompareOperator.EQ, "4+3");
}

private static void test_expressions_work_line_by_line()
{
	var text = "first line\nsecond line";

	assert_cmpstr(found(new Gittree.TextMatch("^second", true, false, true), text), CompareOperator.EQ, "11+6");
	assert_cmpstr(found(new Gittree.TextMatch("line$", true, false, true), text), CompareOperator.EQ, "6+4 18+4");
	assert_cmpstr(found(new Gittree.TextMatch("line.second", true, false, true), text), CompareOperator.EQ, "");
}

private static void test_offsets_count_characters()
{
	var text = "café crème latte";

	assert_cmpstr(found(new Gittree.TextMatch("latte", true, false, false), text), CompareOperator.EQ, "11+5");
	assert_cmpstr(found(new Gittree.TextMatch("latte", true, false, true), text), CompareOperator.EQ, "11+5");
	assert_cmpstr(found(new Gittree.TextMatch("crème", false, false, true), "CAFÉ CRÈME"), CompareOperator.EQ, "5+5");
	assert_cmpstr(found(new Gittree.TextMatch("cr.me", true, false, true), text), CompareOperator.EQ, "5+5");
}

private static void test_whole_word_needs_an_edge_on_each_side()
{
	var text = "word sword words word_x word";

	assert_cmpstr(found(new Gittree.TextMatch("word", true, true, false), text), CompareOperator.EQ, "0+4 24+4");
	assert_cmpstr(found(new Gittree.TextMatch("word", true, true, true), text), CompareOperator.EQ, "0+4 24+4");
	assert_cmpstr(found(new Gittree.TextMatch("w[a-z]+", true, true, true), "a words b"), CompareOperator.EQ, "2+5");
	assert_cmpstr(found(new Gittree.TextMatch("x", true, true, false), "(x) x1 x"), CompareOperator.EQ, "1+1 7+1");
}

}
