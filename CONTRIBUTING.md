# Contributing to gitree

## Build from source

Ubuntu 24.04 or equivalent is necessary:

```bash
sudo apt-get install build-essential git gsettings-desktop-schemas-dev \
    libgee-0.8-dev libgit2-glib-1.0-dev libglib2.0-dev libgtk-3-dev \
    libgtksourceview-4-dev librsvg2-common meson pkgconf valac wget xauth \
    xvfb

meson setup _build
ninja -C _build
./scripts/dev.sh run
```

`scripts/dev.sh` contains the common tasks (`build`, `test`, `run`, `clean`).

## Vendored gitg

`src/vendor-gitg/` is a part of the gitg 44 source. Each file there is byte for byte gitg's, or it has a patch in `vendor/patches/`, whose README gives the cause of each patch. To check this:

```bash
sh vendor/fetch-upstream.sh
sh tests/vendor/check-closure.sh
```

The first command gets gitg 44 and verifies it against `vendor/PROVENANCE`. `sh vendor/try-closure.sh` compiles the vendored part alone.

## Tests

```bash
./scripts/dev.sh test
./scripts/dev.sh test unit
./scripts/dev.sh test ui
```

The first command runs every suite. Every test runs with a private home folder in the build directory. Thus no test reads your git configuration or writes to your list of recent files. The `unit` suite needs no display. The `ui` suite drives real widgets in Xvfb. The `visual` suite compares the window with the installed gitg, pixel by pixel. It is off by default (`-Dvisual_tests=true`), because it needs an X server and gitg.

`tests/perf/fixture.sh <directory>` builds the two large repositories that the speed of gitree is measured on. `tests/perf/measure.sh <directory>` then opens the window of gitree and of the Python prototype on each, three times, and prints the time to open, to tick, to reload, and the peak memory.
