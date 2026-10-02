#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
orig=${1:-$(ls "$root"/_build/deb/gitrl-f_*.orig.tar.gz 2>/dev/null | head -1)}

if [ ! -f "$orig" ]; then
	echo "no orig tarball found; run scripts/build-deb.sh first" >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

tar -tzf "$orig" | sed 's|^\./||' | grep -v '/$' | grep -v '^$' | sort >"$tmp/packed"
git -C "$root" ls-files | grep -v '^debian/' | sort >"$tmp/tracked"

if ! diff -u "$tmp/tracked" "$tmp/packed"; then
	echo "test-orig.sh: $(basename "$orig") does not hold exactly the tracked files" >&2
	exit 1
fi

echo "$(basename "$orig") holds exactly the $(wc -l <"$tmp/packed") tracked files"
