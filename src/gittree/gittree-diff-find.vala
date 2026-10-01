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

namespace Gittree
{

public struct DiffMatch
{
	int file;
	int side;
	int line;
	int start;
	int length;
}

public class DiffFind : Object
{
	private bool d_match_case;
	private DiffMatch[] d_matches;
	private unichar[] d_needle;
	private string d_text;

	public int current { get; set; default = -1; }

	public int length
	{
		get { return d_matches.length; }
	}

	public DiffFind(string text, bool match_case)
	{
		d_match_case = match_case;
		d_matches = new DiffMatch[0];
		d_needle = characters(text, match_case);
		d_text = text;
	}

	public void add_file(int file, Ggit.DiffLineType[] origins, string[] texts, bool split)
	{
		if (d_needle.length == 0)
		{
			return;
		}

		for (var side = 0; side < (split ? 2 : 1); side++)
		{
			for (var line = 0; line < origins.length; line++)
			{
				if (shows(origins[line], split, side))
				{
					add_line(file, side, line, texts[line]);
				}
			}
		}
	}

	private void add_line(int file, int side, int line, string text)
	{
		var haystack = characters(shown_text(text), d_match_case);
		var start = 0;

		while (start + d_needle.length <= haystack.length)
		{
			if (!matches_at(haystack, start))
			{
				start++;
				continue;
			}

			d_matches += DiffMatch() {
				file = file,
				side = side,
				line = line,
				start = start,
				length = d_needle.length
			};

			start += d_needle.length;
		}
	}

	private static unichar[] characters(string text, bool match_case)
	{
		var result = new unichar[0];
		var index = 0;
		unichar c;

		while (text.get_next_char(ref index, out c))
		{
			result += match_case ? c : c.tolower();
		}

		return result;
	}

	public string count_text()
	{
		return Search.count_text(numbers(), current, d_text);
	}

	public DiffMatch get_match(int index)
	{
		return d_matches[index];
	}

	private bool matches_at(unichar[] haystack, int start)
	{
		for (var i = 0; i < d_needle.length; i++)
		{
			if (haystack[start + i] != d_needle[i])
			{
				return false;
			}
		}

		return true;
	}

	private int[] numbers()
	{
		var numbers = new int[d_matches.length];

		for (var i = 0; i < numbers.length; i++)
		{
			numbers[i] = i;
		}

		return numbers;
	}

	private static string shown_text(string text)
	{
		var shown = text.replace("\r", "");

		return shown.has_suffix("\n") ? shown.substring(0, shown.length - 1) : shown;
	}

	private static bool shows(Ggit.DiffLineType origin, bool split, int side)
	{
		switch (origin)
		{
		case Ggit.DiffLineType.CONTEXT:
			return true;
		case Ggit.DiffLineType.ADDITION:
			return !split || side == 1;
		case Ggit.DiffLineType.DELETION:
			return !split || side == 0;
		default:
			return false;
		}
	}

	public void step(int direction)
	{
		current = Search.step(numbers(), current, direction);
	}
}

}
