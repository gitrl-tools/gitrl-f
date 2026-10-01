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
	private Gtk.CheckButton d_case;
	private Gtk.Label d_count;
	private Gitg.DiffView d_diff;
	private Ggit.Diff? d_diff_searched;
	private Gtk.SearchEntry d_field;
	private DiffFind d_find;
	private Gtk.Widget? d_return_focus;
	private bool d_scroll_pending;
	private bool d_scrolling;
	private int[] d_sizes;
	private bool[] d_split;
	private Gee.HashSet<Gitg.DiffViewFile> d_watched;

	public string count
	{
		owned get { return d_count.label; }
	}

	public Gtk.SearchEntry field
	{
		get { return d_field; }
	}

	public bool match_case
	{
		get { return d_case.active; }
		set { d_case.active = value; }
	}

	public DiffFindBar(Gitg.DiffView diff)
	{
		d_diff = diff;
		d_find = new DiffFind("", true);
		d_sizes = new int[0];
		d_split = new bool[0];
		d_watched = new Gee.HashSet<Gitg.DiffViewFile>();

		d_field = new Gtk.SearchEntry();
		d_field.width_chars = 30;
		d_field.placeholder_text = _("Find in the diff");

		var previous = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.BUTTON);
		previous.tooltip_text = _("Previous match (Shift+Enter)");
		previous.clicked.connect(() => step(-1));

		var next = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.BUTTON);
		next.tooltip_text = _("Next match (Enter)");
		next.clicked.connect(() => step(1));

		d_case = new Gtk.CheckButton.with_label(_("Match case"));
		d_case.active = true;
		d_case.toggled.connect(search);

		d_count = new Gtk.Label(null);
		d_count.width_chars = 12;
		d_count.xalign = 0;

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(d_field);
		box.add(previous);
		box.add(next);
		box.add(d_case);
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
		connect_entry(d_field);
		no_show_all = true;

		d_field.search_changed.connect(search);
		d_field.activate.connect(() => step(1));
		d_field.next_match.connect(() => step(1));
		d_field.previous_match.connect(() => step(-1));
		d_field.key_press_event.connect((event) => {
			var enter = event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter;

			if (enter && (event.state & Gdk.ModifierType.SHIFT_MASK) != 0)
			{
				step(-1);
				return true;
			}

			return false;
		});

		notify["search-mode-enabled"].connect(search_mode_changed);
		d_diff.files_changed.connect(() => {
			if (search_mode_enabled)
			{
				search();
			}
		});
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

		var index = d_diff.get_files().index_of(file);

		if (index < 0 || index >= d_split.length)
		{
			return;
		}

		if (file.split != d_split[index] || file.get_lines().size != d_sizes[index])
		{
			search();
			return;
		}

		mark_file(index, file);
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
		var same_diff = d_diff_searched != null && d_diff_searched == d_diff.diff;
		var text = search_mode_enabled ? d_field.text : "";

		d_scroll_pending = false;

		if (!same_diff)
		{
			d_watched.clear();
		}

		d_find = new DiffFind(text, d_case.active);
		d_sizes = new int[files.size];
		d_split = new bool[files.size];

		for (var i = 0; i < files.size; i++)
		{
			var file = files[i];
			var lines = file.get_lines();
			var origins = new Ggit.DiffLineType[lines.size];
			var texts = new string[lines.size];

			watch(file);

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

		d_diff_searched = d_diff.diff;

		for (var i = 0; i < files.size; i++)
		{
			mark_file(i, files[i]);
		}

		show_count();
	}

	private void search_mode_changed()
	{
		visible = search_mode_enabled;

		if (search_mode_enabled)
		{
			var window = get_toplevel() as Gtk.Window;
			var focus = window != null ? window.get_focus() : null;

			d_return_focus = focus != null && focus.is_ancestor(d_diff) ? focus : null;
			d_field.grab_focus();
			return;
		}

		d_field.text = "";
		search();

		if (!d_diff.get_mapped())
		{
			return;
		}

		if (d_return_focus != null && d_return_focus.is_ancestor(d_diff) && d_return_focus.get_mapped())
		{
			d_return_focus.grab_focus();
		}
		else
		{
			d_diff.child_focus(Gtk.DirectionType.TAB_FORWARD);
		}

		d_return_focus = null;
	}

	private void show_count()
	{
		var style = d_field.get_style_context();

		d_count.label = d_find.count_text();

		if (d_field.text != "" && d_find.length == 0)
		{
			style.add_class("error");
		}
		else
		{
			style.remove_class("error");
		}
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

	private static void tag_added(Gtk.TextTagTable table, Gtk.TextTag tag)
	{
		raise_tags(table);
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
