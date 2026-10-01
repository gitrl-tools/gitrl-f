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

[GtkTemplate (ui = "/io/github/li9i/gittree/ui/gittree-window.ui")]
public class Window : Gtk.ApplicationWindow
{
	private const ActionEntry[] s_action_entries = {
		{"dash", on_dash_activated},
		{"filter", on_filter_activated},
		{"preferences", on_preferences_activated},
		{"reload", on_reload_activated},
		{"search", on_search_activated},
	};

	[GtkChild]
	private unowned Gtk.StackSwitcher d_activities_switcher;
	[GtkChild]
	private unowned Gtk.Button d_dash_button;
	[GtkChild]
	private unowned Gtk.ToggleButton d_filter_button;
	[GtkChild]
	private unowned Gtk.MenuButton d_gear_menu;
	[GtkChild]
	private unowned Gtk.HeaderBar d_header_bar;
	[GtkChild]
	private unowned Gtk.InfoBar d_infobar;
	[GtkChild]
	private unowned Gtk.Label d_infobar_primary_label;
	[GtkChild]
	private unowned Gtk.Label d_infobar_secondary_label;
	[GtkChild]
	private unowned Gtk.Stack d_main_stack;
	[GtkChild]
	private unowned Gtk.ToggleButton d_search_button;
	[GtkChild]
	private unowned Gtk.Stack d_stack_activities;

	private DashView d_dash;
	private HistoryActivity d_history;
	private Settings d_interface_settings;
	private Poll d_poll;
	private Gitg.Repository? d_repository;
	private Settings d_state_settings;

	public bool error_shown
	{
		get { return d_infobar.visible; }
	}

	public string error_text
	{
		owned get { return d_infobar_secondary_label.label; }
	}

	public HistoryActivity history
	{
		get { return d_history; }
	}

	public bool polling
	{
		get { return d_poll.running; }
	}

	public Gitg.Repository? repository
	{
		get { return d_repository; }
	}

	public signal void reload();

	public Window(Gtk.Application application)
	{
		Object(application: application);
	}

	construct
	{
		d_state_settings = new Settings("%s.state.window".printf(Config.APPLICATION_ID));

		add_action_entries(s_action_entries, this);

		var builder = new Gtk.Builder.from_resource("/io/github/li9i/gittree/ui/gittree-menus.ui");
		d_gear_menu.menu_model = builder.get_object("gear-menu") as MenuModel;

		d_infobar.response.connect((id) => {
			d_infobar.hide();
		});

		d_dash = new DashView();
		d_dash.location_activated.connect((location) => {
			open_repository(location);
		});
		d_dash.repository_activated.connect((repository) => {
			set_repository(repository, null, {}, null);
		});
		d_dash.show_error.connect((primary, secondary) => {
			show_infobar(primary, secondary, Gtk.MessageType.ERROR);
		});
		d_main_stack.add_named(d_dash, "dash");

		d_history = new HistoryActivity();
		d_history.bind_property("search-visible", d_search_button, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
		d_history.bind_property("filter-visible", d_filter_button, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
		d_history.show_error.connect((primary, secondary) => {
			show_infobar(primary, secondary, Gtk.MessageType.ERROR);
		});

		var dash_tooltip = d_dash_button.tooltip_text;

		d_history.paned.notify["details-only"].connect(() => {
			d_dash_button.tooltip_text = d_history.paned.details_only ? _("Show the refs and the list") : dash_tooltip;
		});

		d_poll = new Poll();
		d_poll.changed.connect(() => {
			d_history.refresh();
		});

		d_interface_settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");
		d_interface_settings.changed["enable-monitoring"].connect(() => {
			update_poll();
		});

		reload.connect(() => {
			d_history.refresh();
			d_poll.reset();
		});

		destroy.connect(() => {
			d_poll.stop();
		});

		d_stack_activities.add_titled(d_history.widget, d_history.id, d_history.display_name);

		restore_state();

		show_dash();
	}

	protected override bool configure_event(Gdk.EventConfigure event)
	{
		if ((d_state_settings.get_int("state") & Gdk.WindowState.MAXIMIZED) == 0)
		{
			int width;
			int height;
			get_size(out width, out height);

			d_state_settings.set_value("size", new Variant("(ii)", width, height));
		}

		return base.configure_event(event);
	}

	protected override bool key_press_event(Gdk.EventKey event)
	{
		if (base.key_press_event(event))
		{
			return true;
		}

		return event.keyval == Gdk.Key.Escape && d_main_stack.visible_child_name == "activities" && d_history.escape();
	}

	private void on_dash_activated(SimpleAction action, Variant? parameter)
	{
		if (d_history.paned.details_only)
		{
			d_history.paned.details_only = false;
			return;
		}

		show_dash();
	}

	private void on_filter_activated(SimpleAction action, Variant? parameter)
	{
		if (d_filter_button.visible)
		{
			d_history.filter_visible = !d_history.filter_visible;
		}
	}

	private void on_preferences_activated(SimpleAction action, Variant? parameter)
	{
		new PreferencesDialog(this).present();
	}

	private void on_reload_activated(SimpleAction action, Variant? parameter)
	{
		reload();
	}

	private void on_search_activated(SimpleAction action, Variant? parameter)
	{
		if (d_search_button.visible)
		{
			d_history.toggle_search();
		}
	}

	public void open_repository(File location, Gee.Set<string>? ticks = null, string[] paths = {}, File? directory = null, string? text = null, bool ignore_case = false)
	{
		try
		{
			set_repository(Repository.open(location), ticks, paths, directory, text, ignore_case);
		}
		catch (Error e)
		{
			show_infobar(_("Failed to open repository"), e.message, Gtk.MessageType.ERROR);
			show_dash();
		}
	}

	private void restore_state()
	{
		var size = d_state_settings.get_value("size");

		int width;
		int height;
		size.get("(ii)", out width, out height);

		if (width > 0 && height > 0)
		{
			set_default_size(width, height);
		}

		if ((d_state_settings.get_int("state") & Gdk.WindowState.MAXIMIZED) != 0)
		{
			maximize();
		}
	}

	private void set_repository(Gitg.Repository repository, Gee.Set<string>? ticks, string[] paths, File? directory, string? text = null, bool ignore_case = false)
	{
		d_repository = repository;
		d_history.open(repository, ticks, paths, directory, text, ignore_case);
		d_poll.repository = repository;
		update_poll();
		d_dash.add_repository(d_repository);
		update_title();
		show_activities();
	}

	public void show_activities()
	{
		d_main_stack.visible_child_name = "activities";

		d_dash_button.visible = true;
		d_activities_switcher.visible = d_stack_activities.get_children().length() > 1;
		d_filter_button.visible = true;
		d_search_button.visible = true;
	}

	public void show_dash()
	{
		d_main_stack.visible_child_name = "dash";
		d_poll.stop();

		d_dash_button.visible = false;
		d_activities_switcher.visible = false;
		d_filter_button.visible = false;
		d_search_button.visible = false;

		d_repository = null;
		update_title();
	}

	public void show_infobar(string primary, string secondary, Gtk.MessageType type)
	{
		d_infobar_primary_label.label = primary;
		d_infobar_secondary_label.label = secondary;
		d_infobar.message_type = type;
		d_infobar.show();
	}

	private void update_poll()
	{
		if (d_repository != null && d_interface_settings.get_boolean("enable-monitoring"))
		{
			d_poll.start();
		}
		else
		{
			d_poll.stop();
		}
	}

	private void update_title()
	{
		if (d_repository == null)
		{
			d_header_bar.title = "gittree";
			d_header_bar.subtitle = null;
			return;
		}

		d_header_bar.title = d_repository.name;

		var workdir = d_repository.get_workdir();
		var location = workdir != null ? workdir : d_repository.get_location();

		d_header_bar.subtitle = location != null ? Gitg.Utils.replace_home_dir_with_tilde(location) : null;
	}

	protected override bool window_state_event(Gdk.EventWindowState event)
	{
		d_state_settings.set_int("state", event.new_window_state);
		return base.window_state_event(event);
	}
}

}
