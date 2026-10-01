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

public class TextSearch : Object
{
	public static async Gee.Set<Ggit.OId> run(File directory, Ggit.OId[] tips, string text, bool ignore_case, bool regex, string[] paths, Cancellable cancellable) throws Error
	{
		string[] argv = { "log", "-z", "--stdin", "--no-textconv", "--format=%H", (regex ? "-G" : "-S") + text };

		if (ignore_case)
		{
			argv += "-i";
		}

		argv += "--";

		foreach (var path in paths)
		{
			argv += path;
		}

		var input = new StringBuilder();

		foreach (var tip in tips)
		{
			input.append(tip.to_string());
			input.append_c('\n');
		}

		var records = yield History.git_async(directory, argv, input.str, cancellable);
		var found = History.id_set();

		foreach (var record in records)
		{
			if (record != "")
			{
				found.add(new Ggit.OId.from_string(record));
			}
		}

		return found;
	}
}

}
