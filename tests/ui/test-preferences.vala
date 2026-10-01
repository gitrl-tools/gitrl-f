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

private static Gtk.CheckButton check_button(Gtk.Widget root, string label)
{
	var found = find_all(root, typeof(Gtk.CheckButton));

	foreach (var widget in found)
	{
		var button = widget as Gtk.CheckButton;

		if (button.label != null && button.label.replace("_", "") == label)
		{
			return button;
		}
	}

	error("no check button labelled %s", label);
}

private static void drain()
{
	while (Gtk.events_pending())
	{
		Gtk.main_iteration();
	}
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/preferences/check-buttons-follow-their-keys", test_check_buttons_follow_their_keys);
	Test.add_func("/gittree/ui/preferences/choices-follow-their-keys", test_choices_follow_their_keys);
	Test.add_func("/gittree/ui/preferences/collapse-scale-follows-its-key", test_collapse_scale_follows_its_key);
	Test.add_func("/gittree/ui/preferences/pages", test_pages);

	return Test.run();
}

private static Settings settings(string suffix)
{
	return new Settings(Gittree.Config.APPLICATION_ID + "." + suffix);
}

private static void test_check_buttons_follow_their_keys()
{
	var dialog = new Gittree.PreferencesDialog(null);

	string[,] rows = {
		{ "preferences.interface", "use-default-font", "Use the system fixed width font" },
		{ "preferences.interface", "use-gravatar", "Use gravatar service to provide user avatars" },
		{ "preferences.interface", "enable-monitoring", "Reload automatically when the repository changes" },
		{ "preferences.interface", "enable-diff-highlighting", "Enable syntax highlighting of source code in diff views" },
		{ "preferences.history", "collapse-inactive-lanes-enabled", "Collapse inactive lanes" },
		{ "preferences.history", "topological-order", "Show history in topological order" },
		{ "preferences.history", "mainline-head", "Preserve mainline for currently checked out branch" },
	};

	for (var i = 0; i < rows.length[0]; i++)
	{
		var keys = settings(rows[i, 0]);
		var button = check_button(dialog, rows[i, 2]);
		var start = keys.get_boolean(rows[i, 1]);

		assert_true(button.active == start);

		button.active = !start;
		drain();
		assert_true(keys.get_boolean(rows[i, 1]) == !start);

		keys.set_boolean(rows[i, 1], start);
		drain();
		assert_true(button.active == start);
	}

	dialog.destroy();
}

private static void test_choices_follow_their_keys()
{
	var dialog = new Gittree.PreferencesDialog(null);
	var keys = settings("preferences.interface");
	Gtk.ComboBoxText? layout = null;
	Gtk.ComboBoxText? scheme = null;

	foreach (var widget in find_all(dialog, typeof(Gtk.ComboBoxText)))
	{
		var combo = widget as Gtk.ComboBoxText;

		if (combo.active_id == "vertical" || combo.active_id == "horizontal")
		{
			layout = combo;
		}
		else
		{
			scheme = combo;
		}
	}

	assert_nonnull(layout);
	assert_nonnull(scheme);

	layout.active_id = "horizontal";
	drain();
	assert_cmpstr(keys.get_string("orientation"), CompareOperator.EQ, "horizontal");

	keys.set_string("orientation", "vertical");
	drain();
	assert_cmpstr(layout.active_id, CompareOperator.EQ, "vertical");

	assert_cmpstr(scheme.active_id, CompareOperator.EQ, "classic");

	scheme.active_id = "oblivion";
	drain();
	assert_cmpstr(keys.get_string("style-scheme"), CompareOperator.EQ, "oblivion");

	keys.set_string("style-scheme", "classic");
	drain();
	assert_cmpstr(scheme.active_id, CompareOperator.EQ, "classic");

	var font = find_all(dialog, typeof(Gtk.FontButton))[0] as Gtk.FontButton;
	keys.set_string("monospace-font-name", "Monospace 9");
	drain();
	assert_cmpstr(font.font, CompareOperator.EQ, "Monospace 9");

	dialog.destroy();
}

private static void test_collapse_scale_follows_its_key()
{
	var dialog = new Gittree.PreferencesDialog(null);
	var keys = settings("preferences.history");
	var scale = find_all(dialog, typeof(Gtk.Scale))[0] as Gtk.Scale;

	assert_cmpfloat(scale.adjustment.lower, CompareOperator.EQ, 0);
	assert_cmpfloat(scale.adjustment.upper, CompareOperator.EQ, 5);
	assert_cmpfloat(scale.adjustment.page_size, CompareOperator.EQ, 1);
	assert_cmpfloat(scale.get_value(), CompareOperator.EQ, keys.get_int("collapse-inactive-lanes"));

	scale.set_value(5);
	drain();
	assert_cmpint(keys.get_int("collapse-inactive-lanes"), CompareOperator.EQ, 4);

	scale.set_value(4.4);
	drain();
	assert_cmpint(keys.get_int("collapse-inactive-lanes"), CompareOperator.EQ, 4);
	assert_cmpfloat(scale.get_value(), CompareOperator.EQ, 4);

	keys.set_int("collapse-inactive-lanes", 1);
	drain();
	assert_cmpfloat(scale.get_value(), CompareOperator.EQ, 1);

	keys.reset("collapse-inactive-lanes");
	dialog.destroy();
}

private static void test_pages()
{
	var dialog = new Gittree.PreferencesDialog(null);
	var notebook = find_all(dialog, typeof(Gtk.Notebook))[0] as Gtk.Notebook;

	assert_cmpint(notebook.get_n_pages(), CompareOperator.EQ, 2);
	assert_cmpstr(notebook.get_tab_label_text(notebook.get_nth_page(0)), CompareOperator.EQ, "Interface");
	assert_cmpstr(notebook.get_tab_label_text(notebook.get_nth_page(1)), CompareOperator.EQ, "History");
	assert_cmpint(find_all(dialog, typeof(Gtk.CheckButton)).length, CompareOperator.EQ, 7);

	dialog.destroy();
}

}
