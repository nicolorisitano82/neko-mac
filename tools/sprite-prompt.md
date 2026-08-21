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

## Full sheet prompt

---

Create a 256 x 128 pixel sprite sheet for a 1990s desktop pet, on a fully
transparent background. It is an 8 x 4 grid of 32 x 32 pixel cells; every cell
holds one pose of the same character, centred in its cell, with no grid lines,
no numbering, no frame borders and no background colour.

The character: a small wizard cat. A pointed wizard hat with a curled tip and a
few stars on it, a short cloak clasped at the neck, and a stubby wand held in
one paw. Everything else reads as an ordinary cartoon cat: round head, small
triangular ears poking out under the hat brim, dot eyes, a long tail.

Style: hard-edged pixel art at true 32 x 32 resolution, no anti-aliasing, no
gradients, no outlines thinner than one pixel. At most six colours plus
transparency: a dark outline, two tones for the fur, two for the hat and cloak,
one accent for the stars and the wand tip. Keep the hat, cloak and wand the same
size, colour and shape in every cell, so the frames read as one character.

The cells, left to right then top to bottom:

Row 1: scratching an unseen wall above it, frame B; walking up and to the left,
frame B; curled up asleep, frame B; walking to the right, frame B; scratching a
wall to its left, frame B; sitting and grooming itself, frame B; sitting and
grooming itself, frame A; sitting and licking a front paw.

Row 2: scratching the wall above, frame A; walking up and to the left, frame A;
curled up asleep, frame A; walking to the right, frame A; scratching the wall to
its left, frame A; walking down and to the right, frame B; walking down and to
the left, frame A; scratching a wall below it, frame B.

Row 3: walking up and to the right, frame B; walking away from the viewer,
frame A; scratching a wall to its right, frame B; sitting and yawning, eyes shut;
walking to the left, frame B; walking down and to the right, frame A; scratching
the wall below, frame A; walking towards the viewer, frame A.

Row 4: walking up and to the right, frame A; walking away from the viewer,
frame B; scratching the wall to its right, frame A; sitting still facing the
viewer, calm, the resting pose; walking to the left, frame A; walking down and
to the left, frame B; walking towards the viewer, frame B; alert and startled,
ears up, eyes wide, hat slightly askew.

In the two frame walks the difference between A and B is only the legs and the
tail, as in a two frame walk cycle. A "back" pose shows the character from
behind, tail towards the viewer; a "towards the viewer" pose shows its face.

Output a single PNG, exactly 256 x 128 pixels, transparent background, no
padding, no watermark, no text.

---

## Smaller prompt, if the full sheet comes out inconsistent

Only the resting pose is mandatory. Diagonals fall back to the nearest cardinal
direction, wall scratching falls back to grooming, and everything else falls
back to sitting still, so ten frames already give a character that animates in
every direction.

---

Create a 160 x 64 pixel sprite sheet on a transparent background: a 5 x 2 grid
of 32 x 32 pixel cells, each holding one pose of the same character, centred, no
grid lines or labels.

The character and the style: [paste the character and style paragraphs from the
prompt above].

Top row, left to right: sitting still facing the viewer, the resting pose;
alert and startled with ears up; sitting and grooming itself; curled up asleep;
sitting and yawning with eyes shut.

Bottom row, left to right: walking to the right frame A; walking to the right
frame B; walking towards the viewer frame A; walking away from the viewer
frame A; walking to the left frame A.

Output a single PNG, exactly 160 x 64 pixels, transparent background, no text.

---

Then cut the ten cells out and place them in a `Foo.nekochar` folder as
`mati2.png`, `awake.png`, `kaki1.png`, `sleep1.png`, `mati3.png`, `right1.png`,
`right2.png`, `down1.png`, `up1.png`, `left1.png`, and write a `character.plist`
naming only the states you have. Anything you leave out is filled in by the
fallback chain.

## Importing a full sheet

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
