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
 */

namespace Gittree
{

public class History : Object
{
	private Gitg.Commit[] d_commits;
	private Gee.HashMap<Ggit.OId, int> d_index;
	private Gitg.Lanes d_lanes;
	private int[] d_parents;
	private int[] d_parents_start;
	private Gee.HashMap<Ggit.OId, Ggit.OId?> d_starts;

	public int size
	{
		get { return d_commits.length; }
	}

	public History(Gitg.Repository repository, Gee.List<Ref> refs, bool topological) throws Error
	{
		var walker = new Ggit.RevisionWalker(repository);
		walker.set_sort_mode(topological ? Ggit.SortMode.TOPOLOGICAL : Ggit.SortMode.TOPOLOGICAL | Ggit.SortMode.TIME);

		var pushed = id_set();

		foreach (var reference in refs)
		{
			if (pushed.add(reference.target))
			{
				walker.push(reference.target);
			}
		}

		begin();

		Ggit.OId? id;
		var parents = new Ggit.OId[0];
		var counts = new int[0];

		while ((id = walker.next()) != null)
		{
			var commit = repository.lookup<Gitg.Commit>(id);
			var commit_parents = commit.get_parents();

			add(commit);

			for (uint j = 0; j < commit_parents.size; j++)
			{
				parents += commit_parents.get_id(j);
			}

			counts += (int)commit_parents.size;
		}

		index_parents(parents, counts);
		d_lanes = new Gitg.Lanes();
	}

	public History.with_paths(Gitg.Repository repository, Gee.List<Ref> refs, string[] paths, File directory, bool topological) throws Error
	{
		var tips = new Gee.ArrayList<string>();
		var pushed = id_set();

		foreach (var reference in refs)
		{
			if (pushed.add(reference.target))
			{
				tips.add(reference.target.to_string());
			}
		}

		string[] log = { "log", "-z", "--parents", topological ? "--topo-order" : "--date-order", "--stdin", "--format=%H%x1f%P", "--" };

		foreach (var path in paths)
		{
			log += path;
		}

		var records = git(directory, log, string.joinv("\n", tips.to_array()) + "\n");

		begin();

		var parents = new Ggit.OId[0];
		var counts = new int[0];

		foreach (var record in records)
		{
			var fields = record.split("\x1f");

			if (fields.length < 2 || fields[0] == "")
			{
				continue;
			}

			add(repository.lookup<Gitg.Commit>(new Ggit.OId.from_string(fields[0])));

			var count = 0;

			foreach (var parent in fields[1].split(" "))
			{
				if (parent != "")
				{
					parents += new Ggit.OId.from_string(parent);
					count++;
				}
			}

			counts += count;
		}

		index_parents(parents, counts);

		foreach (var tip in tips)
		{
			var id = new Ggit.OId.from_string(tip);

			if (d_index.has_key(id))
			{
				continue;
			}

			string[] rev_list = { "rev-list", "-1", tip, "--" };

			foreach (var path in paths)
			{
				rev_list += path;
			}

			var found = git(directory, rev_list, null);
			d_starts[id] = found.length > 0 && found[0] != "" ? new Ggit.OId.from_string(found[0]) : null;
		}

		d_lanes = new Gitg.Lanes();
		d_lanes.set_parents_func(parents_of);
	}

	private void add(Gitg.Commit commit)
	{
		d_index[commit.get_id()] = d_commits.length;
		d_commits += commit;
	}

	private void begin()
	{
		d_commits = new Gitg.Commit[0];
		d_index = id_map<int>();
		d_starts = id_map<Ggit.OId?>();
	}

	private static string[] git(File directory, string[] arguments, string? input) throws Error
	{
		string[] argv = { "git" };

		foreach (var argument in arguments)
		{
			argv += argument;
		}

		var flags = SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE;

		if (input != null)
		{
			flags |= SubprocessFlags.STDIN_PIPE;
		}

		var launcher = new SubprocessLauncher(flags);
		launcher.set_cwd(directory.get_path());

		var process = launcher.spawnv(argv);

		if (input != null)
		{
			Posix.signal(Posix.Signal.PIPE, Posix.SIG_IGN);

			try
			{
				process.get_stdin_pipe().write_all(input.data, null);
			}
			catch (IOError.BROKEN_PIPE e)
			{
			}
		}

		Bytes output;
		Bytes errors;

		process.communicate(input != null ? new Bytes(null) : null, null, out output, out errors);

		if (!process.get_successful())
		{
			var data = errors.get_data();
			var message = data.length > 0 ? ((string)data).ndup(data.length).strip() : "";

			throw new IOError.FAILED("%s", message != "" ? message : _("git failed"));
		}

		var records = new string[0];
		var record = new StringBuilder();

		foreach (var b in output.get_data())
		{
			if (b == 0 || b == '\n')
			{
				records += record.str;
				record.truncate();
			}
			else
			{
				record.append_c((char)b);
			}
		}

		if (record.len > 0)
		{
			records += record.str;
		}

		return records;
	}

	public static Gee.HashMap<Ggit.OId, V> id_map<V>()
	{
		return new Gee.HashMap<Ggit.OId, V>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
		                                    (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);
	}

	public static Gee.HashSet<Ggit.OId> id_set()
	{
		return new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
		                                 (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);
	}

	private void index_parents(Ggit.OId[] parents, int[] counts)
	{
		d_parents = new int[0];
		d_parents_start = new int[d_commits.length + 1];

		var next = 0;

		for (var i = 0; i < d_commits.length; i++)
		{
			d_parents_start[i] = d_parents.length;

			for (var j = 0; j < counts[i]; j++)
			{
				var parent = parents[next++];

				if (d_index.has_key(parent))
				{
					d_parents += d_index[parent];
				}
			}
		}

		d_parents_start[d_commits.length] = d_parents.length;
	}

	public Gitg.Commit? lookup(Ggit.OId id)
	{
		return d_index.has_key(id) ? d_commits[d_index[id]] : null;
	}

	public static Ggit.OId[] mainline(Gitg.Repository repository, bool with_head)
	{
		var ids = new Ggit.OId[0];
		string[] names = {};

		try
		{
			var config = repository.get_config().snapshot();

			try
			{
				names = config.get_string("gitg.mainline").split(",");
			}
			catch
			{
				names = { "refs/heads/" + config.get_string("init.defaultBranch") };
			}
		}
		catch {}

		foreach (var name in names)
		{
			try
			{
				var id = target_of(repository.lookup_reference(name));

				if (id != null)
				{
					ids += id;
				}
			}
			catch {}
		}

		if (with_head)
		{
			try
			{
				var id = target_of(repository.lookup_reference("HEAD"));

				if (id != null)
				{
					ids += id;
				}
			}
			catch {}
		}

		var seen = id_set();
		var ret = new Ggit.OId[0];

		foreach (var id in ids)
		{
			if (seen.add(id))
			{
				ret += id;
			}
		}

		return ret;
	}

	public Ggit.OId[] parents_of(Gitg.Commit commit)
	{
		var ret = new Ggit.OId[0];

		if (!d_index.has_key(commit.get_id()))
		{
			return ret;
		}

		var i = d_index[commit.get_id()];

		for (var p = d_parents_start[i]; p < d_parents_start[i + 1]; p++)
		{
			ret += d_commits[d_parents[p]].get_id();
		}

		return ret;
	}

	public int position(Ggit.OId tip)
	{
		var id = start_of(tip);

		return id != null ? d_index[id] : int.MAX;
	}

	private void reach(int[] starts, bool first_parent_only, bool[] reached)
	{
		var stack = starts;

		while (stack.length > 0)
		{
			var i = stack[stack.length - 1];
			stack.length--;

			if (reached[i])
			{
				continue;
			}

			reached[i] = true;

			var end = first_parent_only ? int.min(d_parents_start[i] + 1, d_parents_start[i + 1])
			                            : d_parents_start[i + 1];

			for (var p = d_parents_start[i]; p < end; p++)
			{
				if (!reached[d_parents[p]])
				{
					stack += d_parents[p];
				}
			}
		}
	}

	public Ggit.OId? start_of(Ggit.OId tip)
	{
		if (d_index.has_key(tip))
		{
			return tip;
		}

		return d_starts.has_key(tip) ? d_starts[tip] : null;
	}

	private static Ggit.OId? target_of(Ggit.Ref reference) throws Error
	{
		var resolved = reference.resolve();

		if (resolved.is_tag())
		{
			var tag = resolved.lookup() as Ggit.Tag;

			return tag != null ? tag.get_target_id() : null;
		}

		return resolved.get_target();
	}

	public Gitg.Commit[] tick(Ggit.OId[] tips, Ggit.OId[] mainline)
	{
		var reached = new bool[d_commits.length];
		var starts = new int[0];
		var roots = id_set();

		foreach (var tip in tips)
		{
			var id = start_of(tip);

			if (id != null)
			{
				starts += d_index[id];
				roots.add(id);
			}
		}

		var reserved = new Ggit.OId[0];
		var chain = new int[0];

		foreach (var id in mainline)
		{
			if (d_index.has_key(id))
			{
				reserved += id;
				chain += d_index[id];
			}
		}

		reach(starts, false, reached);
		reach(chain, true, reached);

		d_lanes.reset(reserved, roots);

		var rows = new Gitg.Commit[0];

		for (var i = 0; i < d_commits.length; i++)
		{
			if (!reached[i])
			{
				continue;
			}

			var commit = d_commits[i];
			SList<Gitg.Lane> lanes;
			int mylane;

			if (d_lanes.next(commit, out lanes, out mylane, true))
			{
				commit.update_lanes((owned)lanes, mylane);
				rows += commit;
			}

			var found = true;

			while (found && d_lanes.miss_commits.size > 0)
			{
				found = false;

				var iter = d_lanes.miss_commits.iterator();

				while (iter.next())
				{
					var miss = iter.get();

					if (d_lanes.next(miss, out lanes, out mylane))
					{
						iter.remove();
						miss.update_lanes((owned)lanes, mylane);
						rows += miss;
						found = true;
					}
				}
			}
		}

		return rows;
	}
}

}
