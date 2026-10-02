#!/bin/sh

set -eu

if [ $# -lt 1 ]; then
	echo "usage: $0 <repository> [<options>] [<ref>...] [-- <path>...]" >&2
	exit 2
fi

here=$(dirname "$(readlink -f "$0")")
root=$(dirname "$(dirname "$here")")
dump=${GITRLF_DUMP:-$root/_build/tests/gitrlf-dump}

if [ ! -x "$dump" ]; then
	echo "compare.sh: $dump is not built; run scripts/dev.sh build first" >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 "$here/dump-prototype.py" "$@" >"$tmp/prototype.txt" 2>"$tmp/prototype.err" || {
	cat "$tmp/prototype.err" >&2
	exit 1
}
GSETTINGS_SCHEMA_DIR=${GSETTINGS_SCHEMA_DIR:-$root/_build/data} GSETTINGS_BACKEND=memory \
	"$dump" "$@" >"$tmp/gitrlf.txt" 2>"$tmp/gitrlf.err" || {
	cat "$tmp/gitrlf.err" >&2
	exit 1
}

if diff -u "$tmp/prototype.txt" "$tmp/gitrlf.txt" >"$tmp/diff.txt"; then
	echo "IDENTICAL: $(tail -n 1 "$tmp/gitrlf.txt")"
	exit 0
fi

echo "DIFFERENT:"
head -n 40 "$tmp/diff.txt"
echo "prototype: $(tail -n 1 "$tmp/prototype.txt")"
echo "gitrlf:   $(tail -n 1 "$tmp/gitrlf.txt")"
exit 1
