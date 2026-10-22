# Layout parity with gitg

This suite compares the layout of the commit list of gitrl-f with the installed gitg. With every ref ticked, gitrl-f shows the same commits as the **All commits** view of gitg. Thus the two lists must have the same rows, the same space between lanes, the same commit dots and the same row height. The colours of the lanes and of the branch labels, and the shape of the label of the checked-out branch, are gitrl-f's own, so the suite does not compare the lists pixel by pixel.

## How to run it

```bash
sh tests/visual/test-parity.sh
```

Or through meson, where the suite is off by default:

```bash
meson setup _build -Dvisual_tests=true
meson test -C _build --suite visual
```

The suite needs Xvfb, xwd, ImageMagick, xdotool, dbus-run-session, gitg and python3-pil. If one of them is missing, the suite fails and names it. It writes its captures to `tests/visual/output/`, or to the directory in `GITRLF_VISUAL_OUT`.

## What it does

1. `fixture.sh` makes a repository of 15 commits with five branches, three remote branches, two tags and two merges. The dates are in 2024, so the two programs do not write a relative date. HEAD is on `topic`, not on `master`, and the fixture sets `gitg.mainline` to `refs/heads/master`. Thus the two lanes that gitg keeps at the left are both in use.
2. `test-parity.sh` starts its own Xvfb at 1400x900 on a free display. Each program runs with `capture.sh`, which gives it an empty environment: a new home folder, a new D-Bus session with no services that it can start, the Adwaita theme, DejaVu Sans 10, the C locale and UTC. The settings come from `keyfile` through the GSettings keyfile back end: gitg opens on **All commits**, both windows are 1400x900, and the divider of gitg is at 450 pixels, below the rows that the suite compares. gitrl-f starts with `-a`. The two programs select the first row.
3. `capture.sh` takes a capture every second, and stops when two captures in sequence are the same. gitrl-f hides its pane until a row gets a double click, so for gitrl-f the script then double-clicks the first row with xdotool, puts the pointer back, and waits again until two captures in sequence are the same.
4. The suite crops one region from each capture: the lanes, labels and subjects of the 15 rows. `measure.py` reads the layout of each region, and `compare-layout.py` compares the number of rows, the lane spacing, the dot radius and the row height. Each must be the same in the two programs. The suite does not compare the pane with the details and the diff. In gitrl-f that pane is below the refs panel and the list, and in gitg it is below the list only, so the two panes have different widths.
5. The suite also compares a capture of the whole gitrl-f window with `reference/gitrlf-window.png`. This finds changes to the parts that gitg does not draw in the same place: the refs panel with its checkboxes, and the pane with the details and the diff.
6. `selfcheck.sh` stretches the region of gitrl-f by 30%, and the layout comparison must find the change. A comparison that cannot fail is not a test.

## Results

Measured on 2026-10-22 with gitg 44-1build2 and GTK 3.24.41 on Ubuntu 24.04.

| Comparison | Result |
|---|---|
| gitg list against gitg list, two runs | 0 differing pixels |
| gitrl-f window against gitrl-f window, two runs | 0 differing pixels |
| gitrl-f window against the reference | 0 differing pixels |

Both regimes of the pixel comparisons are 0, so the bound is 0. There is no tolerance.

| Layout | gitg | gitrl-f | gitrl-f stretched by 30% |
|---|---|---|---|
| Rows | 15 | 15 | 15 |
| Lane spacing | 16 px | 16 px | 21 px |
| Dot radius | 5.0 px | 5.0 px | 6.0 px |
| Row height | 23 px | 23 px | 30 px |

Before 2026-10-22, the suite compared the two lists pixel by pixel. On 2026-10-01 it found 0 differing pixels.

## The region

The region in `test-parity.sh` is a constant of the fixture and the window size. If you change one of these, find the region again from the captures in the output directory:

| Region | gitg | gitrl-f |
|---|---|---|
| List | `490x345+206+51` | `490x345+191+76` |

Each region puts the first row and the first lane at the same place. In gitrl-f, the row of titles above the list puts the first row 25 pixels lower than in gitg, and the lanes start 15 pixels further left. The list region stops at 490 pixels, before the end of the subject column of gitg, which is narrower because gitg shows two more columns. The suite fails if the region is nearly blank, because a wrong region can hold background only, and two backgrounds are the same.

To write the reference window again after a change to the look that you want:

```bash
GITRLF_VISUAL_UPDATE=1 sh tests/visual/test-parity.sh
```

## What this suite found

The first run found 92523 differing pixels in one file section of the diff. The file header of gitrl-f had no background, and its count badge had no bar. gitrl-f opens the repository before GTK opens the display, to report a bad ref with no display. That first call of `Gitg.init()` found no screen and did not add the stylesheet of gitg, and the later calls do nothing. The UI tests start GTK first, so they did not see this. gitrl-f now adds the stylesheet in its `startup()`, and `tests/ui/test-startup.vala` starts gitrl-f as the real program does.

## A warning about `measure.py`

The first method, which looked for runs of lane colour, took label pills and curves for commit dots. It reported a row height of 7 px on this fixture. The present method removes the lines with a morphological opening, and removes the pills by their width. If you change it, run it on the list captures and on the captures that `selfcheck.sh` changes, and make sure that it names the change.

## Files

| File | Role |
|---|---|
| `fixture.sh` | the repository |
| `keyfile` | the GSettings of both programs |
| `settings.ini` | the GTK theme and font |
| `session.conf` | a D-Bus session with no services |
| `capture.sh` | runs one program in the empty environment and captures the screen |
| `compare.sh` | counts the pixels that differ between two images |
| `compare-layout.py` | compares the layout of two lists, as `measure.py` reads it |
| `selfcheck.sh` | proves that the layout comparison can fail |
| `measure.py` | reads the geometry of a list |
| `test-parity.sh` | the suite |
| `reference/gitrlf-window.png` | the whole gitrl-f window on the fixture |
