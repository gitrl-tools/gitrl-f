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

public class PreferencesDialog : Gtk.Dialog
{
	private bool d_block;
	private Settings d_history_settings;
	private Settings d_interface_settings;

	public PreferencesDialog(Gtk.Window? parent)
	{
		Object(title: _("Preferences"),
		       transient_for: parent,
		       use_header_bar: 1,
		       destroy_with_parent: true);
	}

	construct
	{
		d_interface_settings = new Settings("%s.preferences.interface".printf(Config.APPLICATION_ID));
		d_history_settings = new Settings("%s.preferences.history".printf(Config.APPLICATION_ID));

		set_default_size(500, -1);

		var notebook = new Gtk.Notebook();
		notebook.margin = 12;

		notebook.append_page(build_interface_page(), new Gtk.Label(_("Interface")));
		notebook.append_page(build_history_page(), new Gtk.Label(_("History")));

		get_content_area().add(notebook);

		show_all();
	}

	private void add_row(Gtk.Grid grid, ref int row, string label_text, Gtk.Widget control)
	{
		var label = new Gtk.Label.with_mnemonic(label_text);
		label.xalign = 0;
		label.mnemonic_widget = control;

		control.hexpand = true;

		grid.attach(label, 0, row, 1, 1);
		grid.attach(control, 1, row, 1, 1);

		row++;
	}

	private void add_wide_row(Gtk.Grid grid, ref int row, Gtk.Widget control)
	{
		grid.attach(control, 0, row, 2, 1);
		row++;
	}

	private Gtk.Widget build_history_page()
	{
		var grid = new_page_grid();
		var row = 0;

		var collapse = new Gtk.CheckButton.with_mnemonic(_("Collapse inactive lanes"));
		d_history_settings.bind("collapse-inactive-lanes-enabled", collapse, "active",
		                        SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, collapse);

		var scale_box = new Gtk.Grid();
		scale_box.margin_start = 12;
		scale_box.column_spacing = 6;

		var early = new Gtk.Label(_("Early"));
		var late = new Gtk.Label(_("Late"));
		var scale = new Gtk.Scale(Gtk.Orientation.HORIZONTAL, new Gtk.Adjustment(0, 0, 5, 1, 1, 1));
		scale.digits = 0;
		scale.draw_value = false;
		scale.hexpand = true;

		scale_box.attach(early, 0, 0, 1, 1);
		scale_box.attach(scale, 1, 0, 1, 1);
		scale_box.attach(late, 2, 0, 1, 1);
		add_wide_row(grid, ref row, scale_box);

		scale.set_value(d_history_settings.get_int("collapse-inactive-lanes"));

		scale.adjustment.value_changed.connect((adjustment) => {
			if (d_block)
			{
				return;
			}

			var value = round_value(adjustment.get_value());

			if (d_history_settings.get_int("collapse-inactive-lanes") != value)
			{
				d_history_settings.set_int("collapse-inactive-lanes", value);
			}

			d_block = true;
			adjustment.set_value(value);
			d_block = false;
		});

		var changed = d_history_settings.changed["collapse-inactive-lanes"].connect(() => {
			var value = d_history_settings.get_int("collapse-inactive-lanes");

			if (round_value(scale.get_value()) != value)
			{
				d_block = true;
				scale.set_value(value);
				d_block = false;
			}
		});

		destroy.connect(() => {
			d_history_settings.disconnect(changed);
		});

		var topological = new Gtk.CheckButton.with_mnemonic(_("Show history in topological order"));
		d_history_settings.bind("topological-order", topological, "active", SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, topological);

		var mainline = new Gtk.CheckButton.with_mnemonic(_("Preserve mainline for currently checked out branch"));
		d_history_settings.bind("mainline-head", mainline, "active", SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, mainline);

		return grid;
	}

	private Gtk.Widget build_interface_page()
	{
		var grid = new_page_grid();
		var row = 0;

		var orientation = new Gtk.ComboBoxText();
		orientation.append("horizontal", _("Horizontal"));
		orientation.append("vertical", _("Vertical"));
		d_interface_settings.bind("orientation", orientation, "active-id", SettingsBindFlags.DEFAULT);
		add_row(grid, ref row, _("_Layout:"), orientation);

		var use_default_font = new Gtk.CheckButton.with_mnemonic(_("Use the system fixed width font"));
		d_interface_settings.bind("use-default-font", use_default_font, "active",
		                          SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, use_default_font);

		var font_button = new Gtk.FontButton();
		d_interface_settings.bind("monospace-font-name", font_button, "font",
		                          SettingsBindFlags.DEFAULT);
		d_interface_settings.bind("use-default-font", font_button, "sensitive",
		                          SettingsBindFlags.GET | SettingsBindFlags.INVERT_BOOLEAN);
		add_row(grid, ref row, _("_Font:"), font_button);

		var gravatar = new Gtk.CheckButton.with_mnemonic(
			_("Use gravatar service to provide user avatars"));
		d_interface_settings.bind("use-gravatar", gravatar, "active",
		                          SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, gravatar);

		var monitoring = new Gtk.CheckButton.with_mnemonic(
			_("Reload automatically when the repository changes"));
		d_interface_settings.bind("enable-monitoring", monitoring, "active",
		                          SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, monitoring);

		var highlighting = new Gtk.CheckButton.with_mnemonic(
			_("Enable syntax highlighting of source code in diff views"));
		d_interface_settings.bind("enable-diff-highlighting", highlighting, "active",
		                          SettingsBindFlags.DEFAULT);
		add_wide_row(grid, ref row, highlighting);

		add_row(grid, ref row, _("Syntax highlighting _colour scheme:"),
		        style_scheme_chooser());

		return grid;
	}

	private Gtk.Grid new_page_grid()
	{
		var grid = new Gtk.Grid();
		grid.margin = 12;
		grid.row_spacing = 6;
		grid.column_spacing = 12;
		return grid;
	}

	private static int round_value(double value)
	{
		var whole = (int)value;

		return whole + (int)(value - whole > 0.5);
	}

	private Gtk.Widget style_scheme_chooser()
	{
		var schemes = new Gtk.ComboBoxText();
		var manager = Gtk.SourceStyleSchemeManager.get_default();

		foreach (var id in manager.get_scheme_ids())
		{
			var scheme = manager.get_scheme(id);
			schemes.append(id, scheme != null ? scheme.name : id);
		}

		d_interface_settings.bind("style-scheme", schemes, "active-id", SettingsBindFlags.DEFAULT);

		return schemes;
	}
}

}
