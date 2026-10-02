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

public class Repo : Object
{
	private const int64 EPOCH = 1767225600;

	public File path { get; private set; }

	private int d_clock;
	private string[] d_env;

	public Repo(File location) throws Error
	{
		path = location;

		if (!location.query_exists())
		{
			location.make_directory_with_parents();
		}

		var env = Environ.get();

		env = Environ.set_variable(env, "GIT_CONFIG_GLOBAL", "/dev/null", true);
		env = Environ.set_variable(env, "GIT_CONFIG_SYSTEM", "/dev/null", true);

		d_env = env;

		git({"init", "--quiet", "--initial-branch=master"});
		git({"config", "user.name", "Tester"});
		git({"config", "user.email", "tester@example.com"});
	}

	public void branch(string name) throws Error
	{
		git({"branch", name});
	}

	public void branched() throws Error
	{
		commit("base one");
		commit("base two");
		git({"checkout", "--quiet", "-b", "feature/scan"});
		commit("feature one", "feature");
		git({"checkout", "--quiet", "-b", "fix/stamp", "master"});
		commit("fix one", "fix");
		commit("fix two", "fix");
		checkout("master");
		commit("master three");
		merge("fix/stamp");
		commit("master four");
		git({"update-ref", "refs/remotes/origin/master", "master~1"});
		git({"tag", "v1", "master~3"});
	}

	public void checkout(string target) throws Error
	{
		git({"checkout", "--quiet", target});
	}

	public string commit(string subject, string name = "file", string? text = null) throws Error
	{
		d_clock++;

		var target = path.get_child(name);
		var parent = target.get_parent();

		if (parent != null && !parent.query_exists())
		{
			parent.make_directory_with_parents();
		}

		var stream = target.append_to(FileCreateFlags.NONE);
		stream.write(((text != null ? text : subject) + "\n").data);
		stream.close();

		git({"add", name});
		git({"commit", "--quiet", "-m", subject});

		return git({"rev-parse", "HEAD"}).strip();
	}

	public string commit_bytes(string message, string filename, uint8[] content) throws Error
	{
		d_clock++;

		var target = path.get_child(filename);

		target.replace_contents(content, null, false, FileCreateFlags.REPLACE_DESTINATION,
		                        null, null);

		git({"add", "--all"});
		git({"commit", "--quiet", "-m", message});

		return git({"rev-parse", "HEAD"}).strip();
	}

	public static Repo create() throws Error
	{
		var dir = DirUtils.make_tmp("gitrlf-test-XXXXXX");
		return new Repo(File.new_for_path(dir));
	}

	public void delete_branch(string name) throws Error
	{
		git({"branch", "-D", name});
	}

	public string git(string[] args) throws Error
	{
		var when = "@%lld +0000".printf(EPOCH + d_clock);

		var env = Environ.set_variable(d_env, "GIT_AUTHOR_DATE", when, true);
		env = Environ.set_variable(env, "GIT_COMMITTER_DATE", when, true);

		return run_git(args, env);
	}

	public void merge(string name) throws Error
	{
		d_clock++;
		git({"merge", "--quiet", "--no-ff", "--no-edit", name});
	}

	public void remove()
	{
		try
		{
			remove_recursive(path);
		}
		catch (Error e)
		{
			warning("could not remove fixture %s: %s", path.get_path(), e.message);
		}
	}

	private static void remove_recursive(File file) throws Error
	{
		var type = file.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

		if (type == FileType.DIRECTORY)
		{
			var children = file.enumerate_children("standard::name",
			                                       FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

			FileInfo? info;

			while ((info = children.next_file()) != null)
			{
				remove_recursive(file.get_child(info.get_name()));
			}
		}

		file.delete();
	}

	private string run_git(string[] args, string[] env) throws Error
	{
		string[] argv = {};
		argv += "git";
		argv += "-C";
		argv += path.get_path();

		foreach (var arg in args)
		{
			argv += arg;
		}

		argv += null;

		string out;
		string err;
		int status;

		Process.spawn_sync(null,
		                   argv,
		                   env,
		                   SpawnFlags.SEARCH_PATH,
		                   null,
		                   out out,
		                   out err,
		                   out status);

		if (status != 0)
		{
			throw new IOError.FAILED("git %s failed: %s",
			                         string.joinv(" ", args),
			                         err.strip());
		}

		return out;
	}

	public void stash(string? message = null) throws Error
	{
		if (message != null)
		{
			git({"stash", "push", "--quiet", "--message", message});
		}
		else
		{
			git({"stash", "push", "--quiet"});
		}
	}
}

}
