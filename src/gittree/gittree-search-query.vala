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

public class SearchQuery : Object
{
	private DateTime? d_after;
	private TextMatch[] d_authors;
	private DateTime? d_before;
	private bool d_empty;
	private TextMatch[] d_hashes;
	private TextMatch[] d_messages;
	private TextMatch d_plain;

	public bool is_empty
	{
		get { return d_empty; }
	}

	public bool match_case { get; private set; }

	public string? problem { get; private set; }

	public bool regex { get; private set; }

	public string? regex_error { get; private set; }

	public string text { get; private set; }

	public SearchQuery(string text, bool match_case, bool regex)
	{
		var words = /(?<![^\s])(author|message|hash|before|after):("([^"]*)"|(\S*))/;
		var plain = new StringBuilder();
		var start = 0;
		MatchInfo info;

		this.text = text;
		this.match_case = match_case;
		this.regex = regex;

		d_authors = new TextMatch[0];
		d_hashes = new TextMatch[0];
		d_messages = new TextMatch[0];
		d_empty = text.strip() == "";

		for (words.match(text, 0, out info); info.matches(); next_word(info))
		{
			int from;
			int to;
			var key = info.fetch(1);
			var value = info.fetch(3) != null && info.fetch(3) != "" ? info.fetch(3) : info.fetch(4);

			info.fetch_pos(0, out from, out to);
			plain.append(text.substring(start, from - start));
			start = to;

			if (key == "before" || key == "after")
			{
				var date = start_of(value);

				if (date == null)
				{
					problem = _("Bad date");
				}
				else if (key == "before")
				{
					d_before = date;
				}
				else
				{
					d_after = date;
				}

				continue;
			}

			var match = new TextMatch(value != null ? value : "", match_case, regex);

			if (key == "author")
			{
				d_authors += match;
			}
			else if (key == "message")
			{
				d_messages += match;
			}
			else
			{
				d_hashes += match;
			}

			if (match.error != null && problem == null)
			{
				problem = _("Bad regex");
				regex_error = match.error;
			}
		}

		plain.append(text.substring(start));

		var rest = start == 0 ? text : string.joinv(" ", Regex.split_simple("\\s+", plain.str.strip()));

		d_plain = new TextMatch(rest, match_case, regex);

		if (d_plain.error != null && problem == null)
		{
			problem = _("Bad regex");
			regex_error = d_plain.error;
		}
	}

	private static bool all_hold(TextMatch[] matches, string text)
	{
		foreach (var match in matches)
		{
			if (!match.is_empty && !match.matches(text))
			{
				return false;
			}
		}

		return true;
	}

	public TextMatch[] author_marks()
	{
		return marks(d_authors);
	}

	public TextMatch[] hash_marks()
	{
		return marks({});
	}

	private TextMatch[] marks(TextMatch[] words)
	{
		var ret = new TextMatch[0];

		if (!d_plain.is_empty)
		{
			ret += d_plain;
		}

		foreach (var word in words)
		{
			ret += word;
		}

		return ret;
	}

	public bool matches(Gitg.Commit commit)
	{
		if (problem != null || d_empty)
		{
			return false;
		}

		var author = commit.get_author();

		if (d_after != null && author.get_time().compare(d_after) < 0)
		{
			return false;
		}

		if (d_before != null && author.get_time().compare(d_before) >= 0)
		{
			return false;
		}

		if (!d_plain.is_empty && !Search.matches(commit, d_plain))
		{
			return false;
		}

		if (d_authors.length == 0 && d_messages.length == 0 && d_hashes.length == 0)
		{
			return true;
		}

		return all_hold(d_authors, author.get_name() + "\n" + author.get_email())
		    && all_hold(d_messages, commit.get_message())
		    && all_hold(d_hashes, commit.get_id().to_string());
	}

	private static void next_word(MatchInfo info)
	{
		try
		{
			info.next();
		}
		catch (RegexError e)
		{
		}
	}

	private static DateTime? start_of(string? value)
	{
		MatchInfo info;

		if (value == null)
		{
			return null;
		}

		if (!/^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$/.match(value, 0, out info))
		{
			return null;
		}

		var year = int.parse(info.fetch(1));
		var month = info.fetch(2) != null && info.fetch(2) != "" ? int.parse(info.fetch(2)) : 1;
		var day = info.fetch(3) != null && info.fetch(3) != "" ? int.parse(info.fetch(3)) : 1;

		if (month < 1 || month > 12 || day < 1 || day > Date.get_days_in_month((DateMonth)month, (DateYear)year))
		{
			return null;
		}

		return new DateTime.local(year, month, day, 0, 0, 0);
	}

	public TextMatch[] subject_marks()
	{
		return marks(d_messages);
	}
}

}
