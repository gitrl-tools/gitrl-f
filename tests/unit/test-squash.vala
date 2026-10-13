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

private static int gone_process() throws Error
{
	var process = new Subprocess.newv({"true"}, SubprocessFlags.NONE);
	var pid = int.parse(process.get_identifier());

	process.wait();

	return pid;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/squash/a-store-of-a-gone-process-is-cleared", test_a_store_of_a_gone_process_is_cleared);

	return Test.run();
}

private static File store_of(int pid) throws Error
{
	return File.new_for_path(DirUtils.make_tmp(
		"%s%d-XXXXXX".printf(Gitrlf.Squash.PREFIX, pid)));
}

private static void test_a_store_of_a_gone_process_is_cleared()
{
	try
	{
		var repo = Repo.create();
		var gone = store_of(gone_process());
		var live = store_of(Posix.getpid());
		var squash = new Gitrlf.Squash(Gitrlf.Repository.open(
			Gitrlf.Application.discover_repository(repo.path)));

		squash.open();

		assert_false(gone.query_exists());
		assert_true(live.query_exists());

		squash.remove();
		DirUtils.remove(live.get_path());
		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
