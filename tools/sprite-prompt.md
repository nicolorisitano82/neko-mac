# Prompt for generating a character

A character is 32 frames of 32 x 32 pixels. `tools/sheet2char.py` imports them
as one 256 x 128 sheet, an 8 x 4 grid, in the layout oneko.js uses. The tables
below give the pose of every cell in that grid.

Image models are unreliable at filling 32 cells consistently, so there are two
prompts here: the full sheet, and a much smaller set that leans on the importer
filling the gaps.

## The layout

Columns 1 to 8 left to right, rows 1 to 4 top to bottom.

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| **1** | claw up B | walk up-left B | sleep B | walk right B | claw left B | groom B | groom A | lick paw |
| **2** | claw up A | walk up-left A | sleep A | walk right A | claw left A | walk down-right B | walk down-left A | claw down B |
| **3** | walk up-right B | walk up A… | claw right B | yawn | walk left B | walk down-right A | claw down A | walk down A |
| **4** | walk up-right A | walk up B… | claw right A | **sit still** | walk left A | walk down-left B | walk down B | alert |

A and B are the two frames of a two frame animation. "claw *direction*" is the
cat scratching a wall in that direction. "sit still" is the resting pose and the
only one a character cannot do without.

## Cell geometry, spelled out

Generators drift on canvas size — the last three sheets came back 1774 x 887,
which is a cell of 221.75 pixels and not a whole number anywhere. The importer
copes, but the poses land off-centre. Stating the arithmetic cell by cell is what
stops it.

    canvas        2048 x 1024 pixels
    grid          8 columns x 4 rows
    cell          256 x 256 pixels, exactly
    cell origin   x = (column - 1) * 256, y = (row - 1) * 256
    safe area     224 x 224, centred: 16 pixels clear on all four sides
    baseline      y = cell top + 232, where the feet rest
    figure        about 200 pixels tall in every cell

Which gives these corners, top-left of each cell:

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| **row 1** | 0,0 | 256,0 | 512,0 | 768,0 | 1024,0 | 1280,0 | 1536,0 | 1792,0 |
| **row 2** | 0,256 | 256,256 | 512,256 | 768,256 | 1024,256 | 1280,256 | 1536,256 | 1792,256 |
| **row 3** | 0,512 | 256,512 | 512,512 | 768,512 | 1024,512 | 1280,512 | 1536,512 | 1792,512 |
| **row 4** | 0,768 | 256,768 | 512,768 | 768,768 | 1024,768 | 1280,768 | 1536,768 | 1792,768 |

The app's characters are 32, 48 or 64 points across, so 256 is four to eight
times what is needed: plenty for the importer to trim and scale down, and small
enough that a generator keeps the details consistent across 32 cells.

## Full sheet prompt, 8 x 4

Two things decide whether the result is usable, and both were learned the hard
way from generated sheets. **Say what each view shows**: a generator draws the
face in every cell unless told otherwise, and that alone makes a walk cycle
unreadable. **Forbid anything outside the character**: one sheet arrived with a
wash at alpha 1 to 16 over 44% of its area, invisible on screen but enough to
make every cell read as full, which defeats the trimming.

---

Create a 2048 x 1024 pixel sprite sheet for a 1990s desktop pet, on a fully
transparent background. It is an 8 x 4 grid of 256 x 256 pixel cells:
thirty-two poses of the same character, one per cell.

The character: [describe it in two or three sentences: species, clothing, one or
two props, and the colours that must stay identical in every cell].

Style: hard-edged pixel art, no anti-aliasing, no gradients, at most six colours
plus transparency. Every cell is the same character, at the same size, drawn in
the same style.

Framing rules, all mandatory:
- One pose per cell, entirely inside its cell, with at least 16 pixels of empty
  space on all four sides. No pose may touch or cross a cell boundary.
- The character is the same height in every cell, give or take a few pixels, and
  its feet rest on the same imaginary line near the bottom of the cell.
- The background is fully transparent. Nothing at all outside the character
  itself: no glow, no halo, no soft shadow under the feet, no faint wash, no
  coloured backdrop, not even a barely visible one.
- No grid lines, no numbering, no labels, no frame borders.

What the views mean, since this is where sheets usually go wrong:
- **Walking right**: profile, the character faces the right edge, one eye
  visible. **Walking left**: the same pose mirrored, facing the left edge, and it
  must match the right-facing one exactly.
- **Walking up**: seen from behind, the back of the head, no face at all.
  **Walking down**: seen from the front, the face fully visible.
- **Diagonals**: three-quarter views. Up-right and up-left show mostly the back
  with a sliver of cheek; down-right and down-left show mostly the face, turned.
- **Clawing**: the character reaching up with both front paws and scratching an
  unseen wall in that direction. Clawing up means reaching towards the top of
  the cell, clawing down towards the bottom, clawing left and right towards
  those edges.
- **A and B** are the two frames of one animation. Between them only the legs
  change, plus the arms, wings or tail if they swing. Nothing else moves.

The thirty-two cells, left to right then top to bottom.

Row 1: clawing upwards, frame B; walking up-left, frame B; curled up asleep,
frame B; walking right, frame B; clawing to the left, frame B; sitting and
grooming itself, frame B; sitting and grooming itself, frame A; sitting and
licking a front paw.

Row 2: clawing upwards, frame A; walking up-left, frame A; curled up asleep,
frame A; walking right, frame A; clawing to the left, frame A; walking
down-right, frame B; walking down-left, frame A; clawing downwards, frame B.

Row 3: walking up-right, frame B; walking up (away from the viewer), frame A;
clawing to the right, frame B; sitting and yawning with the eyes shut; walking
left, frame B; walking down-right, frame A; clawing downwards, frame A; walking
down (towards the viewer), frame A.

Row 4: walking up-right, frame A; walking up (away from the viewer), frame B;
clawing to the right, frame A; sitting still and calm, facing the viewer, the
resting pose; walking left, frame A; walking down-left, frame B; walking down
(towards the viewer), frame B; alert and startled, eyes wide, small motion marks
around the head.

Output a single PNG, exactly 2048 x 1024 pixels, transparent background, no
padding around the grid.


### The prompt, with the geometry inside it

Paste this as one message, with the character described in the second paragraph.

---

Create one PNG image, exactly 2048 x 1024 pixels, fully transparent background.

It is a sprite sheet: 8 columns x 4 rows = 32 cells. Every cell is exactly
256 x 256 pixels. The cell in column C, row R occupies the pixels from
x = (C-1)*256 to x = C*256-1 and y = (R-1)*256 to y = R*256-1. Nothing is drawn
outside the 2048 x 1024 canvas, and there is no margin around the grid: the grid
fills the image.

The character: [two or three sentences — species, clothes, one or two props, and
the colours that must be identical in all 32 cells].

Style: hard-edged pixel art, no anti-aliasing, no gradients, at most six colours
plus transparency. The same character, the same size, the same style, in every
one of the 32 cells.

Geometry, mandatory in every cell:
- One pose per cell, drawn inside a 224 x 224 safe area centred in the cell, so
  at least 16 transparent pixels remain on all four sides. No pose touches or
  crosses a cell boundary.
- The figure is about 200 pixels tall, the same height in every cell give or take
  a few pixels.
- The feet rest on a baseline 232 pixels below the top of the cell, the same line
  in every cell. Sleeping and sitting poses sit on that line too.
- Fully transparent background. Nothing outside the character: no glow, no halo,
  no soft shadow under the feet, no faint wash, no near-invisible tint. A pixel
  is either part of the character or fully transparent.
- No grid lines, no cell borders, no numbers, no labels, no captions.

What the views mean, because this is where sheets go wrong:
- Walking right: profile, facing the right edge of the cell, one eye visible.
- Walking left: the same pose mirrored, facing the left edge.
- Walking up: from behind — the back of the head, no face at all.
- Walking down: from the front, face fully visible.
- Diagonals: three-quarter views. Up-right and up-left mostly back with a sliver
  of cheek; down-right and down-left mostly face, turned.
- Clawing in a direction: reaching out with both front paws or hands, scratching
  an unseen wall towards that edge of the cell.
- Frames A and B are two frames of one animation: only the legs differ, plus
  arms, wings or tail if they swing. Nothing else moves.

The 32 cells, left to right then top to bottom:

Row 1: clawing upwards frame B; walking up-left frame B; curled up asleep frame
B; walking right frame B; clawing left frame B; sitting and grooming frame B;
sitting and grooming frame A; sitting and licking a front paw.

Row 2: clawing upwards frame A; walking up-left frame A; curled up asleep frame
A; walking right frame A; clawing left frame A; walking down-right frame B;
walking down-left frame A; clawing downwards frame B.

Row 3: walking up-right frame B; walking up (away from the viewer) frame A;
clawing right frame B; sitting and yawning, eyes shut; walking left frame B;
walking down-right frame A; clawing downwards frame A; walking down (towards the
viewer) frame A.

Row 4: walking up-right frame A; walking up (away from the viewer) frame B;
clawing right frame A; sitting still and calm facing the viewer — the resting
pose, the most important cell; walking left frame A; walking down-left frame B;
walking down (towards the viewer) frame B; alert and startled, eyes wide, small
motion marks beside the head.

Output the single 2048 x 1024 PNG and nothing else.

---

Import it, letting the cells fall into the layout they were drawn for:

```sh
python3 tools/grid2char.py ~/Downloads/sheet.png Resources/Characters/Foo.nekochar \
        --name "Foo" --size 48 --mirror
```

`--mirror` is worth keeping even here: it overwrites the left-facing cells with
flipped copies of the right-facing ones, so the two halves match even when the
generator drew them as two different characters, which is the usual outcome.
Drop it only if the left-facing poses came out genuinely better.

## Shorter alternative: half a sheet, 16 cells

Asking a generator for eight directions gets eight loosely related drawings:
the walks come out as sitting poses, and left-facing rarely matches
right-facing. Two things fix that.

**Ask for half of them.** A pose facing left is the pose facing right, flipped.
`grid2char.py --mirror` builds `left`, `upleft`, `dwleft` and `ltogi` by
flipping their right-facing twins, so they match by construction. What is left
to draw is one horizontal direction, one diagonal, towards the viewer, and away.

**Say what each view shows.** A generator defaults to drawing the face in every
cell, which is exactly what makes a walk cycle unreadable. State whether the
face, the back or the profile is visible.

---

Create a 1024 x 1024 pixel sprite sheet for a 1990s desktop pet, on a fully
transparent background. It is a 4 x 4 grid of 256 x 256 pixel cells, sixteen
poses of the same character.

The character: [describe it in two or three sentences: species, clothing,
one or two props, and any colour that must stay the same in every cell].

Style: hard-edged pixel art, no anti-aliasing, no gradients, at most six colours
plus transparency.

Framing rules, all of them mandatory:
- One pose per cell, entirely inside its cell, with at least 16 pixels of empty
  space on all four sides. No pose may touch or cross a cell boundary.
- The character is the same height in every cell, give or take a few pixels, and
  its feet rest on the same imaginary line near the bottom of each cell.
- The background is fully transparent: no glow, no halo, no soft shadow under
  the feet, no faint wash, nothing at all outside the character itself.
- No grid lines, no numbering, no labels, no frame borders.

The sixteen cells, left to right then top to bottom.

Row 1, all seen from the front, face towards the viewer, standing still:
1. calm and at rest, the neutral pose
2. startled: eyes wide, small motion marks around the head
3. yawning, eyes shut
4. looking off to one side, bored

Row 2, all seen from the front:
5. grooming or fidgeting, first frame
6. the same, second frame, hands or paws in a clearly different position
7. curled up asleep, eyes shut, first frame
8. asleep, second frame, only the breathing differs

Row 3, walking, seen in profile from its left side so it faces the right edge of
the cell. The face is visible in profile, one eye showing:
9. walking right, first frame: near leg forward, far leg back
10. walking right, second frame: the legs swapped
11. walking up and to the right, a three-quarter view from behind: most of the
    back visible, a sliver of cheek, first frame
12. the same three-quarter view, legs swapped

Row 4:
13. walking away from the viewer: the back of the head, no face at all, first
    frame
14. walking away, legs swapped
15. walking towards the viewer: the face fully visible, first frame
16. walking towards the viewer, legs swapped

In every walk pair the difference is only the legs, and the arms or wings if
they swing. Nothing else moves between the two frames of a pair.

Output a single PNG, exactly 1024 x 1024 pixels, transparent background.

---

Import it with the cells named in that order:

```sh
python3 tools/grid2char.py ~/Downloads/sheet.png Resources/Characters/Foo.nekochar \
        --name "Foo" --size 48 --grid 4x4 --mirror \
        --frames mati2,awake,mati3,jare2,kaki1,kaki2,sleep1,sleep2,\
right1,right2,upright1,upright2,up1,up2,down1,down2
```

`--mirror` fills in the left-facing half. The wall-scratching poses and the
down-diagonals are not drawn at all: they fall back to grooming and to the
horizontal walk, which is invisible in practice.

## Importing a full 8 x 4 sheet

```sh
python3 tools/sheet2char.py ~/Downloads/wizard.png \
        Resources/Characters/Wizard.nekochar --name "Wizard" \
        --author "generated" --license "check before redistributing"
python3 tools/char2sheet.py --all Resources/Characters web/assets/oneko \
        --registry web/src/oneko-characters.ts
./build.sh
```

`sheet2char.py` reports any cell that came out empty, which is the quickest way
to see whether the model actually filled the grid.

`grid2char.py` prints what it had to repair, which is worth reading: `cleared
N pixels below alpha 16` means the sheet arrived under a near invisible wash,
and one of these sheets had it over 44% of its area — left in place it defeats
the trimming, because every cell's bounding box then covers the whole cell.
