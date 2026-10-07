#!/usr/bin/env python3
"""Draw Cursor Finder's textures as 32-bit TGA files in Media/: the markers round the cursor (Ring, Crosshair,
Corners, Diamond, Triangle, Flag; each 128 px, the cursor's tip at the middle), the Predator's dot (Dot) and its
icon for the settings (Predator), and the arrow over a mob (Arrow).

All are white with a dark outline, so the game can tint them with SetVertexColor and they still read on snow
and in shadow alike. Run from anywhere: python3 tools/make_media.py
"""
import math
import os
import struct

MEDIA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
SS = 4  # supersampling per axis, for smooth edges


def tga(path, size, pixel):
    """An uncompressed 32-bit TGA, top-left origin; pixel(x, y) gives (r, g, b, a) as floats 0..1."""
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28))
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixel(x, y)
            out += bytes((int(b * 255 + .5), int(g * 255 + .5), int(r * 255 + .5), int(a * 255 + .5)))
    with open(path, "wb") as f:
        f.write(out)


def coverage(x, y, inside):
    """How much of the pixel at (x, y) lies inside the shape."""
    n = 0
    for i in range(SS):
        for j in range(SS):
            if inside(x + (i + .5) / SS, y + (j + .5) / SS):
                n += 1
    return n / (SS * SS)


def white_on_dark(body, edge):
    """A white body over a dark edge: the colour and alpha of one pixel."""
    a = max(body, edge)
    if a == 0:
        return (0, 0, 0, 0)
    v = body / a
    return (v, v, v, a)


# the ring: a white band between two dark edges
def ring(x, y, c=64):
    def band(lo, hi):
        return lambda px, py: lo <= math.hypot(px - c, py - c) <= hi
    return white_on_dark(coverage(x, y, band(48, 56)), coverage(x, y, band(44.5, 59.5)) * 0.85)


# the arrow over a mob: pointing down
ARROW = [(20, 4), (44, 4), (44, 28), (58, 28), (32, 58), (6, 28), (20, 28)]


def inside_polygon(px, py, poly):
    inside = False
    for k in range(len(poly)):
        x1, y1 = poly[k]
        x2, y2 = poly[(k + 1) % len(poly)]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def edge_distance(px, py, poly):
    best = float("inf")
    for k in range(len(poly)):
        (ax, ay), (bx, by) = poly[k], poly[(k + 1) % len(poly)]
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(px - ax - t * dx, py - ay - t * dy))
    return best


def arrow(x, y):
    body = coverage(x, y, lambda px, py: inside_polygon(px, py, ARROW) and edge_distance(px, py, ARROW) >= 1.5)
    edge = coverage(x, y, lambda px, py: inside_polygon(px, py, ARROW) or edge_distance(px, py, ARROW) <= 2.5)
    return white_on_dark(body, edge * 0.9)


# ------------------------------------------------------------------------------------------------ more markers
# drawn on the same 128 px square, its middle on the cursor's tip; 3 px of dark outline
C, EDGE = 64.0, 3.0


def inside_rects(px, py, rects, grow=0.0):
    return any(x0 - grow <= px <= x1 + grow and y0 - grow <= py <= y1 + grow for x0, y0, x1, y1 in rects)


def from_rects(rects):
    def pixel(x, y):
        return white_on_dark(coverage(x, y, lambda px, py: inside_rects(px, py, rects)),
                             coverage(x, y, lambda px, py: inside_rects(px, py, rects, EDGE)) * 0.85)
    return pixel


def from_polygon(poly, extra=()):
    def body(px, py):
        return (inside_polygon(px, py, poly) and edge_distance(px, py, poly) >= 0.5) or inside_rects(px, py, extra)

    def edge(px, py):
        return inside_polygon(px, py, poly) or edge_distance(px, py, poly) <= EDGE or inside_rects(px, py, extra, EDGE)

    def pixel(x, y):
        return white_on_dark(coverage(x, y, body), coverage(x, y, edge) * 0.85)
    return pixel


# a crosshair: four bars, the middle left empty for the target
T = 4.5
crosshair = from_rects([(10, C - T, 46, C + T), (82, C - T, 118, C + T),
                        (C - T, 10, C + T, 46), (C - T, 82, C + T, 118)])


# the corners of a lock-on frame
def corner_bars(t=8, n=30, lo=16, hi=112):
    bars = []
    for cx, sx in ((lo, 1), (hi, -1)):
        for cy, sy in ((lo, 1), (hi, -1)):
            for w, h in ((n, t), (t, n)):
                xa, xb = sorted((cx, cx + sx * w))
                ya, yb = sorted((cy, cy + sy * h))
                bars.append((xa, ya, xb, yb))
    return bars


corners = from_rects(corner_bars())


def diamond(x, y):
    d = lambda px, py: abs(px - C) + abs(py - C)
    return white_on_dark(coverage(x, y, lambda px, py: 42 <= d(px, py) <= 52),
                         coverage(x, y, lambda px, py: 42 - EDGE * 1.4 <= d(px, py) <= 52 + EDGE * 1.4) * 0.85)


# above the cursor, its point down on the tip
triangle = from_polygon([(40, 16), (88, 16), (64, 56)])

# its pole planted on the tip, the cloth up and to the right
flag = from_polygon([(C + 2.5, 6), (112, 20), (C + 2.5, 36)], extra=[(C - 2.5, 6, C + 2.5, C)])


# the Predator's dot (64 px): a white core, a dark rim, a soft halo (tinted red in the game)
def dot(x, y, c=32, r=12):
    d = math.hypot(x + .5 - c, y + .5 - c)
    core = coverage(x, y, lambda px, py: math.hypot(px - c, py - c) <= r)
    rim = coverage(x, y, lambda px, py: math.hypot(px - c, py - c) <= r + 3)
    halo = max(0.0, 1 - (d - r) / 18) ** 2 * 0.45 if d > r else 0.0
    a = max(core, rim * 0.85, halo)
    if a == 0:
        return (0, 0, 0, 0)
    # the halo is white too (it glows in the tint), the rim dark
    v = (core + (halo if rim < 0.5 else 0)) / a
    return (min(1, v),) * 3 + (a,)


# the Predator's icon for the settings: three dots in a triangle
def predator(x, y):
    pts = [(64 + 34 * math.cos(math.radians(a)), 64 + 34 * math.sin(math.radians(a))) for a in (270, 30, 150)]
    core = coverage(x, y, lambda px, py: any(math.hypot(px - qx, py - qy) <= 11 for qx, qy in pts))
    rim = coverage(x, y, lambda px, py: any(math.hypot(px - qx, py - qy) <= 14 for qx, qy in pts))
    return white_on_dark(core, rim * 0.85)


if __name__ == "__main__":
    for name, size, pixel in (("Ring", 128, ring), ("Arrow", 64, arrow), ("Crosshair", 128, crosshair),
                              ("Corners", 128, corners), ("Diamond", 128, diamond), ("Triangle", 128, triangle),
                              ("Flag", 128, flag), ("Dot", 64, dot), ("Predator", 128, predator)):
        tga(os.path.join(MEDIA, name + ".tga"), size, pixel)
        print("Media/%s.tga written" % name)
