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

public class CommitFiles : Object
{
	private static Gee.HashMap<string, File>? s_copies;

	public static File copy(Gitg.Repository repository,
	                        Gitg.Commit commit) throws Error
	{
		var id = commit.get_id().to_string();

		if (s_copies == null)
		{
			s_copies = new Gee.HashMap<string, File>();
		}

		if (s_copies.has_key(id))
		{
			return s_copies[id];
		}

		var top = File.new_for_path(DirUtils.make_tmp("gitrlf-XXXXXX"));
		var folder = top.get_child(DiffTool.label(commit));

		folder.make_directory();
		save(repository, commit.get_tree(), folder);
		DiffTool.seal(top);
		s_copies[id] = folder;

		return folder;
	}

	private static void save(Gitg.Repository repository, Ggit.Tree tree,
	                         File folder) throws Error
	{
		for (uint i = 0; i < tree.size(); i++)
		{
			var entry = tree.get(i);
			var target = folder.get_child(entry.get_name());
			var type = entry.get_object_type();

			if (type == typeof(Ggit.Blob))
			{
				var blob = repository.lookup<Ggit.Blob>(entry.get_id());

				DiffTool.write(target, blob.get_raw_content());
			}
			else
			{
				target.make_directory();
			}

			if (type == typeof(Ggit.Tree))
			{
				save(repository, repository.lookup<Ggit.Tree>(entry.get_id()),
				     target);
			}
		}
	}
}

}
