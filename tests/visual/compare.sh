#!/bin/sh

set -eu

if [ $# -ne 2 ]; then
	echo "usage: $0 <first.png> <second.png>" >&2
	exit 2
fi

status=0
count=$(compare -metric AE "$1" "$2" null: 2>&1) || status=$?

if [ "$status" -gt 1 ]; then
	echo "compare.sh: ImageMagick could not compare $1 and $2: $count" >&2
	exit 2
fi

echo "$count"
