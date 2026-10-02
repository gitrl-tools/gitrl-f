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

public class DiffFindBar : Gtk.SearchBar
{
	private const string CURRENT = "diff-find-current";

	private const string MATCH = "diff-find-match";

	private Gtk.Adjustment? d_adjustment;
	private Gtk.Label d_count;
	private Gitg.DiffView d_diff;
	private Ggit.Diff? d_diff_rows;
	private Ggit.Diff? d_diff_searched;
	private Gtk.SearchEntry d_field;
	private DiffFind d_find;
	private Gee.HashMap<Gitg.DiffViewFile, int> d_indexes;
	private bool d_quiet;
	private Gtk.Widget? d_return_focus;
	private bool d_scroll_pending;
	private bool d_scrolling;
	private bool d_searched_case;
	private bool d_searched_regex;
	private string d_searched_text;
	private int[] d_sizes;
	private bool[] d_split;
	private bool d_step_pending;
	private SearchSwitches d_switches;
	private Gee.HashSet<Gitg.DiffViewFile> d_watched;

	public string count
	{
		owned get { return d_count.label; }
	}

	public int current_file
	{
		get { return search_mode_enabled && d_find.current >= 0 ? d_find.get_match(d_find.current).file : -1; }
	}

	public Gtk.SearchEntry field
	{
		get { return d_field; }
	}

	public bool match_case
	{
		get { return d_switches.match_case; }
		set { d_switches.match_case = value; }
	}

	public bool regex
	{
		get { return d_switches.regex; }
		set { d_switches.regex = value; }
	}

	public signal void moved();

	public DiffFindBar(Gitg.DiffView diff)
	{
		d_diff = diff;
		d_find = new DiffFind("", true);
		d_searched_text = "";
		d_indexes = new Gee.HashMap<Gitg.DiffViewFile, int>();
		d_sizes = new int[0];
		d_split = new bool[0];
		d_watched = new Gee.HashSet<Gitg.DiffViewFile>();

		d_field = new Gtk.SearchEntry();
		d_field.width_chars = 30;
		d_field.placeholder_text = _("Find in the changed lines of this commit");
		d_field.tooltip_text = _("Searches the added, removed and unchanged lines of every file in the commit shown below, folded files too. Enter searches");

		d_count = new Gtk.Label(null);
		d_count.width_chars = 12;
		d_count.xalign = 0;
		d_count.margin_start = 12;

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(d_field);
		SearchKeys.attach(d_field, box, go);
		d_switches = new SearchSwitches(box);
		d_switches.changed.connect(show_count);
		box.add(d_count);

		var viewport = new Gtk.Viewport(null, null);
		viewport.shadow_type = Gtk.ShadowType.NONE;
		viewport.add(box);

		var holder = new Gtk.ScrolledWindow(null, null);
		holder.hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
		holder.vscrollbar_policy = Gtk.PolicyType.NEVER;
		holder.propagate_natural_width = true;
		holder.add(viewport);
		holder.show_all();

		add(holder);
		no_show_all = true;
		show_close_button = true;
		BarEdge.drop(this, Gtk.PositionType.TOP);

		d_field.changed.connect(show_count);

		notify["search-mode-enabled"].connect(search_mode_changed);
		d_diff.files_changed.connect(() => {
			d_diff_rows = d_diff.diff;

			if (search_mode_enabled)
			{
				search();
			}
		});
	}

	private void apply()
	{
		d_searched_text = d_field.text;
		d_searched_case = d_switches.match_case;
		d_searched_regex = d_switches.regex;
		search();
	}

	private void adjustment_changed()
	{
		scroll_to_current();
	}

	private void adjustment_moved()
	{
		if (!d_scrolling)
		{
			d_scroll_pending = false;
		}
	}

	private static void ensure_tags(Gtk.TextBuffer buffer)
	{
		if (buffer.tag_table.lookup(MATCH) != null)
		{
			return;
		}

		buffer.create_tag(MATCH, "background", "#fce94f", "foreground", "#1a1a1a");
		buffer.create_tag(CURRENT, "background", "#f57900", "foreground", "#1a1a1a");
		buffer.tag_table.tag_added.connect(tag_added);
	}

	public void fill(string text, bool match_case, bool regex = false)
	{
		var window = get_toplevel() as Gtk.Window;
		var focus = window != null ? window.get_focus() : null;

		d_quiet = true;
		search_mode_enabled = true;
		d_quiet = false;

		if (window != null)
		{
			window.set_focus(focus);
		}
		d_field.text = text;
		d_switches.match_case = match_case;
		d_switches.regex = regex;
		apply();
	}

	private void go(int direction)
	{
		if (pending())
		{
			if (typed_error() == null)
			{
				apply();
			}

			return;
		}

		step(direction);
	}

	private void mark_file(int index, Gitg.DiffViewFile file)
	{
		var views = file.get_text_views();

		for (var side = 0; side < views.length; side++)
		{
			var buffer = views[side].buffer;
			Gtk.TextIter start;
			Gtk.TextIter end;

			ensure_tags(buffer);
			raise_tags(buffer.tag_table);

			var match_tag = buffer.tag_table.lookup(MATCH);
			var current_tag = buffer.tag_table.lookup(CURRENT);

			buffer.get_bounds(out start, out end);
			buffer.remove_tag(match_tag, start, end);
			buffer.remove_tag(current_tag, start, end);

			for (var i = 0; i < d_find.length; i++)
			{
				var match = d_find.get_match(i);

				if (match.file != index || match.side != side)
				{
					continue;
				}

				var offset = file.get_line_offset(views[side], match.line);

				if (offset < 0)
				{
					continue;
				}

				buffer.get_iter_at_offset(out start, offset + match.start);
				buffer.get_iter_at_offset(out end, offset + match.start + match.length);
				buffer.apply_tag(i == d_find.current ? current_tag : match_tag, start, end);
			}
		}
	}

	private void page_shown(Gitg.DiffViewFile file)
	{
		if (!search_mode_enabled)
		{
			return;
		}

		if (!d_indexes.has_key(file))
		{
			return;
		}

		var index = d_indexes[file];

		if (file.split != d_split[index] || file.get_lines().size != d_sizes[index])
		{
			search();
			return;
		}

		mark_file(index, file);
	}

	private bool pending()
	{
		var text = d_field.text;

		return text != d_searched_text || (text != "" && (d_switches.match_case != d_searched_case || d_switches.regex != d_searched_regex));
	}

	private static void raise_tags(Gtk.TextTagTable table)
	{
		var match_tag = table.lookup(MATCH);
		var current_tag = table.lookup(CURRENT);

		if (match_tag == null || current_tag == null)
		{
			return;
		}

		match_tag.set_priority(table.get_size() - 1);
		current_tag.set_priority(table.get_size() - 1);
	}

	private void scroll_to_current()
	{
		if (!d_scroll_pending || d_find.current < 0)
		{
			return;
		}

		var match = d_find.get_match(d_find.current);
		var files = d_diff.get_files();

		if (match.file >= files.size)
		{
			return;
		}

		var file = files[match.file];
		var views = file.get_text_views();

		if (match.side >= views.length)
		{
			return;
		}

		var view = views[match.side];
		var offset = file.get_line_offset(view, match.line);
		Gtk.ScrolledWindow? outer = null;

		for (var widget = view.get_parent(); widget != null; widget = widget.get_parent())
		{
			var scrolled = widget as Gtk.ScrolledWindow;

			if (scrolled != null && scrolled.vscrollbar_policy != Gtk.PolicyType.NEVER)
			{
				outer = scrolled;
				break;
			}
		}

		if (offset < 0 || outer == null)
		{
			return;
		}

		Gtk.TextIter iter;
		Gdk.Rectangle location;
		int x;
		int y;
		int content_x;
		int content_y;

		view.buffer.get_iter_at_offset(out iter, offset + match.start);
		view.scroll_to_iter(iter, 0, false, 0, 0);
		view.get_iter_location(iter, out location);
		view.buffer_to_window_coords(Gtk.TextWindowType.WIDGET, location.x, location.y, out x, out y);

		var content = ((Gtk.Bin)outer.get_child()).get_child();

		if (!view.translate_coordinates(content, x, y, out content_x, out content_y))
		{
			return;
		}

		var adjustment = outer.vadjustment;

		if (d_adjustment != adjustment)
		{
			d_adjustment = adjustment;
			adjustment.changed.connect(adjustment_changed);
			adjustment.value_changed.connect(adjustment_moved);
		}

		if (content_y < adjustment.value || content_y + location.height > adjustment.value + adjustment.page_size)
		{
			var top = content_y - adjustment.page_size / 3;

			d_scrolling = true;
			adjustment.value = top.clamp(adjustment.lower, adjustment.upper - adjustment.page_size);
			d_scrolling = false;
		}
	}

	private void scroll_when_drawn()
	{
		var clock = d_diff.get_frame_clock();

		d_scroll_pending = true;

		if (clock == null)
		{
			scroll_to_current();
			return;
		}

		ulong handler = 0;

		handler = clock.after_paint.connect(() => {
			clock.disconnect(handler);
			scroll_to_current();
		});

		clock.request_phase(Gdk.FrameClockPhase.AFTER_PAINT);
	}

	private void search()
	{
		var files = d_diff.get_files();
		var before = d_find;
		var same_diff = d_diff_searched != null && d_diff_searched == d_diff_rows;
		var text = search_mode_enabled ? d_searched_text : "";

		d_scroll_pending = false;

		if (!same_diff)
		{
			d_watched.clear();
		}

		d_find = new DiffFind(text, d_searched_case, d_searched_regex);
		d_indexes = new Gee.HashMap<Gitg.DiffViewFile, int>();
		d_sizes = new int[files.size];
		d_split = new bool[files.size];

		for (var i = 0; i < files.size; i++)
		{
			var file = files[i];
			var lines = file.get_lines();
			var origins = new Ggit.DiffLineType[lines.size];
			var texts = new string[lines.size];

			watch(file);
			d_indexes[file] = i;

			for (var line = 0; line < lines.size; line++)
			{
				origins[line] = lines[line].get_origin();
				texts[line] = lines[line].get_text();
			}

			d_sizes[i] = lines.size;
			d_split[i] = file.split;
			d_find.add_file(i, origins, texts, file.split);
		}

		if (same_diff && before.current >= 0 && before.current < d_find.length)
		{
			var was = before.get_match(before.current);
			var now = d_find.get_match(before.current);

			if (was.file == now.file && was.side == now.side && was.line == now.line && was.start == now.start)
			{
				d_find.current = before.current;
			}
		}

		d_diff_searched = d_diff_rows;

		for (var i = 0; i < files.size; i++)
		{
			mark_file(i, files[i]);
		}

		show_count();
		step_if_pending();
	}

	private void search_mode_changed()
	{
		visible = search_mode_enabled;

		if (search_mode_enabled)
		{
			var window = get_toplevel() as Gtk.Window;
			var focus = window != null ? window.get_focus() : null;

			if (!d_quiet)
			{
				d_return_focus = focus;
				d_field.grab_focus();
				d_field.select_region(0, -1);
			}

			search();
			return;
		}

		search();

		var window = get_toplevel() as Gtk.Window;

		if (!d_diff.get_mapped() || (window != null && window.get_focus() != null))
		{
			return;
		}

		if (d_return_focus != null && d_return_focus.get_mapped())
		{
			d_return_focus.grab_focus();
		}
		else
		{
			d_diff.child_focus(Gtk.DirectionType.TAB_FORWARD);

			var label = window != null ? window.get_focus() as Gtk.Label : null;

			if (label != null)
			{
				label.select_region(0, 0);
			}
		}

		d_return_focus = null;
	}

	private void show_count()
	{
		var style = d_field.get_style_context();

		var error = typed_error();
		var waiting = error == null && pending();

		if (error != null)
		{
			d_count.label = _("Bad regex");
		}
		else if (waiting)
		{
			d_count.label = _("Enter to search");
		}
		else
		{
			d_count.label = d_find.count_text();
		}

		d_count.tooltip_text = error;

		if (error != null || (!waiting && d_field.text != "" && d_find.length == 0))
		{
			style.add_class("error");
		}
		else
		{
			style.remove_class("error");
		}

		moved();
	}

	public void step(int direction)
	{
		var before = d_find.current;

		d_find.step(direction);
		show_count();

		if (d_find.current < 0)
		{
			return;
		}

		var files = d_diff.get_files();
		var match = d_find.get_match(d_find.current);

		if (before >= 0)
		{
			var old = d_find.get_match(before);

			mark_file(old.file, files[old.file]);
		}

		files[match.file].expanded = true;
		mark_file(match.file, files[match.file]);
		scroll_when_drawn();
	}

	private void step_if_pending()
	{
		if (!d_step_pending || !search_mode_enabled || d_diff_rows != d_diff.diff || d_find.length == 0)
		{
			return;
		}

		var before = d_find.current;

		d_step_pending = false;

		if (before == 0)
		{
			return;
		}

		d_find.current = -1;

		if (before > 0)
		{
			var match = d_find.get_match(before);

			mark_file(match.file, d_diff.get_files()[match.file]);
		}

		step(1);
	}

	public void step_to_first()
	{
		d_step_pending = true;
		step_if_pending();
	}

	private static void tag_added(Gtk.TextTagTable table, Gtk.TextTag tag)
	{
		raise_tags(table);
	}

	public void take_selection(string text, Gtk.TextView view, int offset)
	{
		search_mode_enabled = true;
		d_field.text = text;
		apply();

		var files = d_diff.get_files();
		var chosen = -1;

		for (var i = 0; i < d_find.length && chosen < 0; i++)
		{
			var match = d_find.get_match(i);
			var views = files[match.file].get_text_views();
			var here = match.side < views.length ? views[match.side] : null;

			if (here == view && files[match.file].get_line_offset(view, match.line) + match.start >= offset)
			{
				chosen = i;
			}
		}

		if (chosen < 0)
		{
			return;
		}

		d_find.current = chosen - 1;
		step(1);
	}

	private string? typed_error()
	{
		return new TextMatch(d_field.text, d_switches.match_case, d_switches.regex).error;
	}

	private void watch(Gitg.DiffViewFile file)
	{
		if (d_watched.add(file))
		{
			file.page_shown.connect(() => page_shown(file));
		}
	}
}

}
