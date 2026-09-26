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

public static void click_at(int x, int y, int count)
{
	int status;

	try
	{
		Process.spawn_sync(null, {"xdotool", "mousemove", x.to_string(), y.to_string(), "click", "--repeat", count.to_string(), "--delay", "80", "1"}, null, SpawnFlags.SEARCH_PATH, null, null, null, out status);
		Process.check_exit_status(status);
	}
	catch (Error e)
	{
		Test.fail_printf("xdotool: %s", e.message);
	}
}

}
