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

private const string ONE = "1111111111111111111111111111111111111111";
private const string TWO = "2222222222222222222222222222222222222222";
private const string THREE = "3333333333333333333333333333333333333333";
private const string FOUR = "4444444444444444444444444444444444444444";

private static Gitrlf.Ref branch(string name, string target = ONE, bool head = false)
{
	return new Gitrlf.Ref("refs/heads/" + name, name, Gitrlf.RefKind.LOCAL, "", new Ggit.OId.from_string(target), head);
}

private static string colours_of(Gitrlf.BranchColours colours)
{
	var names = new Gee.ArrayList<string>();

	foreach (var entry in colours.saved.entries)
	{
		names.add("%s:%d".printf(entry.key, entry.value));
	}

	names.sort();

	return string.joinv(",", names.to_array());
}

private static Gee.Set<string> every_name(Gee.List<Gitrlf.Ref> refs)
{
	var names = new Gee.HashSet<string>();

	foreach (var reference in refs)
	{
		names.add(reference.name);
	}

	return names;
}

private static string line_of(Gee.Map<Ggit.OId, Gitg.Color> lines, string target)
{
	var id = new Ggit.OId.from_string(target);

	return lines.has_key(id) ? lines[id].idx.to_string() : "none";
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/branch-colours/a-branch-keeps-its-colour-when-others-come", test_a_branch_keeps_its_colour_when_others_come);
	Test.add_func("/gitrlf/branch-colours/a-branch-may-be-deep-blue", test_a_branch_may_be_deep_blue);
	Test.add_func("/gitrlf/branch-colours/a-branch-saved-past-the-last-colour-takes-another", test_a_branch_saved_past_the_last_colour_takes_another);
	Test.add_func("/gitrlf/branch-colours/a-deleted-branch-gives-its-colour-back", test_a_deleted_branch_gives_its_colour_back);
	Test.add_func("/gitrlf/branch-colours/a-line-shows-the-colour-of-a-ticked-branch-only", test_a_line_shows_the_colour_of_a_ticked_branch_only);
	Test.add_func("/gitrlf/branch-colours/a-line-takes-the-colour-of-its-first-branch-by-name", test_a_line_takes_the_colour_of_its_first_branch_by_name);
	Test.add_func("/gitrlf/branch-colours/a-new-branch-takes-the-least-used-colour", test_a_new_branch_takes_the_least_used_colour);
	Test.add_func("/gitrlf/branch-colours/a-remote-branch-shares-the-colour-of-its-local-twin", test_a_remote_branch_shares_the_colour_of_its_local_twin);
	Test.add_func("/gitrlf/branch-colours/a-checkout-changes-no-line", test_a_checkout_changes_no_line);
	Test.add_func("/gitrlf/branch-colours/branches-take-every-colour-in-turn", test_branches_take_every_colour_in_turn);
	Test.add_func("/gitrlf/branch-colours/new-branches-take-colours-in-name-order", test_new_branches_take_colours_in_name_order);

	return Test.run();
}

private static Gitrlf.Ref remote(string short_name, string target)
{
	return new Gitrlf.Ref("refs/remotes/" + short_name, short_name, Gitrlf.RefKind.REMOTE, short_name.split("/")[0], new Ggit.OId.from_string(target), false);
}

private static Gee.Map<string, int> saved_of(string[] pairs)
{
	var saved = new Gee.HashMap<string, int>();

	foreach (var pair in pairs)
	{
		var parts = pair.split(":");

		saved[parts[0]] = int.parse(parts[1]);
	}

	return saved;
}

private static void test_a_branch_keeps_its_colour_when_others_come()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha"));
	refs.add(branch("beta"));
	refs.add(branch("gamma"));

	var colours = new Gitrlf.BranchColours(saved_of({"beta:4"}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "alpha:0,beta:4,gamma:1");
}

private static void test_a_branch_may_be_deep_blue()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha"));
	refs.add(branch("beta"));

	var colours = new Gitrlf.BranchColours(saved_of({"alpha:0", "beta:1"}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "alpha:0,beta:1");
}

private static void test_a_branch_saved_past_the_last_colour_takes_another()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha"));
	refs.add(branch("beta"));

	var colours = new Gitrlf.BranchColours(saved_of({"alpha:%u".printf(Gitg.Color.size()), "beta:0"}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "alpha:1,beta:0");
}

private static void test_a_checkout_changes_no_line()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha", ONE));
	refs.add(branch("beta", TWO));
	refs.add(branch("gamma", THREE));

	var colours = new Gitrlf.BranchColours(saved_of({"alpha:3", "beta:5"}), refs);
	var ticks = every_name(refs);
	var lines = new string[0];

	foreach (var head in new string[] { "alpha", "beta", "gamma" })
	{
		var checked_out = new Gee.ArrayList<Gitrlf.Ref>();

		checked_out.add(branch("alpha", ONE, head == "alpha"));
		checked_out.add(branch("beta", TWO, head == "beta"));
		checked_out.add(branch("gamma", THREE, head == "gamma"));

		var tips = colours.of_tips(checked_out, ticks);

		lines += string.joinv(",", { line_of(tips, ONE), line_of(tips, TWO), line_of(tips, THREE) });
	}

	assert_cmpstr(lines[0], CompareOperator.EQ, "3,5,0");
	assert_cmpstr(lines[1], CompareOperator.EQ, lines[0]);
	assert_cmpstr(lines[2], CompareOperator.EQ, lines[0]);

	var detached = new Gee.ArrayList<Gitrlf.Ref>();
	detached.add(new Gitrlf.Ref("HEAD", "HEAD", Gitrlf.RefKind.LOCAL, "", new Ggit.OId.from_string(FOUR), true));
	detached.add(branch("alpha", ONE));

	var tips = new Gitrlf.BranchColours(saved_of({"alpha:3"}), detached).of_tips(detached, ticks);

	assert_cmpstr(line_of(tips, FOUR), CompareOperator.EQ, "none");
	assert_cmpstr(line_of(tips, ONE), CompareOperator.EQ, "3");
}

private static void test_a_deleted_branch_gives_its_colour_back()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha"));
	refs.add(branch("delta"));

	var colours = new Gitrlf.BranchColours(saved_of({"alpha:0", "gone:1"}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "alpha:0,delta:1");
}

private static void test_a_line_shows_the_colour_of_a_ticked_branch_only()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha", ONE));
	refs.add(branch("beta", ONE));
	refs.add(branch("gamma", TWO));

	var colours = new Gitrlf.BranchColours(saved_of({}), refs);
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/beta");

	var lines = colours.of_tips(refs, ticks);

	assert_cmpstr(line_of(lines, ONE), CompareOperator.EQ, "1");
	assert_cmpstr(line_of(lines, TWO), CompareOperator.EQ, "none");
}

private static void test_a_line_takes_the_colour_of_its_first_branch_by_name()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("beta", ONE));
	refs.add(branch("alpha", ONE));
	refs.add(branch("zeta", TWO));
	refs.add(branch("master", TWO));

	var colours = new Gitrlf.BranchColours(saved_of({"alpha:3", "beta:1", "zeta:2"}), refs);
	var lines = colours.of_tips(refs, every_name(refs));

	assert_cmpstr(line_of(lines, ONE), CompareOperator.EQ, "3");
	assert_cmpstr(line_of(lines, TWO), CompareOperator.EQ, "0");
}

private static void test_a_new_branch_takes_the_least_used_colour()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();

	foreach (var name in new string[] { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" })
	{
		refs.add(branch(name));
	}

	var colours = new Gitrlf.BranchColours(saved_of({"a:0", "b:1", "c:2", "d:3", "e:4", "f:5", "g:6", "h:0", "i:2"}), refs);

	assert_cmpint(colours.of_branch("j"), CompareOperator.EQ, 1);
}

private static void test_a_remote_branch_shares_the_colour_of_its_local_twin()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("alpha", ONE));
	refs.add(branch("master", ONE));
	refs.add(remote("origin/alpha", TWO));
	refs.add(remote("origin/lonely", THREE));
	refs.add(remote("origin/master", FOUR));

	var colours = new Gitrlf.BranchColours(saved_of({}), refs);
	var lines = colours.of_tips(refs, every_name(refs));

	assert_cmpstr(line_of(lines, TWO), CompareOperator.EQ, "0");
	assert_cmpstr(line_of(lines, THREE), CompareOperator.EQ, "none");
	assert_cmpstr(line_of(lines, FOUR), CompareOperator.EQ, "1");
}

private static void test_branches_take_every_colour_in_turn()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();

	foreach (var name in new string[] { "a", "b", "c", "d", "e", "f", "g", "h", "i" })
	{
		refs.add(branch(name));
	}

	var colours = new Gitrlf.BranchColours(saved_of({}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "a:0,b:1,c:2,d:3,e:4,f:5,g:6,h:0,i:1");
}

private static void test_new_branches_take_colours_in_name_order()
{
	var refs = new Gee.ArrayList<Gitrlf.Ref>();
	refs.add(branch("gamma"));
	refs.add(branch("alpha"));
	refs.add(branch("beta"));

	var colours = new Gitrlf.BranchColours(saved_of({}), refs);

	assert_cmpstr(colours_of(colours), CompareOperator.EQ, "alpha:0,beta:1,gamma:2");
}

}
