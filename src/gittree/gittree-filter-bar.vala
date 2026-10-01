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
	private Gtk.SearchEntry d_field;
	private Gtk.Label d_problem;
	private SearchSwitches d_switches;

	public Gtk.SearchEntry field
	{
		get { return d_field; }
	}

	public bool match_case
	{
		get { return d_switches.match_case; }
		set { d_switches.match_case = value; }
	}

	public string problem
	{
		owned get { return d_problem.label; }
	}

	public bool regex
	{
		get { return d_switches.regex; }
		set { d_switches.regex = value; }
	}

	public signal void applied(string text, bool match_case, bool regex);

	public FilterBar()
	{
		d_field = new Gtk.SearchEntry();
		d_field.width_chars = 40;
		d_field.activate.connect(apply);
		d_field.search_changed.connect(() => check());
		d_field.stop_search.connect(() => {
			search_mode_enabled = false;
		});

		d_problem = new Gtk.Label(null);

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(d_field);

		d_switches = new SearchSwitches(box, false);
		d_switches.changed.connect(() => check());

		var filter = new Gtk.Button.with_label(_("Filter"));
		filter.clicked.connect(apply);

		box.add(filter);
		box.add(d_problem);
		box.show_all();

		add(box);
		check();

		notify["search-mode-enabled"].connect(() => {
			if (search_mode_enabled)
			{
				d_field.grab_focus();
			}
		});
	}

	private void apply()
	{
		if (check())
		{
			applied(d_field.text, d_switches.match_case, d_switches.regex);
		}
	}

	private bool check()
	{
		var bad = d_switches.match(d_field.text).error != null;
		var style = d_field.get_style_context();

		d_field.placeholder_text = d_switches.regex ? _("Only commits whose added or removed lines match this")
		                                           : _("Only commits that add or remove this text");
		d_problem.label = bad ? _("Bad regular expression") : "";

		if (bad)
		{
			style.add_class("error");
		}
		else
		{
			style.remove_class("error");
		}

		return !bad;
	}
}

}
