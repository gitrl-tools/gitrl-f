# Patches applied to vendored gitg code

Each file under `src/vendor-gitg/` is byte for byte the file of gitg 44, or it has a patch here. Each patch has a section below that gives the cause and the cost. Thus a move to a later gitg is a mechanical task. `tests/vendor/check-closure.sh` makes sure that each patch turns the upstream file into the vendored file, and that each patch has its section.

To make a patch again, first run `vendor/fetch-upstream.sh`, then:

    cd src/vendor-gitg
    diff -u --label a/<path> --label b/<path> ../../vendor/upstream/<path> <path>

A patch for a Vala file has the name of the file without `.vala`. A patch for another file has the whole file name, for example `resources.xml.patch`.

Twelve files have patches. Five of them remove the line selection from the diff pane, and the five have the same cause. The cause is given once, under `gitg-diff-view-file-renderer-text.patch`, and the other four refer to it.

gitree takes these patches from gitrl-z, which vendors the same source. The differences are these:

- gitree does not take gitrl-z's patch to `gitg-lanes.vala`, which changes the settings schema that the lanes read. gitree has a history, and it reads gitg's own `preferences.history` settings. Its own patch to that file is a different one, below.
- gitree does not take gitrl-z's patch to `gitg-color.vala`, which adds `Color.from_index()`. Nothing in gitree needs it.
- The diff pane keeps gitg's Unif and Split switcher on each file, which gitrl-z hides.
- The patches add no comments to gitg's code. The reasons are here.

## gitg-repository.patch

Removes `Gitg.Repository.stage`, its field, `init_repository()`, and the three wrappers `create_branch()`, `create_reference()` and `create_symbolic_reference()`.

**Why.** `stage` makes a `Gitg.Stage` on demand. That class is the staging area of gitg and its main write path. `init_repository()` makes a new repository on disk. The three wrappers make refs. Nothing in the closure calls them, but while they stay, the binary links `ggit_repository_create_branch`, `ggit_repository_create_reference` and `ggit_repository_create_symbolic_reference`. This was measured on the object files on 2026-09-25. gitrl-z's patch to this file removes `stage` and `init_repository()` only. gitree writes nothing to a repository. No write path is compiled in, because a write path that nothing calls is still a write path. This removal also keeps `gitg-stage.vala`, `gitg-hook.vala` and their gpgme dependency out of the closure.

**Cost.** None. gitree does not stage, does not make repositories and does not make refs.

## gitg-init.patch

Two changes.

**1. Removes the registration of the `Ggit.Remote` -> `Gitg.Remote` factory.** Remote operations are out of scope, so `gitg-remote.vala` is not vendored, and the registration cannot compile.

**2. Removes the CSS provider.** Upstream gives `Gdk.Screen.get_default()` directly to `Gtk.StyleContext.add_provider_for_screen()`. With no display, that value is null, GTK fails a critical assertion, and `Gitg.init()` stops the process. `Gitg.init()` also registers the Ggit type factory that all other code needs. `git tree -h`, a ref that matches nothing, and arguments outside a repository must all work with no display, and so must the unit tests. A check for a screen inside `Gitg.init()` is not sufficient: gitree opens the repository to read its refs before GTK opens the display, and `Gitg.init()` does its work on the first call only. Thus a window started in a repository did not get the stylesheet. `Gitree.Application.startup()` adds `libgitg-style.css` at the priority that upstream uses, when the screen exists.

**Cost.** The stylesheet is added in a different function. Its content, its priority and its screen are the same as upstream.

## gitg-ext-application.patch

Removes the abstract `remote_lookup` property from the `GitgExt.Application` interface.

**Why.** Its type is `GitgExt.RemoteLookup`, from `gitg-ext-remote-lookup.vala`, which is not vendored for the same cause as above. If the property stayed, each implementation would return a type that does not exist.

**Cost.** None.

## gitg-repository-list-box.patch

Removes the DOAP reading from the rows of the repository chooser.

**Why.** gitg looks for a `.doap` file in the tree of HEAD. It shows the short description and the language tags of that file on the row. This needs `Ide.Doap` from `contrib/ide/` of gitg, about 990 lines of C. `contrib/ide/` needs `contrib/xml-reader/`, which links libxml2. The total is about 1500 lines of vendored C and one more library, for decoration on the rows of repositories that hold a `.doap` file. In practice, almost only GNOME projects have one. gitree depends on no library that gitg does not, and on fewer where it can.

**Cost.** In the repository chooser, a repository that holds a `.doap` file shows no description line and no language tags, where gitg shows them. The branch name and the rest of the row do not change. An ordinary repository has no `.doap` file, and gitg shows nothing more for it either.

The field `d_languages_box` stays bound to the template, but it is not filled, and the compiler gives a note for it. It stays because it is a `[GtkChild]` of `ui/gitg-repository-list-box-row.ui`. Its removal needs a patch to that file too, for no gain.

This patch only removes lines. gitrl-z's patch to this file also indents the lines that stay by one more tab.

## gitg-diff-view-file-renderer-text.patch

Two changes: the selection comes out, and the word marks go in.

**1. Removes the line selection** from the diff renderer of gitg. It removes the `DiffSelectable` interface from the class declaration, and the fields `d_selectable`, `d_lines`, `d_has_selection` and `d_doffset`. It also removes the `has_selection` property, `clear_selection()`, the `selection` property, and the `PatchSet.Patch` that the hunk loop made for each added and removed line.

**Why.** `PatchSet` is declared in `gitg-stage.vala`. That file is the staging area of gitg and its main write path. `gitg-repository.patch` removes the property that reaches it, so that it stays out of the closure with `gitg-hook.vala` and gpgme. A selection is only useful if something can stage it, and nothing in gitree can.

Two things stay. `can_select` stays a construct property of the renderer, and `handle_selection` stays one of `Gitg.DiffView`. The two are constructor parameters, and their removal would spread the patch to each call. The two are false in gitree, as they are in the history of gitg.

The `added` and `removed` counters, the regions and the source marks stay, because they have no relation to the selection. The line tints come from the source marks. The stat badge of a file does not read the counters now, because `gitg-diff-view-file.patch` counts the lines in the file itself.

**Cost.** No selection of lines or hunks in the pane. The history of gitg does not offer it either, because it makes `Gitg.DiffView` with `handle_selection` false. Only the Commit activity of gitg shows it, and that activity is out of scope.

**2. Marks the words that changed inside a changed line.** gitg tints the whole line and leaves the reader to find the word.

The addition has four parts:

- `Gitg.WordMarksFunc`, a delegate. Two lines go in, and the words that differ come out, as byte offsets into each line, in pairs of start and end. It returns false when the pair takes no marks, and then neither array is read. The marker is in the application, which this library cannot name, so it arrives as a function.
- `Gitg.WordMarks`, a holder with one static field for that delegate. The application fills it. It is a class of its own because the renderer is internal to this library, and the application must reach the field from outside. The delegate takes no type of the application, so the dependency goes in one direction only. When the field is null, the renderer does what the renderer of gitg does: tints and no marks.
- Two buffer tags, `word-added` and `word-removed`. They are set with the line tints, in a stronger shade of the same colour, and they follow the theme in the same way. Each tag is a background and not an underline, so that a mark is seen at a glance. The syntax colours are foregrounds, and they stay easy to read through it.
- A pairing pass in `add_hunk`. The first removed line of a change pairs with the first added line, and the second with the second. The run ends at the next context line. A line with no partner, and a pair that the marker declines, keep their tint and take no marks. Each renderer reads each line of the hunk, whatever its style. Thus a half of the split view finds the pairs from the two sides, and marks only the lines that it shows. It holds the lines that it does not show with no buffer line.

A line of the kind "\ No newline at end of file" does not end the run. gitg reads it as a context line, and without this, a removed line and an added line at the end of a file, where each has no newline, do not pair. gitrl-z's patch ends the run there, and gitree does not.

A marked line takes its buffer line from the place where its text goes in. It does not use the count of lines that the hunk loop keeps. In the unified view, a line with no newline and the marker after it share one buffer line, but the count adds two. Thus the added line after the marker took its marks on the next buffer line, which does not hold the added text. The split view did not show the fault, because each half shows only one of the two lines.

The offsets are byte offsets because they index a string, but a text buffer counts characters. The two are different on the first line that holds a character outside ASCII. Thus each offset becomes a character offset before a tag is applied.

## gitg-diff-view-file-renderer-text-split.patch

Two changes.

**1. The same removal in the split renderer:** the `DiffSelectable` interface, the `has_selection` property, `clear_selection()` and the `selection` property. Upstream had already put the bodies of the three in comments. The split view gave no selection and returned an empty `PatchSet`. So what goes is three members that only named a type from `gitg-stage.vala`. `can_select` stays, for the cause given above.

**2. The two sides scroll left and right together.** When the horizontal adjustment of one side changes, `follow()` gives its value to the other. A flag stops the change that comes back, so a side that is wider than the other can scroll to its end.

**Why.** In gitg, each side of the split view has its own horizontal scroll bar, and a line then shows at two different places. The operator asked that the two move together.

**Cost.** Two handlers and a flag. The vertical scroll is not changed: the two sides are in one scrolled pane for that already.

## gitg-diff-view-file-renderer-textable.patch

Removes `DiffSelectable` from the base list of the interface, one line.

**Why.** The two renderers above implement this interface, and neither implements `DiffSelectable` now.

## gitg-diff-view-file.patch

Two changes: the selection comes out, and the text views of a file are made only when they show.

**1. Removes `has_selection()`, `clear_selection()` and `get_selection()`**, which asked each renderer of one file for its selection.

**Why.** Their return type or their cast names `DiffSelectable` or `PatchSet`. Nothing calls them after `gitg-diff-view.patch`.

gitrl-z's patch to this file also hides the Unif and Split switcher of each file. gitree keeps the switcher as gitg has it.

**2. Makes the text views of a file only when they show.** When a commit is selected, gitg makes three text views for each of its files. These are the unified view and the two halves of the split view. Each view loads the old file and the new file and colours them. A commit with more than one file starts with its files folded, so most of this work does not show.

Now the file keeps its hunks. It makes the unified view when the file opens, and the split view when Split is chosen, and then gives the hunks to that view. The file makes its Unif and Split pages, and with them the buttons of the switcher, when it first opens. After that, the switcher is as gitg has it. The file counts the added and removed lines for its header from the hunks, because no view counts them before the file opens. For each view that it makes, the file sends `renderer_added`, and `gitg-diff-view.patch` binds the view there.

**Why.** Before this change, a click on a commit with more than one file made the diff in 75 to 254 ms. The highlighting then kept the pane busy for up to 1.3 s after the click. After this change, the diff took 16 to 57 ms, with no busy time after it. This was measured under Xvfb on a copy of this repository at 0.3.0, in runs of twelve clicks, on 2026-09-27. The pages cost time too. On a commit that adds 118 files, the diff showed after 627 to 704 ms when each file made its pages at once. It showed after 536 to 575 ms when the pages wait for the first open.

**Cost.** A view is made when its file first opens, or when Split is first chosen. A commit with one file opens at once, and its diff took 20 to 81 ms.

## gitg-diff-view-file.ui.patch

Removes the slide from the fold of each file. The revealer that holds the diff of a file has no transition.

**Why.** gitg gives the last file of a commit all the free height of the pane, so that its diff fills the pane. The revealer gets that height too, and the slide only changes the height that the revealer asks for. Thus the slide does not show. When a file opens, its text shows at once. When a file closes, its text stays at full height for the 250 ms of the slide, and then goes. The operator saw this as a slow close. After a click on the arrow, the text went after 250 to 270 ms, and came back after 0.1 ms (measured under Xvfb, 2026-09-26). With no transition, the text goes on the click.

**Cost.** No file of the pane slides open or shut.

## gitg-diff-view.patch

Three changes: the selection comes out, a text view is bound when its file makes it, and the rows of the files are added in batches.

**1. Removes the `has_selection` property**, `on_selection_changed()` and the two calls to it, `get_selection()` and `clear_selection()`.

**Why.** The same cause as the renderer. `get_selection()` returns `PatchSet[]`, and the rest keep that property in step with the renderers.

`handle_selection` stays, as given above, and is false. gitrl-z's patch to this file also adds a property that sets the view of every file at once. gitree keeps the switcher of each file and does not take that property.

**Cost.** None. Selection only feeds staging, which gitree does not have.

**2. Binds a text view when the file makes it.** The bindings of `highlight`, `wrap-lines` and `tab-width`, and the value of `maxlines`, move from the delta callback to `bind_renderer()`. The file calls it through `renderer_added`, because the file now makes its views later, as `gitg-diff-view-file.patch` gives. The plan of the file, from part 3, keeps the value of `maxlines` that gitg gives at that point. Thus each view gets the same value as in gitg.

**Cost.** None. A view gets the same settings, at a later time.

**3. Adds the rows of the files in batches.** The loop over the diff does not make a row for each file now. It keeps a `DiffViewFilePlan` for each file: the file info, the kinds of view, the value of `maxlines` and the hunks. `add_files()` makes the rows of the first 20 plans at once. It makes the next 20 in an idle call at low priority, and it continues until all the rows show. If the diff changes before all the rows are made, the cancellable of the old diff stops the rest.

**Why.** Each row takes time to make, to add to the pane and to lay out. On a commit that adds 118 files, the diff showed after 536 to 575 ms, with all the rows at once. With batches, the first 20 rows showed after 102 to 149 ms, and all 118 rows were in the pane after 356 to 407 ms. A commit with 20 files or fewer shows as before. This was measured under Xvfb on a copy of this repository, on 2026-09-27.

**Cost.** On a big commit, the rows after the first 20 come in after the first paint. The scroll bar grows while they come in.

## gitg-lanes.patch

Three changes.

**1. Lets the caller give `Gitg.Lanes` the parents of each commit, through `set_parents_func()`.** Two places read the parents of a commit: `prepare_lanes()` and `expand_lanes()`. They now ask `parent_ids()`, which calls that function when it is set, and reads the commit when it is not. `Gitg.Lanes` does not own the function: the caller owns the lanes and must live longer than them. An owned function held a reference to its caller, and the two were never freed.

Under a path limit, gitree shows only the commits that change the paths. It takes the parents of each one from `git log --parents`, which rewrites them to the nearest shown ancestors. libgit2 has no history simplification by path. The lanes must follow the rewritten parents, or the graph does not join from one shown commit to the next. The commit object holds its real parents, so the lanes need another source.

**2. Removes the `debug()` call at the start of `next()`.** Its arguments, the subject of the commit and its hash as text, are made for every commit even when debug output is off. On a tick of one branch of a history of 100000 commits, the lanes took 0.296 s with the call and 0.272 s without it (measured, 2026-09-25).

**3. Does not make the list of lanes for a hidden commit.** `next()` copied every lane into a new list for each commit, and the caller drops that list when `next()` returns false, which it does for a hidden commit. A hidden commit is one on the first parent line of the mainline that no ticked ref reaches. `next()` now gives null for it, as it already does for a commit that it saves as a miss. The same tick took 0.255 s with this change and the one above (measured).

**Cost.** None. With no path limit, no function is set, and the lanes read the parents of the commit as upstream does. Every caller, `Gitg.CommitModel` included, reads the list only when `next()` returns true. The pixel comparison with gitg is unchanged at zero differing pixels.

## resources.xml.patch

Removes two entries from the resource list of `libgitg`: `ui/gitg-authentication-dialog.ui` and `ui/gitg-sidebar.ui`.

**Why.** The authentication dialog is for remote operations, which are out of scope. `gitg-sidebar.vala` is not vendored, because the refs panel of gitree does not use `Gitg.Sidebar`, so that template has no class. A resource list that names a file which is not vendored does not compile. The other entries stay in upstream's order. The `/org/gnome/gitg` prefix stays, because the vendored Vala files name these paths in their `[GtkTemplate]` attributes. The resources are internal to the gitree binary, so the prefix cannot collide with the installed gitg.

**Cost.** None. gitrl-z also removes these two entries, but it sorts the list again, adds a comment, and has no patch for the file.
