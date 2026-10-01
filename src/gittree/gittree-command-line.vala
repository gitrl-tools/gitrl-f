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

public class CommandLine : Object
{
	public const string HELP = """usage: gittree [<options>] [<ref>...] [-S <text> | -G <regex>] [-i] [-- <path>...]

Shows the history of the repository in a window, with a checkbox
for each branch, remote branch and tag. Only the commits that a
ticked ref reaches are drawn, and only ticked refs are labelled.
A commit that a ticked branch shares with an unticked one still
shows, as part of the ticked branch.

git tree runs it too.

With no <ref> and no option, every ref is ticked. Outside a
repository, it opens a list of the repositories you opened last.

    <ref>...        tick only these; a glob such as 'feature/*' works
    -a, --all       tick every ref
    -l, --local     tick every local branch
    -r, --remotes   tick every remote branch
    -t, --tags      tick every tag
    -S, --text <text>
                    draw only the commits that add or remove <text>
    -G, --regex <regex>
                    draw only the commits whose added or removed
                    lines match <regex>
    -i, --ignore-case
                    with -S or -G, ignore case
    -h, --help      print this help and exit
    --version       print the version and exit
    --no-wd         open the chooser, not the repository of this
                    folder
    -- <path>...    draw only the commits that change these files
                    or folders

Options add up: 'gittree -l origin/master' ticks every local
branch and origin/master.

The window follows the repository. A commit, a fetch, a checkout
or a rebase redraws it with the same ticks, the same commit
selected and the same scroll. A new local branch comes in ticked.
New remote branches and tags come in unticked.

Keys
    Click, Enter                show or hide the details of a commit
    Open a file, Expand all     fill the window with the diff
    Ctrl+F                      open or close the search bar, or the
                                diff's find bar when the diff has the
                                focus
    Ctrl+Shift+F                open or close the filter bar
    Enter, Ctrl+G               go to the next commit that matches
    Shift+Enter, Ctrl+Shift+G   go to the one before
    Escape                      close a bar, the full diff or the details
    F5                          read the repository again
    Ctrl+Q                      quit

Search looks in the subject, the message, the author and the
hash. Words narrow it: author:, message:, hash:, before: and
after:, as in author:"Jane Doe" after:2026-01.

A commit adds or removes the text when the number of times it
appears in a file the commit changes goes up or down, as in git
log -S. A merge never does.

A regex is a POSIX extended regular expression, as in git log -G.
One file after -- is followed through its renames, as in git log
--follow.
""";

	public const string USAGE = "usage: gittree [<options>] [<ref>...] [-S <text> | -G <regex>] [-i] [-- <path>...]\n";

	private const string LONG_KEYS = "alrtSGihVW";

	private const string[] LONG_NAMES = { "all", "local", "remotes", "tags", "text", "regex", "ignore-case", "help", "version", "no-wd" };

	private const string SHORT_NAMES = "alrtSGih";

	private string[] d_extras;
	private char d_wants;

	public bool all { get; private set; }
	public string? error { get; private set; }
	public bool help { get; private set; }
	public bool ignore_case { get; private set; }
	public bool local { get; private set; }
	public bool no_wd { get; private set; }
	public string[] paths { get; private set; }
	public string[] refs { get; private set; }
	public string? regex { get; private set; }
	public bool remotes { get; private set; }
	public bool tags { get; private set; }
	public string? text { get; private set; }
	public bool version { get; private set; }

	public bool is_empty
	{
		get
		{
			return !all && !local && !remotes && !tags && text == null && regex == null && !ignore_case && refs.length == 0 && paths.length == 0;
		}
	}

	public CommandLine(string[] arguments)
	{
		parse(arguments);
	}

	private static string? ambiguity(string argument)
	{
		var matches = long_matches(long_name(argument));

		if (matches.length < 2)
		{
			return null;
		}

		var names = new string[0];

		foreach (var match in matches)
		{
			names += "--" + match;
		}

		return "ambiguous option: %s could match %s".printf(argument, string.joinv(", ", names));
	}

	private static string expected(char option)
	{
		return "argument %s: expected one argument".printf(names_of(option));
	}

	private void explicit_argument(char option, string argument)
	{
		error = "argument %s: ignored explicit argument %s".printf(names_of(option), quoted(argument));
	}

	private static int index_of_long(string name)
	{
		for (var i = 0; i < LONG_NAMES.length; i++)
		{
			if (LONG_NAMES[i] == name)
			{
				return i;
			}
		}

		return -1;
	}

	private static bool is_negative_number(string argument)
	{
		return Regex.match_simple("^-\\d+$|^-\\d*\\.\\d+$", argument);
	}

	private static bool is_option_like(string argument)
	{
		if (!argument.has_prefix("-") || argument == "-")
		{
			return false;
		}

		if (argument.has_prefix("--"))
		{
			if (long_matches(long_name(argument)).length > 0)
			{
				return true;
			}
		}
		else if (is_short_name(argument[1]))
		{
			return true;
		}

		return !is_negative_number(argument) && !(" " in argument);
	}

	private static bool is_short_name(char c)
	{
		return c != 0 && SHORT_NAMES.index_of_char(c) >= 0;
	}

	private static string[] long_matches(string name)
	{
		var matches = new string[0];

		foreach (var candidate in LONG_NAMES)
		{
			if (candidate == name)
			{
				return { candidate };
			}

			if (candidate.has_prefix(name))
			{
				matches += candidate;
			}
		}

		return matches;
	}

	private static string long_name(string argument)
	{
		var equals = argument.index_of_char('=');

		return (equals >= 0 ? argument.substring(0, equals) : argument).substring(2);
	}

	private static string names_of(char option)
	{
		var index = LONG_KEYS.index_of_char(option);

		return is_short_name(option) ? "-%c/--%s".printf(option, LONG_NAMES[index]) : "--" + LONG_NAMES[index];
	}

	private void parse(string[] arguments)
	{
		d_extras = new string[0];
		var positional = new string[0];
		var after = new string[0];
		var run = 0;
		var split = false;

		foreach (var argument in arguments)
		{
			if (argument == "--")
			{
				break;
			}

			if (argument.has_prefix("--") && ambiguity(argument) != null)
			{
				error = ambiguity(argument);
				refs = positional;
				paths = after;
				return;
			}
		}

		foreach (var argument in arguments)
		{
			if (split)
			{
				after += argument;
				continue;
			}

			if (d_wants != 0)
			{
				var option = d_wants;

				d_wants = 0;

				if (argument != "--" && !is_option_like(argument))
				{
					set_value(option, argument);

					if (error != null)
					{
						break;
					}

					continue;
				}

				error = expected(option);
				break;
			}

			if (argument == "--")
			{
				split = true;
				continue;
			}

			var is_option = parse_option(argument);

			if (error != null)
			{
				break;
			}

			if (is_option)
			{
				if (run == 1)
				{
					run = 2;
				}

				continue;
			}

			if (run < 2)
			{
				positional += argument;
				run = 1;
			}
			else
			{
				d_extras += argument;
			}
		}

		refs = positional;
		paths = after;

		if (error == null && d_wants != 0)
		{
			error = expected(d_wants);
		}

		if (error == null && d_extras.length > 0)
		{
			error = "unrecognized arguments: " + string.joinv(" ", d_extras);
		}
	}

	private bool parse_long(string argument)
	{
		var head = argument;
		string? explicit = null;
		var equals = argument.index_of_char('=');

		if (equals >= 0)
		{
			head = argument.substring(0, equals);
			explicit = argument.substring(equals + 1);
		}

		var matches = long_matches(head.substring(2));

		if (matches.length == 0)
		{
			if (" " in argument)
			{
				return false;
			}

			d_extras += argument;
			return true;
		}

		var option = LONG_KEYS[index_of_long(matches[0])];

		if (takes_value(option))
		{
			take_value(option, explicit);
		}
		else if (explicit != null)
		{
			explicit_argument(option, explicit);
		}
		else
		{
			set_option(option);
		}

		return true;
	}

	private bool parse_option(string argument)
	{
		if (!argument.has_prefix("-") || argument == "-" || is_negative_number(argument))
		{
			return false;
		}

		if (argument.has_prefix("--"))
		{
			return parse_long(argument);
		}

		return parse_short(argument);
	}

	private bool parse_short(string argument)
	{
		var option = argument[1];

		if (!is_short_name(option))
		{
			if (" " in argument)
			{
				return false;
			}

			d_extras += argument;
			return true;
		}

		var rest = argument.substring(2);

		if (takes_value(option))
		{
			take_value(option, rest.has_prefix("=") ? rest.substring(1) : rest, !rest.has_prefix("="));
			return true;
		}

		set_option(option);

		while (rest.length > 0)
		{
			if (rest[0] == '=')
			{
				explicit_argument(option, rest.substring(1));
				return true;
			}

			if (rest[0] == '-')
			{
				explicit_argument(option, rest);
				return true;
			}

			if (!is_short_name(rest[0]))
			{
				d_extras += "-" + rest;
				return true;
			}

			option = rest[0];
			rest = rest.substring(1);

			if (takes_value(option))
			{
				take_value(option, rest.has_prefix("=") ? rest.substring(1) : rest, !rest.has_prefix("="));
				return true;
			}

			set_option(option);
		}

		return true;
	}

	private static string quoted(string text)
	{
		var quote = ("'" in text && !("\"" in text)) ? "\"" : "'";
		var escaped = text.replace("\\", "\\\\").replace(quote, "\\" + quote);

		escaped = escaped.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r");

		return quote + escaped + quote;
	}

	private void set_option(char option)
	{
		switch (option)
		{
			case 'a':
				all = true;
				break;
			case 'h':
				help = true;
				break;
			case 'i':
				ignore_case = true;
				break;
			case 'l':
				local = true;
				break;
			case 'r':
				remotes = true;
				break;
			case 't':
				tags = true;
				break;
			case 'V':
				version = true;
				break;
			case 'W':
				no_wd = true;
				break;
		}
	}

	private void set_value(char option, string value)
	{
		var other = option == 'S' ? 'G' : 'S';

		if ((option == 'S' && regex != null) || (option == 'G' && text != null))
		{
			error = "argument %s: not allowed with argument %s".printf(names_of(option), names_of(other));
			return;
		}

		if (option == 'S')
		{
			text = value;
		}
		else
		{
			regex = value;
		}
	}

	private void take_value(char option, string? attached, bool attached_or_next = false)
	{
		if (attached != null && (attached != "" || !attached_or_next))
		{
			set_value(option, attached);
			return;
		}

		d_wants = option;
	}

	private static bool takes_value(char option)
	{
		return option == 'S' || option == 'G';
	}
}

}
