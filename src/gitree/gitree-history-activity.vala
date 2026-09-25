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

namespace Gitree
{

public class HistoryActivity : Object, GitgExt.UIElement, GitgExt.Activity
{
	private Gtk.Box d_widget;

	public GitgExt.Application? application { owned get; construct set; }

	public string description
	{
		owned get { return _("Show the history of the refs you tick"); }
	}

	public string display_name
	{
		owned get { return _("History"); }
	}

	public string id
	{
		owned get { return "/io/github/li9i/gitree/Activities/History"; }
	}

	public Gitg.Repository? repository { get; set; }

	public Gtk.Widget? widget
	{
		owned get { return d_widget; }
	}

	construct
	{
		d_widget = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		d_widget.show();
	}
}

}
