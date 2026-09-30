#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
deb=${1:-$(ls "$root"/_build/deb/gitree_*_amd64.deb 2>/dev/null | head -1)}

if [ ! -f "$deb" ]; then
	echo "no .deb found; run scripts/build-deb.sh first" >&2
	exit 1
fi

deb=$(readlink -f "$deb")
full=$(dpkg-deb -f "$deb" Version)
upstream=${full%%-*}
series=$(echo "$full" | sed -n 's/.*~ubuntu\([0-9][0-9]\.[0-9][0-9]\).*/\1/p')
image=ubuntu:${series:-24.04}

echo "testing $(basename "$deb") in $image"

docker run --rm -e GITREE_VERSION="$upstream" \
	-v "$deb:/tmp/gitree.deb:ro" "$image" sh -eu -c '
	export DEBIAN_FRONTEND=noninteractive

	rm -f /etc/dpkg/dpkg.cfg.d/excludes

	apt-get update -qq

	apt-get install -y -qq libglib2.0-bin desktop-file-utils >/dev/null
	command -v gsettings >/dev/null
	command -v desktop-file-validate >/dev/null

	echo "--- install ---"
	apt-get install -y -qq /tmp/gitree.deb

	echo "--- both names run ---"
	test "$(gitree --version)" = "gitree $GITREE_VERSION"
	test "$(git-tree --version)" = "gitree $GITREE_VERSION"
	test "$(readlink /usr/bin/git-tree)" = "gitree"

	echo "--- files are where the package said ---"
	test -x /usr/bin/gitree
	test -f /usr/share/applications/io.github.li9i.gitree.desktop
	test -f /usr/share/metainfo/io.github.li9i.gitree.metainfo.xml
	test -f /usr/share/man/man1/gitree.1.gz
	test -f /usr/share/man/man1/git-tree.1.gz
	for size in 128 64 48; do
		test -f "/usr/share/icons/hicolor/${size}x${size}/apps/io.github.li9i.gitree.png"
	done
	test -f /usr/share/icons/hicolor/symbolic/apps/io.github.li9i.gitree-symbolic.svg
	test -f /usr/share/bash-completion/completions/gitree
	test "$(readlink /usr/share/bash-completion/completions/git-tree)" = "gitree"

	echo "--- the schema was compiled on install ---"
	for schema in preferences.interface preferences.history state.window state.history; do
		gsettings list-schemas | grep -qx "io.github.li9i.gitree.$schema"
	done

	echo "--- the desktop entry is valid as installed ---"
	desktop-file-validate /usr/share/applications/io.github.li9i.gitree.desktop

	echo "--- remove ---"
	apt-get remove -y -qq gitree >/dev/null
	test ! -e /usr/bin/gitree
	test ! -e /usr/bin/git-tree
	test ! -e /usr/share/bash-completion/completions/gitree
	test ! -e /usr/share/bash-completion/completions/git-tree

	echo "--- purge ---"
	dpkg --purge gitree
	test ! -d /usr/share/doc/gitree

	if gsettings list-schemas | grep -qx "io.github.li9i.gitree.state.window"; then
		echo "schema still registered after purge" >&2
		exit 1
	fi

	echo "--- dpkg has no record left ---"
	if dpkg -l gitree 2>/dev/null | grep -q "^ii"; then
		echo "gitree still installed after purge" >&2
		exit 1
	fi
'

echo "install, remove and purge clean"
