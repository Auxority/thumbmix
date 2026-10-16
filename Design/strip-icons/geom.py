"""Helpers for drawing a new or changed icon in icons.py: compute where a detail line meets an outline, never guess.

    >>> from geom import GAP, ellipse_y, vline
    >>> vline(9, ellipse_y(12, 6, 7, 2.2, 9) + GAP, 14.6 - GAP)   # a lug from a drum's head down to its base
    'M9 8.79V13.8'

Paste the resulting path into icons.py; generate.py only reads icons.py.
"""
import math

GAP = 0.8  # a detail line that doesn't touch its outline stops this far short of it


def f(value):
    """A number as icons.py writes it: at most two decimals, no trailing zeros."""
    return f"{value:.2f}".rstrip("0").rstrip(".")


def ellipse_y(cx, cy, rx, ry, x, lower=True):
    """The y of an ellipse's lower (or upper) edge at x: where a line from a drum head or shell meets it."""
    dy = ry * math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
    return cy + dy if lower else cy - dy


def ellipse_x(cx, cy, rx, ry, y, right=True):
    dx = rx * math.sqrt(max(0.0, 1 - ((y - cy) / ry) ** 2))
    return cx + dx if right else cx - dx


def circle_y(cx, cy, r, x, lower=True):
    return ellipse_y(cx, cy, r, r, x, lower)


def polar(cx, cy, r, degrees):
    """A point on a circle; 0 degrees points right, 90 down (SVG's y runs down)."""
    a = math.radians(degrees)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def tangent_point(cx, cy, r, px, py, outer=True):
    """Where a line from (px, py) touches a circle, like tape leaving a reel; outer picks the side away from the centre line."""
    d = math.hypot(px - cx, py - cy)
    toward = math.atan2(py - cy, px - cx)
    spread = math.acos(r / d)
    a = toward + spread if outer else toward - spread
    return cx + r * math.cos(a), cy + r * math.sin(a)


def vline(x, y1, y2):
    return f"M{f(x)} {f(y1)}V{f(y2)}"


def hline(y, x1, x2):
    return f"M{f(x1)} {f(y)}H{f(x2)}"


def seg(p, q):
    return f"M{f(p[0])} {f(p[1])}L{f(q[0])} {f(q[1])}"
