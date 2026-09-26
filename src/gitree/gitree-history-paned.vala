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

[GtkTemplate (ui = "/io/github/li9i/gitree/ui/gitree-history-paned.ui")]
public class HistoryPaned : Gtk.Paned
{
	[GtkChild]
	private unowned Gtk.Button d_all;
	[GtkChild]
	private unowned Gtk.Box d_box_details;
	[GtkChild]
	private unowned Gtk.TreeViewColumn d_column_author;
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
	private unowned Gtk.InfoBar d_path_bar;
	[GtkChild]
	private unowned Gtk.Label d_path_label;
	[GtkChild]
	private unowned RefsList d_refs_list;
	[GtkChild]
	private unowned Gtk.CellRendererText d_renderer_author;
	[GtkChild]
	private unowned Gitg.CellRendererLanes d_renderer_subject;
	[GtkChild]
	private unowned Gtk.ScrolledWindow d_scrolled_window_commit_list;
	[GtkChild]
	private unowned Gtk.Stack d_stack_list;
	[GtkChild]
	private unowned Gtk.Label d_summary;

	public Gtk.Button all_button
	{
		get { return d_all; }
	}

	public Gtk.Box box_details
	{
		get { return d_box_details; }
	}

	public Gtk.TreeViewColumn column_author
	{
		get { return d_column_author; }
	}

	public Gtk.TreeViewColumn column_subject
	{
		get { return d_column_subject; }
	}

	public Gitg.CommitListView commit_list_view
	{
		get { return d_commit_list_view; }
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

			d_paned_panels.orientation = value;

			d_paned_panels.remove(d_stack_list);
			d_paned_panels.remove(d_box_details);

			if (value == Gtk.Orientation.HORIZONTAL)
			{
				d_paned_panels.pack1(d_box_details, true, true);
				d_paned_panels.pack2(d_stack_list, true, true);
			}
			else
			{
				d_paned_panels.pack1(d_stack_list, true, true);
				d_paned_panels.pack2(d_box_details, true, true);
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

	public Gtk.InfoBar path_bar
	{
		get { return d_path_bar; }
	}

	public Gtk.Label path_label
	{
		get { return d_path_label; }
	}

	public RefsList refs_list
	{
		get { return d_refs_list; }
	}

	public Gtk.CellRendererText renderer_author
	{
		get { return d_renderer_author; }
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

	public Gtk.Label summary
	{
		get { return d_summary; }
	}

	static construct
	{
		typeof(Gitg.CommitListView).ensure();
		typeof(Gitg.CellRendererLanes).ensure();
		typeof(RefsList).ensure();
	}

	construct
	{
		var state_settings = new Settings(Config.APPLICATION_ID + ".state.history");

		position = state_settings.get_int("paned-sidebar-position");

		notify["position"].connect(() => {
			state_settings.set_int("paned-sidebar-position", position);
		});

		var interface_settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("orientation", this, "inner_orientation", SettingsBindFlags.GET);
	}
}

}
