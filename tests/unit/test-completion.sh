#!/bin/bash

set -euo pipefail

binary=$(readlink -f "$1")
script=$2

if [ ! -f /usr/share/bash-completion/bash_completion ]; then
	echo "SKIP: bash-completion is not installed"
	exit 77
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/completions"
cp "$script" "$tmp/completions/gitree"
ln -s gitree "$tmp/completions/git-tree"
export BASH_COMPLETION_USER_DIR=$tmp

git init -q -b master "$tmp/origin"
git -C "$tmp/origin" -c user.name=test -c user.email=test@example.com \
	commit -q --allow-empty -m one
git -C "$tmp/origin" branch feature/one
git clone -q "$tmp/origin" "$tmp/repo"
git -C "$tmp/repo" branch topic
git -C "$tmp/repo" tag v1
touch "$tmp/repo/notes.txt"
cd "$tmp/repo"

"$binary" --help | awk '/^    -/ {
	for (i = 1; i <= NF; i++) {
		word = $i
		sub(/,$/, "", word)
		if (word !~ /^-/)
			break
		print word
	}
}' | sort -u > "$tmp/options"

set +eu
. /usr/share/bash-completion/bash_completion

complete_line()
{
	local line=$1 spec

	read -ra COMP_WORDS <<< "$line"
	[[ $line == *" " ]] && COMP_WORDS+=("")
	COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
	COMP_LINE=$line
	COMP_POINT=${#line}
	COMPREPLY=()

	spec=$(complete -p "${COMP_WORDS[0]}" 2>/dev/null) || {
		_completion_loader "${COMP_WORDS[0]}"
		spec=$(complete -p "${COMP_WORDS[0]}")
	}
	spec=${spec##*-F }
	${spec%% *} "${COMP_WORDS[0]}" "${COMP_WORDS[COMP_CWORD]}" \
		"${COMP_WORDS[COMP_CWORD-1]}"
	printf '%s\n' "${COMPREPLY[@]}" | sed 's/ $//' | sort -u
}

status=0

expect()
{
	local line=$1 expected=$2 offered

	offered=$(complete_line "$line")
	if [ "$offered" = "$expected" ]; then
		echo "PASS: '$line'"
	else
		echo "FAIL: '$line'" >&2
		diff <(echo "$expected") <(echo "$offered") | sed 's/^/  /' >&2
		status=1
	fi
}

refs="master
origin/feature/one
origin/master
topic
v1"

expect "gitree -" "$(cat "$tmp/options")"
expect "gitree " "$refs"
expect "gitree master -- n" "notes.txt"
expect "git-tree -" "$(cat "$tmp/options")"
expect "git tree -" "$(cat "$tmp/options")"
expect "git tree to" "topic"

kept=$(
	_own() { :; }
	complete -F _own git-tree
	_completion_loader gitree
	complete -p git-tree
)
if [ "$kept" = "complete -F _own git-tree" ]; then
	echo "PASS: a completion of git-tree already defined is kept"
else
	echo "FAIL: loading the completion replaced '$kept'" >&2
	status=1
fi

exit $status
