# Neko

A Mac OS X port of the [Neko program](http://en.wikipedia.org/wiki/Neko_%28computer_program%29) written in Objective-C. You can run Oneko
on Mac OS X but the cat doesn't appear in front of Mac OS applications, so I
ported it to Cocoa. My version does not change the mouse cursor or support
different themes. This is based off the public domain Oneko code.

Neko does not show up in the dock. It lives in the menu bar instead: click the
cat icon for

* **Pause Neko** / **Resume Neko** — hide and freeze the cat, or bring it back
* **Character ▸** — pick the sprite set; the menu bar icon follows it
* **Preferences…** (⌘,) — character, speed, size (1× or 2×) and whether the cat
  falls asleep when the mouse sits still
* **About Neko**
* **Quit Neko** (⌘Q)

Settings are stored in `NSUserDefaults` (`NekoCharacter`, `NekoSpeed`,
`NekoScale`, `NekoIdleSleep`, `NekoPaused`) and take effect immediately.

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

Six characters ship with the app:

| Character | Where it comes from |
|---|---|
| Neko | the original oneko cat |
| Tora | oneko's tiger; it reuses the cat's masks, oneko has no `bitmasks/tora` |
| Dog | oneko's dog |
| Sakura, Tomoyo | oneko's sakura patch. The sprites derive from Card Captor Sakura artwork, so check the situation before redistributing the app with them |
| Kuro | an inverted recolour of Neko, added to exercise the picker |

### Converting more oneko animals

`tools/xbm2char.py` turns an oneko animal into a character folder. oneko stores
each frame as two 1-bit XBM files — `bitmaps/` says which pixels take the
foreground colour, `bitmasks/` says which pixels are drawn at all — and the
script combines them into RGBA PNGs.

```sh
curl -O http://deb.debian.org/debian/pool/main/o/oneko/oneko_1.2.sakura.6.orig.tar.gz
tar xzf oneko_1.2.sakura.6.orig.tar.gz
python3 tools/xbm2char.py oneko-1.2.sakura.6.orig tora Resources/Characters/Tora.nekochar --name Tora
```

`--verify DIR` compares the conversion against an existing character instead of
writing files; converting `neko` reproduces `Neko.nekochar` pixel for pixel,
which is what keeps the bit polarity in the script honest.

The `*_togi` states are currently unreachable: they need screen edge detection,
which this port does not do.

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
