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

namespace Gitrlf
{

public class LineColours : Object
{
	private const Gitg.Color.Rgb[] SET_1 = {
		{171, 36, 57, false},
		{26, 116, 68, false},
		{152, 111, 45, false},
		{151, 172, 200, true}
	};

	private const Gitg.Color.Rgb[] SET_2 = {
		{30, 14, 63, false},
		{121, 51, 39, false},
		{0, 110, 184, false},
		{0, 180, 155, true},
		{216, 163, 123, true}
	};

	private const Gitg.Color.Rgb[] SET_3 = {
		{5, 18, 48, false},
		{118, 44, 25, false},
		{0, 151, 141, true},
		{244, 128, 103, true},
		{181, 177, 216, true}
	};

	private const Gitg.Color.Rgb[] SET_4 = {
		{78, 29, 76, false},
		{67, 119, 66, false},
		{218, 82, 93, false},
		{249, 157, 27, true}
	};

	private const Gitg.Color.Rgb[] SET_5 = {
		{30, 14, 63, false},
		{128, 38, 38, false},
		{26, 116, 68, false},
		{0, 113, 144, false},
		{216, 163, 123, true}
	};

	private const Gitg.Color.Rgb[] SET_6 = {
		{5, 18, 48, false},
		{100, 75, 30, false},
		{140, 76, 98, false},
		{0, 180, 155, true},
		{244, 128, 103, true}
	};

	public static void use(string name)
	{
		switch (name)
		{
			case "dictionary-1":
				Gitg.Color.use_palette(SET_1);
				break;
			case "dictionary-2":
				Gitg.Color.use_palette(SET_2);
				break;
			case "dictionary-3":
				Gitg.Color.use_palette(SET_3);
				break;
			case "dictionary-4":
				Gitg.Color.use_palette(SET_4);
				break;
			case "dictionary-5":
				Gitg.Color.use_palette(SET_5);
				break;
			case "dictionary-6":
				Gitg.Color.use_palette(SET_6);
				break;
			default:
				Gitg.Color.use_palette(null);
				break;
		}
	}
}

}
