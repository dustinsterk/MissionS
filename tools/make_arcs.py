#!/usr/bin/env python3
"""Pre-render the static arc rings of MissionS as PNGs (arcs/*.png).

The dash shows these as plain Images (GPU textures) instead of drawing them
with Canvas, which is CPU-rasterised on the IC7. Re-run this if you change a
dial's radius, start angle or sweep in Cluster.qml / SideDial.qml:

    python3 tools/make_arcs.py          (needs Pillow: pip install pillow)

Angles are degrees clockwise from 12 o'clock, same as the QML. A negative
sweep runs anticlockwise.
"""
import os
from PIL import Image, ImageDraw

SS = 4                                   # supersampling for smooth edges
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "arcs")

def hexcol(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def arc_png(name, radius, arc_radius, start, sweep, width, color,
            count=1, spacing=0, round_cap=False):
    size = int(radius * 2)
    big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    c = radius * SS
    a0, a1 = (start, start + sweep) if sweep >= 0 else (start + sweep, start)
    col = hexcol(color)
    for i in range(count):
        r = (arc_radius - i * spacing) * SS
        w = width * SS
        ro = r + w / 2                     # PIL draws the band inward from the box
        box = [c - ro, c - ro, c + ro, c + ro]
        d.arc(box, a0 - 90, a1 - 90, fill=col, width=int(round(w)))
        if round_cap:
            import math
            for a in (a0, a1):
                x = c + r * math.sin(math.radians(a)); y = c - r * math.cos(math.radians(a))
                d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=col)
    img = big.resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("arcs/%s.png" % name)

# ---- rev counter (radius 172) ----
TR = 172
arc_png("tacho_sport_rings", TR, TR - 16, 225, 270, 2, "#ff2d2d", count=5, spacing=5)
arc_png("tacho_band_base",   TR, TR - 62, 150, 240, 34, "#3a140a")
arc_png("tacho_band_mask",   TR, TR - 62, 150, 240, 34, "#ffffff")

# ---- side dials: name, radius, start, sweep (must match Cluster.qml) ----
for name, R, start, sweep in (("speed", 108, 190, 180),
                              ("oil",   108, 170, -180),
                              ("fuel",   64, 200, 140),
                              ("cool",   64, 160, -140)):
    arc_png(name + "_sport", R, R - 11, start, sweep, 3, "#ff2d2d")
    arc_png(name + "_track", R, R - 14, start, sweep, 7, "#ff4d1c", round_cap=True)
