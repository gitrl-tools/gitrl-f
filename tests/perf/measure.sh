#!/bin/sh

set -eu

if [ $# -lt 1 ]; then
	echo "usage: $0 <directory with big and big100> [<runs>]" >&2
	exit 2
fi

here=$(dirname "$(readlink -f "$0")")
root=$(dirname "$(dirname "$here")")
repositories=$1
runs=${2:-3}
bench=${GITTREE_BENCH:-$root/_build/tests/gittree-bench}
dotfiles=${GITTREE_DOTFILES:-$HOME/dotfiles}
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT

if [ ! -x "$bench" ]; then
	echo "measure.sh: $bench is not built; run scripts/dev.sh build first" >&2
	exit 1
fi

for name in big big100; do
	if [ ! -d "$repositories/$name" ]; then
		echo "measure.sh: $repositories/$name is missing; make it with tests/perf/fixture.sh" >&2
		exit 1
	fi
done

private() {
	rm -rf "$home/run"
	mkdir -p "$home/run"
	env GITTREE_DOTFILES="$dotfiles" HOME="$home/run" XDG_CACHE_HOME="$home/run/.cache" \
		XDG_CONFIG_HOME="$home/run/.config" XDG_DATA_HOME="$home/run/.local/share" \
		GSETTINGS_SCHEMA_DIR="$root/_build/data" GSETTINGS_BACKEND=memory GIT_CONFIG_GLOBAL=/dev/null \
		GTK_THEME=Adwaita sh "$root/tests/ui/run-xvfb.sh" "$@" 2>"$home/errors" || {
		cat "$home/errors" >&2
		exit 1
	}
}

for name in big big100; do
	case $name in
	big) only=refs/heads/feature/f39 ;;
	big100) only=refs/heads/side ;;
	esac

	run=1

	while [ "$run" -le "$runs" ]; do
		echo "--- $name, run $run, gittree"
		private "$bench" --window "$repositories/$name" "$only"
		echo "--- $name, run $run, prototype"
		private python3 "$here/prototype-window.py" "$repositories/$name" "$only"
		run=$((run + 1))
	done
done
