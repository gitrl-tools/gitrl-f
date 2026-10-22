#!/bin/sh

set -eu

here=$(dirname "$(readlink -f "$0")")
root=$(dirname "$(dirname "$here")")
binary=${GITRLF_BINARY:-$root/_build/src/gitrlf/gitrlf}
out=${GITRLF_VISUAL_OUT:-$here/output}
home=$out/home
fixture=$home/fixture
reference=$here/reference/gitrlf-window.png

GSETTINGS_SCHEMA_DIR=${GSETTINGS_SCHEMA_DIR:-$root/_build/data}
export GSETTINGS_SCHEMA_DIR

GITG_LIST=490x345+206+51
GITRLF_LIST=490x345+191+76
FIRST_ROW="400 87"

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
	(cd "$fixture" && GITRLF_VISUAL_CLICK="$click" "$here/capture.sh" "$out/$name.png" "$home" "$@")
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
capture gitrlf-1 "$binary" -a
capture gitrlf-2 "$binary" -a

for name in gitg-1 gitg-2; do
	crop "$name" "$GITG_LIST" list
done

for name in gitrlf-1 gitrlf-2; do
	crop "$name" "$GITRLF_LIST" list
done

echo "--- a capture against itself, taken twice ---"
check "gitg list" "$out/gitg-1-list.png" "$out/gitg-2-list.png"
check "gitrlf window" "$out/gitrlf-1.png" "$out/gitrlf-2.png"

echo "--- the layout of gitrlf against gitg ---"
python3 "$here/measure.py" "$out/gitg-1-list.png" --json >"$out/gitg.json"
python3 "$here/measure.py" "$out/gitrlf-1-list.png" --json >"$out/gitrlf.json"
python3 "$here/compare-layout.py" "$out/gitg.json" "$out/gitrlf.json" || failed=1

echo "--- gitrlf against its reference window ---"

if [ "${GITRLF_VISUAL_UPDATE:-0}" = 1 ]; then
	cp "$out/gitrlf-1.png" "$reference"
	echo "  wrote $reference"
else
	check "window" "$out/gitrlf-1.png" "$reference"
fi

echo "--- self check: the layout comparison must see a stretched copy ---"
"$here/selfcheck.sh" "$out/gitrlf-1-list.png" "$out" || failed=1

if [ "$failed" -ne 0 ]; then
	echo "visual parity FAILED; the captures are in $out"
	exit 1
fi

echo "visual parity passed"
