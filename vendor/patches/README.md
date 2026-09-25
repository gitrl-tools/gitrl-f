# Patches applied to vendored gitg code

Each file under `src/vendor-gitg/` is byte for byte the file of gitg 44, or it has a patch here. Each patch has a section below that gives the cause and the cost. Thus a move to a later gitg is a mechanical task. `tests/vendor/check-closure.sh` makes sure that each patch turns the upstream file into the vendored file, and that each patch has its section.

To make a patch again, first run `vendor/fetch-upstream.sh`, then:

    cd src/vendor-gitg
    diff -u --label a/<path> --label b/<path> ../../vendor/upstream/<path> <path>

A patch for a Vala file has the name of the file without `.vala`. A patch for another file has the whole file name, for example `resources.xml.patch`.

Ten files have patches. Five of them are the diff pane, and the five have the same cause. The cause is given once, under `gitg-diff-view-file-renderer-text.patch`, and the other four refer to it.

gitree takes these patches from gitrl-z, which vendors the same source. The differences are these:

- gitree does not take gitrl-z's patch to `gitg-lanes.vala`, which changes the settings schema that the lanes read. gitree has a history, and it reads gitg's own `preferences.history` settings.
- gitree does not take gitrl-z's patch to `gitg-color.vala`, which adds `Color.from_index()`. Nothing in gitree needs it.
- The diff pane keeps gitg's Unif and Split switcher on each file, which gitrl-z hides.
- The patches add no comments to gitg's code. The reasons are here.

## gitg-repository.patch

Removes `Gitg.Repository.stage`, its field, `init_repository()`, and the three wrappers `create_branch()`, `create_reference()` and `create_symbolic_reference()`.

**Why.** `stage` makes a `Gitg.Stage` on demand. That class is the staging area of gitg and its main write path. `init_repository()` makes a new repository on disk. The three wrappers make refs. Nothing in the closure calls them, but while they stay, the binary links `ggit_repository_create_branch`, `ggit_repository_create_reference` and `ggit_repository_create_symbolic_reference`. This was measured on the object files on 2026-09-25. gitrl-z's patch to this file removes `stage` and `init_repository()` only. gitree writes nothing to a repository except its ticks file. No write path is compiled in, because a write path that nothing calls is still a write path. This removal also keeps `gitg-stage.vala`, `gitg-hook.vala` and their gpgme dependency out of the closure.

**Cost.** None. gitree does not stage, does not make repositories and does not make refs.

## gitg-init.patch

Two changes.

**1. Removes the registration of the `Ggit.Remote` -> `Gitg.Remote` factory.** Remote operations are out of scope, so `gitg-remote.vala` is not vendored, and the registration cannot compile.

**2. Adds the CSS provider only when there is a `Gdk.Screen`.** Upstream gives `Gdk.Screen.get_default()` directly to `Gtk.StyleContext.add_provider_for_screen()`. With no display, that value is null, GTK fails a critical assertion, and `Gitg.init()` stops the process. `Gitg.init()` also registers the Ggit type factory that all other code needs. `git tree -h`, a ref that matches nothing, and arguments outside a repository must all work with no display, and so must the unit tests.

**Cost.** None. With no screen, the type factory is the part that has an effect. The CSS has an effect only on a screen, and there the code path is the same as upstream.

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

The `added` and `removed` counters, the regions and the source marks stay. The stat badge and the line tints read them, and they have no relation to the selection.

**Cost.** No selection of lines or hunks in the pane. The history of gitg does not offer it either, because it makes `Gitg.DiffView` with `handle_selection` false. Only the Commit activity of gitg shows it, and that activity is out of scope.

**2. Marks the words that changed inside a changed line.** gitg tints the whole line and leaves the reader to find the word.

The addition has four parts:

- `Gitg.WordMarksFunc`, a delegate. Two lines go in, and the words that differ come out, as byte offsets into each line, in pairs of start and end. It returns false when the pair takes no marks, and then neither array is read. The marker is in the application, which this library cannot name, so it arrives as a function.
- `Gitg.WordMarks`, a holder with one static field for that delegate. The application fills it. It is a class of its own because the renderer is internal to this library, and the application must reach the field from outside. The delegate takes no type of the application, so the dependency goes in one direction only. When the field is null, the renderer does what the renderer of gitg does: tints and no marks.
- Two buffer tags, `word-added` and `word-removed`. They are set with the line tints, in a stronger shade of the same colour, and they follow the theme in the same way. Each tag is a background and not an underline, so that a mark is seen at a glance. The syntax colours are foregrounds, and they stay easy to read through it.
- A pairing pass in `add_hunk`. The first removed line of a change pairs with the first added line, and the second with the second. The run ends at the next context line. A line with no partner, and a pair that the marker declines, keep their tint and take no marks. Each renderer reads each line of the hunk, whatever its style. Thus a half of the split view finds the pairs from the two sides, and marks only the lines that it shows. It holds the lines that it does not show with no buffer line.

The offsets are byte offsets because they index a string, but a text buffer counts characters. The two are different on the first line that holds a character outside ASCII. Thus each offset becomes a character offset before a tag is applied.

## gitg-diff-view-file-renderer-text-split.patch

The same removal in the split renderer: the `DiffSelectable` interface, the `has_selection` property, `clear_selection()` and the `selection` property.

Upstream had already put the bodies of the three in comments. The split view gave no selection and returned an empty `PatchSet`. So what goes is three members that only named a type from `gitg-stage.vala`. `can_select` stays, for the cause given above.

## gitg-diff-view-file-renderer-textable.patch

Removes `DiffSelectable` from the base list of the interface, one line.

**Why.** The two renderers above implement this interface, and neither implements `DiffSelectable` now.

## gitg-diff-view-file.patch

Removes `has_selection()`, `clear_selection()` and `get_selection()`, which asked each renderer of one file for its selection.

**Why.** Their return type or their cast names `DiffSelectable` or `PatchSet`. Nothing calls them after `gitg-diff-view.patch`.

gitrl-z's patch to this file also hides the Unif and Split switcher of each file. gitree keeps the switcher as gitg has it.

## gitg-diff-view.patch

Removes the `has_selection` property, `on_selection_changed()` and the two calls to it, `get_selection()` and `clear_selection()`.

**Why.** The same cause as the renderer. `get_selection()` returns `PatchSet[]`, and the rest keep that property in step with the renderers.

`handle_selection` stays, as given above, and is false. gitrl-z's patch to this file also adds a property that sets the view of every file at once. gitree keeps the switcher of each file and does not take that property.

## resources.xml.patch

Removes two entries from the resource list of `libgitg`: `ui/gitg-authentication-dialog.ui` and `ui/gitg-sidebar.ui`.

**Why.** The authentication dialog is for remote operations, which are out of scope. `gitg-sidebar.vala` is not vendored, because the refs panel of gitree does not use `Gitg.Sidebar`, so that template has no class. A resource list that names a file which is not vendored does not compile. The other entries stay in upstream's order. The `/org/gnome/gitg` prefix stays, because the vendored Vala files name these paths in their `[GtkTemplate]` attributes. The resources are internal to the gitree binary, so the prefix cannot collide with the installed gitg.

**Cost.** None. gitrl-z also removes these two entries, but it sorts the list again, adds a comment, and has no patch for the file.
