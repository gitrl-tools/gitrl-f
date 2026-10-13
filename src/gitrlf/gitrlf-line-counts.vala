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

public class LineCounts : Object
{
	private Cancellable d_cancellable;
	private Gee.HashMap<Ggit.OId, string> d_counts;
	private bool d_counting;
	private File d_directory;
	private Gee.HashSet<Ggit.OId> d_wanted;

	public signal void counted();

	public LineCounts(File directory)
	{
		d_cancellable = new Cancellable();
		d_counts = History.id_map<string>();
		d_directory = directory;
		d_wanted = History.id_set();
	}

	public static async Gee.Map<Ggit.OId, string> count(File directory,
	                                                    Ggit.OId[] ids,
	                                                    Cancellable cancellable)
	                                                    throws Error
	{
		var input = new StringBuilder();

		foreach (var id in ids)
		{
			input.append("%s\n".printf(id.to_string()));
		}

		string[] log = { "log", "--no-walk=unsorted", "--stdin",
		                 "--diff-merges=first-parent", "--numstat",
		                 "--format=%H" };
		var records = yield History.git_async(directory, log, input.str,
		                                      cancellable);
		var counts = History.id_map<string>();
		Ggit.OId? id = null;
		var added = 0;
		var removed = 0;

		foreach (var record in records)
		{
			var fields = record.split("\t");

			if (fields.length == 1)
			{
				id = new Ggit.OId.from_string(record);
				added = 0;
				removed = 0;
			}
			else if (fields.length > 1)
			{
				added += int.parse(fields[0]);
				removed += int.parse(fields[1]);
			}

			counts[id] = text_of(added, removed);
		}

		return counts;
	}

	private async void run()
	{
		while (!d_wanted.is_empty)
		{
			try
			{
				var found = yield count(d_directory, d_wanted.to_array(),
				                        d_cancellable);

				d_counts.set_all(found);
				d_wanted.remove_all(found.keys);
			}
			catch (Error e)
			{
				break;
			}

			counted();
		}

		d_counting = false;
	}

	public void stop()
	{
		d_cancellable.cancel();
	}

	public string? text(Ggit.OId id)
	{
		if (!d_counts.has_key(id) && d_wanted.add(id) && !d_counting)
		{
			d_counting = true;

			Idle.add(() => {
				run.begin();
				return false;
			});
		}

		return d_counts[id];
	}

	public static string text_of(int added, int removed)
	{
		return "+%d/-%d".printf(added, removed);
	}
}

}
