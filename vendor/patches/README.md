# Patches applied to vendored gitg code

Each file under `src/vendor-gitg/` is byte for byte the file of gitg 44, or it has a patch here. Each patch has a section below that gives the cause and the cost. Thus a move to a later gitg is a mechanical task. `tests/vendor/check-closure.sh` makes sure that each patch turns the upstream file into the vendored file, and that each patch has its section.

To make a patch again, first run `vendor/fetch-upstream.sh`, then:

    cd src/vendor-gitg
    diff -u --label a/<path> --label b/<path> ../../vendor/upstream/<path> <path>

A patch for a Vala file has the name of the file without `.vala`. A patch for another file has the whole file name, for example `resources.xml.patch`.

Thirteen files have patches. Five of them remove the line selection from the diff pane, and the five have the same cause. The cause is given once, under `gitg-diff-view-file-renderer-text.patch`, and the other four refer to it.

gittree takes these patches from gitrl-z, which vendors the same source. The differences are these:

- gittree does not take gitrl-z's patch to `gitg-lanes.vala`, which changes the settings schema that the lanes read. gittree has a history, and it reads gitg's own `preferences.history` settings. Its own patch to that file is a different one, below.
- gittree does not take gitrl-z's patch to `gitg-color.vala`, which adds `Color.from_index()`. Nothing in gittree needs it.
- The diff pane keeps gitg's Unif and Split switcher on each file, which gitrl-z hides.
- The parts of four patches that give the find bar of the diff its view of the pane, and all of `gitg-diff-view-file-info.patch`, are gittree's own. gitrl-z has no find in the diff.
- The patches add no comments to gitg's code. The reasons are here.

## gitg-repository.patch

Removes `Gitg.Repository.stage`, its field, `init_repository()`, and the three wrappers `create_branch()`, `create_reference()` and `create_symbolic_reference()`.

**Why.** `stage` makes a `Gitg.Stage` on demand. That class is the staging area of gitg and its main write path. `init_repository()` makes a new repository on disk. The three wrappers make refs. Nothing in the closure calls them, but while they stay, the binary links `ggit_repository_create_branch`, `ggit_repository_create_reference` and `ggit_repository_create_symbolic_reference`. This was measured on the object files on 2026-09-25. gitrl-z's patch to this file removes `stage` and `init_repository()` only. gittree writes nothing to a repository. No write path is compiled in, because a write path that nothing calls is still a write path. This removal also keeps `gitg-stage.vala`, `gitg-hook.vala` and their gpgme dependency out of the closure.

**Cost.** None. gittree does not stage, does not make repositories and does not make refs.

## gitg-init.patch

Two changes.

**1. Removes the registration of the `Ggit.Remote` -> `Gitg.Remote` factory.** Remote operations are out of scope, so `gitg-remote.vala` is not vendored, and the registration cannot compile.

**2. Removes the CSS provider.** Upstream gives `Gdk.Screen.get_default()` directly to `Gtk.StyleContext.add_provider_for_screen()`. With no display, that value is null, GTK fails a critical assertion, and `Gitg.init()` stops the process. `Gitg.init()` also registers the Ggit type factory that all other code needs. `git tree -h`, a ref that matches nothing, and arguments outside a repository must all work with no display, and so must the unit tests. A check for a screen inside `Gitg.init()` is not sufficient: gittree opens the repository to read its refs before GTK opens the display, and `Gitg.init()` does its work on the first call only. Thus a window started in a repository did not get the stylesheet. `Gittree.Application.startup()` adds `libgitg-style.css` at the priority that upstream uses, when the screen exists.

**Cost.** The stylesheet is added in a different function. Its content, its priority and its screen are the same as upstream.

## gitg-ext-application.patch

Removes the abstract `remote_lookup` property from the `GitgExt.Application` interface.

**Why.** Its type is `GitgExt.RemoteLookup`, from `gitg-ext-remote-lookup.vala`, which is not vendored for the same cause as above. If the property stayed, each implementation would return a type that does not exist.

**Cost.** None.

## gitg-repository-list-box.patch

Removes the DOAP reading from the rows of the repository chooser.

**Why.** gitg looks for a `.doap` file in the tree of HEAD. It shows the short description and the language tags of that file on the row. This needs `Ide.Doap` from `contrib/ide/` of gitg, about 990 lines of C. `contrib/ide/` needs `contrib/xml-reader/`, which links libxml2. The total is about 1500 lines of vendored C and one more library, for decoration on the rows of repositories that hold a `.doap` file. In practice, almost only GNOME projects have one. gittree depends on no library that gitg does not, and on fewer where it can.

**Cost.** In the repository chooser, a repository that holds a `.doap` file shows no description line and no language tags, where gitg shows them. The branch name and the rest of the row do not change. An ordinary repository has no `.doap` file, and gitg shows nothing more for it either.

The field `d_languages_box` stays bound to the template, but it is not filled, and the compiler gives a note for it. It stays because it is a `[GtkChild]` of `ui/gitg-repository-list-box-row.ui`. Its removal needs a patch to that file too, for no gain.

This patch only removes lines. gitrl-z's patch to this file also indents the lines that stay by one more tab.

## gitg-diff-view-file-renderer-text.patch

Four changes: the selection comes out, the word marks go in, the view records where the text of each line starts, and the colours of a file load in a repository with no working tree.

**1. Removes the line selection** from the diff renderer of gitg. It removes the `DiffSelectable` interface from the class declaration, and the fields `d_selectable`, `d_lines`, `d_has_selection` and `d_doffset`. It also removes the `has_selection` property, `clear_selection()`, the `selection` property, and the `PatchSet.Patch` that the hunk loop made for each added and removed line.

**Why.** `PatchSet` is declared in `gitg-stage.vala`. That file is the staging area of gitg and its main write path. `gitg-repository.patch` removes the property that reaches it, so that it stays out of the closure with `gitg-hook.vala` and gpgme. A selection is only useful if something can stage it, and nothing in gittree can.

Two things stay. `can_select` stays a construct property of the renderer, and `handle_selection` stays one of `Gitg.DiffView`. The two are constructor parameters, and their removal would spread the patch to each call. The two are false in gittree, as they are in the history of gitg.

The `added` and `removed` counters, the regions and the source marks stay, because they have no relation to the selection. The line tints come from the source marks. The stat badge of a file does not read the counters now, because `gitg-diff-view-file.patch` counts the lines in the file itself.

**Cost.** No selection of lines or hunks in the pane. The history of gitg does not offer it either, because it makes `Gitg.DiffView` with `handle_selection` false. Only the Commit activity of gitg shows it, and that activity is out of scope.

**2. Marks the words that changed inside a changed line.** gitg tints the whole line and leaves the reader to find the word.

The addition has four parts:

- `Gitg.WordMarksFunc`, a delegate. Two lines go in, and the words that differ come out, as byte offsets into each line, in pairs of start and end. It returns false when the pair takes no marks, and then neither array is read. The marker is in the application, which this library cannot name, so it arrives as a function.
- `Gitg.WordMarks`, a holder with one static field for that delegate. The application fills it. It is a class of its own because the renderer is internal to this library, and the application must reach the field from outside. The delegate takes no type of the application, so the dependency goes in one direction only. When the field is null, the renderer does what the renderer of gitg does: tints and no marks.
- Two buffer tags, `word-added` and `word-removed`. They are set with the line tints, in a stronger shade of the same colour, and they follow the theme in the same way. Each tag is a background and not an underline, so that a mark is seen at a glance. The syntax colours are foregrounds, and they stay easy to read through it.
- A pairing pass in `add_hunk`. The first removed line of a change pairs with the first added line, and the second with the second. The run ends at the next context line. A line with no partner, and a pair that the marker declines, keep their tint and take no marks. Each renderer reads each line of the hunk, whatever its style. Thus a half of the split view finds the pairs from the two sides, and marks only the lines that it shows. It holds the lines that it does not show with no buffer line.

A line of the kind "\ No newline at end of file" does not end the run. gitg reads it as a context line, and without this, a removed line and an added line at the end of a file, where each has no newline, do not pair. gitrl-z's patch ends the run there, and gittree does not.

A marked line takes its buffer line from the place where its text goes in. It does not use the count of lines that the hunk loop keeps. In the unified view, a line with no newline and the marker after it share one buffer line, but the count adds two. Thus the added line after the marker took its marks on the next buffer line, which does not hold the added text. The split view did not show the fault, because each half shows only one of the two lines.

The offsets are byte offsets because they index a string, but a text buffer counts characters. The two are different on the first line that holds a character outside ASCII. Thus each offset becomes a character offset before a tag is applied.

**3. Records where the text of each line starts.** For each line of each hunk, in the order of the hunks, the view keeps the character offset in its buffer where the text of that line goes in. `get_line_offset()` gives it, or -1 for a line that the view does not show. The halves of the split view do not show the lines of the other side. No view shows the "\ No newline at end of file" lines as lines of their own.

**Why.** The find bar of the diff marks a text in the lines of a file, and it must put each mark at the correct place in the buffer. A search of the buffer text does not give the same result. The marker line goes into the buffer on the same line as the line before it. The unified view of a file whose last line changes and has no newline shows `old end\ No newline at end of file` on one buffer line (measured in the UI test, 2026-10-01). A search of the buffer then finds text in the marker, and text across the join, that is in no line of the diff. The split view adds empty lines where one side has more lines than the other. With the offsets, a mark goes on the text of its line and nowhere else.

**Cost.** One integer for each line of each hunk.

**4. Lets the colours of a file load when the file has no place on disk.** The content type is guessed with no file name when the location of the file is null, and `init_highlighting_buffer_from_stream()` takes a null location, as its body already allows.

**Why.** In a repository with no working tree, a file has no location. gitg asked the null location for its name, and GIO gave the critical message "g_file_get_basename: assertion 'G_IS_FILE (file)' failed" each time such a repository showed a diff (seen in the UI test of the menu of a file, 2026-10-01).

**Cost.** None. A file with a location loads as before.

## gitg-diff-view-file-renderer-text-split.patch

Three changes.

**1. The same removal in the split renderer:** the `DiffSelectable` interface, the `has_selection` property, `clear_selection()` and the `selection` property. Upstream had already put the bodies of the three in comments. The split view gave no selection and returned an empty `PatchSet`. So what goes is three members that only named a type from `gitg-stage.vala`. `can_select` stays, for the cause given above.

**2. The two sides scroll left and right together.** When the horizontal adjustment of one side changes, `follow()` gives its value to the other. A flag stops the change that comes back, so a side that is wider than the other can scroll to its end.

**Why.** In gitg, each side of the split view has its own horizontal scroll bar, and a line then shows at two different places. The operator asked that the two move together.

**Cost.** Two handlers and a flag. The vertical scroll is not changed: the two sides are in one scrolled pane for that already.

**3. Gives its two text views, left then right, through `get_text_views()`.** `gitg-diff-view-file.patch` gives them to gittree. The cause is given there.

## gitg-diff-view-file-renderer-textable.patch

Removes `DiffSelectable` from the base list of the interface, one line.

**Why.** The two renderers above implement this interface, and neither implements `DiffSelectable` now.

## gitg-diff-view-file.patch

Four changes: the selection comes out, the text views of a file are made only when they show, gittree can read the lines and the views of a file, and gittree can add items to the menu of a file.

**1. Removes `has_selection()`, `clear_selection()` and `get_selection()`**, which asked each renderer of one file for its selection.

**Why.** Their return type or their cast names `DiffSelectable` or `PatchSet`. Nothing calls them after `gitg-diff-view.patch`.

gitrl-z's patch to this file also hides the Unif and Split switcher of each file. gittree keeps the switcher as gitg has it.

**2. Makes the text views of a file only when they show.** When a commit is selected, gitg makes three text views for each of its files. These are the unified view and the two halves of the split view. Each view loads the old file and the new file and colours them. A commit with more than one file starts with its files folded, so most of this work does not show.

Now the file keeps its hunks. It makes the unified view when the file opens, and the split view when Split is chosen, and then gives the hunks to that view. The file makes its Unif and Split pages, and with them the buttons of the switcher, when it first opens. After that, the switcher is as gitg has it. The file counts the added and removed lines for its header from the hunks, because no view counts them before the file opens. For each view that it makes, the file sends `renderer_added`, and `gitg-diff-view.patch` binds the view there.

**Why.** Before this change, a click on a commit with more than one file made the diff in 75 to 254 ms. The highlighting then kept the pane busy for up to 1.3 s after the click. After this change, the diff took 16 to 57 ms, with no busy time after it. This was measured under Xvfb on a copy of this repository at 0.3.0, in runs of twelve clicks, on 2026-09-27. The pages cost time too. On a commit that adds 118 files, the diff showed after 627 to 704 ms when each file made its pages at once. It showed after 536 to 575 ms when the pages wait for the first open.

**Cost.** A view is made when its file first opens, or when Split is first chosen. A commit with one file opens at once, and its diff took 20 to 81 ms.

**3. Makes the class public, with five members for the find bar of the diff.**

- `get_lines()` gives the lines of all the hunks of the file, in order, when the file shows its diff as text. It gives no lines for a binary file, and for a file that shows another page, such as an image.
- `split` is true when the Split page shows.
- `get_text_views()` gives the text views of the page that shows: one for Unif, two for Split, left then right. It gives none before the page is made.
- `get_line_offset()` gives where the text of a line starts in one of those views, from `gitg-diff-view-file-renderer-text.patch`.
- `page_shown` is sent when the file shows another page. The first open of a file is one of these, because it adds the Unif page. The view of a page is made before the signal is sent.

`expanded` was already a property. gittree sets it to open a folded file.

`renderer_list`, `renderer_added` and `add_renderer()` become internal. Their types are internal to this library, and a public class cannot have public members of such a type. `info` stays public, because a construct property must be public. Thus `gitg-diff-view-file-info.patch` makes its class public.

**Why.** The find bar of the diff searches every file of the commit, folded files included. It must know the lines of a file before its views are made, open a folded file, and mark the views when they are made. gitg keeps the lines of a file in a private field and has no public type for a file. A search of the widget tree gives the views, but not the lines of a folded file, or the buffer place of a line.

**Cost.** The class is public, so it is in the interface file of the library. The five members only read state or send a signal. `expanded` changes nothing that a click on the arrow does not.

**4. Lets gittree add items to the menu of a file, and opens the menu in a repository with no working tree.** gitg makes the menu of a file when the second mouse button presses its header. The menu has Open file, Open containing folder and Copy file path, and gitg connects it only when the repository has a working tree. Now the menu is connected in every repository. Before the menu opens, the new signal `populate_menu` gives the menu and the path of the file from the top of the repository, and a handler can add items to it. gitg's three items need a file on disk, so they show only with a working tree. A menu that has no item does not open.

**Why.** gittree adds Show history of this file to that menu. JetBrains IDEs, GitLens and GitKraken put the history of a file in the menu of the file, so a user looks for it there. The history of a file needs no file on disk, so the menu must open in a bare repository too.

**Cost.** One signal and one small method. In a repository with a working tree, gitg's items are the same, in the same order.

## gitg-diff-view-file-info.patch

Two changes of one word each.

**1. Makes the class `Gitg.DiffViewFileInfo` public.**

**Why.** `gitg-diff-view-file.patch` makes `Gitg.DiffViewFile` public, and its `info` is a construct property. The compiler refuses an internal construct property: "construct properties must be public". A public property cannot have an internal type, so the type of `info` becomes public too. Its members name only public types.

**Cost.** None. gittree does not use the class.

**2. Lets the guess of the content type take no file name.** The parameter `basename` of `guess_content_type()` can be null.

**Why.** In a repository with no working tree, a file has no place on disk, so its name on disk is null. The parameter could not be null, so the code that the compiler makes stopped the guess with the critical message "assertion 'basename != NULL' failed" each time such a repository showed a diff (seen in the UI test of the menu of a file, 2026-10-01). `GLib.ContentType.guess()` takes a null file name and guesses from the data.

**Cost.** None.

## gitg-diff-view-file.ui.patch

Removes the slide from the fold of each file. The revealer that holds the diff of a file has no transition.

**Why.** gitg gives the last file of a commit all the free height of the pane, so that its diff fills the pane. The revealer gets that height too, and the slide only changes the height that the revealer asks for. Thus the slide does not show. When a file opens, its text shows at once. When a file closes, its text stays at full height for the 250 ms of the slide, and then goes. The operator saw this as a slow close. After a click on the arrow, the text went after 250 to 270 ms, and came back after 0.1 ms (measured under Xvfb, 2026-09-26). With no transition, the text goes on the click.

**Cost.** No file of the pane slides open or shut.

## gitg-diff-view.patch

Six changes: the selection comes out, a text view is bound when its file makes it, the rows of the files are added in batches, gittree can read the rows, gittree can read the parent that the diff compares with, and the message wraps.

**1. Removes the `has_selection` property**, `on_selection_changed()` and the two calls to it, `get_selection()` and `clear_selection()`.

**Why.** The same cause as the renderer. `get_selection()` returns `PatchSet[]`, and the rest keep that property in step with the renderers.

`handle_selection` stays, as given above, and is false. gitrl-z's patch to this file also adds a property that sets the view of every file at once. gittree keeps the switcher of each file and does not take that property.

**Cost.** None. Selection only feeds staging, which gittree does not have.

**2. Binds a text view when the file makes it.** The bindings of `highlight`, `wrap-lines` and `tab-width`, and the value of `maxlines`, move from the delta callback to `bind_renderer()`. The file calls it through `renderer_added`, because the file now makes its views later, as `gitg-diff-view-file.patch` gives. The plan of the file, from part 3, keeps the value of `maxlines` that gitg gives at that point. Thus each view gets the same value as in gitg.

**Cost.** None. A view gets the same settings, at a later time.

**3. Adds the rows of the files in batches.** The loop over the diff does not make a row for each file now. It keeps a `DiffViewFilePlan` for each file: the file info, the kinds of view, the value of `maxlines` and the hunks. `add_files()` makes the rows of the first 20 plans at once. It makes the next 20 in an idle call at low priority, and it continues until all the rows show. If the diff changes before all the rows are made, the cancellable of the old diff stops the rest.

**Why.** Each row takes time to make, to add to the pane and to lay out. On a commit that adds 118 files, the diff showed after 536 to 575 ms, with all the rows at once. With batches, the first 20 rows showed after 102 to 149 ms, and all 118 rows were in the pane after 356 to 407 ms. A commit with 20 files or fewer shows as before. This was measured under Xvfb on a copy of this repository, on 2026-09-27.

**Cost.** On a big commit, the rows after the first 20 come in after the first paint. The scroll bar grows while they come in.

**4. Gives the rows of the files, and a signal when they change.** `get_files()` gives the row of each file, in the order of the pane. `files_changed` is sent after each batch of rows from part 3. The first batch of a new diff comes after the rows of the old diff are removed. Thus the signal also tells that the rows were replaced.

**Why.** The find bar of the diff searches the files of the commit that shows, and it must search again when more files come in. The grid that holds the rows is private. A `Gtk.Grid` gives its children in the reverse of the order in which they were added. For a commit of `a.txt` to `d.bin`, it gave `d.bin` first (measured in the UI test, 2026-10-01). Thus `get_files()` sorts the rows by their row in the grid, in one pass over the children. A first version asked the grid for the child at each row, and its time grew with the square of the number of files. On a commit of 1000 files with the find bar open, opening every file took 12.22 s with that version and 4.46 s with this one. With the bar closed, it took 4.13 s (measured under Xvfb, 2026-10-01).

**Cost.** One signal for each batch, and nothing when nothing listens.

**5. Gives the parent that the diff compares with**, through the read-only property `parent_commit`. It reads the parent that the details grid holds, which is the parent that the parents row of a merge chose.

**Why.** The history of removed lines, and the commit that last changed a line, dig from the parent that the diff shows. For a merge, the user can choose another parent in the details grid, and the grid keeps it in a private field.

**Cost.** None. The property only reads.

**6. Wraps the lines of the commit message at the width of the pane**, and measures the height of the message again when its width changes.

**Why.** The text view of the message did not wrap. Thus one long line of a message made the content of the pane wider than the pane. The pane then showed a horizontal scroll bar at its bottom, which moved the message, the names of the files and the diffs together. A long line of a diff has its own scroll bar at the end of its file, so the operator saw the bar at the bottom as wrong. A message with lines of 400 characters made the content 2753 pixels wide, in a pane of 1200 pixels (measured under Xvfb, 2026-10-02).

A text view that wraps finds its height before it knows its width. When the pane opened, the same message got 306 pixels for 177 pixels of text, and the rows of the files started below an empty space. The view now asks for its size again after each change of its width, and it gets 177 pixels (measured in the same test).

**Cost.** A long line of a message shows on two or more lines. The lines that the author broke stay broken at the same places. Each change of the width of the pane asks for the size of the message one more time.

## gitg-lanes.patch

Three changes.

**1. Lets the caller give `Gitg.Lanes` the parents of each commit, through `set_parents_func()`.** Two places read the parents of a commit: `prepare_lanes()` and `expand_lanes()`. They now ask `parent_ids()`, which calls that function when it is set, and reads the commit when it is not. `Gitg.Lanes` does not own the function: the caller owns the lanes and must live longer than them. An owned function held a reference to its caller, and the two were never freed.

Under a path limit, gittree shows only the commits that change the paths. It takes the parents of each one from `git log --parents`, which rewrites them to the nearest shown ancestors. libgit2 has no history simplification by path. The lanes must follow the rewritten parents, or the graph does not join from one shown commit to the next. The commit object holds its real parents, so the lanes need another source.

**2. Removes the `debug()` call at the start of `next()`.** Its arguments, the subject of the commit and its hash as text, are made for every commit even when debug output is off. On a tick of one branch of a history of 100000 commits, the lanes took 0.296 s with the call and 0.272 s without it (measured, 2026-09-25).

**3. Does not make the list of lanes for a hidden commit.** `next()` copied every lane into a new list for each commit, and the caller drops that list when `next()` returns false, which it does for a hidden commit. A hidden commit is one on the first parent line of the mainline that no ticked ref reaches. `next()` now gives null for it, as it already does for a commit that it saves as a miss. The same tick took 0.255 s with this change and the one above (measured).

**Cost.** None. With no path limit, no function is set, and the lanes read the parents of the commit as upstream does. Every caller, `Gitg.CommitModel` included, reads the list only when `next()` returns true. The pixel comparison with gitg is unchanged at zero differing pixels.

## resources.xml.patch

Removes two entries from the resource list of `libgitg`: `ui/gitg-authentication-dialog.ui` and `ui/gitg-sidebar.ui`.

**Why.** The authentication dialog is for remote operations, which are out of scope. `gitg-sidebar.vala` is not vendored, because the refs panel of gittree does not use `Gitg.Sidebar`, so that template has no class. A resource list that names a file which is not vendored does not compile. The other entries stay in upstream's order. The `/org/gnome/gitg` prefix stays, because the vendored Vala files name these paths in their `[GtkTemplate]` attributes. The resources are internal to the gittree binary, so the prefix cannot collide with the installed gitg.

**Cost.** None. gitrl-z also removes these two entries, but it sorts the list again, adds a comment, and has no patch for the file.
