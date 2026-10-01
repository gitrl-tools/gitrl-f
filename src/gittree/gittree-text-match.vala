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

public struct TextSpan
{
	int start;
	int length;
}

public class TextMatch : Object
{
	private bool d_match_case;
	private unichar[] d_needle;
	private Posix.Regex d_regex;
	private bool d_regex_ready;

	public string? error { get; private set; }

	public bool is_empty
	{
		get { return d_needle.length == 0; }
	}

	public TextMatch(string text, bool match_case, bool regex)
	{
		d_match_case = match_case;
		d_needle = characters(text, match_case);

		if (!regex || text == "")
		{
			return;
		}

		var flags = Posix.RegexCompileFlags.EXTENDED | Posix.RegexCompileFlags.NEWLINE;

		if (!match_case)
		{
			flags |= Posix.RegexCompileFlags.ICASE;
		}

		var code = d_regex.comp(text, flags);

		if (code != 0)
		{
			error = d_regex.error(code);
			return;
		}

		d_regex_ready = true;
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

	public TextSpan[] find(string haystack)
	{
		if (error != null || is_empty)
		{
			return new TextSpan[0];
		}

		return d_regex_ready ? find_regex(haystack) : find_text(haystack);
	}

	private TextSpan[] find_regex(string haystack)
	{
		var spans = new TextSpan[0];
		var found = new Posix.RegexMatch[1];
		var offset = 0;

		while (offset <= haystack.length)
		{
			var flags = offset > 0 ? Posix.RegexExecFlags.NOTBOL : 0;

			if (d_regex.exec(haystack.offset(offset), found, flags) != 0)
			{
				break;
			}

			var from = offset + (int)found[0].so;
			var to = offset + (int)found[0].eo;

			if (to > from)
			{
				spans += TextSpan() {
					start = haystack.char_count(from),
					length = haystack.offset(from).char_count(to - from)
				};

				offset = to;
				continue;
			}

			var next = from;
			unichar skipped;

			if (!haystack.get_next_char(ref next, out skipped))
			{
				break;
			}

			offset = next;
		}

		return spans;
	}

	private TextSpan[] find_text(string haystack)
	{
		var spans = new TextSpan[0];
		var characters = characters(haystack, d_match_case);
		var start = 0;

		while (start + d_needle.length <= characters.length)
		{
			if (!matches_at(characters, start))
			{
				start++;
				continue;
			}

			spans += TextSpan() {
				start = start,
				length = d_needle.length
			};

			start += d_needle.length;
		}

		return spans;
	}

	public bool matches(string haystack)
	{
		return find(haystack).length > 0;
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
}

}
