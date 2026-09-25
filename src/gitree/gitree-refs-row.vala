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

[GtkTemplate (ui = "/io/github/li9i/gitree/ui/gitree-refs-row.ui")]
public class RefsRow : Gtk.ListBoxRow
{
	[GtkChild]
	private unowned Gtk.Box d_box;
	[GtkChild]
	private unowned Gtk.CheckButton d_check;
	[GtkChild]
	private unowned Gtk.Label d_label;
	[GtkChild]
	private unowned Gtk.Label d_note;

	private bool d_updating;

	public RefsHeader group { get; construct; }
	public Ref reference { get; construct; }

	public bool ticked
	{
		get { return d_check.active; }
		set
		{
			d_updating = true;
			d_check.active = value;
			d_updating = false;
		}
	}

	public signal void toggled();

	public RefsRow(Ref reference, RefsHeader group)
	{
		Object(reference: reference, group: group);
	}

	construct
	{
		var name = reference.short_name;

		if (reference.kind == RefKind.REMOTE)
		{
			name = name.substring(reference.remote.length + 1);
			d_box.margin_start += 12;
		}

		d_label.label = name;

		if (reference.head)
		{
			d_note.label = reference.name == "HEAD" ? _("detached") : _("HEAD");
			d_note.show();
		}

		d_check.toggled.connect(() => {
			if (!d_updating)
			{
				toggled();
			}
		});
	}

	public bool matches(string needle)
	{
		return needle in reference.short_name.down();
	}
}

}
