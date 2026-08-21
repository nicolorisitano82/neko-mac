# Neko

A Mac OS X port of the [Neko program](http://en.wikipedia.org/wiki/Neko_%28computer_program%29) written in Objective-C. You can run Oneko
on Mac OS X but the cat doesn't appear in front of Mac OS applications, so I
ported it to Cocoa. My version does not change the mouse cursor or support
different themes. This is based off the public domain Oneko code.

Neko does not show up in the dock. It lives in the menu bar instead: click the
cat icon for

* **Pause Neko** / **Resume Neko** — hide and freeze the cat, or bring it back
* **Character ▸** — pick the sprite set; the menu bar icon follows it
* **Preferences…** (⌘,) — character, speed, how close it comes to the pointer,
  size (1× or 2×), which of the two behaviours it follows, whether the cat falls
  asleep when the mouse sits still, whether it wanders off on its own, and
  whether it opens at login
* **Ask Neko** (⌃⌥N) — hold a question out loud, get an answer in a bubble.
  Until it is set up the same slot reads **Set up Ask Neko…** and opens its
  preferences instead
* **About Neko**
* **Quit Neko** (⌘Q)

The interface is available in English, Italian, French and Spanish, following
the language the system asks for.

Settings are stored in `NSUserDefaults` (`NekoCharacter`, `NekoSpeed`,
`NekoStopRadius`, `NekoScale`, `NekoIdleSleep`, `NekoWander`, `NekoBehaviour`,
`NekoPaused`) and take effect
immediately.

**Behaviour** is a choice between two, because they do not mix:

*Follows the cursor* is the classic one. The cat chases the pointer, stops at
the ring described above, and rests wherever it stopped — in mid-air if that is
where it stopped, exactly as oneko always did.

*Lives on the Dock* ignores the pointer and moves in along the bottom of the
screen instead. When the Dock is out the cat lives on top of it; when the Dock is
hidden, or set to a side of the screen, it runs to the top edge of a window that
is not filling the screen and lives there instead; with neither, it settles on
the desk. Gravity applies in this behaviour, so hiding the Dock or closing the
window it sat on drops it onto whatever is below.

The Dock's own window covers the whole screen and says nothing useful, so the
room it takes is read from the difference between a screen's `frame` and its
`visibleFrame`. Window rectangles come from `CGWindowListCopyWindowInfo`, which
needs no permission and works inside the sandbox; nothing is read but geometry.

**Wander off when idle** belongs to the first behaviour and is disabled in the
second, where the cat is already moving about on its own. Once it has arrived,
sat down and been left alone for half a minute, it strolls off away from the
pointer instead of sleeping there for ever. Moving the pointer cancels the errand
at once.

**Open at login** asks the system to launch Neko when you log in, through
`SMAppService`, so there is no helper bundle and no stored preference: the
system holds that state and the checkbox reads it back. macOS may ask you to
allow it under Login Items before it takes effect, and the checkbox stays
disabled on macOS 12 and earlier, where the API does not exist.

**Stops short by** is the ring the cat keeps around the pointer, 0 to 200
points, 48 by default. At 0 it sits right under the cursor, which is what it did
before the setting existed. The step is capped by whatever distance is left over
the ring, so the cat settles on it instead of stepping across and jittering
back; as in the original, it only bothers getting up once the pointer is more
than half a step beyond the ring.

## Ask Neko

Off by default. The menu bar offers to set it up until it is on, and asks the
question afterwards. Once on, it gives the cat a keystroke — ⌃⌥N by default: press it, ask something out loud, and the answer
appears in a bubble beside the cat, which stops chasing the pointer while you
talk to it.

The keystroke is registered rather than monitored, so it costs no Accessibility
permission and works inside the sandbox. The microphone is asked for the first
time the feature is used and opens only between the keystroke and the end of the
sentence; recognition stays on this Mac when the language supports it.

Answers come from one of three places, chosen in the preferences:

*Apple Intelligence, on this Mac* is the default: the on-device model, the same
one behind Apple Intelligence. Nothing leaves the Mac, there is no key and there
is no bill. It needs macOS 26 or newer on a Mac that supports Apple
Intelligence, with the feature switched on; when any of that is missing the
preferences say which.

*A Shortcut of mine* hands the question to a Shortcut you own and shows what it
puts on the clipboard, restoring whatever was there before. The intelligence is
yours to choose: Apple Intelligence's *Use Model* action, which can escalate to
ChatGPT, a ChatGPT action, or anything else that ends in text. No key lives in
the app and nothing of ours goes over the network.

*Claude, directly* calls the Anthropic API with a key you paste once, kept in the
Keychain and never in the preferences file. Questions go to Anthropic; the
preferences say so next to the field.

Neko answers in the language it is running in — named outright in the
instructions, because "the same language as the question" is too weak for a
small model, which drifts into English halfway through. To have it answer in a
different language, change the app's language in System Settings.

Whoever is on screen is who answers: the manifest's `Persona` describes the
character, and the question goes out with it, so the wizard cat sounds like a
wizard and the flying saucer talks about this planet from the outside. The facts
are not negotiable — the instructions put truth first and confine the character
to the wording, because a small model handed a costume will otherwise invent a
charming explanation. Characters without a `Persona` answer as themselves, by
name.

With none of the providers available the cat answers in character anyway, which
is the whole joke and needs no setup at all.

The on-device model is reached through `src/NekoAppleModel.swift`, the only Swift
file in the project: `FoundationModels` ships no headers, so a Swift shim is the
only way in. The Intel half of the universal binary leaves it out, since Apple
Intelligence needs Apple silicon anyway. [docs/ask-neko.md](docs/ask-neko.md) has the design,
including the part that cannot work: Siri has no public API that hands an answer
back to another application.

## Characters

Every sprite set is a folder in `Resources/Characters`, and the whole directory
is copied into the app as a folder reference, so adding a character needs no
project change — drop the folder in and rebuild:

    Resources/Characters/Neko.nekochar/
        character.plist
        mati2.gif, sleep1.gif, ...

`character.plist`:

| Key | |
|---|---|
| `Identifier` | unique string, this is what `NekoCharacter` stores |
| `Name` | shown in the menu and in the preferences |
| `SpriteWidth` / `SpriteHeight` | points; the panel sizes itself from these |
| `Persona` | optional: who this character is, in a phrase, used when it is asked a question |
| `States` | one entry per state: `Frames` (file names, in order) and `TicksPerFrame` |

A tick is 0.125s, so `TicksPerFrame = 4` holds each frame for half a second —
that is how the sleeping animation is slowed down.

The state names are `stop`, `jare`, `kaki`, `akubi`, `sleep`, `awake`,
`u_move`, `d_move`, `l_move`, `r_move`, `ul_move`, `ur_move`, `dl_move`,
`dr_move`, `u_togi`, `d_togi`, `l_togi`, `r_togi`. Only `stop` is required:
diagonals fall back to the nearest cardinal direction, the wall-scratching
`*_togi` states fall back to `kaki`, and everything else falls back to `stop`,
so a partial character still animates. Any image format `NSImage` reads works,
mixed extensions included.

34 characters ship with the app, in three families.

**From oneko itself** — public domain sprites, converted from oneko's 1-bit XBM
pairs: **Neko** (the original cat), **Tora** (its tiger, which reuses the cat's
masks because oneko has no `bitmasks/tora`), **Dog**, and **Sakura** and
**Tomoyo** from oneko's sakura patch. **Kuro** is an inverted recolour of Neko.

**From the oneko.js ecosystem** — 22 skins written for the JavaScript port:
Ace, Black, Bunny, Calico, Eevee, Esmeralda, Fox, Ghost, Gray, Jess, Kina,
Lucy, Maia, Maria, Mike, Moka, Silver, Silversky, Snuupy, Spirit, Valentine,
Vaporwave.

**Drawn for this app** — generated pixel art imported with `tools/grid2char.py`,
and the first characters here that are not 32 points across: **Merlin** the
wizard cat and **Owl** at 48, **Merlin XL** and **Owl XL** at 64, **Alien** and
**Pinup** at 48.

The Sakura and Tomoyo sprites derive from Card Captor Sakura artwork, the
oneko.js skins are fan-made sheets from collections that state no licence, and
the generated ones have their own uncertainty, so check the situation before
shipping the app with them. Each `character.plist` records where its sprites
came from.

Because the menu bar icon is rendered as a template image only when the sprites
are greyscale, the classic two colour characters adapt to a light or dark menu
bar while the colourful ones keep their colours.

### Converting more characters

Two converters live in `tools/`, both writing a ready `*.nekochar` folder.

`xbm2char.py` takes an oneko animal. oneko stores each frame as two 1-bit XBM
files — `bitmaps/` says which pixels take the foreground colour, `bitmasks/`
says which pixels are drawn at all — and the script combines them into RGBA
PNGs.

```sh
curl -O http://deb.debian.org/debian/pool/main/o/oneko/oneko_1.2.sakura.6.orig.tar.gz
tar xzf oneko_1.2.sakura.6.orig.tar.gz
python3 tools/xbm2char.py oneko-1.2.sakura.6.orig tora Resources/Characters/Tora.nekochar --name Tora
```

`--verify DIR` compares the conversion against an existing character instead of
writing files; converting `neko` reproduces `Neko.nekochar` pixel for pixel,
which is what keeps the bit polarity in the script honest.

`sheet2char.py` takes an oneko.js sprite sheet: one 256x128 PNG holding an 8x4
grid of 32x32 cells, which is exactly the 32 frames a character needs. Sheets a
pixel short of that (some community skins are 255x127) are padded rather than
rejected.

```sh
python3 tools/sheet2char.py oneko.gif Resources/Characters/Foo.nekochar --name Foo
```

The cell layout in that script was not read off the oneko.js source: it was
derived by slicing oneko.js' own sheet and matching every cell against the
sprites already in `Neko.nekochar`. All 32 matched exactly, so the mapping is a
bijection and any sheet in that format converts unambiguously.

`char2sheet.py` goes the other way, packing a character back into an oneko.js
sheet, and with `--all` it also writes the TypeScript registry the web version
uses:

```sh
python3 tools/char2sheet.py --all Resources/Characters web/assets/oneko \
        --registry web/src/oneko-characters.ts
```

Packing `Neko.nekochar` reproduces oneko.js' own sheet pixel for pixel, and
packing an imported skin reproduces the sheet it was sliced from; `--verify
SHEET` runs that comparison.

## The web version

`web/` holds a TypeScript port of oneko.js that wears all 28 characters,
packaged as a standalone Angular component plus a framework-agnostic engine.
Its sheets and character registry are generated from `Resources/Characters` by
the command above, so the two versions cannot drift. See
[web/README.md](web/README.md), and [web/INTEGRATION.md](web/INTEGRATION.md) for
adding it to an app that already exists.

The `*_togi` states are the cat clawing at what it cannot get past: the edge of
the screens, or the top of the window it stands on when the pointer is inside
that window.

## Building

Open `Neko.xcodeproj` in Xcode and build, or, with only the Command Line Tools
installed:

```sh
./build.sh            # -> build/Neko.app
./build.sh install    # -> also ~/Applications/Neko.app
```

If the sources were downloaded with a browser the folder carries macOS'
quarantine flag, which the app inherits: Gatekeeper then refuses to run it and
reports it as damaged. Clear it once with

```sh
xattr -dr com.apple.quarantine .
```

## Packaging

`./dmg.sh` builds `dist/Neko-<version>.dmg`: the app, an alias to
`/Applications` to drag it onto, and a Finder window arranged over
`packaging/dmg-background.png`. A background twice the window size is paired
with a downscaled copy in a TIFF automatically, so one file covers Retina and
non-Retina displays. The icon positions in the script were measured from the
picture; [packaging/dmg-background-prompt.md](packaging/dmg-background-prompt.md)
records the geometry and the prompt the picture came from.

Arranging the window means scripting Finder, which needs permission to control
it (System Settings > Privacy & Security > Automation). Without that permission
the script still produces a working image, only without arranged icons.

The app is signed ad hoc, and Gatekeeper refuses an ad-hoc signed app that
arrives inside a downloaded image. To hand the image to someone else, sign and
notarise it:

```sh
./dmg.sh --sign "Developer ID Application: Your Name (TEAMID)"
xcrun notarytool submit dist/Neko-1.7.dmg --apple-id ... --team-id ... --wait
xcrun stapler staple dist/Neko-1.7.dmg
```
