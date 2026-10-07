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
	private unowned ChangesLane d_changes_gap;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_author;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_date;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_hash;
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
	private unowned Gtk.Label d_staged_count;
	[GtkChild]
	private unowned ChangesLane d_staged_lane;
	[GtkChild]
	private unowned Gtk.ListBoxRow d_staged_row;
	[GtkChild]
	private unowned Gtk.Label d_summary;
	[GtkChild]
	private unowned Gtk.Label d_unstaged_count;
	[GtkChild]
	private unowned ChangesLane d_unstaged_lane;
	[GtkChild]
	private unowned Gtk.ListBoxRow d_unstaged_row;

	private int d_pressed;
	private Settings d_state_settings;

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

	public ChangesLane changes_gap
	{
		get { return d_changes_gap; }
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

	public Gtk.Label staged_count
	{
		get { return d_staged_count; }
	}

	public ChangesLane staged_lane
	{
		get { return d_staged_lane; }
	}

	public Gtk.ListBoxRow staged_row
	{
		get { return d_staged_row; }
	}

	public Gtk.Label summary
	{
		get { return d_summary; }
	}

	public Gtk.Label unstaged_count
	{
		get { return d_unstaged_count; }
	}

	public ChangesLane unstaged_lane
	{
		get { return d_unstaged_lane; }
	}

	public Gtk.ListBoxRow unstaged_row
	{
		get { return d_unstaged_row; }
	}

	static construct
	{
		typeof(Gitg.CommitListView).ensure();
		typeof(Gitg.CellRendererLanes).ensure();
		typeof(ChangesLane).ensure();
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
}

}
