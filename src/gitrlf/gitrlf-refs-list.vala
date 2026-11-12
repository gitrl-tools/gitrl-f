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

public class RefsList : Gtk.ListBox
{
	private class Entry
	{
		public RefsHeader group;
		public string label;
		public int order;
		public Ref reference;
		public RefsRow? row;

		public Entry(Ref reference, RefsHeader group, string label, int order)
		{
			this.reference = reference;
			this.group = group;
			this.label = label;
			this.order = order;
		}
	}

	private bool d_batching;
	private CopyMenu d_copy_menu;
	private Gee.ArrayList<Entry> d_entries;
	private Gee.HashMap<string, bool> d_folds;
	private Gee.ArrayList<RefsHeader> d_headers;
	private string d_needle;
	private int d_order;
	private Gee.ArrayList<RefsRow> d_rows;
	private string? d_shape;
	private Gee.HashSet<string> d_ticks;

	public string filter_text
	{
		owned get { return d_needle; }
		set
		{
			d_needle = value.strip().down();

			if (d_needle != "")
			{
				d_batching = true;

				foreach (var header in d_headers)
				{
					header.expanded = true;
				}

				d_batching = false;
				build_shown();
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

	public signal void menu_opening(Ref reference, CopyMenu menu);
	public signal void ref_activated(Ref reference);
	public signal void ticks_changed();

	construct
	{
		d_entries = new Gee.ArrayList<Entry>();
		d_folds = new Gee.HashMap<string, bool>();
		d_headers = new Gee.ArrayList<RefsHeader>();
		d_needle = "";
		d_rows = new Gee.ArrayList<RefsRow>();
		d_ticks = new Gee.HashSet<string>();

		selection_mode = Gtk.SelectionMode.NONE;
		activate_on_single_click = true;

		get_style_context().add_class("sidebar");

		set_filter_func(filter_row);
		set_sort_func((a, b) => order_of(a) - order_of(b));
		row_activated.connect(on_row_activated);

		d_copy_menu = new CopyMenu(this);
		d_copy_menu.find.connect(find_copy);
	}

	private RefsHeader add_header(string key, string title, RefsHeader? parent_group)
	{
		var header = new RefsHeader(key, title, parent_group);

		header.order = d_order++;
		header.expanded = d_folds.has_key(key) ? d_folds[key] : key != "section:tags";
		header.notify["expanded"].connect(() => {
			d_folds[header.key] = header.expanded;

			if (!d_batching)
			{
				build_shown();
				invalidate_filter();
			}
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
		d_entries.add(new Entry(reference, group, label, d_order++));
	}

	private void add_tree(Gee.List<Ref> refs, string key_prefix, RefsHeader group, History? history)
	{
		var tops = new Gee.HashMap<string, int>();

		foreach (var reference in refs)
		{
			var parts = reference.short_name.split("/");
			var position = position_of(reference, history);

			for (var i = 0; i < parts.length; i++)
			{
				var key = entry_key(parts, i);

				tops[key] = tops.has_key(key) ? int.min(tops[key], position) : position;
			}
		}

		var sorted = new Gee.ArrayList<Ref>();
		sorted.add_all(refs);
		sorted.sort((a, b) => compare_paths(a.short_name.split("/"), b.short_name.split("/"), tops));

		var open = new Gee.ArrayList<RefsHeader>();

		foreach (var reference in sorted)
		{
			var parts = reference.short_name.split("/");
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

	private void build_row(Entry entry)
	{
		var row = new RefsRow(entry.reference, entry.group, entry.label);

		row.order = entry.order;
		row.ticked = d_ticks.contains(entry.reference.name);
		row.toggled.connect(() => {
			if (row.ticked)
			{
				d_ticks.add(row.reference.name);
			}
			else
			{
				d_ticks.remove(row.reference.name);
			}

			changed_by_user();
		});

		entry.row = row;
		d_rows.add(row);
		add(row);
	}

	private void build_shown()
	{
		foreach (var entry in d_entries)
		{
			if (entry.row == null && entry.group.expanded && entry.group.is_shown_by_folds)
			{
				build_row(entry);
			}
		}
	}

	private void build_widest()
	{
		var widest = new Gee.HashMap<int, Entry>();
		var widths = new Gee.HashMap<int, int>();

		foreach (var entry in d_entries)
		{
			if (entry.row != null)
			{
				continue;
			}

			if (entry.reference.head)
			{
				build_row(entry);
				continue;
			}

			var depth = entry.group.depth;
			int width;
			int height;

			create_pango_layout(entry.label).get_pixel_size(out width, out height);

			if (!widths.has_key(depth) || width > widths[depth])
			{
				widths[depth] = width;
				widest[depth] = entry;
			}
		}

		foreach (var entry in widest.values)
		{
			build_row(entry);
		}
	}

	private void changed_by_user()
	{
		show_ticks();
		ticks_changed();
	}

	private static int compare_paths(string[] a, string[] b, Gee.Map<string, int> tops)
	{
		for (var i = 0; i < a.length && i < b.length; i++)
		{
			var a_group = i < a.length - 1;
			var b_group = i < b.length - 1;

			if (a_group != b_group)
			{
				return a_group ? 1 : -1;
			}

			var order = tops[entry_key(a, i)] - tops[entry_key(b, i)];

			if (order == 0)
			{
				order = Refs.compare_natural(a[i], b[i]);
			}

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

	private static string entry_key(string[] parts, int level)
	{
		return string.joinv("/", parts[0:level + 1]) + (level < parts.length - 1 ? "/" : "");
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
					if (header.contains(candidate.group) && candidate.matches(d_needle))
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

	private bool find_copy(double x, double y)
	{
		var row = get_row_at_y((int)y) as RefsRow;

		if (row == null)
		{
			return false;
		}

		d_copy_menu.add_copy(_("Copy name"), row.reference.short_name);
		menu_opening(row.reference, d_copy_menu);
		return true;
	}

	private void fold_unticked()
	{
		d_batching = true;

		foreach (var header in d_headers)
		{
			var ticked = false;

			foreach (var name in leaves(header))
			{
				ticked = ticked || d_ticks.contains(name);
			}

			if (!ticked)
			{
				header.expanded = false;
			}
		}

		d_batching = false;
		invalidate_filter();
	}

	private Gee.List<string> leaves(RefsHeader header)
	{
		var names = new Gee.ArrayList<string>();

		foreach (var entry in d_entries)
		{
			if (header.contains(entry.group))
			{
				names.add(entry.reference.name);
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

	private static int order_of(Gtk.ListBoxRow row)
	{
		var header = row as RefsHeader;

		return header != null ? header.order : ((RefsRow)row).order;
	}

	private static int position_of(Ref reference, History? history)
	{
		return history != null ? history.position(reference.target) : int.MAX;
	}

	public Gee.List<Ref> refs_in_order()
	{
		var refs = new Gee.ArrayList<Ref>();

		foreach (var entry in d_entries)
		{
			refs.add(entry.reference);
		}

		return refs;
	}

	public void set_refs(Gee.List<Ref> refs, Gee.Set<string> ticks, History? history, bool fold = false)
	{
		var shape = shape_of(refs, history);

		d_ticks.clear();
		d_ticks.add_all(ticks);

		if (shape == d_shape)
		{
			var named = new Gee.HashMap<string, Ref>();

			foreach (var reference in refs)
			{
				named[reference.name] = reference;
			}

			foreach (var entry in d_entries)
			{
				entry.reference = named[entry.reference.name];

				if (entry.row != null)
				{
					entry.row.reference = entry.reference;
				}
			}

			show_ticks();

			if (fold)
			{
				fold_unticked();
			}

			return;
		}

		d_shape = shape;

		foreach (var child in get_children())
		{
			child.destroy();
		}

		d_entries.clear();
		d_headers.clear();
		d_order = 0;
		d_rows.clear();

		Ref? detached = null;
		var locals = new Gee.ArrayList<Ref>();
		var remotes = new Gee.ArrayList<Ref>();
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
			else if (reference.kind == RefKind.REMOTE)
			{
				remotes.add(reference);
			}
			else if (reference.kind == RefKind.TAG)
			{
				tags.add(reference);
			}
		}

		if (detached != null || !locals.is_empty)
		{
			var branches = add_header("section:local", _("Branches"), null);

			if (detached != null)
			{
				add_row(detached, branches, detached.short_name);
			}

			add_tree(locals, "local:", branches, history);
		}

		if (!remotes.is_empty)
		{
			add_tree(remotes, "remote:", add_header("section:remotes", _("Remotes"), null), history);
		}

		if (!tags.is_empty)
		{
			add_tree(tags, "tag:", add_header("section:tags", _("Tags"), null), history);
		}

		if (fold)
		{
			fold_unticked();
		}

		build_shown();
		show_ticks();
		invalidate_filter();
	}

	public void set_ticks(Gee.Set<string> ticks)
	{
		d_ticks.clear();
		d_ticks.add_all(ticks);
		show_ticks();
	}

	private static string shape_of(Gee.List<Ref> refs, History? history)
	{
		var positions = new Gee.ArrayList<int>();
		var ranks = new Gee.HashMap<int, int>();
		var text = new StringBuilder();

		foreach (var reference in refs)
		{
			positions.add(position_of(reference, history));
		}

		positions.sort((a, b) => a < b ? -1 : (a > b ? 1 : 0));

		foreach (var position in positions)
		{
			if (!ranks.has_key(position))
			{
				ranks[position] = ranks.size;
			}
		}

		foreach (var reference in refs)
		{
			text.append_printf("%d %d %s %s %s %s\n",
			                   ranks[position_of(reference, history)],
			                   reference.kind, reference.head.to_string(),
			                   reference.remote, reference.name,
			                   reference.short_name);
		}

		return text.str;
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
		foreach (var entry in d_entries)
		{
			d_ticks.add(entry.reference.name);
		}

		changed_by_user();
	}

	public void tick_none()
	{
		d_ticks.clear();
		changed_by_user();
	}

	public int widest_row()
	{
		var widest = 0;

		build_widest();

		foreach (var child in get_children())
		{
			int minimum;
			int natural;

			child.get_preferred_width(out minimum, out natural);
			widest = int.max(widest, natural);
		}

		return widest;
	}
}

}
