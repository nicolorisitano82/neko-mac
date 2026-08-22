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


def blob_boxes(image, columns, rows, floor):
    """One box per pose, taken from the pixels themselves rather than the grid.

    Generators draw the figure larger than the cell it belongs to often enough
    that a straight grid cut lops off heads and feet: one sheet had 100 to 500
    opaque pixels crossing every horizontal boundary, and no empty gutter
    anywhere for --autogrid to find. So the poses are found as connected regions
    of opaque pixels, each region is filed under the cell its centre falls in,
    and the boxes are the union of whatever landed in each cell — which puts the
    Zzz above a sleeping pose, or the surprise marks beside a startled one, back
    with the figure they belong to.
    """
    width, height = image.size
    alpha = image.split()[3].load()
    seen = bytearray(width * height)
    cell_width, cell_height = width / columns, height / rows
    cells = [None] * (columns * rows)
    small = []

    for start_y in range(height):
        for start_x in range(width):
            if seen[start_y * width + start_x] or alpha[start_x, start_y] <= floor:
                continue
            # Flood the region, tracking its own bounding box as it goes.
            queue = deque([(start_x, start_y)])
            seen[start_y * width + start_x] = 1
            left = right = start_x
            top = bottom = start_y
            count = 0
            while queue:
                x, y = queue.popleft()
                count += 1
                if x < left: left = x
                if x > right: right = x
                if y < top: top = y
                if y > bottom: bottom = y
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if seen[ny * width + nx] or alpha[nx, ny] <= floor:
                        continue
                    seen[ny * width + nx] = 1
                    queue.append((nx, ny))

            box = (left, top, right + 1, bottom + 1)
            if count < (cell_width * cell_height) / 100.0:
                small.append(box)          # decoration; filed once the poses are known
                continue
            centre_x = (left + right) / 2.0
            centre_y = (top + bottom) / 2.0
            col = min(columns - 1, int(centre_x / cell_width))
            row = min(rows - 1, int(centre_y / cell_height))
            index = row * columns + col
            cells[index] = box if cells[index] is None else (
                min(cells[index][0], box[0]), min(cells[index][1], box[1]),
                max(cells[index][2], box[2]), max(cells[index][3], box[3]))

    # Decorations go to the pose they sit closest to, and only if they are close.
    attached = 0
    for box in small:
        centre = ((box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0)
        best, distance = None, None
        for index, pose in enumerate(cells):
            if pose is None:
                continue
            dx = max(pose[0] - centre[0], 0, centre[0] - pose[2])
            dy = max(pose[1] - centre[1], 0, centre[1] - pose[3])
            gap = (dx * dx + dy * dy) ** 0.5
            if distance is None or gap < distance:
                best, distance = index, gap
        if best is not None and distance <= cell_width / 4.0:
            pose = cells[best]
            cells[best] = (min(pose[0], box[0]), min(pose[1], box[1]),
                           max(pose[2], box[2]), max(pose[3], box[3]))
            attached += 1

    missing = [i for i, box in enumerate(cells) if box is None]
    if missing:
        raise SystemExit('no pose found for %d of the %d cells (%s): the sheet is '
                         'not the grid it was said to be'
                         % (len(missing), columns * rows,
                            ', '.join(str(i + 1) for i in missing)))
    return cells, attached


def snapped_boxes(image, columns, rows, floor, window=30):
    """Cell boxes with every cut moved to where the fewest pixels cross it.

    Generators draw the figures taller than their cell and high up in it, so the
    feet of one row lie over the hair of the next: on one sheet the nominal
    boundary crossed 131 to 426 opaque pixels, and there was no empty gutter for
    --autogrid to find. Vertical cuts are chosen per column rather than once for
    the whole sheet, because the overlap is a different few pixels in each
    column, and a jagged grid that misses the figures beats a straight one that
    slices them.
    """
    width, height = image.size
    alpha = image.split()[3].load()

    def quietest(profile, nominal):
        low = max(1, nominal - window)
        high = min(len(profile) - 1, nominal + window)
        return min(range(low, high + 1), key=lambda i: (profile[i], abs(i - nominal)))

    column_profile = [sum(1 for y in range(height) if alpha[x, y] > floor)
                      for x in range(width)]
    xs = [0] + [quietest(column_profile, round(c * width / columns))
                for c in range(1, columns)] + [width]

    boxes = [None] * (columns * rows)
    crossed = 0
    for col in range(columns):
        left, right = xs[col], xs[col + 1]
        strip = [sum(1 for x in range(left, right) if alpha[x, y] > floor)
                 for y in range(height)]
        ys = [0] + [quietest(strip, round(r * height / rows))
                    for r in range(1, rows)] + [height]
        for row in range(rows):
            boxes[row * columns + col] = (left, ys[row], right, ys[row + 1])
            if row:
                crossed += strip[ys[row]]
    return boxes, crossed


def split_poses(image, columns, rows, floor):
    """One image per pose, with every opaque pixel given to exactly one of them.

    The hardest sheets draw the figures taller than the cell they belong to, so
    the feet of one row lie over the hair of the next and no straight cut can
    avoid slicing something: on one sheet, snapping the cuts to the quietest
    lines still left thirty of the thirty-two poses touching an edge, some by
    fifty pixels.

    So nothing is cut. A seed is placed at the opaque pixel nearest each cell's
    centre, and the opaque pixels are shared out between the seeds by a
    breadth-first sweep from all of them at once — each pixel goes to whichever
    pose reached it first, staying inside the figure while it travels. Two
    figures that touch are separated along the line where they meet, which is
    exactly where they should be separated. Loose marks that nothing reached,
    the Zzz over a sleeping pose or the surprise lines beside a startled one, go
    to the nearest pose if they are close enough to belong to it.

    Returns a list of cropped RGBA images in cell order, and how many pixels
    ended up nobody's.
    """
    width, height = image.size
    alpha = image.split()[3].load()
    opaque = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            if alpha[x, y] > floor:
                opaque[row + x] = 1

    cell_width, cell_height = width / columns, height / rows
    label = [0] * (width * height)          # 0 = unclaimed
    queue = deque()
    for row in range(rows):
        for col in range(columns):
            index = row * columns + col
            centre = (int((col + 0.5) * cell_width), int((row + 0.5) * cell_height))
            seed = None
            # Spiral out from the cell centre until an opaque pixel turns up.
            for radius in range(0, int(min(cell_width, cell_height) / 2)):
                for dy in range(-radius, radius + 1):
                    for dx in range(-radius, radius + 1):
                        if max(abs(dx), abs(dy)) != radius:
                            continue
                        x, y = centre[0] + dx, centre[1] + dy
                        if 0 <= x < width and 0 <= y < height and opaque[y * width + x]:
                            seed = (x, y)
                            break
                    if seed:
                        break
                if seed:
                    break
            if seed is None:
                raise SystemExit('cell %d of %d has nothing in it: the sheet is not '
                                 'the grid it was said to be' % (index + 1, columns * rows))
            label[seed[1] * width + seed[0]] = index + 1
            queue.append(seed)

    touching = 0
    while queue:
        x, y = queue.popleft()
        mine = label[y * width + x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < width and 0 <= ny < height):
                continue
            spot = ny * width + nx
            if not opaque[spot]:
                continue
            if label[spot]:
                if label[spot] != mine:
                    touching += 1      # two figures drawn into each other
                continue
            label[spot] = mine
            queue.append((nx, ny))

    orphans = sum(1 for spot in range(width * height) if opaque[spot] and not label[spot])

    # Boxes first, so a loose mark can be matched to the pose it sits beside.
    boxes = [None] * (columns * rows)
    for y in range(height):
        row = y * width
        for x in range(width):
            index = label[row + x]
            if not index:
                continue
            box = boxes[index - 1]
            boxes[index - 1] = ((x, y, x + 1, y + 1) if box is None else
                                (min(box[0], x), min(box[1], y),
                                 max(box[2], x + 1), max(box[3], y + 1)))

    if orphans:
        # Loose marks come in clumps: the Zzz over a sleeper, the surprise lines
        # beside a startled pose. Clumps get filed with a pose; single specks,
        # which are stray pixels of a neighbour's shoe, are dropped.
        seen = bytearray(width * height)
        reunited = dropped = 0
        for start_y in range(height):
            for start_x in range(width):
                spot = start_y * width + start_x
                if not opaque[spot] or label[spot] or seen[spot]:
                    continue
                clump = []
                stack = [(start_x, start_y)]
                seen[spot] = 1
                while stack:
                    x, y = stack.pop()
                    clump.append((x, y))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                                   (1, 1), (1, -1), (-1, 1), (-1, -1)):
                        nx, ny = x + dx, y + dy
                        if not (0 <= nx < width and 0 <= ny < height):
                            continue
                        here = ny * width + nx
                        if opaque[here] and not label[here] and not seen[here]:
                            seen[here] = 1
                            stack.append((nx, ny))

                if len(clump) < 24:
                    dropped += len(clump)
                    continue

                centre_x = sum(x for x, _ in clump) / len(clump)
                centre_y = sum(y for _, y in clump) / len(clump)
                # The cell the clump falls in comes first: the sparkles above a
                # startled pose are nearer the pose in the cell above, and went
                # to it until this was ordered properly.
                own = (min(rows - 1, int(centre_y / cell_height)) * columns
                       + min(columns - 1, int(centre_x / cell_width)))
                best, distance = own, None
                for index, box in enumerate(boxes):
                    dx = max(box[0] - centre_x, 0, centre_x - box[2])
                    dy = max(box[1] - centre_y, 0, centre_y - box[3])
                    gap = (dx * dx + dy * dy) ** 0.5
                    if index == own and gap <= cell_width / 2.0:
                        best, distance = index, gap
                        break
                    if distance is None or gap < distance:
                        best, distance = index, gap
                if distance is not None and distance > cell_width / 2.0:
                    dropped += len(clump)
                    continue

                box = boxes[best]
                for x, y in clump:
                    label[y * width + x] = best + 1
                    box = (min(box[0], x), min(box[1], y),
                           max(box[2], x + 1), max(box[3], y + 1))
                boxes[best] = box
                reunited += len(clump)
        orphans = dropped

    # Each pose as its own image: the neighbour's foot stays with the neighbour.
    source = image.load()
    poses = []
    for index, box in enumerate(boxes):
        left, top, right, bottom = box
        cut = Image.new('RGBA', (right - left, bottom - top), (0, 0, 0, 0))
        target = cut.load()
        for y in range(top, bottom):
            row = y * width
            for x in range(left, right):
                if label[row + x] == index + 1:
                    target[x - left, y - top] = source[x, y]
        poses.append(cut)
    return poses, orphans, touching


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
    p.add_argument('--split', action='store_true',
                   help='give every pixel to one pose instead of cutting cells, for '
                        'sheets whose figures overlap each other')
    p.add_argument('--snap', action='store_true',
                   help='move each cut to where the fewest pixels cross it, for '
                        'sheets whose figures overflow their cells')
    p.add_argument('--blobs', action='store_true',
                   help='find each pose as a connected region of opaque pixels, for '
                        'sheets whose figures overflow their cells')
    p.add_argument('--persona', default='',
                   help='who this character is, in a phrase, for when it is asked '
                        'a question: "a small owl, solemn and slightly pedantic"')
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

    cuts = None
    if args.split:
        cuts, orphans, touching = split_poses(image, columns, rows, args.alpha_floor)
        heights = [c.size[1] for c in cuts]
        widths = [c.size[0] for c in cuts]
        print('poses shared out pixel by pixel, %dx%d to %dx%d%s%s'
              % (min(widths), min(heights), max(widths), max(heights),
                 ', %d stray pixels dropped' % orphans if orphans else '',
                 ', %d pixels where two poses were drawn into each other'
                 % touching if touching else ', none of them drawn into another'))
        boxes = [(0, 0, c.size[0], c.size[1]) for c in cuts]
    elif args.snap:
        boxes, crossed = snapped_boxes(image, columns, rows, args.alpha_floor)
        print('grid %dx%d snapped to the gaps, %d pixels still crossing a cut'
              % (columns, rows, crossed))
    elif args.blobs:
        boxes, attached = blob_boxes(image, columns, rows, args.alpha_floor)
        widths = [b[2] - b[0] for b in boxes]
        heights = [b[3] - b[1] for b in boxes]
        print('poses found one by one, %dx%d to %dx%d pixels%s'
              % (min(widths), min(heights), max(widths), max(heights),
                 ', %d loose marks reunited with their pose' % attached if attached else ''))
    elif args.autogrid:
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
        cell = cuts[index] if cuts is not None else image.crop(boxes[index])
        result = tile(cell, args.size, args.fit, args.align, args.pad)
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
        'Persona': args.persona,
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
