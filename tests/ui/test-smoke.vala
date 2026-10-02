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
namespace GitrlfTest
{

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/smoke/window-shows-after-gitg-init", test_window_shows_after_gitg_init);

	return Test.run();
}

private static void test_window_shows_after_gitg_init()
{
	try
	{
		Gitg.init();
	}
	catch (Error e)
	{
		Test.fail_printf("Gitg.init() failed: %s", e.message);
		return;
	}

	var window = new Gtk.Window();
	window.show();

	while (Gtk.events_pending())
	{
		Gtk.main_iteration();
	}

	assert_true(window.get_realized());

	window.destroy();
}

}
