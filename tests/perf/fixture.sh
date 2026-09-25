#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <directory>" >&2
	exit 2
fi

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

stream_big() {
	awk '
	function commit(ref, msg, from, merge, path) {
		n++
		t += 60
		mark++
		printf "commit %s\nmark :%d\n", ref, mark
		printf "author A <a@example.com> %d +0000\ncommitter A <a@example.com> %d +0000\n", t, t
		printf "data %d\n%s\n", length(msg), msg
		if (from > 0) {
			printf "from :%d\n", from
		}
		if (merge > 0) {
			printf "merge :%d\n", merge
		}
		content = "line " n "\n"
		printf "M 100644 inline %s\ndata %d\n%s\n", path, length(content), content
	}
	BEGIN {
		t = 1600000000
		for (i = 0; i < 40; i++) {
			for (k = i * 1000; k < (i + 1) * 1000; k++) {
				commit("refs/heads/master", "Master change " k, master, 0, sprintf("src/file%d.cpp", k % 500))
				master = mark
				if (k == 39899) {
					v1 = mark
				}
				if (k == 39989) {
					v2 = mark
				}
			}
			tip = master
			for (j = 0; j < 25; j++) {
				commit("refs/heads/feature/f" i, "Feature " i " change " j, tip, 0, "feat/f" i ".cpp")
				tip = mark
			}
			feature[i] = tip
			if (i % 2 == 0) {
				commit("refs/heads/master", "Merge feature " i, master, tip, "merges.txt")
				master = mark
			}
		}
		for (i = 0; i < 20; i++) {
			printf "reset refs/remotes/origin/feature/f%d\nfrom :%d\n\n", i, feature[i]
		}
		printf "reset refs/tags/v1\nfrom :%d\n\nreset refs/tags/v2\nfrom :%d\n\n", v1, v2
	}'
}

stream_big100() {
	awk '
	BEGIN {
		for (n = 1; n <= 100000; n++) {
			t = 1600000000 + 60 * n
			msg = "Change " n
			content = "line " n "\n"
			printf "commit refs/heads/master\nmark :%d\n", n
			printf "author A <a@example.com> %d +0000\ncommitter A <a@example.com> %d +0000\n", t, t
			printf "data %d\n%s\n", length(msg), msg
			if (n > 1) {
				printf "from :%d\n", n - 1
			}
			printf "M 100644 inline src/file%d.cpp\ndata %d\n%s\n", n % 500, length(content), content
		}
		printf "reset refs/heads/side\nfrom :50000\n\n"
	}'
}

build() {
	mkdir "$1"
	git init -q -b master "$1"
	"$2" | git -C "$1" fast-import --quiet
	git -C "$1" reset -q --hard
}

mkdir -p "$1"
build "$1/big" stream_big
build "$1/big100" stream_big100
