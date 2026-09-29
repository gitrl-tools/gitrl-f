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

private static Gtk.Button button(Gitree.Window window, string tooltip)
{
	foreach (var widget in find_all(window.history.widget, typeof(Gtk.Button)))
	{
		if (widget.tooltip_text == tooltip)
		{
			return (Gtk.Button)widget;
		}
	}

	error("no button %s", tooltip);
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitree/ui/search/bar-opens-from-the-shortcut-and-the-toggle", test_bar_opens_from_the_shortcut_and_the_toggle);
	Test.add_func("/gitree/ui/search/escape-closes-clears-and-gives-the-focus-back", test_escape_closes_clears_and_gives_the_focus_back);
	Test.add_func("/gitree/ui/search/marks-show-in-the-subject-hash-and-author-columns", test_marks_show_in_the_subject_hash_and_author_columns);
	Test.add_func("/gitree/ui/search/next-and-previous-wrap-and-count", test_next_and_previous_wrap_and_count);
	Test.add_func("/gitree/ui/search/no-match-turns-the-field-red", test_no_match_turns_the_field_red);
	Test.add_func("/gitree/ui/search/tick-searches-again", test_tick_searches_again);
	Test.add_func("/gitree/ui/search/ticking-nothing-counts-no-match", test_ticking_nothing_counts_no_match);
	Test.add_func("/gitree/ui/search/typing-moves-nothing", test_typing_moves_nothing);

	return Test.run();
}

private static int marked_pixels(Gitree.Window window, int index)
{
	var view = window.history.paned.commit_list_view;
	var column = view.get_column(index);
	var surface = new Cairo.ImageSurface(Cairo.Format.RGB24, view.get_allocated_width(), view.get_allocated_height());
	var context = new Cairo.Context(surface);

	view.draw(context);
	surface.flush();

	var data = (uint8*)surface.get_data();
	var stride = surface.get_stride();
	var end = int.min(column.get_x_offset() + column.get_width(), surface.get_width());
	var count = 0;

	for (var y = 0; y < surface.get_height(); y++)
	{
		for (var x = column.get_x_offset(); x < end; x++)
		{
			var pixel = data + y * stride + x * 4;

			if (pixel[2] == 0xfc && pixel[1] == 0xe9 && pixel[0] == 0x4f)
			{
				count++;
			}
		}
	}

	return count;
}

private static Gitree.Window opened(Repo repo) throws Error
{
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/master");
	ticks.add("refs/heads/feature/scan");

	var window = new Gitree.Window(application());
	window.open_repository(Gitree.Application.discover_repository(repo.path), ticks, {}, repo.path);
	window.set_default_size(1000, 600);
	window.show();
	settle(100);

	return window;
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

private static void test_bar_opens_from_the_shortcut_and_the_toggle()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		Gtk.ToggleButton? toggle = null;

		foreach (var child in ((Gtk.HeaderBar)window.get_titlebar()).get_children())
		{
			if (child is Gtk.ToggleButton)
			{
				toggle = (Gtk.ToggleButton)child;
			}
		}

		assert_false(window.history.search_visible);

		window.activate_action("search", null);
		assert_true(window.history.search_visible);
		assert_true(toggle.active);

		window.activate_action("search", null);
		assert_false(window.history.search_visible);

		toggle.active = true;
		assert_true(window.history.search_visible);

		assert_cmpstr(window.history.search_field.placeholder_text, CompareOperator.EQ, "Subject, message, author or hash");
		assert_cmpstr(string.joinv(",", application().get_accels_for_action("win.search")), CompareOperator.EQ, "<Primary>f");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_escape_closes_clears_and_gives_the_focus_back()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		type_text(window, "fix");
		window.history.search_field.grab_focus();
		settle(50);

		Gtk.test_widget_send_key(window.history.search_field, Gdk.Key.Escape, 0);
		settle(100);

		assert_false(window.history.search_visible);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "");
		assert_true(window.history.paned.commit_list_view.has_focus);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_marks_show_in_the_subject_hash_and_author_columns()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var sha = window.history.rows()[0].get_id().to_string();

		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		type_text(window, "fix");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.GT, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		type_text(window, sha.substring(0, 7));
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.GT, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.EQ, 0);

		type_text(window, "tester");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 1), CompareOperator.EQ, 0);
		assert_cmpint(marked_pixels(window, 2), CompareOperator.GT, 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_next_and_previous_wrap_and_count()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var next = button(window, "Next match (Enter)");
		var previous = button(window, "Previous match (Shift+Enter)");

		type_text(window, "FIX");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 matches");

		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 of 3");

		next.clicked();
		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "fix one");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 of 3");

		next.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");

		previous.clicked();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "fix one");

		window.history.search_field.activate();
		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, "Merge branch 'fix/stamp'");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_no_match_turns_the_field_red()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		type_text(window, "zzz");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		type_text(window, "base");

		assert_false(window.history.search_field.get_style_context().has_class("error"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_tick_searches_again()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		type_text(window, "feature");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		var ticks = window.history.ticks;
		ticks.remove("refs/heads/feature/scan");
		window.history.set_ticks(ticks);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticking_nothing_counts_no_match()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);

		type_text(window, "fix");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "3 matches");

		window.history.set_ticks(new Gee.HashSet<string>());

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");
		assert_true(window.history.search_field.get_style_context().has_class("error"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_typing_moves_nothing()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		var before = window.history.selected.get_subject();

		type_text(window, "fix one");

		assert_cmpstr(window.history.selected.get_subject(), CompareOperator.EQ, before);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void type_text(Gitree.Window window, string text)
{
	window.history.search_visible = true;
	window.history.search_field.text = text;
	settle(400);
}

}
