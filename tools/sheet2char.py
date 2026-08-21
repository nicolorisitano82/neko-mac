#!/usr/bin/env python3
"""Convert an oneko.js sprite sheet into a Neko.app character folder.

oneko.js (https://github.com/adryd325/oneko.js) and the skins written for it
keep every frame in one 256x128 PNG: an 8x4 grid of 32x32 cells.  The cell
layout below was not read off the oneko.js source but derived by slicing
oneko.js' own sheet and matching each cell against the sprites already in
Neko.nekochar -- all 32 cells matched exactly, so the mapping is a bijection.

    python3 tools/sheet2char.py SHEET.png OUT.nekochar --name NAME

Sheets a pixel or two short of 256x128 (a few community skins are 255x127) are
padded with transparency rather than rejected.
"""

import argparse
import os
import plistlib
import sys

from PIL import Image

from xbm2char import STATES

CELL = 32
COLUMNS, ROWS = 8, 4

# (column, row) -> oneko frame name
CELLS = {
    (0, 0): "utogi2",  (1, 0): "upleft2", (2, 0): "sleep2", (3, 0): "right2",
    (4, 0): "ltogi2",  (5, 0): "kaki2",   (6, 0): "kaki1",  (7, 0): "jare2",
    (0, 1): "utogi1",  (1, 1): "upleft1", (2, 1): "sleep1", (3, 1): "right1",
    (4, 1): "ltogi1",  (5, 1): "dwright2", (6, 1): "dwleft1", (7, 1): "dtogi2",
    (0, 2): "upright2", (1, 2): "up2",    (2, 2): "rtogi2", (3, 2): "mati3",
    (4, 2): "left2",   (5, 2): "dwright1", (6, 2): "dtogi1", (7, 2): "down1",
    (0, 3): "upright1", (1, 3): "up1",    (2, 3): "rtogi1", (3, 3): "mati2",
    (4, 3): "left1",   (5, 3): "dwleft2", (6, 3): "down2",  (7, 3): "awake",
}

WIDTH, HEIGHT = COLUMNS * CELL, ROWS * CELL


def load_sheet(path):
    sheet = Image.open(path).convert("RGBA")
    if sheet.size == (WIDTH, HEIGHT):
        return sheet, None
    if sheet.width > WIDTH or sheet.height > HEIGHT:
        raise SystemExit("%s: %dx%d is not an 8x4 grid of %dpx cells"
                         % (path, sheet.width, sheet.height, CELL))
    padded = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    padded.paste(sheet, (0, 0))
    return padded, "padded from %dx%d" % (sheet.width, sheet.height)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("sheet")
    p.add_argument("out", help="destination Foo.nekochar folder")
    p.add_argument("--name", help="display name (default: from the file name)")
    p.add_argument("--identifier", help="default: lowercased name")
    p.add_argument("--author", default="")
    p.add_argument("--license", default="")
    args = p.parse_args()

    name = args.name or os.path.splitext(os.path.basename(args.sheet))[0].capitalize()
    identifier = args.identifier or name.lower().replace(" ", "-")

    sheet, note = load_sheet(args.sheet)
    os.makedirs(args.out, exist_ok=True)

    empty = []
    for (col, row), frame in CELLS.items():
        cell = sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
        if not cell.getbbox():
            empty.append(frame)
        cell.save(os.path.join(args.out, frame + ".png"))

    manifest = {
        "Identifier": identifier,
        "Name": name,
        "SpriteWidth": CELL,
        "SpriteHeight": CELL,
        "Author": args.author,
        "License": args.license,
        "States": {state: {"Frames": [b + ".png" for b in bases],
                           "TicksPerFrame": ticks}
                   for state, bases, ticks in STATES},
    }
    with open(os.path.join(args.out, "character.plist"), "wb") as fh:
        plistlib.dump(manifest, fh)

    detail = ", ".join(filter(None, [note, "blank cells: " + ", ".join(empty) if empty else ""]))
    print("wrote %s%s" % (args.out, " (%s)" % detail if detail else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
