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

public class FilterBar : Gtk.SearchBar
{
	private Gtk.SearchEntry d_field;
	private Gtk.Entry d_paths;
	private Gtk.Label d_problem;
	private SearchSwitches d_switches;

	public Gtk.SearchEntry field
	{
		get { return d_field; }
	}

	public bool match_case
	{
		get { return d_switches.match_case; }
		set { d_switches.match_case = value; }
	}

	public Gtk.Entry paths_field
	{
		get { return d_paths; }
	}

	public string problem
	{
		owned get { return d_problem.label; }
	}

	public bool regex
	{
		get { return d_switches.regex; }
		set { d_switches.regex = value; }
	}

	public signal void applied(string text, bool match_case, bool regex, string[] paths);

	public FilterBar()
	{
		d_field = new Gtk.SearchEntry();
		d_field.width_chars = 40;
		d_field.tooltip_text = _("Searches the lines that each commit added or removed, in every file of every ref, as git log -S does, or git log -G with Regular expression");
		d_field.activate.connect(apply);
		d_field.search_changed.connect(() => check());

		d_paths = new Gtk.Entry();
		d_paths.width_chars = 30;
		d_paths.placeholder_text = _("Only commits that change these paths");
		d_paths.tooltip_text = _("Files or folders, split by spaces. Globs such as '*.yaml' work");
		d_paths.activate.connect(apply);
		d_paths.changed.connect(() => check());

		d_problem = new Gtk.Label(null);

		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		box.add(d_field);

		d_switches = new SearchSwitches(box);
		d_switches.changed.connect(() => check());

		var filter = new Gtk.Button.with_label(_("Filter"));
		filter.clicked.connect(apply);

		box.add(d_paths);
		box.add(filter);
		box.add(d_problem);
		var row = new BarRow(box);

		row.show_all();
		add(row);
		check();

		notify["search-mode-enabled"].connect(() => {
			if (search_mode_enabled)
			{
				d_field.grab_focus();
			}
		});
	}

	private void apply()
	{
		string[] paths;
		var whole = split(d_paths.text, out paths);

		if (check() && whole)
		{
			applied(d_field.text, d_switches.match_case, d_switches.regex, paths);
		}
	}

	private bool check()
	{
		string[] paths;
		var bad = d_switches.match(d_field.text).error != null;
		var unquoted = !split(d_paths.text, out paths);

		d_field.placeholder_text = d_switches.regex ? _("Only commits whose added or removed lines match this")
		                                           : _("Only commits that add or remove this text");
		d_problem.label = bad ? _("Bad regular expression") : (unquoted ? _("A quote is not closed") : "");
		mark(d_field, bad);
		mark(d_paths, unquoted);

		return !bad && !unquoted;
	}

	private static void mark(Gtk.Widget widget, bool bad)
	{
		var style = widget.get_style_context();

		if (bad)
		{
			style.add_class("error");
		}
		else
		{
			style.remove_class("error");
		}
	}

	public void set_paths(string[] paths)
	{
		var words = new string[0];

		foreach (var path in paths)
		{
			words += Regex.match_simple("^[^\\s'\"\\\\]+$", path) ? path : Shell.quote(path);
		}

		d_paths.text = string.joinv(" ", words);
	}

	private static bool split(string text, out string[] paths)
	{
		paths = new string[0];

		if (text.strip() == "")
		{
			return true;
		}

		try
		{
			return Shell.parse_argv(text, out paths);
		}
		catch (ShellError e)
		{
			return false;
		}
	}
}

}
