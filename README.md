# `gittree`

> The git history only of the refs that you want to see

`gittree` is a stripped-down version of `gitg`: it shows the history of the branches, remote branches and tags that you tick, and nothing else. It draws that history as gitg does: the same lanes, the same labels and the same diff. A commit is drawn when a ticked ref reaches it. A commit that a ticked branch shares with an unticked one is still drawn, as part of the ticked branch. Only the ticked refs get a label.

![Refs ticked and unticked on the left, and the history redrawn on the right each time](docs/screenshots/demo-ticks.gif)

## What it does

- **A checkbox for each ref.** The refs are on the left, in three groups: branches, remote branches under each remote, and tags. A name with slashes, such as `feature/lexer`, goes into a group `feature`, to any depth. The box of a group ticks every ref in it and opens the group, or unticks them all and folds it. At each level the refs come first, then the groups. Both follow the order of the graph: a ref whose commit is higher in the history comes first, and a group takes the place of its highest ref. Refs on the same commit are sorted by name.
- **Every ref at the start.** With no ref and no option on the command line, every ref is ticked.
- **The details on a click.** The pane under the history is hidden until you click a commit, or press Enter on it. Then it shows gitg's details and diff of that commit. A click on the same commit, Enter or Escape hides it again. A double-click is two clicks: it shows the pane and hides it again. A click that opens a file, or a click on Expand all, fills the window with the diff. A click that closes a file does not change the window. When the commit changes only one file, Enter fills the window at once. Escape, the back arrow or the close button at the top right of the diff brings back the refs and the list.
- **A path limit.** `gittree -- src/parser.py` keeps only the commits that change that file, and the graph joins across the commits that it leaves out, as `git log` does.
- **Find in the diff.** Ctrl+F in the pane opens a find bar above the details. It marks every match in every file of the commit, folded files too, and Enter goes to the next match and opens its file. It matches case unless you turn **Match case** off.
- **A text filter.** `gittree -S parse_args` keeps only the commits that add or remove `parse_args`, as `git log -S` does, and the graph joins across the other commits. Ctrl+Shift+F, or the funnel button, sets or changes the filter in the window. Enter on an empty field of the filter bar, or the close button of the yellow bar, lifts it. The search runs in the background, so the window stays in use while git reads the history. Under a filter, the find bar of the diff opens with the same text.
- **It follows the repository.** A commit, a fetch, a checkout or a rebase in another terminal redraws the window, with the same ticks, the same commit selected and the same commit at the top of the list.

![A click on a commit shows its details and its diff, and Escape hides them](docs/screenshots/demo-pane.gif)

`gittree` is built from `gitg`. It uses the language of gitg (Vala) and the same libraries, and the graph, the labels and the diff are gitg's own code.

## Installation

### From Launchpad

The PPA is for Ubuntu 24.04 and 26.04:

```bash
sudo add-apt-repository ppa:li9i/gittree
sudo apt-get install gittree
```

The package is `gittree`. The command is `gittree`, and `git tree` runs it too. In bash, TAB completes the options of both, then the names of the refs, and after `--` the paths.

Before 0.4.0, the name was `gitree` and the PPA was `ppa:li9i/gitree`. That PPA is closed. If you added it, remove it:

```bash
sudo add-apt-repository --remove ppa:li9i/gitree
```

The `gittree` package removes the `gitree` package when you install it.

### `.deb` package

Packages for Ubuntu 24.04 and 26.04 are on the [releases page](https://github.com/li9i/gittree/releases). Download the one for your release, then install it with `apt`, so that you also get its dependencies:

```bash
sudo apt-get install ./gittree_*_amd64.deb
```

If you installed gittree into `~/.local` from source before, remove that copy first, so that it does not come before the package on your `PATH`:

```bash
rm -f ~/.local/bin/gittree ~/.local/bin/git-tree
rm -f ~/.local/share/bash-completion/completions/gittree ~/.local/share/bash-completion/completions/git-tree
```

### AppImage

Download the AppImage from the [releases page](https://github.com/li9i/gittree/releases). It is one file, and it is not necessary to install it. Make it executable, then run it from a repository:

```bash
chmod +x gittree-*-x86_64.AppImage
./gittree-*-x86_64.AppImage
```

If your machine has no FUSE, run it unpacked. This needs no other software:

```bash
./gittree-*-x86_64.AppImage --appimage-extract-and-run
```

To call it as `gittree` and as `git tree` from any directory, link it into `~/.local/bin` under both names, from the folder that holds it:

```bash
ln -s "$PWD"/gittree-*-x86_64.AppImage ~/.local/bin/gittree
ln -s "$PWD"/gittree-*-x86_64.AppImage ~/.local/bin/git-tree
```

The AppImage has no TAB completion. The package and a build from source have it.

## Build from source

```bash
git clone https://github.com/li9i/gittree.git
cd gittree
```

`CONTRIBUTING.md` gives the packages that the build needs.

### For one user

```bash
meson setup --prefix="$HOME/.local" _build
meson install -C _build
```

`~/.local/bin` must be on the `PATH`. The install puts `gittree` there, and `git-tree` as a second name for it. GLib finds the settings schema in `~/.local/share/glib-2.0/schemas`, and bash finds the TAB completion in `~/.local/share/bash-completion/completions`, with no more configuration.

### `.deb` package

Built in a container of the Ubuntu release that the package is for, so that it links the libraries of that release. You need Docker:

```bash
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04
```

The packages go to `_build/deb/`. Install one with `apt`, so that you also get its dependencies:

```bash
sudo apt-get remove --purge gittree
sudo apt-get install ./_build/deb/gittree_*~ubuntu24.04.1_amd64.deb
```

### AppImage

```bash
./scripts/build-appimage.sh
```

The AppImage goes to the top of the repository, as `gittree-<version>-x86_64.AppImage`.

## How to run it

In a repository:

```bash
gittree                         # every ref ticked
gittree main origin/main        # only these two
gittree 'feature/*'             # every ref whose name matches
gittree -l -r                   # every local and every remote branch
gittree -- src/parser.py        # only the commits that change this file
gittree -S 'parse_args'         # only the commits that add or remove this text
gittree -S 'parse_args' -- src/parser.py
                                # the same, in this file only
git tree -l                     # the same program, as a git command
```

Outside a repository, `gittree` opens a list of the repositories that you opened before. `gittree -h` prints every option, and `man gittree` gives the whole of it.

| Key | What it does |
|-----|--------------|
| Click, `Enter` in the list | Shows or hides the details and the diff of a commit. `Enter` also fills the window when the commit changes one file |
| Click that opens a file, or on Expand all | Fills the window with the diff |
| `Escape` | Closes the bar that has the focus. Else it closes the first that is open of: the search bar, the find bar of the diff, the filter bar, the full diff and the details. It never lifts the filter |
| `Ctrl+F` | Opens or closes the search bar, or the find bar of the diff when the diff has the focus or fills the window |
| `Ctrl+Shift+F` | Opens or closes the filter bar |
| `Enter`, `Ctrl+G` | Goes to the next commit that matches, or in the find bar of the diff, to the next match |
| `Shift+Enter`, `Ctrl+Shift+G` | Goes to the one before, in the list or in the find bar of the diff |
| `F5` | Reads the repository again |
| `Ctrl+Q` | Quits |

## Licence

GPL-2.0-or-later, from gitg. Refer to `COPYING`. `debian/copyright` gives the data for each file, with the credit to the authors of gitg. The icon is an adaptation of the Git logo by Jason Long, CC BY 3.0.
