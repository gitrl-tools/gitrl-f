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

private static Gtk.Widget[] find_all(Gtk.Widget widget, Type type)
{
	var found = new Gtk.Widget[0];

	if (widget.get_type().is_a(type))
	{
		found += widget;
	}

	var container = widget as Gtk.Container;

	if (container != null)
	{
		foreach (var child in container.get_children())
		{
			foreach (var inner in find_all(child, type))
			{
				found += inner;
			}
		}
	}

	return found;
}

private static Repo fixture() throws Error
{
	var repo = Repo.create();

	repo.branched();
	repo.git({"update-ref", "refs/remotes/backup/master", "master"});

	return repo;
}

private static void click_name(Gitree.RefsHeader header)
{
	var name = find_all(header, typeof(Gtk.Label))[0];
	int x;
	int y;
	int origin_x;
	int origin_y;

	name.translate_coordinates(name.get_toplevel(), name.get_allocated_width() / 2, name.get_allocated_height() / 2, out x, out y);
	name.get_toplevel().get_window().get_origin(out origin_x, out origin_y);

	click_at(origin_x + x, origin_y + y, 1);
	settle(700);
}

private static Gitree.RefsHeader header(Gitree.RefsList list, string key)
{
	foreach (var child in list.get_children())
	{
		var candidate = child as Gitree.RefsHeader;

		if (candidate != null && candidate.key == key)
		{
			return candidate;
		}
	}

	error("no header %s", key);
}

private static int indent_of(Gitree.RefsList list, Gtk.Widget row)
{
	var check = find_all(row, typeof(Gtk.CheckButton))[0];
	int x;
	int y;

	check.translate_coordinates(list, 0, 0, out x, out y);

	return x;
}

private static string label_of(Gtk.Widget row, int index)
{
	var labels = find_all(row, typeof(Gtk.Label));
	return ((Gtk.Label)labels[index]).get_text();
}

private static string layout(Gitree.RefsList list)
{
	var parts = new string[0];

	foreach (var child in list.get_children())
	{
		var shown = child.get_child_visible() ? "" : "(hidden)";

		if (child is Gitree.RefsHeader)
		{
			parts += "H:" + ((Gitree.RefsHeader)child).title + ":" + label_of(child, 1) + shown;
		}
		else
		{
			var row = (Gitree.RefsRow)child;
			var note = label_of(row, 1);

			parts += "R:" + label_of(row, 0) + (note != "" ? " " + note : "") + shown;
		}
	}

	return string.joinv("|", parts);
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitree/ui/refs-panel/all-ticks-every-ref-whatever-the-filter-shows", test_all_ticks_every_ref_whatever_the_filter_shows);
	Test.add_func("/gitree/ui/refs-panel/detached-head-row", test_detached_head_row);
	Test.add_func("/gitree/ui/refs-panel/each-level-is-indented-by-12-pixels", test_each_level_is_indented_by_12_pixels);
	Test.add_func("/gitree/ui/refs-panel/filter-keeps-matching-refs-and-unfolds", test_filter_keeps_matching_refs_and_unfolds);
	Test.add_func("/gitree/ui/refs-panel/filter-keeps-nested-groups-that-hold-a-match", test_filter_keeps_nested_groups_that_hold_a_match);
	Test.add_func("/gitree/ui/refs-panel/folds-are-kept-across-a-reload", test_folds_are_kept_across_a_reload);
	Test.add_func("/gitree/ui/refs-panel/group-checkbox-count-and-mixed-state", test_group_checkbox_count_and_mixed_state);
	Test.add_func("/gitree/ui/refs-panel/group-name-click-folds-and-opens-it", test_group_name_click_folds_and_opens_it);
	Test.add_func("/gitree/ui/refs-panel/group-name-folds-it", test_group_name_folds_it);
	Test.add_func("/gitree/ui/refs-panel/groups-order-and-notes", test_groups_order_and_notes);
	Test.add_func("/gitree/ui/refs-panel/nested-groups-in-every-list", test_nested_groups_in_every_list);
	Test.add_func("/gitree/ui/refs-panel/none-unticks-every-ref", test_none_unticks_every_ref);
	Test.add_func("/gitree/ui/refs-panel/ref-name-activates-the-ref", test_ref_name_activates_the_ref);
	Test.add_func("/gitree/ui/refs-panel/rows-offer-no-only-link", test_rows_offer_no_only_link);
	Test.add_func("/gitree/ui/refs-panel/subgroup-checkbox-ticks-everything-under-it", test_subgroup_checkbox_ticks_everything_under_it);
	Test.add_func("/gitree/ui/refs-panel/subgroup-name-folds-everything-under-it", test_subgroup_name_folds_everything_under_it);
	return Test.run();
}

private static Repo nested_fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("one");
	repo.commit("two");

	foreach (var name in new string[] { "zed", "b/a10", "backup", "b/a2", "Alpha", "b/c/d", "b/a1" })
	{
		repo.branch(name);
	}

	repo.git({"update-ref", "refs/remotes/origin/master", "master"});
	repo.git({"update-ref", "refs/remotes/origin/b/a1", "master"});
	repo.git({"tag", "v1"});
	repo.git({"tag", "release/v10"});
	repo.git({"tag", "release/v2"});

	return repo;
}

private static Gitree.RefsList panel(Repo repo, out Gee.List<Gitree.Ref> refs) throws Error
{
	var repository = Gitree.Repository.open(Gitree.Application.discover_repository(repo.path));
	var list = new Gitree.RefsList();

	refs = Gitree.Refs.read(repository);
	list.set_refs(refs, Gitree.Ticks.resolve(null, refs));

	var window = new Gtk.Window();
	window.add(list);
	window.show_all();

	return list;
}

private static Gitree.RefsRow row(Gitree.RefsList list, string short_name)
{
	foreach (var child in list.get_children())
	{
		var candidate = child as Gitree.RefsRow;

		if (candidate != null && candidate.reference.short_name == short_name)
		{
			return candidate;
		}
	}

	error("no row %s", short_name);
}

private static void settle(int milliseconds)
{
	for (var i = 0; i < milliseconds / 10; i++)
	{
		while (Gtk.events_pending())
		{
			Gtk.main_iteration();
		}

		Thread.usleep(10000);
	}
}

private static string sorted(Gee.Set<string> names)
{
	var list = new Gee.ArrayList<string>();
	list.add_all(names);
	list.sort();
	return string.joinv(",", list.to_array());
}

private static void test_all_ticks_every_ref_whatever_the_filter_shows()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		list.filter_text = "fix";
		list.tick_all();

		assert_cmpint(list.ticks.size, CompareOperator.EQ, refs.size);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_detached_head_row()
{
	try
	{
		var repo = fixture();
		repo.git({"checkout", "--quiet", "--detach", "master~1"});

		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		assert_true(layout(list).has_prefix("H:Branches:4/4|R:HEAD detached|R:master|H:feature:1/1|R:scan|"));
		assert_true(list.ticks.contains("HEAD"));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_each_level_is_indented_by_12_pixels()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var start = indent_of(list, header(list, "section:local"));

		assert_cmpint(indent_of(list, header(list, "local:b")), CompareOperator.EQ, start + 12);
		assert_cmpint(indent_of(list, row(list, "master")), CompareOperator.EQ, start + 12);
		assert_cmpint(indent_of(list, row(list, "b/a1")), CompareOperator.EQ, start + 24);
		assert_cmpint(indent_of(list, header(list, "local:b/c")), CompareOperator.EQ, start + 24);
		assert_cmpint(indent_of(list, row(list, "b/c/d")), CompareOperator.EQ, start + 36);
		assert_cmpint(indent_of(list, header(list, "remote:origin")), CompareOperator.EQ, start + 12);
		assert_cmpint(indent_of(list, row(list, "origin/master")), CompareOperator.EQ, start + 24);
		assert_cmpint(indent_of(list, row(list, "origin/b/a1")), CompareOperator.EQ, start + 36);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_filter_keeps_matching_refs_and_unfolds()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		list.filter_text = "ORIGIN/m";

		assert_cmpstr(layout(list), CompareOperator.EQ, string.joinv("|", {
			"H:Branches:3/3(hidden)", "R:master HEAD(hidden)", "H:feature:1/1(hidden)", "R:scan(hidden)", "H:fix:1/1(hidden)",
			"R:stamp(hidden)",
			"H:Remotes:2/2", "H:backup:1/1(hidden)", "R:master(hidden)", "H:origin:1/1", "R:master",
			"H:Tags:1/1(hidden)", "R:v1(hidden)",
		}));

		list.filter_text = "v";
		list.filter_text = "";

		assert_true(header(list, "section:tags").expanded);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_filter_keeps_nested_groups_that_hold_a_match()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		header(list, "local:b").expanded = false;
		list.filter_text = "a1";

		assert_cmpstr(layout(list), CompareOperator.EQ, string.joinv("|", {
			"H:Branches:8/8", "R:Alpha(hidden)", "R:backup(hidden)", "R:master HEAD(hidden)", "R:zed(hidden)",
			"H:b:4/4", "R:a1", "R:a2(hidden)", "R:a10", "H:c:1/1(hidden)", "R:d(hidden)",
			"H:Remotes:2/2", "H:origin:2/2", "R:master(hidden)", "H:b:1/1", "R:a1",
			"H:Tags:3/3(hidden)", "R:v1(hidden)", "H:release:2/2(hidden)", "R:v2(hidden)", "R:v10(hidden)",
		}));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_folds_are_kept_across_a_reload()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		header(list, "section:local").expanded = false;
		header(list, "section:tags").expanded = true;
		list.set_refs(refs, list.ticks);

		assert_false(header(list, "section:local").expanded);
		assert_true(header(list, "section:tags").expanded);
		assert_false(row(list, "master").get_child_visible());

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_group_checkbox_count_and_mixed_state()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var remotes = header(list, "section:remotes");
		var check = (Gtk.CheckButton)find_all(remotes, typeof(Gtk.CheckButton))[0];

		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "2/2");
		assert_true(check.active);

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "0/2");
		assert_false(check.active);
		assert_false(check.inconsistent);

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "2/2");

		var backup = (Gtk.CheckButton)find_all(row(list, "backup/master"), typeof(Gtk.CheckButton))[0];
		backup.clicked();

		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "1/2");
		assert_true(check.inconsistent);
		assert_cmpstr(sorted(list.ticks), CompareOperator.EQ,
		              "refs/heads/feature/scan,refs/heads/fix/stamp,refs/heads/master,refs/remotes/origin/master,refs/tags/v1");

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "2/2");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_group_name_click_folds_and_opens_it()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		settle(300);

		click_name(header(list, "local:b"));

		assert_false(header(list, "local:b").expanded);
		assert_false(row(list, "b/a1").get_child_visible());

		click_name(header(list, "local:b"));

		assert_true(header(list, "local:b").expanded);
		assert_true(row(list, "b/a1").get_child_visible());

		click_name(header(list, "section:local"));

		assert_false(header(list, "section:local").expanded);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_group_name_folds_it()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var branches = header(list, "section:local");

		list.row_activated(branches);

		assert_false(branches.expanded);
		assert_false(row(list, "fix/stamp").get_child_visible());

		list.row_activated(branches);

		assert_true(row(list, "fix/stamp").get_child_visible());

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_groups_order_and_notes()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		assert_cmpstr(layout(list), CompareOperator.EQ, string.joinv("|", {
			"H:Branches:3/3", "R:master HEAD", "H:feature:1/1", "R:scan", "H:fix:1/1", "R:stamp",
			"H:Remotes:2/2", "H:backup:1/1", "R:master", "H:origin:1/1", "R:master",
			"H:Tags:1/1", "R:v1(hidden)",
		}));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_nested_groups_in_every_list()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		assert_cmpstr(layout(list), CompareOperator.EQ, string.joinv("|", {
			"H:Branches:8/8", "R:Alpha", "R:backup", "R:master HEAD", "R:zed", "H:b:4/4", "R:a1", "R:a2", "R:a10", "H:c:1/1", "R:d",
			"H:Remotes:2/2", "H:origin:2/2", "R:master", "H:b:1/1", "R:a1",
			"H:Tags:3/3", "R:v1(hidden)", "H:release:2/2(hidden)", "R:v2(hidden)", "R:v10(hidden)",
		}));

		header(list, "section:tags").expanded = true;

		assert_true(header(list, "tag:release").expanded);
		assert_true(row(list, "release/v10").get_child_visible());

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_none_unticks_every_ref()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var changes = 0;

		list.ticks_changed.connect(() => changes++);

		list.tick_none();
		assert_cmpint(list.ticks.size, CompareOperator.EQ, 0);
		assert_cmpint(changes, CompareOperator.EQ, 1);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ref_name_activates_the_ref()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		string? activated = null;

		list.ref_activated.connect((reference) => {
			activated = reference.name;
		});

		list.row_activated(row(list, "fix/stamp"));

		assert_cmpstr(activated, CompareOperator.EQ, "refs/heads/fix/stamp");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_rows_offer_no_only_link()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var target = row(list, "fix/stamp");

		target.set_state_flags(Gtk.StateFlags.PRELIGHT, false);

		foreach (var widget in find_all(target, typeof(Gtk.Label)))
		{
			assert_cmpstr(((Gtk.Label)widget).get_text(), CompareOperator.NE, "only");
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}


private static void test_subgroup_checkbox_ticks_everything_under_it()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var branches = header(list, "section:local");
		var b = header(list, "local:b");
		var c = header(list, "local:b/c");
		var check = (Gtk.CheckButton)find_all(b, typeof(Gtk.CheckButton))[0];

		check.clicked();

		assert_cmpstr(label_of(b, 1), CompareOperator.EQ, "0/4");
		assert_cmpstr(label_of(c, 1), CompareOperator.EQ, "0/1");
		assert_cmpstr(label_of(branches, 1), CompareOperator.EQ, "4/8");
		assert_true(((Gtk.CheckButton)find_all(branches, typeof(Gtk.CheckButton))[0]).inconsistent);
		assert_cmpstr(sorted(list.ticks), CompareOperator.EQ, string.joinv(",", {
			"refs/heads/Alpha", "refs/heads/backup", "refs/heads/master", "refs/heads/zed",
			"refs/remotes/origin/b/a1", "refs/remotes/origin/master",
			"refs/tags/release/v10", "refs/tags/release/v2", "refs/tags/v1",
		}));

		((Gtk.CheckButton)find_all(row(list, "b/c/d"), typeof(Gtk.CheckButton))[0]).clicked();

		assert_cmpstr(label_of(c, 1), CompareOperator.EQ, "1/1");
		assert_cmpstr(label_of(b, 1), CompareOperator.EQ, "1/4");
		assert_true(check.inconsistent);

		check.clicked();

		assert_cmpstr(label_of(b, 1), CompareOperator.EQ, "4/4");
		assert_cmpstr(label_of(branches, 1), CompareOperator.EQ, "8/8");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_subgroup_name_folds_everything_under_it()
{
	try
	{
		var repo = nested_fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);

		list.row_activated(header(list, "local:b/c"));

		assert_false(row(list, "b/c/d").get_child_visible());
		assert_true(row(list, "b/a1").get_child_visible());

		list.row_activated(header(list, "local:b"));

		assert_false(row(list, "b/a1").get_child_visible());
		assert_false(header(list, "local:b/c").get_child_visible());
		assert_true(row(list, "backup").get_child_visible());

		list.set_refs(refs, list.ticks);
		list.row_activated(header(list, "local:b"));

		assert_true(row(list, "b/a1").get_child_visible());
		assert_false(row(list, "b/c/d").get_child_visible());

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
