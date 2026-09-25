# Contributing to gitree

## Build from source

Ubuntu 24.04 or equivalent is necessary:

```bash
sudo apt-get install build-essential gsettings-desktop-schemas-dev \
    libgee-0.8-dev libgit2-glib-1.0-dev libglib2.0-dev libgtk-3-dev \
    libgtksourceview-4-dev libhandy-1-dev meson pkgconf valac xvfb

meson setup _build
ninja -C _build
./scripts/dev.sh run
```

`scripts/dev.sh` contains the common tasks (`build`, `test`, `run`, `clean`).

## Tests

```bash
./scripts/dev.sh test
./scripts/dev.sh test unit
./scripts/dev.sh test ui
```

The first command runs every suite. The `unit` suite needs no display. The `ui` suite drives real widgets in Xvfb. The `visual` suite compares the window with the installed gitg, pixel by pixel. It is off by default (`-Dvisual_tests=true`), because it needs an X server and gitg.
