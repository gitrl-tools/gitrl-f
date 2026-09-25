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

public class Dump : Object
{
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
			stderr.printf("usage: %s <repository> [<options>] [<ref>...] [-- <path>...]\n", args[0]);
			return 2;
		}

		var directory = File.new_for_commandline_arg(args[1]);
		var command_line = new CommandLine(args[2:args.length]);

		if (command_line.error != null)
		{
			stderr.printf("gitree-dump: %s\n", command_line.error);
			return 2;
		}

		var location = Application.discover_repository(directory);

		if (location == null)
		{
			stderr.printf("gitree-dump: not a git repository: %s\n", args[1]);
			return 1;
		}

		try
		{
			var repository = Repository.open(location);
			var refs = Refs.read(repository);
			var ticks = Ticks.resolve(command_line, refs, Ticks.load(Ticks.file_for(repository), refs));
			var history = command_line.paths.length > 0
				? new History.with_paths(repository, refs, command_line.paths, directory, false)
				: new History(repository, refs, false);
			var tips = new Ggit.OId[0];

			foreach (var reference in refs)
			{
				if (ticks.contains(reference.name))
				{
					tips += reference.target;
				}
			}

			var rows = history.tick(tips, History.mainline(repository, true));
			var shown = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc)Ggit.OId.hash, (Gee.EqualDataFunc)Ggit.OId.equal);

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
			stderr.printf("gitree-dump: %s\n", e.message);
			return 1;
		}

		return 0;
	}
}

}
