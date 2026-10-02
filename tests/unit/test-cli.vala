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
 */namespace GitrlfTest
{

private const string[] PROTOTYPE_PARSES = {
	"|||||",
	"-a|all||||",
	"--all|all||||",
	"--al|all||||",
	"--a|all||||",
	"-al|all,local||||",
	"-alrt|all,local,remotes,tags||||",
	"--loc|local||||",
	"--rem|remotes||||",
	"--t||||ambiguous option: --t could match --tags, --text|",
	"--h|||||help",
	"-x||||unrecognized arguments: -x|",
	"--foo||||unrecognized arguments: --foo|",
	"-x --foo master||||unrecognized arguments: -x --foo|",
	"-ax||||unrecognized arguments: -x|",
	"--all=x||||argument -a/--all: ignored explicit argument 'x'|",
	"-a=x||||argument -a/--all: ignored explicit argument 'x'|",
	"master -l dev||||unrecognized arguments: dev|",
	"-||-|||",
	"-1||-1|||",
	"-- a -b|||a,-b||",
	"x -- --all||x|--all||",
	"-h -x||||unrecognized arguments: -x|",
	"-h master|||||help",
	"-lh|||||help",
	"--help|||||help",
	"--he|||||help",
	"-- --|||--||",
	"-a --|all||||",
	"---x||||unrecognized arguments: ---x|",
	"--al=1||||argument -a/--all: ignored explicit argument '1'|",
	"-ha|||||help",
	"-l1||||unrecognized arguments: -1|",
	"master -x dev||||unrecognized arguments: -x dev|",
	"-l master -t dev||||unrecognized arguments: dev|",
	"master dev -l|local|master,dev|||",
	"-x master||||unrecognized arguments: -x|",
	"-axl||||unrecognized arguments: -xl|",
	"-alx||||unrecognized arguments: -x|",
	"--foo=bar||||unrecognized arguments: --foo=bar|",
	"-h=x||||argument -h/--help: ignored explicit argument 'x'|",
	"--all=x -y||||argument -a/--all: ignored explicit argument 'x'|",
	"-y --all=x||||argument -a/--all: ignored explicit argument 'x'|",
	"-x -a=x||||argument -a/--all: ignored explicit argument 'x'|",
	"master -l dev -x||||unrecognized arguments: dev -x|",
	"-l a b -t|local,tags|a,b|||",
	"-1 -l|local|-1|||",
	"-- -h|||-h||",
	"-l -- x|local||x||",
	"a -- b -- c||a|b,--,c||",
	"--al --a|all||||",
	"-a -a|all||||",
	"--foo -- p||||unrecognized arguments: --foo|",
	"-lx -y||||unrecognized arguments: -x -y|",
	"-=x||||unrecognized arguments: -=x|",
	"--=||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd|",
	"-l-||||argument -l/--local: ignored explicit argument '-'|",
	"-la=x||||argument -a/--all: ignored explicit argument 'x'|",
	"-l origin/master|local|origin/master|||",
	"-t master|tags|master|||",
	"feature/* refs/tags/v1.*||feature/*,refs/tags/v1.*|||",
	"-.5||-.5|||",
	"-1.5x||||unrecognized arguments: -1.5x|",
};

private const string[] REGEX_PARSES = {
	"-G\tx||||None|x||",
	"-Gx||||None|x||",
	"-G=x||||None|x||",
	"-G-x||||None|-x||",
	"-G\t-1||||None|-1||",
	"--regex\tx||||None|x||",
	"--regex=x||||None|x||",
	"--reg\tx||||None|x||",
	"--re\tx|||||||ambiguous option: --re could match --remotes, --regex",
	"--r|||||||ambiguous option: --r could match --remotes, --regex",
	"--r\tx|||||||ambiguous option: --r could match --remotes, --regex",
	"--rem|remotes|||None|None||",
	"-r|remotes|||None|None||",
	"--rege=x||||None|x||",
	"-S\ta\t-G\tb|||||||argument -G/--regex: not allowed with argument -S/--text",
	"-G\tb\t-S\ta|||||||argument -S/--text: not allowed with argument -G/--regex",
	"-G\ta\t-G\tb||||None|b||",
	"-S\ta\t-S\tb||||b|None||",
	"-G|||||||argument -G/--regex: expected one argument",
	"--regex|||||||argument -G/--regex: expected one argument",
	"-G\t-x|||||||argument -G/--regex: expected one argument",
	"-G\t--all|||||||argument -G/--regex: expected one argument",
	"-G\tx\tmaster||master||None|x||",
	"master\t-G\tx||master||None|x||",
	"-G\tx\t--\tsrc|||src|None|x||",
	"-G\t--\tsrc|||||||argument -G/--regex: expected one argument",
	"-lG\tx|local|||None|x||",
	"-lGx|local|||None|x||",
	"-Gl||||None|l||",
	"-iG\tx||||None|x|i|",
	"-G\tx\t-i||||None|x|i|",
	"-G\t||||None|||",
	"-G=||||None|||",
	"-G\ta b||||None|a b||",
	"-G\t-foo|||||||argument -G/--regex: expected one argument",
	"-G-foo||||None|-foo||",
	"-G\t^a.*b$||||None|^a.*b$||",
	"-G\t[0-9]+||||None|[0-9]+||",
	"-SG\tx||x||G|None||",
	"-GS\tx||x||None|S||",
	"-S\ta\t-Gb|||||||argument -G/--regex: not allowed with argument -S/--text",
	"--text=a\t--regex=b|||||||argument -G/--regex: not allowed with argument -S/--text",
	"-G\tx\t--t|||||||ambiguous option: --t could match --tags, --text",
	"--=|||||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"-G\t--=|||||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"-G\t--r|||||||ambiguous option: --r could match --remotes, --regex",
	"-x\t-G\ta|||||||unrecognized arguments: -x",
};

private const string[] TEXT_PARSES = {
	"-S\tfoo||||foo||",
	"-Sfoo||||foo||",
	"-S=foo||||foo||",
	"-S=-x||||-x||",
	"-S-x||||-x||",
	"-S\t-1||||-1||",
	"--text\tfoo||||foo||",
	"--text=foo||||foo||",
	"--te\tfoo||||foo||",
	"--te=foo||||foo||",
	"--t\tfoo||||||ambiguous option: --t could match --tags, --text",
	"-S\ta\t-S\tb||||b||",
	"-S||||||argument -S/--text: expected one argument",
	"-S\t-x||||||argument -S/--text: expected one argument",
	"-S\t--all||||||argument -S/--text: expected one argument",
	"--text||||||argument -S/--text: expected one argument",
	"-S\tfoo\tmaster||master||foo||",
	"master\t-S\tfoo||master||foo||",
	"master\t-S\tfoo\tdev||||||unrecognized arguments: dev",
	"-S\tfoo\t--\tsrc|||src|foo||",
	"-S\t--\tsrc||||||argument -S/--text: expected one argument",
	"-lS\tfoo|local|||foo||",
	"-lSfoo|local|||foo||",
	"-Sl||||l||",
	"-iS\tfoo||||foo|i|",
	"-S\tfoo\t-i||||foo|i|",
	"-i||||None|i|",
	"--ignore-case||||None|i|",
	"--ig||||None|i|",
	"--i||||None|i|",
	"-i=x||||||argument -i/--ignore-case: ignored explicit argument 'x'",
	"-S\t||||||",
	"-S=||||||",
	"-S\tfoo bar||||foo bar||",
	"-S\t-foo||||||argument -S/--text: expected one argument",
	"-S-foo||||-foo||",
	"--text\t-x||||||argument -S/--text: expected one argument",
	"--text=-x||||-x||",
	"-S\tfoo\t-x||||||unrecognized arguments: -x",
	"-ia|all|||None|i|",
	"-ai|all|||None|i|",
	"--=||||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"--ta|tags|||None||",
	"--tex\tfoo||||foo||",
	"-lS=foo|local|||foo||",
	"-S\t--t||||||ambiguous option: --t could match --tags, --text",
	"-S\t--zzz||||||argument -S/--text: expected one argument",
	"-S\t-a b||||||argument -S/--text: expected one argument",
	"-S\t-x y||||-x y||",
	"-S\t--=||||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"-S\t-||||-||",
	"-S\t--no||||||argument -S/--text: expected one argument",
	"-S\t--text=x||||||argument -S/--text: expected one argument",
	"-S\ta b||||a b||",
	"-x\t-S\tfoo||||||unrecognized arguments: -x",
	"-S\tfoo\t--t||||||ambiguous option: --t could match --tags, --text",
	"-S\t-x\t--t||||||ambiguous option: --t could match --tags, --text",
	"-S\t-x\t--=||||||ambiguous option: --= could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"-S\t--zzz\t--t||||||ambiguous option: --t could match --tags, --text",
	"-S\t-x\t--\t--t||||||argument -S/--text: expected one argument",
	"--t\t-S||||||ambiguous option: --t could match --tags, --text",
	"-S\t-x\t--te||||||argument -S/--text: expected one argument",
	"-S\t-x\t--t\t-a||||||ambiguous option: --t could match --tags, --text",
	"-x\t-S\t--t||||||ambiguous option: --t could match --tags, --text",
	"-a=1\t--t||||||ambiguous option: --t could match --tags, --text",
	"-i=x\t--=x||||||ambiguous option: --=x could match --all, --local, --remotes, --tags, --text, --regex, --ignore-case, --help, --version, --no-wd",
	"-x\t--t||||||ambiguous option: --t could match --tags, --text",
	"-h\t--t||||||ambiguous option: --t could match --tags, --text",
};

private static string[] arguments_of(string row)
{
	var fields = row.split("|");
	var joined = fields[0];

	if (joined == "")
	{
		return new string[0];
	}

	return joined.split(" ");
}

private static string flags_of(Gitrlf.CommandLine cli)
{
	var flags = new string[0];

	if (cli.all)
	{
		flags += "all";
	}

	if (cli.local)
	{
		flags += "local";
	}

	if (cli.remotes)
	{
		flags += "remotes";
	}

	if (cli.tags)
	{
		flags += "tags";
	}

	return string.joinv(",", flags);
}

private static string[] headless_environment()
{
	var env = Environ.get();

	env = Environ.unset_variable(env, "DISPLAY");
	env = Environ.unset_variable(env, "WAYLAND_DISPLAY");

	return env;
}

public static int main(string[] args)
{
	Test.init(ref args);

	Test.add_func("/gitrlf/cli/a-bad-regex-is-refused", test_a_bad_regex_is_refused);
	Test.add_func("/gitrlf/cli/a-text-alone-ticks-every-ref", test_a_text_alone_ticks_every_ref);
	Test.add_func("/gitrlf/cli/an-empty-regex-is-refused", test_an_empty_regex_is_refused);
	Test.add_func("/gitrlf/cli/an-empty-text-is-refused", test_an_empty_text_is_refused);
	Test.add_func("/gitrlf/cli/help-is-printed-anywhere", test_help_is_printed_anywhere);
	Test.add_func("/gitrlf/cli/help-names-every-option", test_help_names_every_option);
	Test.add_func("/gitrlf/cli/help-says-gitrlf-only", test_help_says_gitrlf_only);
	Test.add_func("/gitrlf/cli/help-says-what-adds-or-removes-a-text", test_help_says_what_adds_or_removes_a_text);
	Test.add_func("/gitrlf/cli/ignore-case-needs-a-text", test_ignore_case_needs_a_text);
	Test.add_func("/gitrlf/cli/long-only-options-parse-as-argparse", test_long_only_options_parse_as_argparse);
	Test.add_func("/gitrlf/cli/no-display-exits-with-one", test_no_display_exits_with_one);
	Test.add_func("/gitrlf/cli/no-wd-refuses-refs-paths-texts-and-tick-options", test_no_wd_refuses_refs_paths_texts_and_tick_options);
	Test.add_func("/gitrlf/cli/outside-a-repository-arguments-are-an-error", test_outside_a_repository_arguments_are_an_error);
	Test.add_func("/gitrlf/cli/parses-as-the-prototype", test_parses_as_the_prototype);
	Test.add_func("/gitrlf/cli/regex-parses-as-argparse", test_regex_parses_as_argparse);
	Test.add_func("/gitrlf/cli/text-and-ignore-case-parse-as-argparse", test_text_and_ignore_case_parse_as_argparse);
	Test.add_func("/gitrlf/cli/version-prints-the-name-and-the-version", test_version_prints_the_name_and_the_version);
	Test.add_func("/gitrlf/cli/wrong-option-prints-usage-and-exits-with-two", test_wrong_option_prints_usage_and_exits_with_two);

	return Test.run();
}

private static int run(string directory, string[] arguments, out string output, out string errors)
{
	string[] argv = { Environment.get_variable("GITRLF_BINARY") };

	foreach (var argument in arguments)
	{
		argv += argument;
	}

	int status = -1;
	output = "";
	errors = "";

	try
	{
		Process.spawn_sync(directory, argv, headless_environment(), 0, null, out output, out errors, out status);
	}
	catch (SpawnError e)
	{
		Test.fail_printf("could not start %s: %s", argv[0], e.message);
	}

	return Process.if_exited(status) ? Process.exit_status(status) : -1;
}

private static void test_a_bad_regex_is_refused()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		string output;
		string errors;

		assert_cmpint(run(repo.path.get_path(), { "-G", "(" }, out output, out errors), CompareOperator.EQ, 2);
		assert_cmpstr(output, CompareOperator.EQ, "");
		assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: argument -G/--regex: bad regex: Unmatched ( or \\(\n");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_a_text_alone_ticks_every_ref()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");
		repo.branch("side");
		repo.git({"tag", "v1"});

		var repository = Gitrlf.Repository.open(Gitrlf.Application.discover_repository(repo.path));
		var refs = Gitrlf.Refs.read(repository);
		var all = Gitrlf.Ticks.resolve(new Gitrlf.CommandLine({ "-S", "foo" }), refs);
		var local = Gitrlf.Ticks.resolve(new Gitrlf.CommandLine({ "-S", "foo", "-l" }), refs);

		assert_cmpint(all.size, CompareOperator.EQ, refs.size);
		assert_true(all.contains("refs/tags/v1"));
		assert_true(local.contains("refs/heads/side"));
		assert_false(local.contains("refs/tags/v1"));

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_empty_regex_is_refused()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		foreach (var arguments in new string[] { "-G\t", "-G=", "--regex=" })
		{
			string output;
			string errors;

			assert_cmpint(run(repo.path.get_path(), arguments.split("\t"), out output, out errors), CompareOperator.EQ, 2);
			assert_cmpstr(output, CompareOperator.EQ, "");
			assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: argument -G/--regex: the regex is empty\n");
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_an_empty_text_is_refused()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		foreach (var arguments in new string[] { "-S\t", "-S=", "--text=" })
		{
			string output;
			string errors;

			assert_cmpint(run(repo.path.get_path(), arguments.split("\t"), out output, out errors), CompareOperator.EQ, 2);
			assert_cmpstr(output, CompareOperator.EQ, "");
			assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: argument -S/--text: the text is empty\n");
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_help_is_printed_anywhere()
{
	try
	{
		var repo = Repo.create();
		var outside = DirUtils.make_tmp("gitrlf-outside-XXXXXX");

		foreach (var directory in new string[] { repo.path.get_path(), outside })
		{
			foreach (var option in new string[] { "-h", "--help" })
			{
				string output;
				string errors;

				assert_cmpint(run(directory, { option }, out output, out errors), CompareOperator.EQ, 0);
				assert_cmpstr(output, CompareOperator.EQ, Gitrlf.CommandLine.HELP);
				assert_cmpstr(errors, CompareOperator.EQ, "");
			}
		}

		repo.remove();
		DirUtils.remove(outside);
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_help_names_every_option()
{
	string output;
	string errors;

	run(Environment.get_current_dir(), { "-h" }, out output, out errors);

	foreach (var option in new string[] { "--all", "--local", "--remotes", "--tags", "--text <text>", "--regex <regex>", "--ignore-case", "--version", "--no-wd", "-- <path>..." })
	{
		assert_true(option in output);
	}
}

private static void test_help_says_gitrlf_only()
{
	var lines = Gitrlf.CommandLine.HELP.split("\n");

	assert_cmpstr(lines[0], CompareOperator.EQ, "usage: gitrlf [<options>] [<ref>...] [-S <text> | -G <regex>] [-i] [-- <path>...]");
	assert_cmpstr(Gitrlf.CommandLine.USAGE, CompareOperator.EQ, lines[0] + "\n");
	assert_false("git tree" in Gitrlf.CommandLine.HELP);
	assert_true("\nOptions add up: 'gitrlf -l origin/master' ticks every local\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    --version       print the version and exit\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    --no-wd         open the chooser, not the repository of this\n                    folder\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    -h, --help      print this help and exit\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    Click, Enter                show or hide the details of a commit\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    Open a file, Expand all     fill the window with the diff\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n    Escape                      close a bar, the full diff or the details\n" in Gitrlf.CommandLine.HELP);
	assert_true("\n                                while it is shut\n    Ctrl+Shift+F                open the search bar on Changed lines\n    Enter, Ctrl+G" in Gitrlf.CommandLine.HELP);
	assert_true("\n    Ctrl+F                      open or close the diff's find bar while\n                                the pane is open, or the search bar\n                                while it is shut\n" in Gitrlf.CommandLine.HELP);
}

private static void test_help_says_what_adds_or_removes_a_text()
{
	var help = Gitrlf.CommandLine.HELP;

	assert_true("\n    -t, --tags      tick every tag\n    -S, --text <text>\n                    draw only the commits that add or remove <text>\n    -G, --regex <regex>\n                    draw only the commits whose added or removed\n                    lines match <regex>\n    -i, --ignore-case\n                    with -S or -G, ignore case\n    -h, --help" in help);
	assert_true("\nSearch looks in the subject, the message, the author and the\nhash. Words narrow it: author:, message:, hash:, before: and\nafter:, as in author:\"Jane Doe\" after:2026-01.\n\nA commit adds or removes the text when the number of times it\nappears in a file the commit changes goes up or down, as in git\nlog -S. A merge never does.\n\nA regex is a POSIX extended regular expression, as in git log -G.\nOne file after -- is followed through its renames, as in git log\n--follow.\n" in help);
}

private static void test_ignore_case_needs_a_text()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		foreach (var option in new string[] { "-i", "--ignore-case" })
		{
			string output;
			string errors;

			assert_cmpint(run(repo.path.get_path(), { option }, out output, out errors), CompareOperator.EQ, 2);
			assert_cmpstr(output, CompareOperator.EQ, "");
			assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: argument -i/--ignore-case: needs -S or -G\n");
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_long_only_options_parse_as_argparse()
{
	string[,] cases = {
		{ "--version", "version", "" },
		{ "--v", "version", "" },
		{ "--no-wd", "no-wd", "" },
		{ "--no", "no-wd", "" },
		{ "--version=x", "", "argument --version: ignored explicit argument 'x'" },
		{ "--no-wd=1", "", "argument --no-wd: ignored explicit argument '1'" },
	};

	for (var i = 0; i < cases.length[0]; i++)
	{
		var cli = new Gitrlf.CommandLine({ cases[i, 0] });
		var flag = cli.version ? "version" : (cli.no_wd ? "no-wd" : "");

		assert_cmpstr(cli.error != null ? cli.error : "", CompareOperator.EQ, cases[i, 2]);

		if (cases[i, 2] == "")
		{
			assert_cmpstr(flag, CompareOperator.EQ, cases[i, 1]);
		}
	}
}

private static void test_no_display_exits_with_one()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		string output;
		string errors;

		assert_cmpint(run(repo.path.get_path(), {}, out output, out errors), CompareOperator.EQ, 1);
		assert_true(errors != "");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_no_wd_refuses_refs_paths_texts_and_tick_options()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		string[,] cases = {
			{ "master", "" },
			{ "-a", "" },
			{ "-l", "" },
			{ "--", "file" },
			{ "-S", "foo" },
			{ "-G", "foo" },
			{ "-i", "" },
		};

		for (var i = 0; i < cases.length[0]; i++)
		{
			string[] arguments = { "--no-wd", cases[i, 0] };

			if (cases[i, 1] != "")
			{
				arguments += cases[i, 1];
			}

			string output;
			string errors;

			assert_cmpint(run(repo.path.get_path(), arguments, out output, out errors), CompareOperator.EQ, 2);
			assert_cmpstr(output, CompareOperator.EQ, "");
			assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: --no-wd takes no ref, no path, no text, no regex and no tick option\n");
		}

		foreach (var option in new string[] { "-h", "--version" })
		{
			string output;
			string errors;

			assert_cmpint(run(repo.path.get_path(), { "--no-wd", option }, out output, out errors), CompareOperator.EQ, 0);
			assert_cmpstr(errors, CompareOperator.EQ, "");
			assert_true(output != "");
		}

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

private static void test_outside_a_repository_arguments_are_an_error()
{
	string outside;

	try
	{
		outside = DirUtils.make_tmp("gitrlf-outside-XXXXXX");
	}
	catch (FileError e)
	{
		Test.fail_printf("%s", e.message);
		return;
	}

	string[,] cases = {
		{ "master", "" },
		{ "-a", "" },
		{ "--", "file" },
		{ "-S", "foo" },
	};

	for (var i = 0; i < cases.length[0]; i++)
	{
		string[] arguments = { cases[i, 0] };

		if (cases[i, 1] != "")
		{
			arguments += cases[i, 1];
		}

		string output;
		string errors;

		assert_cmpint(run(outside, arguments, out output, out errors), CompareOperator.EQ, 1);
		assert_cmpstr(output, CompareOperator.EQ, "");
		assert_cmpstr(errors, CompareOperator.EQ, "gitrlf: not a git repository\n");
	}

	DirUtils.remove(outside);
}

private static void test_parses_as_the_prototype()
{
	foreach (var row in PROTOTYPE_PARSES)
	{
		var expected = row.split("|");
		var cli = new Gitrlf.CommandLine(arguments_of(row));

		assert_cmpstr(cli.error != null ? cli.error : "", CompareOperator.EQ, expected[4]);

		if (expected[4] != "")
		{
			continue;
		}

		assert_true(cli.help == (expected[5] == "help"));

		if (cli.help)
		{
			continue;
		}

		assert_cmpstr(flags_of(cli), CompareOperator.EQ, expected[1]);
		assert_cmpstr(string.joinv(",", cli.refs), CompareOperator.EQ, expected[2]);
		assert_cmpstr(string.joinv(",", cli.paths), CompareOperator.EQ, expected[3]);
	}
}

private static void test_regex_parses_as_argparse()
{
	foreach (var row in REGEX_PARSES)
	{
		var expected = row.split("|");
		var arguments = expected[0] == "" ? new string[0] : expected[0].split("\t");
		var cli = new Gitrlf.CommandLine(arguments);

		assert_cmpstr(cli.error != null ? cli.error : "", CompareOperator.EQ, expected[7]);

		if (expected[7] != "")
		{
			continue;
		}

		assert_cmpstr(flags_of(cli), CompareOperator.EQ, expected[1]);
		assert_cmpstr(string.joinv(",", cli.refs), CompareOperator.EQ, expected[2]);
		assert_cmpstr(string.joinv(",", cli.paths), CompareOperator.EQ, expected[3]);
		assert_cmpstr(cli.text != null ? cli.text : "None", CompareOperator.EQ, expected[4]);
		assert_cmpstr(cli.regex != null ? cli.regex : "None", CompareOperator.EQ, expected[5]);
		assert_true(cli.ignore_case == (expected[6] == "i"));
	}
}

private static void test_text_and_ignore_case_parse_as_argparse()
{
	foreach (var row in TEXT_PARSES)
	{
		var expected = row.split("|");
		var arguments = expected[0] == "" ? new string[0] : expected[0].split("\t");
		var cli = new Gitrlf.CommandLine(arguments);

		assert_cmpstr(cli.error != null ? cli.error : "", CompareOperator.EQ, expected[6]);

		if (expected[6] != "")
		{
			continue;
		}

		assert_cmpstr(flags_of(cli), CompareOperator.EQ, expected[1]);
		assert_cmpstr(string.joinv(",", cli.refs), CompareOperator.EQ, expected[2]);
		assert_cmpstr(string.joinv(",", cli.paths), CompareOperator.EQ, expected[3]);
		assert_cmpstr(cli.text != null ? cli.text : "None", CompareOperator.EQ, expected[4]);
		assert_true(cli.ignore_case == (expected[5] == "i"));
	}
}

private static void test_version_prints_the_name_and_the_version()
{
	string output;
	string errors;

	assert_cmpint(run(Environment.get_current_dir(), { "--version" }, out output, out errors), CompareOperator.EQ, 0);
	assert_cmpstr(output, CompareOperator.EQ, "gitrlf %s\n".printf(Gitrlf.Config.PACKAGE_VERSION));
	assert_cmpstr(errors, CompareOperator.EQ, "");
}

private static void test_wrong_option_prints_usage_and_exits_with_two()
{
	try
	{
		var repo = Repo.create();
		repo.commit("first");

		string output;
		string errors;

		assert_cmpint(run(repo.path.get_path(), { "-x" }, out output, out errors), CompareOperator.EQ, 2);
		assert_cmpstr(output, CompareOperator.EQ, "");
		assert_cmpstr(errors, CompareOperator.EQ, Gitrlf.CommandLine.USAGE + "gitrlf: error: unrecognized arguments: -x\n");

		repo.remove();
	}
	catch (Error e)
	{
		Test.fail_printf("%s", e.message);
	}
}

}
