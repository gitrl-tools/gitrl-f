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

public class Search : Object
{
	private const string MARK = "<span background=\"#fce94f\" foreground=\"#1a1a1a\">%s</span>";
	private const string EMPHASIS = "<span weight=\"bold\">%s</span>";

	public static string count_text(int[] matches, int selected, bool empty, string? problem)
	{
		if (empty)
		{
			return "";
		}

		if (problem != null)
		{
			return problem;
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

	public static int[] find(Gitg.Commit[] rows, SearchQuery query)
	{
		var found = new int[0];

		if (query.is_empty)
		{
			return found;
		}

		for (var i = 0; i < rows.length; i++)
		{
			if (query.matches(rows[i]))
			{
				found += i;
			}
		}

		return found;
	}

	public static string emphasised(string markup)
	{
		return EMPHASIS.printf(markup);
	}

	public static string marked(string text, TextMatch[] matches)
	{
		var result = new StringBuilder();
		var spans = new Gee.ArrayList<TextSpan?>();
		var start = 0;
		var reach = 0;

		foreach (var match in matches)
		{
			foreach (var span in match.find(text))
			{
				spans.add(span);
			}
		}

		spans.sort((a, b) => a.start - b.start);

		foreach (var span in spans)
		{
			var first = int.max(span.start, reach);
			var last = span.start + span.length;

			if (last <= first)
			{
				continue;
			}

			var from = text.index_of_nth_char(first);
			var to = text.index_of_nth_char(last);

			result.append(Markup.escape_text(text.substring(start, from - start)));
			result.append(MARK.printf(Markup.escape_text(text.substring(from, to - from))));
			start = to;
			reach = last;
		}

		result.append(Markup.escape_text(text.substring(start)));

		return result.str;
	}

	public static bool matches(Gitg.Commit commit, TextMatch match)
	{
		var author = commit.get_author();
		var haystack = string.join("\n",
		                           commit.get_message(),
		                           author.get_name(),
		                           author.get_email(),
		                           commit.get_id().to_string());

		return match.matches(haystack);
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
