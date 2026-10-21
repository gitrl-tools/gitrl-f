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

[GtkTemplate (ui = "/io/github/li9i/gitrlf/ui/gitrlf-history-paned.ui")]
public class HistoryPaned : Gtk.Box
{
	[GtkChild]
	private unowned Gtk.Button d_all;
	[GtkChild]
	private unowned Gtk.Box d_box_details;
	[GtkChild]
	private unowned Gtk.Box d_box_main;
	[GtkChild]
	private unowned Gtk.Box d_box_sidebar;
	[GtkChild]
	private unowned Gtk.ListBox d_changes;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_author;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_date;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_hash;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_lines;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_subject;
	[GtkChild]
	private unowned Gitg.CommitListView d_commit_list_view;
	[GtkChild]
	private unowned Gtk.SearchEntry d_filter;
	[GtkChild]
	private unowned Gtk.Button d_none;
	[GtkChild]
	private unowned Gtk.Label d_notice;
	[GtkChild]
	private unowned Gtk.Paned d_paned_panels;
	[GtkChild]
	private unowned Gtk.Paned d_paned_sidebar;
	[GtkChild]
	private unowned Gtk.InfoBar d_path_bar;
	[GtkChild]
	private unowned Gtk.Label d_path_label;
	[GtkChild]
	private unowned Gtk.Spinner d_path_spinner;
	[GtkChild]
	private unowned RefsList d_refs_list;
	[GtkChild]
	private unowned Gtk.CellRendererText d_renderer_author;
	[GtkChild]
	private unowned Gtk.CellRendererText d_renderer_date;
	[GtkChild]
	private unowned Gtk.CellRendererText d_renderer_hash;
	[GtkChild]
	private unowned Gitg.CellRendererLanes d_renderer_subject;
	[GtkChild]
	private unowned Gtk.ScrolledWindow d_scrolled_window_commit_list;
	[GtkChild]
	private unowned Gtk.ScrolledWindow d_scrolled_window_refs;
	[GtkChild]
	private unowned Gtk.Stack d_stack_list;
	[GtkChild]
	private unowned Gtk.Label d_staged_added;
	[GtkChild]
	private unowned Gtk.Label d_staged_count;
	[GtkChild]
	private unowned Gtk.Box d_staged_label;
	[GtkChild]
	private unowned Gtk.Overlay d_staged_overlay;
	[GtkChild]
	private unowned Gtk.Label d_staged_removed;
	[GtkChild]
	private unowned Gtk.ListBoxRow d_staged_row;
	[GtkChild]
	private unowned Gtk.Label d_summary;
	[GtkChild]
	private unowned Gtk.TreeView d_titles;
	[GtkChild]
	private unowned Gtk.Label d_unstaged_added;
	[GtkChild]
	private unowned Gtk.Label d_unstaged_count;
	[GtkChild]
	private unowned Gtk.Box d_unstaged_label;
	[GtkChild]
	private unowned Gtk.Overlay d_unstaged_overlay;
	[GtkChild]
	private unowned Gtk.Label d_unstaged_removed;
	[GtkChild]
	private unowned Gtk.ListBoxRow d_unstaged_row;

	private const string[] TITLE_PROPERTIES = {
		"expand", "fixed-width", "min-width", "reorderable", "resizable",
		"sizing", "title", "visible"
	};

	private Gee.HashMap<Gtk.TreeViewColumn, Gtk.TreeViewColumn> d_columns;
	private Variant d_default_widths;
	private bool d_fitting;
	private int d_pressed;
	private string d_repository_path;
	private bool d_saving;
	private Settings d_state_settings;
	private CopyMenu d_titles_menu;

	public Gtk.Button all_button
	{
		get { return d_all; }
	}

	public Gtk.Box box_details
	{
		get { return d_box_details; }
	}

	public Gtk.ListBox changes
	{
		get { return d_changes; }
	}

	public Gtk.TreeViewColumn column_author
	{
		get { return d_column_author; }
	}

	public Gtk.TreeViewColumn column_date
	{
		get { return d_column_date; }
	}

	public Gtk.TreeViewColumn column_hash
	{
		get { return d_column_hash; }
	}

	public Gtk.TreeViewColumn column_lines
	{
		get { return d_column_lines; }
	}

	public Gtk.TreeViewColumn column_subject
	{
		get { return d_column_subject; }
	}

	public Gitg.CommitListView commit_list_view
	{
		get { return d_commit_list_view; }
	}

	public bool details_only
	{
		get { return !d_box_sidebar.visible; }

		set
		{
			var list = d_paned_panels.get_child1() == d_box_details ? d_paned_panels.get_child2() : d_paned_panels.get_child1();

			d_box_sidebar.visible = !value;
			list.visible = !value;

			if (!value)
			{
				d_commit_list_view.grab_focus();
			}
		}
	}

	public bool details_visible
	{
		get { return d_box_details.visible; }

		set
		{
			d_box_details.visible = value;

			if (value)
			{
				var length = d_paned_panels.orientation == Gtk.Orientation.VERTICAL ? d_paned_panels.get_allocated_height() : d_paned_panels.get_allocated_width();
				d_paned_panels.position = length / 2;
			}
		}
	}

	public Gtk.SearchEntry filter
	{
		get { return d_filter; }
	}

	public Gtk.Orientation inner_orientation
	{
		get { return d_paned_panels.orientation; }

		set
		{
			if (d_paned_panels.orientation == value)
			{
				return;
			}

			details_only = false;
			d_paned_panels.orientation = value;

			foreach (var widget in new Gtk.Widget[] { d_paned_sidebar, d_paned_panels, d_box_details, d_stack_list })
			{
				((Gtk.Container)widget.get_parent()).remove(widget);
			}

			if (value == Gtk.Orientation.HORIZONTAL)
			{
				d_paned_panels.pack1(d_box_details, true, true);
				d_paned_panels.pack2(d_stack_list, true, true);
				d_box_main.pack_start(d_paned_panels, true, true, 0);
				pack_start(d_paned_sidebar, true, true, 0);
			}
			else
			{
				d_paned_panels.pack1(d_paned_sidebar, true, true);
				d_paned_panels.pack2(d_box_details, true, true);
				d_box_main.pack_start(d_stack_list, true, true, 0);
				pack_start(d_paned_panels, true, true, 0);
			}
		}
	}

	public Gtk.Button none_button
	{
		get { return d_none; }
	}

	public Gtk.Label notice
	{
		get { return d_notice; }
	}

	public Gtk.Paned paned_panels
	{
		get { return d_paned_panels; }
	}

	public Gtk.Paned paned_sidebar
	{
		get { return d_paned_sidebar; }
	}

	public Gtk.InfoBar path_bar
	{
		get { return d_path_bar; }
	}

	public Gtk.Label path_label
	{
		get { return d_path_label; }
	}

	public Gtk.Spinner path_spinner
	{
		get { return d_path_spinner; }
	}

	public RefsList refs_list
	{
		get { return d_refs_list; }
	}

	public Gtk.CellRendererText renderer_author
	{
		get { return d_renderer_author; }
	}

	public Gtk.CellRendererText renderer_date
	{
		get { return d_renderer_date; }
	}

	public Gtk.CellRendererText renderer_hash
	{
		get { return d_renderer_hash; }
	}

	public Gitg.CellRendererLanes renderer_subject
	{
		get { return d_renderer_subject; }
	}

	public Gtk.ScrolledWindow scrolled_window_commit_list
	{
		get { return d_scrolled_window_commit_list; }
	}

	public Gtk.Stack stack_list
	{
		get { return d_stack_list; }
	}

	public Gtk.Label staged_added
	{
		get { return d_staged_added; }
	}

	public Gtk.Label staged_count
	{
		get { return d_staged_count; }
	}

	public Gtk.Label staged_removed
	{
		get { return d_staged_removed; }
	}

	public Gtk.ListBoxRow staged_row
	{
		get { return d_staged_row; }
	}

	public Gtk.Label summary
	{
		get { return d_summary; }
	}

	public Gtk.TreeView titles
	{
		get { return d_titles; }
	}

	public Gtk.Label unstaged_added
	{
		get { return d_unstaged_added; }
	}

	public Gtk.Label unstaged_count
	{
		get { return d_unstaged_count; }
	}

	public Gtk.Label unstaged_removed
	{
		get { return d_unstaged_removed; }
	}

	public Gtk.ListBoxRow unstaged_row
	{
		get { return d_unstaged_row; }
	}

	static construct
	{
		typeof(Gitg.CommitListView).ensure();
		typeof(Gitg.CellRendererLanes).ensure();
		typeof(HeadedList).ensure();
		typeof(RefsList).ensure();
	}

	construct
	{
		d_state_settings = new Settings(Config.APPLICATION_ID + ".state.history");

		if (d_state_settings.get_boolean("paned-sidebar-dragged"))
		{
			d_paned_sidebar.position = d_state_settings.get_int("paned-sidebar-position");
		}

		d_paned_sidebar.button_press_event.connect((event) => {
			d_pressed = d_paned_sidebar.position;
			return false;
		});
		d_paned_sidebar.button_release_event.connect((event) => {
			if (event.window == d_paned_sidebar.get_handle_window() && d_paned_sidebar.position != d_pressed)
			{
				d_state_settings.set_int("paned-sidebar-position", d_paned_sidebar.position);
				d_state_settings.set_boolean("paned-sidebar-dragged", true);
			}

			return false;
		});

		var interface_settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("orientation", this, "inner_orientation", SettingsBindFlags.GET);

		d_staged_overlay.get_child_position.connect(place_change_line);
		d_unstaged_overlay.get_child_position.connect(place_change_line);
		d_staged_overlay.size_allocate.connect_after(place_change_label);
		d_unstaged_overlay.size_allocate.connect_after(place_change_label);
		d_column_lines.notify["x-offset"].connect(queue_change_lines);
		d_column_lines.notify["width"].connect(queue_change_lines);
		d_column_subject.notify["x-offset"].connect(queue_change_lines);
		d_column_subject.notify["width"].connect(queue_change_lines);
		d_column_lines.notify["visible"].connect(queue_change_lines);
		d_column_subject.notify["visible"].connect(queue_change_lines);
		d_commit_list_view.hadjustment.value_changed.connect(
			queue_change_lines);

		restore_column_order();
		restore_hidden_columns();
		add_titles();
		d_titles_menu = new CopyMenu(d_titles);
		d_titles_menu.find.connect(fill_titles_menu);
		d_commit_list_view.columns_changed.connect(save_column_order);
		d_commit_list_view.draw.connect_after(keep_fitted_subject);
		d_titles.columns_changed.connect(follow_titles);
		destroy.connect(() => {
			d_titles.columns_changed.disconnect(follow_titles);
			d_commit_list_view.columns_changed.disconnect(save_column_order);
			d_columns.clear();
		});
	}

	private void add_titles()
	{
		d_columns = new Gee.HashMap<Gtk.TreeViewColumn, Gtk.TreeViewColumn>();
		d_titles.model = new Gtk.ListStore(1, typeof(string));

		foreach (var column in d_commit_list_view.get_columns())
		{
			var title = new Gtk.TreeViewColumn();

			foreach (var property in TITLE_PROPERTIES)
			{
				column.bind_property(property, title, property,
				                     BindingFlags.BIDIRECTIONAL
				                     | BindingFlags.SYNC_CREATE);
			}

			d_columns[title] = column;
			d_titles.append_column(title);
			column.notify["width"].connect(keep_fixed_width);
		}

		fit_titles();
		d_titles.style_updated.connect(fit_titles);
	}

	private Gtk.TreeViewColumn? column_named(string name)
	{
		foreach (var column in d_commit_list_view.get_columns())
		{
			if (name_of(column) == name)
			{
				return column;
			}
		}

		return null;
	}

	private bool fill_titles_menu(double x, double y)
	{
		var shown = 0;

		foreach (var title in d_titles.get_columns())
		{
			shown += title.visible ? 1 : 0;
		}

		foreach (var title in d_titles.get_columns())
		{
			var item = new Gtk.CheckMenuItem.with_label(title.title);

			item.active = title.visible;
			item.sensitive = !title.visible || shown > 1;
			item.toggled.connect(() => {
				title.visible = item.active;
				save_hidden_columns();
			});
			item.show();
			d_titles_menu.add(item);
		}

		return true;
	}

	public void fit_sidebar()
	{
		int minimum;
		int natural;
		int list;
		int scrolled;

		if (d_state_settings.get_boolean("paned-sidebar-dragged"))
		{
			return;
		}

		d_refs_list.get_preferred_width(out list, out natural);
		d_scrolled_window_refs.get_preferred_width(out scrolled, out natural);
		d_box_sidebar.get_preferred_width(out minimum, out natural);
		d_paned_sidebar.position = int.max(natural, d_refs_list.widest_row() + scrolled - list);
	}

	private void fit_titles()
	{
		foreach (var title in d_titles.get_columns())
		{
			int least;
			int natural;

			title.get_button().get_preferred_width(out least, out natural);
			title.min_width = natural;
		}
	}

	private Variant fixed_widths()
	{
		var widths = new VariantDict();

		foreach (var column in d_commit_list_view.get_columns())
		{
			widths.insert_value(name_of(column), column.fixed_width);
		}

		return widths.end();
	}

	private void follow_titles()
	{
		Gtk.TreeViewColumn? previous = null;

		foreach (var title in d_titles.get_columns())
		{
			d_commit_list_view.move_column_after(d_columns[title], previous);
			previous = d_columns[title];
		}
	}

	private bool keep_fitted_subject()
	{
		if (d_fitting)
		{
			d_fitting = false;
			d_column_subject.expand = false;
			d_column_subject.fixed_width = d_column_subject.width;
			save_column_widths();
		}

		return false;
	}

	private void keep_fixed_width(Object column, ParamSpec property)
	{
		var list_column = (Gtk.TreeViewColumn)column;

		if (list_column.fixed_width == -1)
		{
			list_column.fixed_width = list_column.width;
		}
	}

	private static string name_of(Gtk.TreeViewColumn column)
	{
		return ((Gtk.Buildable)column).get_name();
	}

	private int overlay_x(Gtk.Widget overlay, int x)
	{
		int widget_x;
		int y;

		d_commit_list_view.convert_bin_window_to_widget_coords(x, 0,
		                                                       out widget_x,
		                                                       out y);
		d_commit_list_view.translate_coordinates(overlay, widget_x, 0,
		                                         out widget_x, out y);

		return widget_x;
	}

	private void place_change_label(Gtk.Widget overlay,
	                                Gtk.Allocation allocation)
	{
		var label = overlay == d_staged_overlay ? d_staged_label
		                                        : d_unstaged_label;
		Gtk.Allocation subject = {
			allocation.x + overlay_x(overlay, d_column_subject.x_offset),
			allocation.y, d_column_subject.width, allocation.height
		};

		label.set_child_visible(d_column_subject.visible);
		label.size_allocate(subject);
	}

	private bool place_change_line(Gtk.Overlay overlay, Gtk.Widget widget,
	                               out Gdk.Rectangle allocation)
	{
		var removed = widget == d_staged_removed
		              || widget == d_unstaged_removed;
		var cell = (Gtk.CellRendererText)d_column_lines.get_cells()
			.nth_data(removed ? 1 : 0);
		var pad = (int)cell.xpad;
		int separator;
		int start;
		int width;

		d_commit_list_view.style_get("horizontal-separator", out separator);
		d_column_lines.cell_get_position(cell, out start, out width);
		widget.set_child_visible(d_column_lines.visible && width > 2 * pad);

		allocation = Gdk.Rectangle() {
			x = overlay_x(overlay, d_column_lines.x_offset + separator / 2
			                       + start) + pad,
			y = 0,
			width = int.max(width - 2 * pad, 0),
			height = overlay.get_allocated_height()
		};

		return true;
	}

	private void queue_change_lines()
	{
		d_staged_overlay.queue_resize();
		d_unstaged_overlay.queue_resize();
	}

	private void restore_column_order()
	{
		Gtk.TreeViewColumn? previous = null;

		foreach (var name in d_state_settings.get_strv("column-order"))
		{
			var column = column_named(name);

			if (column != null)
			{
				d_commit_list_view.move_column_after(column, previous);
				previous = column;
			}
		}
	}

	public void restore_column_widths(string repository)
	{
		var saved = new VariantDict(
			d_state_settings.get_value("column-widths")).lookup_value(
			repository, VariantType.VARDICT);
		var widths = saved ?? d_default_widths;

		d_saving = false;

		foreach (var column in d_commit_list_view.get_columns())
		{
			column.expand = false;
			column.fixed_width = widths.lookup_value(
				name_of(column), VariantType.INT32).get_int32();
		}

		d_fitting = saved == null;

		if (d_fitting)
		{
			d_column_subject.expand = true;
			d_column_subject.fixed_width = d_column_subject.min_width;
		}

		d_repository_path = repository;
		d_saving = true;
	}

	private void restore_hidden_columns()
	{
		foreach (var name in d_state_settings.get_strv("hidden-columns"))
		{
			var column = column_named(name);

			if (column != null)
			{
				column.visible = false;
			}
		}
	}

	private void save_column_order()
	{
		var names = new string[0];

		foreach (var column in d_commit_list_view.get_columns())
		{
			names += name_of(column);
		}

		d_state_settings.set_strv("column-order", names);
	}

	private void save_column_widths()
	{
		if (!d_saving)
		{
			return;
		}

		var saved = new VariantDict(
			d_state_settings.get_value("column-widths"));

		saved.insert_value(d_repository_path, fixed_widths());
		d_state_settings.set_value("column-widths", saved.end());
	}

	private void save_hidden_columns()
	{
		var names = new string[0];

		foreach (var column in d_commit_list_view.get_columns())
		{
			if (!column.visible)
			{
				names += name_of(column);
			}
		}

		d_state_settings.set_strv("hidden-columns", names);
	}

	public void watch_column_widths()
	{
		d_default_widths = fixed_widths();

		foreach (var column in d_commit_list_view.get_columns())
		{
			column.notify["fixed-width"].connect(save_column_widths);
		}
	}
}

}
