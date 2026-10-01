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

public class SearchSwitches : Object
{
	private Gtk.CheckButton d_case;
	private Gtk.CheckButton d_regex;

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
		d_regex = add(box, _("Regular expression"), _("Read the text as a regular expression, as git log -G does"));
	}

	private Gtk.CheckButton add(Gtk.Box box, string label, string tooltip)
	{
		var button = new Gtk.CheckButton.with_label(label);

		button.tooltip_text = tooltip;
		button.toggled.connect(() => changed());
		box.add(button);

		return button;
	}

	public TextMatch match(string text)
	{
		return new TextMatch(text, match_case, regex);
	}

	public SearchQuery query(string text)
	{
		return new SearchQuery(text, match_case, regex);
	}
}

}
