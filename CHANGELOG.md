# Changelog

## 1.7 — 2026-08-22

### Ask Neko

Off by default: ⌃⌥N, a question out loud, an answer in a bubble beside the cat,
which holds still while you talk to it.

One slot in the menu carries it, changing identity rather than greying out:
**Set up Ask Neko…** opens its preferences tab while the feature is off, and
becomes **Ask Neko (⌃⌥N)** once it is on. A disabled item that does nothing
teaches nobody anything, and a checkmark would have hidden the five settings
behind it.

The bubble used to cut the end off short answers. It measured the text with
`boundingRectWithSize:` and drew it in an `NSTextField`, which keeps insets of
its own: a sentence that measured as one line needed two inside the field, and
the second one fell outside the frame. It is now measured by the cell that draws
it. The question also stays on screen while the cat thinks, instead of being
replaced by a row of dots, so you can see what it understood.

The keystroke is a Carbon hotkey registration rather than an event monitor,
which is why it needs no Accessibility permission and works in the sandbox. The
microphone is requested the first time the feature is used, after a sheet that
says what is about to happen, and it is open only between the keystroke and the
end of the sentence. `SFSpeechRecognizer` is weakly linked and keeps recognition
on the Mac when the language allows.

Answers come from one of three providers behind a one-method protocol.

**Apple's on-device model** is the default: the one behind Apple Intelligence,
free, private and offline, answering in about two seconds. It is reached through
`src/NekoAppleModel.swift`, the first Swift file in this project —
`FoundationModels` is Swift-only and ships no headers, so there is no other way
in. The Intel slice of the universal binary omits it, because the Command Line
Tools carry the Swift compatibility libraries for arm64 only and Apple
Intelligence needs Apple silicon regardless; the provider reports itself
unavailable when the class is missing, which is what already happens on macOS
older than 26.

The other two: a Shortcut the user owns, which returns its answer through the
clipboard and gets the previous contents put back, or the Anthropic API with a
key kept in the Keychain. With none of them available the cat answers in
character.

Asking for a Shortcut that does not exist used to mean twelve seconds of waiting
and a vague apology while Shortcuts complained on its own behalf; the name is now
checked against `shortcuts list` first, and the cat says which name it could not
find.

The deployment target moves from 10.13 to 11, which is what mixing Swift in
costs.

Siri itself is not involved, and cannot be: no public API hands a Siri answer
back to another application. `docs/ask-neko.md` records that, the design, and the
three places where the implementation deliberately differs from it.

## 1.6 — 2026-08-21

### The cat claws at what it cannot pass

Every bundled character has always carried four wall-scratching animations this
port could not reach, because nothing told it where the walls were. It does now:
the edge of the combined screens, and the top of the window the cat is standing
on when the pointer is inside that window. The cat also stays on screen, which
it did not before — it could walk off the edge following a pointer at the
border.

### Two behaviours, not one with an extra switch

**Behaviour** replaces what started as a checkbox, because chasing the pointer
and living on window edges fight each other: one wants the cat to rest wherever
it stopped, the other pulls it down onto the nearest surface, and having both at
once made the cat arrive at the pointer, slide to the floor, climb back and
start over.

*Follows the cursor* is the classic behaviour, unchanged. *Lives on the Dock*
ignores the pointer: the cat lives on top of the Dock, and when the Dock is
hidden or sits on a side of the screen it runs to a window that is not filling
the screen and lives on its top edge instead. Gravity applies, so hiding the Dock
or closing that window drops it.

The Dock's own Quartz window covers the whole screen and tells you nothing, so
the space it reserves is read from the difference between a screen's `frame` and
its `visibleFrame`, and the cat is kept over the middle of that edge where the
Dock actually is. Window rectangles come from `CGWindowListCopyWindowInfo`, which
works inside the sandbox and needs no permission; the list is refreshed every few
ticks, since windows do not move eight times a second.

**Wander off when idle** is disabled in the second behaviour rather than
fighting it: a cat on the Dock is already moving about on its own.

### Designed, not built

`docs/ask-neko.md` plans **Ask Neko**: a hotkey, a spoken question, an answer in
a bubble beside the cat. It is a design document only — no code — and it records
what cannot work as first imagined, since Siri has no public API that hands an
answer back to another app.

### It goes for a walk, once it has actually rested

**Wander off when idle** now waits for the cat to arrive, sit down and be left
alone for half a minute, and then sends it *away* from the pointer rather than
to a random spot. Moving the pointer cancels the errand immediately.

## 1.5.2 — 2026-08-21

### Opens at login

A new preference asks the system to launch Neko when you log in. It goes
through `SMAppService`, so there is no helper bundle to ship and no preference
of our own: the system holds that state and the checkbox reads it back, which
also means the checkbox follows what the system agreed to rather than what was
clicked. macOS may ask for approval under Login Items before it takes effect,
and says so when it does.

`ServiceManagement` is linked, since a framework that is never linked is never
loaded and the class would be invisible to the runtime lookup. The framework has
existed since macOS 10.6 while the class arrived in 13, so the app still starts
on older systems, where the checkbox is simply disabled.

### Characters that face the right way

A generated sheet rarely holds eight coherent directions: the walks come out as
sitting poses and left-facing rarely matches right-facing. `grid2char.py
--mirror` builds every left-facing frame by flipping its right-facing twin, so
the two halves match by construction, and every generated character was
reimported with it. Pinup was redrawn against the rewritten prompt in
`tools/sprite-prompt.md`, which now says what each view has to show — walking up
is seen from behind, with no face at all, which is what was missing.

`--alpha-floor` clears a near invisible wash before anything else. One sheet
arrived with 44% of its area at alpha 1 to 16: invisible on screen, but enough
that no row read as empty and every cell's bounding box covered the whole cell,
so the trimming quietly did nothing and each pose was scaled from its cell
rather than from itself.

## 1.5.1 — 2026-08-21

### Stops short of the pointer

A new preference, **Stops short by**, is the ring the cat keeps around the
cursor: 0 to 200 points, 48 by default. At 0 it sits right under the cursor, the
way it always did. The step towards the pointer is capped by the distance left
over the ring, so the cat settles on it instead of stepping across and jittering
back, and anything under a point counts as arrived — the deltas are whole
points, so without that the cat could creep a fraction of a point per tick
without ever finishing.

The web version gained the same `stopRadius` option, replacing a hard-coded
48-point cushion that quietly doubled at 2× scale.

### The interface speaks four languages

English, Italian, French and Spanish, in `Resources/<lang>.lproj`. The English
text is the lookup key, so a missing translation falls back to English on its
own. The preferences window was widened to fit the longest of them, checked by
measuring every string against the control that holds it.

### Six new characters

Generated pixel art, imported with the new `tools/grid2char.py`: **Merlin** the
wizard cat and **Owl** at 48 points, **Merlin XL** and **Owl XL** at 64,
**Alien** and **Pinup** at 48. They are the first characters larger than the
32-point sprites oneko drew, which the manifest always allowed and nothing had
exercised.

`grid2char.py` keys the background out by flooding in from the border, so white
fur inside a character survives a white backdrop, and it compares alpha as well
as colour — a sprite outlined in black shares its colour with transparent black,
and an earlier version ate the outlines. `--autogrid` takes the cell boxes from
where the poses actually are rather than splitting the image evenly.

`char2sheet.py` now scales oversized characters down to 32 points for the web
sprite sheet instead of leaving them out.

### Fixed

- A character that fails to load no longer sizes the window to nothing.
- `tools/sprite-prompt.md` documents the cell-by-cell layout of a sheet, so a
  new character can be drawn to fit.

## 1.5 — 2026-08-21

The cat that chases your cursor, now with a menu bar item, preferences, 28
characters, and a web version. First release since the fork, so everything below
is new.

### A menu bar item

Neko has no dock icon, and until now the only way to quit it was `killall`. It
now lives in the menu bar:

- **Pause / Resume** — hide and freeze the cat, or bring it back
- **Character ▸** — switch sprite set; the menu bar icon follows it
- **Preferences…** (⌘,) — character, speed, size, idle behaviour
- **About Neko**
- **Quit Neko** (⌘Q)

The icon is drawn as a template image only when the sprites are greyscale, so
the classic cats adapt to a light or dark menu bar while the colourful ones keep
their colours.

### Preferences

| | |
|---|---|
| Character | any of the 28 below |
| Speed | 4 to 30 points per tick, shown in points per second |
| Stops short by | 0 to 200 points to keep from the pointer, 48 by default; 0 sits on the cursor |
| Size | 1× (32px) or 2× |
| Fall asleep when idle | on or off |

Settings live in `NSUserDefaults` (`NekoCharacter`, `NekoSpeed`,
`NekoStopRadius`, `NekoScale`, `NekoIdleSleep`, `NekoPaused`) and apply
immediately, no restart. The step towards the pointer is capped by the distance
left over the stop ring, so the cat settles on it rather than stepping across
and jittering back.

### 28 characters

From oneko itself, public domain: **Neko**, **Tora**, **Dog**, **Sakura**,
**Tomoyo**, plus **Kuro**, an inverted recolour.

From the oneko.js ecosystem: Ace, Black, Bunny, Calico, Eevee, Esmeralda, Fox,
Ghost, Gray, Jess, Kina, Lucy, Maia, Maria, Mike, Moka, Silver, Silversky,
Snuupy, Spirit, Valentine, Vaporwave.

Each one is a folder in `Resources/Characters` with a `character.plist`
manifest, added to the project as a folder reference — a new character is a
folder drop and a rebuild, no project change. Sprite size and per-state frame
timing come from the manifest, and a character that only describes some states
still animates: diagonals fall back to the nearest cardinal direction, wall
scratching falls back to grooming, everything else to sitting still.

Internally this replaced the state machine's comparison of `NSArray` pointers
with a `NekoState` enum, which is what made runtime character switching
possible at all.

### A web version

`web/` holds a TypeScript port of oneko.js wearing the same 28 characters,
packaged as a standalone Angular component plus a framework-agnostic engine:
live character swap, 1×/2× scale, adjustable speed, pause, idle sleep,
`prefers-reduced-motion` support, and inert under server side rendering.

Its sprite sheets and character registry are generated from the same folders the
app uses, so the two versions cannot drift. `web/INTEGRATION.md` covers adding
it to an app that already exists.

### For contributors

Three converters in `tools/`:

- `xbm2char.py` — an oneko animal (bitmap + bitmask XBM pairs) into a character
- `sheet2char.py` — an oneko.js 256×128 sprite sheet into a character
- `char2sheet.py` — a character back into a sheet, and the TypeScript registry

They check themselves: converting oneko's own cat reproduces the sprites already
in the tree pixel for pixel, and packing a character back reproduces the sheet
it came from. `--verify` runs those comparisons.

`./build.sh` builds the app with just the Command Line Tools, no Xcode.
`./dmg.sh` builds the disk image, background and window layout included. The
project also builds on a current macOS again: `SDKROOT` was pinned to the 10.9
SDK, which no longer exists.

### Installing

Open `Neko-1.5.dmg` and drag Neko to Applications.

**The app is signed ad hoc, not notarised.** macOS will report it as damaged the
first time, because it arrived from the internet. Clear the quarantine flag
once:

```sh
xattr -dr com.apple.quarantine /Applications/Neko.app
```

Universal binary, x86_64 and arm64, built for macOS 10.13 and later.

To quit it, use **Quit Neko** in the menu bar.

### Known limitations

- The wall-scratching animations are unreachable: they need screen edge
  detection, which this port does not do yet.
- No launch at login.
- The pet does not change the mouse cursor, unlike the X11 original.

### Credits and licences

Based on the public domain oneko by Masayuki Koba, and on Matthew Donoughe's
Cocoa port. The web engine is a port of
[oneko.js](https://github.com/adryd325/oneko.js), MIT, © 2022 adryd.

The sprites do not share one licence. The oneko animals are public domain.
Sakura and Tomoyo derive from Card Captor Sakura artwork. The oneko.js skins
come from community collections that state no licence, and several are fan art
of other people's characters. Each character's provenance is recorded in its
manifest.
