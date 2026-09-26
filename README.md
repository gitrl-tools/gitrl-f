# gitree

`git tree` shows the history of a git repository in a window, with a checkbox for each branch, remote branch and tag. It draws only the commits that a ticked ref reaches, and it labels only the ticked refs. gitree is built from the source of gitg 44. It uses Vala and the same libraries as gitg, so the history and the diff look the same as in gitg.

gitree is not complete. It does not have a desktop entry, a manual page or a package.

## Install

To install gitree for one user, in `~/.local`:

```bash
meson setup --prefix="$HOME/.local" _build
meson install -C _build
```

`~/.local/bin` must be on the `PATH`. Git then runs `git-tree` as `git tree`. GLib finds the settings schema in `~/.local/share/glib-2.0/schemas` with no more configuration. `CONTRIBUTING.md` gives the packages that are necessary to build gitree.

## Licence

GPL-2.0-or-later, the licence of gitg. Refer to `COPYING`.
