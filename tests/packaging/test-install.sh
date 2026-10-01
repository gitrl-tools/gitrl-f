#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
deb=${1:-$(ls "$root"/_build/deb/gittree_*_amd64.deb 2>/dev/null | head -1)}

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

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
old=https://github.com/li9i/gittree/releases/download/v0.3.6
curl -fsSL -o "$tmp/gitree.deb" \
	"$old/gitree_0.3.6-1.ubuntu${series:-24.04}.1_amd64.deb"

docker run --rm -e GITTREE_VERSION="$upstream" \
	-v "$tmp/gitree.deb:/tmp/gitree.deb:ro" \
	-v "$deb:/tmp/gittree.deb:ro" "$image" sh -eu -c '
	export DEBIAN_FRONTEND=noninteractive

	rm -f /etc/dpkg/dpkg.cfg.d/excludes

	apt-get update -qq

	apt-get install -y -qq libglib2.0-bin desktop-file-utils >/dev/null
	command -v gsettings >/dev/null
	command -v desktop-file-validate >/dev/null

	echo "--- install ---"
	apt-get install -y -qq /tmp/gittree.deb

	echo "--- both names run ---"
	test "$(gittree --version)" = "gittree $GITTREE_VERSION"
	test "$(git-tree --version)" = "gittree $GITTREE_VERSION"
	test "$(readlink /usr/bin/git-tree)" = "gittree"

	echo "--- files are where the package said ---"
	test -x /usr/bin/gittree
	test -f /usr/share/applications/io.github.li9i.gittree.desktop
	test -f /usr/share/metainfo/io.github.li9i.gittree.metainfo.xml
	test -f /usr/share/man/man1/gittree.1.gz
	test -f /usr/share/man/man1/git-tree.1.gz
	for size in 128 64 48; do
		test -f "/usr/share/icons/hicolor/${size}x${size}/apps/io.github.li9i.gittree.png"
	done
	test -f /usr/share/icons/hicolor/symbolic/apps/io.github.li9i.gittree-symbolic.svg
	test -f /usr/share/bash-completion/completions/gittree
	test "$(readlink /usr/share/bash-completion/completions/git-tree)" = "gittree"

	echo "--- the schema was compiled on install ---"
	for schema in preferences.interface preferences.history state.window state.history; do
		gsettings list-schemas | grep -qx "io.github.li9i.gittree.$schema"
	done

	echo "--- the desktop entry is valid as installed ---"
	desktop-file-validate /usr/share/applications/io.github.li9i.gittree.desktop

	echo "--- remove ---"
	apt-get remove -y -qq gittree >/dev/null
	test ! -e /usr/bin/gittree
	test ! -e /usr/bin/git-tree
	test ! -e /usr/share/bash-completion/completions/gittree
	test ! -e /usr/share/bash-completion/completions/git-tree

	echo "--- purge ---"
	dpkg --purge gittree
	test ! -d /usr/share/doc/gittree

	if gsettings list-schemas | grep -qx "io.github.li9i.gittree.state.window"; then
		echo "schema still registered after purge" >&2
		exit 1
	fi

	echo "--- dpkg has no record left ---"
	if dpkg -l gittree 2>/dev/null | grep -q "^ii"; then
		echo "gittree still installed after purge" >&2
		exit 1
	fi

	echo "--- it takes the place of gitree ---"
	apt-get install -y -qq /tmp/gitree.deb >/dev/null
	apt-get install -y -qq /tmp/gittree.deb >/dev/null
	if dpkg -l gitree 2>/dev/null | grep -q "^ii"; then
		echo "gitree still installed beside gittree" >&2
		exit 1
	fi
	test "$(git-tree --version)" = "gittree $GITTREE_VERSION"
'

echo "install, remove, purge and the move from gitree clean"
