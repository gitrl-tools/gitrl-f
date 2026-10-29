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

private const string[] SETS = {
	"dictionary-1",
	"dictionary-2",
	"dictionary-3",
	"dictionary-4",
	"dictionary-5",
	"dictionary-6",
};

private static double contrast(double[] a, double[] b)
{
	var x = luminance(a);
	var y = luminance(b);

	return (double.max(x, y) + 0.05) / (double.min(x, y) + 0.05);
}

private static string hexes()
{
	var parts = new string[0];

	for (uint i = 0; i < Gitg.Color.size(); i++)
	{
		var colour = Gitg.Color.from_index(i);

		parts += "%02x%02x%02x".printf((uint)Math.round(colour.r * 255), (uint)Math.round(colour.g * 255), (uint)Math.round(colour.b * 255));
	}

	return string.joinv(",", parts);
}

private static double luminance(double[] rgb)
{
	double[] weights = { 0.2126, 0.7152, 0.0722 };
	var sum = 0.0;

	for (var i = 0; i < 3; i++)
	{
		var c = rgb[i];

		sum += weights[i] * (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
	}

	return sum;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/line-colours/each-dictionary-set-has-eight-colours", test_each_dictionary_set_has_eight_colours);
	Test.add_func("/gitrlf/line-colours/the-default-is-the-picked-scheme", test_the_default_is_the_picked_scheme);
	Test.add_func("/gitrlf/line-colours/the-first-dictionary-set-is-the-one-on-the-page", test_the_first_dictionary_set_is_the_one_on_the_page);

	return Test.run();
}

private static void test_each_dictionary_set_has_eight_colours()
{
	double[] light = { 0xee / 255.0, 0xee / 255.0, 0xec / 255.0 };
	double[] dark = { 0x2e / 255.0, 0x34 / 255.0, 0x36 / 255.0 };

	foreach (var name in SETS)
	{
		Gitrlf.LineColours.use(name);

		var seen = new Gee.HashSet<string>();

		foreach (var hex in hexes().split(","))
		{
			seen.add(hex);
		}

		assert_cmpuint(Gitg.Color.size(), CompareOperator.EQ, 8);
		assert_cmpint(seen.size, CompareOperator.EQ, 8);

		for (uint i = 0; i < Gitg.Color.size(); i++)
		{
			var colour = Gitg.Color.from_index(i);
			double[] fill = { colour.r, colour.g, colour.b };

			assert_true(colour.dark_text == (contrast(fill, dark) > contrast(fill, light)));
		}
	}

	Gitrlf.LineColours.use("default");
}

private static void test_the_default_is_the_picked_scheme()
{
	Gitrlf.LineColours.use("dictionary-2");
	Gitrlf.LineColours.use("default");

	assert_cmpstr(hexes(), CompareOperator.EQ, "204a87,6c3566,729fcf,ef2929,34e2e2,f37fb7,fce94f");
	assert_cmpstr(tones(), CompareOperator.EQ, "light,light,light,light,dark,dark,dark");
}

private static void test_the_first_dictionary_set_is_the_one_on_the_page()
{
	Gitrlf.LineColours.use("dictionary-1");

	assert_cmpstr(hexes(), CompareOperator.EQ, "111314,064f6e,644b1e,7a4456,437742,00b49b,f48067,f99d1b");

	Gitrlf.LineColours.use("default");
}

private static string tones()
{
	var parts = new string[0];

	for (uint i = 0; i < Gitg.Color.size(); i++)
	{
		parts += Gitg.Color.from_index(i).dark_text ? "dark" : "light";
	}

	return string.joinv(",", parts);
}

}
