# `gitree`

> The git history only of the refs that you want to see

`gitree` is a stripped-down version of `gitg`: it shows the history of the branches, remote branches and tags that you tick, and nothing else. It draws that history as gitg does: the same lanes, the same labels and the same diff. A commit is drawn when a ticked ref reaches it. A commit that a ticked branch shares with an unticked one is still drawn, as part of the ticked branch. Only the ticked refs get a label.

![Refs ticked and unticked on the left, and the history redrawn on the right each time](docs/screenshots/demo-ticks.gif)

## What it does

- **A checkbox for each ref.** The refs are on the left, in three groups: branches, remote branches under each remote, and tags. A name with slashes, such as `feature/lexer`, goes into a group `feature`, to any depth. The box of a group ticks every ref in it and opens the group, or unticks them all and folds it. At each level the refs come first, then the groups. Both follow the order of the graph: a ref whose commit is higher in the history comes first, and a group takes the place of its highest ref. Refs on the same commit are sorted by name.
- **Every ref at the start.** With no ref and no option on the command line, every ref is ticked.
- **The details on a double click.** The pane under the history is hidden until you double-click a commit, or press Enter on it. Then it shows gitg's details and diff of that commit. A double-click on the same commit, Enter or Escape hides it again. A click that opens a file, or a click on Expand all, fills the window with the diff. A click that closes a file does not change the window. When the commit changes only one file, the double-click or Enter fills the window at once. Escape, the back arrow or the close button at the top right of the diff brings back the refs and the list.
- **A path limit.** `gitree -- src/parser.py` keeps only the commits that change that file, and the graph joins across the commits that it leaves out, as `git log` does.
- **It follows the repository.** A commit, a fetch, a checkout or a rebase in another terminal redraws the window, with the same ticks, the same commit selected and the same scroll.

![A double click on a commit shows its details and its diff, and Escape hides them](docs/screenshots/demo-pane.gif)

`gitree` is built from `gitg`. It uses the language of gitg (Vala) and the same libraries, and the graph, the labels and the diff are gitg's own code.

## Installation

### From Launchpad

The PPA is for Ubuntu 24.04 and 26.04:

```bash
sudo add-apt-repository ppa:li9i/gitree
sudo apt-get install gitree
```

The package is `gitree`. The command is `gitree`, and `git tree` runs it too.

### `.deb` package

Packages for Ubuntu 24.04 and 26.04 are on the [releases page](https://github.com/li9i/gitree/releases). Download the one for your release, then install it with `apt`, so that you also get its dependencies:

```bash
sudo apt-get install ./gitree_*_amd64.deb
```

If you installed gitree into `~/.local` from source before, remove that copy first, so that it does not come before the package on your `PATH`:

```bash
rm -f ~/.local/bin/gitree ~/.local/bin/git-tree
```

### AppImage

Download the AppImage from the [releases page](https://github.com/li9i/gitree/releases). It is one file, and it is not necessary to install it. Make it executable, then run it from a repository:

```bash
chmod +x gitree-*-x86_64.AppImage
./gitree-*-x86_64.AppImage
```

If your machine has no FUSE, run it unpacked. This needs no other software:

```bash
./gitree-*-x86_64.AppImage --appimage-extract-and-run
```

To call it as `gitree` and as `git tree` from any directory, link it into `~/.local/bin` under both names, from the folder that holds it:

```bash
ln -s "$PWD"/gitree-*-x86_64.AppImage ~/.local/bin/gitree
ln -s "$PWD"/gitree-*-x86_64.AppImage ~/.local/bin/git-tree
```

## Build from source

```bash
git clone https://github.com/li9i/gitree.git
cd gitree
```

`CONTRIBUTING.md` gives the packages that the build needs.

### For one user

```bash
meson setup --prefix="$HOME/.local" _build
meson install -C _build
```

`~/.local/bin` must be on the `PATH`. The install puts `gitree` there, and `git-tree` as a second name for it. GLib finds the settings schema in `~/.local/share/glib-2.0/schemas` with no more configuration.

### `.deb` package

Built in a container of the Ubuntu release that the package is for, so that it links the libraries of that release. You need Docker:

```bash
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04
```

The packages go to `_build/deb/`. Install one with `apt`, so that you also get its dependencies:

```bash
sudo apt-get install ./_build/deb/gitree_*~ubuntu24.04.1_amd64.deb
```

### AppImage

```bash
./scripts/build-appimage.sh
```

The AppImage goes to the top of the repository, as `gitree-<version>-x86_64.AppImage`.

## How to run it

In a repository:

```bash
gitree                          # every ref ticked
gitree main origin/main         # only these two
gitree 'feature/*'              # every ref whose name matches
gitree -l -r                    # every local and every remote branch
gitree -- src/parser.py         # only the commits that change this file
git tree -l                     # the same program, as a git command
```

Outside a repository, `gitree` opens a list of the repositories that you opened before. `gitree -h` prints every option, and `man gitree` gives the whole of it.

| Key | What it does |
|-----|--------------|
| Double click, `Enter` in the list | Shows or hides the details and the diff of a commit, and fills the window when the commit changes one file |
| Click that opens a file, or on Expand all | Fills the window with the diff |
| `Escape` | Closes the search bar, or else the full diff, or else the details |
| `Ctrl+F` | Opens or closes the search bar |
| `Enter`, `Ctrl+G` | Goes to the next commit that matches |
| `Shift+Enter`, `Ctrl+Shift+G` | Goes to the one before |
| `F5` | Reads the repository again |
| `Ctrl+Q` | Quits |

## Licence

GPL-2.0-or-later, from gitg. Refer to `COPYING`. `debian/copyright` gives the data for each file, with the credit to the authors of gitg. The icon is an adaptation of the Git logo by Jason Long, CC BY 3.0.
