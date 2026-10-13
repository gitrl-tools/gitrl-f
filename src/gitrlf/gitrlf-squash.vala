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

public class Squash : Object
{
	private Gitg.Repository d_repository;
	private Gitg.Repository? d_store;

	public Squash(Gitg.Repository repository)
	{
		d_repository = repository;
	}

	public Ggit.Diff diff(Gitg.Commit[] picked,
	                      Ggit.DiffOptions? options) throws Error
	{
		var store = open();
		var favour = new Ggit.MergeOptions();
		var before = tree_of(store, picked[picked.length - 1].get_parents()[0]);
		var tree = before;

		favour.set_file_favor(Ggit.MergeFileFavor.THEIRS);

		for (var i = picked.length - 1; i >= 0; i--)
		{
			var parent = tree_of(store, picked[i].get_parents()[0]);
			var own = tree_of(store, picked[i]);

			if (parent.get_id().equal(tree.get_id()))
			{
				tree = own;
			}
			else
			{
				var index = store.merge_trees(parent, tree, own, favour);

				tree = store.lookup<Ggit.Tree>(index.write_tree_to(store));
			}
		}

		var diff = new Ggit.Diff.tree_to_tree(store, before, tree, options);

		diff.find_similar(null);

		return diff;
	}

	public Gitg.Repository open() throws Error
	{
		if (d_store == null)
		{
			var location = File.new_for_path(DirUtils.make_tmp("gitrlf-XXXXXX"));
			var objects = History.git(d_repository.get_location(), {
				"rev-parse", "--path-format=absolute", "--git-path", "objects"
			}, null)[0];
			var workdir = d_repository.get_workdir();

			Ggit.Repository.init_repository(location, true);
			FileUtils.set_contents(location.resolve_relative_path(
				"objects/info/alternates").get_path(), objects + "\n");
			d_store = new Gitg.Repository(location, null);

			if (workdir != null)
			{
				d_store.set_workdir(workdir, false);
			}
		}

		return d_store;
	}

	public void remove()
	{
		if (d_store == null)
		{
			return;
		}

		try
		{
			DiffTool.remove(d_store.get_location());
		}
		catch (Error e)
		{
		}

		d_store = null;
	}

	private Ggit.Tree tree_of(Gitg.Repository store,
	                          Ggit.Commit? commit) throws Error
	{
		var id = commit != null ? commit.get_tree_id()
		                        : store.create_tree_builder().write();

		return store.lookup<Ggit.Tree>(id);
	}
}

}
