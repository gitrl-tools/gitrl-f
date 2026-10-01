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

public class Dump : Object
{
	private static History filtered(History history, Gee.List<Ref> refs, File directory, CommandLine command_line) throws Error
	{
		var loop = new MainLoop();
		var tips = new Ggit.OId[0];
		Gee.Set<Ggit.OId>? matches = null;
		Error? failure = null;

		foreach (var reference in refs)
		{
			tips += reference.target;
		}

		var regex = command_line.regex != null;
		var filter = new Filter(regex ? command_line.regex : command_line.text, command_line.ignore_case, regex, command_line.paths, false);

		TextSearch.run.begin(directory, tips, filter, new Cancellable(), (obj, res) => {
			try
			{
				Gee.Map<Ggit.OId, Gee.List<string>> names;

				matches = TextSearch.run.end(res, out names);
			}
			catch (Error e)
			{
				failure = e;
			}

			loop.quit();
		});

		loop.run();

		if (failure != null)
		{
			throw failure;
		}

		return new History.filtered(history, matches, refs);
	}

	private static string labels_at(Gitg.Commit commit, Gee.List<Ref> refs, Gee.Set<string> ticks)
	{
		var names = new Gee.ArrayList<string>();

		foreach (var reference in refs)
		{
			if (ticks.contains(reference.name) && reference.target.equal(commit.get_id()))
			{
				names.add(reference.name);
			}
		}

		names.sort();

		return string.joinv(",", names.to_array());
	}

	public static int main(string[] args)
	{
		if (args.length < 2)
		{
			stderr.printf("usage: %s <repository> [<options>] [<ref>...] [-S <text> | -G <regex>] [-i] [-- <path>...]\n", args[0]);
			return 2;
		}

		var directory = File.new_for_commandline_arg(args[1]);
		var command_line = new CommandLine(args[2:args.length]);

		if (command_line.error != null)
		{
			stderr.printf("gittree-dump: %s\n", command_line.error);
			return 2;
		}

		var location = Application.discover_repository(directory);

		if (location == null)
		{
			stderr.printf("gittree-dump: not a git repository: %s\n", args[1]);
			return 1;
		}

		try
		{
			var repository = Repository.open(location);
			var refs = Refs.read(repository);
			var ticks = Ticks.resolve(command_line, refs);
			var history = command_line.paths.length > 0
				? new History.with_paths(repository, refs, command_line.paths, directory, false)
				: new History(repository, refs, false);

			if (command_line.text != null || command_line.regex != null)
			{
				history = filtered(history, refs, directory, command_line);
			}
			var tips = new Ggit.OId[0];

			foreach (var reference in refs)
			{
				if (ticks.contains(reference.name))
				{
					tips += reference.target;
				}
			}

			var rows = history.tick(tips, History.mainline(repository, true));
			var shown = History.id_set();

			foreach (var commit in rows)
			{
				shown.add(commit.get_id());
			}

			foreach (var commit in rows)
			{
				var parents = new string[0];

				foreach (var parent in history.parents_of(commit))
				{
					if (shown.contains(parent))
					{
						parents += parent.to_string();
					}
				}

				stdout.printf("%s\t%s\t%s\n", commit.get_id().to_string(), string.joinv(" ", parents), labels_at(commit, refs, ticks));
			}

			stdout.printf("Showing %d of %d commits\n", rows.length, history.size);
		}
		catch (Error e)
		{
			stderr.printf("gittree-dump: %s\n", e.message);
			return 1;
		}

		return 0;
	}
}

}
