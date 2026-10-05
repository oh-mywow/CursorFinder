#!/usr/bin/env python3
"""Draw Cursor Finder's two textures as 32-bit TGA files: Media/Ring.tga and Media/Arrow.tga.

Both are white with a dark outline, so the game can tint them with SetVertexColor and they still read on snow
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


if __name__ == "__main__":
    tga(os.path.join(MEDIA, "Ring.tga"), 128, ring)
    tga(os.path.join(MEDIA, "Arrow.tga"), 64, arrow)
    print("Media/Ring.tga and Media/Arrow.tga written")
