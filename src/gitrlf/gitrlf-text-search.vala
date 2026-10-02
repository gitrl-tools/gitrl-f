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
	public static async Gee.Set<Ggit.OId> run(File directory, Ggit.OId[] tips, Filter filter, Cancellable cancellable, out Gee.Map<Ggit.OId, Gee.List<string>> names) throws Error
	{
		var input = new StringBuilder();

		foreach (var tip in tips)
		{
			input.append(tip.to_string());
			input.append_c('\n');
		}

		var records = yield History.git_async(directory, filter.log_arguments(), input.str, cancellable);
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
