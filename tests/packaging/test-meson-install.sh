#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <build directory>" >&2
	exit 2
fi

build=$1
dest=$(mktemp -d)
trap 'rm -rf "$dest"' EXIT

meson install -C "$build" --no-rebuild --quiet --destdir "$dest" >/dev/null

prefix=$(meson introspect "$build" --buildoptions | python3 -c 'import json, sys; print([o["value"] for o in json.load(sys.stdin) if o["name"] == "prefix"][0])')

cd "$dest$prefix"

find . -type f -o -type l | sed 's|^\./||' | sort >"$dest/installed"

sort >"$dest/expected" <<'LIST'
bin/git-tree
bin/gitree
share/glib-2.0/schemas/io.github.li9i.gitree.gschema.xml
LIST

if ! diff -u "$dest/expected" "$dest/installed"; then
	echo "test-meson-install.sh: the installed files differ from the list" >&2
	exit 1
fi

if [ "$(readlink bin/git-tree)" != "gitree" ]; then
	echo "test-meson-install.sh: bin/git-tree is not a link to gitree" >&2
	exit 1
fi

echo "installed files match the list, and git-tree links to gitree"
