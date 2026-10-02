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

public static string bold_hashes(Gittree.Window window, Gee.Map<string, int> plain)
{
	var names = new string[0];

	foreach (var entry in hash_ink(window).entries)
	{
		if (entry.value * 100 > plain[entry.key] * 115)
		{
			names += entry.key;
		}
	}

	var shown = new string[0];

	foreach (var commit in window.history.rows())
	{
		if (commit.get_subject() in names)
		{
			shown += commit.get_subject();
		}
	}

	return string.joinv(",", shown);
}

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

public static Gtk.CheckButton choice_box(Gittree.Window window, string label)
{
	foreach (var widget in find_all(list_bar(window), typeof(Gtk.RadioButton)))
	{
		if (((Gtk.Label)find_all(widget, typeof(Gtk.Label))[0]).label != label)
		{
			continue;
		}

		foreach (var inner in find_all(widget, typeof(Gtk.CheckButton)))
		{
			if (!(inner is Gtk.RadioButton))
			{
				return (Gtk.CheckButton)inner;
			}
		}
	}

	error("no choice %s", label);
}

public static string choice_labels(Gittree.Window window)
{
	var labels = new string[0];

	foreach (var widget in find_all(list_bar(window), typeof(Gtk.RadioButton)))
	{
		labels += ((Gtk.Label)find_all(widget, typeof(Gtk.Label))[0]).label;
	}

	return string.joinv(",", labels);
}

public static string choice_tips(Gittree.Window window)
{
	var tips = new string[0];

	foreach (var widget in find_all(list_bar(window), typeof(Gtk.RadioButton)))
	{
		tips += widget.tooltip_text;
	}

	return string.joinv("|", tips);
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

private static Cairo.ImageSurface drawn(Gtk.Widget widget)
{
	var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, widget.get_allocated_width(), widget.get_allocated_height());

	widget.draw(new Cairo.Context(surface));
	surface.flush();

	return surface;
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

public static Gee.Map<string, int> hash_ink(Gittree.Window window)
{
	var view = window.history.paned.commit_list_view;
	var column = window.history.paned.column_hash;
	var surface = drawn(view);
	var data = (uint8*)surface.get_data();
	var stride = surface.get_stride();
	var rows = window.history.rows();
	var ink = new Gee.HashMap<string, int>();

	for (var i = 0; i < rows.length; i++)
	{
		Gdk.Rectangle area;
		int x;
		int y;
		var count = 0;

		view.get_background_area(new Gtk.TreePath.from_indices(i), column, out area);
		view.convert_bin_window_to_widget_coords(area.x, area.y, out x, out y);

		var back = data + (y + area.height / 2) * stride + (x + area.width - 2) * 4;
		var contrast = new int[area.width * area.height];
		var strongest = 0;
		var n = 0;

		for (var j = int.max(y, 0); j < int.min(y + area.height, surface.get_height()); j++)
		{
			for (var k = x; k < int.min(x + area.width, surface.get_width()); k++)
			{
				var pixel = data + j * stride + k * 4;

				contrast[n] = ((int)pixel[0] - back[0]).abs() + ((int)pixel[1] - back[1]).abs() + ((int)pixel[2] - back[2]).abs();
				strongest = int.max(strongest, contrast[n]);
				n++;
			}
		}

		for (var m = 0; m < n; m++)
		{
			if (contrast[m] * 2 > strongest)
			{
				count++;
			}
		}

		ink[rows[i].get_subject()] = count;
	}

	return ink;
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

public static string lit_rows(Gittree.Window window)
{
	var view = window.history.paned.commit_list_view;
	var surface = drawn(view);
	var rows = window.history.rows();
	var names = new string[0];
	var data = (uint8*)surface.get_data();
	var stride = surface.get_stride();
	Gdk.Rectangle area;
	int x;
	int y;

	view.get_background_area(new Gtk.TreePath.from_indices(rows.length - 1), window.history.paned.column_author, out area);
	view.convert_bin_window_to_widget_coords(area.x + area.width - 2, area.y + area.height + 4, out x, out y);

	var plain = *(uint32*)(data + y * stride + x * 4) & 0xffffff;

	for (var i = 0; i < rows.length; i++)
	{
		view.get_background_area(new Gtk.TreePath.from_indices(i), window.history.paned.column_author, out area);
		view.convert_bin_window_to_widget_coords(area.x + area.width - 2, area.y + area.height / 2, out x, out y);

		if ((*(uint32*)(data + y * stride + x * 4) & 0xffffff) != plain)
		{
			names += rows[i].get_subject();
		}
	}

	return string.joinv(",", names);
}

public static string marked_rows(Gittree.Window window, Gtk.TreeViewColumn column)
{
	var view = window.history.paned.commit_list_view;
	var surface = drawn(view);
	var rows = window.history.rows();
	var names = new string[0];
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

public static string selected_label_text(Gtk.Widget root)
{
	foreach (var widget in find_all(root, typeof(Gtk.Label)))
	{
		var label = (Gtk.Label)widget;
		var start = 0;
		var end = 0;

		if (label.selectable && label.get_selection_bounds(out start, out end) && start != end)
		{
			return label.get_text();
		}
	}

	return "";
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

public static string ticked_choices(Gittree.Window window)
{
	var names = new string[0];

	foreach (var widget in find_all(list_bar(window), typeof(Gtk.RadioButton)))
	{
		var label = ((Gtk.Label)find_all(widget, typeof(Gtk.Label))[0]).label;

		if (choice_box(window, label).active)
		{
			names += label;
		}
	}

	return string.joinv("|", names);
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
