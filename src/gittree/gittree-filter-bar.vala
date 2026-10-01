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

public class FilterBar : Gtk.SearchBar
{
	private Gtk.CheckButton d_case;
	private Gtk.SearchEntry d_field;

	public Gtk.SearchEntry field
	{
		get { return d_field; }
	}

	public bool match_case
	{
		get { return d_case.active; }
		set { d_case.active = value; }
	}

	public signal void applied(string text, bool match_case);

	public FilterBar()
	{
		d_field = new Gtk.SearchEntry();
		d_field.width_chars = 40;
		d_field.placeholder_text = _("Only commits that add or remove this text");
		d_field.activate.connect(apply);
		d_field.stop_search.connect(() => {
			search_mode_enabled = false;
		});

		d_case = new Gtk.CheckButton.with_label(_("Match case"));
		d_case.active = false;

		var filter = new Gtk.Button.with_label(_("Filter"));
		filter.clicked.connect(apply);

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(d_field);
		box.add(d_case);
		box.add(filter);
		box.show_all();

		add(box);

		notify["search-mode-enabled"].connect(() => {
			if (search_mode_enabled)
			{
				d_field.grab_focus();
			}
		});
	}

	private void apply()
	{
		applied(d_field.text, d_case.active);
	}
}

}
