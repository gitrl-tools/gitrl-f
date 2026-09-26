# The build container

## Purpose

The container is not the development environment. Development and daily use happen on the host, which is the target platform: Ubuntu 24.04 with gitg 44.

The container proves that `Build-Depends` is complete. The `Dockerfile` installs the build dependencies that `debian/control` declares, with `apt-get build-dep`, and nothing else that the build could use. The build therefore fails in the container when it needs software that `debian/control` does not name, even when that software is on the developer's machine. A Launchpad builder makes the same check.

A second layer adds what the tests need and the build does not: Xvfb, xdotool, a real `man` in place of the minimal image's placeholder, and an icon theme. `Dockerfile.visual` adds gitg 44 and ImageMagick for the pixel suite, on Ubuntu 24.04 only, because it compares gitree with that gitg.

## How to use it

```bash
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04
```

Each builds the image for that release and the `.deb` for it, into `_build/deb/`. A `.deb` links the libraries of the release it was built on, so each release needs its own image.

To run every test suite in a container:

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD:/src:ro" -w /src \
    gitree-build:24.04 sh -c 'meson setup /tmp/b && ninja -C /tmp/b && meson test -C /tmp/b'
```

The source tarball holds only the files that git tracks, so a file must be committed or staged before a build takes it.
