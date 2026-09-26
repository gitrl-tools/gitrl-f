#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(readlink -f "$0")")")

scene=${1:-all}

binary=$root/_build/src/gitree/gitree

case "$scene" in
ticks|pane|still)
	scenes=$scene
	;;
all)
	scenes="ticks pane still"
	;;
*)
	echo "usage: capture-demo.sh [ticks|pane|still|all]" >&2
	exit 2
	;;
esac

if [ ! -x "$binary" ]; then
	echo "capture-demo.sh: gitree not built; run scripts/dev.sh build first" >&2
	exit 1
fi

for tool in xvfb-run xdotool xwd ffmpeg convert; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "capture-demo.sh: $tool is not installed" >&2
		exit 1
	fi
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/home"
"$root/scripts/demo-fixture.sh" "$work/home/parser"

record() {
	env -i PATH=/usr/bin:/bin HOME="$work/home" LANG=C.UTF-8 TZ=Europe/Berlin \
		GTK_THEME=Adwaita GTK_OVERLAY_SCROLLING=0 NO_AT_BRIDGE=1 GTK_A11Y=none \
		GSETTINGS_SCHEMA_DIR="$root/_build/data" GSETTINGS_BACKEND=memory GIO_USE_VFS=local \
		xvfb-run -a --server-args="-screen 0 1210x781x24 -nolisten tcp" \
		dbus-run-session --config-file="$root/tests/visual/session.conf" -- sh -c '
		set -eu
		output=$1
		binary=$2
		repo=$3
		scene=$4
		seconds=$5

		glide() {
			i=1
			while [ "$i" -le 10 ]; do
				xdotool mousemove \
					$(( $1 + ($3 - $1) * i / 10 )) \
					$(( $2 + ($4 - $2) * i / 10 ))
				sleep 0.04
				i=$((i + 1))
			done
		}

		cd "$repo"
		"$binary" >/dev/null 2>&1 &
		app=$!

		sleep 4

		window=$(xdotool search --onlyvisible --name "^parser$" | head -1)
		xdotool windowsize "$window" 1210 781
		xdotool windowmove "$window" 0 0
		xdotool mousemove 700 700

		sleep 2

		if [ "$scene" = still ]; then
			xdotool mousemove 700 113 click --repeat 2 --delay 80 1
			sleep 1
			xdotool mousemove 1200 20
			sleep 2
			xwd -root -silent | convert xwd:- "$output"
			kill "$app"
			wait "$app" 2>/dev/null || true
			exit 0
		fi

		ffmpeg -y -loglevel error -f x11grab -draw_mouse 1 \
		       -video_size 1210x781 -framerate 10 -i "$DISPLAY" -t "$seconds" \
		       -c:v ffv1 "$output" &
		grab=$!

		sleep 1.5

		case "$scene" in
		ticks)
			glide 700 700 21 399
			xdotool click 1
			sleep 2.5

			glide 21 399 33 205
			xdotool click 1
			sleep 2.5

			glide 33 205 33 233
			xdotool click 1
			sleep 2.5

			xdotool click 1
			sleep 2.5

			glide 33 233 70 288
			xdotool click 1
			sleep 3.0
			;;
		pane)
			glide 700 700 700 113
			xdotool click --repeat 2 --delay 80 1
			sleep 3.0

			glide 700 113 700 213
			xdotool click --repeat 2 --delay 80 1
			sleep 3.0

			xdotool key Escape
			sleep 2.5
			;;
		esac

		wait "$grab"

		kill "$app" 2>/dev/null || true
		wait "$app" 2>/dev/null || true
	' sh "$1" "$binary" "$work/home/parser" "$2" "$3"
}

encode() {
	video=$1
	output=$2

	rm -rf "$work/frames" "$work/marked"
	mkdir -p "$work/frames" "$work/marked"

	ffmpeg -y -loglevel error -i "$video" -vf fps=10 "$work/frames/%04d.png"

	total=$(find "$work/frames" -name '*.png' | wc -l)
	index=1

	for frame in "$work"/frames/*.png; do
		filled=$(( 1210 * index / total - 1 ))

		if [ "$filled" -lt 0 ]; then
			filled=0
		fi

		convert "$frame" -fill "#3a8f94" -draw "rectangle 0,776 $filled,780" \
		        "$work/marked/$(basename "$frame")"

		index=$((index + 1))
	done

	ffmpeg -y -loglevel error -framerate 10 -i "$work/marked/%04d.png" \
	       -vf "palettegen=max_colors=128:stats_mode=diff" "$work/palette.png"

	ffmpeg -y -loglevel error -framerate 10 -i "$work/marked/%04d.png" -i "$work/palette.png" \
	       -lavfi "paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" "$output"
}

mkdir -p "$root/docs/screenshots"

for name in $scenes; do
	case "$name" in
	still)
		record "$root/docs/screenshots/gitree.png" still 0
		echo "captured $root/docs/screenshots/gitree.png"
		continue
		;;
	ticks)
		seconds=18
		;;
	pane)
		seconds=14
		;;
	esac

	output=$root/docs/screenshots/demo-$name.gif

	record "$work/$name.mkv" "$name" "$seconds"
	encode "$work/$name.mkv" "$output"

	echo "captured $output"
done
