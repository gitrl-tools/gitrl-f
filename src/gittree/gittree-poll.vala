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

public class Poll : Object
{
	private string? d_last;
	private uint d_timeout;

	public Gitg.Repository? repository { get; set; }

	public bool running
	{
		get { return d_timeout != 0; }
	}

	public signal void changed();

	public void check()
	{
		if (repository == null)
		{
			return;
		}

		var now = snapshot(repository);

		if (d_last != null && now != d_last)
		{
			d_last = now;
			changed();
			return;
		}

		d_last = now;
	}

	public void reset()
	{
		d_last = repository != null ? snapshot(repository) : null;
	}

	public static string snapshot(Gitg.Repository repository)
	{
		var text = new StringBuilder();

		try
		{
			var head = repository.lookup_reference("HEAD");

			if (head.get_reference_type() == Ggit.RefType.SYMBOLIC)
			{
				text.append_printf("HEAD -> %s\n", head.get_symbolic_target());
			}
			else
			{
				text.append_printf("HEAD %s\n", head.get_target().to_string());
			}

			repository.references_foreach_name((name) => {
				try
				{
					var reference = repository.lookup_reference(name);

					if (reference.get_reference_type() == Ggit.RefType.SYMBOLIC)
					{
						text.append_printf("%s -> %s\n", name, reference.get_symbolic_target());
					}
					else
					{
						text.append_printf("%s %s\n", name, reference.get_target().to_string());
					}
				}
				catch {}

				return 0;
			});
		}
		catch (Error e)
		{
			return "";
		}

		return text.str;
	}

	public void start()
	{
		if (d_timeout == 0)
		{
			reset();
			d_timeout = Timeout.add_seconds(2, () => {
				check();
				return true;
			});
		}
	}

	public void stop()
	{
		if (d_timeout != 0)
		{
			Source.remove(d_timeout);
			d_timeout = 0;
		}
	}
}

}
