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
 */
namespace GitreeTest
{

private const string[] CHILDREN = {
	"preferences|commit,diff,history",
	"preferences.commit|message",
	"state|history,window",
};

private const string[] KEYS = {
	"preferences.commit.message|custom-datetime|''",
	"preferences.commit.message|datetime-selection|'predefined'",
	"preferences.commit.message|predefined-datetime|'%Y-%m-%dT%R%z'",
	"preferences.diff|changes-inline|false",
	"preferences.diff|context-lines|3",
	"preferences.diff|ignore-whitespace|false",
	"preferences.diff|tab-width|4",
	"preferences.diff|wrap|false",
	"preferences.history|collapse-inactive-lanes|2",
	"preferences.history|collapse-inactive-lanes-enabled|true",
	"preferences.history|mainline-head|true",
	"preferences.history|topological-order|false",
	"preferences.interface|enable-diff-highlighting|true",
	"preferences.interface|enable-monitoring|true",
	"preferences.interface|monospace-font-name|'Monospace 12'",
	"preferences.interface|orientation|'vertical'",
	"preferences.interface|style-scheme|'classic'",
	"preferences.interface|use-default-font|true",
	"preferences.interface|use-gravatar|false",
	"state.history|paned-sidebar-position|200",
	"state.window|size|(650, 500)",
	"state.window|state|0",
};

private static SettingsSchema? lookup(string suffix)
{
	return SettingsSchemaSource.get_default().lookup(Gitree.Config.APPLICATION_ID + "." + suffix, false);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/settings/children-are-gitgs", test_children_are_gitgs);
	Test.add_func("/gitree/settings/every-key-has-gitgs-default", test_every_key_has_gitgs_default);
	Test.add_func("/gitree/settings/no-other-key-exists", test_no_other_key_exists);

	return Test.run();
}

private static string sorted(string[] names)
{
	var list = new Gee.ArrayList<string>.wrap(names);
	list.sort();
	return string.joinv(",", list.to_array());
}

private static void test_children_are_gitgs()
{
	foreach (var row in CHILDREN)
	{
		var parts = row.split("|");
		var schema = lookup(parts[0]);

		assert_nonnull(schema);
		assert_cmpstr(sorted(schema.list_children()), CompareOperator.EQ, parts[1]);
	}
}

private static void test_every_key_has_gitgs_default()
{
	foreach (var row in KEYS)
	{
		var parts = row.split("|");
		var schema = lookup(parts[0]);

		assert_nonnull(schema);
		assert_true(schema.has_key(parts[1]));
		assert_cmpstr(schema.get_key(parts[1]).get_default_value().print(false), CompareOperator.EQ, parts[2]);
	}
}

private static void test_no_other_key_exists()
{
	var expected = new Gee.HashMap<string, Gee.TreeSet<string>>();

	foreach (var row in KEYS)
	{
		var parts = row.split("|");

		if (!expected.has_key(parts[0]))
		{
			expected[parts[0]] = new Gee.TreeSet<string>();
		}

		expected[parts[0]].add(parts[1]);
	}

	foreach (var entry in expected.entries)
	{
		var schema = lookup(entry.key);

		assert_nonnull(schema);
		assert_cmpstr(sorted(schema.list_keys()), CompareOperator.EQ, string.joinv(",", entry.value.to_array()));
	}
}

}
