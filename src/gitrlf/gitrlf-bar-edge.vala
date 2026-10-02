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

public class BarEdge : Object
{
	public static void drop(Gtk.SearchBar bar, Gtk.PositionType side)
	{
		var box = (Gtk.Container)((Gtk.Bin)bar.get_children().nth_data(0)).get_child();
		var width = (int)box.border_width;

		box.border_width = 0;
		box.margin_start = width;
		box.margin_end = width;
		box.margin_top = side == Gtk.PositionType.TOP ? 0 : width;
		box.margin_bottom = side == Gtk.PositionType.BOTTOM ? 0 : width;
	}
}

}
