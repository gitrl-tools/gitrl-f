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

public class CopyMenu : Gtk.Menu
{
	private Gtk.GestureMultiPress d_press;

	public signal bool find(double x, double y);

	public CopyMenu(Gtk.Widget widget)
	{
		attach_to_widget(widget, null);
		widget.destroy.connect(() => {
			destroy();
		});

		d_press = new Gtk.GestureMultiPress(widget);
		d_press.button = Gdk.BUTTON_SECONDARY;
		d_press.propagation_phase = Gtk.PropagationPhase.CAPTURE;
		d_press.pressed.connect((presses, x, y) => {
			foreach (var child in get_children())
			{
				child.destroy();
			}

			if (find(x, y) && get_children() != null)
			{
				d_press.set_state(Gtk.EventSequenceState.CLAIMED);
				popup_at_pointer(d_press.get_last_event(d_press.get_current_sequence()));
			}
		});
	}

	public void add_copy(string caption, string text)
	{
		var item = new Gtk.MenuItem.with_label(caption);

		item.activate.connect(() => {
			get_attach_widget().get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(text, -1);
		});
		item.show();
		add(item);
	}

	public void add_separator()
	{
		var separator = new Gtk.SeparatorMenuItem();

		separator.show();
		add(separator);
	}
}

}
