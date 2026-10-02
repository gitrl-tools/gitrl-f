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

namespace GittreeTest
{

public static Gtk.CheckButton check_labelled(Gtk.Widget root, string label)
{
	foreach (var widget in find_all(root, typeof(Gtk.CheckButton)))
	{
		if (((Gtk.CheckButton)widget).label == label)
		{
			return (Gtk.CheckButton)widget;
		}
	}

	error("no check button %s", label);
}

public static string choice_labels(Gittree.Window window)
{
	var buttons = find_all(list_bar(window), typeof(Gtk.MenuButton));
	var labels = new string[0];

	if (buttons.length != 1)
	{
		error("no choice button");
	}

	foreach (var child in ((Gtk.MenuButton)buttons[0]).popup.get_children())
	{
		labels += ((Gtk.MenuItem)child).label;
	}

	return string.joinv(",", labels);
}

public static Gtk.MenuItem? copy_item()
{
	foreach (var toplevel in Gtk.Window.list_toplevels())
	{
		foreach (var widget in find_all(toplevel, typeof(Gtk.MenuItem)))
		{
			var item = (Gtk.MenuItem)widget;

			if (item.get_mapped() && item.label.has_prefix("Copy"))
			{
				return item;
			}
		}
	}

	return null;
}

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

public static Gtk.Label label_with(Gtk.Widget root, string text)
{
	foreach (var widget in find_all(root, typeof(Gtk.Label)))
	{
		if (((Gtk.Label)widget).get_text() == text)
		{
			return (Gtk.Label)widget;
		}
	}

	error("no label %s", text);
}

public static Gtk.Widget list_bar(Gittree.Window window)
{
	return window.history.search_field.get_parent();
}

public static string marked_rows(Gittree.Window window, Gtk.TreeViewColumn column)
{
	var view = window.history.paned.commit_list_view;
	var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, view.get_allocated_width(), view.get_allocated_height());
	var context = new Cairo.Context(surface);
	var rows = window.history.rows();
	var names = new string[0];

	view.draw(context);
	surface.flush();

	var data = (uint8*)surface.get_data();
	var stride = surface.get_stride();
	var end = int.min(column.get_x_offset() + column.get_width(), surface.get_width());

	for (var i = 0; i < rows.length; i++)
	{
		Gdk.Rectangle area;
		int x;
		int top;
		var count = 0;

		view.get_background_area(new Gtk.TreePath.from_indices(i), column, out area);
		view.convert_bin_window_to_widget_coords(area.x, area.y, out x, out top);

		for (var y = int.max(top, 0); y < int.min(top + area.height, surface.get_height()); y++)
		{
			for (var column_x = column.get_x_offset(); column_x < end; column_x++)
			{
				var pixel = data + y * stride + column_x * 4;

				if (pixel[2] == 0xfc && pixel[1] == 0xe9 && pixel[0] == 0x4f)
				{
					count++;
				}
			}
		}

		if (count > 0)
		{
			names += rows[i].get_subject();
		}
	}

	return string.joinv(",", names);
}

public static Gtk.MenuItem? menu_item(string label)
{
	foreach (var toplevel in Gtk.Window.list_toplevels())
	{
		foreach (var widget in find_all(toplevel, typeof(Gtk.MenuItem)))
		{
			var item = (Gtk.MenuItem)widget;

			if (item.get_mapped() && item.label == label)
			{
				return item;
			}
		}
	}

	return null;
}

public static Gtk.MenuItem? menu_item_starting(string prefix)
{
	foreach (var toplevel in Gtk.Window.list_toplevels())
	{
		foreach (var widget in find_all(toplevel, typeof(Gtk.MenuItem)))
		{
			var item = (Gtk.MenuItem)widget;

			if (item.get_mapped() && item.label.has_prefix(prefix))
			{
				return item;
			}
		}
	}

	return null;
}

public static string menu_labels()
{
	var labels = new string[0];

	foreach (var toplevel in Gtk.Window.list_toplevels())
	{
		foreach (var widget in find_all(toplevel, typeof(Gtk.MenuItem)))
		{
			var item = (Gtk.MenuItem)widget;

			if (item.get_mapped() && !(item is Gtk.SeparatorMenuItem))
			{
				labels += item.label.replace("_", "");
			}
		}
	}

	return string.joinv(",", labels);
}

public static Gittree.RefsRow row(Gittree.RefsList list, string short_name)
{
	foreach (var child in list.get_children())
	{
		var candidate = child as Gittree.RefsRow;

		if (candidate != null && candidate.reference.short_name == short_name)
		{
			return candidate;
		}
	}

	error("no row %s", short_name);
}

public static void scroll_to_row(Gittree.Window window, string subject, int hidden)
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

public static string submenu_labels(Gtk.MenuItem item)
{
	var labels = new string[0];

	foreach (var child in ((Gtk.Menu)item.submenu).get_children())
	{
		var entry = child as Gtk.MenuItem;

		if (entry != null && !(entry is Gtk.SeparatorMenuItem))
		{
			var check = entry as Gtk.CheckMenuItem;

			labels += (check != null && check.active ? "*" : "") + entry.label;
		}
	}

	return string.joinv(",", labels);
}

public static string top_row(Gittree.Window window)
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
