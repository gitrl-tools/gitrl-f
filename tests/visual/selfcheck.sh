#!/bin/sh

set -eu

if [ $# -ne 3 ]; then
	echo "usage: $0 <region.png> <colour> <directory>" >&2
	exit 2
fi

region=$1
colour=$2
out=$3
here=$(dirname "$(readlink -f "$0")")
name=$(basename "$region" .png)
hex=${colour#\#}
blue=$((0x${hex#????} ^ 1))
changed=$(printf '#%s%02x' "${hex%??}" "$blue")

convert "$region" -fill "$changed" -opaque "$colour" "$out/$name-colour.png"
convert "$region" -roll +1+0 "$out/$name-moved.png"

failed=0

for kind in colour moved; do
	count=$("$here/compare.sh" "$region" "$out/$name-$kind.png")

	if [ "$count" -eq 0 ]; then
		echo "  SELF CHECK FAILED: the $kind perturbation of $name went unnoticed"
		failed=1
	else
		echo "  the $kind perturbation of $name differs by $count pixels (good)"
	fi
done

exit "$failed"
