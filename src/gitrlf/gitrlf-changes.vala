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

public class Changes : Object
{
	public static string key(Gitg.Repository repository,
	                         Ggit.Diff diff) throws Error
	{
		var text = new StringBuilder();

		for (size_t i = 0; i < diff.get_num_deltas(); i++)
		{
			var delta = diff.get_delta(i);
			var old_file = delta.get_old_file();
			var new_file = delta.get_new_file();

			text.append_printf("%d %s %s %s %s", (int)delta.get_status(),
			                   old_file.get_path(),
			                   old_file.get_oid().to_string(),
			                   new_file.get_path(),
			                   new_file.get_oid().to_string());

			if ((new_file.get_flags() & Ggit.DiffFlag.VALID_ID) == 0
			    && delta.get_status() != Ggit.DeltaType.DELETED)
			{
				var path = new_file.get_path();
				var info = repository.get_workdir().get_child(path).query_info(
					"time::modified,time::modified-usec,standard::size",
					FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				var seconds = info.get_attribute_uint64("time::modified");
				var micro = info.get_attribute_uint32("time::modified-usec");

				text.append_printf(" %llu.%u %lld", seconds, micro,
				                   info.get_size());
			}

			text.append("\n");
		}

		return text.str;
	}

	private static Ggit.DiffOptions options(int context)
	{
		var options = new Ggit.DiffOptions();

		options.n_context_lines = context;

		return options;
	}

	public static Ggit.Diff staged(Gitg.Repository repository,
	                               int context) throws Error
	{
		var head = repository.lookup<Ggit.Commit>(
			repository.get_head().get_target());

		return new Ggit.Diff.tree_to_index(repository, head.get_tree(), null,
		                                   options(context));
	}

	public static Ggit.Diff unstaged(Gitg.Repository repository,
	                                 int context) throws Error
	{
		var options = options(context);

		options.flags = Ggit.DiffOption.INCLUDE_UNTRACKED
		                | Ggit.DiffOption.RECURSE_UNTRACKED_DIRS
		                | Ggit.DiffOption.SHOW_UNTRACKED_CONTENT;

		return new Ggit.Diff.index_to_workdir(repository, null, options);
	}
}

}
