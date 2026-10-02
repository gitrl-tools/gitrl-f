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
	Test.init(ref args);

	Test.add_func("/gittree/ui/startup/gitg-style-reaches-a-window-started-in-a-repository", test_gitg_style_reaches_a_window_started_in_a_repository);
	Test.add_func("/gittree/ui/startup/no-wd-opens-the-chooser-in-a-repository", test_no_wd_opens_the_chooser_in_a_repository);
	Test.add_func("/gittree/ui/startup/ticks-are-kept-for-each-repository", test_ticks_are_kept_for_each_repository);

	return Test.run();
}

private static string started(File directory, string[] arguments, string[] ticks)
{
	var app = new Gittree.Application();
	var found = "";

	app.window_added.connect((window) => {
		Idle.add(() => {
			var history = ((Gittree.Window)window).history;
			var names = new Gee.ArrayList<string>();

			names.add_all(history.ticks);
			names.sort();
			found = string.joinv(",", names.to_array());

			if (ticks.length > 0)
			{
				var chosen = new Gee.HashSet<string>();

				chosen.add_all_array(ticks);
				history.set_ticks(chosen);
			}

			window.close();

			return false;
		});
	});

	var before = Environment.get_current_dir();
	Environment.set_current_dir(directory.get_path());
	app.run(arguments);
	Environment.set_current_dir(before);

	return found;
}

private static void test_gitg_style_reaches_a_window_started_in_a_repository()
{
	Repo repo;

	try
	{
		repo = Repo.create();
		repo.commit("first");
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}

	var app = new Gittree.Application();
	var background = Gdk.RGBA();

	app.window_added.connect((window) => {
		Idle.add(() => {
			var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			var context = header.get_style_context();

			context.add_class("gitg-file-header");
			context.add_class("expanded");

			Value value = context.get_property("background-color", context.get_state());
			background = *((Gdk.RGBA*)value.get_boxed());

			window.close();

			return false;
		});
	});

	var directory = Environment.get_current_dir();
	Environment.set_current_dir(repo.path.get_path());
	app.run({"gittree"});
	Environment.set_current_dir(directory);

	assert_cmpfloat(background.alpha, CompareOperator.EQ, 1.0);

	repo.remove();
}

private static void test_no_wd_opens_the_chooser_in_a_repository()
{
	Repo repo;

	try
	{
		repo = Repo.create();
		repo.commit("first");
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}

	var app = new Gittree.Application();
	var chooser = false;

	app.window_added.connect((window) => {
		Idle.add(() => {
			var dash = find(window, typeof(Gittree.DashView));

			chooser = dash != null && dash.get_mapped();
			window.close();

			return false;
		});
	});

	var directory = Environment.get_current_dir();
	Environment.set_current_dir(repo.path.get_path());
	app.run({"gittree", "--no-wd"});
	Environment.set_current_dir(directory);

	assert_true(chooser);

	repo.remove();
}

private static void test_ticks_are_kept_for_each_repository()
{
	Repo repo;

	try
	{
		repo = Repo.create();
		repo.branched();
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}

	var below = repo.path.get_child("below");

	try
	{
		below.make_directory();
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}

	assert_cmpstr(started(repo.path, {"gittree"}, {"refs/heads/feature/scan", "refs/heads/master", "refs/remotes/origin/master"}), CompareOperator.EQ, "refs/heads/feature/scan,refs/heads/fix/stamp,refs/heads/master,refs/remotes/origin/master,refs/tags/v1");

	try
	{
		repo.branch("late");
		repo.git({"tag", "v2"});
		repo.git({"update-ref", "refs/remotes/origin/late", "master"});
	}
	catch (Error e)
	{
		error("fixture failed: %s", e.message);
	}

	var kept = "refs/heads/feature/scan,refs/heads/late,refs/heads/master,refs/remotes/origin/master";

	assert_cmpstr(started(below, {"gittree"}, {}), CompareOperator.EQ, kept);
	assert_cmpstr(started(below, {"gittree", "master"}, {"refs/heads/fix/stamp"}), CompareOperator.EQ, "refs/heads/master");
	assert_cmpstr(started(repo.path, {"gittree"}, {}), CompareOperator.EQ, kept);

	repo.remove();
}

}
