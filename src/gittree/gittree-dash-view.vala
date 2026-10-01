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

public class DashView : Gtk.Box
{
	private Gitg.RepositoryListBox d_repository_list;
	private Gtk.SearchEntry d_search_entry;

	public signal void location_activated(File location);
	public signal void repository_activated(Gitg.Repository repository);
	public signal void show_error(string primary, string secondary);

	construct
	{
		orientation = Gtk.Orientation.VERTICAL;

		var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		header.margin = 12;

		d_search_entry = new Gtk.SearchEntry();
		d_search_entry.placeholder_text = _("Search repositories");
		d_search_entry.hexpand = true;
		d_search_entry.search_changed.connect(on_search_changed);
		header.add(d_search_entry);

		var open_button = new Gtk.Button.with_mnemonic(_("_Open Repository…"));
		open_button.clicked.connect(on_open_clicked);
		header.add(open_button);

		add(header);

		d_repository_list = new Gitg.RepositoryListBox();
		d_repository_list.repository_activated.connect((repository) => {
			repository_activated(repository);
		});
		d_repository_list.show_error.connect((primary, secondary) => {
			show_error(primary, secondary);
		});

		var scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hexpand = true;
		scrolled.vexpand = true;
		scrolled.add(d_repository_list);

		add(scrolled);

		d_repository_list.location = File.new_for_path(Path.build_filename(Environment.get_user_data_dir(),
		                                                                   "gittree",
		                                                                   "repositories.gbookmarks"));
		d_repository_list.populate_bookmarks();

		show_all();
	}

	public void add_repository(Gitg.Repository repository)
	{
		d_repository_list.add_repository(repository);
	}

	private void on_open_clicked()
	{
		var chooser = new Gtk.FileChooserNative(_("Open Repository"),
		                                        get_toplevel() as Gtk.Window,
		                                        Gtk.FileChooserAction.SELECT_FOLDER,
		                                        _("_Open"),
		                                        _("_Cancel"));

		if (chooser.run() == Gtk.ResponseType.ACCEPT)
		{
			var file = chooser.get_file();

			if (file != null)
			{
				open_location(file);
			}
		}

		chooser.destroy();
	}

	private void on_search_changed()
	{
		d_repository_list.filter_text(d_search_entry.text);
	}

	public void open_location(File file)
	{
		var location = Application.discover_repository(file);

		if (location == null)
		{
			show_error(_("Not a git repository"),
			           _("%s is not inside a git repository.").printf(file.get_path()));
			return;
		}

		location_activated(location);
	}
}

}
