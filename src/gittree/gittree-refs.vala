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

public class Refs : Object
{
	private static Ggit.OId? commit_of(Gitg.Repository repository, Ggit.Ref reference)
	{
		try
		{
			var target = reference.lookup();

			if (target is Ggit.Tag)
			{
				var tag = (Ggit.Tag)target;

				return tag.get_target_type().is_a(typeof(Ggit.Commit)) ? tag.get_target_id() : null;
			}

			return (target is Ggit.Commit) ? target.get_id() : null;
		}
		catch (Error e)
		{
			return null;
		}
	}

	private static int compare(Ref a, Ref b)
	{
		if (a.kind != b.kind)
		{
			return (int)a.kind - (int)b.kind;
		}

		var remote = strcmp(a.remote, b.remote);

		if (remote != 0)
		{
			return remote;
		}

		if (a.head != b.head)
		{
			return a.head ? -1 : 1;
		}

		return compare_natural(a.short_name, b.short_name);
	}

	public static int compare_natural(string a, string b)
	{
		var left = natural_parts(a);
		var right = natural_parts(b);

		for (var i = 0; i < left.length && i < right.length; i++)
		{
			var order = (i % 2 == 0) ? strcmp(left[i].down(), right[i].down()) : compare_numbers(left[i], right[i]);

			if (order != 0)
			{
				return order;
			}
		}

		return left.length - right.length;
	}

	private static int compare_numbers(string a, string b)
	{
		var left = strip_zeros(a);
		var right = strip_zeros(b);

		if (left.length != right.length)
		{
			return left.length - right.length;
		}

		return strcmp(left, right);
	}

	private static string[] natural_parts(string text)
	{
		string[] parts;

		try
		{
			parts = new Regex("([0-9]+)").split(text);
		}
		catch (RegexError e)
		{
			parts = { text };
		}

		return parts;
	}

	public static Gee.List<Ref> read(Gitg.Repository repository) throws Error
	{
		var names = new Gee.ArrayList<string>();

		repository.references_foreach_name((name) => {
			if (name.has_prefix("refs/heads/") || name.has_prefix("refs/remotes/") || name.has_prefix("refs/tags/"))
			{
				names.add(name);
			}

			return 0;
		});

		names.sort((a, b) => strcmp(a, b));

		var refs = new Gee.ArrayList<Ref>();
		var head = repository.lookup_reference("HEAD");
		var current = head.get_reference_type() == Ggit.RefType.SYMBOLIC ? head.get_symbolic_target() : null;

		if (current == null)
		{
			var target = head.get_target();

			if (target != null)
			{
				refs.add(new Ref("HEAD", "HEAD", RefKind.LOCAL, "", target, true));
			}
		}

		foreach (var name in names)
		{
			var reference = repository.lookup_reference(name);

			if (reference.get_reference_type() == Ggit.RefType.SYMBOLIC)
			{
				continue;
			}

			var target = commit_of(repository, reference);

			if (target == null)
			{
				continue;
			}

			if (name.has_prefix("refs/heads/"))
			{
				refs.add(new Ref(name, name.substring(11), RefKind.LOCAL, "", target, name == current));
			}
			else if (name.has_prefix("refs/remotes/"))
			{
				var short_name = name.substring(13);
				var slash = short_name.index_of_char('/');
				var remote = slash >= 0 ? short_name.substring(0, slash) : short_name;

				refs.add(new Ref(name, short_name, RefKind.REMOTE, remote, target, false));
			}
			else
			{
				refs.add(new Ref(name, name.substring(10), RefKind.TAG, "", target, false));
			}
		}

		refs.sort(compare);

		return refs;
	}

	private static string strip_zeros(string digits)
	{
		var i = 0;

		while (i < digits.length - 1 && digits[i] == '0')
		{
			i++;
		}

		return digits.substring(i);
	}
}

}
