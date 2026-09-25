#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <directory>" >&2
	exit 2
fi

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="Ada Lane"
export GIT_AUTHOR_EMAIL="ada@example.com"
export GIT_COMMITTER_NAME="Ada Lane"
export GIT_COMMITTER_EMAIL="ada@example.com"

hour=0

change() {
	stamp
	printf '%s\n' "$2" >> "$1"
	git add "$1"
	git commit -q -m "$3"
}

merge() {
	stamp
	git merge -q --no-ff -m "$2" "$1"
}

stamp() {
	hour=$((hour + 1))
	GIT_AUTHOR_DATE="2024-03-04T$(printf '%02d' "$hour"):00:00+0100"
	GIT_COMMITTER_DATE=$GIT_AUTHOR_DATE
	export GIT_AUTHOR_DATE GIT_COMMITTER_DATE
}

rm -rf "$1"
git init -q --initial-branch=master "$1"
cd "$1"

git config gitg.mainline refs/heads/master
git remote add origin https://example.com/fixture.git

change README "A fixture for the lanes" "Start the project"
change parser.c "int parse(void);" "Add the parser"
git checkout -q -b feature/lanes
change lanes.c "void lanes(void);" "Draw the lanes"
git checkout -q master
change parser.c "int parse_all(void);" "Fix the parser"
git checkout -q feature/lanes
change lanes.c "void colour(void);" "Colour the lanes"
git checkout -q -b topic master~1
change layout.c "void layout(void);" "Try another layout"
git checkout -q master
merge feature/lanes "Merge feature/lanes"
git checkout -q -b feature/labels
change labels.c "void labels(void);" "Draw the labels"
git checkout -q topic
change layout.c "void tidy(void);" "Tidy the layout"
git checkout -q master
stamp
printf '%s\n' "gitree" "" "Shows the history of the refs you tick." "Each ref has a checkbox." > MANUAL
git add MANUAL
git commit -q -m "Write the manual"
git tag -a -m "First release" v1.0
git update-ref refs/remotes/origin/master HEAD
git checkout -q feature/labels
change labels.c "void round(void);" "Round the labels"
git update-ref refs/remotes/origin/feature/labels HEAD
git checkout -q topic
merge master "Merge master into topic"
git update-ref refs/remotes/origin/topic HEAD
git checkout -q -b release master
change VERSION "1.1" "Bump the version"
git tag v1.1
git checkout -q feature/labels
change labels.c "void space(void);" "Space the labels"
git checkout -q topic
change layout.c "void finish(void);" "Finish the layout"
