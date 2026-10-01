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

public class CopyMenu : Gtk.Menu
{
	private Gtk.MenuItem d_item;
	private Gtk.GestureMultiPress d_press;
	private string d_text;

	public signal bool find(double x, double y, out string caption, out string text);

	public CopyMenu(Gtk.Widget widget)
	{
		d_text = "";

		d_item = new Gtk.MenuItem();
		d_item.activate.connect(() => {
			get_attach_widget().get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(d_text, -1);
		});
		d_item.show();

		add(d_item);
		attach_to_widget(widget, null);

		d_press = new Gtk.GestureMultiPress(widget);
		d_press.button = Gdk.BUTTON_SECONDARY;
		d_press.propagation_phase = Gtk.PropagationPhase.CAPTURE;
		d_press.pressed.connect((presses, x, y) => {
			string caption;
			string text;

			if (find(x, y, out caption, out text))
			{
				d_item.label = caption;
				d_text = text;
				d_press.set_state(Gtk.EventSequenceState.CLAIMED);
				popup_at_pointer(d_press.get_last_event(d_press.get_current_sequence()));
			}
		});
	}
}

}
