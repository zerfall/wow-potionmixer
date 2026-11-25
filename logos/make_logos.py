#!/usr/bin/env python3
"""Pixel-art logo for Potion Mixer: the Split Flask.

One flask, half healing red and half mana blue, meeting in a purple seam, on a
bronze-framed violet tile. Drawn on a 32x32 grid and written as:

    logos/potion-mixer-logo-32.png        the pixel art itself
    logos/potion-mixer-logo-400.png       CurseForge's project avatar (must be 400x400)
    logos/potion-mixer-logo-512.png       for the addon websites
    logos/potion-mixer-logo-1024.png
    logos/potion-mixer-logo.aseprite      layers "Frame" and "Art" (when Aseprite is installed)
    logos/potion-mixer.gpl                the palette (GIMP format, Aseprite reads it)
    PotionMixer/Media/Logo.tga            64x64 icon for the game's AddOns list (## IconTexture)

All scaling is nearest neighbour, so the pixels stay sharp.

Usage: python3 logos/make_logos.py   (needs Pillow)
Aseprite is looked up in $ASEPRITE, on the PATH and in the Steam library.
"""
import math
import os
import shutil
import subprocess
import tempfile

from PIL import Image

S = 32
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
ADDON_MEDIA = os.path.join(os.path.dirname(OUT_DIR), "PotionMixer", "Media")


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


C = {name: rgb(value) for name, value in {
    "ink": "#140e1c",                                        # outlines
    "frame_hi": "#e2b260", "frame": "#a8743a", "frame_lo": "#6a421f",
    "bg_top": "#2b2649", "bg_mid": "#231f3d", "bg_low": "#1b1830", "glow": "#353063",
    "glass_hi": "#eef8fc", "glass": "#a9c7d8", "glass_lo": "#6f8ea6",
    "red_hi": "#ff7d66", "red": "#e03a3a", "red_lo": "#991d2e",
    "blue_hi": "#6fc2ff", "blue": "#2f72e6", "blue_lo": "#1c3c9a",
    "purple_hi": "#d494ff", "purple": "#a24ee0",
    "cork_hi": "#e3b077", "cork": "#b07a44", "cork_lo": "#774b26",
    "white": "#fdfaf1",
}.items()}


class Canvas:
    def __init__(self):
        self.px = [[None] * S for _ in range(S)]  # everything, flattened
        self.layers = {"frame": [[None] * S for _ in range(S)], "art": [[None] * S for _ in range(S)]}
        self.layer = "art"                        # tile() draws on "frame"

    def set(self, x, y, color):
        if 0 <= x < S and 0 <= y < S and color is not None:
            color = C[color] if isinstance(color, str) else color
            self.px[y][x] = color
            self.layers[self.layer][y][x] = color

    def image(self, scale=1, layer=None):
        source = self.layers[layer] if layer else self.px
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for y in range(S):
            for x in range(S):
                if source[y][x]:
                    img.putpixel((x, y), source[y][x])
        return img.resize((S * scale, S * scale), Image.NEAREST) if scale > 1 else img


def in_rounded(x, y, x0, y0, x1, y1, r):
    """Pixel (x, y) inside the rectangle x0..x1, y0..y1 with corners rounded by r."""
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.6


def tile(c, glow_center, glow_radius):
    """Square badge: dark outline, bronze bevel, deep violet ground with a soft glow."""
    c.layer = "frame"
    for y in range(S):
        for x in range(S):
            if not in_rounded(x, y, 0, 0, S - 1, S - 1, 3):
                continue
            if not in_rounded(x, y, 1, 1, S - 2, S - 2, 2):
                c.set(x, y, "ink")
            elif not in_rounded(x, y, 2, 2, S - 3, S - 3, 1):
                lit = x + y < S - 1          # top-left half of the ring catches the light
                c.set(x, y, "frame_hi" if (x <= 2 or y <= 2) and lit else
                            "frame_lo" if (x >= S - 3 or y >= S - 3) and not lit else "frame")
            elif not in_rounded(x, y, 3, 3, S - 4, S - 4, 0):
                c.set(x, y, "ink")
            else:
                band = "bg_top" if y < 12 else "bg_mid" if y < 21 else "bg_low"
                # dither the band edges for a pixel-art gradient
                if y in (11, 20) and (x + y) % 2 == 0:
                    band = "bg_mid" if y == 11 else "bg_low"
                c.set(x, y, band)
                d = math.hypot(x - glow_center[0], y - glow_center[1])
                if d < glow_radius - 1 or (d < glow_radius and (x + y) % 2 == 0):
                    c.set(x, y, "glow")
    c.layer = "art"


def outline(c, inside):
    """Ink every pixel that touches a drawn shape (inside(x, y) is True) from outside."""
    for y in range(S):
        for x in range(S):
            if inside(x, y):
                continue
            if any(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c.set(x, y, "ink")


def shade(nx, ny, hi=-0.3, lo=0.42):
    """Light from the top left: -1..1 position -> '_hi', '' or '_lo'."""
    v = nx * 0.6 + ny * 0.8
    return "_hi" if v < hi else "_lo" if v > lo else ""


def split_flask():
    c = Canvas()
    cx, cy, r = 16.0, 19.6, 8.3
    tile(c, glow_center=(16, 18), glow_radius=13)

    def in_body(x, y):
        return math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r

    def in_neck(x, y):
        return 14 <= x <= 17 and 7 <= y <= 12

    def in_lip(x, y):
        return 13 <= x <= 18 and y == 6

    def in_cork(x, y):
        return 14 <= x <= 17 and 3 <= y <= 5

    def inside(x, y):
        return in_body(x, y) or in_neck(x, y) or in_lip(x, y) or in_cork(x, y)

    outline(c, inside)
    surface = 15
    for y in range(S):
        for x in range(S):
            if in_cork(x, y):
                c.set(x, y, "cork_hi" if x == 14 else "cork_lo" if x == 17 or y == 5 else "cork")
            elif in_lip(x, y):
                c.set(x, y, "glass_hi" if x <= 15 else "glass")
            elif in_neck(x, y) and not in_body(x, y):
                c.set(x, y, "glass_hi" if x == 14 else "glass_lo" if x == 17 else "glass")
            elif in_body(x, y):
                nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                if y < surface:
                    c.set(x, y, "glass" + shade(nx, ny, hi=-0.75, lo=0.05))
                    continue
                # the two potions meet along a wavy purple seam
                seam = round(15.5 + 1.2 * math.sin((y - surface) / 1.6))
                if x == seam:
                    c.set(x, y, "purple_hi" if y == surface else "purple")
                    continue
                base = "red" if x < seam else "blue"
                c.set(x, y, base + ("_hi" if y == surface else shade(nx, ny)))
    # glass highlight and bubbles
    for x, y in ((10, 15), (9, 16), (9, 17), (9, 18), (10, 13), (11, 12), (14, 8), (14, 9)):
        c.set(x, y, "white")
    for x, y, color in ((11, 20, "red_hi"), (12, 20, "red_hi"), (11, 21, "red_hi"), (13, 24, "red_hi"),
                        (20, 18, "blue_hi"), (21, 18, "blue_hi"), (20, 19, "blue_hi"), (19, 23, "blue_hi"),
                        (22, 21, "blue_hi"), (17, 12, "glass_hi"), (16, 9, "glass_hi")):
        c.set(x, y, color)
    return c


def write_palette(path):
    """The logo colours as a GIMP palette, which Aseprite loads too."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("GIMP Palette\nName: Potion Mixer\nColumns: 8\n#\n")
        for name, (r, g, b, _) in C.items():
            f.write(f"{r:3d} {g:3d} {b:3d}\t{name}\n")


def find_aseprite():
    candidates = [os.environ.get("ASEPRITE"), shutil.which("aseprite")]
    for steam in ("~/.local/share/Steam", "~/.steam/steam"):
        candidates.append(os.path.expanduser(steam + "/steamapps/common/Aseprite/aseprite"))
    return next((c for c in candidates if c and os.path.isfile(c) and os.access(c, os.X_OK)), None)


def write_aseprite(aseprite, canvas, palette, out):
    with tempfile.TemporaryDirectory() as tmp:
        layers = {}
        for layer in ("frame", "art"):
            layers[layer] = os.path.join(tmp, layer + ".png")
            canvas.image(layer=layer).save(layers[layer])
        subprocess.run([aseprite, "-b",
                        "--script-param", "frame=" + layers["frame"],
                        "--script-param", "art=" + layers["art"],
                        "--script-param", "palette=" + palette,
                        "--script-param", "out=" + out,
                        "--script", os.path.join(OUT_DIR, "make_aseprite.lua")], check=True)


def main():
    logo = split_flask()
    for scale, suffix in ((1, "32"), (16, "512"), (32, "1024")):
        logo.image(scale).save(os.path.join(OUT_DIR, f"potion-mixer-logo-{suffix}.png"))

    # CurseForge wants exactly 400x400. 400 isn't a multiple of 32, so scale by 12 (384)
    # to keep every pixel the same size, and centre it on a transparent 400x400 canvas.
    avatar = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    avatar.paste(logo.image(12), (8, 8))
    avatar.save(os.path.join(OUT_DIR, "potion-mixer-logo-400.png"))

    # In-game icon: uncompressed 32-bit TGA, power-of-two size.
    os.makedirs(ADDON_MEDIA, exist_ok=True)
    logo.image(2).save(os.path.join(ADDON_MEDIA, "Logo.tga"))

    palette = os.path.join(OUT_DIR, "potion-mixer.gpl")
    write_palette(palette)
    aseprite = find_aseprite()
    if aseprite:
        write_aseprite(aseprite, logo, palette, os.path.join(OUT_DIR, "potion-mixer-logo.aseprite"))
    print("wrote the logo", "(with .aseprite file)" if aseprite else "(Aseprite not found: no .aseprite file)")


if __name__ == "__main__":
    main()
