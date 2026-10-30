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

public class BranchColours : Object
{
	private Gee.Map<string, int> d_colours;
	private Ref? d_head;
	private Gee.Map<string, Gitg.Color> d_lines;
	private Gee.Set<string> d_locals;

	public Gee.Map<string, int> saved
	{
		get { return d_colours; }
	}

	public BranchColours(Gee.Map<string, int> saved, Gee.List<Ref> refs)
	{
		var used = new int[Gitg.Color.size()];
		var fresh = new Gee.ArrayList<string>();

		d_colours = new Gee.HashMap<string, int>();
		d_lines = new Gee.HashMap<string, Gitg.Color>();
		d_locals = new Gee.HashSet<string>();

		foreach (var reference in refs)
		{
			var name = reference.short_name;

			if (!reference.name.has_prefix("refs/heads/"))
			{
				continue;
			}

			d_locals.add(name);

			if (reference.head)
			{
				d_head = reference;
			}

			if (saved.has_key(name) && saved[name] < used.length)
			{
				d_colours[name] = saved[name];
				used[saved[name]]++;
			}
			else
			{
				fresh.add(name);
			}
		}

		fresh.sort(Refs.compare_natural);

		foreach (var name in fresh)
		{
			var least = -1;

			for (var i = 0; i < used.length; i++)
			{
				if (least < 0 || used[i] < used[least])
				{
					least = i;
				}
			}

			d_colours[name] = least;
			used[least]++;
		}
	}

	private string? branch_of(Ref reference)
	{
		var name = reference.short_name;

		if (reference.kind == RefKind.REMOTE)
		{
			name = name.substring(reference.remote.length + 1);
		}
		else if (!reference.name.has_prefix("refs/heads/"))
		{
			return null;
		}

		return d_locals.contains(name) ? name : null;
	}

	public Ggit.OId? head_of(Gee.Set<string> ticks)
	{
		return d_head != null && ticks.contains(d_head.name) ? d_head.target : null;
	}

	public bool keep()
	{
		var changed = false;

		foreach (var entry in d_lines.entries)
		{
			if (d_colours[entry.key] != entry.value.idx)
			{
				d_colours[entry.key] = (int)entry.value.idx;
				changed = true;
			}
		}

		return changed;
	}

	public int of_branch(string name)
	{
		return d_colours[name];
	}

	public Gee.Map<Ggit.OId, Gitg.Color> of_tips(Gee.List<Ref> refs, Gee.Set<string> ticks)
	{
		var names = History.id_map<string>();
		var colours = History.id_map<Gitg.Color>();

		d_lines = new Gee.HashMap<string, Gitg.Color>();

		foreach (var reference in refs)
		{
			var name = branch_of(reference);
			var tip = reference.target;

			if (name != null && ticks.contains(reference.name) && (!names.has_key(tip) || Refs.compare_natural(name, names[tip]) < 0))
			{
				names[tip] = name;
			}
		}

		foreach (var entry in names.entries)
		{
			if (!d_lines.has_key(entry.value))
			{
				d_lines[entry.value] = Gitg.Color.from_index(of_branch(entry.value));
			}

			colours[entry.key] = d_lines[entry.value];
		}

		return colours;
	}
}

}
