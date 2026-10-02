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

public delegate void StepFunc(int direction);

public class SearchKeys : Object
{
	public static void attach(Gtk.SearchEntry field, Gtk.Box box, owned StepFunc step)
	{
		var previous = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.BUTTON);
		previous.tooltip_text = _("Previous match (Shift+Enter)");
		previous.clicked.connect(() => step(-1));

		var next = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.BUTTON);
		next.tooltip_text = _("Next match (Enter)");
		next.clicked.connect(() => step(1));

		box.add(previous);
		box.add(next);

		field.activate.connect(() => step(1));
		field.next_match.connect(() => step(1));
		field.previous_match.connect(() => step(-1));
		field.key_press_event.connect((event) => {
			var enter = event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter;

			if (enter && (event.state & Gdk.ModifierType.SHIFT_MASK) != 0)
			{
				step(-1);
				return true;
			}

			return false;
		});
	}
}

}
