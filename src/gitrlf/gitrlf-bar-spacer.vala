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

public class BarSpacer : Gtk.Box
{
	private bool d_active;
	private Gtk.Widget d_before;
	private Gtk.Widget d_mirror;

	public bool active
	{
		get { return d_active; }
		set
		{
			d_active = value;
			queue_resize();
		}
	}

	public BarSpacer(Gtk.Widget mirror, Gtk.Widget before)
	{
		d_before = before;
		d_mirror = mirror;
	}

	public override void get_preferred_width(out int minimum, out int natural)
	{
		int ignored;

		minimum = 0;
		natural = 0;

		if (d_active)
		{
			var box = get_parent() as Gtk.Box;
			int left;

			d_mirror.get_preferred_width(out ignored, out natural);
			d_before.get_preferred_width(out ignored, out left);
			natural = int.max(natural - left - (box != null ? box.spacing : 0), 0);
		}
	}
}

}
