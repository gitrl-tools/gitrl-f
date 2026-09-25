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

namespace Gitree
{

public class Search : Object
{
	private const string MARK = "<span background=\"#fce94f\" foreground=\"#1a1a1a\">%s</span>";

	public static string count_text(int[] matches, int selected, string needle)
	{
		if (needle == "")
		{
			return "";
		}

		if (matches.length == 0)
		{
			return _("No match");
		}

		for (var i = 0; i < matches.length; i++)
		{
			if (matches[i] == selected)
			{
				return _("%d of %d").printf(i + 1, matches.length);
			}
		}

		return ngettext("%d match", "%d matches", matches.length).printf(matches.length);
	}

	public static int[] find(Gitg.Commit[] rows, string needle)
	{
		var found = new int[0];

		if (needle == "")
		{
			return found;
		}

		for (var i = 0; i < rows.length; i++)
		{
			if (matches(rows[i], needle))
			{
				found += i;
			}
		}

		return found;
	}

	public static string marked(string text, string needle)
	{
		if (needle == "")
		{
			return Markup.escape_text(text);
		}

		var result = new StringBuilder();
		var lower = text.down();
		var wanted = needle.down();
		var start = 0;

		while (true)
		{
			var found = lower.index_of(wanted, start);

			if (found < 0 || lower.length != text.length)
			{
				break;
			}

			result.append(Markup.escape_text(text.substring(start, found - start)));
			result.append(MARK.printf(Markup.escape_text(text.substring(found, wanted.length))));
			start = found + wanted.length;
		}

		result.append(Markup.escape_text(text.substring(start)));

		return result.str;
	}

	public static bool matches(Gitg.Commit commit, string needle)
	{
		var author = commit.get_author();
		var haystack = string.join("\n",
		                           commit.get_message(),
		                           author.get_name(),
		                           author.get_email(),
		                           commit.get_id().to_string());

		return needle.down() in haystack.down();
	}

	public static int step(int[] matches, int selected, int direction)
	{
		if (matches.length == 0)
		{
			return -1;
		}

		if (direction > 0)
		{
			foreach (var row in matches)
			{
				if (row > selected)
				{
					return row;
				}
			}

			return matches[0];
		}

		for (var i = matches.length - 1; i >= 0; i--)
		{
			if (matches[i] < selected)
			{
				return matches[i];
			}
		}

		return matches[matches.length - 1];
	}
}

}
