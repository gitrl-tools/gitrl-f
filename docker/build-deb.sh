#!/bin/sh

set -eu

series=${1:-}
suffix=${2:-}

src=/src

container_series=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")
target_series=${series:-noble}
if [ "$container_series" != "$target_series" ]; then
    echo "build-deb.sh: asked to build for '$target_series' but this container is '$container_series'." >&2
    echo "A .deb links this container's libraries, so the series must match." >&2
    echo "Build the image on that series first: docker build --build-arg UBUNTU=<ver> -t gitrlf-build:<ver> ." >&2
    exit 1
fi

full=$(dpkg-parsechangelog -l "$src/debian/changelog" -S Version)
version=${full%-*}
work=/tmp/gitrlf-build-deb
pkgdir="$work/gitrl-f-$version"

rm -rf "$work"
mkdir -p "$pkgdir"

git -C "$src" ls-files -z | tar -C "$src" --null -T - -cf - | tar -C "$pkgdir" -xf -

if [ -n "$series" ] || [ -n "$suffix" ]; then
    sed -i "1s|.*|gitrl-f ($full$suffix) $target_series; urgency=medium|" \
        "$pkgdir/debian/changelog"
fi

tar --exclude=./debian --sort=name --mtime="@$(git -C "$src" log -1 --format=%ct)" \
    --owner=0 --group=0 --numeric-owner -C "$pkgdir" -cf - . | gzip -n >"$work/gitrl-f_$version.orig.tar.gz"

cd "$pkgdir"

dpkg-buildpackage -us -uc

mkdir -p "$src/_build/deb"
cp "$work"/gitrl-f*.deb \
   "$work"/gitrl-f*.ddeb \
   "$work"/gitrl-f_*.dsc \
   "$work"/gitrl-f_*.orig.tar.gz \
   "$work"/gitrl-f_*.debian.tar.* \
   "$work"/gitrl-f_*.changes \
   "$work"/gitrl-f_*.buildinfo \
   "$src/_build/deb/" 2>/dev/null || true

echo "--- built artefacts ---"
ls -la "$src/_build/deb/"
