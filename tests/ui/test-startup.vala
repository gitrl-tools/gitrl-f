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

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/ui/startup/gitg-style-reaches-a-window-started-in-a-repository", test_gitg_style_reaches_a_window_started_in_a_repository);

	return Test.run();
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

	var app = new Gitree.Application();
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
	app.run({"git-tree"});
	Environment.set_current_dir(directory);

	assert_cmpfloat(background.alpha, CompareOperator.EQ, 1.0);

	repo.remove();
}

}
