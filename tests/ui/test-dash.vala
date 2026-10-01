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
namespace GittreeTest
{

private static Gittree.Application application()
{
	var app = GLib.Application.get_default() as Gittree.Application;

	if (app == null)
	{
		app = new Gittree.Application();

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

private static Gtk.Widget? find(Gtk.Widget widget, Type type)
{
	if (widget.get_type().is_a(type))
	{
		return widget;
	}

	var container = widget as Gtk.Container;

	if (container == null)
	{
		return null;
	}

	foreach (var child in container.get_children())
	{
		var found = find(child, type);

		if (found != null)
		{
			return found;
		}
	}

	return null;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/dash/a-folder-in-a-repository-opens-it", test_a_folder_in_a_repository_opens_it);
	Test.add_func("/gittree/ui/dash/a-folder-outside-a-repository-shows-an-error", test_a_folder_outside_a_repository_shows_an_error);
	Test.add_func("/gittree/ui/dash/opened-repository-is-listed-and-opens", test_opened_repository_is_listed_and_opens);
	Test.add_func("/gittree/ui/dash/shows-with-no-repository", test_shows_with_no_repository);

	return Test.run();
}

private static void settle(int milliseconds)
{
	for (var i = 0; i < milliseconds / 10; i++)
	{
		while (Gtk.events_pending())
		{
			Gtk.main_iteration();
		}

		Thread.usleep(10000);
	}
}

private static void test_a_folder_in_a_repository_opens_it()
{
	Repo repo;

	try
	{
		repo = Repo.create();
		repo.commit("first");
	}
	catch (Error e)
	{
		Test.fail_printf("fixture failed: %s", e.message);
		return;
	}

	var window = new Gittree.Window(application());
	window.show();
	settle(100);

	var dash = find(window, typeof(Gittree.DashView)) as Gittree.DashView;
	dash.open_location(repo.path);
	settle(100);

	var bar = window.get_titlebar() as Gtk.HeaderBar;
	assert_cmpstr(bar.title, CompareOperator.EQ, repo.path.get_basename());
	assert_false(dash.get_mapped());
	assert_false(window.error_shown);

	window.destroy();
	repo.remove();
}

private static void test_a_folder_outside_a_repository_shows_an_error()
{
	string outside;

	try
	{
		outside = DirUtils.make_tmp("gittree-outside-XXXXXX");
	}
	catch (Error e)
	{
		Test.fail_printf("fixture failed: %s", e.message);
		return;
	}

	var window = new Gittree.Window(application());
	window.show();
	settle(100);

	var dash = find(window, typeof(Gittree.DashView)) as Gittree.DashView;
	dash.open_location(File.new_for_path(outside));
	settle(100);

	assert_true(window.error_shown);
	assert_true(dash.get_mapped());

	window.destroy();
	DirUtils.remove(outside);
}

private static void test_opened_repository_is_listed_and_opens()
{
	Repo repo;

	try
	{
		repo = Repo.create();
		repo.commit("first");
	}
	catch (Error e)
	{
		Test.fail_printf("fixture failed: %s", e.message);
		return;
	}

	var first = new Gittree.Window(application());
	first.open_repository(repo.path);
	settle(500);
	first.destroy();

	var window = new Gittree.Window(application());
	window.show();
	settle(100);

	var list = find(window, typeof(Gitg.RepositoryListBox)) as Gitg.RepositoryListBox;
	assert_nonnull(list);

	Gitg.RepositoryListBox.Row? row = null;

	foreach (var child in list.get_children())
	{
		var candidate = child as Gitg.RepositoryListBox.Row;

		if (candidate != null && candidate.repository_name == repo.path.get_basename())
		{
			row = candidate;
		}
	}

	assert_nonnull(row);

	list.row_activated(row);
	settle(100);

	var bar = window.get_titlebar() as Gtk.HeaderBar;
	assert_cmpstr(bar.title, CompareOperator.EQ, repo.path.get_basename());
	assert_false(list.get_mapped());

	window.destroy();
	repo.remove();
}

private static void test_shows_with_no_repository()
{
	var window = new Gittree.Window(application());
	window.show();
	settle(100);

	var dash = find(window, typeof(Gittree.DashView));
	assert_nonnull(dash);
	assert_true(dash.get_mapped());

	window.destroy();
}

}
