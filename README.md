<p align="center">
  <img src="data/icons/io.github.li9i.gitrlf.svg" alt="gitrl-f logo" width="128">
</p>

# `gitrl-f`

> Search the git history, in only the refs that you tick

Somewhere in the history is the commit you want: the one that added a function, the one that changed a line, the one whose hash a colleague pasted in a chat. `git log` can find it with `-S`, `-G`, `-L` and a path, but it gives you a wall of text, and it gives you every branch, including the ones you do not care about. `gitrl-f` draws the history the way `gitg` does, with only the branches, remote branches and tags that you tick, and puts a search on top of it.

> [!TIP]
> gitrl-f is pronounced git-ROL-EFF (/ɡɪtˈrəʊlɛf/), after ctrl-f said aloud: control eff.

![A word typed in the search bar, its matches in bold, then only the matching commits shown](docs/screenshots/demo-search.gif)

## Features

**History**
- Graph of only the branches, remote branches and tags that you tick, remembered per repository
- Staged and unstaged changes as rows above the history, with their line counts
- Added and removed line counts for each commit
- Reloads by itself when the repository changes

**Search**
- One bar for messages, authors and hashes, changed lines (`git log -S` / `-G`) and files (`git log --follow`)
- Match case, Regex and **Display matches only**
- **Tick and show**: finds matches in the refs that you did not tick

**Right-click on a commit**
- **Show diff**, also for several selected commits as one combined diff
- **Open diff in difftool**, for one commit, several commits, or one file
- **Browse files at this commit** in the file manager

**Right-click on a ref**
- **Go to where it splits from** another ref (`git merge-base`)

**Diff pane**
- Ctrl+F finds a word in every file of the diff
- **Show history of the selected lines** (`git log -L`)
- **Go to the commit that last changed this line** (`git blame`)
- **Show history of this file**, following renames

**Command line**
- `gitrlf [refs] [-S text] [-G regex] [-- paths]`, with TAB completion in bash

> [!NOTE]
> `gitrl-f` never writes to the repository

## Installation

### From Launchpad

The PPA is [available for Ubuntu 24.04 and 26.04](https://launchpad.net/~li9i/+archive/ubuntu/gitrl-f):

```bash
sudo add-apt-repository ppa:li9i/gitrl-f
sudo apt-get install gitrl-f
```

The package is `gitrl-f`. The command is `gitrlf`, or `gitf` for short. The install adds `gitf` only if no other program called `gitf` is on the `PATH`. In bash, TAB completes its options, then the names of the refs, and after `--` the paths.

### `.deb` package

Packages for Ubuntu 24.04 and 26.04 are on the [releases page](https://github.com/gitrl-tools/gitrl-f/releases). Download the one for your release, then install it with `apt`, so that you also get its dependencies:

```bash
sudo apt-get install ./gitrl-f_*_amd64.deb
```

### AppImage

Download the AppImage from the [releases page](https://github.com/gitrl-tools/gitrl-f/releases). It is one file, and it is not necessary to install it. Make it executable, then run it from a repository:

```bash
chmod +x gitrl-f-*-x86_64.AppImage
./gitrl-f-*-x86_64.AppImage
```

If your machine has no FUSE, run it unpacked. This needs no other software:

```bash
./gitrl-f-*-x86_64.AppImage --appimage-extract-and-run
```

To call it as `gitrlf` from any directory, link it into `~/.local/bin` from the folder holding the AppImage:

```bash
ln -s "$PWD"/gitrl-f-*-x86_64.AppImage ~/.local/bin/gitrlf
```

The AppImage has no TAB completion. The package has it, and so does `meson install`.

## Build from source

```bash
git clone https://github.com/gitrl-tools/gitrl-f.git
cd gitrl-f
```

`CONTRIBUTING.md` gives the packages that the build needs.

### AppImage

```bash
./scripts/build-appimage.sh
# -> gitrl-f-<version>-x86_64.AppImage in the repository root
```

### `.deb` package

Built inside a container that matches the target Ubuntu, so that it links the libraries of that release (you need Docker):

```bash
# Ubuntu 24.04
./scripts/build-deb.sh 24.04

# The `.deb` goes to `_build/deb/`. Remove any installed copy, then install it with `apt`, so that you also get its dependencies.
sudo apt-get remove --purge gitrl-f
sudo apt-get install ./_build/deb/gitrl-f_*~ubuntu24.04.1_amd64.deb
```

```bash
# Ubuntu 26.04
./scripts/build-deb.sh 26.04

# The `.deb` goes to `_build/deb/`. Remove any installed copy, then install it with `apt`, so that you also get its dependencies.
sudo apt-get remove --purge gitrl-f
sudo apt-get install ./_build/deb/gitrl-f_*~ubuntu26.04.1_amd64.deb
```

### For one user

```bash
meson setup --prefix="$HOME/.local" _build
meson install -C _build
```

The install puts `gitrlf` in `~/.local/bin`, with `gitf` as a short name for it if no other program called `gitf` is on the `PATH`. That folder must be on the `PATH`. GLib and bash find the settings schema and the TAB completion with no more configuration.

Uninstalling does not remove `gitf`. Remove it first, then uninstall:

```bash
~/.local/share/gitrl-f/alias-link.sh remove
ninja -C _build uninstall
```

## How to run it

```bash
# cd to a repository ...
gitrlf                          # the ticks you chose last, or every ref
gitrlf main origin/main         # only these two
gitrlf 'feature/*'              # every ref whose name matches
gitrlf -l -r                    # every local and every remote branch
gitrlf -- src/parser.py         # only the commits that change this file,
                                # followed through its renames
gitrlf -S 'parse_args'          # only the commits that add or remove this text
gitrlf -S 'parse_args' -- src/parser.py
                                # the same, in this file only
gitrlf -G 'parse_[a-z]+'        # only the commits whose changed lines match
```

Run outside a repository, `gitrlf` opens a chooser listing the repositories that you opened before. `gitrlf -h` prints every option and key, and `man gitrlf` gives the whole of it.

| Key | What it does |
|-----|--------------|
| Double-click, `Enter` in the list | Shows or hides the details and the diff of a commit |
| `Escape` | Closes one thing, from the bottom of the window up |
| `Ctrl+F` | Opens the find bar of the diff, or the search bar when the pane is shut |
| `Ctrl+Shift+F` | Opens the search bar on **Changed lines** |
| `Enter`, `Ctrl+G`, `Shift+Enter`, `Ctrl+Shift+G` | Goes to the next match, or with `Shift` to the one before |
| `F5` | Reads the repository again |
| `Ctrl+Q` | Quits |

The window follows the repository as it changes, so a commit, a fetch, a checkout or a rebase in another terminal shows up without you touching anything. The ticks and the selected commit stay as they were.

## Licence

`gitrl-f` is built from `gitg`. It uses the language of gitg (Vala) and the same libraries. The graph, the labels and the diff are gitg's own code.

GPL-2.0-or-later, from gitg. Refer to `COPYING`. `debian/copyright` gives the per-file data that credits the gitg authors. The icon is an adaptation of the Git logo by Jason Long, CC BY 3.0.

## Disclaimer

`gitrl-f` was created by li9i and coded by Claude. What a time to be alive.
