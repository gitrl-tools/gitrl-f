#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
provenance=${1:-$root/vendor/PROVENANCE}

url=$(sed -n 's/^ *URL: *//p' "$provenance" | head -n 1)
sha256=$(sed -n 's/^ *SHA-256: *//p' "$provenance" | head -n 1)

if [ -z "$url" ] || [ -z "$sha256" ]; then
	echo "no URL or SHA-256 in $provenance" >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

wget -q -O "$tmp/upstream.tar.xz" "$url"
echo "$sha256  $tmp/upstream.tar.xz" | sha256sum -c --quiet -
echo "fresh download of $url matches $provenance"
