#!/bin/sh

set -eu

here=$(dirname "$(readlink -f "$0")")
root=$(dirname "$(dirname "$here")")
binary=${GITTREE_BINARY:-$root/_build/src/gittree/gittree}
out=${GITTREE_VISUAL_OUT:-$here/output}
home=$out/home
fixture=$home/fixture
reference=$here/reference/gittree-window.png

GSETTINGS_SCHEMA_DIR=${GSETTINGS_SCHEMA_DIR:-$root/_build/data}
export GSETTINGS_SCHEMA_DIR

LIST=490x345+206+51
FIRST_ROW="400 62"

for tool in Xvfb xwd convert compare xdotool dbus-run-session gitg python3 setsid; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "test-parity.sh: $tool is not installed" >&2
		exit 1
	fi
done

if ! python3 -c 'import PIL' 2>/dev/null; then
	echo "test-parity.sh: python3-pil is not installed" >&2
	exit 1
fi

if [ ! -x "$binary" ]; then
	echo "test-parity.sh: $binary is not built" >&2
	exit 1
fi

rm -rf "$out"
mkdir -p "$out"

Xvfb -displayfd 3 -screen 0 1400x900x24 -nolisten tcp 3>"$out/display" 2>"$out/xvfb.log" &
server=$!
trap 'kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true' EXIT

tries=0

until [ -s "$out/display" ]; do
	sleep 0.1
	tries=$((tries + 1))

	if [ "$tries" -ge 100 ]; then
		echo "test-parity.sh: Xvfb did not start; see $out/xvfb.log" >&2
		exit 1
	fi
done

DISPLAY=:$(cat "$out/display")
export DISPLAY
xdotool mousemove 1 899

capture() {
	name=$1
	shift
	rm -rf "$home"
	mkdir -p "$home/.cache" "$home/.config/glib-2.0/settings" "$home/.config/gtk-3.0" "$home/.local/share"
	cp "$here/settings.ini" "$home/.config/gtk-3.0/settings.ini"
	cp "$here/keyfile" "$home/.config/glib-2.0/settings/keyfile"
	"$here/fixture.sh" "$fixture"
	(cd "$fixture" && GITTREE_VISUAL_CLICK="$click" "$here/capture.sh" "$out/$name.png" "$home" "$@")
	echo "  captured $name"
}

check() {
	count=$("$here/compare.sh" "$2" "$3")
	echo "  $1: $count differing pixels"

	if [ "$count" -ne 0 ]; then
		failed=1
	fi
}

crop() {
	convert "$out/$1.png" -crop "$2" +repage "$out/$1-$3.png"

	if [ "$(convert "$out/$1-$3.png" -format %k info:)" -lt 16 ]; then
		echo "test-parity.sh: the $3 region of $1 is nearly blank; the region is wrong" >&2
		exit 1
	fi
}

failed=0

echo "--- capture ---"
click=
capture gitg-1 gitg "$fixture"
capture gitg-2 gitg "$fixture"
click=$FIRST_ROW
capture gittree-1 "$binary" -a
capture gittree-2 "$binary" -a

for name in gitg-1 gitg-2 gittree-1 gittree-2; do
	crop "$name" "$LIST" list
done

echo "--- a capture against itself, taken twice ---"
check "gitg list" "$out/gitg-1-list.png" "$out/gitg-2-list.png"
check "gittree window" "$out/gittree-1.png" "$out/gittree-2.png"

echo "--- gittree against gitg ---"
list=$("$here/compare.sh" "$out/gitg-1-list.png" "$out/gittree-1-list.png")
echo "  list: $list differing pixels"

if [ "$list" -ne 0 ]; then
	failed=1
	echo "--- what moved in the list ---"
	python3 "$here/measure.py" "$out/gitg-1-list.png" --json >"$out/gitg.json"
	python3 "$here/measure.py" "$out/gittree-1-list.png" --json >"$out/gittree.json"
	python3 - "$out/gitg.json" "$out/gittree.json" <<'PY'
import json
import sys

gitg = json.load(open(sys.argv[1]))
gittree = json.load(open(sys.argv[2]))

for key in sorted(gitg):
    if key != "dots" and gitg[key] != gittree[key]:
        print("  {}: gitg {}, gittree {}".format(key, gitg[key], gittree[key]))

for a, b in zip(gitg["dots"], gittree["dots"]):
    if a != b:
        print("  dot in row {}: gitg lane {} {}, gittree lane {} {}".format(a[0], a[1], a[2], b[1], b[2]))

if len(gitg["dots"]) != len(gittree["dots"]):
    print("  dots: gitg {}, gittree {}".format(len(gitg["dots"]), len(gittree["dots"])))
PY
fi

echo "--- gittree against its reference window ---"

if [ "${GITTREE_VISUAL_UPDATE:-0}" = 1 ]; then
	cp "$out/gittree-1.png" "$reference"
	echo "  wrote $reference"
else
	check "window" "$out/gittree-1.png" "$reference"
fi

echo "--- self check: the comparison must see a changed colour and a shift ---"
"$here/selfcheck.sh" "$out/gittree-1-list.png" '#c4a000' "$out" || failed=1

if [ "$failed" -ne 0 ]; then
	echo "visual parity FAILED; the captures are in $out"
	exit 1
fi

echo "visual parity passed"
