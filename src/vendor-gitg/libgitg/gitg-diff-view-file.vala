/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file.ui")]
public class Gitg.DiffViewFile : Gtk.Grid
{
	[GtkChild( name = "expander" )]
	private unowned Gtk.Expander d_expander;

	[GtkChild( name = "label_file_header" )]
	private unowned Gtk.Label d_label_file_header;

	[GtkChild( name = "diff_stat_file" )]
	private unowned DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_content" )]
	private unowned Gtk.Revealer d_revealer_content;

	[GtkChild( name = "stack_switcher" )]
	private unowned Gtk.StackSwitcher? d_stack_switcher;

	[GtkChild( name = "stack_file_renderer" )]
	private unowned Gtk.Stack? d_stack_file_renderer;

	private bool d_expanded;
	private bool d_handle_selection;
	private bool d_text;
	private Gee.ArrayList<Ggit.DiffHunk> d_hunks;
	private Gee.ArrayList<Gee.ArrayList<Ggit.DiffLine>> d_hunk_lines;
	private Gtk.ScrolledWindow? d_text_page;
	private Gtk.Box? d_split_page;

	internal Gee.ArrayList<DiffViewFileRenderer> renderer_list {get; private set;}

	public int maxlines { get; set; }

	internal signal void renderer_added(DiffViewFileRenderer renderer);

	public signal void page_shown();
	public signal void populate_menu(Gtk.Menu menu, string path);

	public bool new_is_workdir { get; construct set; }

	public bool expanded
	{
		get
		{
			return d_expanded;
		}

		set
		{
			if (d_expanded != value)
			{
				d_expanded = value;
				d_revealer_content.reveal_child = d_expanded;
				build_visible_page();
				bool visible = false;
				if (d_expanded)
				{
					visible = d_stack_file_renderer.get_children().length() > 1;
				}
				d_stack_switcher.set_visible(visible);


				var ctx = get_style_context();

				if (d_expanded)
				{
					ctx.add_class("expanded");
				}
				else
				{
					ctx.remove_class("expanded");
				}
			}
		}
	}

	public DiffViewFileInfo? info {get; construct set;}
	private Gee.HashMap<Gtk.Widget, bool> d_diff_stat_visible_map = new Gee.HashMap<Gtk.Widget, bool>();

	public DiffViewFile(DiffViewFileInfo? info)
	{
		Object(info: info);
		bind_property("vexpand", d_stack_file_renderer, "vexpand", BindingFlags.SYNC_CREATE);
		d_stack_file_renderer.notify["visible-child"].connect(page_changed);
		renderer_list = new Gee.ArrayList<DiffViewFileRenderer>();
		d_hunks = new Gee.ArrayList<Ggit.DiffHunk>();
		d_hunk_lines = new Gee.ArrayList<Gee.ArrayList<Ggit.DiffLine>>();
	}

	private void page_changed()
	{
		var visible_child = d_stack_file_renderer.get_visible_child();
		var visible = d_diff_stat_visible_map.get(visible_child);
		d_diff_stat_file.set_visible(visible);
		build_visible_page();
		page_shown();
	}

	private void add_page(Gtk.Widget widget, string name, string title, bool show_stats)
	{
		d_diff_stat_visible_map.set(widget, show_stats);
		d_stack_file_renderer.add_titled(widget, name, title);
	}

	internal void add_renderer(DiffViewFileRenderer renderer, Gtk.Widget widget, string name, string title, bool show_stats)
	{
		renderer_list.add(renderer);
		add_page(widget, name, title, show_stats);
	}

	public void add_text_renderer(bool handle_selection)
	{
		d_handle_selection = handle_selection;
		d_text = true;
	}

	private void add_text_pages()
	{
		d_text_page = new Gtk.ScrolledWindow (null, null);
		d_text_page.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
		d_text_page.show();

		// Translators: Unif stands for unified diff format
		add_page(d_text_page, "text", _("Unif"), true);

		d_split_page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		d_split_page.show();
		// Translators: Split stands for the noun
		add_page(d_split_page, "splittext", _("Split"), true);
	}

	private void build_visible_page()
	{
		if (!d_expanded)
		{
			return;
		}

		if (d_text && d_text_page == null)
		{
			add_text_pages();
		}

		var visible_child = d_stack_file_renderer.get_visible_child();

		if (visible_child == d_text_page && d_text_page.get_child() == null)
		{
			var renderer = new DiffViewFileRendererText(info, d_handle_selection, DiffViewFileRendererText.Style.ONE);
			renderer.show();
			d_text_page.add(renderer);
			fill(renderer);
		}
		else if (visible_child == d_split_page && d_split_page.get_children().length() == 0)
		{
			var renderer_split = new DiffViewFileRendererTextSplit(info, d_handle_selection);
			renderer_split.show();
			d_split_page.pack_start(renderer_split, true, true, 0);
			fill(renderer_split);
		}
	}

	private void fill(DiffViewFileRenderer renderer)
	{
		renderer_list.add(renderer);
		renderer_added(renderer);

		for (var i = 0; i < d_hunks.size; i++)
		{
			renderer.add_hunk(d_hunks[i], d_hunk_lines[i]);
		}
	}

	public void add_binary_renderer()
	{
		var renderer = new DiffViewFileRendererBinary();
		renderer.show();
		add_renderer(renderer, renderer, "binary", _("Binary"), false);
	}

	public void add_image_renderer()
	{
		var renderer = new DiffViewFileRendererImage(info.repository, info.delta);
		renderer.show();
		add_renderer(renderer, renderer, "image", _("Image"), false);
	}

	protected override void constructed()
	{
		base.constructed();

		var delta = info.delta;
		var oldfile = delta.get_old_file();
		var newfile = delta.get_new_file();

		var oldpath = (oldfile != null ? oldfile.get_path() : null);
		var newpath = (newfile != null ? newfile.get_path() : null);

		if (delta.get_similarity() > 0)
		{
			d_label_file_header.label = @"$(newfile.get_path()) ← $(oldfile.get_path())";
		}
		else if (newpath != null)
		{
			d_label_file_header.label = newpath;
		}
		else
		{
			d_label_file_header.label = oldpath;
		}

		d_expander.bind_property("expanded", this, "expanded", BindingFlags.BIDIRECTIONAL);

		var repository = info.repository;
		if (repository != null)
		{
			d_expander.popup_menu.connect(expander_popup_menu);
			d_expander.button_press_event.connect(expander_button_press_event);
		}
	}

	private void show_popup(Gdk.EventButton? event)
	{
		var menu = new Gtk.Menu();

		var delta  = info.delta;
		var oldpath = delta.get_old_file().get_path();
		var newpath = delta.get_new_file().get_path();

		var open_file = new Gtk.MenuItem.with_mnemonic(_("_Open file"));
		open_file.show();

		File? location = null;

		var repository = info.repository;
		if (!repository.is_bare && newpath != null && newpath != "")
		{
			location = repository.get_workdir().get_child(newpath);
		}
		else if (!repository.is_bare && oldpath != null && oldpath != "")
		{
			location = repository.get_workdir().get_child(oldpath);
		}

		if (location == null)
		{
			populate_menu(menu, newpath != null && newpath != "" ? newpath : oldpath);
			popup_if_filled(menu, event);
			return;
		}

		open_file.activate.connect(() => {
			try
			{
				Gtk.show_uri_on_window((Gtk.Window)d_expander.get_toplevel(), location.get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open file: $(e.message)\n");
			}
		});

		menu.add(open_file);

		var open_folder = new Gtk.MenuItem.with_mnemonic(_("Open containing _folder"));
		open_folder.show();

		open_folder.activate.connect(() => {
			try
			{
				Gtk.show_uri_on_window((Gtk.Window)d_expander.get_toplevel(), location.get_parent().get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open folder: $(e.message)\n");
			}
		});

		menu.add(open_folder);

		var separator = new Gtk.SeparatorMenuItem();
		separator.show();
		menu.add(separator);

		var copy_file_path = new Gtk.MenuItem.with_mnemonic(_("_Copy file path"));
		copy_file_path.show();

		copy_file_path.activate.connect(() => {
			var clip = d_expander.get_clipboard(Gdk.SELECTION_CLIPBOARD);
			clip.set_text(location.get_path(), -1);
		});

		menu.add(copy_file_path);

		populate_menu(menu, newpath != null && newpath != "" ? newpath : oldpath);
		popup_if_filled(menu, event);
	}

	private void popup_if_filled(Gtk.Menu menu, Gdk.EventButton? event)
	{
		if (menu.get_children() == null)
		{
			return;
		}

		menu.attach_to_widget(d_expander, null);
		menu.popup_at_pointer(event);
	}

	private bool expander_button_press_event(Gtk.Widget widget, Gdk.EventButton? event)
	{
		if (event.triggers_context_menu())
		{
			show_popup(event);
			return true;
		}

		return false;
	}

	private bool expander_popup_menu(Gtk.Widget widget)
	{
		show_popup(null);
		return true;
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		d_hunks.add(hunk);
		d_hunk_lines.add(lines);

		if (d_text)
		{
			foreach (var line in lines)
			{
				if (line.get_origin() == Ggit.DiffLineType.ADDITION)
				{
					d_diff_stat_file.added++;
				}
				else if (line.get_origin() == Ggit.DiffLineType.DELETION)
				{
					d_diff_stat_file.removed++;
				}
			}
		}

		foreach (DiffViewFileRenderer renderer in renderer_list)
		{
			renderer.add_hunk(hunk, lines);
		}
	}

	public Gee.List<Ggit.DiffLine> get_lines()
	{
		var lines = new Gee.ArrayList<Ggit.DiffLine>();
		var visible_child = d_stack_file_renderer.get_visible_child();

		if (d_text && (visible_child == null || visible_child == d_text_page || visible_child == d_split_page))
		{
			foreach (var hunk_lines in d_hunk_lines)
			{
				lines.add_all(hunk_lines);
			}
		}

		return lines;
	}

	public int get_line_offset(Gtk.TextView view, int line)
	{
		var renderer = view as DiffViewFileRendererText;

		return renderer != null ? renderer.get_line_offset(line) : -1;
	}

	public Gtk.TextView[] get_text_views()
	{
		var visible_child = d_stack_file_renderer.get_visible_child();

		if (visible_child == null)
		{
			return {};
		}

		if (visible_child == d_text_page && d_text_page.get_child() != null)
		{
			return { (Gtk.TextView) d_text_page.get_child() };
		}

		if (visible_child == d_split_page && d_split_page.get_children() != null)
		{
			return ((DiffViewFileRendererTextSplit) d_split_page.get_children().data).get_text_views();
		}

		return {};
	}

	public bool split
	{
		get
		{
			return d_split_page != null && d_stack_file_renderer.get_visible_child() == d_split_page;
		}
	}
}

// ex:ts=4 noet
