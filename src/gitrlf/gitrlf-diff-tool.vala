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

namespace Gitrlf
{

public class DiffTool : Object
{
	private static async void compare(Gitg.Repository repository,
	                                  File directory,
	                                  Ggit.Commit? before,
	                                  Ggit.Commit after,
	                                  Ggit.DiffDelta[] deltas,
	                                  bool folders) throws Error
	{
		var top = File.new_for_path(DirUtils.make_tmp("gitrlf-XXXXXX"));
		var left = top.get_child(before != null ? short_id(before) : "empty");
		var right = top.get_child(short_id(after));
		var local = left;
		var remote = right;

		left.make_directory();
		right.make_directory();

		foreach (var delta in deltas)
		{
			local = save(repository, delta.get_old_file(), left, folders);
			remote = save(repository, delta.get_new_file(), right, folders);
		}

		seal(top);

		var launcher = new SubprocessLauncher(SubprocessFlags.NONE);

		launcher.set_cwd(directory.get_path());
		launcher.setenv("GIT_DIFFTOOL_DIRDIFF", "true", true);

		var process = launcher.spawnv({
			"git", "difftool--helper",
			(folders ? left : local).get_path(),
			(folders ? right : remote).get_path()
		});

		yield process.wait_async();
		remove(top);
	}

	public static async void compare_commit(Gitg.Repository repository,
	                                        File directory,
	                                        Gitg.Commit commit) throws Error
	{
		var diff = commit.get_diff(null, 0);
		var deltas = new Ggit.DiffDelta[0];

		for (size_t i = 0; i < diff.get_num_deltas(); i++)
		{
			deltas += diff.get_delta(i);
		}

		yield compare(repository, directory, commit.get_parents()[0], commit,
		              deltas, true);
	}

	public static async void compare_file(Gitg.Repository repository,
	                                      File directory,
	                                      Ggit.Commit? before,
	                                      Ggit.Commit after,
	                                      Ggit.DiffDelta delta) throws Error
	{
		yield compare(repository, directory, before, after, { delta }, false);
	}

	private static void remove(File file) throws Error
	{
		var type = file.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

		if (type == FileType.DIRECTORY)
		{
			FileUtils.chmod(file.get_path(), 0700);

			var children = file.enumerate_children(
				"standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
			FileInfo? info;

			while ((info = children.next_file()) != null)
			{
				remove(file.get_child(info.get_name()));
			}
		}

		FileUtils.remove(file.get_path());
	}

	private static File save(Gitg.Repository repository, Ggit.DiffFile file,
	                         File side, bool folders) throws Error
	{
		var target = side.get_child(file.get_path());
		var oid = file.get_oid();

		if (oid.is_zero() && folders)
		{
			return target;
		}

		DirUtils.create_with_parents(target.get_parent().get_path(), 0755);

		if (oid.is_zero())
		{
			FileUtils.set_contents_full(target.get_path(), "", 0,
			                            FileSetContentsFlags.NONE, 0444);
		}
		else
		{
			var blob = repository.lookup<Ggit.Blob>(oid);
			var data = blob.get_raw_content();

			FileUtils.set_contents_full(target.get_path(), (string)data,
			                            data.length,
			                            FileSetContentsFlags.NONE, 0444);
		}

		return target;
	}

	private static void seal(File folder) throws Error
	{
		var children = folder.enumerate_children(
			"standard::name,standard::type",
			FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
		FileInfo? info;

		while ((info = children.next_file()) != null)
		{
			if (info.get_file_type() == FileType.DIRECTORY)
			{
				seal(folder.get_child(info.get_name()));
			}
		}

		FileUtils.chmod(folder.get_path(), 0555);
	}

	private static string short_id(Ggit.Commit commit)
	{
		return commit.get_id().to_string().substring(0, 7);
	}
}

}
