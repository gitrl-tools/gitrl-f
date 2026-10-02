/*
 * This file is part of gitrl-f
 *
 * Copyright (C) 2026 alexandros filotheou <alexandros.filotheou@gmail.com>
 *
 * gitrl-f is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * gitrl-f is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along
 * with gitrl-f. If not, see <http://www.gnu.org/licenses/>.
 */
namespace GitrlfTest
{

private static Gitrlf.Application application()
{
	var app = GLib.Application.get_default() as Gitrlf.Application;

	if (app == null)
	{
		app = new Gitrlf.Application();

		try
		{
			app.register();
		}
		catch (Error e)
		{
			Test.fail_printf("could not register: %s", e.message);
		}
	}

	return app;
}

private static void drain()
{
	while (Gtk.events_pending())
	{
		Gtk.main_iteration();
	}
}

private static string[] labels_of(MenuModel menu)
{
	var labels = new string[0];

	for (var i = 0; i < menu.get_n_items(); i++)
	{
		var section = menu.get_item_link(i, Menu.LINK_SECTION);

		for (var j = 0; j < section.get_n_items(); j++)
		{
			string label;
			string action;

			section.get_item_attribute(j, Menu.ATTRIBUTE_LABEL, "s", out label);
			section.get_item_attribute(j, Menu.ATTRIBUTE_ACTION, "s", out action);

			labels += "%d:%s:%s".printf(i, label, action);
		}
	}

	return labels;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitrlf/ui/window/about-credits-the-logo-and-links-the-site", test_about_credits_the_logo_and_links_the_site);
	Test.add_func("/gitrlf/ui/window/header-bar-order", test_header_bar_order);
	Test.add_func("/gitrlf/ui/window/menu-entries", test_menu_entries);
	Test.add_func("/gitrlf/ui/window/shortcuts", test_shortcuts);
	Test.add_func("/gitrlf/ui/window/size-is-kept", test_size_is_kept);
	Test.add_func("/gitrlf/ui/window/title-and-subtitle", test_title_and_subtitle);
	Test.add_func("/gitrlf/ui/window/two-runs-are-two-processes", test_two_runs_are_two_processes);

	return Test.run();
}

private static Repo new_repository()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		return repo;
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}
}

private static void test_about_credits_the_logo_and_links_the_site()
{
	var app = application();
	var window = new Gitrlf.Window(app);

	window.show();
	drain();

	app.activate_action("about", null);
	drain();

	Gtk.AboutDialog? about = null;

	foreach (var toplevel in Gtk.Window.list_toplevels())
	{
		if (toplevel is Gtk.AboutDialog)
		{
			about = (Gtk.AboutDialog)toplevel;
		}
	}

	assert_nonnull(about);
	assert_cmpstr(about.logo_icon_name, CompareOperator.EQ, Gitrlf.Config.APPLICATION_ID);
	assert_cmpstr(about.website, CompareOperator.EQ, "https://github.com/li9i/gitrl-f");
	assert_true("Git logo by Jason Long, CC BY 3.0" in string.joinv("|", about.artists));
	assert_cmpstr(Gtk.Window.get_default_icon_name(), CompareOperator.EQ, Gitrlf.Config.APPLICATION_ID);

	about.destroy();
	window.destroy();
}

private static void test_header_bar_order()
{
	var window = new Gitrlf.Window(application());
	var repo = new_repository();

	window.open_repository(repo.path);
	window.show();
	drain();

	var bar = window.get_titlebar() as Gtk.HeaderBar;
	var start = new string[0];
	var end = new string[0];

	foreach (var child in bar.get_children())
	{
		Gtk.PackType pack;
		bar.child_get(child, "pack-type", out pack);

		var name = child.get_type().name() + (child.visible ? "" : "(hidden)");

		if (pack == Gtk.PackType.START)
		{
			start += name;
		}
		else
		{
			end += name;
		}
	}

	assert_cmpstr(string.joinv(",", start), CompareOperator.EQ, "GtkButton,GtkStackSwitcher(hidden)");
	assert_cmpstr(string.joinv(",", end), CompareOperator.EQ, "GtkMenuButton,GtkToggleButton");

	window.destroy();
	repo.remove();
}

private static void test_menu_entries()
{
	var window = new Gitrlf.Window(application());
	Gtk.MenuButton? menu_button = null;

	var bar = window.get_titlebar() as Gtk.HeaderBar;
	assert_nonnull(bar);

	foreach (var child in bar.get_children())
	{
		if (child is Gtk.MenuButton)
		{
			menu_button = child as Gtk.MenuButton;
		}
	}

	assert_nonnull(menu_button);
	assert_cmpstr(string.joinv("|", labels_of(menu_button.menu_model)), CompareOperator.EQ,
	              "0:_New Window:app.new-window|1:_Reload:win.reload|2:_Preferences:win.preferences|2:_About gitrl-f:app.about|2:_Quit:app.quit");

	window.destroy();
}

private static void test_shortcuts()
{
	var app = application();

	assert_cmpstr(string.joinv(",", app.get_accels_for_action("app.quit")), CompareOperator.EQ, "<Primary>q");
	assert_cmpstr(string.joinv(",", app.get_accels_for_action("win.reload")), CompareOperator.EQ, "F5");
}

private static void test_size_is_kept()
{
	var settings = new Settings(Gitrlf.Config.APPLICATION_ID + ".state.window");
	settings.set_value("size", new Variant("(ii)", 700, 520));

	var window = new Gitrlf.Window(application());
	window.show();
	drain();

	int width;
	int height;
	window.get_default_size(out width, out height);

	assert_cmpint(width, CompareOperator.EQ, 700);
	assert_cmpint(height, CompareOperator.EQ, 520);

	window.resize(810, 610);

	for (var i = 0; i < 50; i++)
	{
		drain();
		Thread.usleep(10000);
	}

	int saved_width;
	int saved_height;
	settings.get_value("size").get("(ii)", out saved_width, out saved_height);

	assert_cmpint(saved_width, CompareOperator.EQ, 810);
	assert_cmpint(saved_height, CompareOperator.EQ, 610);

	window.destroy();
}

private static void test_title_and_subtitle()
{
	var window = new Gitrlf.Window(application());
	var bar = window.get_titlebar() as Gtk.HeaderBar;

	assert_cmpstr(bar.title, CompareOperator.EQ, "gitrl-f");
	assert_null(bar.subtitle);

	var repo = new_repository();
	window.open_repository(repo.path);

	assert_cmpstr(bar.title, CompareOperator.EQ, repo.path.get_basename());
	assert_cmpstr(bar.subtitle, CompareOperator.EQ, Gitg.Utils.replace_home_dir_with_tilde(repo.path));

	window.show_dash();

	assert_cmpstr(bar.title, CompareOperator.EQ, "gitrl-f");
	assert_null(bar.subtitle);

	window.destroy();
	repo.remove();
}

private static void test_two_runs_are_two_processes()
{
	var repo = new_repository();
	string[] argv = { Environment.get_variable("GITRLF_BINARY"), null };
	Pid first;
	Pid second;

	try
	{
		Process.spawn_async(repo.path.get_path(), argv, null, SpawnFlags.DO_NOT_REAP_CHILD, null, out first);
		Process.spawn_async(repo.path.get_path(), argv, null, SpawnFlags.DO_NOT_REAP_CHILD, null, out second);
	}
	catch (SpawnError e)
	{
		Test.fail_printf("could not start: %s", e.message);
		return;
	}

	Thread.usleep(1500000);

	int status;

	assert_cmpint(Posix.waitpid(first, out status, Posix.WNOHANG), CompareOperator.EQ, 0);
	assert_cmpint(Posix.waitpid(second, out status, Posix.WNOHANG), CompareOperator.EQ, 0);

	Posix.kill(first, Posix.Signal.TERM);
	Posix.kill(second, Posix.Signal.TERM);
	Posix.waitpid(first, out status, 0);
	Posix.waitpid(second, out status, 0);

	repo.remove();
}

}
