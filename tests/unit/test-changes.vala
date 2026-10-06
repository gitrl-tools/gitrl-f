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

private static string files(Ggit.Diff diff)
{
	var names = new string[0];

	for (size_t i = 0; i < diff.get_num_deltas(); i++)
	{
		var delta = diff.get_delta(i);

		names += "%s %s".printf(delta.get_status().to_string(),
		                        delta.get_new_file().get_path());
	}

	return string.joinv(",", names);
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/changes/a-new-file-counts-as-unstaged",
	              test_a_new_file_counts_as_unstaged);
	Test.add_func("/gitrlf/changes/an-edit-to-a-new-file-changes-the-key",
	              test_an_edit_to_a_new_file_changes_the_key);
	Test.add_func("/gitrlf/changes/staged-and-unstaged-are-apart",
	              test_staged_and_unstaged_are_apart);
	Test.add_func("/gitrlf/changes/staging-later-shows-on-the-next-read",
	              test_staging_later_shows_on_the_next_read);
	Test.add_func("/gitrlf/changes/the-key-holds-while-nothing-changes",
	              test_the_key_holds_while_nothing_changes);

	return Test.run();
}

private static Gitg.Repository open(Repo repo) throws Error
{
	return Gitrlf.Repository.open(
		Gitrlf.Application.discover_repository(repo.path));
}

private static void write(Repo repo, string name, string text) throws Error
{
	FileUtils.set_contents(repo.path.get_child(name).get_path(), text);
}

private static void test_a_new_file_counts_as_unstaged()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");
		write(repo, "fresh", "new\n");

		var repository = open(repo);

		assert_cmpstr(files(Gitrlf.Changes.staged(repository, 3)),
		              CompareOperator.EQ, "");
		assert_cmpstr(files(Gitrlf.Changes.unstaged(repository, 3)),
		              CompareOperator.EQ, "GGIT_DELTA_UNTRACKED fresh");
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_edit_to_a_new_file_changes_the_key()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");
		write(repo, "fresh", "aaa\n");

		var repository = open(repo);
		var before = Gitrlf.Changes.key(repository,
		                                Gitrlf.Changes.unstaged(repository, 3));
		var fresh = repo.path.get_child("fresh");

		write(repo, "fresh", "bbb\n");
		fresh.set_attribute_uint64(FileAttribute.TIME_MODIFIED,
		                           get_real_time() / 1000000 + 5,
		                           FileQueryInfoFlags.NONE);

		var after = Gitrlf.Changes.key(repository,
		                               Gitrlf.Changes.unstaged(repository, 3));

		assert_cmpstr(after, CompareOperator.NE, before);
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_staged_and_unstaged_are_apart()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");
		repo.commit("two", "other");
		write(repo, "notes", "staged\n");
		repo.git({"add", "notes"});
		write(repo, "other", "edited\n");

		var repository = open(repo);

		assert_cmpstr(files(Gitrlf.Changes.staged(repository, 3)),
		              CompareOperator.EQ, "GGIT_DELTA_MODIFIED notes");
		assert_cmpstr(files(Gitrlf.Changes.unstaged(repository, 3)),
		              CompareOperator.EQ, "GGIT_DELTA_MODIFIED other");
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_staging_later_shows_on_the_next_read()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");

		var repository = open(repo);

		assert_cmpstr(files(Gitrlf.Changes.staged(repository, 3)),
		              CompareOperator.EQ, "");

		write(repo, "notes", "staged\n");
		repo.git({"add", "notes"});

		assert_cmpstr(files(Gitrlf.Changes.staged(repository, 3)),
		              CompareOperator.EQ, "GGIT_DELTA_MODIFIED notes");
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_the_key_holds_while_nothing_changes()
{
	try
	{
		var repo = Repo.create();

		repo.commit("one", "notes");
		write(repo, "notes", "edited\n");
		write(repo, "fresh", "new\n");

		var repository = open(repo);
		var first = Gitrlf.Changes.key(repository,
		                               Gitrlf.Changes.unstaged(repository, 3));
		var second = Gitrlf.Changes.key(repository,
		                                Gitrlf.Changes.unstaged(repository, 3));

		assert_cmpstr(first, CompareOperator.NE, "");
		assert_cmpstr(second, CompareOperator.EQ, first);
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
