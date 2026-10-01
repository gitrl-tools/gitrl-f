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

private const Ggit.DiffLineType ADDED = Ggit.DiffLineType.ADDITION;
private const Ggit.DiffLineType CONTEXT = Ggit.DiffLineType.CONTEXT;
private const Ggit.DiffLineType REMOVED = Ggit.DiffLineType.DELETION;

private static string found(Gittree.DiffFind find)
{
	var parts = new string[0];

	for (var i = 0; i < find.length; i++)
	{
		var match = find.get_match(i);

		parts += "%d.%d.%d@%d+%d".printf(match.file, match.side, match.line, match.start, match.length);
	}

	return string.joinv(" ", parts);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gittree/diff-find/a-binary-file-has-no-match", test_a_binary_file_has_no_match);
	Test.add_func("/gittree/diff-find/a-context-line-counts-once-unified-and-twice-split", test_a_context_line_counts_once_unified_and_twice_split);
	Test.add_func("/gittree/diff-find/added-and-removed-lines-match-on-their-own-side", test_added_and_removed_lines_match_on_their_own_side);
	Test.add_func("/gittree/diff-find/case-is-matched-unless-the-switch-is-off", test_case_is_matched_unless_the_switch_is_off);
	Test.add_func("/gittree/diff-find/count-wording", test_count_wording);
	Test.add_func("/gittree/diff-find/expressions-follow-the-switch", test_expressions_follow_the_switch);
	Test.add_func("/gittree/diff-find/files-come-in-the-order-they-are-added", test_files_come_in_the_order_they_are_added);
	Test.add_func("/gittree/diff-find/headers-and-no-newline-markers-do-not-match", test_headers_and_no_newline_markers_do_not_match);
	Test.add_func("/gittree/diff-find/next-and-previous-wrap", test_next_and_previous_wrap);
	Test.add_func("/gittree/diff-find/offsets-count-characters-as-the-pane-shows-them", test_offsets_count_characters_as_the_pane_shows_them);
	Test.add_func("/gittree/diff-find/several-matches-on-one-line", test_several_matches_on_one_line);

	return Test.run();
}

private static void test_a_binary_file_has_no_match()
{
	var find = new Gittree.DiffFind("x", true);

	find.add_file(0, {}, {}, false);

	assert_cmpint(find.length, CompareOperator.EQ, 0);
	assert_cmpstr(find.count_text(), CompareOperator.EQ, "No match");
}

private static void test_a_context_line_counts_once_unified_and_twice_split()
{
	var unified = new Gittree.DiffFind("b", true);
	var split = new Gittree.DiffFind("b", true);

	unified.add_file(0, { CONTEXT }, { "abc\n" }, false);
	split.add_file(0, { CONTEXT }, { "abc\n" }, true);

	assert_cmpstr(found(unified), CompareOperator.EQ, "0.0.0@1+1");
	assert_cmpstr(found(split), CompareOperator.EQ, "0.0.0@1+1 0.1.0@1+1");
}

private static void test_added_and_removed_lines_match_on_their_own_side()
{
	Ggit.DiffLineType[] origins = { REMOVED, ADDED, CONTEXT };
	string[] texts = { "x old\n", "x new\n", "x kept\n" };
	var unified = new Gittree.DiffFind("x", true);
	var split = new Gittree.DiffFind("x", true);

	unified.add_file(0, origins, texts, false);
	split.add_file(0, origins, texts, true);

	assert_cmpstr(found(unified), CompareOperator.EQ, "0.0.0@0+1 0.0.1@0+1 0.0.2@0+1");
	assert_cmpstr(found(split), CompareOperator.EQ, "0.0.0@0+1 0.0.2@0+1 0.1.1@0+1 0.1.2@0+1");
}

private static void test_case_is_matched_unless_the_switch_is_off()
{
	var exact = new Gittree.DiffFind("foo", true);
	var loose = new Gittree.DiffFind("foo", false);
	var accents = new Gittree.DiffFind("école", false);

	exact.add_file(0, { CONTEXT, ADDED }, { "Foo bar\n", "foo\n" }, false);
	loose.add_file(0, { CONTEXT, ADDED }, { "Foo bar\n", "foo\n" }, false);
	accents.add_file(0, { ADDED }, { "ÉCOLE\n" }, false);

	assert_cmpstr(found(exact), CompareOperator.EQ, "0.0.1@0+3");
	assert_cmpstr(found(loose), CompareOperator.EQ, "0.0.0@0+3 0.0.1@0+3");
	assert_cmpstr(found(accents), CompareOperator.EQ, "0.0.0@0+5");
}

private static void test_count_wording()
{
	var empty = new Gittree.DiffFind("", true);
	var none = new Gittree.DiffFind("zzz", true);
	var one = new Gittree.DiffFind("a", true);
	var three = new Gittree.DiffFind("a", true);

	empty.add_file(0, { ADDED }, { "a\n" }, false);
	none.add_file(0, { ADDED }, { "a\n" }, false);
	one.add_file(0, { ADDED }, { "a\n" }, false);
	three.add_file(0, { ADDED, ADDED, ADDED }, { "a\n", "a\n", "a\n" }, false);

	assert_cmpstr(empty.count_text(), CompareOperator.EQ, "");
	assert_cmpint(empty.length, CompareOperator.EQ, 0);
	assert_cmpstr(none.count_text(), CompareOperator.EQ, "No match");
	assert_cmpstr(one.count_text(), CompareOperator.EQ, "1 match");
	assert_cmpstr(three.count_text(), CompareOperator.EQ, "3 matches");

	three.step(1);
	three.step(1);

	assert_cmpstr(three.count_text(), CompareOperator.EQ, "2 of 3");
}

private static void test_expressions_follow_the_switch()
{
	var expression = new Gittree.DiffFind("^ne+d", true, true);
	var bad = new Gittree.DiffFind("(", false, true);

	expression.add_file(0, { ADDED, CONTEXT }, { "need it\n", "a need\n" }, false);
	bad.add_file(0, { ADDED }, { "(\n" }, false);

	assert_cmpstr(found(expression), CompareOperator.EQ, "0.0.0@0+4");
	assert_cmpint(bad.length, CompareOperator.EQ, 0);
	assert_cmpstr(bad.count_text(), CompareOperator.EQ, "Bad regex");
}

private static void test_files_come_in_the_order_they_are_added()
{
	var find = new Gittree.DiffFind("k", true);

	find.add_file(0, { ADDED }, { "k\n" }, false);
	find.add_file(2, { CONTEXT }, { "k\n" }, true);
	find.add_file(3, { REMOVED }, { "k\n" }, false);

	assert_cmpstr(found(find), CompareOperator.EQ, "0.0.0@0+1 2.0.0@0+1 2.1.0@0+1 3.0.0@0+1");
}

private static void test_headers_and_no_newline_markers_do_not_match()
{
	Ggit.DiffLineType[] origins = {
		Ggit.DiffLineType.FILE_HDR,
		Ggit.DiffLineType.HUNK_HDR,
		Ggit.DiffLineType.BINARY,
		Ggit.DiffLineType.CONTEXT_EOFNL,
		Ggit.DiffLineType.ADD_EOFNL,
		Ggit.DiffLineType.DEL_EOFNL
	};
	string[] texts = {
		"diff --git a/newline b/newline\n",
		"@@ -1 +1 @@ newline\n",
		"Binary files differ: newline\n",
		"\n\\ No newline at end of file\n",
		"\n\\ No newline at end of file\n",
		"\n\\ No newline at end of file\n"
	};
	var unified = new Gittree.DiffFind("newline", false);
	var split = new Gittree.DiffFind("newline", false);

	unified.add_file(0, origins, texts, false);
	split.add_file(0, origins, texts, true);

	assert_cmpint(unified.length, CompareOperator.EQ, 0);
	assert_cmpint(split.length, CompareOperator.EQ, 0);
}

private static void test_next_and_previous_wrap()
{
	var forward = new Gittree.DiffFind("a", true);
	var backward = new Gittree.DiffFind("a", true);
	var nothing = new Gittree.DiffFind("z", true);

	forward.add_file(0, { ADDED, ADDED, ADDED }, { "a\n", "a\n", "a\n" }, false);
	backward.add_file(0, { ADDED, ADDED, ADDED }, { "a\n", "a\n", "a\n" }, false);
	nothing.add_file(0, { ADDED }, { "a\n" }, false);

	assert_cmpint(forward.current, CompareOperator.EQ, -1);

	forward.step(1);
	assert_cmpint(forward.current, CompareOperator.EQ, 0);
	forward.step(1);
	forward.step(1);
	assert_cmpint(forward.current, CompareOperator.EQ, 2);
	forward.step(1);
	assert_cmpint(forward.current, CompareOperator.EQ, 0);
	forward.step(-1);
	assert_cmpint(forward.current, CompareOperator.EQ, 2);

	backward.step(-1);
	assert_cmpint(backward.current, CompareOperator.EQ, 2);

	nothing.step(1);
	assert_cmpint(nothing.current, CompareOperator.EQ, -1);
	nothing.step(-1);
	assert_cmpint(nothing.current, CompareOperator.EQ, -1);
}

private static void test_offsets_count_characters_as_the_pane_shows_them()
{
	var accent = new Gittree.DiffFind("x", true);
	var carriage = new Gittree.DiffFind("ab", true);
	var newline = new Gittree.DiffFind("b\n", true);

	accent.add_file(0, { ADDED }, { "café x\n" }, false);
	carriage.add_file(0, { ADDED }, { "a\rb\r\n" }, false);
	newline.add_file(0, { ADDED }, { "ab\n" }, false);

	assert_cmpstr(found(accent), CompareOperator.EQ, "0.0.0@5+1");
	assert_cmpstr(found(carriage), CompareOperator.EQ, "0.0.0@0+2");
	assert_cmpint(newline.length, CompareOperator.EQ, 0);
}

private static void test_several_matches_on_one_line()
{
	var spaced = new Gittree.DiffFind("ab", true);
	var overlapping = new Gittree.DiffFind("aa", true);

	spaced.add_file(0, { CONTEXT }, { "abab ab\n" }, false);
	overlapping.add_file(0, { CONTEXT }, { "aaaaa\n" }, false);

	assert_cmpstr(found(spaced), CompareOperator.EQ, "0.0.0@0+2 0.0.0@2+2 0.0.0@5+2");
	assert_cmpstr(found(overlapping), CompareOperator.EQ, "0.0.0@0+2 0.0.0@2+2");
}

}
