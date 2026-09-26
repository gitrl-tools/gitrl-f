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

public class RefsList : Gtk.ListBox
{
	private Gee.HashMap<string, bool> d_folds;
	private Gee.ArrayList<RefsHeader> d_headers;
	private string d_needle;
	private Gee.ArrayList<RefsRow> d_rows;
	private Gee.HashSet<string> d_ticks;

	public string filter_text
	{
		owned get { return d_needle; }
		set
		{
			d_needle = value.strip().down();

			if (d_needle != "")
			{
				foreach (var header in d_headers)
				{
					header.expanded = true;
				}
			}

			invalidate_filter();
		}
	}

	public Gee.Set<string> ticks
	{
		owned get
		{
			var copy = new Gee.HashSet<string>();
			copy.add_all(d_ticks);
			return copy;
		}
	}

	public signal void ref_activated(Ref reference);
	public signal void ticks_changed();

	construct
	{
		d_folds = new Gee.HashMap<string, bool>();
		d_headers = new Gee.ArrayList<RefsHeader>();
		d_needle = "";
		d_rows = new Gee.ArrayList<RefsRow>();
		d_ticks = new Gee.HashSet<string>();

		selection_mode = Gtk.SelectionMode.NONE;
		activate_on_single_click = true;

		get_style_context().add_class("sidebar");

		set_filter_func(filter_row);
		row_activated.connect(on_row_activated);
	}

	private RefsHeader add_header(string key, string title, RefsHeader? parent_group)
	{
		var header = new RefsHeader(key, title, parent_group);

		header.expanded = d_folds.has_key(key) ? d_folds[key] : key != "section:tags";
		header.notify["expanded"].connect(() => {
			d_folds[header.key] = header.expanded;
			invalidate_filter();
		});
		header.toggled.connect(() => {
			var names = leaves(header);
			var all = true;

			foreach (var name in names)
			{
				all = all && d_ticks.contains(name);
			}

			if (all)
			{
				d_ticks.remove_all(names);
			}
			else
			{
				d_ticks.add_all(names);
			}

			header.expanded = !all;
			changed_by_user();
		});

		d_folds[key] = header.expanded;
		d_headers.add(header);
		add(header);

		return header;
	}

	private void add_row(Ref reference, RefsHeader group, string label)
	{
		var row = new RefsRow(reference, group, label);

		row.toggled.connect(() => {
			if (row.ticked)
			{
				d_ticks.add(reference.name);
			}
			else
			{
				d_ticks.remove(reference.name);
			}

			changed_by_user();
		});

		d_rows.add(row);
		add(row);
	}

	private void add_tree(Gee.List<Ref> refs, int skip, string key_prefix, RefsHeader group)
	{
		var sorted = new Gee.ArrayList<Ref>();
		sorted.add_all(refs);
		sorted.sort((a, b) => compare_paths(a.short_name.substring(skip).split("/"), b.short_name.substring(skip).split("/")));

		var open = new Gee.ArrayList<RefsHeader>();

		foreach (var reference in sorted)
		{
			var parts = reference.short_name.substring(skip).split("/");
			var common = 0;

			while (common < open.size && common < parts.length - 1 && open[common].title == parts[common])
			{
				common++;
			}

			while (open.size > common)
			{
				open.remove_at(open.size - 1);
			}

			for (var i = common; i < parts.length - 1; i++)
			{
				var parent = open.is_empty ? group : open.last();
				open.add(add_header(key_prefix + string.joinv("/", parts[0:i + 1]), parts[i], parent));
			}

			add_row(reference, open.is_empty ? group : open.last(), parts[parts.length - 1]);
		}
	}

	private void changed_by_user()
	{
		show_ticks();
		ticks_changed();
	}

	private static int compare_paths(string[] a, string[] b)
	{
		for (var i = 0; i < a.length && i < b.length; i++)
		{
			var a_group = i < a.length - 1;
			var b_group = i < b.length - 1;

			if (a_group != b_group)
			{
				return a_group ? 1 : -1;
			}

			var order = Refs.compare_natural(a[i], b[i]);

			if (order == 0)
			{
				order = strcmp(a[i], b[i]);
			}

			if (order != 0)
			{
				return order;
			}
		}

		return a.length - b.length;
	}

	private bool filter_row(Gtk.ListBoxRow row)
	{
		var header = row as RefsHeader;

		if (d_needle != "")
		{
			if (header != null)
			{
				foreach (var candidate in d_rows)
				{
					if (header.contains(candidate) && candidate.matches(d_needle))
					{
						return true;
					}
				}

				return false;
			}

			return ((RefsRow)row).matches(d_needle);
		}

		if (header != null)
		{
			return header.is_shown_by_folds;
		}

		var group = ((RefsRow)row).group;

		return group.expanded && group.is_shown_by_folds;
	}

	private Gee.List<string> leaves(RefsHeader header)
	{
		var names = new Gee.ArrayList<string>();

		foreach (var row in d_rows)
		{
			if (header.contains(row))
			{
				names.add(row.reference.name);
			}
		}

		return names;
	}

	private void on_row_activated(Gtk.ListBoxRow row)
	{
		var header = row as RefsHeader;

		if (header != null)
		{
			header.expanded = !header.expanded;
			return;
		}

		ref_activated(((RefsRow)row).reference);
	}

	public void set_refs(Gee.List<Ref> refs, Gee.Set<string> ticks)
	{
		foreach (var child in get_children())
		{
			child.destroy();
		}

		d_headers.clear();
		d_rows.clear();
		d_ticks.clear();
		d_ticks.add_all(ticks);

		RefsHeader? remotes = null;
		Ref? detached = null;
		var locals = new Gee.ArrayList<Ref>();
		var remote_names = new Gee.ArrayList<string>();
		var tags = new Gee.ArrayList<Ref>();

		foreach (var reference in refs)
		{
			if (reference.kind == RefKind.LOCAL && reference.name == "HEAD")
			{
				detached = reference;
			}
			else if (reference.kind == RefKind.LOCAL)
			{
				locals.add(reference);
			}
			else if (reference.kind == RefKind.REMOTE && !remote_names.contains(reference.remote))
			{
				remote_names.add(reference.remote);
			}
			else if (reference.kind == RefKind.TAG)
			{
				tags.add(reference);
			}
		}

		remote_names.sort(Refs.compare_natural);

		if (detached != null || !locals.is_empty)
		{
			var branches = add_header("section:local", _("Branches"), null);

			if (detached != null)
			{
				add_row(detached, branches, detached.short_name);
			}

			add_tree(locals, 0, "local:", branches);
		}

		foreach (var remote in remote_names)
		{
			if (remotes == null)
			{
				remotes = add_header("section:remotes", _("Remotes"), null);
			}

			var group = add_header("remote:" + remote, remote, remotes);
			var members = new Gee.ArrayList<Ref>();

			foreach (var reference in refs)
			{
				if (reference.kind == RefKind.REMOTE && reference.remote == remote)
				{
					members.add(reference);
				}
			}

			add_tree(members, remote.length + 1, "remote:" + remote + "/", group);
		}

		if (!tags.is_empty)
		{
			add_tree(tags, 0, "tag:", add_header("section:tags", _("Tags"), null));
		}

		show_ticks();
		invalidate_filter();
	}

	public void set_ticks(Gee.Set<string> ticks)
	{
		d_ticks.clear();
		d_ticks.add_all(ticks);
		show_ticks();
	}

	private void show_ticks()
	{
		foreach (var row in d_rows)
		{
			row.ticked = d_ticks.contains(row.reference.name);
		}

		foreach (var header in d_headers)
		{
			var names = leaves(header);
			var ticked = 0;

			foreach (var name in names)
			{
				if (d_ticks.contains(name))
				{
					ticked++;
				}
			}

			header.show_count(ticked, names.size);
		}
	}

	public void tick_all()
	{
		foreach (var row in d_rows)
		{
			d_ticks.add(row.reference.name);
		}

		changed_by_user();
	}

	public void tick_none()
	{
		d_ticks.clear();
		changed_by_user();
	}
}

}
