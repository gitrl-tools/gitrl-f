# Contributing to gittree

## Build from source

Ubuntu 24.04 or equivalent is necessary:

```bash
sudo apt-get install appstream build-essential desktop-file-utils git \
    groff-base gsettings-desktop-schemas-dev libgee-0.8-dev \
    libgit2-glib-1.0-dev libglib2.0-dev libgtk-3-dev libgtksourceview-4-dev \
    librsvg2-common libxml2-utils meson pkgconf valac wget xauth xdotool xvfb

meson setup _build
ninja -C _build
./scripts/dev.sh run
```

When the `_build` directory is present, `meson configure _build --prefix="$HOME/.local"` sets the prefix before `meson install -C _build`.

`scripts/dev.sh` contains the common tasks (`setup`, `build`, `test`, `run`, `clean`). `run` starts the built `gittree` in the folder that you call it from, with the settings schema of the build.

## Vendored gitg

`src/vendor-gitg/` is a part of the gitg 44 source. Each file there is byte for byte gitg's, or it has a patch in `vendor/patches/`, whose README gives the cause of each patch. To check this:

```bash
sh vendor/fetch-upstream.sh
sh tests/vendor/check-closure.sh
```

The first command gets gitg 44 and verifies its SHA-256, which the script holds. The second compares the vendored files, the stylesheet and the vapi files copied from gitg with that tree, and runs in the `unit` suite too. `sh tests/vendor/check-provenance.sh` fetches the tarball again and compares it with the checksum in `vendor/PROVENANCE`. It needs the network, so no suite runs it. `sh vendor/try-closure.sh` compiles the vendored part alone.

## Tests

```bash
./scripts/dev.sh test
./scripts/dev.sh test unit
./scripts/dev.sh test ui
```

The first command runs every suite: `data`, which validates the settings schema, the desktop entry and the metainfo, `install`, which installs the build into a temporary folder and compares the files with a list, `unit` and `ui`. Every test runs with a private home folder in the build directory. Thus no test reads your git configuration or writes to your list of recent files. The `unit` suite needs no display. The `ui` suite drives real widgets in Xvfb. The `visual` suite compares the window with the installed gitg, pixel by pixel. It is off by default (`-Dvisual_tests=true`), because it needs an X server and gitg.

`tests/parity/compare.sh <repository> [<gittree arguments>]` compares the commits that gittree shows, with their parents and labels, with those of the Python prototype, which it reads from commit `5ccd222` of the dotfiles repository, `~/dotfiles` or the path in `GITTREE_DOTFILES`. The prototype has no text filter, so `compare.sh` cannot compare `-S` or `-G`. The window follows one file through its renames, and the prototype and the dump do not, so with one file after `--` the window can show more commits than `compare.sh` compares. `_build/tests/gittree-dump <repository> -S <text>` prints the rows of gittree alone.

`tests/perf/fixture.sh <directory>` builds the two large repositories that the speed of gittree is measured on. `tests/perf/measure.sh <directory>` then opens the window of gittree and of the Python prototype on each, three times, and prints the time to open, to tick, to reload, and the peak memory. For gittree, it also prints the time to open with the text filter `-S 'line 1'` and to tick under it. `_build/tests/gittree-bench --window <repository> --search <text> [<ref>...]` prints the time of the search bar of the list, of Only matches, and of the search beyond the ticks with only each named ref ticked.

## The animations in the README

```bash
./scripts/capture-demo.sh
```

The script builds a repository with fixed names and dates with `scripts/demo-fixture.sh`, starts the built `gittree` on it in a private Xvfb with a private D-Bus, drives it with xdotool, and records it with ffmpeg. It writes `docs/screenshots/demo-ticks.gif`, `docs/screenshots/demo-pane.gif`, and `docs/screenshots/gittree.png`, which the metainfo names as its screenshot. `./scripts/capture-demo.sh ticks` makes one of them only. The clicks are at fixed places in a 1210x781 window, so a change to the layout needs the places found again.

`./scripts/regen-icons.sh` renders the three PNG icons from `data/icons/io.github.li9i.gittree.svg`.

## Packaging

```bash
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04

./tests/packaging/test-orig.sh
./tests/packaging/test-lintian.sh _build/deb/gittree_<version>-1~ubuntu24.04.1_amd64.changes
./tests/packaging/test-install.sh _build/deb/gittree_<version>-1~ubuntu24.04.1_amd64.deb
./tests/packaging/test-install.sh _build/deb/gittree_<version>-1~ubuntu26.04.1_amd64.deb
```

The packages build in the `build` stage of the container, which installs only the packaging tools and the build dependencies that `debian/control` declares, so a build in it proves that the list is complete. A Launchpad builder makes the same check. `docker/README.md` says more. The source tarball holds only the files that git tracks: `test-orig.sh` compares the two. `test-lintian.sh` shows every lintian tag at `--pedantic`. The one tag to expect is `binary-nmu-debian-revision-in-source`, which the `~ubuntuNN.NN.1` suffix causes. `test-install.sh` installs the package in a clean container of its release, runs both names, checks every installed file, then removes and purges it.

## AppImage

```bash
./scripts/build-appimage.sh
./tests/packaging/test-appimage.sh
```

`linuxdeploy` and its GTK plugin put GTK 3, its modules and theme, the settings schema and the libraries of gittree into one file. The script downloads those tools into `_build/appimage/tools`. `test-appimage.sh` runs the file in a clean `ubuntu:24.04` container with a private X server, and checks the version and the window. The container first gets the eight libraries that every desktop has and that an AppImage leaves out: libX11, libxcb, fontconfig, freetype, harfbuzz, fribidi, wayland-client and expat. Give it `ubuntu:26.04` as a second argument for the newer release.

## Releases

`docs/packaging.md` gives the whole procedure, from the version bump to the uploads.
