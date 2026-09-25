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

public errordomain RepositoryError
{
	NOT_A_REPOSITORY,
}

public class Repository : Object
{
	public static Gitg.Repository open(File location) throws RepositoryError
	{
		try
		{
			Gitg.init();

			return new Gitg.Repository(location, null);
		}
		catch (Error e)
		{
			throw new RepositoryError.NOT_A_REPOSITORY("%s", e.message);
		}
	}
}

}
