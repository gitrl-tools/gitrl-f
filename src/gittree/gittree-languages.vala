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

public class Languages : Object
{
	private const uint LIMIT = 10000;

	private static Gee.HashMap<string, Gtk.SourceBuffer>? s_kept;

	private static Gee.Collection<string> file_names(Ggit.Repository repository)
	{
		var names = new Gee.HashMap<string, string>();

		try
		{
			var entries = repository.get_index().get_entries();
			var count = uint.min(entries.size(), LIMIT);

			for (uint i = 0; i < count; i++)
			{
				var name = Path.get_basename(entries.get_by_index(i).get_path());
				var dot = name.last_index_of_char('.');
				var key = dot > 0 ? name.substring(dot) : name;

				if (!names.has_key(key))
				{
					names[key] = name;
				}
			}
		}
		catch {}

		return names.values;
	}

	private static void keep(string name)
	{
		bool uncertain;
		var type = ContentType.guess(name, null, out uncertain);
		var language = Gtk.SourceLanguageManager.get_default().guess_language(name, type);

		if (language == null || s_kept.has_key(language.id))
		{
			return;
		}

		var buffer = new Gtk.SourceBuffer(null);
		buffer.language = language;
		s_kept[language.id] = buffer;
	}

	public static void warm(Ggit.Repository repository)
	{
		if (s_kept == null)
		{
			s_kept = new Gee.HashMap<string, Gtk.SourceBuffer>();
		}

		Idle.add(() => {
			var pending = file_names(repository).iterator();

			Idle.add(() => {
				if (!pending.next())
				{
					return false;
				}

				keep(pending.get());
				return true;
			}, Priority.LOW);

			return false;
		}, Priority.LOW);
	}
}

}
