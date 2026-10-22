#!/bin/sh

set -eu

if [ $# -ne 2 ]; then
	echo "usage: $0 <region.png> <directory>" >&2
	exit 2
fi

region=$1
out=$2
here=$(dirname "$(readlink -f "$0")")
name=$(basename "$region" .png)

convert "$region" -scale 130% "$out/$name-stretched.png"
python3 "$here/measure.py" "$region" --json >"$out/$name.json"
python3 "$here/measure.py" "$out/$name-stretched.png" --json >"$out/$name-stretched.json"

if python3 "$here/compare-layout.py" "$out/$name.json" "$out/$name-stretched.json" >"$out/$name-stretched.txt"; then
	echo "  SELF CHECK FAILED: the stretched copy of $name went unnoticed"
	exit 1
fi

echo "  the stretched copy of $name has another layout (good)"
