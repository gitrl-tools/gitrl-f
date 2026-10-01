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
 */namespace GittreeTest
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

private static Gtk.Button button(Gittree.Window window, string tooltip)
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

private static Repo four_subjects() throws Error
{
	var repo = Repo.create();

	repo.commit("Parser fix");
	repo.commit("parser tidy");
	repo.commit("prefix work");
	repo.commit("issue 42");

	return repo;
}

private static Gtk.Widget list_bar(Gittree.Window window)
{
	return window.history.search_field.get_parent();
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gittree/ui/search/a-bad-expression-turns-the-field-red", test_a_bad_expression_turns_the_field_red);
	Test.add_func("/gittree/ui/search/bar-opens-from-the-shortcut-and-the-toggle", test_bar_opens_from_the_shortcut_and_the_toggle);
	Test.add_func("/gittree/ui/search/escape-closes-keeps-the-text-and-gives-the-focus-back", test_escape_closes_keeps_the_text_and_gives_the_focus_back);
	Test.add_func("/gittree/ui/search/marks-show-in-the-subject-hash-and-author-columns", test_marks_show_in_the_subject_hash_and_author_columns);
	Test.add_func("/gittree/ui/search/next-and-previous-wrap-and-count", test_next_and_previous_wrap_and_count);
	Test.add_func("/gittree/ui/search/no-match-turns-the-field-red", test_no_match_turns_the_field_red);
	Test.add_func("/gittree/ui/search/opening-again-selects-the-kept-text", test_opening_again_selects_the_kept_text);
	Test.add_func("/gittree/ui/search/switches-keep-their-state-when-the-bar-closes", test_switches_keep_their_state_when_the_bar_closes);
	Test.add_func("/gittree/ui/search/switches-narrow-the-matches", test_switches_narrow_the_matches);
	Test.add_func("/gittree/ui/search/switches-say-what-they-do", test_switches_say_what_they_do);
	Test.add_func("/gittree/ui/search/tick-searches-again", test_tick_searches_again);
	Test.add_func("/gittree/ui/search/ticking-nothing-counts-no-match", test_ticking_nothing_counts_no_match);
	Test.add_func("/gittree/ui/search/typing-moves-nothing", test_typing_moves_nothing);

	return Test.run();
}

private static int marked_pixels(Gittree.Window window, int index)
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

private static Gittree.Window opened(Repo repo) throws Error
{
	var ticks = new Gee.HashSet<string>();
	ticks.add("refs/heads/master");
	ticks.add("refs/heads/feature/scan");

	var window = new Gittree.Window(application());
	window.open_repository(Gittree.Application.discover_repository(repo.path), ticks, {}, repo.path);
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

private static void test_a_bad_expression_turns_the_field_red()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		type_text(window, "(");
		check_labelled(list_bar(window), "Regular expression").active = true;
		settle(200);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "Bad regular expression");
		assert_true(window.history.search_field.get_style_context().has_class("error"));
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
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
			if (child is Gtk.ToggleButton && child.tooltip_text == "Search the history")
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

private static void test_escape_closes_keeps_the_text_and_gives_the_focus_back()
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
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "fix");
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "");
		assert_cmpint(marked_pixels(window, 0), CompareOperator.EQ, 0);
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

private static void test_opening_again_selects_the_kept_text()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo);
		int start;
		int end;

		type_text(window, "fix");

		var count = window.history.search_count;

		window.history.search_visible = false;
		settle(100);
		window.activate_action("search", null);
		settle(300);

		assert_true(window.history.search_visible);
		assert_cmpstr(window.history.search_field.text, CompareOperator.EQ, "fix");
		assert_true(window.history.search_field.has_focus);
		assert_true(window.history.search_field.get_selection_bounds(out start, out end));
		assert_cmpint(start, CompareOperator.EQ, 0);
		assert_cmpint(end, CompareOperator.EQ, 3);
		assert_cmpstr(window.history.search_count, CompareOperator.EQ, count);
		assert_cmpstr(count, CompareOperator.EQ, "3 matches");
		assert_true(marked_pixels(window, 0) > 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_keep_their_state_when_the_bar_closes()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);

		type_text(window, "parser");
		check_labelled(list_bar(window), "Match case").active = true;
		check_labelled(list_bar(window), "Whole word").active = true;
		window.history.search_visible = false;
		settle(100);
		window.history.search_visible = true;
		settle(100);

		assert_true(check_labelled(list_bar(window), "Match case").active);
		assert_true(check_labelled(list_bar(window), "Whole word").active);
		assert_false(check_labelled(list_bar(window), "Regular expression").active);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_narrow_the_matches()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window);

		type_text(window, "parser");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "2 matches");

		check_labelled(bar, "Match case").active = true;
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		check_labelled(bar, "Match case").active = false;
		type_text(window, "fix");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "2 matches");

		check_labelled(bar, "Whole word").active = true;
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 match");

		check_labelled(bar, "Whole word").active = false;
		type_text(window, "issue [0-9]+");

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "No match");

		check_labelled(bar, "Regular expression").active = true;
		settle(100);

		assert_cmpstr(window.history.search_count, CompareOperator.EQ, "1 of 1");
		assert_true(marked_pixels(window, 0) > 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_switches_say_what_they_do()
{
	try
	{
		var repo = four_subjects();
		var window = opened(repo);
		var bar = list_bar(window);

		assert_cmpstr(check_labelled(bar, "Match case").tooltip_text, CompareOperator.EQ, "Tell capital and small letters apart");
		assert_cmpstr(check_labelled(bar, "Whole word").tooltip_text, CompareOperator.EQ, "Match only whole words");
		assert_cmpstr(check_labelled(bar, "Regular expression").tooltip_text, CompareOperator.EQ, "Read the text as a regular expression, as git log -G does");

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

private static void type_text(Gittree.Window window, string text)
{
	window.history.search_visible = true;
	window.history.search_field.text = text;
	settle(400);
}

}
