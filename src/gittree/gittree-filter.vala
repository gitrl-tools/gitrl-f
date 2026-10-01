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

public class Filter : Object
{
	public bool follow { get; private set; }
	public bool ignore_case { get; private set; }
	public string[] paths { get; private set; }
	public bool regex { get; private set; }
	public string? text { get; private set; }

	public Filter(string? text, bool ignore_case, bool regex, string[] paths, bool follow)
	{
		this.follow = follow;
		this.ignore_case = ignore_case;
		this.paths = paths;
		this.regex = regex;
		this.text = text;
	}

	public static bool is_one_file(Gitg.Repository repository, string[] relative)
	{
		if (relative.length != 1)
		{
			return false;
		}

		var path = relative[0];

		if ("*" in path || "?" in path || "[" in path || path == ".")
		{
			return false;
		}

		var top = repository.get_workdir();

		if (path == ".." || path.has_prefix("../") || Path.is_absolute(path))
		{
			return false;
		}

		if (top != null && top.resolve_relative_path(path).query_file_type(FileQueryInfoFlags.NONE) == FileType.DIRECTORY)
		{
			return false;
		}

		try
		{
			var head = repository.lookup_reference("HEAD").resolve();
			var commit = repository.lookup<Gitg.Commit>(head.get_target());
			var entry = commit.get_tree().get_by_path(path);

			return entry == null || entry.get_object_type() != typeof(Ggit.Tree);
		}
		catch (Error e)
		{
			return true;
		}
	}

	public string[] log_arguments()
	{
		string[] argv = { "log", "-z", "--stdin", "--no-textconv", "--format=%x01%H" };

		if (text != null)
		{
			argv += (regex ? "-G" : "-S") + text;

			if (ignore_case)
			{
				argv += "-i";
			}
		}

		if (follow)
		{
			argv += "--name-status";
			argv += "--follow";
		}

		argv += "--";

		foreach (var path in paths)
		{
			argv += path;
		}

		return argv;
	}

	public static string[] relative_paths(Gitg.Repository repository, File? directory, string[] paths)
	{
		var top = repository.get_workdir();
		var start = directory != null ? directory : top;
		var ret = new string[0];

		if (start == null)
		{
			return paths;
		}

		foreach (var path in paths)
		{
			var file = start.resolve_relative_path(path);
			var relative = top != null ? top.get_relative_path(file) : null;

			ret += relative != null ? relative : (top != null && file.equal(top) ? "." : path);
		}

		return ret;
	}
}

}
