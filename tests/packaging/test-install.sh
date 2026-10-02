#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
deb=${1:-$(ls "$root"/_build/deb/gitrl-f_*_amd64.deb 2>/dev/null | head -1)}

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
old=https://github.com/li9i/gitrl-f/releases/download/v0.4.0
curl -fsSL -o "$tmp/gittree.deb" \
	"$old/gittree_0.4.0-1.ubuntu${series:-24.04}.1_amd64.deb"

docker run --rm -e GITRLF_VERSION="$upstream" \
	-v "$tmp/gittree.deb:/tmp/gittree.deb:ro" \
	-v "$deb:/tmp/gitrlf.deb:ro" "$image" sh -eu -c '
	export DEBIAN_FRONTEND=noninteractive

	rm -f /etc/dpkg/dpkg.cfg.d/excludes

	apt-get update -qq

	apt-get install -y -qq libglib2.0-bin desktop-file-utils >/dev/null
	command -v gsettings >/dev/null
	command -v desktop-file-validate >/dev/null

	echo "--- install ---"
	apt-get install -y -qq /tmp/gitrlf.deb

	echo "--- the command runs ---"
	test "$(gitrlf --version)" = "gitrlf $GITRLF_VERSION"

	echo "--- files are where the package said ---"
	test -x /usr/bin/gitrlf
	test -f /usr/share/applications/io.github.li9i.gitrlf.desktop
	test -f /usr/share/metainfo/io.github.li9i.gitrlf.metainfo.xml
	test -f /usr/share/man/man1/gitrlf.1.gz
	for size in 128 64 48; do
		test -f "/usr/share/icons/hicolor/${size}x${size}/apps/io.github.li9i.gitrlf.png"
	done
	test -f /usr/share/icons/hicolor/symbolic/apps/io.github.li9i.gitrlf-symbolic.svg
	test -f /usr/share/bash-completion/completions/gitrlf

	echo "--- the schema was compiled on install ---"
	for schema in preferences.interface preferences.history state.window state.history; do
		gsettings list-schemas | grep -qx "io.github.li9i.gitrlf.$schema"
	done

	echo "--- the desktop entry is valid as installed ---"
	desktop-file-validate /usr/share/applications/io.github.li9i.gitrlf.desktop

	echo "--- remove ---"
	apt-get remove -y -qq gitrl-f >/dev/null
	test ! -e /usr/bin/gitrlf
	test ! -e /usr/share/bash-completion/completions/gitrlf

	echo "--- purge ---"
	dpkg --purge gitrl-f
	test ! -d /usr/share/doc/gitrl-f

	if gsettings list-schemas | grep -qx "io.github.li9i.gitrlf.state.window"; then
		echo "schema still registered after purge" >&2
		exit 1
	fi

	echo "--- dpkg has no record left ---"
	if dpkg -l gitrl-f 2>/dev/null | grep -q "^ii"; then
		echo "gitrl-f still installed after purge" >&2
		exit 1
	fi

	echo "--- it takes the place of gittree ---"
	apt-get install -y -qq /tmp/gittree.deb >/dev/null
	apt-get install -y -qq /tmp/gitrlf.deb >/dev/null
	if dpkg -l gittree 2>/dev/null | grep -q "^ii"; then
		echo "gittree still installed beside gitrl-f" >&2
		exit 1
	fi
	test "$(gitrlf --version)" = "gitrlf $GITRLF_VERSION"
'

echo "install, remove, purge and the move from gitree clean"
