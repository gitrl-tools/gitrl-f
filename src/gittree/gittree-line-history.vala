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

public class LineHistory : Object
{
	public int end { get; private set; }
	public bool from_parent { get; private set; }
	public int start { get; private set; }

	private LineHistory(int start, int end, bool from_parent)
	{
		this.end = end;
		this.from_parent = from_parent;
		this.start = start;
	}

	public static async Ggit.OId? blame(File directory, Ggit.OId parent, string path, int line, Cancellable cancellable, out string? name) throws Error
	{
		string[] argv = { "blame", "--porcelain", "-L%d,%d".printf(line, line), parent.to_string(), "--", path };
		var records = yield History.git_async(directory, argv, null, cancellable);
		Ggit.OId? found = null;

		name = null;

		foreach (var record in records)
		{
			if (found == null && record.length >= 40)
			{
				found = new Ggit.OId.from_string(record.substring(0, 40));
			}
			else if (name == null && record.has_prefix("filename "))
			{
				name = record.substring(9);
			}
		}

		return found;
	}

	public static int line_at(int[] offsets, int offset)
	{
		var found = -1;

		for (var i = 0; i < offsets.length; i++)
		{
			if (offsets[i] >= 0 && offsets[i] <= offset)
			{
				found = i;
			}
		}

		return found;
	}

	public static LineHistory? of_view(Ggit.DiffLineType[] origins, int[] old_numbers, int[] new_numbers, int[] offsets, int from, int to, int side, bool split)
	{
		var picked_new = new int[0];
		var picked_old = new int[0];
		var last = to > from ? to - 1 : from;
		var next = new int[offsets.length];
		var following = int.MAX;

		for (var i = offsets.length - 1; i >= 0; i--)
		{
			next[i] = following;

			if (offsets[i] >= 0)
			{
				following = offsets[i];
			}
		}

		for (var i = 0; i < offsets.length; i++)
		{
			if (offsets[i] < 0 || offsets[i] > last || next[i] <= from)
			{
				continue;
			}

			if (new_numbers[i] > 0)
			{
				picked_new += new_numbers[i];
			}

			if (old_numbers[i] > 0)
			{
				picked_old += old_numbers[i];
			}
		}

		var old_side = split ? side == 0 : picked_new.length == 0;
		var picked = old_side ? picked_old : picked_new;

		if (picked.length == 0)
		{
			return null;
		}

		var low = picked[0];
		var high = picked[0];

		foreach (var number in picked)
		{
			low = int.min(low, number);
			high = int.max(high, number);
		}

		return new LineHistory(low, high, old_side);
	}

	public static async Gee.Set<Ggit.OId> run(File directory, Ggit.OId commit, string path, int start, int end, Cancellable cancellable) throws Error
	{
		string[] argv = { "log", "-z", "--format=%x01%H", "-s", "-L%d,%d:%s".printf(start, end, path), commit.to_string() };
		var records = yield History.git_async(directory, argv, null, cancellable);
		var found = History.id_set();

		foreach (var record in records)
		{
			if (record.has_prefix("\x01"))
			{
				found.add(new Ggit.OId.from_string(record.substring(1)));
			}
		}

		return found;
	}
}

}
