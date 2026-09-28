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

namespace GitreeTest
{

public static Gtk.Widget[] find_all(Gtk.Widget widget, Type type)
{
	var found = new Gtk.Widget[0];

	if (widget.get_type().is_a(type))
	{
		found += widget;
	}

	var container = widget as Gtk.Container;

	if (container != null)
	{
		foreach (var child in container.get_children())
		{
			foreach (var inner in find_all(child, type))
			{
				found += inner;
			}
		}
	}

	return found;
}

public static Gitree.RefsRow row(Gitree.RefsList list, string short_name)
{
	foreach (var child in list.get_children())
	{
		var candidate = child as Gitree.RefsRow;

		if (candidate != null && candidate.reference.short_name == short_name)
		{
			return candidate;
		}
	}

	error("no row %s", short_name);
}

public static void scroll_to_row(Gitree.Window window, string subject, int hidden)
{
	var rows = window.history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == subject)
		{
			Gdk.Rectangle area;
			window.history.paned.commit_list_view.get_background_area(new Gtk.TreePath.from_indices(i), null, out area);
			window.history.paned.scrolled_window_commit_list.vadjustment.value = i * area.height + hidden;
			return;
		}
	}

	error("no row %s", subject);
}

public static string top_row(Gitree.Window window)
{
	var view = window.history.paned.commit_list_view;
	Gtk.TreePath start;
	Gtk.TreePath end;
	Gdk.Rectangle area;

	assert_true(view.get_visible_range(out start, out end));
	view.get_background_area(start, null, out area);

	if (area.y + area.height <= 0)
	{
		start.next();
		view.get_background_area(start, null, out area);
	}

	return "%s %d".printf(window.history.rows()[start.get_indices()[0]].get_subject(), area.y);
}

}
