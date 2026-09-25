#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(readlink -f "$0")")")
build=$root/_build
caller=$(pwd)

cd "$root"

configure() {
	[ -d "$build" ] || meson setup _build
}

case "${1:-build}" in
setup)
	configure
	;;
build)
	configure
	ninja -C _build
	;;
test)
	configure
	ninja -C _build
	meson test -C _build --print-errorlogs ${2:+--suite $2}
	;;
run)
	configure
	ninja -C _build
	shift
	cd "$caller"
	GSETTINGS_SCHEMA_DIR="$build/data" exec "$build/src/gitree/git-tree" "$@"
	;;
clean)
	rm -rf "$build"
	;;
*)
	echo "usage: $0 {setup|build|test|run|clean}" >&2
	exit 2
	;;
esac
