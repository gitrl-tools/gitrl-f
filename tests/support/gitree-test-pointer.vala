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

public static void click_at(int x, int y, int count, int button = 1)
{
	xdotool({"mousemove", x.to_string(), y.to_string(), "click", "--repeat", count.to_string(), "--delay", "80", button.to_string()});
}

public static void click_widget(Gtk.Widget widget, int button = 1)
{
	int x;
	int y;
	int origin_x;
	int origin_y;

	widget.translate_coordinates(widget.get_toplevel(), widget.get_allocated_width() / 2, widget.get_allocated_height() / 2, out x, out y);
	widget.get_toplevel().get_window().get_origin(out origin_x, out origin_y);

	click_at(origin_x + x, origin_y + y, 1, button);
}

public static void press_key(string name)
{
	xdotool({"key", name});
}

private static void xdotool(string[] arguments)
{
	string[] argv = { "xdotool" };
	int status;

	foreach (var argument in arguments)
	{
		argv += argument;
	}

	try
	{
		Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, null, null, out status);
		Process.check_exit_status(status);
	}
	catch (Error e)
	{
		Test.fail_printf("xdotool: %s", e.message);
	}
}

}
