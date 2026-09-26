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
share/applications/io.github.li9i.gitree.desktop
share/glib-2.0/schemas/io.github.li9i.gitree.gschema.xml
share/icons/hicolor/128x128/apps/io.github.li9i.gitree.png
share/icons/hicolor/48x48/apps/io.github.li9i.gitree.png
share/icons/hicolor/64x64/apps/io.github.li9i.gitree.png
share/icons/hicolor/symbolic/apps/io.github.li9i.gitree-symbolic.svg
share/man/man1/git-tree.1
share/man/man1/gitree.1
share/metainfo/io.github.li9i.gitree.metainfo.xml
LIST

if ! diff -u "$dest/expected" "$dest/installed"; then
	echo "test-meson-install.sh: the installed files differ from the list" >&2
	exit 1
fi

if [ "$(readlink bin/git-tree)" != "gitree" ]; then
	echo "test-meson-install.sh: bin/git-tree is not a link to gitree" >&2
	exit 1
fi

warnings=$(groff -man -ww -z share/man/man1/gitree.1 2>&1)

if [ -n "$warnings" ]; then
	echo "test-meson-install.sh: the manual page has warnings:" >&2
	echo "$warnings" >&2
	exit 1
fi

if ! MANPAGER=cat MANWIDTH=80 man -M "$dest$prefix/share/man" git-tree 2>/dev/null | grep -q "gitree - "; then
	echo "test-meson-install.sh: man git-tree does not show the page of gitree" >&2
	exit 1
fi

echo "installed files match the list, git-tree links to gitree, and man git-tree shows the page"
