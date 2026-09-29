# Pixel parity with gitg

This suite compares gitree with the installed gitg, pixel by pixel. With every ref ticked, gitree shows the same commits as the **All commits** view of gitg. Thus the two lists must be the same image.

## How to run it

```bash
sh tests/visual/test-parity.sh
```

Or through meson, where the suite is off by default:

```bash
meson setup _build -Dvisual_tests=true
meson test -C _build --suite visual
```

The suite needs Xvfb, xwd, ImageMagick, xdotool, dbus-run-session, gitg and python3-pil. If one of them is missing, the suite fails and names it. It writes its captures to `tests/visual/output/`, or to the directory in `GITREE_VISUAL_OUT`.

## What it does

1. `fixture.sh` makes a repository of 15 commits with five branches, three remote branches, two tags and two merges. The dates are in 2024, so the two programs do not write a relative date. HEAD is on `topic`, not on `master`, and the fixture sets `gitg.mainline` to `refs/heads/master`. Thus the two lanes that gitg keeps at the left are both in use.
2. `test-parity.sh` starts its own Xvfb at 1400x900 on a free display. Each program runs with `capture.sh`, which gives it an empty environment: a new home folder, a new D-Bus session with no services that it can start, the Adwaita theme, DejaVu Sans 10, the C locale and UTC. The settings come from `keyfile` through the GSettings keyfile back end: gitg opens on **All commits**, both windows are 1400x900, and the divider of gitg is at 450 pixels, below the rows that the suite compares. gitree starts with `-a`. The two programs select the first row.
3. `capture.sh` takes a capture every second, and stops when two captures in sequence are the same. gitree hides its pane until a row gets a click, so for gitree the script then clicks the first row with xdotool, puts the pointer back, and waits again until two captures in sequence are the same.
4. The suite crops one region from each capture and counts the pixels that differ with ImageMagick. The region is the lanes, labels and subjects of the 15 rows. The suite does not compare the pane with the details and the diff. In gitree that pane is below the refs panel and the list, and in gitg it is below the list only, so the two panes have different widths.
5. The suite also compares a capture of the whole gitree window with `reference/gitree-window.png`. This finds changes to the parts that gitg does not draw in the same place: the refs panel with its checkboxes, and the pane with the details and the diff.
6. `selfcheck.sh` changes one lane colour, and moves the region by one pixel. The comparison must find each change. A comparison that cannot fail is not a test.
7. If the lists differ, `measure.py` reads the geometry of the two lists and names what moved: the place of the first lane and the first row, the lane spacing, the dot radius, the row height, or the colour of a dot.

## Results

Measured on 2026-09-26 with gitg 44-1build2 and GTK 3.24 on Ubuntu 24.04.

| Comparison | Differing pixels |
|---|---|
| gitg list against gitg list, two runs | 0 |
| gitree window against gitree window, two runs | 0 |
| gitree list against gitg list | 0 |
| gitree window against the reference | 0 |

Both regimes are 0, so the bound is 0. There is no tolerance.

The self check found each change: 835 pixels for the changed lane colour and 16910 for the shift in the list.

`measure.py` read the same geometry from the two lists: lane spacing 16 px, dot radius 5.0 px, row height 23 px.

## The region

The region in `test-parity.sh` is a constant of the fixture and the window size. If you change one of these, find the region again from the captures in the output directory:

| Region | gitg | gitree |
|---|---|---|
| List | `490x345+206+51` | `490x345+206+51` |

The list region stops at 490 pixels, before the end of the subject column of gitg, which is narrower because gitg shows two more columns. The suite fails if the region is nearly blank, because a wrong region can hold background only, and two backgrounds are the same.

To write the reference window again after a change to the look that you want:

```bash
GITREE_VISUAL_UPDATE=1 sh tests/visual/test-parity.sh
```

## What this suite found

The first run found 92523 differing pixels in one file section of the diff. The file header of gitree had no background, and its count badge had no bar. gitree opens the repository before GTK opens the display, to report a bad ref with no display. That first call of `Gitg.init()` found no screen and did not add the stylesheet of gitg, and the later calls do nothing. The UI tests start GTK first, so they did not see this. gitree now adds the stylesheet in its `startup()`, and `tests/ui/test-startup.vala` starts gitree as the real program does.

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
| `selfcheck.sh` | proves that the comparison can fail |
| `measure.py` | reads the geometry of a list |
| `test-parity.sh` | the suite |
| `reference/gitree-window.png` | the whole gitree window on the fixture |
