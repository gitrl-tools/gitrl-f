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

public class HeadedList : Gtk.Container, Gtk.Scrollable
{
	private bool d_arranging;
	private Gtk.Widget? d_body;
	private int d_fold;
	private Gtk.Widget? d_header;
	private Gtk.Adjustment d_inner;
	private Gtk.Adjustment? d_outer;
	private bool d_syncing;

	public Gtk.Adjustment hadjustment { get; set construct; }
	public Gtk.ScrollablePolicy hscroll_policy { get; set; }

	public Gtk.Adjustment vadjustment
	{
		get { return d_outer; }

		set construct
		{
			if (d_outer != null)
			{
				d_outer.value_changed.disconnect(follow_outer);
			}

			d_outer = value;

			if (d_outer != null)
			{
				d_outer.value_changed.connect(follow_outer);
			}
		}
	}

	public Gtk.ScrollablePolicy vscroll_policy { get; set; }

	construct
	{
		set_has_window(false);
		d_inner = new Gtk.Adjustment(0, 0, 0, 0, 0, 0);
		d_inner.value_changed.connect(follow_body);
		notify["hadjustment"].connect(pass_hadjustment);
	}

	public override void add(Gtk.Widget widget)
	{
		if (d_header == null)
		{
			d_header = widget;
		}
		else
		{
			d_body = widget;
			pass_hadjustment();
			((Gtk.Scrollable)widget).vadjustment = d_inner;
		}

		widget.set_parent(this);
	}

	private void arrange(Gtk.Allocation allocation)
	{
		var height = header_height(allocation.width);

		d_fold = d_inner.value > 0 ? height : int.min(d_fold, height);

		var shown = int.min(height - d_fold, allocation.height);
		Gtk.Allocation top = {
			allocation.x, allocation.y, allocation.width, shown
		};
		Gtk.Allocation rest = {
			allocation.x, allocation.y + shown,
			allocation.width, allocation.height - shown
		};

		d_header.set_child_visible(shown > 0);
		d_header.size_allocate(top);
		((Gtk.Scrollable)d_header).vadjustment.value = d_fold;
		d_body.size_allocate(rest);
	}

	private void follow_body()
	{
		if (!d_syncing)
		{
			place(d_fold + d_inner.value);
		}
	}

	private void follow_outer()
	{
		if (!d_syncing)
		{
			place(d_outer.value);
		}
	}

	public override void forall_internal(bool include_internals,
	                                     Gtk.Callback callback)
	{
		var header = d_header;
		var body = d_body;

		if (header != null)
		{
			callback(header);
		}

		if (body != null)
		{
			callback(body);
		}
	}

	public bool get_border(out Gtk.Border border)
	{
		border = Gtk.Border();

		return false;
	}

	public override void get_preferred_height(out int minimum,
	                                          out int natural)
	{
		int header_minimum;
		int header_natural;

		d_header.get_preferred_height(out header_minimum,
		                              out header_natural);
		d_body.get_preferred_height(out minimum, out natural);
		minimum += header_natural;
		natural += header_natural;
	}

	public override void get_preferred_width(out int minimum,
	                                         out int natural)
	{
		int header_minimum;
		int header_natural;

		d_header.get_preferred_width(out header_minimum,
		                             out header_natural);
		d_body.get_preferred_width(out minimum, out natural);
		minimum = int.max(minimum, header_minimum);
		natural = int.max(natural, header_natural);
	}

	private int header_height(int width)
	{
		int minimum;
		int natural;

		d_header.get_preferred_height_for_width(width, out minimum,
		                                        out natural);

		return natural;
	}

	private void pass_hadjustment()
	{
		if (d_body != null)
		{
			((Gtk.Scrollable)d_body).hadjustment = hadjustment;
		}
	}

	private void place(double scroll)
	{
		var height = header_height(get_allocated_width());
		var fold = (int)double.min(scroll, height);

		d_syncing = true;
		d_inner.value = scroll - fold;
		d_outer.value = scroll;
		d_syncing = false;

		if (fold != d_fold)
		{
			d_fold = fold;

			if (!d_arranging)
			{
				queue_allocate();
			}
		}
	}

	public override void remove(Gtk.Widget widget)
	{
		widget.unparent();

		if (widget == d_header)
		{
			d_header = null;
		}
		else
		{
			d_body = null;
		}
	}

	public override void size_allocate(Gtk.Allocation allocation)
	{
		var width = allocation.width;
		var fold = 0;
		var height = 0;

		set_allocation(allocation);
		d_arranging = true;

		do
		{
			fold = d_fold;
			height = header_height(width);
			arrange(allocation);
		}
		while (fold != d_fold || height != header_height(width));

		d_arranging = false;
		d_syncing = true;
		d_outer.configure(d_fold + d_inner.value, 0,
		                  height + d_inner.upper,
		                  d_inner.step_increment,
		                  d_inner.page_increment,
		                  allocation.height);
		d_syncing = false;
	}
}

}
