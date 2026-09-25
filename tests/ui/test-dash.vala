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
namespace GitreeTest
{

private static Gitree.Application application()
{
	var app = GLib.Application.get_default() as Gitree.Application;

	if (app == null)
	{
		app = new Gitree.Application();

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

	Test.add_func("/gitree/ui/dash/opened-repository-is-listed-and-opens", test_opened_repository_is_listed_and_opens);
	Test.add_func("/gitree/ui/dash/shows-with-no-repository", test_shows_with_no_repository);

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

	var first = new Gitree.Window(application());
	first.open_repository(repo.path);
	settle(500);
	first.destroy();

	var window = new Gitree.Window(application());
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
	var window = new Gitree.Window(application());
	window.show();
	settle(100);

	var dash = find(window, typeof(Gitree.DashView));
	assert_nonnull(dash);
	assert_true(dash.get_mapped());

	window.destroy();
}

}
