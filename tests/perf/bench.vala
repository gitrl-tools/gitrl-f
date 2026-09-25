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

			var timer = new Timer();
			var repository = Repository.open(Application.discover_repository(File.new_for_path(args[1])));
			var refs = Refs.read(repository);
			var history = new History(repository, refs, false);
			var mainline = History.mainline(repository, true);

			stdout.printf("commits %d, refs %d, open %.3f s\n", history.size, refs.size, timer.elapsed());
			stdout.flush();

			var every = new Ggit.OId[0];

			foreach (var reference in refs)
			{
				every += reference.target;
			}

			tick(history, mainline, "every ref ticked", every);

			for (var i = 2; i < args.length; i++)
			{
				foreach (var reference in refs)
				{
					if (reference.name == args[i])
					{
						tick(history, mainline, "only " + args[i], { reference.target });
					}
				}
			}

			timer.start();

			for (var i = 0; i < 20; i++)
			{
				Poll.snapshot(repository);
			}

			stdout.printf("poll snapshot %.2f ms\n", timer.elapsed() * 1000 / 20);
			stdout.printf("peak resident memory %.0f MiB\n", peak_memory());
		}
		catch (Error e)
		{
			stderr.printf("%s\n", e.message);
			return 1;
		}

		return 0;
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

	private static void tick(History history, Ggit.OId[] mainline, string label, Ggit.OId[] tips)
	{
		var timer = new Timer();
		var rows = history.tick(tips, mainline);
		var lanes = timer.elapsed();
		var model = new HistoryModel();

		model.set_rows(rows);

		stdout.printf("tick, %s: %.3f s, of which lanes %.3f s, %d rows\n", label, timer.elapsed(), lanes, rows.length);
		stdout.flush();
	}
}

}
