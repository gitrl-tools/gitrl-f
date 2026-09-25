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
	public const string FILE_NAME = "git-tree-ticks";

	public static File file_for(Gitg.Repository repository)
	{
		return Repository.common_dir(repository).get_child(FILE_NAME);
	}

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

	public static Gee.Set<string>? load(File file, Gee.List<Ref> refs)
	{
		string contents;

		try
		{
			FileUtils.get_contents(file.get_path(), out contents);
		}
		catch (FileError e)
		{
			if (!(e is FileError.NOENT))
			{
				stderr.printf("git tree: could not read the ticks: %s\n", e.message);
			}

			return null;
		}

		var known = new Gee.HashMap<string, bool>();

		foreach (var line in contents.split("\n"))
		{
			if (line.has_prefix("+ ") || line.has_prefix("- "))
			{
				known[line.substring(2)] = line[0] == '+';
			}
		}

		var ticks = new Gee.HashSet<string>();

		foreach (var reference in refs)
		{
			var ticked = known.has_key(reference.name) ? known[reference.name] : reference.kind == RefKind.LOCAL;

			if (ticked)
			{
				ticks.add(reference.name);
			}
		}

		return ticks;
	}

	public static Gee.Set<string> resolve(CommandLine? command_line, Gee.List<Ref> refs, Gee.Set<string>? stored) throws TicksError
	{
		var all = command_line != null && command_line.all;
		var local = command_line != null && (command_line.local || all);
		var remotes = command_line != null && (command_line.remotes || all);
		var tags = command_line != null && (command_line.tags || all);
		var patterns = command_line != null ? command_line.refs : new string[0];
		var ticks = new Gee.HashSet<string>();

		if (!local && !remotes && !tags && patterns.length == 0)
		{
			if (stored != null)
			{
				ticks.add_all(stored);
				return ticks;
			}

			foreach (var reference in refs)
			{
				if (reference.kind == RefKind.LOCAL)
				{
					ticks.add(reference.name);
				}
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

	public static void save(File file, Gee.List<Ref> refs, Gee.Set<string> ticks)
	{
		var contents = new StringBuilder();

		foreach (var reference in refs)
		{
			contents.append_printf("%c %s\n", ticks.contains(reference.name) ? '+' : '-', reference.name);
		}

		try
		{
			FileUtils.set_contents(file.get_path(), contents.str);
		}
		catch (FileError e)
		{
			stderr.printf("git tree: could not keep the ticks: %s\n", e.message);
		}
	}
}

}
