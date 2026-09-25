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

public class HistoryActivity : Object, GitgExt.UIElement, GitgExt.Activity, GitgExt.Searchable
{
	private Gtk.Box d_box;
	private Gitg.DiffView d_diff;
	private Gtk.Label d_match_count;
	private int[] d_matches;
	private HistoryPaned d_paned;
	private History? d_history;
	private SList<Gitg.Ref> d_labels;
	private HistoryModel d_model;
	private string d_needle;
	private string[] d_paths;
	private Gee.List<Ref> d_refs;
	private Gitg.Repository? d_repository;
	private Settings d_settings;
	private Gtk.SearchBar d_search_bar;
	private Gtk.SearchEntry d_search_entry;
	private Gee.Set<string> d_ticks;

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

	public string id
	{
		owned get { return "/io/github/li9i/gitree/Activities/History"; }
	}

	public string list_page
	{
		owned get { return d_paned.stack_list.visible_child_name; }
	}

	public string notice_text
	{
		owned get { return d_paned.notice.label; }
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
		d_model = new HistoryModel();
		d_paths = new string[0];
		d_refs = new Gee.ArrayList<Ref>();
		d_ticks = new Gee.HashSet<string>();
		d_settings = new Settings(Config.APPLICATION_ID + ".preferences.history");

		d_matches = new int[0];
		d_needle = "";

		d_paned = new HistoryPaned();
		d_paned.commit_list_view.model = d_model;
		d_paned.column_subject.set_cell_data_func(d_paned.renderer_subject, lanes_data_func);
		d_paned.column_author.set_cell_data_func(d_paned.renderer_author, author_data_func);

		d_search_entry = new Gtk.SearchEntry();
		d_search_entry.width_chars = 40;
		d_search_entry.placeholder_text = _("Subject, message, author or hash");

		var previous = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.BUTTON);
		previous.tooltip_text = _("Previous match (Shift+Enter)");
		previous.clicked.connect(() => step(-1));

		var next = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.BUTTON);
		next.tooltip_text = _("Next match (Enter)");
		next.clicked.connect(() => step(1));

		d_match_count = new Gtk.Label(null);
		d_match_count.width_chars = 12;
		d_match_count.xalign = 0;

		var search_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		search_box.add(d_search_entry);
		search_box.add(previous);
		search_box.add(next);
		search_box.add(d_match_count);

		d_search_bar = new Gtk.SearchBar();
		d_search_bar.add(search_box);
		d_search_bar.connect_entry(d_search_entry);
		d_search_bar.notify["search-mode-enabled"].connect(() => {
			if (!d_search_bar.search_mode_enabled)
			{
				d_search_entry.text = "";
				d_paned.commit_list_view.grab_focus();
			}

			notify_property("search-visible");
		});

		d_search_entry.search_changed.connect(() => {
			find_matches();
		});
		d_search_entry.activate.connect(() => step(1));
		d_search_entry.next_match.connect(() => step(1));
		d_search_entry.previous_match.connect(() => step(-1));
		d_search_entry.key_press_event.connect((event) => {
			var enter = event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter;

			if (enter && (event.state & Gdk.ModifierType.SHIFT_MASK) != 0)
			{
				step(-1);
				return true;
			}

			return false;
		});

		d_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		d_box.add(d_search_bar);
		d_box.add(d_paned);
		d_box.show_all();

		d_diff = new Gitg.DiffView();
		d_diff.vexpand = true;
		d_diff.show();
		d_paned.box_details.add(d_diff);

		var diff_settings = new Settings(Config.APPLICATION_ID + ".preferences.diff");

		diff_settings.bind("ignore-whitespace", d_diff, "ignore-whitespace", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("changes-inline", d_diff, "changes-inline", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("context-lines", d_diff, "context-lines", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("tab-width", d_diff, "tab-width", SettingsBindFlags.GET | SettingsBindFlags.SET);
		diff_settings.bind("wrap", d_diff, "wrap-lines", SettingsBindFlags.GET | SettingsBindFlags.SET);

		var interface_settings = new Settings(Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("use-gravatar", d_diff, "use-gravatar", SettingsBindFlags.GET | SettingsBindFlags.SET);
		interface_settings.bind("enable-diff-highlighting", d_diff, "highlight", SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_diff.parent_activated.connect((id) => {
			select(id);
		});

		d_paned.commit_list_view.get_selection().changed.connect(() => {
			show_details();
			show_match_count();
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

	private void author_data_func(Gtk.CellLayout layout, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter)
	{
		var commit = d_model.commit_from_iter(iter);

		if (commit != null && d_needle != "")
		{
			((Gtk.CellRendererText)cell).markup = Search.marked(commit.get_author().get_name(), d_needle);
		}
	}

	private void find_matches()
	{
		d_needle = d_search_entry.text.strip();
		d_matches = Search.find(rows(), d_needle);

		var style = d_search_entry.get_style_context();

		if (d_needle != "" && d_matches.length == 0)
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
			if (reference.name == name && d_history != null)
			{
				var start = d_history.start_of(reference.target);

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

		if (d_needle != "")
		{
			lanes.markup = Search.marked(commit.get_subject(), d_needle);
		}
	}

	public void open(Gitg.Repository repository, Gee.Set<string>? ticks, string[] paths, File? directory)
	{
		Gee.List<Ref> refs;
		Gee.Set<string> resolved;

		try
		{
			refs = Refs.read(repository);
			resolved = Ticks.resolve(null, refs, ticks != null ? ticks : Ticks.load(Ticks.file_for(repository), refs));
		}
		catch (Error e)
		{
			d_repository = null;
			d_history = null;
			d_refs = new Gee.ArrayList<Ref>();
			d_ticks = new Gee.HashSet<string>();
			d_paned.refs_list.set_refs(d_refs, d_ticks);
			show_ticks();
			show_error(_("Could not read the refs"), e.message);
			return;
		}

		d_repository = repository;
		d_paths = paths;
		this.directory = directory;
		d_diff.repository = repository;
		d_diff.options.pathspec = pathspec();
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

		d_paned.refs_list.set_refs(d_refs, d_ticks);
		show_path_bar();
		show_ticks();
	}

	private string[]? pathspec()
	{
		if (d_paths.length == 0)
		{
			return null;
		}

		var top = d_repository.get_workdir();
		var start = directory != null ? directory : top;
		var ret = new string[0];

		foreach (var path in d_paths)
		{
			var file = start.resolve_relative_path(path);
			var relative = top != null ? top.get_relative_path(file) : null;

			ret += relative != null ? relative : (file.equal(top) ? "." : path);
		}

		return ret;
	}

	private History read_history(Gee.List<Ref> refs) throws Error
	{
		d_repository.clear_refs_cache();

		var topological = d_settings.get_boolean("topological-order");

		if (d_paths.length > 0)
		{
			return new History.with_paths(d_repository, refs, d_paths, directory, topological);
		}

		return new History(d_repository, refs, topological);
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

		var adjustment = d_paned.scrolled_window_commit_list.vadjustment;
		var scroll = adjustment.value;

		d_refs = refs;
		d_ticks = ticks;
		d_history = history;
		d_paned.refs_list.set_refs(d_refs, d_ticks);
		show_ticks();

		adjustment.value = scroll;
		Idle.add(() => {
			adjustment.value = scroll;
			return false;
		});
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

	public void save_ticks()
	{
		if (d_repository != null)
		{
			Ticks.save(Ticks.file_for(d_repository), d_refs, d_ticks);
		}
	}

	private void select(Ggit.OId id)
	{
		var path = d_model.path_from_commit(id);

		if (path == null)
		{
			return;
		}

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

	private void show_details()
	{
		var commit = selected;

		if (commit == null || d_history == null)
		{
			d_diff.commit = null;
			return;
		}

		var labels = new Gitg.Ref[0];

		foreach (var label in ticked_labels(commit))
		{
			labels += label;
		}

		d_diff.shown_parents = d_history.parents_of(commit);
		d_diff.shown_labels = labels;
		d_diff.commit = commit;
	}

	private void show_match_count()
	{
		d_match_count.label = Search.count_text(d_matches, selected_row(), d_needle);
	}

	private void show_path_bar()
	{
		if (d_paths.length == 0)
		{
			d_paned.path_bar.hide();
			return;
		}

		var names = new string[0];

		foreach (var path in d_paths)
		{
			names += "<b>%s</b>".printf(Markup.escape_text(path));
		}

		d_paned.path_label.set_markup(_("Only commits that change %s").printf(string.joinv(", ", names)));
		d_paned.path_bar.show();
	}

	private void show_ticks()
	{
		var kept = selected != null ? selected.get_id() : null;
		var rows = new Gitg.Commit[0];

		if (d_history != null)
		{
			var tips = new Ggit.OId[0];

			foreach (var reference in d_refs)
			{
				if (d_ticks.contains(reference.name))
				{
					tips += reference.target;
				}
			}

			rows = d_history.tick(tips, History.mainline(d_repository, d_settings.get_boolean("mainline-head")));
		}

		d_paned.commit_list_view.model = null;
		d_model.set_rows(rows);
		d_paned.commit_list_view.model = d_model;
		find_matches();

		var total = d_history != null ? d_history.size : 0;
		d_paned.summary.label = _("Showing %u of %d commits").printf(d_model.size, total);

		if (d_ticks.size == 0)
		{
			d_paned.notice.label = _("Nothing is ticked. Tick a branch, a remote branch or a tag on the left.");
			d_paned.stack_list.visible_child_name = "notice";
			show_details();
			return;
		}

		if (d_model.size == 0 && d_paths.length > 0)
		{
			d_paned.notice.label = _("No ticked ref reaches a commit that changes %s.").printf(string.joinv(", ", d_paths));
			d_paned.stack_list.visible_child_name = "notice";
			show_details();
			return;
		}

		d_paned.stack_list.visible_child_name = "list";

		if (kept != null && d_model.path_from_commit(kept) != null)
		{
			select(kept);
		}
		else if (d_model.size > 0)
		{
			d_paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.first());
		}

		show_details();
	}

	public void step(int direction)
	{
		var target = Search.step(d_matches, selected_row(), direction);

		if (target >= 0)
		{
			select(d_model.get_row(target).get_id());
		}
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
}

}
