# The build container

## Purpose

The container is not the development environment. Development and daily use happen on the host, which is the target platform: Ubuntu 24.04 with gitg 44.

The container proves that `Build-Depends` is complete. The `Dockerfile` has two stages. The `build` stage installs the packaging tools and the build dependencies that `debian/control` declares, with `apt-get build-dep`, and nothing else. The packages are built in it, so the build fails when it needs software that `debian/control` does not name, even when that software is on the developer's machine. A Launchpad builder makes the same check.

The `test` stage adds what the tests need and the build does not: Xvfb, xdotool, a real `man` in place of the minimal image's placeholder, and an icon theme. `Dockerfile.visual` adds gitg 44 and ImageMagick to it for the pixel suite, on Ubuntu 24.04 only, because it compares gitree with that gitg.

## How to use it

```bash
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04
```

Each builds the `build` stage for that release as `gitree-build:<release>`, and the `.deb` in it, into `_build/deb/`. A `.deb` links the libraries of the release it was built on, so each release needs its own image.

To run every test suite in a container:

```bash
docker build --build-arg UBUNTU=24.04 -t gitree-test:24.04 .
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD:/src:ro" -w /src \
    gitree-test:24.04 sh -c 'meson setup /tmp/b && ninja -C /tmp/b && meson test -C /tmp/b'
```

To run the pixel suite:

```bash
docker build -f Dockerfile.visual -t gitree-visual:24.04 .
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD:/src:ro" -w /src \
    gitree-visual:24.04 sh -c 'meson setup /tmp/b && ninja -C /tmp/b && \
    GITREE_BINARY=/tmp/b/src/gitree/gitree GSETTINGS_SCHEMA_DIR=/tmp/b/data \
    GITREE_VISUAL_OUT=/tmp/out sh tests/visual/test-parity.sh'
```

The source tarball holds only the files that git tracks, so a file must be committed or staged before a build takes it.
