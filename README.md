# Neko

A Mac OS X port of the [Neko program](http://en.wikipedia.org/wiki/Neko_%28computer_program%29) written in Objective-C. You can run Oneko
on Mac OS X but the cat doesn't appear in front of Mac OS applications, so I
ported it to Cocoa. My version does not change the mouse cursor or support
different themes. This is based off the public domain Oneko code.

**If you draw, come and help.** Forty-three characters ship with the app and most
of the newer ones are generated pixel art that a real artist would improve in an
afternoon. Both kinds of contribution are wanted — polishing the characters that
are here, and drawing new ones — and a character is just a folder of PNGs, no
code involved. See [Graphic artists welcome](#graphic-artists-welcome) below.

Neko does not show up in the dock. It lives in the menu bar instead: click the
cat icon for

* **Pause Neko** / **Resume Neko** — hide and freeze the cat, or bring it back
* **Character ▸** — pick the sprite set; the menu bar icon follows it
* **Preferences…** (⌘,) — character, speed, how close it comes to the pointer,
  size (1× or 2×), which of the three behaviours it follows, whether the cat
  falls asleep when the mouse sits still, whether it wanders off on its own,
  whether it comments on what you are doing, and whether it opens at login
* **Ask Neko** (⌃⌥N) — hold a question out loud, get an answer in a bubble.
  Until it is set up the same slot reads **Set up Ask Neko…** and opens its
  preferences instead
* **About Neko**
* **Quit Neko** (⌘Q)

The interface is available in English, Italian, French and Spanish, following
the language the system asks for.

Settings are stored in `NSUserDefaults` (`NekoCharacter`, `NekoSpeed`,
`NekoStopRadius`, `NekoScale`, `NekoIdleSleep`, `NekoWander`, `NekoBehaviour`,
`NekoPaused`, `NekoSuggest`, `NekoSuggestEvery`) and take effect
immediately.

**Behaviour** is a choice between three, because they do not mix:

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

*Roams on its own* is the third: the cat goes wherever it likes on the desk and
the pointer means nothing to it — not a destination, not something to avoid. It
picks somewhere at least a third of the desk away, walks there, sits for a second
or three, and sets off again. Moving the mouse does not interrupt it, which is
the difference between this and wandering.

Sleeping is on a longer clock here. The idle chain would have it dozing three
seconds into its first pause, which looks broken rather than sleepy, so it stays
awake for five minutes of roaming before a nap is allowed, sleeps for half a
minute, and then the five minutes start again. Measured: over 150 s it walked
10 650 pt across 14 trips, on its feet 57% of the time and asleep for none of it;
over 400 s, 27 793 pt across 35 trips, still 57% on its feet, 6% of it asleep —
one nap, in the last minute and a half.

Following, the cat closed to 16 pt of a parked pointer; roaming, it never came
within 439 pt.

**Curiosity** comes with that behaviour. Every so often — 45 to 120 seconds
apart, and never while you are away — the cat drops what it was doing and takes
an interest in you:

* typing fast: it comes over to the pointer, sits down and asks what you are
  writing
* moving the mouse about: it runs over and pounces on the cursor
* neither, for twenty seconds: it goes and claws the edge of the screen
* anything else: it wanders over to see what you are up to

What it goes on is what the system tells anyone without a permission prompt:
`CGEventSourceCounterForEventType` for how many keys and mouse moves have
happened, and how long since the last one. Not which keys, not where, nothing
that identifies anything — typing fast is a number going up. The question waits
until the cat has actually arrived, because asking what you are writing from the
far corner of the screen is a worse joke.

The question itself comes from whichever engine **Ask Neko** is set to, asked
while the cat is still crossing the desk so the walk covers the wait. Written-in
lines are the fallback for no engine, an error, or an answer that arrives after
the cat has wandered off.

**Reading the text you are working on** is a separate switch on the Suggestions
tab, off until you turn it on, and it needs the Accessibility permission. With it
on, the field you are typing in — or whatever is under the pointer — is read
through `AXUIElementCopyAttributeValue` and included in what the engine is told,
which is what turns *"what are you writing?"* into *"cosa stai scrivendo nelle
note di rilascio?"*. Both measured, same desktop, with a file open in TextEdit.

Password fields are refused by subrole, nothing at all is read while macOS has
secure keyboard entry on, only the last few hundred characters are taken, and
with a remote engine that text is sent to that service. The tab prints the exact
block that would be sent, switch on or off.

**Suggestions** live in that third behaviour and nowhere else, under their own
tab, off until you turn them on. While roaming, the cat glances at what you are
doing and now and then says something about it in the bubble — a tip, a nudge or
a joke — through whichever engine **Ask Neko** is set to.

What it can see is deliberately shallow and needs no permission at all: which
application is in front, how long you have been in it, how often you have been
switching, whether you are at the keyboard, and the time. Window titles are read
only if this Mac has already granted Neko screen recording for some other reason;
the permission is never requested. Nothing is read from inside your documents.
The tab prints the exact text that would be sent before you switch it on, and
with a remote provider that text goes to that service like any other question.

It stays quiet while you are away from the keyboard, waits until you have been in
one application for twenty-five seconds, keeps at most one remark per interval
(two to sixty minutes, ten by default), and doubles that before commenting on the
same application twice. A remark it decided not to make still costs the interval,
so a refusal cannot turn into a loop.

Quality follows the engine rather than the plumbing. Apple's on-device model
answers in about 0.8 s with something like *"Safari ti tiene incollato: prova a
chiuderne qualcuna"*; the 1.5B GGUF, given the same context, manages *"Navigo
verso i siti web"* — grammatical, pointless. For this feature the bigger models
are worth their disk.

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

## Graphic artists welcome

The 43 characters here came from three places: oneko's public domain XBM sprites,
fan-made sheets written for the JavaScript port, and pixel art generated by asking
an image model nicely. That last group works, and it shows: the walk cycles are
two frames of whatever the model felt like, the left-facing poses are flipped
copies of the right-facing ones because the drawn ones never matched, and a human
eye would find plenty to fix in all of them.

So: if you draw, contributions are very welcome — both **improving the characters
already here** and **adding new ones**. Nothing needs to be built or compiled to
try one.

A character is a folder, `Foo.nekochar`, holding 32 PNG frames and a
`character.plist` naming them. The whole `Resources/Characters` directory is
copied into the app as a folder reference, so a new folder needs no project
change: drop it in, rebuild, and it appears in the menu. The sprites can be any
size — 32, 48 and 64 points all ship — and any state may be left out, because
missing ones fall back (`jare` to `stop`, the wall-scratching poses to `kaki`, and
so on).

The easiest way in is one sheet, 8 columns by 4 rows, one pose per cell:

```sh
python3 tools/grid2char.py sheet.png Resources/Characters/Foo.nekochar \
        --name "Foo" --size 48 --mirror --split
```

[tools/sprite-prompt.md](tools/sprite-prompt.md) has the layout of all 32 cells,
the exact cell geometry, what each view is supposed to show, and what the
importer does about sheets whose figures overflow their cells. `--mirror` builds
the left-facing poses from the right-facing ones; drop it if you drew both and
they match.

Two things worth knowing before you spend an evening on it. Each
`character.plist` records where its sprites came from and under what licence, and
sprites you drew yourself are the only ones here whose licence is not a question
mark — those are the most valuable contribution of all. And a character can carry
a `Persona`, one phrase saying who it is, which is what it sounds like when
someone asks it a question out loud.

Open a pull request, or an issue with the sheet attached if the tooling gets in
the way.

## Ask Neko

Off by default. The menu bar offers to set it up until it is on, and asks the
question afterwards. Once on, it gives the cat a keystroke — ⌃⌥N by default: press it, ask something out loud, and the answer
appears in a bubble beside the cat, which stops chasing the pointer while you
talk to it.

The keystroke is registered rather than monitored, so it costs no Accessibility
permission and works inside the sandbox. The microphone is asked for the first
time the feature is used and opens only between the keystroke and the end of the
sentence; recognition stays on this Mac when the language supports it.

Answers come from one of five places, chosen in the preferences:

*Apple Intelligence, on this Mac* is the default: the on-device model, the same
one Siri's own features run on. Nothing leaves the Mac, there is no key and there
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

*ChatGPT* and *Claude* are asked directly, each with a key of your own kept in
the Keychain under its own account, so switching between them loses neither. The
model name is a preference in both cases. Apple's own ChatGPT integration cannot
be reached from another application — it answers inside Siri and the writing
tools, never to a program — so a Shortcut ending in a ChatGPT action is the other
way to it.

*A model on this Mac* is a GGUF you download from the **Local model** tab — four
instruction-tuned builds between 468 MB and 2.0 GB, Qwen2.5 and Llama 3.2 — kept
in the app's own Application Support folder. llama.cpp is built once as a static
library and linked in, with Metal, so the model runs on this Mac's GPU and
nothing else is installed for it: no daemon, no package manager, no second
application. A **Remove unused models** button clears everything but the model
you chose, after saying how much disk that frees.

Both local routes answer as they go. Apple's model puts the first words in the
bubble in about half a second, where the whole answer takes nearer two. The 1.5B
GGUF reaches its first word in 0.40 s including opening the file, and answers a
second question in 0.03 s once the model is in memory. The two remote providers
answer in one piece.

While an answer is on its way the bubble shows the cat thinking — a pacing paw
and one of five feline occupations — under the question you asked, until the
first word of the answer arrives.

Apple's model is reached through `src/NekoAppleModel.swift`, the only Swift file
in the project: `FoundationModels` ships no headers, so a Swift shim is the only
way in. The GGUF engine is `src/NekoLlamaEngine.mm`, and `build.sh` clones and
builds llama.cpp once into `~/Library/Caches/neko-llama` before linking it — the
Xcode project lists the file but does not compile it, since it has no llama
libraries to link. The Intel half of the universal binary leaves both out: Apple
Intelligence needs Apple silicon, and so does the Metal build here. [docs/ask-neko.md](docs/ask-neko.md) has the design,
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

43 characters ship with the app, in three families.

**From oneko itself** — public domain sprites, converted from oneko's 1-bit XBM
pairs: **Neko** (the original cat), **Tora** (its tiger, which reuses the cat's
masks because oneko has no `bitmasks/tora`), **Dog**, and **Sakura** and
**Tomoyo** from oneko's sakura patch. **Kuro** is an inverted recolour of Neko.

**From the oneko.js ecosystem** — 22 skins written for the JavaScript port:
Ace, Black, Bunny, Calico, Eevee, Esmeralda, Fox, Ghost, Gray, Jess, Kina,
Lucy, Maia, Maria, Mike, Moka, Silver, Silversky, Snuupy, Spirit, Valentine,
Vaporwave.

**Drawn for this app** — generated pixel art imported with `tools/grid2char.py`
(with `--split`, which shares the sheet's pixels out between the poses instead of
cutting cells: these sheets draw the figures taller than their cell, and a
straight cut takes off shoes and hat tips),
and the first characters here that are not 32 points across: **Merlin** the
wizard cat, **Owl**, **Alien**, **Pinup**, **Gandalf**, **Frodo** and the two
musicians **TS** and **OR** at 48, with **Merlin XL**, **Owl XL**, **Pinup XL**,
**Gandalf XL**, **Frodo XL**, **TS XL** and **OR XL** at 64.

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
xcrun notarytool submit dist/Neko-1.7.1.dmg --apple-id ... --team-id ... --wait
xcrun stapler staple dist/Neko-1.7.1.dmg
```
