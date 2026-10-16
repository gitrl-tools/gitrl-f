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

public class TextSearch : Object
{
	private const int BLOCK = 8;

	private static string[] chunks(History history)
	{
		var count = int.min((int)get_num_processors(), (history.size + BLOCK - 1) / BLOCK);
		var lists = new StringBuilder[count];
		var ret = new string[0];

		for (var i = 0; i < count; i++)
		{
			lists[i] = new StringBuilder();
		}

		for (var i = 0; i < history.size; i++)
		{
			unowned StringBuilder list = lists[i / BLOCK % count];

			list.append(history.at(i).get_id().to_string());
			list.append_c('\n');
		}

		foreach (unowned StringBuilder list in lists)
		{
			ret += list.str;
		}

		return ret;
	}

	public static async Gee.Set<Ggit.OId> run(File directory, History history, Ggit.OId[] tips, Filter filter, Cancellable cancellable, out Gee.Map<Ggit.OId, Gee.List<string>> names) throws Error
	{
		var listed = !filter.follow && filter.paths.length == 0;
		var input = new StringBuilder();
		var records = new string[0];

		foreach (var tip in tips)
		{
			input.append(tip.to_string());
			input.append_c('\n');
		}

		yield History.git_each(directory, filter.log_arguments(listed), listed ? chunks(history) : new string[] { input.str }, cancellable, (index, part) => {
			foreach (var record in part)
			{
				records += record;
			}
		});

		var found = History.id_set();
		var named = History.id_map<Gee.List<string>>();
		Ggit.OId? current = null;
		var wanted = 0;

		foreach (var record in records)
		{
			if (record.has_prefix("\x01"))
			{
				current = new Ggit.OId.from_string(record.substring(1));
				found.add(current);
				named[current] = new Gee.ArrayList<string>();
				wanted = 0;
			}
			else if (record != "" && current != null && wanted == 0)
			{
				wanted = record[0] == 'R' || record[0] == 'C' ? 2 : 1;
			}
			else if (record != "" && current != null)
			{
				named[current].add(record);
				wanted--;
			}
		}

		if (filter.path_match != null)
		{
			var kept = History.id_map<Gee.List<string>>();

			foreach (var entry in named.entries)
			{
				var matched = new Gee.ArrayList<string>();

				foreach (var name in entry.value)
				{
					if (filter.path_match.matches(name))
					{
						matched.add(name);
					}
				}

				if (matched.size > 0)
				{
					kept[entry.key] = matched;
				}
				else
				{
					found.remove(entry.key);
				}
			}

			named = kept;
		}

		names = named;

		return found;
	}
}

}
