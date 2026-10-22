#!/usr/bin/env python3
"""Compare the layout of two commit graphs, as measure.py reads them.

The number of rows, the space between lanes, the radius of a commit dot and
the height of a row. The colours are gitrl-f's own and are not compared. Each
property is printed with its two values, and the exit status is 1 if one
differs.

    compare-layout.py <first.json> <second.json>
"""

import json
import sys

COMPARED = ["lane_spacing", "dot_radius", "row_height"]


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    first, second = (json.load(open(path)) for path in sys.argv[1:])
    values = {"rows": (len(first["dots"]), len(second["dots"]))}

    for key in COMPARED:
        values[key] = (first[key], second[key])

    status = 0

    for key, (a, b) in values.items():
        verdict = "match" if a == b else "DIFFERS"
        print("  {}: {} and {} ({})".format(key, a, b, verdict))

        if a != b:
            status = 1

    return status


if __name__ == "__main__":
    sys.exit(main())
