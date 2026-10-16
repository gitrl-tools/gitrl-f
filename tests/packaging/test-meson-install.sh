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
bin/gitf
bin/gitrlf
share/applications/io.github.li9i.gitrlf.desktop
share/bash-completion/completions/gitf
share/bash-completion/completions/gitrlf
share/gitrl-f/alias-link.sh
share/glib-2.0/schemas/io.github.li9i.gitrlf.gschema.xml
share/icons/hicolor/128x128/apps/io.github.li9i.gitrlf.png
share/icons/hicolor/48x48/apps/io.github.li9i.gitrlf.png
share/icons/hicolor/64x64/apps/io.github.li9i.gitrlf.png
share/icons/hicolor/symbolic/apps/io.github.li9i.gitrlf-symbolic.svg
share/man/man1/gitf.1
share/man/man1/gitrlf.1
share/metainfo/io.github.li9i.gitrlf.metainfo.xml
LIST

if ! diff -u "$dest/expected" "$dest/installed"; then
	echo "test-meson-install.sh: the installed files differ from the list" >&2
	exit 1
fi

links="bin/gitf share/bash-completion/completions/gitf share/man/man1/gitf.1"

for link in $links; do
	if ! cmp -s "$link" "$(dirname "$link")/gitrlf${link##*/gitf}"; then
		echo "test-meson-install.sh: $link is not the same as gitrlf" >&2
		exit 1
	fi
done

warnings=$(groff -man -ww -z share/man/man1/gitrlf.1 2>&1)

if [ -n "$warnings" ]; then
	echo "test-meson-install.sh: the manual page has warnings:" >&2
	echo "$warnings" >&2
	exit 1
fi

DESTDIR=$dest share/gitrl-f/alias-link.sh remove

for link in $links; do
	if [ -e "$link" ] || [ -L "$link" ]; then
		echo "test-meson-install.sh: the removal left $link" >&2
		exit 1
	fi
done

keeps_other()
{
	before=$(ls -l bin/gitf)
	meson install -C "$build" --no-rebuild --quiet --destdir "$dest" \
		>/dev/null
	DESTDIR=$dest share/gitrl-f/alias-link.sh remove

	if [ "$(ls -l bin/gitf)" != "$before" ]; then
		echo "test-meson-install.sh: another bin/gitf was changed" >&2
		exit 1
	fi

	for link in $links; do
		if [ "$link" != bin/gitf ] && [ -e "$link" ]; then
			echo "test-meson-install.sh: $link beside another bin/gitf" >&2
			exit 1
		fi
	done

	rm bin/gitf
}

echo other >bin/gitf
keeps_other
ln -s /bin/true bin/gitf
keeps_other

echo "installed files match the list, the manual page has no warnings," \
	"and a gitf of another owner is kept"
