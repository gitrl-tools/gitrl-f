#!/usr/bin/env python3
"""Read the geometry of a commit graph from a capture of the list.

The pixel comparison says how many pixels differ. This says what moved: the
place of the first lane and the first row, the space between lanes, the
radius of a commit dot, the height of a row, and the colour at the centre of
each dot, read from the capture alone.

A lane line is two pixels wide and a dot is ten, so an opening of the mask of
lane colours removes the lines and keeps the dots. A label pill is wider than
a dot and is dropped by its size. Earlier versions of this method, which
looked for runs of colour without the opening, took pills and curves for
dots and reported values that looked right and were wrong.

    measure.py <image.png> [--json]
"""

import json
import sys
from collections import Counter

try:
    from PIL import Image, ImageFilter
except ImportError:
    print("python3-pil is required", file=sys.stderr)
    raise SystemExit(2)


DOT_MAX = 14
DOT_MIN = 7
MERGE = 3
OPENING = 5
PALETTE = [
    (196, 160, 0),
    (78, 154, 6),
    (206, 92, 0),
    (32, 74, 135),
    (108, 53, 102),
    (164, 0, 0),
    (138, 226, 52),
    (252, 175, 62),
    (114, 159, 207),
    (252, 233, 79),
    (136, 138, 133),
    (173, 127, 168),
    (233, 185, 110),
    (239, 41, 41),
]
TOLERANCE = 30


def cluster(values):
    """Sorted centres of values that lie within MERGE of each other."""
    groups = []

    for value in sorted(values):
        if groups and value - groups[-1][-1] <= MERGE:
            groups[-1].append(value)
        else:
            groups.append([value])

    return [sum(group) / len(group) for group in groups]


def components(mask, width, height):
    """Bounding boxes of the four connected regions of a mask."""
    seen = bytearray(width * height)
    boxes = []

    for start in range(width * height):
        if not mask[start] or seen[start]:
            continue

        seen[start] = 1
        stack = [start]
        left, top, right, bottom = width, height, -1, -1

        while stack:
            index = stack.pop()
            x, y = index % width, index // width
            left, top = min(left, x), min(top, y)
            right, bottom = max(right, x), max(bottom, y)

            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbour = ny * width + nx

                    if mask[neighbour] and not seen[neighbour]:
                        seen[neighbour] = 1
                        stack.append(neighbour)

        boxes.append((left, top, right, bottom))

    return boxes


def find_dots(image):
    """Dots as (centre x, centre y, centre colour, horizontal diameter)."""
    width, height = image.size
    pixels = list(image.getdata())
    slots = [palette_index(pixel) for pixel in pixels]
    mask = Image.new("L", image.size)
    mask.putdata([0 if slot is None else 255 for slot in slots])
    opened = mask.filter(ImageFilter.MinFilter(OPENING)).filter(ImageFilter.MaxFilter(OPENING))
    kept = [value > 0 for value in opened.getdata()]
    dots = []

    for left, top, right, bottom in components(kept, width, height):
        box_width, box_height = right - left + 1, bottom - top + 1

        if not (DOT_MIN <= box_width <= DOT_MAX and DOT_MIN <= box_height <= DOT_MAX):
            continue

        cx, cy = (left + right) // 2, (top + bottom) // 2
        inside = [slots[y * width + x] for y in range(top, bottom + 1) for x in range(left, right + 1)]
        slot = Counter(s for s in inside if s is not None).most_common(1)[0][0]
        widest = max(run(slots, width, cx, y, slot) for y in range(top, bottom + 1))

        if widest > DOT_MAX:
            continue

        dots.append((cx, cy, image.getpixel((cx, cy)), run(slots, width, cx, cy, slot)))

    return dots


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    result = measure(sys.argv[1])

    if "--json" in sys.argv:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for key in sorted(result):
            print("{}: {}".format(key, result[key]))

    return 0



def measure(path):
    image = Image.open(path).convert("RGB")
    dots = find_dots(image)

    if len(dots) < 2:
        raise SystemExit("found fewer than two commit dots in {}".format(path))

    rows = cluster([y for _, y, _, _ in dots])
    lanes = cluster([x for x, _, _, _ in dots])
    row_gaps = [round(b - a) for a, b in zip(rows, rows[1:])]
    lane_gaps = [round(b - a) for a, b in zip(lanes, lanes[1:])]
    placed = []

    for x, y, colour, _ in sorted(dots, key=lambda dot: (dot[1], dot[0])):
        row = min(range(len(rows)), key=lambda i: abs(rows[i] - y))
        lane = min(range(len(lanes)), key=lambda i: abs(lanes[i] - x))
        placed.append([row, lane, "#%02x%02x%02x" % colour])

    return {
        "dot_radius": Counter(d for _, _, _, d in dots).most_common(1)[0][0] / 2.0,
        "dots": placed,
        "first_lane_x": round(lanes[0]),
        "first_row_y": round(rows[0]),
        "lane_spacing": Counter(lane_gaps).most_common(1)[0][0] if lane_gaps else None,
        "row_height": Counter(row_gaps).most_common(1)[0][0] if row_gaps else None,
    }


def palette_index(pixel):
    """The palette slot a pixel is drawn in, or None."""
    best = None
    best_distance = TOLERANCE + 1

    for index, colour in enumerate(PALETTE):
        distance = sum(abs(a - b) for a, b in zip(pixel, colour))

        if distance < best_distance:
            best, best_distance = index, distance

    return best



def run(slots, width, x, y, slot):
    """Length of the horizontal run of one palette slot through a pixel."""
    x0 = x1 = x

    while x0 > 0 and slots[y * width + x0 - 1] == slot:
        x0 -= 1

    while x1 < width - 1 and slots[y * width + x1 + 1] == slot:
        x1 += 1

    return x1 - x0 + 1 if slots[y * width + x] == slot else 0

if __name__ == "__main__":
    sys.exit(main())
