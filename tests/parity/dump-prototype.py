#!/usr/bin/env python3
"""Print what the Python prototype of git tree shows for a repository.

The prototype lived in ~/dotfiles as git/.local/bin/git-tree. This script
reads it from commit 5ccd222 with git show, so it still runs after the file
is removed. It uses the prototype's own functions to read the refs and the
history, to resolve the ticks and to find the commits a tick reaches, and
prints the same lines as gitrlf-dump:

    <hash> TAB <parents that the graph joins> TAB <ticked refs at the commit>
    Showing N of M commits

The prototype imports GTK, but these functions do not open a display.

    dump-prototype.py <repository> [<options>] [<ref>...] [-- <path>...]
"""

import os
import subprocess
import sys
import types

DOTFILES = os.environ.get("GITRLF_DOTFILES", os.path.expanduser("~/dotfiles"))
PROTOTYPE = "5ccd222:git/.local/bin/git-tree"


def load():
    source = subprocess.run(
        ["git", "-C", DOTFILES, "show", PROTOTYPE], capture_output=True, check=True, text=True
    ).stdout
    module = types.ModuleType("git_tree")
    exec(compile(source, "git-tree", "exec"), module.__dict__)
    return module


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2

    repository = sys.argv[1]
    arguments = sys.argv[2:]
    prototype = load()
    os.chdir(repository)
    options, paths = prototype.parse_args(arguments)

    if not (options.all or options.local or options.remotes or options.tags or options.refs):
        options, paths = prototype.parse_args(["-a"] + arguments)

    common = prototype.git("rev-parse", "--path-format=absolute", "--git-common-dir").strip()
    refs = prototype.read_refs()
    stored = prototype.load_ticks(os.path.join(common, prototype.TICKS_FILE), refs)

    try:
        ticks = prototype.resolve_ticks(options, refs, stored)
    except prototype.UnknownRef as error:
        print("dump-prototype.py: no ref matches '{}'".format(error), file=sys.stderr)
        return 1

    tips = sorted({ref.sha for ref in refs})
    history = prototype.log(tips, paths) if tips else []
    by_sha = {commit.sha: commit for commit in history}
    entry = {}

    for tip in tips:
        if tip not in by_sha:
            entry[tip] = prototype.git("rev-list", "-1", tip, "--", *paths).strip() or None

    starts = [ref.sha if ref.sha in by_sha else entry.get(ref.sha) for ref in refs if ref.name in ticks]
    seen = prototype.reach([start for start in starts if start], by_sha)
    commits = [commit for commit in history if commit.sha in seen]
    shown = {commit.sha for commit in commits}

    for commit in commits:
        parents = [parent for parent in commit.parents if parent in shown]
        labels = sorted(ref.name for ref in refs if ref.sha == commit.sha and ref.name in ticks)
        print("{}\t{}\t{}".format(commit.sha, " ".join(parents), ",".join(labels)))

    print("Showing {} of {} commits".format(len(commits), len(history)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
