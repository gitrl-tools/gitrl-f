#!/bin/sh

set -eu

binary=$(readlink -f "$1")
repo=$(mktemp -d)

pids() {
	for pid in $(pgrep -x gitrlf || true); do
		[ "$(readlink "/proc/$pid/cwd")" = "$repo" ] && echo "$pid"
	done
	true
}

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

trap 'kill $(pids) 2>/dev/null || true; rm -rf "$repo" "$repo.fifo"' EXIT

git -C "$repo" init --quiet
git -C "$repo" -c user.name=Tester -c user.email=tester@example.com \
	commit --quiet --allow-empty -m first
cd "$repo"

out=$(timeout 10 script -qec "'$binary'; echo returned \$?" /dev/null || true)
case $out in
*"returned 0"*) ;;
*) fail "from a terminal, the prompt did not come back: $out" ;;
esac
timeout 10 xdotool search --sync --onlyvisible --name "$(basename "$repo")" \
	>/dev/null || fail "no window after the terminal closed"
[ -n "$(pids)" ] || fail "no gitrlf process after the terminal closed"
echo "ok - from a terminal, the prompt comes back and the window stays"
kill $(pids)

fifo=$repo.fifo
mkfifo "$fifo"
cat "$fifo" >/dev/null &
reader=$!
timeout 10 script -qec "'$binary' 9>'$fifo'" /dev/null >/dev/null || true
timeout 10 xdotool search --sync --onlyvisible --name "$(basename "$repo")" \
	>/dev/null || fail "no window from the start with a pipe"
kill -0 "$reader" 2>/dev/null || fail "the pipe closed while the window is open"
kill $(pids)
timeout 5 sh -c "while kill -0 $reader 2>/dev/null; do sleep 0.1; done" \
	|| fail "the pipe stayed open after the window closed"
echo "ok - a pipe from the starter stays open while the window is open"

status=0
timeout 5 script -qec "'$binary' --foreground" /dev/null >/dev/null || status=$?
[ "$status" = 124 ] || fail "--foreground gave the prompt back, status $status"
echo "ok - --foreground keeps the terminal until the window closes"
kill $(pids) 2>/dev/null || true

out=$(script -qec "'$binary' -S ''" /dev/null || true)
case $out in
*"the text is empty"*) ;;
*) fail "an option error did not reach the terminal: $out" ;;
esac
echo "ok - an option error still reaches the terminal"
