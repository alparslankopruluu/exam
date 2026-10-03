"""Rewrites <circle> and <ellipse> as equivalent <path> arcs.

svg2vectordrawable drops ellipses inside transformed groups, so the Android
export runs every illustration through this first.
Usage: python3 svg_shapes_to_paths.py in.svg out.svg
"""
import re
import sys


def attrs(tag):
    return dict(re.findall(r'([\w:-]+)="([^"]*)"', tag))


def to_path(match):
    tag = match.group(0)
    kind = match.group(1)
    a = attrs(tag)
    cx, cy = float(a.pop("cx", 0)), float(a.pop("cy", 0))
    if kind == "circle":
        rx = ry = float(a.pop("r"))
    else:
        rx, ry = float(a.pop("rx")), float(a.pop("ry"))
    d = (f"M{cx - rx} {cy} a{rx} {ry} 0 1 0 {2 * rx} 0 "
         f"a{rx} {ry} 0 1 0 {-2 * rx} 0 Z")
    rest = " ".join(f'{k}="{v}"' for k, v in a.items())
    return f'<path d="{d}" {rest}/>'


src = open(sys.argv[1]).read()
out = re.sub(r"<(circle|ellipse)\b[^>]*/>", to_path, src)
open(sys.argv[2], "w").write(out)
