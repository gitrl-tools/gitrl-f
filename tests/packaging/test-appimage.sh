#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
appimage=${1:-$(ls "$root"/gittree-*-x86_64.AppImage 2>/dev/null | head -1)}
image=${2:-ubuntu:24.04}

if [ ! -f "$appimage" ]; then
	echo "no AppImage found; run scripts/build-appimage.sh first" >&2
	exit 1
fi

appimage=$(readlink -f "$appimage")
version=$(basename "$appimage" | sed -n 's/^gittree-\([0-9.]*\)-x86_64\.AppImage$/\1/p')

echo "testing $(basename "$appimage") in $image"

docker run --rm -e GITTREE_VERSION="$version" \
	-v "$appimage:/tmp/gittree.AppImage:ro" "$image" sh -eu -c '
	export DEBIAN_FRONTEND=noninteractive
	export APPIMAGE_EXTRACT_AND_RUN=1

	apt-get update -qq
	apt-get install -y -qq git xvfb x11-utils >/dev/null
	apt-get install -y -qq libexpat1 libfontconfig1 libfreetype6 libfribidi0 libharfbuzz0b libwayland-client0 libx11-6 libxcb1 >/dev/null

	echo "--- the version ---"
	test "$(/tmp/gittree.AppImage --version)" = "gittree $GITTREE_VERSION"

	repo=/tmp/fixture
	git init -q "$repo"
	git -C "$repo" -c user.name=Tester -c user.email=tester@example.com commit -q --allow-empty -m first

	mkdir -p /tmp/.X11-unix
	chmod 1777 /tmp/.X11-unix
	Xvfb :7 -screen 0 1200x800x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
	server=$!

	echo "--- the window draws ---"
	cd "$repo"
	DISPLAY=:7 NO_AT_BRIDGE=1 /tmp/gittree.AppImage >/tmp/app.log 2>&1 &
	app=$!

	tries=0
	until DISPLAY=:7 xwininfo -root -tree 2>/dev/null | grep -q "\"fixture\""; do
		if ! kill -0 "$app" 2>/dev/null; then
			echo "gittree stopped before it drew a window:" >&2
			tail -20 /tmp/app.log >&2
			exit 1
		fi

		tries=$((tries + 1))

		if [ "$tries" -ge 60 ]; then
			echo "no window named fixture in 30 s:" >&2
			tail -20 /tmp/app.log >&2
			exit 1
		fi

		sleep 0.5
	done

	kill "$app" "$server"
'

echo "the AppImage runs and draws its window"
