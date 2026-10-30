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

private static double ciede2000(Gitg.Color one, Gitg.Color two)
{
	var a = cielab({ one.r, one.g, one.b });
	var b = cielab({ two.r, two.g, two.b });
	var chroma = (Math.hypot(a[1], a[2]) + Math.hypot(b[1], b[2])) / 2;
	var seventh = Math.pow(chroma, 7);
	var g = 0.5 * (1 - Math.sqrt(seventh / (seventh + Math.pow(25, 7))));
	var a1 = (1 + g) * a[1];
	var a2 = (1 + g) * b[1];
	var c1 = Math.hypot(a1, a[2]);
	var c2 = Math.hypot(a2, b[2]);
	var h1 = hue(a[2], a1);
	var h2 = hue(b[2], a2);
	var dh = h2 - h1;

	if (c1 * c2 == 0)
	{
		dh = 0;
	}
	else if (dh > 180)
	{
		dh -= 360;
	}
	else if (dh < -180)
	{
		dh += 360;
	}

	var big_h = 2 * Math.sqrt(c1 * c2) * Math.sin(radians(dh / 2));
	var l = (a[0] + b[0]) / 2;
	var c = (c1 + c2) / 2;
	var h = h1 + h2;

	if (c1 * c2 != 0 && (h1 - h2).abs() > 180)
	{
		h += h < 360 ? 360 : -360;
	}

	if (c1 * c2 != 0)
	{
		h /= 2;
	}

	var t = 1 - 0.17 * Math.cos(radians(h - 30))
	        + 0.24 * Math.cos(radians(2 * h))
	        + 0.32 * Math.cos(radians(3 * h + 6))
	        - 0.2 * Math.cos(radians(4 * h - 63));
	var turn = 30 * Math.exp(-Math.pow((h - 275) / 25, 2));
	var mean_seventh = Math.pow(c, 7);
	var rc = 2 * Math.sqrt(mean_seventh / (mean_seventh + Math.pow(25, 7)));
	var lightness = Math.pow(l - 50, 2);
	var sl = 1 + 0.015 * lightness / Math.sqrt(20 + lightness);
	var sc = 1 + 0.045 * c;
	var sh = 1 + 0.015 * c * t;
	var rt = -Math.sin(radians(2 * turn)) * rc;
	var dl = (b[0] - a[0]) / sl;
	var dc = (c2 - c1) / sc;
	var dhue = big_h / sh;

	return Math.sqrt(dl * dl + dc * dc + dhue * dhue + rt * dc * dhue);
}

private static double[] cielab(double[] rgb)
{
	double[] white = { 0.95047, 1.0, 1.08883 };
	double[] linear = new double[3];
	double[] xyz = new double[3];
	double[] f = new double[3];

	for (var i = 0; i < 3; i++)
	{
		var c = rgb[i];
		var curved = Math.pow((c + 0.055) / 1.055, 2.4);

		linear[i] = c <= 0.04045 ? c / 12.92 : curved;
	}

	xyz[0] = 0.4124 * linear[0] + 0.3576 * linear[1] + 0.1805 * linear[2];
	xyz[1] = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
	xyz[2] = 0.0193 * linear[0] + 0.1192 * linear[1] + 0.9505 * linear[2];

	for (var i = 0; i < 3; i++)
	{
		var t = xyz[i] / white[i];

		f[i] = t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16.0 / 116.0;
	}

	return { 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2]) };
}

private static double contrast(double[] a, double[] b)
{
	var x = luminance(a);
	var y = luminance(b);

	return (double.max(x, y) + 0.05) / (double.min(x, y) + 0.05);
}

private static string hex_of(Gitg.Color colour)
{
	return "%02x%02x%02x".printf((uint)Math.round(colour.r * 255),
	                             (uint)Math.round(colour.g * 255),
	                             (uint)Math.round(colour.b * 255));
}

private static string hexes()
{
	var parts = new string[0];

	for (uint i = 0; i < Gitg.Color.size(); i++)
	{
		parts += hex_of(Gitg.Color.from_index(i));
	}

	return string.joinv(",", parts);
}

private static double hue(double b, double a)
{
	var turned = Math.atan2(b, a) * 180 / Math.PI;

	return turned < 0 ? turned + 360 : turned;
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

	Test.add_func("/gitrlf/line-colours/each-dictionary-set-has-four-or-five-colours", test_each_dictionary_set_has_four_or_five_colours);
	Test.add_func("/gitrlf/line-colours/no-line-colour-is-near-the-checked-out-blue", test_no_line_colour_is_near_the_checked_out_blue);
	Test.add_func("/gitrlf/line-colours/the-checked-out-colour-is-deep-blue-with-light-text", test_the_checked_out_colour_is_deep_blue_with_light_text);
	Test.add_func("/gitrlf/line-colours/the-default-is-the-picked-scheme-without-deep-blue", test_the_default_is_the_picked_scheme_without_deep_blue);
	Test.add_func("/gitrlf/line-colours/the-first-dictionary-set-is-the-one-on-the-page-without-its-blue", test_the_first_dictionary_set_is_the_one_on_the_page_without_its_blue);

	return Test.run();
}

private static double radians(double angle)
{
	return angle * Math.PI / 180;
}

private static void test_each_dictionary_set_has_four_or_five_colours()
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

		var size = name == "dictionary-1" || name == "dictionary-4" ? 4 : 5;

		assert_cmpuint(Gitg.Color.size(), CompareOperator.EQ, size);
		assert_cmpint(seen.size, CompareOperator.EQ, size);

		for (uint i = 0; i < Gitg.Color.size(); i++)
		{
			var colour = Gitg.Color.from_index(i);
			double[] fill = { colour.r, colour.g, colour.b };

			assert_true(colour.dark_text == (contrast(fill, dark) > contrast(fill, light)));
		}
	}

	Gitrlf.LineColours.use("default");
}

private static void test_no_line_colour_is_near_the_checked_out_blue()
{
	var head = Gitg.Color.head();
	var closest = double.MAX;

	Gitrlf.LineColours.use("default");

	for (uint i = 0; i < Gitg.Color.size(); i++)
	{
		for (uint j = i + 1; j < Gitg.Color.size(); j++)
		{
			var apart = ciede2000(Gitg.Color.from_index(i),
			                      Gitg.Color.from_index(j));

			closest = double.min(closest, apart);
		}
	}

	string[] names = { "default" };

	foreach (var name in SETS)
	{
		names += name;
	}

	foreach (var name in names)
	{
		Gitrlf.LineColours.use(name);

		for (uint i = 0; i < Gitg.Color.size(); i++)
		{
			var apart = ciede2000(Gitg.Color.from_index(i), head);

			assert_cmpfloat(apart, CompareOperator.GT, closest);
		}
	}

	Gitrlf.LineColours.use("default");
}

private static void test_the_checked_out_colour_is_deep_blue_with_light_text()
{
	foreach (var name in new string[] { "default", "dictionary-3" })
	{
		Gitrlf.LineColours.use(name);

		var head = Gitg.Color.head();

		assert_cmpstr(hex_of(head), CompareOperator.EQ, "204a87");
		assert_false(head.dark_text);
		assert_true(head.is_head);
		assert_false(Gitg.Color.from_index(0).is_head);
	}

	Gitrlf.LineColours.use("default");
}

private static void test_the_default_is_the_picked_scheme_without_deep_blue()
{
	Gitrlf.LineColours.use("dictionary-2");
	Gitrlf.LineColours.use("default");

	assert_cmpstr(hexes(), CompareOperator.EQ, "6c3566,729fcf,a40000,ad7fa8,f37fb7,fce94f");
	assert_cmpstr(tones(), CompareOperator.EQ, "light,light,light,light,light,dark");
}

private static void test_the_first_dictionary_set_is_the_one_on_the_page_without_its_blue()
{
	Gitrlf.LineColours.use("dictionary-1");

	assert_cmpstr(hexes(), CompareOperator.EQ, "ab2439,1a7444,986f2d,97acc8");

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
