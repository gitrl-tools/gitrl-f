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

public class ChangesLane : Gtk.DrawingArea
{
	private const double DOT = 1.25;
	private const int DOTS = 3;
	private const int DOT_SPACING = 4;
	private const double RADIUS = 4;
	private const int WIDTH = 16;

	public Gdk.RGBA color { get; set; }
	public bool dots { get; set; }
	public int lane { get; set; }
	public bool line_above { get; set; }
	public bool line_below { get; set; }
	public bool ring { get; set; }

	construct
	{
		notify.connect(() => {
			width_request = ring ? (lane + 1) * WIDTH : -1;
			queue_draw();
		});
	}

	public override bool draw(Cairo.Context context)
	{
		var height = get_allocated_height();
		var x = lane * WIDTH + WIDTH / 2.0;
		var middle = height / 2.0;
		var gap = ring ? RADIUS : 0;

		get_style_context().render_background(context, 0, 0,
		                                      get_allocated_width(), height);

		Gdk.cairo_set_source_rgba(context, color);
		context.set_line_width(2);

		if (dots)
		{
			for (var i = 0; i < DOTS; i++)
			{
				var y = middle + (i - (DOTS - 1) / 2) * DOT_SPACING;

				context.arc(x, y, DOT, 0, 2 * Math.PI);
				context.fill();
			}
		}

		if (line_above)
		{
			context.move_to(x, 0);
			context.line_to(x, middle - gap);
		}

		if (line_below)
		{
			context.move_to(x, middle + gap);
			context.line_to(x, height);
		}

		context.stroke();

		if (ring)
		{
			context.arc(x, middle, RADIUS, 0, 2 * Math.PI);
			context.stroke();
		}

		return false;
	}
}

}
