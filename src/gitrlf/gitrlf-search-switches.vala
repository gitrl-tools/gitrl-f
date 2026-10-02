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

public class SearchSwitches : Object
{
	private Gtk.ToggleButton d_case;
	private Gtk.ToggleButton d_regex;

	public bool match_case
	{
		get { return d_case.active; }
		set { d_case.active = value; }
	}

	public bool regex
	{
		get { return d_regex.active; }
		set { d_regex.active = value; }
	}

	public signal void changed();

	public SearchSwitches(Gtk.Box box)
	{
		d_case = add(box, _("Match case"), _("Tell capital and small letters apart"));
		d_regex = add(box, _("Regex"), _("Read the text as a regex, a POSIX extended regular expression, as git log -G does"));
	}

	private Gtk.ToggleButton add(Gtk.Box box, string label, string tooltip)
	{
		var button = new Gtk.ToggleButton.with_label(label);

		button.tooltip_text = tooltip;
		button.focus_on_click = false;
		button.toggled.connect(() => changed());
		box.add(button);

		return button;
	}
}

}
