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

public int main(string[] args)
{
	Intl.setlocale(LocaleCategory.ALL, "");
	Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.GITG_LOCALEDIR);
	Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain(Config.GETTEXT_PACKAGE);

	var app = new Gtk.Application(Config.APPLICATION_ID, ApplicationFlags.NON_UNIQUE);

	app.startup.connect(() => {
		try
		{
			Gitg.init();
		}
		catch (Error e)
		{
			stderr.printf("git tree: %s\n", e.message);
		}
	});

	app.activate.connect(() => {
		new Gtk.ApplicationWindow(app).show();
	});

	return app.run(args);
}

}
