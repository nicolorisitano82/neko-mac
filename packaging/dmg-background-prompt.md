# Prompt for the DMG background

`packaging/dmg-background.png` is the picture in use, 1280 x 800, generated from
the prompt below. `dmg.sh` arranges a 640 x 400 point Finder window over it with
96 point icons, and its `APP_ICON_*` and `DROP_ICON_*` constants were measured
from the two clear circles in that picture rather than guessed: they are 126
points across, centred at (156, 216) and (487, 217) in window points, which is
(313, 432) and (974, 435) in the image's own pixels.

Replacing the picture therefore means re-measuring, or asking for the circles at
the same place. The prompt below asks for them at (340, 420) and (940, 420),
which is where they were specified; the generated image put them a few points
off, and the script followed the image.

Paste the following into an image model.

---

Create a 1280 x 800 pixel background image for a macOS disk image installer
window. It is the backdrop of a Finder window, so the artwork has to sit behind
two icons the operating system draws on top of it.

Subject: Neko, a tiny pixel-art cat that chases the mouse cursor around the
screen. Retro late-90s desktop-toy feeling, an affectionate nod to the classic
X11 program, not a corporate product page.

Hard layout constraints:
- Leave a clear, quiet circle of about 110 pixels radius centred at (340, 420):
  the app icon and its filename label go there.
- Leave the same clear circle centred at (940, 420): the Applications folder
  alias goes there.
- Between them, roughly x 480 to 800 at around y 420, draw a simple arrow or a
  dotted path pointing right, suggesting "drag from here to there". Pixel-art
  dashes or paw prints fit the subject.
- Keep the top band, y 60 to 200, free of busy detail: it can hold a short
  title, or stay empty.
- Keep the bottom 60 pixels calm and near-empty; the window edge can cover
  them.

Style:
- Flat, soft, low contrast. The icon filenames are drawn as small text under
  each icon, so the two circles and the area just below them must stay light
  and even, with no fine pattern that would fight the labels.
- Muted palette: pale warm grey, cream, dusty blue. One accent colour at most.
- Pixel-art or subtle graph-paper texture is welcome; a photographic or 3D
  render is not.
- Optional decoration: a few 32 x 32 style pixel cat silhouettes wandering the
  margins, small paw prints, a sleeping cat curled in a corner. Keep them out
  of the two clear circles.

Do not include: any drawing of an app icon or a folder icon at the two clear
positions, an Apple logo or any real trademark, macOS window chrome, title bars
or traffic-light buttons, drop shadows implying a window frame, a watermark, a
signature, or transparency. No rounded corners, the image is a plain rectangle.

Text: at most one short line, in the top band, reading "Drag Neko to your
Applications folder". If the model renders text poorly, leave the band empty
and let the arrow carry the meaning.

Output: a single flat PNG, exactly 1280 x 800 pixels, no alpha channel.

---

## Installing the result

```sh
cp ~/Downloads/generated.png packaging/dmg-background.png
./dmg.sh
```

That is all. A 1280 x 800 picture is twice the window, so on its own it would
only fill it on a Retina display; `dmg.sh` notices the size and pairs it with a
downscaled copy in a two representation TIFF, which covers both kinds of
display from one file. Dropping a ready made `packaging/dmg-background.tiff` in
instead also works and takes precedence.

Then measure where the icons should go, rather than eyeballing it:

```sh
open dist/Neko-1.5.2.dmg      # look at it, and if the icons sit off the circles
```

the four constants near the top of `dmg.sh` are the ones to change. The
positions actually written into the image can be read back out of its
`.DS_Store`, which is how the current numbers were confirmed.
