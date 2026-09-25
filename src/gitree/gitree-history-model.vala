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

public class HistoryModel : Object, Gtk.TreeModel
{
	private Gee.HashMap<Ggit.OId, int> d_index;
	private Gitg.Commit[] d_rows;
	private int d_stamp;

	public uint size
	{
		get { return d_rows.length; }
	}

	construct
	{
		d_rows = new Gitg.Commit[0];
		d_index = History.id_map<int>();
	}

	public Gitg.Commit? commit_from_iter(Gtk.TreeIter iter)
	{
		return_val_if_fail(iter.stamp == d_stamp, null);

		return get_row((uint)(ulong)iter.user_data);
	}

	public Type get_column_type(int index)
	{
		return ((Gitg.CommitModelColumns)index).type();
	}

	public Gtk.TreeModelFlags get_flags()
	{
		return Gtk.TreeModelFlags.LIST_ONLY | Gtk.TreeModelFlags.ITERS_PERSIST;
	}

	public bool get_iter(out Gtk.TreeIter iter, Gtk.TreePath path)
	{
		iter = {};

		int[] indices = path.get_indices();

		if (indices.length != 1 || indices[0] < 0 || indices[0] >= d_rows.length)
		{
			return false;
		}

		iter.user_data = (void *)(ulong)indices[0];
		iter.stamp = d_stamp;

		return true;
	}

	public int get_n_columns()
	{
		return Gitg.CommitModelColumns.NUM;
	}

	public Gtk.TreePath? get_path(Gtk.TreeIter iter)
	{
		return_val_if_fail(iter.stamp == d_stamp, null);

		return new Gtk.TreePath.from_indices((int)(ulong)iter.user_data);
	}

	public Gitg.Commit? get_row(uint index)
	{
		return index < d_rows.length ? d_rows[index] : null;
	}

	public void get_value(Gtk.TreeIter iter, int column, out Value val)
	{
		val = {};

		return_if_fail(iter.stamp == d_stamp);

		var commit = get_row((uint)(ulong)iter.user_data);

		val.init(get_column_type(column));

		if (commit == null)
		{
			return;
		}

		switch (column)
		{
			case Gitg.CommitModelColumns.SHA1:
				val.set_string(commit.get_id().to_string());
			break;
			case Gitg.CommitModelColumns.SUBJECT:
				val.set_string(commit.get_subject());
			break;
			case Gitg.CommitModelColumns.MESSAGE:
				val.set_string(commit.get_message());
			break;
			case Gitg.CommitModelColumns.COMMITTER:
				val.set_string("%s <%s>".printf(commit.get_committer().get_name(),
				                                commit.get_committer().get_email()));
			break;
			case Gitg.CommitModelColumns.COMMITTER_NAME:
				val.set_string(commit.get_committer().get_name());
			break;
			case Gitg.CommitModelColumns.COMMITTER_EMAIL:
				val.set_string(commit.get_committer().get_email());
			break;
			case Gitg.CommitModelColumns.COMMITTER_DATE:
				val.set_string(commit.committer_date_for_display);
			break;
			case Gitg.CommitModelColumns.AUTHOR:
				val.set_string("%s <%s>".printf(commit.get_author().get_name(),
				                                commit.get_author().get_email()));
			break;
			case Gitg.CommitModelColumns.AUTHOR_NAME:
				val.set_string(commit.get_author().get_name());
			break;
			case Gitg.CommitModelColumns.AUTHOR_EMAIL:
				val.set_string(commit.get_author().get_email());
			break;
			case Gitg.CommitModelColumns.AUTHOR_DATE:
				val.set_string(commit.author_date_for_display);
			break;
			case Gitg.CommitModelColumns.COMMIT:
				val.set_object(commit);
			break;
		}
	}

	public bool iter_children(out Gtk.TreeIter iter, Gtk.TreeIter? parent)
	{
		iter = {};

		if (parent != null || d_rows.length == 0)
		{
			return false;
		}

		iter.user_data = (void *)(ulong)0;
		iter.stamp = d_stamp;

		return true;
	}

	public bool iter_has_child(Gtk.TreeIter iter)
	{
		return false;
	}

	public int iter_n_children(Gtk.TreeIter? iter)
	{
		return iter == null ? d_rows.length : 0;
	}

	public bool iter_next(ref Gtk.TreeIter iter)
	{
		return_val_if_fail(iter.stamp == d_stamp, false);

		var index = (uint)(ulong)iter.user_data + 1;

		if (index >= d_rows.length)
		{
			return false;
		}

		iter.user_data = (void *)(ulong)index;

		return true;
	}

	public bool iter_nth_child(out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n)
	{
		iter = {};

		if (parent != null || n < 0 || n >= d_rows.length)
		{
			return false;
		}

		iter.user_data = (void *)(ulong)n;
		iter.stamp = d_stamp;

		return true;
	}

	public bool iter_parent(out Gtk.TreeIter parent, Gtk.TreeIter iter)
	{
		parent = {};

		return false;
	}

	public Gtk.TreePath? path_from_commit(Ggit.OId id)
	{
		return d_index.has_key(id) ? new Gtk.TreePath.from_indices(d_index[id]) : null;
	}

	public void set_rows(Gitg.Commit[] rows)
	{
		d_stamp++;
		d_rows = rows;
		d_index.clear();

		for (var i = 0; i < d_rows.length; i++)
		{
			d_index[d_rows[i].get_id()] = i;
		}
	}
}

}
