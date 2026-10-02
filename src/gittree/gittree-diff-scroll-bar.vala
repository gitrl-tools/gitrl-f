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

public class DiffScrollBar : Gtk.Scrollbar
{
	private Gitg.DiffView d_diff;
	private DiffFindBar d_find;
	private Gtk.Adjustment? d_followed;
	private Gtk.ScrolledWindow? d_pane;
	private Ggit.Diff? d_shown;
	private Gee.HashSet<Gitg.DiffViewFile> d_watched;

	public DiffScrollBar(Gitg.DiffView diff, DiffFindBar find)
	{
		Object(orientation: Gtk.Orientation.HORIZONTAL);

		d_diff = diff;
		d_find = find;
		d_watched = new Gee.HashSet<Gitg.DiffViewFile>();
		no_show_all = true;

		d_diff.files_changed.connect(refresh);
		d_find.moved.connect(follow);
	}

	private Gitg.DiffViewFile? chosen(Gee.List<Gitg.DiffViewFile> files)
	{
		var current = d_find.current_file;

		if (current >= 0 && current < files.size)
		{
			return files[current];
		}

		if (d_pane == null)
		{
			return null;
		}

		var content = ((Gtk.Bin)d_pane.get_child()).get_child();
		var middle = d_pane.vadjustment.value + d_pane.vadjustment.page_size / 2;
		var distance = double.MAX;
		Gitg.DiffViewFile? best = null;

		foreach (var file in files)
		{
			var x = 0;
			var y = 0;

			if (!file.get_mapped() || !file.translate_coordinates(content, 0, 0, out x, out y))
			{
				continue;
			}

			var away = middle < y ? y - middle : double.max(0, middle - y - file.get_allocated_height());

			if (away < distance)
			{
				best = file;
				distance = away;
			}
		}

		return best;
	}

	private void follow()
	{
		var file = chosen(d_diff.get_files());
		var views = file != null ? file.get_text_views() : new Gtk.TextView[0];
		var scrolled = views.length > 0 ? views[0].get_parent() as Gtk.ScrolledWindow : null;
		var followed = scrolled != null ? scrolled.hadjustment : null;

		if (followed != d_followed)
		{
			if (d_followed != null)
			{
				d_followed.changed.disconnect(show_when_wide);
			}

			d_followed = followed;

			if (followed != null)
			{
				adjustment = followed;
				followed.changed.connect(show_when_wide);
			}
		}

		show_when_wide();
	}

	private void refresh()
	{
		var files = d_diff.get_files();

		if (d_shown != d_diff.diff)
		{
			d_shown = d_diff.diff;
			d_watched.clear();
		}

		foreach (var file in files)
		{
			watch(file);

			foreach (var view in file.get_text_views())
			{
				((Gtk.ScrolledWindow)view.get_parent()).hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
			}
		}

		if (d_pane == null && files.size > 0)
		{
			d_pane = files[0].get_ancestor(typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow;
			d_pane.vadjustment.value_changed.connect(follow);
			d_pane.vadjustment.changed.connect(follow);
		}

		follow();
	}

	private void show_when_wide()
	{
		visible = d_followed != null && d_followed.upper > d_followed.page_size;
	}

	private void watch(Gitg.DiffViewFile file)
	{
		if (d_watched.add(file))
		{
			file.page_shown.connect(refresh);
		}
	}
}

}
