#!/bin/sh

set -eu

if [ $# -lt 3 ]; then
	echo "usage: $0 <output.png> <home> <command> [<argument>...]" >&2
	exit 2
fi

output=$1
home=$2
shift 2
program=$1
here=$(dirname "$(readlink -f "$0")")

: "${DISPLAY:?capture.sh needs DISPLAY set to a private X server}"

setsid env -i \
	PATH=/usr/bin:/bin \
	HOME="$home" \
	XDG_CACHE_HOME="$home/.cache" \
	XDG_CONFIG_HOME="$home/.config" \
	XDG_DATA_HOME="$home/.local/share" \
	DISPLAY="$DISPLAY" \
	LANG=C.UTF-8 \
	LC_ALL=C.UTF-8 \
	TZ=UTC \
	GTK_THEME=Adwaita \
	GTK_OVERLAY_SCROLLING=0 \
	NO_AT_BRIDGE=1 \
	GTK_A11Y=none \
	GSETTINGS_BACKEND=keyfile \
	GIO_USE_VFS=local \
	GIT_CONFIG_NOSYSTEM=1 \
	${GSETTINGS_SCHEMA_DIR:+GSETTINGS_SCHEMA_DIR="$GSETTINGS_SCHEMA_DIR"} \
	dbus-run-session --config-file="$here/session.conf" -- "$@" >"$output.log" 2>&1 &
app=$!

stop() {
	kill -TERM "-$app" 2>/dev/null || true
	waited=0

	while kill -0 "-$app" 2>/dev/null; do
		if [ "$waited" -ge 50 ]; then
			kill -KILL "-$app" 2>/dev/null || true
		fi

		sleep 0.1
		waited=$((waited + 1))
	done

	wait "$app" 2>/dev/null || true
}

settle() {
	previous=
	tries=0

	while :; do
		sleep 1
		tries=$((tries + 1))

		if ! kill -0 "$app" 2>/dev/null; then
			echo "capture.sh: $program stopped before it drew a window; see $output.log" >&2
			exit 1
		fi

		xwd -root -silent | convert xwd:- "$output"
		current=$(md5sum <"$output")

		if [ -n "$previous" ] && [ "$current" = "$previous" ] && [ "$(convert "$output" -format %k info:)" -gt 2 ]; then
			break
		fi

		if [ "$tries" -ge 30 ]; then
			echo "capture.sh: the screen did not settle in 30 s" >&2
			exit 1
		fi

		previous=$current
	done
}

trap stop EXIT

settle

if [ -n "${GITRLF_VISUAL_CLICK:-}" ]; then
	xdotool mousemove $GITRLF_VISUAL_CLICK click 1 mousemove restore
	settle
fi
