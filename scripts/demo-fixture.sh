#!/bin/sh

set -eu

target=${1:?usage: demo-fixture.sh <directory>}

if [ -e "$target" ]; then
	echo "demo-fixture.sh: $target exists already; remove it or name another path" >&2
	exit 1
fi

mkdir -p "$target"
cd "$target"

export GIT_AUTHOR_NAME="Ada Lovelace"
export GIT_AUTHOR_EMAIL="ada@example.com"
export GIT_COMMITTER_NAME="Ada Lovelace"
export GIT_COMMITTER_EMAIL="ada@example.com"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

minutes=0

tick() {
	minutes=$((minutes + 11))

	stamp=$(printf '2026-07-20 %02d:%02d:00 +0200' \
		$((9 + minutes / 60)) $((minutes % 60)))

	GIT_AUTHOR_DATE=$stamp
	GIT_COMMITTER_DATE=$stamp

	export GIT_AUTHOR_DATE GIT_COMMITTER_DATE
}

commit() {
	tick
	printf '%s\n' "$2" >> "$1"
	git add -A
	git commit -q -m "$3"
}

tick
git init -q --initial-branch=main
git config user.name "Ada Lovelace"
git config user.email "ada@example.com"

commit README.md "A small expression language." "Start the project"
commit parser.py "def parse(text): pass" "Add the parser"
git tag v0.1

git checkout -q -b feature/lexer
commit lexer.py "def lex(text): pass" "Add the lexer"
commit test_lexer.py "def test_lex(): pass" "Test the lexer"

git checkout -q main
commit Makefile "test:" "Add the build rules"

git checkout -q -b feature/errors
commit errors.py "class ParseError(Exception): pass" "Report parse errors"

git checkout -q main
tick
git merge -q --no-ff --no-edit feature/lexer
commit parser.py "def parse_number(text): pass" "Parse numbers"

git checkout -q -b fix/empty-input
commit parser.py "def parse_empty(): return None" "Accept empty input"

git checkout -q main
commit README.md "Run make test." "Say how to run the tests"
git tag v0.2

git branch backup/before-errors feature/errors~1
git update-ref refs/remotes/origin/main main~1
git update-ref refs/remotes/origin/feature/lexer feature/lexer
git update-ref refs/remotes/origin/feature/errors feature/errors
