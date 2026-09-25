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
	Test.add_func("/gitree/ui/refs-panel/filter-keeps-matching-refs-and-unfolds", test_filter_keeps_matching_refs_and_unfolds);
	Test.add_func("/gitree/ui/refs-panel/folds-are-kept-across-a-reload", test_folds_are_kept_across_a_reload);
	Test.add_func("/gitree/ui/refs-panel/group-checkbox-count-and-mixed-state", test_group_checkbox_count_and_mixed_state);
	Test.add_func("/gitree/ui/refs-panel/group-name-folds-it", test_group_name_folds_it);
	Test.add_func("/gitree/ui/refs-panel/groups-order-and-notes", test_groups_order_and_notes);
	Test.add_func("/gitree/ui/refs-panel/none-and-only", test_none_and_only);
	Test.add_func("/gitree/ui/refs-panel/only-shows-under-the-pointer", test_only_shows_under_the_pointer);
	Test.add_func("/gitree/ui/refs-panel/ref-name-activates-the-ref", test_ref_name_activates_the_ref);
	return Test.run();
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

		assert_true(layout(list).has_prefix("H:Branches:4/4|R:HEAD detached|R:feature/scan|"));
		assert_true(list.ticks.contains("HEAD"));

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
			"H:Branches:3/3(hidden)", "R:master HEAD(hidden)", "R:feature/scan(hidden)", "R:fix/stamp(hidden)",
			"H:Remotes:0/2", "H:backup:0/1(hidden)", "R:master(hidden)", "H:origin:0/1", "R:master",
			"H:Tags:0/1(hidden)", "R:v1(hidden)",
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

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "2/2");
		assert_true(check.active);
		assert_false(check.inconsistent);

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "0/2");

		var backup = (Gtk.CheckButton)find_all(row(list, "backup/master"), typeof(Gtk.CheckButton))[0];
		backup.clicked();

		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "1/2");
		assert_true(check.inconsistent);
		assert_cmpstr(sorted(list.ticks), CompareOperator.EQ,
		              "refs/heads/feature/scan,refs/heads/fix/stamp,refs/heads/master,refs/remotes/backup/master");

		check.clicked();
		assert_cmpstr(label_of(remotes, 1), CompareOperator.EQ, "2/2");

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
			"H:Branches:3/3", "R:master HEAD", "R:feature/scan", "R:fix/stamp",
			"H:Remotes:0/2", "H:backup:0/1", "R:master", "H:origin:0/1", "R:master",
			"H:Tags:0/1", "R:v1(hidden)",
		}));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_none_and_only()
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

		row(list, "origin/master").only();
		assert_cmpstr(sorted(list.ticks), CompareOperator.EQ, "refs/remotes/origin/master");
		assert_cmpint(changes, CompareOperator.EQ, 2);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_only_shows_under_the_pointer()
{
	try
	{
		var repo = fixture();
		Gee.List<Gitree.Ref> refs;
		var list = panel(repo, out refs);
		var target = row(list, "fix/stamp");
		Gtk.Label? only = null;

		foreach (var widget in find_all(target, typeof(Gtk.Label)))
		{
			if (((Gtk.Label)widget).get_text() == "only")
			{
				only = (Gtk.Label)widget;
			}
		}

		assert_nonnull(only);
		assert_false(only.visible);

		target.set_state_flags(Gtk.StateFlags.PRELIGHT, false);
		assert_true(only.visible);

		target.unset_state_flags(Gtk.StateFlags.PRELIGHT);
		assert_false(only.visible);

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

}
