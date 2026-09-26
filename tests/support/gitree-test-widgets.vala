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

}
