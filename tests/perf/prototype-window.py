#!/usr/bin/env python3
"""Time the window of the Python prototype as gitree-bench --window times gitree's.

The prototype is read from commit 5ccd222 of the dotfiles repository, as
tests/parity/dump-prototype.py reads it. The script opens its window on a
repository, ticks every ref, ticks each named ref alone, reloads, and prints
each time and the peak resident memory in the words gitree-bench uses. Each
step is timed until GTK has no more events to handle, so the draw is included.

    prototype-window.py <repository> [<full ref name>...]
"""

import importlib.util
import os
import resource
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))


def drain(gtk):
    while gtk.events_pending():
        gtk.main_iteration()


def load():
    path = os.path.join(os.path.dirname(HERE), "parity", "dump-prototype.py")
    spec = importlib.util.spec_from_file_location("dump_prototype", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.load()


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2

    prototype = load()
    gtk = prototype.Gtk
    os.chdir(sys.argv[1])

    start = time.perf_counter()
    options, paths = prototype.parse_args(["-a"])
    top = prototype.git("rev-parse", "--show-toplevel").strip()
    common = prototype.git("rev-parse", "--path-format=absolute", "--git-common-dir").strip()
    refs = prototype.read_refs()
    ticks_file = os.path.join(common, prototype.TICKS_FILE)
    ticks = prototype.resolve_ticks(options, refs, prototype.load_ticks(ticks_file, refs))
    window = prototype.Viewer(top, ticks_file, refs, ticks, paths)
    window.show_all()
    drain(gtk)
    print("window open {:.3f} s".format(time.perf_counter() - start), flush=True)

    start = time.perf_counter()
    window.set_ticks({ref.name for ref in refs})
    drain(gtk)
    print("window tick, every ref ticked: {:.3f} s".format(time.perf_counter() - start))

    for name in sys.argv[2:]:
        start = time.perf_counter()
        window.set_ticks({name})
        drain(gtk)
        print("window tick, only {}: {:.3f} s".format(name, time.perf_counter() - start))

    start = time.perf_counter()
    window.reload()
    drain(gtk)
    print("window reload {:.3f} s".format(time.perf_counter() - start))

    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
    print("peak resident memory {:.0f} MiB".format(peak))
    return 0


if __name__ == "__main__":
    sys.exit(main())
