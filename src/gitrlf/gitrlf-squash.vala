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

[CCode (cname = "flock", cheader_filename = "sys/file.h")]
extern int flock(int fd, int operation);

[CCode (cname = "LOCK_EX", cheader_filename = "sys/file.h")]
extern const int LOCK_EX;

[CCode (cname = "LOCK_NB", cheader_filename = "sys/file.h")]
extern const int LOCK_NB;

public class Squash : Object
{
	private const string STORE = "store-";

	private class Entry
	{
		public Ggit.OId? id;
		public Ggit.FileMode mode;

		public Entry(Ggit.OId? id, Ggit.FileMode mode)
		{
			this.id = id;
			this.mode = mode;
		}

		public Entry.at(Ggit.TreeEntry? entry)
		{
			this(entry != null ? entry.get_id() : null,
			     entry != null ? entry.get_file_mode() : Ggit.FileMode.BLOB);
		}

		public bool same(Entry other)
		{
			if (id == null || other.id == null)
			{
				return id == other.id;
			}

			return id.equal(other.id) && mode == other.mode;
		}
	}

	private class Step
	{
		public string path;
		public Entry was;
		public Entry will;

		public Step(string path, Entry was, Entry will)
		{
			this.path = path;
			this.was = was;
			this.will = will;
		}
	}

	private int d_hold = -1;
	private Gitg.Repository d_repository;
	private Gitg.Repository? d_store;

	public Squash(Gitg.Repository repository)
	{
		d_repository = repository;
	}

	public static File folder()
	{
		return File.new_for_path(Environment.get_user_runtime_dir())
			.get_child("gitrlf");
	}

	private static Ggit.OId build(Gitg.Repository store, Ggit.Tree? tree,
	                              Gee.Map<string, Entry> changes) throws Error
	{
		var builder = tree != null ? store.create_tree_builder_from_tree(tree)
		                           : store.create_tree_builder();
		var folders = new Gee.HashMap<string, Gee.HashMap<string, Entry>>();

		foreach (var change in changes.entries)
		{
			var slash = change.key.index_of_char('/');

			if (slash >= 0)
			{
				var name = change.key.substring(0, slash);

				if (!folders.has_key(name))
				{
					folders[name] = new Gee.HashMap<string, Entry>();
				}

				folders[name][change.key.substring(slash + 1)] = change.value;
			}
			else if (change.value.id != null)
			{
				builder.insert(change.key, change.value.id, change.value.mode);
			}
			else if (builder.get_entry(change.key) != null)
			{
				builder.remove(change.key);
			}
		}

		foreach (var folder in folders.entries)
		{
			var entry = builder.get_entry(folder.key);
			var tree_entry = entry != null
			                 && entry.get_file_mode() == Ggit.FileMode.TREE;
			var inner = tree_entry ? store.lookup<Ggit.Tree>(entry.get_id())
			                       : null;
			var id = build(store, inner, folder.value);

			if (store.lookup<Ggit.Tree>(id).size() > 0)
			{
				builder.insert(folder.key, id, Ggit.FileMode.TREE);
			}
			else if (inner != null)
			{
				builder.remove(folder.key);
			}
		}

		return builder.write();
	}

	private static void changed(Gitg.Repository store, string path,
	                            Ggit.TreeEntry? was, Ggit.TreeEntry? will,
	                            Gee.List<Step> steps) throws Error
	{
		var was_tree = was != null && was.get_file_mode() == Ggit.FileMode.TREE;
		var will_tree = will != null
		                && will.get_file_mode() == Ggit.FileMode.TREE;

		if (was_tree || will_tree)
		{
			compare(store,
			        was_tree ? store.lookup<Ggit.Tree>(was.get_id()) : null,
			        will_tree ? store.lookup<Ggit.Tree>(will.get_id()) : null,
			        path + "/", steps);
		}

		var file_was = was_tree ? null : was;
		var file_will = will_tree ? null : will;

		if (file_was != null || file_will != null)
		{
			steps.add(new Step(path, new Entry.at(file_was),
			                   new Entry.at(file_will)));
		}
	}

	private static void clear(File top) throws Error
	{
		var children = top.enumerate_children(
			"standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
		FileInfo? info;

		while ((info = children.next_file()) != null)
		{
			var store = top.get_child(info.get_name());

			if (!info.get_name().has_prefix(STORE))
			{
				continue;
			}

			var hold = hold(store);

			if (flock(hold, LOCK_EX | LOCK_NB) == 0)
			{
				discard(store);
			}

			Posix.close(hold);
		}
	}

	private static void compare(Gitg.Repository store, Ggit.Tree? was,
	                            Ggit.Tree? will, string prefix,
	                            Gee.List<Step> steps) throws Error
	{
		for (uint i = 0; was != null && i < was.size(); i++)
		{
			var old = was.get(i);
			var now = will != null ? will.get_by_name(old.get_name()) : null;

			if (now == null || !old.get_id().equal(now.get_id())
			    || old.get_file_mode() != now.get_file_mode())
			{
				changed(store, prefix + old.get_name(), old, now, steps);
			}
		}

		for (uint i = 0; will != null && i < will.size(); i++)
		{
			var now = will.get(i);

			if (was == null || was.get_by_name(now.get_name()) == null)
			{
				changed(store, prefix + now.get_name(), null, now, steps);
			}
		}
	}

	public Ggit.Diff diff(Gitg.Commit[] picked,
	                      Ggit.DiffOptions? options) throws Error
	{
		var store = open();
		var before = tree_of(store, picked[picked.length - 1].get_parents()[0]);
		var changes = new Gee.HashMap<string, Entry>();

		for (var i = picked.length - 1; i >= 0; i--)
		{
			var steps = new Gee.ArrayList<Step>();

			compare(store, tree_of(store, picked[i].get_parents()[0]),
			        tree_of(store, picked[i]), "", steps);

			foreach (var step in steps)
			{
				var now = changes.has_key(step.path)
					? changes[step.path] : entry_at(before, step.path);

				changes[step.path] = replay(store, now, step.was, step.will);
			}
		}

		var after = store.lookup<Ggit.Tree>(build(store, before, changes));
		var diff = new Ggit.Diff.tree_to_tree(store, before, after, options);

		diff.find_similar(null);

		return diff;
	}

	private static void discard(File location)
	{
		try
		{
			DiffTool.remove(location);
		}
		catch (Error e)
		{
		}
	}

	private static int hold(File store)
	{
		return Posix.open(store.get_path(), Posix.O_RDONLY | Posix.O_DIRECTORY);
	}

	private static Entry entry_at(Ggit.Tree tree, string path)
	{
		try
		{
			return new Entry.at(tree.get_by_path(path));
		}
		catch (Error e)
		{
			return new Entry.at(null);
		}
	}

	private static void include(File config, string path) throws Error
	{
		string own;
		var quoted = path.replace("\\", "\\\\").replace("\"", "\\\"");

		FileUtils.get_contents(config.get_path(), out own);
		FileUtils.set_contents(config.get_path(),
		                       "[include]\n\tpath = \"%s\"\n%s".printf(quoted,
		                                                              own));
	}

	private static Entry merged(Gitg.Repository store, Entry was, Entry now,
	                            Entry will) throws Error
	{
		var favour = new Ggit.MergeOptions();

		favour.set_file_favor(Ggit.MergeFileFavor.THEIRS);

		var index = store.merge_trees(single(store, was), single(store, now),
		                              single(store, will), favour);

		if (index.has_conflicts())
		{
			return will;
		}

		var entry = index.get_entries().get_by_index(0);

		return new Entry(entry.get_id(), (Ggit.FileMode)entry.get_mode());
	}

	public Gitg.Repository open() throws Error
	{
		if (d_store == null)
		{
			var paths = History.git(d_repository.get_location(), {
				"rev-parse", "--path-format=absolute", "--git-path", "objects",
				"--git-path", "config", "--git-path", "info/attributes"
			}, null);
			var workdir = d_repository.get_workdir();
			var top = folder();

			DirUtils.create_with_parents(top.get_path(), 0700);

			var all = Posix.open(top.get_child("lock").get_path(),
			                     Posix.O_RDWR | Posix.O_CREAT, 0600);
			var location = top.get_child(STORE + Uuid.string_random());

			flock(all, LOCK_EX);

			try
			{
				clear(top);
				location.make_directory();
				d_hold = hold(location);
				flock(d_hold, LOCK_EX);
			}
			finally
			{
				Posix.close(all);
			}

			Ggit.Repository.init_repository(location, true);
			FileUtils.set_contents(location.resolve_relative_path(
				"objects/info/alternates").get_path(), paths[0] + "\n");
			include(location.get_child("config"), paths[1]);
			DirUtils.create_with_parents(
				location.get_child("info").get_path(), 0700);
			FileUtils.symlink(paths[2], location.resolve_relative_path(
				"info/attributes").get_path());
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

		discard(d_store.get_location());
		Posix.close(d_hold);
		d_hold = -1;
		d_store = null;
	}

	private static Entry replay(Gitg.Repository store, Entry now, Entry was,
	                            Entry will) throws Error
	{
		if (now.same(was) || now.id == null || was.id == null
		    || will.id == null)
		{
			return will;
		}

		return merged(store, was, now, will);
	}

	private static Ggit.Tree single(Gitg.Repository store,
	                                Entry entry) throws Error
	{
		var builder = store.create_tree_builder();

		builder.insert("f", entry.id, entry.mode);

		return store.lookup<Ggit.Tree>(builder.write());
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
