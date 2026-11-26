/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitg
{
	public class CellRendererLanes : Gtk.CellRendererText
	{
		public Commit? commit { get; set; }
		public Commit? next_commit { get; set; }
		public Commit? prev_commit { get; set; }
		public uint lane_width { get; set; default = 16; }
		public uint dot_width { get; set; default = 10; }
		public unowned SList<Ref> labels { get; set; }

		private const string CAPITALS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		private const double CLEARANCE = 2.0;
		private const double LINE_WIDTH = 2.0;

		private int d_last_height;
		private uint d_gap;
		private int d_indent;
		private string? d_gap_key;

		private delegate double DirectionFunc(double i);

		private uint num_visible_lanes
		{
			get
			{
				int ret = 0;
				int trailing_hidden = 0;

				foreach (var lane in commit.get_lanes())
				{
					++ret;

					if ((lane.tag & LaneTag.HIDDEN) != 0)
					{
						trailing_hidden++;
					}
					else
					{
						trailing_hidden = 0;
					}
				}

				return ret - trailing_hidden;
			}
		}

		private uint lane_gap
		{
			get { return d_gap > 0 ? d_gap : lane_width; }
		}

		private uint own_end
		{
			get { return commit.mylane * lane_gap + lane_width; }
		}

		private uint lanes_end
		{
			get
			{
				var visible = num_visible_lanes;

				return visible == 0 ? 0 : (visible - 1) * lane_gap + lane_width;
			}
		}

		/**
		 * Gives the x of the middle of lane @index, from the left edge of
		 * the cell.
		 */
		public double lane_centre(uint index)
		{
			return index * lane_gap + lane_width / 2.0;
		}

		private uint text_offset(Gtk.Widget widget)
		{
			return own_end + LabelRenderer.width(widget, font_desc, labels);
		}

		private void measure_gap(Gtk.Widget widget)
		{
			var font = widget.get_pango_context().get_font_description().copy();
			font.merge(font_desc, true);

			var key = "%s %d %u".printf(font.to_string(), d_indent, xpad);

			if (key == d_gap_key)
			{
				return;
			}

			d_gap_key = key;

			var layout = widget.create_pango_layout(null);
			var reach = 0;

			foreach (var weight in new Pango.Weight[] { Pango.Weight.NORMAL, Pango.Weight.BOLD })
			{
				font.set_weight(weight);
				layout.set_font_description(font);

				for (var i = 0; i < CAPITALS.length; i++)
				{
					Pango.Rectangle ink;

					layout.set_text(CAPITALS.substring(i, 1), -1);
					layout.get_pixel_extents(out ink, null);
					reach = int.max(reach, ink.x + ink.width);
				}
			}

			var gap = lane_width / 2.0 + d_indent + xpad + reach +
			          CLEARANCE + LINE_WIDTH / 2.0;

			d_gap = uint.max(lane_width, (uint)Math.ceil(gap));
		}

		public override void get_preferred_width(Gtk.Widget widget,
		                                         out int    minimum_width,
		                                         out int    natural_width)
		{
			base.get_preferred_width(widget, out minimum_width, out natural_width);

			measure_gap(widget);

			var offset = (int)text_offset(widget);
			var reach = (int)lanes_end;

			minimum_width = int.max(minimum_width, int.max(offset, reach));
			natural_width = int.max(natural_width + offset, reach);
		}

		private void draw_arrow(Cairo.Context context,
		                        Gdk.Rectangle area,
		                        uint          laneidx,
		                        bool          top)
		{
			double xpos = area.x + lane_centre(laneidx);
			double df = (top ? -1 : 1) * 0.25 * area.height;
			double ypos = area.y + area.height / 2.0 + df;
			double q = lane_width / 4.0;

			context.move_to(xpos - q, ypos + (top ? q : -q));
			context.line_to(xpos, ypos);
			context.line_to(xpos + q, ypos + (top ? q : -q));
			context.stroke();

			context.move_to(xpos, ypos);
			context.line_to(xpos, ypos - df);
			context.stroke();
		}

		private void draw_arrows(Cairo.Context context,
		                         Gdk.Rectangle area)
		{
			uint to = 0;

			foreach (var lane in commit.get_lanes())
			{
				var color = lane.color;
				context.set_source_rgb(color.r, color.g, color.b);

				if (lane.tag == LaneTag.START)
				{
					draw_arrow(context, area, to, true);
				}
				else if (lane.tag == LaneTag.END)
				{
					draw_arrow(context, area, to, false);
				}

				++to;
			}
		}

		private static Color bend_color(Lane lane, int from, Commit? above)
		{
			if (above == null)
			{
				return lane.color;
			}

			unowned SList<Lane> lanes = above.get_lanes();

			foreach (var other in lanes)
			{
				if (other.line == lane.line)
				{
					return lanes.nth_data(from).color;
				}
			}

			return lane.color;
		}

		private void draw_paths_real(Cairo.Context context,
		                             Gdk.Rectangle area,
		                             Commit?       commit,
		                             Commit?       above,
		                             DirectionFunc f,
		                             double        yoffset)
		{
			if (commit == null)
			{
				return;
			}

			int to = 0;
			double ch = area.height / 2.0;

			foreach (var lane in commit.get_lanes())
			{
				if ((lane.tag & LaneTag.HIDDEN) != 0)
				{
					++to;
					continue;
				}

				foreach (var from in lane.from)
				{
					var color = bend_color(lane, from, above);
					context.set_source_rgb(color.r, color.g, color.b);

					double x1 = area.x + f(lane_centre(from));
					double x2 = area.x + f(lane_centre(to));
					double y1 = area.y + yoffset * ch;
					double y2 = area.y + (yoffset + 1) * ch;
					double y3 = area.y + (yoffset + 2) * ch;

					context.move_to(x1, y1);
					context.curve_to(x1, y2, x2, y2, x2, y3);
					context.stroke();
				}

				++to;
			}
		}

		private void draw_top_paths(Cairo.Context context,
		                            Gdk.Rectangle area,
		                            DirectionFunc f)
		{
			draw_paths_real(context, area, commit, prev_commit, f, -1);
		}

		private void draw_bottom_paths(Cairo.Context context,
		                               Gdk.Rectangle area,
		                               DirectionFunc f)
		{
			draw_paths_real(context, area, next_commit, commit, f, 1);
		}

		private void draw_paths(Cairo.Context context,
		                        Gdk.Rectangle area,
		                        DirectionFunc f)
		{
			context.set_line_width(LINE_WIDTH);
			context.set_line_cap(Cairo.LineCap.ROUND);

			context.save();

			draw_top_paths(context, area, f);
			draw_bottom_paths(context, area, f);
			draw_arrows(context, area);

			context.restore();
		}

		private void draw_indicator(Cairo.Context context,
		                            Gdk.Rectangle area,
		                            DirectionFunc f)
		{
			double radius = dot_width / 2.0;

			context.set_line_width(0.0);

			context.arc(area.x + f(lane_centre(commit.mylane)),
			            area.y + area.height / 2.0,
			            radius,
			            0,
			            2 * Math.PI);

			context.set_source_rgb(0, 0, 0);
			context.stroke_preserve();

			if (commit.lane != null)
			{
				var color = commit.lane.color;
				context.set_source_rgb(color.r, color.g, color.b);
			}

			context.fill();
		}

		private void draw_labels(Cairo.Context context,
		                         Gtk.Widget    widget,
		                         Gdk.Rectangle area)
		{
			int offset;

			offset = (int)own_end;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			if (rtl)
			{
				offset = -offset;
			}

			context.save();
			context.translate(offset, 0);
			LabelRenderer.draw(widget, font_desc, context, labels, area, commit.lane.color);
			context.restore();
		}

		private void draw_lane(Cairo.Context context,
		                       Gtk.Widget    widget,
		                       Gdk.Rectangle area)
		{
			DirectionFunc f;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			context.save();

			if (rtl)
			{
				context.translate(area.width, 0);
				f = (a) => -a;
			}
			else
			{
				f = (a) => a;
			}

			draw_paths(context, area, f);
			draw_indicator(context, area, f);

			context.restore();
		}

		public override void render(Cairo.Context         context,
		                            Gtk.Widget            widget,
		                            Gdk.Rectangle         area,
		                            Gdk.Rectangle         cell_area,
		                            Gtk.CellRendererState flags)
		{
			var ncell_area = cell_area;
			var narea = area;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			d_last_height = area.height;

			if (rtl == (Pango.find_base_dir(text, -1) != Pango.Direction.RTL))
			{
				xalign = 1.0f;
			}

			if (commit != null)
			{
				d_indent = rtl ? area.x + area.width - cell_area.x - cell_area.width
				               : cell_area.x - area.x;
				measure_gap(widget);

				var tw = (int)text_offset(widget);

				if (!rtl)
				{
					narea.x += tw;
					ncell_area.x += tw;
				}

				narea.width -= tw;
				ncell_area.width -= tw;

				context.save();

				Gdk.cairo_rectangle(context, area);
				context.clip();

				var crossed = num_visible_lanes > commit.mylane + 1;

				if (crossed)
				{
					context.push_group();
				}

				draw_lane(context, widget, area);

				if (crossed)
				{
					cut_clearance(context, widget, area, narea, ncell_area,
					              flags);
					context.pop_group_to_source();
					context.paint();
				}

				draw_labels(context, widget, area);

				context.restore();
			}

			base.render(context, widget, narea, ncell_area, flags);
		}

		private void cut_clearance(Cairo.Context         context,
		                           Gtk.Widget            widget,
		                           Gdk.Rectangle         area,
		                           Gdk.Rectangle         text_area,
		                           Gdk.Rectangle         text_cell_area,
		                           Gtk.CellRendererState flags)
		{
			context.set_operator(Cairo.Operator.DEST_OUT);

			for (var dy = -CLEARANCE; dy <= CLEARANCE; dy++)
			{
				for (var dx = -CLEARANCE; dx <= CLEARANCE; dx++)
				{
					context.save();
					context.translate(dx, dy);
					draw_labels(context, widget, area);
					base.render(context, widget, text_area, text_cell_area,
					            flags);
					context.restore();
				}
			}
		}

		public Ref? get_ref_at_pos(Gtk.Widget widget,
		                           int        x,
		                           int        cell_w,
		                           out int    hot_x)
		{
			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;
			var offset = (int)own_end;

			if (rtl)
			{
				x = cell_w - x;
			}

			return LabelRenderer.get_ref_at_pos(widget,
			                                    font_desc,
			                                    labels,
			                                    x - offset,
			                                    out hot_x);
		}
	}
}

// ex:ts=4 noet
