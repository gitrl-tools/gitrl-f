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

[GtkTemplate (ui = "/io/github/li9i/gitree/ui/gitree-refs-header.ui")]
public class RefsHeader : Gtk.ListBoxRow
{
	[GtkChild]
	private unowned Gtk.CheckButton d_check;
	[GtkChild]
	private unowned Gtk.Label d_count;
	[GtkChild]
	private unowned Gtk.Expander d_expander;
	[GtkChild]
	private unowned Gtk.Label d_label;

	private bool d_updating;

	public bool expanded { get; set; default = true; }
	public string key { get; construct; }
	public RefsHeader? parent_group { get; construct; }
	public string title { get; construct; }

	public signal void toggled();

	public RefsHeader(string key, string title, RefsHeader? parent_group)
	{
		Object(key: key, title: title, parent_group: parent_group);
	}

	construct
	{
		d_label.set_markup("<b>%s</b>".printf(Markup.escape_text(title)));

		bind_property("expanded", d_expander, "expanded", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

		d_expander.button_press_event.connect(() => {
			expanded = !expanded;
			return true;
		});

		if (parent_group != null)
		{
			d_check.margin_start += 12;
		}

		d_check.toggled.connect(() => {
			if (!d_updating)
			{
				toggled();
			}
		});
	}

	public bool contains(RefsRow row)
	{
		for (var group = row.group; group != null; group = group.parent_group)
		{
			if (group == this)
			{
				return true;
			}
		}

		return false;
	}

	public bool is_shown_by_folds
	{
		get
		{
			for (var group = parent_group; group != null; group = group.parent_group)
			{
				if (!group.expanded)
				{
					return false;
				}
			}

			return true;
		}
	}

	public void show_count(int ticked, int total)
	{
		d_updating = true;
		d_check.active = total > 0 && ticked == total;
		d_check.inconsistent = ticked > 0 && ticked < total;
		d_updating = false;

		d_count.label = "%d/%d".printf(ticked, total);
	}
}

}
