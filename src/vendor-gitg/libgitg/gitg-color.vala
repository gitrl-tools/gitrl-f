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

public class Color : Object
{
	public struct Rgb
	{
		public ushort r;
		public ushort g;
		public ushort b;
		public bool dark_text;
	}

	private const Rgb[] standard = {
		{32, 74, 135, false},
		{108, 53, 102, false},
		{114, 159, 207, false},
		{239, 41, 41, false},
		{52, 226, 226, true},
		{243, 127, 183, true},
		{252, 233, 79, true}
	};

	private static Rgb[]? chosen;

	private static uint current_index;

	public uint idx = 0;

	public static void reset()
	{
		current_index = 0;
	}

	public static void use_palette(Rgb[]? colours)
	{
		chosen = colours;
		current_index = 0;
	}

	private static unowned Rgb[] palette()
	{
		return chosen != null ? chosen : standard;
	}

	private Rgb rgb
	{
		get { return palette()[idx % size()]; }
	}

	public double r
	{
		get { return rgb.r / 255.0; }
	}

	public double g
	{
		get { return rgb.g / 255.0; }
	}

	public double b
	{
		get { return rgb.b / 255.0; }
	}

	public bool dark_text
	{
		get { return rgb.dark_text; }
	}

	public void components(out double r, out double g, out double b)
	{
		r = this.r;
		g = this.g;
		b = this.b;
	}

	private static uint inc_index()
	{
		uint next = current_index++;

		if (current_index == size())
		{
			current_index = 0;
		}

		return next;
	}

	public static Color next()
	{
		Color ret = new Color();
		ret.idx = inc_index();

		return ret;
	}

	public static Color from_index(uint index)
	{
		Color ret = new Color();
		ret.idx = index % size();

		return ret;
	}

	public static uint size()
	{
		return palette().length;
	}

	public Color next_index()
	{
		this.idx = inc_index();
		return this;
	}

	public Color copy()
	{
		Color ret = new Color();
		ret.idx = idx;

		return ret;
	}
}

}

// ex:set ts=4 noet
