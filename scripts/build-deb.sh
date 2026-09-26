#!/bin/sh

set -eu

version=${1:-24.04}

case "$version" in
	24.04) series=noble ;;
	26.04) series=resolute ;;
	*)
		echo "usage: $0 [24.04|26.04]" >&2
		exit 2
		;;
esac

cd "$(dirname "$0")/.."

docker build --target build --build-arg UBUNTU="$version" -t "gitree-build:$version" .
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD:/src" -w /src \
	"gitree-build:$version" ./docker/build-deb.sh "$series" "~ubuntu$version.1"
