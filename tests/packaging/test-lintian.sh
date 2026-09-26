#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
changes=${1:-$(ls "$root"/_build/deb/gitree_*_amd64.changes 2>/dev/null | head -1)}

if [ ! -f "$changes" ]; then
	echo "no .changes found; run scripts/build-deb.sh first" >&2
	exit 1
fi

echo "--- overridden tags (gitree declares none) ---"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
	-v "$root:/src" -w /src gitree-build:24.04 \
	lintian --pedantic --show-overrides "${changes#$root/}" 2>&1 | grep '^O:' || true

echo "--- tags (expect binary-nmu-debian-revision-in-source only, from the ~ubuntuNN.NN.1 suffix) ---"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
	-v "$root:/src" -w /src gitree-build:24.04 \
	lintian --pedantic --info "${changes#$root/}"

echo "lintian clean"
