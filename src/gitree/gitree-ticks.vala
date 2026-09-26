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

public errordomain TicksError
{
	NO_MATCH,
}

public class Ticks : Object
{
	public static bool glob_match(string pattern, string text)
	{
		try
		{
			return new Regex(glob_pattern(pattern), RegexCompileFlags.DOTALL).match(text);
		}
		catch (RegexError e)
		{
			return false;
		}
	}

	private static string glob_pattern(string pattern)
	{
		var regex = new StringBuilder("^");
		var i = 0;
		var n = pattern.length;

		while (i < n)
		{
			var c = pattern[i];
			i++;

			if (c == '*')
			{
				regex.append(".*");
			}
			else if (c == '?')
			{
				regex.append(".");
			}
			else if (c == '[')
			{
				var j = i;

				if (j < n && pattern[j] == '!')
				{
					j++;
				}

				if (j < n && pattern[j] == ']')
				{
					j++;
				}

				while (j < n && pattern[j] != ']')
				{
					j++;
				}

				if (j >= n)
				{
					regex.append("\\[");
					continue;
				}

				var stuff = pattern.substring(i, j - i).replace("\\", "\\\\");
				i = j + 1;

				if (stuff.has_prefix("!"))
				{
					stuff = "^" + stuff.substring(1);
				}
				else if (stuff.has_prefix("^") || stuff.has_prefix("["))
				{
					stuff = "\\" + stuff;
				}

				regex.append("[" + stuff + "]");
			}
			else
			{
				regex.append(Regex.escape_string(c.to_string()));
			}
		}

		regex.append("$");

		return regex.str;
	}

	public static Gee.Set<string> resolve(CommandLine? command_line, Gee.List<Ref> refs) throws TicksError
	{
		var all = command_line != null && command_line.all;
		var local = command_line != null && (command_line.local || all);
		var remotes = command_line != null && (command_line.remotes || all);
		var tags = command_line != null && (command_line.tags || all);
		var patterns = command_line != null ? command_line.refs : new string[0];
		var ticks = new Gee.HashSet<string>();

		if (!local && !remotes && !tags && patterns.length == 0)
		{
			foreach (var reference in refs)
			{
				ticks.add(reference.name);
			}

			return ticks;
		}

		foreach (var reference in refs)
		{
			if ((reference.kind == RefKind.LOCAL && local)
			    || (reference.kind == RefKind.REMOTE && remotes)
			    || (reference.kind == RefKind.TAG && tags))
			{
				ticks.add(reference.name);
			}
		}

		foreach (var pattern in patterns)
		{
			var found = false;

			foreach (var reference in refs)
			{
				var short_match = pattern == "HEAD" ? reference.head : glob_match(pattern, reference.short_name);

				if (short_match || glob_match(pattern, reference.name))
				{
					ticks.add(reference.name);
					found = true;
				}
			}

			if (!found)
			{
				throw new TicksError.NO_MATCH("%s", pattern);
			}
		}

		return ticks;
	}

}

}
