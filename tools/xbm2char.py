#!/usr/bin/env python3
"""Convert an oneko animal into a Neko.app character folder.

oneko keeps every frame as a pair of 1-bit XBM files: the bitmap says which
pixels are drawn in the foreground colour, the mask says which pixels are drawn
at all.  This script combines them into RGBA images (black outline, white body,
transparent elsewhere) and writes the character.plist manifest next to them.

    python3 tools/xbm2char.py ONEKO_SOURCE ANIMAL OUT.nekochar [--name NAME]

ONEKO_SOURCE is an unpacked oneko source tree (the one holding bitmaps/ and
bitmasks/).  Pass --verify DIR to compare the result against an existing
character folder instead of writing anything, which is how the bit polarity
below is kept honest.

The tiger has no bitmasks/tora directory: oneko reuses the cat's masks for it,
because it is the same silhouette with stripes painted on.
"""

import argparse
import os
import plistlib
import sys

from PIL import Image

# state -> (frame base names, ticks each frame is held for)
STATES = [
    ("stop",    ["mati2"],               1),
    ("jare",    ["jare2", "mati2"],      1),
    ("kaki",    ["kaki1", "kaki2"],      1),
    ("akubi",   ["mati3"],               1),
    ("sleep",   ["sleep1", "sleep2"],    4),
    ("awake",   ["awake"],               1),
    ("u_move",  ["up1", "up2"],          1),
    ("d_move",  ["down1", "down2"],      1),
    ("l_move",  ["left1", "left2"],      1),
    ("r_move",  ["right1", "right2"],    1),
    ("ul_move", ["upleft1", "upleft2"],  1),
    ("ur_move", ["upright1", "upright2"], 1),
    ("dl_move", ["dwleft1", "dwleft2"],  1),
    ("dr_move", ["dwright1", "dwright2"], 1),
    ("u_togi",  ["utogi1", "utogi2"],    1),
    ("d_togi",  ["dtogi1", "dtogi2"],    1),
    ("l_togi",  ["ltogi1", "ltogi2"],    1),
    ("r_togi",  ["rtogi1", "rtogi2"],    1),
]

FOREGROUND = (0, 0, 0, 255)
BACKGROUND = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

# Pillow decodes an XBM set bit as 255.
SET = 255


def bitmap_path(source, animal, base):
    if animal == "neko":
        return os.path.join(source, "bitmaps", "neko", base + ".xbm")
    return os.path.join(source, "bitmaps", animal, "%s_%s.xbm" % (base, animal))


def mask_path(source, animal, base):
    if animal in ("neko", "tora"):
        return os.path.join(source, "bitmasks", "neko", base + "_mask.xbm")
    return os.path.join(source, "bitmasks", animal,
                        "%s_%s_mask.xbm" % (base, animal))


def frame_image(source, animal, base):
    bits = Image.open(bitmap_path(source, animal, base)).convert("L")
    mask = Image.open(mask_path(source, animal, base)).convert("L")
    if bits.size != mask.size:
        raise SystemExit("%s: bitmap %s and mask %s disagree on size"
                         % (base, bits.size, mask.size))

    out = Image.new("RGBA", bits.size)
    bp, mp, op = bits.load(), mask.load(), out.load()
    for y in range(bits.height):
        for x in range(bits.width):
            if mp[x, y] != SET:
                op[x, y] = TRANSPARENT
            elif bp[x, y] == SET:
                op[x, y] = FOREGROUND
            else:
                op[x, y] = BACKGROUND
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source", help="unpacked oneko source tree")
    p.add_argument("animal", help="neko, tora, dog, sakura or tomoyo")
    p.add_argument("out", help="destination Foo.nekochar folder")
    p.add_argument("--name", help="display name (default: capitalised animal)")
    p.add_argument("--license", default="Public domain (oneko)")
    p.add_argument("--verify", metavar="DIR",
                   help="compare against an existing character instead of writing")
    args = p.parse_args()

    frames = {}
    for _, bases, _ in STATES:
        for base in bases:
            if base not in frames:
                frames[base] = frame_image(args.source, args.animal, base)

    if args.verify:
        bad = 0
        for base, image in sorted(frames.items()):
            for ext in (".gif", ".png"):
                reference = os.path.join(args.verify, base + ext)
                if os.path.exists(reference):
                    break
            else:
                print("missing reference for %s" % base)
                bad += 1
                continue
            expected = Image.open(reference).convert("RGBA")
            ap, bp = image.load(), expected.load()
            differing = sum(1 for y in range(image.height) for x in range(image.width)
                            if ap[x, y][3] != bp[x, y][3]
                            or (ap[x, y][3] and ap[x, y][:3] != bp[x, y][:3]))
            if differing:
                print("%s: %d differing pixels" % (base, differing))
                bad += 1
        print("%d of %d frames differ" % (bad, len(frames)))
        return 1 if bad else 0

    os.makedirs(args.out, exist_ok=True)
    for base, image in frames.items():
        image.save(os.path.join(args.out, base + ".png"))

    size = next(iter(frames.values())).size
    manifest = {
        "Identifier": args.animal,
        "Name": args.name or args.animal.capitalize(),
        "SpriteWidth": size[0],
        "SpriteHeight": size[1],
        "Author": "Masayuki Koba, Tatsuya Kato (oneko)",
        "License": args.license,
        "States": {name: {"Frames": [b + ".png" for b in bases],
                          "TicksPerFrame": ticks}
                   for name, bases, ticks in STATES},
    }
    with open(os.path.join(args.out, "character.plist"), "wb") as fh:
        plistlib.dump(manifest, fh)
    print("wrote %s (%d frames, %dx%d)" % (args.out, len(frames), size[0], size[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
