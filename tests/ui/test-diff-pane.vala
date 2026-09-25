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

private static Gtk.Widget[] find_all(Gtk.Widget widget, Type type)
{
	var found = new Gtk.Widget[0];

	if (widget.get_type().is_a(type))
	{
		found += widget;
	}

	var container = widget as Gtk.Container;

	if (container != null)
	{
		foreach (var child in container.get_children())
		{
			foreach (var inner in find_all(child, type))
			{
				found += inner;
			}
		}
	}

	return found;
}

private static Gtk.Widget[] find_named(Gtk.Widget widget, string type_name)
{
	var found = new Gtk.Widget[0];

	foreach (var candidate in find_all(widget, typeof(Gtk.Widget)))
	{
		if (candidate.get_type().name() == type_name)
		{
			found += candidate;
		}
	}

	return found;
}

private static string[] headers(Gitree.Window window)
{
	var names = new string[0];

	foreach (var file in find_named(window.history.diff_view, "GitgDiffViewFile"))
	{
		var labels = find_all(file, typeof(Gtk.Label));

		foreach (var widget in labels)
		{
			var label = (Gtk.Label)widget;

			if (label.get_name() == "label_file_header" || label.label.contains("/") || label.label.contains("."))
			{
				names += label.label;
				break;
			}
		}
	}

	return names;
}

public static int main(string[] args)
{
	Gtk.test_init(ref args);

	Test.add_func("/gitree/ui/diff-pane/added-lines-without-a-removed-partner-are-not-word-marked", test_added_lines_without_a_removed_partner_are_not_word_marked);
	Test.add_func("/gitree/ui/diff-pane/an-image-uses-gitgs-image-view", test_an_image_uses_gitgs_image_view);
	Test.add_func("/gitree/ui/diff-pane/details-are-gitgs", test_details_are_gitgs);
	Test.add_func("/gitree/ui/diff-pane/details-survive-bytes-that-are-not-utf8", test_details_survive_bytes_that_are_not_utf8);
	Test.add_func("/gitree/ui/diff-pane/diff-is-limited-to-the-paths", test_diff_is_limited_to_the_paths);
	Test.add_func("/gitree/ui/diff-pane/diff-is-limited-to-the-paths-from-a-subfolder", test_diff_is_limited_to_the_paths_from_a_subfolder);
	Test.add_func("/gitree/ui/diff-pane/diff-names-renames-and-binary-files", test_diff_names_renames_and_binary_files);
	Test.add_func("/gitree/ui/diff-pane/file-names-with-spaces-or-quotes-are-read-whole", test_file_names_with_spaces_or_quotes_are_read_whole);
	Test.add_func("/gitree/ui/diff-pane/known-language-is-highlighted", test_known_language_is_highlighted);
	Test.add_func("/gitree/ui/diff-pane/line-numbers-follow-the-hunk-header", test_line_numbers_follow_the_hunk_header);
	Test.add_func("/gitree/ui/diff-pane/orientation-follows-the-layout-setting", test_orientation_follows_the_layout_setting);
	Test.add_func("/gitree/ui/diff-pane/sections-start-folded-when-there-are-several", test_sections_start_folded_when_there_are_several);
	Test.add_func("/gitree/ui/diff-pane/split-sides-scroll-together", test_split_sides_scroll_together);
	Test.add_func("/gitree/ui/diff-pane/ticking-nothing-clears-the-details", test_ticking_nothing_clears_the_details);
	Test.add_func("/gitree/ui/diff-pane/word-mark-colours", test_word_mark_colours);
	Test.add_func("/gitree/ui/diff-pane/word-marks-in-both-views", test_word_marks_in_both_views);
	Test.add_func("/gitree/ui/diff-pane/word-marks-reach-across-a-no-newline-marker", test_word_marks_reach_across_a_no_newline_marker);
	return Test.run();
}

private static string marked_words(Gitree.Window window, string tag_name)
{
	var words = new string[0];

	foreach (var widget in find_all(window.history.diff_view, typeof(Gtk.SourceView)))
	{
		var buffer = ((Gtk.SourceView)widget).buffer;
		var tag = buffer.tag_table.lookup(tag_name);

		if (tag == null)
		{
			continue;
		}

		Gtk.TextIter iter;
		buffer.get_start_iter(out iter);

		while (iter.forward_to_tag_toggle(tag))
		{
			if (!iter.starts_tag(tag))
			{
				continue;
			}

			var end = iter;
			end.forward_to_tag_toggle(tag);
			words += iter.get_text(end);
			iter = end;
		}
	}

	return string.joinv("|", words);
}

private static Gitree.Window opened(Repo repo, string[] ticked, string[] paths = {}, File? directory = null) throws Error
{
	var ticks = new Gee.HashSet<string>();

	foreach (var name in ticked)
	{
		ticks.add(name);
	}

	var window = new Gitree.Window(application());
	window.set_default_size(1200, 900);
	window.open_repository(Gitree.Application.discover_repository(repo.path), ticks, paths, directory != null ? directory : repo.path);
	window.show();
	settle(300);

	return window;
}

private static void select_subject(Gitree.Window window, string subject)
{
	var rows = window.history.rows();

	for (var i = 0; i < rows.length; i++)
	{
		if (rows[i].get_subject() == subject)
		{
			window.history.paned.commit_list_view.get_selection().select_path(new Gtk.TreePath.from_indices(i));
		}
	}

	settle(300);
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

private static string source_text(Gitree.Window window)
{
	var text = new StringBuilder();

	foreach (var widget in find_all(window.history.diff_view, typeof(Gtk.SourceView)))
	{
		var buffer = ((Gtk.SourceView)widget).buffer;
		Gtk.TextIter start;
		Gtk.TextIter end;

		buffer.get_bounds(out start, out end);
		text.append(buffer.get_text(start, end, true));
	}

	return text.str;
}

private static void test_added_lines_without_a_removed_partner_are_not_word_marked()
{
	try
	{
		var repo = Repo.create();
		repo.commit("start", "f", "old line");
		FileUtils.set_contents(repo.path.get_child("f").get_path(), "new line\nextra one\nextra two\n");
		repo.git({"commit", "--quiet", "-am", "grow"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "grow");

		var added = marked_words(window, "word-added");

		assert_true("new" in added);
		assert_false("extra" in added);
		assert_false("one" in added);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_image_uses_gitgs_image_view()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, false, 8, 4, 4);
		pixbuf.fill((uint32)0xff0000ffU);

		uint8[] png;
		pixbuf.save_to_buffer(out png, "png");
		repo.commit_bytes("image", "dot.png", png);

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "image");

		assert_cmpint(find_named(window.history.diff_view, "GitgDiffViewFileRendererImage").length, CompareOperator.EQ, 1);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_details_are_gitgs()
{
	try
	{
		var repo = Repo.create();
		repo.commit("one line", "a");
		repo.git({"checkout", "--quiet", "-b", "side"});
		repo.commit("side", "c");
		repo.checkout("master");
		repo.commit("more", "a", "x\ny");
		repo.merge("side");

		var window = opened(repo, {"refs/heads/master", "refs/heads/side"});

		select_subject(window, "more");

		var details = find_named(window, "GitgDiffViewCommitDetails")[0];

		foreach (var widget in find_all(details, typeof(Gtk.Label)))
		{
			var label = (Gtk.Label)widget;

			if (label.get_mapped())
			{
				assert_false(label.get_text() == "Parent" || label.get_text() == "Parents" || label.get_text() == "Refs");
				assert_false("changed," in label.get_text());
			}
		}

		select_subject(window, "Merge branch 'side'");

		var choices = 0;

		foreach (var widget in find_all(details, typeof(Gtk.RadioButton)))
		{
			if (widget.get_mapped())
			{
				choices++;
			}
		}

		assert_cmpint(choices, CompareOperator.EQ, 2);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_details_survive_bytes_that_are_not_utf8()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.commit_bytes("latin one", "latin.txt", "caf\xe9 au lait\n".data);

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "latin one");

		var text = source_text(window);

		assert_true(text.validate());
		assert_true("au lait" in text);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_diff_is_limited_to_the_paths()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first", "sub/a");
		repo.git({"checkout", "--quiet", "-b", "side"});
		FileUtils.set_contents(repo.path.get_child("sub").get_child("a").get_path(), "changed\n");
		FileUtils.set_contents(repo.path.get_child("b").get_path(), "other\n");
		repo.git({"add", "--all"});
		repo.git({"commit", "--quiet", "-m", "both"});

		var window = opened(repo, {"refs/heads/side"}, {"sub"});

		select_subject(window, "both");

		var names = headers(window);

		assert_cmpint(names.length, CompareOperator.EQ, 1);
		assert_true("sub/a" in names[0]);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_diff_is_limited_to_the_paths_from_a_subfolder()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first", "sub/a");
		repo.git({"checkout", "--quiet", "-b", "side"});
		FileUtils.set_contents(repo.path.get_child("sub").get_child("a").get_path(), "changed\n");
		FileUtils.set_contents(repo.path.get_child("a").get_path(), "other\n");
		repo.git({"add", "--all"});
		repo.git({"commit", "--quiet", "-m", "both"});

		var window = opened(repo, {"refs/heads/side"}, {"a"}, repo.path.get_child("sub"));

		select_subject(window, "both");

		var names = headers(window);

		assert_cmpint(names.length, CompareOperator.EQ, 1);
		assert_true("sub/a" in names[0]);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_diff_names_renames_and_binary_files()
{
	try
	{
		var repo = Repo.create();
		repo.commit("start", "old name", "some text that stays the same\nand more\n");
		repo.git({"mv", "old name", "new name"});
		repo.git({"commit", "--quiet", "-m", "rename"});
		repo.commit_bytes("binary", "blob.bin", { 0, 1, 2, 3, 0, 255, 254 });

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "rename");
		assert_cmpstr(string.joinv("|", headers(window)), CompareOperator.EQ, "new name ← old name");

		select_subject(window, "binary");
		assert_cmpint(find_named(window.history.diff_view, "GitgDiffViewFileRendererBinary").length, CompareOperator.EQ, 1);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_file_names_with_spaces_or_quotes_are_read_whole()
{
	try
	{
		var repo = Repo.create();
		repo.commit("odd names", "with space \"and\" quote's.txt");

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "odd names");
		assert_cmpstr(string.joinv("|", headers(window)), CompareOperator.EQ, "with space \"and\" quote's.txt");

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_known_language_is_highlighted()
{
	try
	{
		var repo = Repo.create();
		repo.commit("c file", "main.c", "int main(void) { return 0; }");

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "c file");

		var views = find_all(window.history.diff_view, typeof(Gtk.SourceView));

		assert_true(views.length > 0);

		var coloured = false;

		foreach (var view in views)
		{
			var buffer = ((Gtk.SourceView)view).buffer;
			Gtk.TextIter iter;

			buffer.get_start_iter(out iter);

			do
			{
				foreach (var tag in iter.get_tags())
				{
					coloured = coloured || tag.foreground_set;
				}
			}
			while (iter.forward_char());
		}

		assert_true(coloured);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_line_numbers_follow_the_hunk_header()
{
	try
	{
		var repo = Repo.create();
		var lines = new StringBuilder();

		for (var n = 1; n <= 30; n++)
		{
			lines.append_printf("line %d\n", n);
		}

		repo.commit("thirty", "f", lines.str.strip());
		FileUtils.set_contents(repo.path.get_child("f").get_path(), lines.str.replace("line 20\n", "line twenty\n"));
		repo.git({"commit", "--quiet", "-am", "change twenty"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "change twenty");

		assert_true("@@ -17,7 +17,7 @@" in source_text(window));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_orientation_follows_the_layout_setting()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		var settings = new Settings(Gitree.Config.APPLICATION_ID + ".preferences.interface");
		var window = opened(repo, {"refs/heads/master"});
		var panels = window.history.paned.paned_panels;

		assert_true(panels.orientation == Gtk.Orientation.VERTICAL);
		assert_true(panels.get_child1() == window.history.paned.stack_list);

		settings.set_string("orientation", "horizontal");
		settle(50);

		assert_true(panels.orientation == Gtk.Orientation.HORIZONTAL);
		assert_true(panels.get_child2() == window.history.paned.stack_list);

		settings.reset("orientation");
		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_sections_start_folded_when_there_are_several()
{
	try
	{
		var repo = Repo.create();
		repo.commit("one file", "a");
		FileUtils.set_contents(repo.path.get_child("b").get_path(), "b\n");
		FileUtils.set_contents(repo.path.get_child("c").get_path(), "c\n");
		repo.git({"add", "--all"});
		repo.git({"commit", "--quiet", "-m", "two files"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "one file");

		foreach (var file in find_named(window.history.diff_view, "GitgDiffViewFile"))
		{
			bool expanded;
			file.get("expanded", out expanded);
			assert_true(expanded);
		}

		select_subject(window, "two files");

		var files = find_named(window.history.diff_view, "GitgDiffViewFile");

		assert_cmpint(files.length, CompareOperator.EQ, 2);

		foreach (var file in files)
		{
			bool expanded;
			file.get("expanded", out expanded);
			assert_false(expanded);
		}

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_split_sides_scroll_together()
{
	try
	{
		var repo = Repo.create();
		var wide = string.nfill(400, 'a');
		repo.commit("start", "f", wide + " one");
		FileUtils.set_contents(repo.path.get_child("f").get_path(), wide + " two " + wide + "\n");
		repo.git({"commit", "--quiet", "-am", "widen"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "widen");

		foreach (var widget in find_all(window.history.diff_view, typeof(Gtk.ToggleButton)))
		{
			var toggle = (Gtk.ToggleButton)widget;

			if (toggle.label == "Split")
			{
				toggle.active = true;
			}
		}

		settle(300);

		var split = find_named(window.history.diff_view, "GitgDiffViewFileRendererTextSplit")[0];
		var sides = find_all(split, typeof(Gtk.ScrolledWindow));
		var left = ((Gtk.ScrolledWindow)sides[0]).hadjustment;
		var right = ((Gtk.ScrolledWindow)sides[1]).hadjustment;

		assert_cmpfloat(left.upper - left.page_size, CompareOperator.GT, 200);
		assert_cmpfloat(right.upper - right.page_size, CompareOperator.GT, 200);

		left.value = 150;
		assert_cmpfloat(right.value, CompareOperator.EQ, 150);

		right.value = 40;
		assert_cmpfloat(left.value, CompareOperator.EQ, 40);

		var end = right.upper - right.page_size;
		assert_cmpfloat(end, CompareOperator.GT, left.upper - left.page_size);

		right.value = end;
		assert_cmpfloat(right.value, CompareOperator.EQ, end);
		assert_cmpfloat(left.value, CompareOperator.EQ, left.upper - left.page_size);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_ticking_nothing_clears_the_details()
{
	try
	{
		var repo = Repo.create();
		repo.branched();

		var window = opened(repo, {"refs/heads/master"});

		assert_nonnull(window.history.diff_view.commit);

		window.history.set_ticks(new Gee.HashSet<string>());
		settle(100);

		assert_null(window.history.diff_view.commit);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_word_mark_colours()
{
	try
	{
		var repo = Repo.create();
		repo.commit("start", "f", "alpha beta gamma");
		FileUtils.set_contents(repo.path.get_child("f").get_path(), "alpha BETA gamma\n");
		repo.git({"commit", "--quiet", "-am", "shout"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "shout");

		var checked = 0;

		foreach (var widget in find_all(window.history.diff_view, typeof(Gtk.SourceView)))
		{
			var table = ((Gtk.SourceView)widget).buffer.tag_table;
			var added = table.lookup("word-added");
			var removed = table.lookup("word-removed");

			if (added == null || removed == null)
			{
				continue;
			}

			assert_cmpstr(added.background_rgba.to_string(), CompareOperator.EQ, "rgb(168,240,168)");
			assert_cmpstr(removed.background_rgba.to_string(), CompareOperator.EQ, "rgb(255,176,176)");
			checked++;
		}

		assert_true(checked > 0);

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_word_marks_in_both_views()
{
	try
	{
		var repo = Repo.create();
		repo.commit("start", "f", "the quick brown fox jumps");
		FileUtils.set_contents(repo.path.get_child("f").get_path(), "the quick red fox jumps\n");
		repo.git({"commit", "--quiet", "-am", "recolour"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "recolour");

		var views = 0;

		foreach (var widget in find_all(window.history.diff_view, typeof(Gtk.SourceView)))
		{
			var buffer = ((Gtk.SourceView)widget).buffer;

			if (buffer.tag_table.lookup("word-added") != null || buffer.tag_table.lookup("word-removed") != null)
			{
				views++;
			}
		}

		assert_true(views >= 2);
		assert_true("brown" in marked_words(window, "word-removed"));
		assert_true("red" in marked_words(window, "word-added"));
		assert_false("quick" in marked_words(window, "word-added"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_word_marks_reach_across_a_no_newline_marker()
{
	try
	{
		var repo = Repo.create();
		repo.commit("start");
		FileUtils.set_contents(repo.path.get_child("end").get_path(), "old end");
		repo.git({"add", "end"});
		repo.git({"commit", "--quiet", "-m", "old"});
		FileUtils.set_contents(repo.path.get_child("end").get_path(), "new end");
		repo.git({"commit", "--quiet", "-am", "new"});

		var window = opened(repo, {"refs/heads/master"});

		select_subject(window, "new");

		assert_true("new" in marked_words(window, "word-added"));
		assert_true("old" in marked_words(window, "word-removed"));

		window.destroy();
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
