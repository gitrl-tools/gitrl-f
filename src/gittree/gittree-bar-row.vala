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

namespace Gittree
{

public class BarRow : Gtk.ScrolledWindow
{
	public BarRow(Gtk.Widget content)
	{
		var viewport = new Gtk.Viewport(null, null);

		viewport.shadow_type = Gtk.ShadowType.NONE;
		viewport.add(content);

		hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
		vscrollbar_policy = Gtk.PolicyType.NEVER;
		propagate_natural_width = true;
		add(viewport);
	}
}

}
