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
 */

namespace Gitree
{
	public class Bench : Object
	{
		private Gitg.Commit[] d_commits;
		private Gee.HashMap<Ggit.OId, int> d_index;
		private Gitg.Lanes d_lanes;
		private int[] d_mainline;
		private int[] d_parents;
		private int[] d_parents_start;
		private Gitg.Repository d_repository;
		private Gitg.Commit[] d_rows;
		private Gee.HashMap<string, Ggit.OId> d_tips;

		private static Gee.HashSet<Ggit.OId> id_set()
		{
			return new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
			                                 (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);
		}

		private static Gee.HashMap<Ggit.OId, int> index_map()
		{
			return new Gee.HashMap<Ggit.OId, int>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
			                                      (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);
		}

		public static int main(string[] args)
		{
			if (args.length < 2)
			{
				stderr.printf("usage: %s <repository> [<full ref name>...]\n", args[0]);
				return 2;
			}

			try
			{
				Gitg.init();

				var bench = new Bench();
				var timer = new Timer();

				bench.open(args[1]);
				var open = timer.elapsed();

				stdout.printf("commits %d, refs %d, mainline lanes %d\n",
				              bench.d_commits.length, bench.d_tips.size, bench.d_mainline.length);
				stdout.printf("open %.3f s\n", open);
				stdout.flush();

				bench.measure("every ref ticked", bench.d_tips.values.to_array());

				for (var i = 2; i < args.length; i++)
				{
					bench.measure("only " + args[i], { bench.d_tips[args[i]] });
				}

				stdout.printf("peak resident memory %.0f MiB\n", peak_memory());
			}
			catch (Error e)
			{
				stderr.printf("%s\n", e.message);
				return 1;
			}

			return 0;
		}

		private int[] mainline() throws Error
		{
			var config = d_repository.get_config().snapshot();
			string[] names = {};

			try
			{
				names = config.get_string("gitg.mainline").split(",");
			}
			catch
			{
				try
				{
					names = { "refs/heads/" + config.get_string("init.defaultBranch") };
				}
				catch {}
			}

			var ids = new Ggit.OId[0];

			foreach (var name in names)
			{
				if (d_tips.has_key(name))
				{
					ids += d_tips[name];
				}
			}

			ids += d_repository.get_head().resolve().get_target();

			var seen = new Gee.HashSet<int>();
			var ret = new int[0];

			foreach (var id in ids)
			{
				if (seen.add(d_index[id]))
				{
					ret += d_index[id];
				}
			}

			return ret;
		}

		private void measure(string label, Ggit.OId[] ticked)
		{
			var timer = new Timer();
			tick(ticked, false);
			var chains = timer.elapsed();
			var chains_rows = d_rows.length;
			var chains_lanes = signature();

			timer.start();
			tick(ticked, true);
			var full = timer.elapsed();

			stdout.printf("tick, %s: %.3f s, %d rows\n", label, chains, chains_rows);
			stdout.printf("  as gitg walks, every commit the mainline reaches: %.3f s, %d rows, lanes %s\n",
			              full, d_rows.length, signature() == chains_lanes ? "identical" : "DIFFERENT");
			stdout.flush();
		}

		public void open(string path) throws Error
		{
			d_repository = new Gitg.Repository(File.new_for_path(path), null);
			d_tips = new Gee.HashMap<string, Ggit.OId>();

			d_repository.references_foreach_name((name) => {
				if (name.has_prefix("refs/heads/") || name.has_prefix("refs/remotes/") || name.has_prefix("refs/tags/"))
				{
					var id = tip_of(name);

					if (id != null)
					{
						d_tips[name] = id;
					}
				}

				return 0;
			});

			var walker = new Ggit.RevisionWalker(d_repository);
			walker.set_sort_mode(Ggit.SortMode.TOPOLOGICAL | Ggit.SortMode.TIME);

			var pushed = id_set();

			foreach (var id in d_tips.values)
			{
				if (pushed.add(id))
				{
					walker.push(id);
				}
			}

			d_commits = new Gitg.Commit[0];
			d_index = index_map();

			Ggit.OId? id;

			while ((id = walker.next()) != null)
			{
				d_index[id] = d_commits.length;
				d_commits += d_repository.lookup<Gitg.Commit>(id);
			}

			d_parents = new int[0];
			d_parents_start = new int[d_commits.length + 1];

			for (var i = 0; i < d_commits.length; i++)
			{
				d_parents_start[i] = d_parents.length;

				var parents = d_commits[i].get_parents();

				for (uint j = 0; j < parents.size; j++)
				{
					var parent = parents.get_id(j);

					if (d_index.has_key(parent))
					{
						d_parents += d_index[parent];
					}
				}
			}

			d_parents_start[d_commits.length] = d_parents.length;
			d_mainline = mainline();
			d_lanes = new Gitg.Lanes();
		}

		private static double peak_memory()
		{
			string status;

			try
			{
				FileUtils.get_contents("/proc/self/status", out status);
			}
			catch
			{
				return 0;
			}

			foreach (var line in status.split("\n"))
			{
				if (line.has_prefix("VmHWM:"))
				{
					var kib = line.substring(6).strip().split(" ");
					return double.parse(kib[0]) / 1024;
				}
			}

			return 0;
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

		private string signature()
		{
			var sum = new Checksum(ChecksumType.SHA256);

			foreach (var commit in d_rows)
			{
				sum.update(commit.get_id().to_string().data, -1);
				sum.update("%u:".printf(commit.mylane).data, -1);

				foreach (var lane in commit.get_lanes())
				{
					sum.update("%u,%d".printf(lane.color.idx, (int)lane.tag).data, -1);

					foreach (var from in lane.from)
					{
						sum.update(",%d".printf(from).data, -1);
					}

					sum.update(";".data, -1);
				}
			}

			return sum.get_string();
		}

		private void tick(Ggit.OId[] ticked, bool every_mainline_commit)
		{
			var reached = new bool[d_commits.length];
			var starts = new int[0];
			var roots = id_set();

			foreach (var id in ticked)
			{
				starts += d_index[id];
				roots.add(id);
			}

			reach(starts, false, reached);
			reach(d_mainline, !every_mainline_commit, reached);

			var reserved = new Ggit.OId[0];

			foreach (var i in d_mainline)
			{
				reserved += d_commits[i].get_id();
			}

			d_lanes.reset(reserved, roots);
			d_rows = new Gitg.Commit[0];

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
					d_rows += commit;
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
							d_rows += miss;
							found = true;
						}
					}
				}
			}
		}

		private Ggit.OId? tip_of(string name)
		{
			try
			{
				var reference = d_repository.lookup_reference(name);

				if (reference.get_reference_type() != Ggit.RefType.OID)
				{
					return null;
				}

				var target = reference.lookup();

				if (target is Ggit.Tag)
				{
					target = ((Ggit.Tag)target).peel();
				}

				return (target is Ggit.Commit) ? target.get_id() : null;
			}
			catch
			{
				return null;
			}
		}
	}
}
