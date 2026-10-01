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

public class HistoryActivity : Object, GitgExt.UIElement, GitgExt.Activity, GitgExt.Searchable
{
	private History? d_all;
	private Gtk.Box d_box;
	private CopyMenu d_copy_menu;
	private bool d_details_queued;
	private Gitg.DiffView d_diff;
	private Gtk.GestureMultiPress d_file_press;
	private FilterBar d_filter_bar;
	private DiffFindBar d_find_bar;
	private bool d_find_closed;
	private bool d_find_with_pane;
	private History? d_full;
	private TextMatch d_match;
	private Gtk.Label d_match_count;
	private int[] d_matches;
	private HistoryPaned d_paned;
	private History? d_history;
	private double d_hold;
	private int d_hold_height;
	private bool d_ignore_case;
	private Ggit.OId? d_kept;
	private History? d_line_history;
	private string? d_line_label;
	private Cancellable? d_line_search;
	private LineHistory? d_lines;
	private Ggit.OId? d_lines_commit;
	private string? d_lines_path;
	private SList<Gitg.Ref> d_labels;
	private HistoryModel d_model;
	private string d_narrow_key;
	private History? d_narrow_source;
	private History? d_narrowed;
	private Gee.Map<Ggit.OId, Gee.List<string>>? d_names;
	private Gtk.CheckButton d_only_matches;
	private string[] d_paths;
	private Gtk.GestureMultiPress d_press;
	private bool d_press_on_row;
	private bool d_press_on_shown;
	private string[]? d_reading;
	private Gee.List<Ref> d_refs;
	private bool d_regex;
	private Gitg.Repository? d_repository;
	private Cancellable? d_search;
	private Settings d_settings;
	private Gtk.SearchBar d_search_bar;
	private Gtk.SearchEntry d_search_entry;
	private SearchSwitches d_search_switches;
	private string? d_text;
	private Gee.Set<string> d_ticks;
	private bool d_waiting;

	public GitgExt.Application? application { owned get; construct set; }

	public Gitg.DiffView diff_view
	{
		get { return d_diff; }
	}

	public string description
	{
		owned get { return _("Show the history of the refs you tick"); }
	}

	public File? directory { get; set; }

	public string display_name
	{
		owned get { return _("History"); }
	}

	public FilterBar filter_bar
	{
		get { return d_filter_bar; }
	}

	public bool filter_visible
	{
		get { return d_filter_bar.search_mode_enabled; }
		set { d_filter_bar.search_mode_enabled = value; }
	}

	public DiffFindBar find_bar
	{
		get { return d_find_bar; }
	}

	public string id
	{
		owned get { return "/io/github/li9i/gittree/Activities/History"; }
	}

	public string list_page
	{
		owned get { return d_paned.stack_list.visible_child_name; }
	}

	public string notice_text
	{
		owned get { return d_paned.notice.get_text(); }
	}

	public HistoryPaned paned
	{
		get { return d_paned; }
	}

	public string path_bar_text
	{
		owned get { return d_paned.path_bar.visible ? d_paned.path_label.get_text() : ""; }
	}

	public Gitg.Repository? repository
	{
		get { return d_repository; }
	}

	public Gitg.Commit? selected
	{
		owned get
		{
			Gtk.TreeModel model;
			Gtk.TreeIter iter;

			if (!d_paned.commit_list_view.get_selection().get_selected(out model, out iter))
			{
				return null;
			}

			return d_model.commit_from_iter(iter);
		}
	}

	public bool search_available
	{
		get { return true; }
	}

	public Gtk.Entry? search_entry
	{
		set {}
	}

	public string search_count
	{
		owned get { return d_match_count.label; }
	}

	public Gtk.SearchEntry search_field
	{
		get { return d_search_entry; }
	}

	public string search_text
	{
		owned get { return d_search_entry.text; }
		set { d_search_entry.text = value; }
	}

	public bool search_visible
	{
		get { return d_search_bar.search_mode_enabled; }
		set { d_search_bar.search_mode_enabled = value; }
	}

	public string summary_text
	{
		owned get { return d_paned.summary.label; }
	}

	public Gee.Set<string> ticks
	{
		owned get
		{
			var copy = new Gee.HashSet<string>();
			copy.add_all(d_ticks);
			return copy;
		}
	}

	public Gtk.Widget? widget
	{
		owned get { return d_box; }
	}

	public signal void show_error(string primary, string secondary);

	static construct
	{
		Gitg.WordMarks.func = WordDiff.refine_flat;
	}

	construct
	{
		d_hold = -1;
		d_model = new HistoryModel();
		d_paths = new string[0];
		d_refs = new Gee.ArrayList<Ref>();
		d_ticks = new Gee.HashSet<string>();
		d_settings = new Settings(Config.APPLICATION_ID + ".preferences.history");

		d_match = new TextMatch("", false, false, false);
		d_matches = new int[0];
		d_narrow_key = "";

		d_paned = new HistoryPaned();
		d_paned.commit_list_view.model = d_model;
		d_paned.column_subject.set_cell_data_func(d_paned.renderer_subject, lanes_data_func);
		d_paned.column_author.set_cell_data_func(d_paned.renderer_author, author_data_func);
		d_paned.column_hash.set_cell_data_func(d_paned.renderer_hash, hash_data_func);

		d_search_entry = new Gtk.SearchEntry();
		d_search_entry.width_chars = 40;
		d_search_entry.placeholder_text = _("Subject, message, author or hash");

		d_match_count = new Gtk.Label(null);
		d_match_count.width_chars = 12;
		d_match_count.xalign = 0;

		var search_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		search_box.add(d_search_entry);
		SearchKeys.attach(d_search_entry, search_box, step);
		d_search_switches = new SearchSwitches(search_box, true);
		d_search_switches.changed.connect(find_matches);

		d_only_matches = new Gtk.CheckButton.with_label(_("Only matches"));
		d_only_matches.tooltip_text = _("Hide the commits that do not match");
		d_only_matches.toggled.connect(find_matches);
		search_box.add(d_only_matches);
		search_box.add(d_match_count);

		d_search_bar = new Gtk.SearchBar();
		d_search_bar.add(search_box);
		d_search_bar.notify["search-mode-enabled"].connect(() => {
			if (d_search_bar.search_mode_enabled)
			{
				d_search_entry.grab_focus();
				d_search_entry.select_region(0, -1);
			}
			else
			{
				d_paned.commit_list_view.grab_focus();
			}

			find_matches();
			notify_property("search-visible");
		});
		d_search_entry.stop_search.connect(() => {
			d_search_bar.search_mode_enabled = false;
		});

		d_search_entry.search_changed.connect(() => {
			find_matches();
		});

		d_filter_bar = new FilterBar();
		d_filter_bar.applied.connect((text, match_case, regex, paths) => {
			apply(text, !match_case, regex, paths);
		});
		d_filter_bar.notify["search-mode-enabled"].connect(() => {
			notify_property("filter-visible");
		});

		d_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		d_box.add(d_search_bar);
		d_box.add(d_filter_bar);
		d_box.add(d_paned);
		d_box.show_all();
		d_box.destroy.connect(stop_search);

		d_press = new Gtk.GestureMultiPress(d_paned.commit_list_view);
		d_press.button = Gdk.BUTTON_PRIMARY;
		d_press.propagation_phase = Gtk.PropagationPhase.CAPTURE;
		d_press.pressed.connect((presses, x, y) => {
			int bin_x;
			int bin_y;
			Gtk.TreePath? path;

			d_paned.commit_list_view.convert_widget_to_bin_window_coords((int)x, (int)y, out bin_x, out bin_y);
			d_paned.commit_list_view.get_path_at_pos(bin_x, bin_y, out path, null, null, null);

			d_press_on_row = path != null;
			d_press_on_shown = d_paned.details_visible && path != null && d_paned.commit_list_view.get_selection().path_is_selected(path);
		});
		d_press.released.connect(() => {
			if (d_press_on_row)
			{
				d_paned.details_visible = !d_press_on_shown;
			}
		});

		d_copy_menu = new CopyMenu(d_paned.commit_list_view);
		d_copy_menu.find.connect(prepare_copy);

		d_paned.commit_list_view.row_activated.connect(() => {
			var event = Gtk.get_current_event();

			if (event != null && event.type != Gdk.EventType.KEY_PRESS)
			{
				return;
			}

			d_paned.details_visible = !d_paned.details_visible;

			if (d_paned.details_visible && d_diff.diff != null && d_diff.diff.get_num_deltas() == 1)
			{
				d_paned.details_only = true;
			}
		});

		d_diff = new Gitg.DiffView();
		d_diff.vexpand = true;

		var close = new Gtk.Button.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
		close.tooltip_text = _("Show the refs and the list (Escape)");
		close.halign = Gtk.Align.END;
		close.valign = Gtk.Align.START;
		close.margin = 12;
		close.no_show_all = true;
		close.clicked.connect(() => {
			d_paned.details_only = false;
		});

		d_paned.notify["details-only"].connect(() => {
			close.visible = d_paned.details_only;
		});

		d_paned.notify["details-visible"].connect(() => {
			if (!d_paned.details_visible)
			{
				d_find_with_pane = true;
				d_find_bar.search_mode_enabled = false;
				d_find_with_pane = false;
			}

			show_details();
			fill_find_bar(false);
		});

		d_diff.files_changed.connect(offer_file_history);
		d_diff.files_changed.connect(offer_line_history);

		d_find_bar = new DiffFindBar(d_diff);
		d_find_bar.notify["search-mode-enabled"].connect(() => {
			if (!d_find_bar.search_mode_enabled && !d_find_with_pane)
			{
				d_find_closed = true;
			}
		});
		d_paned.box_details.add(d_find_bar);

		var overlay = new Gtk.Overlay();
		overlay.add(d_diff);
		overlay.add_overlay(close);
		overlay.show_all();
		d_paned.box_details.add(overlay);

		d_file_press = new Gtk.GestureMultiPress(d_diff);
		d_file_press.button = Gdk.BUTTON_PRIMARY;
		d_file_press.propagation_phase = Gtk.PropagationPhase.CAPTURE;
		d_file_press.released.connect(() => {
			var target = Gtk.get_event_widget(Gtk.get_current_event());

			Idle.add(() => {
				if (opens_files(target))
				{
					d_paned.details_only = true;
				}

				return false;
			});
		});

		var diff_settings = new Settings(Config.APPLICATION_ID + ".preferences.diff");

		diff_settings.bind("ignore-whitespace", d_diff, "ignore-whitespace", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("changes-inline", d_diff, "changes-inline", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("context-lines", d_diff, "context-lines", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("tab-width", d_diff, "tab-width", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("wrap", d_diff, "wrap-lines", SettingsBindFlags.GET | SettingsBindFlags.SET);

		var interface_settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("use-gravatar", d_diff, "use-gravatar", SettingsBindFlags.GET | SettingsBindFlags.SET);
		interface_settings.bind("enable-diff-highlighting", d_diff, "highlight", SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_paned.commit_list_view.get_selection().changed.connect(() => {
			if (selected != null)
			{
				d_kept = null;
			}

			queue_details();
			show_match_count();
		});
		d_paned.commit_list_view.size_allocate.connect_after((allocation) => {
			if (d_hold >= 0)
			{
				d_paned.scrolled_window_commit_list.vadjustment.value = d_hold;
				d_hold = -1;
			}
		});

		d_paned.path_bar.response.connect((response) => {
			if (response == Gtk.ResponseType.CLOSE && d_lines != null)
			{
				lift_lines();
			}
			else if (response == Gtk.ResponseType.CLOSE)
			{
				lift_filter();
			}
		});

		d_paned.refs_list.ticks_changed.connect(() => {
			set_ticks(d_paned.refs_list.ticks);
		});
		d_paned.refs_list.ref_activated.connect((reference) => {
			jump(reference.name);
		});
		d_paned.filter.search_changed.connect(() => {
			d_paned.refs_list.filter_text = d_paned.filter.text;
		});
		d_paned.all_button.clicked.connect(() => {
			d_paned.refs_list.tick_all();
		});
		d_paned.none_button.clicked.connect(() => {
			d_paned.refs_list.tick_none();
		});

		d_settings.changed["topological-order"].connect(() => {
			refresh();
		});
		d_settings.changed["mainline-head"].connect(() => {
			show_ticks();
		});
		d_settings.changed["collapse-inactive-lanes"].connect(() => {
			show_ticks();
		});
		d_settings.changed["collapse-inactive-lanes-enabled"].connect(() => {
			show_ticks();
		});
	}

	public void apply(string text, bool ignore_case, bool regex, string[] paths)
	{
		drop_lines();

		if (string.joinv("\n", paths) != string.joinv("\n", d_paths))
		{
			read_paths(paths, text != "" ? text : null, ignore_case, regex);
			return;
		}

		if (text != "")
		{
			apply_filter(text, ignore_case, regex);
			return;
		}

		if (d_paths.length == 0)
		{
			lift_filter();
			return;
		}

		stop_search();
		d_text = null;
		d_regex = false;
		show_base();
	}

	public void apply_filter(string text, bool ignore_case, bool regex = false)
	{
		if (d_repository == null || d_full == null)
		{
			return;
		}

		var waiting = d_waiting;

		drop_lines();
		d_find_closed = false;
		d_text = text;
		d_ignore_case = ignore_case;
		d_regex = regex;
		search(waiting);
		show_path_bar();

		if (waiting)
		{
			show_ticks();
		}
	}

	private void add_line_items(Gitg.DiffViewFile file, Gtk.TextView view, Gtk.Widget popup)
	{
		var menu = popup as Gtk.Menu;
		var commit = d_diff.commit;

		if (menu == null || commit == null)
		{
			return;
		}

		Gtk.TextIter start;
		Gtk.TextIter end;
		var selected = view.buffer.get_selection_bounds(out start, out end);
		var from = selected ? start.get_offset() : view.get_data<int>("gittree-click");
		var to = selected ? end.get_offset() : from;
		var rows = file.get_lines();
		var origins = new Ggit.DiffLineType[rows.size];
		var old_numbers = new int[rows.size];
		var new_numbers = new int[rows.size];
		var offsets = new int[rows.size];
		var views = file.get_text_views();
		var side = 0;

		for (var i = 0; i < rows.size; i++)
		{
			origins[i] = rows[i].get_origin();
			old_numbers[i] = rows[i].get_old_lineno();
			new_numbers[i] = rows[i].get_new_lineno();
			offsets[i] = file.get_line_offset(view, i);
		}

		for (var i = 0; i < views.length; i++)
		{
			if (views[i] == view)
			{
				side = i;
			}
		}

		var lines = LineHistory.of_view(origins, old_numbers, new_numbers, offsets, from, to, side, file.split);

		if (lines == null)
		{
			return;
		}

		var delta = file.info.delta;
		var path = lines.from_parent ? delta.get_old_file().get_path() : delta.get_new_file().get_path();
		var dig = lines.from_parent ? diff_parent(commit) : commit.get_id();

		if (dig == null || path == null)
		{
			return;
		}

		var separator = new Gtk.SeparatorMenuItem();
		var item = new Gtk.MenuItem.with_label(selected ? _("Show history of the selected lines") : _("Show history of this line"));

		item.activate.connect(() => show_line_history(lines, path, dig));
		separator.show();
		item.show();
		menu.append(separator);
		menu.append(item);
	}

	private void author_data_func(Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter)
	{
		var commit = d_model.commit_from_iter(iter);

		if (commit != null && !d_match.is_empty)
		{
			((Gtk.CellRendererText)cell).markup = Search.marked(commit.get_author().get_name(), d_match);
		}
	}

	private static string bold_list(string[] paths)
	{
		var names = new string[0];

		foreach (var path in paths)
		{
			names += "<b>%s</b>".printf(Markup.escape_text(path));
		}

		return string.joinv(", ", names);
	}

	private Ggit.OId? diff_parent(Gitg.Commit commit)
	{
		var parent = d_diff.parent_commit;

		if (parent != null)
		{
			return parent.get_id();
		}

		var parents = commit.get_parents();

		return parents.size > 0 ? parents.get_id(0) : null;
	}

	private string? diff_selection(out Gtk.TextView? view, out int offset)
	{
		var window = d_box.get_toplevel() as Gtk.Window;

		view = window != null ? window.get_focus() as Gtk.TextView : null;
		offset = 0;

		if (view == null || !view.is_ancestor(d_diff))
		{
			return null;
		}

		Gtk.TextIter start;
		Gtk.TextIter end;

		if (!view.buffer.get_selection_bounds(out start, out end) || start.get_line() != end.get_line())
		{
			return null;
		}

		offset = start.get_offset();

		return view.buffer.get_text(start, end, false);
	}

	private void drop_lines()
	{
		if (d_line_search != null)
		{
			d_line_search.cancel();
			d_line_search = null;
		}

		d_lines = null;
		d_line_history = null;
		d_line_label = null;
	}

	public bool escape()
	{
		foreach (var bar in new Gtk.SearchBar[] { d_search_bar, d_find_bar, d_filter_bar })
		{
			if (bar.search_mode_enabled)
			{
				bar.search_mode_enabled = false;
				return true;
			}
		}

		if (d_paned.details_only)
		{
			d_paned.details_only = false;
			return true;
		}

		if (d_paned.details_visible)
		{
			d_paned.details_visible = false;
			d_paned.commit_list_view.grab_focus();
			return true;
		}

		return false;
	}

	private void fill_find_bar(bool refill)
	{
		if (d_text == null || d_search != null || d_lines != null || !d_paned.details_visible || d_diff.commit == null)
		{
			return;
		}

		if (!d_find_bar.search_mode_enabled && d_find_closed)
		{
			return;
		}

		if (!d_find_bar.search_mode_enabled || refill)
		{
			d_find_bar.fill(d_text, !d_ignore_case, d_regex);
		}

		d_find_bar.step_to_first();
	}

	private void find_matches()
	{
		d_match = d_search_switches.match(d_search_bar.search_mode_enabled ? d_search_entry.text.strip() : "");

		if (narrow_key() != d_narrow_key)
		{
			show_ticks();
			return;
		}

		mark_matches();
	}

	private bool finds_in_diff()
	{
		if (!d_paned.details_visible)
		{
			return false;
		}

		if (d_paned.details_only)
		{
			return true;
		}

		var window = d_box.get_toplevel() as Gtk.Window;
		var focus = window != null ? window.get_focus() : null;

		return focus != null && focus.is_ancestor(d_paned.box_details);
	}

	private bool follows()
	{
		return d_repository != null && d_paths.length > 0 && Filter.is_one_file(d_repository, pathspec());
	}

	private File git_directory()
	{
		if (directory != null)
		{
			return directory;
		}

		var top = d_repository.get_workdir();

		if (top != null)
		{
			return top;
		}

		return d_repository.get_location();
	}

	private void hash_data_func(Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter)
	{
		var commit = d_model.commit_from_iter(iter);

		if (commit != null)
		{
			var hash = commit.get_id().to_string().substring(0, 7);
			((Gtk.CellRendererText)cell).markup = Search.marked(hash, d_match);
		}
	}

	public void jump(string name)
	{
		if (!d_ticks.contains(name))
		{
			var ticks = this.ticks;
			ticks.add(name);
			set_ticks(ticks);
		}

		foreach (var reference in d_refs)
		{
			if (reference.name == name && shown_history() != null)
			{
				var start = shown_history().start_of(reference.target);

				if (start != null)
				{
					select(start);
				}
			}
		}
	}

	public string[] labels_for(Gitg.Commit commit)
	{
		var names = new string[0];

		foreach (var label in ticked_labels(commit))
		{
			names += label.parsed_name.shortname;
		}

		return names;
	}

	private void keep_top(Gitg.Commit[] before, double scroll, int height)
	{
		if (height == 0)
		{
			return;
		}

		d_hold = 0;
		d_hold_height = height;

		if (scroll <= 0)
		{
			return;
		}

		var top = (int)(scroll / height);

		d_hold = d_model.size * height;

		for (var i = top; i < before.length; i++)
		{
			var path = d_model.path_from_commit(before[i].get_id());

			if (path != null)
			{
				d_hold = path.get_indices()[0] * height + (i == top ? scroll - top * height : 0);
				return;
			}
		}
	}

	private void lanes_data_func(Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter)
	{
		var lanes = (Gitg.CellRendererLanes)cell;
		var commit = d_model.commit_from_iter(iter);

		if (commit == null)
		{
			return;
		}

		var next = iter;
		Gitg.Commit? next_commit = null;

		if (d_model.iter_next(ref next))
		{
			next_commit = d_model.commit_from_iter(next);
		}

		d_labels = ticked_labels(commit);

		lanes.commit = commit;
		lanes.next_commit = next_commit;
		lanes.labels = d_labels;

		if (!d_match.is_empty)
		{
			lanes.markup = Search.marked(commit.get_subject(), d_match);
		}
	}

	public void lift_filter()
	{
		stop_search();
		d_text = null;
		d_regex = false;

		if (d_paths.length > 0)
		{
			var unlimited = follows();

			d_paths = new string[0];
			d_diff.options.pathspec = null;
			d_names = null;

			try
			{
				d_full = unlimited ? d_full : read_history(d_refs);
			}
			catch (Error e)
			{
				show_error(_("Could not read the history"), e.message);
			}
		}

		d_history = d_full;
		d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);
		show_path_bar();
		show_ticks();
	}

	private void lift_lines()
	{
		drop_lines();
		show_path_bar();
		show_ticks();
	}

	private void mark_matches()
	{
		d_matches = Search.find(rows(), d_match);

		var style = d_search_entry.get_style_context();

		if (!d_match.is_empty && d_matches.length == 0)
		{
			style.add_class("error");
		}
		else
		{
			style.remove_class("error");
		}

		show_match_count();
		d_paned.commit_list_view.queue_draw();
	}

	private string narrow_key()
	{
		if (!d_only_matches.active || d_match.is_empty || d_match.error != null)
		{
			return "";
		}

		return "%s\n%d%d%d".printf(d_search_entry.text.strip(), (int)d_search_switches.match_case, (int)d_search_switches.whole_word, (int)d_search_switches.regex);
	}

	public void open(Gitg.Repository repository, Gee.Set<string>? ticks, string[] paths, File? directory, string? text = null, bool ignore_case = false, bool regex = false)
	{
		Gee.List<Ref> refs;
		Gee.Set<string> resolved;

		stop_search();
		drop_lines();
		d_all = null;
		d_find_closed = false;
		d_names = null;
		d_text = null;
		d_regex = false;

		try
		{
			refs = Refs.read(repository);
			resolved = ticks != null ? ticks : Ticks.resolve(null, refs);
		}
		catch (Error e)
		{
			d_repository = null;
			d_history = null;
			d_refs = new Gee.ArrayList<Ref>();
			d_ticks = new Gee.HashSet<string>();
			d_paned.refs_list.set_refs(d_refs, d_ticks, null);
			show_ticks(true);
			show_error(_("Could not read the refs"), e.message);
			return;
		}

		d_repository = repository;
		d_paths = paths;
		d_filter_bar.set_paths(paths);
		this.directory = directory;
		d_diff.repository = repository;
		d_diff.options.pathspec = pathspec();
		Languages.warm(repository);
		d_refs = refs;
		d_ticks = resolved;

		try
		{
			d_history = read_history(d_refs);
		}
		catch (Error e)
		{
			d_history = null;
			show_error(_("Could not read the history"), e.message);
		}

		d_full = d_history;
		d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);

		if (text != null && d_history != null)
		{
			d_text = text;
			d_ignore_case = ignore_case;
			d_regex = regex;
			d_filter_bar.field.text = text;
			d_filter_bar.match_case = !ignore_case;
			d_filter_bar.regex = regex;
		}

		if (d_history != null && (d_text != null || follows()))
		{
			search(true);
		}

		show_path_bar();
		show_ticks(true);
	}

	private void offer_file_history()
	{
		foreach (var file in d_diff.get_files())
		{
			if (file.get_data<bool>("gittree-history-item"))
			{
				continue;
			}

			file.set_data<bool>("gittree-history-item", true);
			file.populate_menu.connect((menu, path) => {
				var item = new Gtk.MenuItem.with_label(_("Show history of this file"));

				if (menu.get_children() != null)
				{
					var separator = new Gtk.SeparatorMenuItem();

					separator.show();
					menu.add(separator);
				}

				item.activate.connect(() => show_file_history(path));
				item.show();
				menu.add(item);
			});
		}
	}

	private void offer_line_history()
	{
		foreach (var file in d_diff.get_files())
		{
			if (!file.get_data<bool>("gittree-line-items"))
			{
				file.set_data<bool>("gittree-line-items", true);
				file.page_shown.connect(() => offer_line_items(file));
			}

			offer_line_items(file);

			var delta = file.info.delta;

			if (d_line_history != null && (delta.get_new_file().get_path() == d_lines_path || delta.get_old_file().get_path() == d_lines_path))
			{
				file.expanded = true;
			}
		}
	}

	private void offer_line_items(Gitg.DiffViewFile file)
	{
		foreach (var view in file.get_text_views())
		{
			if (view.get_data<bool>("gittree-line-items"))
			{
				continue;
			}

			view.set_data<bool>("gittree-line-items", true);
			view.button_press_event.connect((event) => {
				int x;
				int y;
				Gtk.TextIter iter;

				if (event.button == Gdk.BUTTON_SECONDARY)
				{
					view.window_to_buffer_coords(Gtk.TextWindowType.TEXT, (int)event.x, (int)event.y, out x, out y);
					view.get_iter_at_location(out iter, x, y);
					view.set_data<int>("gittree-click", iter.get_offset());
				}

				return false;
			});
			view.populate_popup.connect((popup) => add_line_items(file, view, popup));
		}
	}

	private bool opens_files(Gtk.Widget? target)
	{
		var box = target as Gtk.EventBox;

		if (box != null && box.get_child() is Gtk.Label)
		{
			foreach (var sibling in ((Gtk.Container)box.get_parent()).get_children())
			{
				if (sibling is Gtk.Expander)
				{
					return ((Gtk.Expander)sibling).expanded;
				}
			}
		}

		for (var widget = target; widget != null && widget != d_diff; widget = widget.get_parent())
		{
			if (widget is Gtk.Expander)
			{
				return ((Gtk.Expander)widget).expanded;
			}
		}

		return false;
	}

	private string[]? pathspec()
	{
		if (d_paths.length == 0)
		{
			return null;
		}

		return Filter.relative_paths(d_repository, directory, d_paths);
	}

	private bool prepare_copy(double x, double y, out string caption, out string text)
	{
		var view = d_paned.commit_list_view;
		int bin_x;
		int bin_y;
		int cell_x;
		int cell_width;
		int hot_x;
		Gtk.TreePath? path;
		Gtk.TreeViewColumn? column;
		Gtk.TreeIter iter;

		caption = "";
		text = "";

		view.convert_widget_to_bin_window_coords((int)x, (int)y, out bin_x, out bin_y);

		if (!view.get_path_at_pos(bin_x, bin_y, out path, out column, out cell_x, null))
		{
			return false;
		}

		d_model.get_iter(out iter, path);

		var commit = d_model.commit_from_iter(iter);

		if (commit != null && column == d_paned.column_hash)
		{
			caption = _("Copy hash");
			text = commit.get_id().to_string();
			return true;
		}

		if (commit == null || column != d_paned.column_subject)
		{
			return false;
		}

		var lanes = (Gitg.CellRendererLanes)view.find_cell_at_pos(column, path, cell_x, out cell_width);
		var label = lanes.get_ref_at_pos(view, cell_x, cell_width, out hot_x);

		if (label == null)
		{
			return false;
		}

		caption = _("Copy name");
		text = label.parsed_name.shortname;
		return true;
	}

	private void queue_details()
	{
		var clock = d_paned.commit_list_view.get_frame_clock();

		if (clock == null)
		{
			show_details();
			return;
		}

		if (!d_details_queued)
		{
			d_details_queued = true;
			ulong handler = 0;

			handler = clock.after_paint.connect(() => {
				clock.disconnect(handler);

				Idle.add(() => {
					d_details_queued = false;
					show_details();
					return false;
				});
			});
		}

		clock.request_phase(Gdk.FrameClockPhase.AFTER_PAINT);
	}

	private History read_history(Gee.List<Ref> refs) throws Error
	{
		d_repository.clear_refs_cache();

		var topological = d_settings.get_boolean("topological-order");

		if (d_paths.length > 0 && !follows())
		{
			return new History.with_paths(d_repository, refs, d_paths, git_directory(), topological);
		}

		return new History(d_repository, refs, topological);
	}

	private void read_paths(string[] wanted, string? text, bool ignore_case, bool regex)
	{
		string[] paths = wanted;

		if (d_repository == null || d_full == null)
		{
			return;
		}

		stop_search();

		if (paths.length == 0)
		{
			lift_filter();

			if (text != null)
			{
				apply_filter(text, ignore_case, regex);
			}

			return;
		}

		if (Filter.is_one_file(d_repository, Filter.relative_paths(d_repository, directory, paths)))
		{
			var unlimited = d_paths.length == 0 || follows();

			d_paths = paths;
			d_diff.options.pathspec = pathspec();

			try
			{
				d_full = unlimited ? d_full : read_history(d_refs);
			}
			catch (Error e)
			{
				show_error(_("Could not read the history"), e.message);
				return;
			}

			d_text = text;
			d_ignore_case = ignore_case;
			d_regex = regex;
			d_find_closed = false;
			search(false);
			show_path_bar();
			return;
		}

		var cancellable = new Cancellable();

		d_search = cancellable;
		d_reading = paths;
		show_path_bar();

		History.read_paths.begin(d_repository, d_refs, paths, git_directory(), d_settings.get_boolean("topological-order"), cancellable, (obj, res) => {
			History history;

			try
			{
				history = History.read_paths.end(res);
			}
			catch (Error e)
			{
				if (!cancellable.is_cancelled())
				{
					d_search = null;
					d_reading = null;
					show_error(_("Could not read the history"), e.message);
					show_path_bar();
				}

				return;
			}

			if (cancellable.is_cancelled())
			{
				return;
			}

			d_search = null;
			d_reading = null;
			d_paths = paths;
			d_diff.options.pathspec = pathspec();
			d_full = history;
			d_history = history;
			d_text = null;
			d_regex = false;
			d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);

			if (text != null)
			{
				apply_filter(text, ignore_case, regex);
				return;
			}

			show_path_bar();
			show_ticks();
		});
	}

	public void refresh()
	{
		if (d_repository == null)
		{
			return;
		}

		var previous = new Gee.HashSet<string>();

		foreach (var reference in d_refs)
		{
			previous.add(reference.name);
		}

		Gee.List<Ref> refs;
		History history;

		try
		{
			refs = Refs.read(d_repository);
			history = read_history(refs);
		}
		catch (Error e)
		{
			show_error(_("Could not read the repository again"), e.message);
			return;
		}

		var ticks = new Gee.HashSet<string>();

		foreach (var reference in refs)
		{
			if (d_ticks.contains(reference.name) || (!previous.contains(reference.name) && reference.kind == RefKind.LOCAL))
			{
				ticks.add(reference.name);
			}
		}

		d_refs = refs;
		d_ticks = ticks;
		d_full = history;
		d_all = null;

		if (d_text != null || follows())
		{
			search(d_waiting);
		}
		else
		{
			d_history = history;
		}

		d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);

		if (d_lines != null)
		{
			search_lines();
		}

		show_ticks();
	}

	public Gitg.Commit[] rows()
	{
		var ret = new Gitg.Commit[0];

		for (uint i = 0; i < d_model.size; i++)
		{
			ret += d_model.get_row(i);
		}

		return ret;
	}

	private void search(bool waiting)
	{
		stop_search();

		var cancellable = new Cancellable();
		var tips = History.tips_of(d_refs);
		var start = git_directory();

		d_search = cancellable;
		d_waiting = waiting;

		var filter = new Filter(d_text, d_ignore_case, d_regex, d_paths, follows());

		TextSearch.run.begin(start, tips, filter, cancellable, (obj, res) => {
			Gee.Set<Ggit.OId> matches;
			Gee.Map<Ggit.OId, Gee.List<string>> names;

			try
			{
				matches = TextSearch.run.end(res, out names);
			}
			catch (Error e)
			{
				if (!cancellable.is_cancelled())
				{
					d_search = null;
					d_waiting = false;
					d_text = null;
					d_history = d_full;
					d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);
					show_error(_("Could not search the changes"), e.message);
					show_path_bar();
					show_ticks();
				}

				return;
			}

			if (cancellable.is_cancelled())
			{
				return;
			}

			d_search = null;
			d_waiting = false;
			d_names = filter.follow ? names : null;
			d_history = new History.filtered(d_full, matches, d_refs);
			d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);
			show_path_bar();
			show_ticks();
			fill_find_bar(true);
		});
	}

	private void search_lines()
	{
		var cancellable = new Cancellable();

		if (d_line_search != null)
		{
			d_line_search.cancel();
		}

		d_line_search = cancellable;
		show_path_bar();

		LineHistory.run.begin(top_directory(), d_lines_commit, d_lines_path, d_lines.start, d_lines.end, cancellable, (obj, res) => {
			Gee.Set<Ggit.OId> found;

			try
			{
				found = LineHistory.run.end(res);
			}
			catch (Error e)
			{
				if (!cancellable.is_cancelled())
				{
					show_error(_("Could not read the history of the lines"), e.message);
					lift_lines();
				}

				return;
			}

			if (cancellable.is_cancelled())
			{
				return;
			}

			d_line_search = null;
			d_line_history = new History.filtered(unlimited_history(), found, d_refs);
			show_path_bar();
			show_ticks();
		});
	}

	private void select(Ggit.OId id)
	{
		var path = d_model.path_from_commit(id);

		if (path == null)
		{
			return;
		}

		d_hold = -1;
		d_paned.commit_list_view.get_selection().select_path(path);
		d_paned.commit_list_view.scroll_to_cell(path, null, false, 0, 0);
	}

	private int selected_row()
	{
		var commit = selected;

		if (commit == null)
		{
			return -1;
		}

		var path = d_model.path_from_commit(commit.get_id());

		return path != null ? path.get_indices()[0] : -1;
	}

	public void set_ticks(Gee.Set<string> ticks)
	{
		d_ticks = new Gee.HashSet<string>();
		d_ticks.add_all(ticks);
		d_paned.refs_list.set_ticks(d_ticks);
		show_ticks();
	}

	private void show_base()
	{
		if (follows())
		{
			search(false);
			show_path_bar();
			return;
		}

		d_history = d_full;
		d_paned.refs_list.set_refs(d_refs, d_ticks, d_history);
		show_path_bar();
		show_ticks();
	}

	private void show_details()
	{
		var commit = selected;

		if (commit == null && d_kept != null)
		{
			return;
		}

		if (commit == null || d_history == null)
		{
			d_diff.commit = null;
			return;
		}

		if (!d_paned.details_visible || d_diff.commit == commit)
		{
			return;
		}

		if (d_names != null && d_names.has_key(commit.get_id()))
		{
			d_diff.options.pathspec = d_names[commit.get_id()].to_array();
		}

		d_diff.commit = commit;
		fill_find_bar(false);
	}

	private void show_file_history(string path)
	{
		var top = d_repository.get_workdir();
		var wanted = path;

		if (top != null && directory != null && !directory.equal(top))
		{
			var file = top.resolve_relative_path(path);
			var relative = directory.get_relative_path(file);

			wanted = relative != null ? relative : file.get_path();
		}

		d_filter_bar.field.text = "";
		d_filter_bar.set_paths({ wanted });
		filter_visible = true;
		apply("", !d_filter_bar.match_case, d_filter_bar.regex, { wanted });
	}

	private void show_line_history(LineHistory lines, string path, Ggit.OId commit)
	{
		var name = "<b>%s</b>".printf(Markup.escape_text(path));
		var from = "<b>%s</b>".printf(commit.to_string().substring(0, 7));

		drop_lines();
		d_lines = lines;
		d_lines_commit = commit;
		d_lines_path = path;
		d_line_label = lines.start == lines.end ? _("History of line %s of %s, from %s").printf("<b>%d</b>".printf(lines.start), name, from)
		                                        : _("History of lines %s to %s of %s, from %s").printf("<b>%d</b>".printf(lines.start), "<b>%d</b>".printf(lines.end), name, from);
		search_lines();
	}

	private void show_match_count()
	{
		d_match_count.label = Search.count_text(d_matches, selected_row(), d_match);
	}

	private void show_notice(string markup)
	{
		d_paned.notice.set_markup(markup);
		d_paned.stack_list.visible_child_name = "notice";
		show_details();
	}

	private void show_path_bar()
	{
		if (d_lines != null)
		{
			var reading = d_line_search != null;

			d_paned.path_spinner.visible = reading;
			d_paned.path_spinner.active = reading;
			d_paned.path_bar.show_close_button = true;
			d_paned.path_label.set_markup(reading ? Markup.escape_text(_("Reading the history of lines...")) : d_line_label);
			d_paned.path_bar.show();
			return;
		}

		var searching = d_search != null;

		d_paned.path_spinner.visible = searching;
		d_paned.path_spinner.active = searching;
		d_paned.path_bar.show_close_button = d_text != null || d_paths.length > 0;

		if (d_paths.length == 0 && d_text == null && d_reading == null)
		{
			d_paned.path_bar.hide();
			return;
		}

		var paths = bold_list(d_paths);
		var text = d_text != null ? "<b>%s</b>".printf(Markup.escape_text(d_text)) : "";
		string markup;

		if (d_reading != null)
		{
			markup = _("Reading the history of %s...").printf(bold_list(d_reading));
		}
		else if (searching && d_text == null)
		{
			markup = _("Reading the history of %s...").printf(paths);
		}
		else if (searching)
		{
			markup = _("Searching the changes for %s...").printf(text);
		}
		else if (d_text == null)
		{
			markup = _("Only commits that change %s").printf(paths);
		}
		else if (d_paths.length == 0)
		{
			markup = d_regex ? _("Only commits whose added or removed lines match %s").printf(text)
			                 : _("Only commits that add or remove %s").printf(text);
		}
		else
		{
			markup = d_regex ? _("Only commits that change %s and whose added or removed lines match %s").printf(paths, text)
			                 : _("Only commits that change %s and add or remove %s").printf(paths, text);
		}

		if (!searching && follows())
		{
			markup += _(", following renames");
		}

		if (!searching && d_text != null && d_ignore_case)
		{
			markup += _(", ignoring case");
		}

		d_paned.path_label.set_markup(markup);
		d_paned.path_bar.show();
	}

	private void show_ticks(bool from_top = false)
	{
		var kept = selected != null ? selected.get_id() : d_kept;
		var before = this.rows();
		var history = shown_history();
		var pending = d_hold >= 0;
		Gdk.Rectangle area;

		d_paned.commit_list_view.get_background_area(new Gtk.TreePath.first(), null, out area);

		var height = pending ? d_hold_height : area.height;
		var scroll = from_top ? 0 : (pending ? d_hold : d_paned.scrolled_window_commit_list.vadjustment.value);

		d_hold = -1;

		var rows = new Gitg.Commit[0];

		if (history != null && !d_waiting)
		{
			var tips = new Ggit.OId[0];

			foreach (var reference in d_refs)
			{
				if (d_ticks.contains(reference.name))
				{
					tips += reference.target;
				}
			}

			rows = history.tick(tips, History.mainline(d_repository, d_settings.get_boolean("mainline-head")));
		}

		d_paned.commit_list_view.model = null;
		d_model.set_rows(rows);
		d_paned.commit_list_view.model = d_model;
		mark_matches();

		var total = d_history != null ? d_history.size : 0;
		d_paned.summary.label = d_waiting ? "" : _("Showing %u of %d commits").printf(d_model.size, total);

		if (d_waiting)
		{
			show_notice(d_text != null ? _("Searching the changes for %s...").printf("<b>%s</b>".printf(Markup.escape_text(d_text)))
			                           : _("Reading the history of %s...").printf(bold_list(d_paths)));
			return;
		}

		if (d_ticks.size == 0)
		{
			show_notice(Markup.escape_text(_("Nothing is ticked. Tick a branch, a remote branch or a tag on the left.")));
			return;
		}

		if (d_model.size == 0 && d_line_history != null && d_narrowed == null)
		{
			show_notice(Markup.escape_text(_("No ticked ref reaches a commit that changed these lines.")));
			return;
		}

		if (d_model.size == 0 && d_narrowed != null)
		{
			d_kept = kept;
			show_notice(_("No commit in the ticked refs matches %s.").printf("<b>%s</b>".printf(Markup.escape_text(d_search_entry.text.strip()))));
			return;
		}

		if (d_model.size == 0 && d_text != null)
		{
			var text = "<b>%s</b>".printf(Markup.escape_text(d_text));
			var paths = Markup.escape_text(string.joinv(", ", d_paths));

			if (d_regex)
			{
				show_notice(d_paths.length == 0 ? _("No ticked ref reaches a commit whose added or removed lines match %s.").printf(text)
				                                : _("No ticked ref reaches a commit whose added or removed lines match %s in %s.").printf(text, paths));
				return;
			}

			show_notice(d_paths.length == 0 ? _("No ticked ref reaches a commit that adds or removes %s.").printf(text)
			                                : _("No ticked ref reaches a commit that adds or removes %s in %s.").printf(text, paths));
			return;
		}

		if (d_model.size == 0 && d_paths.length > 0)
		{
			show_notice(Markup.escape_text(_("No ticked ref reaches a commit that changes %s.").printf(string.joinv(", ", d_paths))));
			return;
		}

		d_paned.stack_list.visible_child_name = "list";

		var path = kept != null ? d_model.path_from_commit(kept) : null;

		d_kept = path == null && d_narrowed != null ? kept : null;

		if (d_model.size > 0 && d_kept == null)
		{
			d_paned.commit_list_view.get_selection().select_path(path != null ? path : new Gtk.TreePath.first());
		}

		keep_top(before, scroll, height);
		show_details();
	}

	private History? shown_history()
	{
		var key = narrow_key();
		var source = d_line_history != null ? d_line_history : d_history;

		if (key == "" || source == null)
		{
			d_narrow_key = key;
			d_narrowed = null;
			return source;
		}

		if (d_narrowed == null || key != d_narrow_key || d_narrow_source != source)
		{
			var found = History.id_set();

			for (var i = 0; i < source.size; i++)
			{
				var commit = source.at(i);

				if (Search.matches(commit, d_match))
				{
					found.add(commit.get_id());
				}
			}

			d_narrowed = new History.filtered(source, found, d_refs);
			d_narrow_key = key;
			d_narrow_source = source;
		}

		return d_narrowed;
	}

	public void step(int direction)
	{
		var from = selected_row();

		if (from < 0 && d_kept != null && d_history != null)
		{
			var place = d_history.index_of(d_kept);
			var above = 0;

			foreach (var row in rows())
			{
				if (d_history.index_of(row.get_id()) < place)
				{
					above++;
				}
			}

			from = direction > 0 ? above - 1 : above;
		}

		var target = Search.step(d_matches, from, direction);

		if (target >= 0)
		{
			select(d_model.get_row(target).get_id());
		}
	}

	private void stop_search()
	{
		if (d_search != null)
		{
			d_search.cancel();
			d_search = null;
		}

		d_reading = null;
		d_waiting = false;
	}

	private SList<Gitg.Ref> ticked_labels(Gitg.Commit commit)
	{
		var labels = new SList<Gitg.Ref>();

		foreach (var reference in d_refs)
		{
			if (reference.name == "HEAD" && d_ticks.contains("HEAD") && reference.target.equal(commit.get_id()))
			{
				try
				{
					labels.append(d_repository.lookup_reference("HEAD"));
				}
				catch {}
			}
		}

		foreach (var label in d_repository.refs_for_id(commit.get_id()))
		{
			if (d_ticks.contains(label.get_name()))
			{
				labels.append(label);
			}
		}

		return labels;
	}

	private File top_directory()
	{
		var top = d_repository.get_workdir();

		return top != null ? top : d_repository.get_location();
	}

	public void toggle_filter()
	{
		Gtk.TextView? view;
		int offset;
		var text = diff_selection(out view, out offset);

		if (text != null)
		{
			d_filter_bar.field.text = text;
			filter_visible = true;
			return;
		}

		filter_visible = !filter_visible;
	}

	public void toggle_search()
	{
		Gtk.TextView? view;
		int offset;
		var text = diff_selection(out view, out offset);

		if (text != null)
		{
			d_find_bar.take_selection(text, view, offset);
			return;
		}

		if (finds_in_diff())
		{
			d_find_bar.search_mode_enabled = !d_find_bar.search_mode_enabled;
			return;
		}

		search_visible = !search_visible;
	}

	private History? unlimited_history()
	{
		if (d_paths.length == 0 || follows())
		{
			return d_full;
		}

		if (d_all == null)
		{
			try
			{
				d_all = new History(d_repository, d_refs, d_settings.get_boolean("topological-order"));
			}
			catch (Error e)
			{
				show_error(_("Could not read the history"), e.message);
				return d_full;
			}
		}

		return d_all;
	}
}

}
