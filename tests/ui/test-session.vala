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
 */namespace GitreeTest
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

private static string differences(File a, File b) throws Error
{
	return run({ "diff", "-r", "--no-dereference", "-x", "git-tree-ticks", a.get_path(), b.get_path() });
}

private static void every_row(Gitree.Window window)
{
	var rows = window.history.rows().length;

	for (var i = 0; i < rows; i++)
	{
		window.history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
		settle(120);
	}
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitree/ui/session/a-session-changes-nothing-but-the-ticks", test_a_session_changes_nothing_but_the_ticks);

	return Test.run();
}

private static string run(string[] argv) throws Error
{
	string output;
	string errors;
	int status;

	Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH, null, out output, out errors, out status);

	return output + errors;
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

private static void test_a_session_changes_nothing_but_the_ticks()
{
	try
	{
		var repo = Repo.create();
		repo.branched();
		repo.git({"tag", "-a", "-m", "annotated", "v2", "master"});
		repo.commit("binary", "blob.bin", "\x01\x02");
		repo.commit("image", "dot.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2\" height=\"2\"/>");
		FileUtils.set_contents(repo.path.get_child("file").get_path(), "uncommitted change\n");
		FileUtils.set_contents(repo.path.get_child("untracked").get_path(), "untracked\n");

		var copy = repo.path.get_parent().get_child(repo.path.get_basename() + "-copy");
		run({ "cp", "-a", repo.path.get_path(), copy.get_path() });

		var location = Gitree.Application.discover_repository(repo.path);
		var window = new Gitree.Window(application());
		window.set_default_size(1000, 800);
		window.open_repository(location, null, {}, repo.path);
		window.show();
		settle(200);

		var refs = window.history.paned.refs_list;

		refs.tick_all();
		every_row(window);
		refs.tick_none();
		refs.tick_all();
		window.history.jump("refs/tags/v2");
		window.history.search_visible = true;
		window.history.search_field.text = "fix";
		settle(300);
		window.history.step(1);
		window.history.step(-1);
		window.activate_action("reload", null);
		settle(200);
		window.close();
		settle(100);

		var limited = new Gitree.Window(application());
		limited.set_default_size(1000, 800);
		limited.open_repository(location, null, {"fix"}, repo.path);
		limited.show();
		settle(200);
		every_row(limited);
		limited.close();
		settle(100);

		assert_true(repo.path.get_child(".git").get_child("git-tree-ticks").query_exists());
		assert_cmpstr(differences(copy, repo.path), CompareOperator.EQ, "");

		run({ "rm", "-rf", copy.get_path() });
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
