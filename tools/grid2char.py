#!/usr/bin/env python3
"""Turn a drawn grid of poses into a Neko.app character folder.

Image models hand back a sheet with an opaque background and cells far larger
than the 32x32 the app wants, the poses sitting anywhere inside their cell. This
script keys out the background, cuts the grid, trims each pose and scales it
down onto a 32x32 tile.

    python3 tools/grid2char.py SHEET.png OUT.nekochar --name "Wizard"

The background is whatever is connected to the border of the image, so white fur
inside the character survives while a white backdrop does not.

By default the grid is the 8x4 oneko layout, and the cells are read in that
layout's order (see tools/sprite-prompt.md). A different grid needs --frames
naming each cell, left to right then top to bottom.
"""

import argparse
import os
import plistlib
import sys
from collections import deque

from PIL import Image

from sheet2char import CELL, CELLS
from xbm2char import STATES


# A pose facing left is the pose facing right, flipped. Asking a generator for
# both is asking for two characters that do not match; these pairs are made
# rather than drawn.
MIRROR_PAIRS = (
    ('left1', 'right1'), ('left2', 'right2'),
    ('upleft1', 'upright1'), ('upleft2', 'upright2'),
    ('dwleft1', 'dwright1'), ('dwleft2', 'dwright2'),
    ('ltogi1', 'rtogi1'), ('ltogi2', 'rtogi2'),
)


def frames_in_layout_order():
    """The 8x4 oneko layout, read left to right then top to bottom."""
    return [CELLS[(col, row)] for row in range(4) for col in range(8)]


def clear_faint(image, floor):
    """Drop a near invisible wash, which some generators lay over the whole sheet.

    Left in place it defeats everything downstream: no row reads as empty, so the
    grid cannot be detected, and every cell's bounding box covers the whole cell,
    so trimming does nothing and the pose ends up scaled from the cell instead of
    from itself."""
    if floor <= 0:
        return image, 0
    alpha = image.split()[3]
    px = image.load()
    cleared = 0
    for y in range(image.height):
        for x in range(image.width):
            pixel = px[x, y]
            if 0 < pixel[3] <= floor:
                px[x, y] = (0, 0, 0, 0)
                cleared += 1
    return image, cleared


def bands(projection, wanted, minimum=20):
    """Runs of non-empty lines in a projection, one per row or column of poses."""
    found, start = [], None
    for i, value in enumerate(projection):
        if value > 0 and start is None:
            start = i
        elif value == 0 and start is not None:
            if i - start >= minimum:
                found.append((start, i))
            start = None
    if start is not None and len(projection) - start >= minimum:
        found.append((start, len(projection)))
    if len(found) != wanted:
        raise SystemExit('found %d bands, expected %d: the poses are not separated '
                         'cleanly, drop --autogrid' % (len(found), wanted))
    return found


def detect_grid(image, columns, rows):
    """Cell boxes taken from where the poses actually are, not from an even split."""
    alpha = image.split()[3].load()
    width, height = image.size
    column_profile = [sum(1 for y in range(0, height, 2) if alpha[x, y] > 8) for x in range(width)]
    row_profile = [sum(1 for x in range(0, width, 2) if alpha[x, y] > 8) for y in range(height)]
    xs = bands(column_profile, columns)
    ys = bands(row_profile, rows)
    return [(xs[col][0], ys[row][0], xs[col][1], ys[row][1])
            for row in range(rows) for col in range(columns)]


def strip_background(image, tolerance):
    """Clear every pixel connected to the border that matches the border colour."""
    image = image.convert('RGBA')
    width, height = image.size
    px = image.load()
    corners = [px[0, 0], px[width - 1, 0], px[0, height - 1], px[width - 1, height - 1]]
    reference = max(set(corners), key=corners.count)

    if reference[3] == 0:
        # Already cut out. Keying here would be worse than useless: a sprite
        # outlined in black shares its colour with transparent black, and the
        # fill would eat the outline from the outside in.
        return image, reference, 0

    def matches(pixel):
        # The alpha has to match too, for the same reason.
        return (abs(pixel[3] - reference[3]) <= tolerance
                and all(abs(pixel[i] - reference[i]) <= tolerance for i in range(3)))

    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            queue.append((x, y))

    cleared = 0
    while queue:
        x, y = queue.popleft()
        if not (0 <= x < width and 0 <= y < height) or seen[y * width + x]:
            continue
        seen[y * width + x] = 1
        if px[x, y][3] == 0:
            queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            continue
        if not matches(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        cleared += 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return image, reference, cleared


def tile(cell, side, fit, align, pad):
    """Fit one cropped cell onto a side x side transparent tile."""
    out = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    if fit == 'cell':
        return cell.resize((side, side), Image.BOX)

    box = cell.getbbox()
    if box is None:
        return None
    sprite = cell.crop(box)
    room = side - 2 * pad
    factor = min(room / sprite.width, room / sprite.height)
    size = (max(1, round(sprite.width * factor)), max(1, round(sprite.height * factor)))
    sprite = sprite.resize(size, Image.BOX)

    x = (side - sprite.width) // 2
    y = side - pad - sprite.height if align == 'bottom' else (side - sprite.height) // 2
    out.alpha_composite(sprite, (x, max(0, y)))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('sheet')
    p.add_argument('out', help='destination Foo.nekochar folder')
    p.add_argument('--name')
    p.add_argument('--identifier')
    p.add_argument('--grid', default='8x4', help='columns x rows, default 8x4')
    p.add_argument('--size', type=int, default=CELL,
                   help='side of the sprites to write, default %d. Only %d exports to '
                        'the web version, which uses the fixed oneko.js sheet' % (CELL, CELL))
    p.add_argument('--frames', help='comma separated frame names, one per cell')
    p.add_argument('--fit', choices=('trim', 'cell'), default='trim',
                   help='trim each pose and scale it, or scale the whole cell')
    p.add_argument('--align', choices=('bottom', 'center'), default='bottom')
    p.add_argument('--mirror', action='store_true',
                   help='build every left-facing frame by flipping its right-facing '
                        'twin, instead of using whatever was drawn for it')
    p.add_argument('--pad', type=int, default=0, help='transparent margin, in final pixels')
    p.add_argument('--alpha-floor', type=int, default=16, metavar='N',
                   help='treat alpha up to N as empty, clearing a near invisible '
                        'wash before anything else. Default 16, 0 disables it')
    p.add_argument('--tolerance', type=int, default=12,
                   help='how far a pixel may stray from the border colour and still count as background')
    p.add_argument('--keep-background', action='store_true')
    p.add_argument('--autogrid', action='store_true',
                   help='take the cell boxes from where the poses are instead of '
                        'splitting the image evenly')
    p.add_argument('--author', default='')
    p.add_argument('--license', default='')
    args = p.parse_args()

    columns, rows = (int(n) for n in args.grid.lower().split('x'))
    names = ([n.strip() for n in args.frames.split(',')] if args.frames
             else frames_in_layout_order())
    if columns * rows != len(names):
        raise SystemExit('grid %dx%d holds %d cells but %d frame names were given'
                         % (columns, rows, columns * rows, len(names)))

    image = Image.open(args.sheet).convert('RGBA')
    image, faint = clear_faint(image, args.alpha_floor)
    if faint:
        print('cleared %d pixels below alpha %d' % (faint, args.alpha_floor))

    if args.keep_background:
        reference, cleared = None, 0
    else:
        image, reference, cleared = strip_background(image, args.tolerance)
        if cleared:
            print('background %s cleared from %d pixels' % (reference[:3], cleared))
        else:
            print('background already transparent, nothing to key out')

    if args.autogrid:
        boxes = detect_grid(image, columns, rows)
        widths = [b[2] - b[0] for b in boxes]
        heights = [b[3] - b[1] for b in boxes]
        print('grid %dx%d detected, poses from %dx%d to %dx%d pixels'
              % (columns, rows, min(widths), min(heights), max(widths), max(heights)))
    else:
        cell_width = image.width / columns
        cell_height = image.height / rows
        boxes = [(round(col * cell_width), round(row * cell_height),
                  round((col + 1) * cell_width), round((row + 1) * cell_height))
                 for row in range(rows) for col in range(columns)]
        print('grid %dx%d, cells of %.1f x %.1f pixels' % (columns, rows, cell_width, cell_height))

    name = args.name or os.path.splitext(os.path.basename(args.sheet))[0].capitalize()
    identifier = args.identifier or name.lower().replace(' ', '-')
    os.makedirs(args.out, exist_ok=True)

    written, empty = [], []
    for index, frame in enumerate(names):
        result = tile(image.crop(boxes[index]), args.size, args.fit, args.align, args.pad)
        if result is None:
            empty.append(frame)
            continue
        result.save(os.path.join(args.out, frame + '.png'))
        written.append(frame)

    if args.mirror:
        made = []
        for target, source in MIRROR_PAIRS:
            if source not in written:
                continue
            image_path = os.path.join(args.out, source + '.png')
            flipped = Image.open(image_path).transpose(Image.FLIP_LEFT_RIGHT)
            flipped.save(os.path.join(args.out, target + '.png'))
            if target not in written:
                written.append(target)
            if target in empty:
                empty.remove(target)
            made.append(target)
        if made:
            print('mirrored from the right-facing poses: %s' % ', '.join(made))

    states = {}
    for state, bases, ticks in STATES:
        have = [b + '.png' for b in bases if b in written]
        if have:
            states[state] = {'Frames': have, 'TicksPerFrame': ticks}
    if 'stop' not in states:
        raise SystemExit('no usable frame for the resting pose (mati2), nothing to build')

    manifest = {
        'Identifier': identifier,
        'Name': name,
        'SpriteWidth': args.size,
        'SpriteHeight': args.size,
        'Author': args.author,
        'License': args.license,
        'States': states,
    }
    with open(os.path.join(args.out, 'character.plist'), 'wb') as fh:
        plistlib.dump(manifest, fh)

    print('wrote %s: %d frames of %dpx, %d states'
          % (args.out, len(written), args.size, len(states)))
    if empty:
        print('empty cells, left to the fallback chain: %s' % ', '.join(empty))
    return 0


if __name__ == '__main__':
    sys.exit(main())
