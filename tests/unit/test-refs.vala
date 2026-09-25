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
namespace GitreeTest
{

private static string describe(Gee.List<Gitree.Ref> refs)
{
	var parts = new string[0];

	foreach (var reference in refs)
	{
		parts += "%s:%s:%s:%s%s".printf(reference.name,
		                                 reference.short_name,
		                                 reference.kind.to_string().replace("GITREE_REF_KIND_", "").down(),
		                                 reference.remote,
		                                 reference.head ? ":head" : "");
	}

	return string.joinv("\n", parts);
}

private static Repo fixture() throws Error
{
	var repo = Repo.create();

	repo.commit("first");
	repo.branch("f10");
	repo.branch("f2");
	repo.branch("Zeta");
	repo.branch("alpha");
	repo.git({"update-ref", "refs/remotes/origin/master", "HEAD"});
	repo.git({"update-ref", "refs/remotes/origin/f2", "HEAD"});
	repo.git({"update-ref", "refs/remotes/backup/master", "HEAD"});
	repo.git({"symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/master"});
	repo.git({"tag", "v10"});
	repo.git({"tag", "v9"});
	repo.git({"tag", "-a", "-m", "annotated", "v1"});
	repo.git({"tag", "tree", "HEAD^{tree}"});
	repo.commit("second");

	return repo;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitree/refs/annotated-tag-is-followed-to-its-commit", test_annotated_tag_is_followed_to_its_commit);
	Test.add_func("/gitree/refs/detached-head-is-a-local-ref-named-head", test_detached_head_is_a_local_ref_named_head);
	Test.add_func("/gitree/refs/kinds-names-and-order", test_kinds_names_and_order);
	Test.add_func("/gitree/refs/natural-order-is-the-prototypes", test_natural_order_is_the_prototypes);
	Test.add_func("/gitree/refs/opened-from-a-nested-folder", test_opened_from_a_nested_folder);

	return Test.run();
}

private static Gitg.Repository open(File location) throws Error
{
	var found = Gitree.Application.discover_repository(location);

	assert_nonnull(found);

	return Gitree.Repository.open(found);
}

private static void test_annotated_tag_is_followed_to_its_commit()
{
	try
	{
		var repo = fixture();
		var first = repo.git({"rev-parse", "HEAD~1"}).strip();
		var found = false;

		foreach (var reference in Gitree.Refs.read(open(repo.path)))
		{
			if (reference.name == "refs/tags/v1")
			{
				assert_cmpstr(reference.target.to_string(), CompareOperator.EQ, first);
				found = true;
			}
		}

		assert_true(found);

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_detached_head_is_a_local_ref_named_head()
{
	try
	{
		var repo = fixture();
		repo.git({"checkout", "--quiet", "--detach", "HEAD~1"});

		var refs = Gitree.Refs.read(open(repo.path));

		assert_cmpstr(refs[0].name, CompareOperator.EQ, "HEAD");
		assert_cmpstr(refs[0].short_name, CompareOperator.EQ, "HEAD");
		assert_true(refs[0].kind == Gitree.RefKind.LOCAL);
		assert_true(refs[0].head);
		assert_cmpstr(refs[0].target.to_string(), CompareOperator.EQ, repo.git({"rev-parse", "HEAD"}).strip());

		foreach (var reference in refs)
		{
			assert_true(reference.head == (reference.name == "HEAD"));
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_kinds_names_and_order()
{
	try
	{
		var repo = fixture();

		assert_cmpstr(describe(Gitree.Refs.read(open(repo.path))), CompareOperator.EQ, string.joinv("\n", {
			"refs/heads/master:master:local::head",
			"refs/heads/alpha:alpha:local:",
			"refs/heads/f2:f2:local:",
			"refs/heads/f10:f10:local:",
			"refs/heads/Zeta:Zeta:local:",
			"refs/remotes/backup/master:backup/master:remote:backup",
			"refs/remotes/origin/f2:origin/f2:remote:origin",
			"refs/remotes/origin/master:origin/master:remote:origin",
			"refs/tags/v1:v1:tag:",
			"refs/tags/v9:v9:tag:",
			"refs/tags/v10:v10:tag:",
		}));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_natural_order_is_the_prototypes()
{
	var names = new Gee.ArrayList<string>.wrap({
		"10", "9", "a10b", "a9b", "A2", "a02", "b", "x1y10", "x1y2", "release-1.10", "release-1.9",
		"Ωmega2", "ωmega10", "v1.0.0", "v1.0.0-rc1", "007", "7", "feature/f39", "feature/f4", "_x",
		"Z", "z1", "z01",
	});

	names.sort(Gitree.Refs.compare_natural);

	assert_cmpstr(string.joinv(" ", names.to_array()), CompareOperator.EQ,
	              "007 7 9 10 _x A2 a02 a9b a10b b feature/f4 feature/f39 release-1.9 release-1.10 "
	              + "v1.0.0 v1.0.0-rc1 x1y2 x1y10 Z z1 z01 Ωmega2 ωmega10");
}

private static void test_opened_from_a_nested_folder()
{
	try
	{
		var repo = fixture();
		var nested = repo.path.get_child("a").get_child("b");

		nested.make_directory_with_parents();

		var repository = open(nested);

		assert_cmpstr(repository.get_workdir().get_path(), CompareOperator.EQ, repo.path.get_path());

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
