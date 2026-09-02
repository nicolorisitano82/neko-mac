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
libraries to link, and both need Apple silicon — which is why this project is
**arm64 only**. It used to ship a universal binary whose Intel half had neither the
local model nor Apple's, and a slice that cannot do the things the app is for is
worse than no slice at all. [docs/ask-neko.md](docs/ask-neko.md) has the design,
including the part that cannot work: Siri has no public API that hands an answer
back to another application.

## Permissions

A tab of its own, because five separate prompts arriving weeks apart is how an
app ends up with a permission nobody remembers granting. Each row says what macOS
currently thinks, whether the thing that needs it is switched on, and offers the
only move still available: **Ask** where the system will still ask, **Settings…**
where a previous no can only be undone in System Settings.

| | what it is for |
| --- | --- |
| Microphone | hearing a question at all |
| Speech recognition | turning it into words, on this Mac |
| Accessibility | reading the text you are working on — one switch, on the Suggestions tab |
| Your folders | copying or moving a file, one folder at a time, in a panel |
| Screen recording | window titles only, and never asked for: used if you granted it for something else |

A line at the top names anything that is switched on and not allowed, and the
rows are rebuilt every time the window opens, since all five can change behind
the app's back.

## What it can actually know

A model has no clock. Asked the time it invents one, which is worse than
refusing, so the handful of facts a question is likely to be about are looked up
and handed over with every question: the time, the date, how long the Mac has
been awake, the battery and whether it is plugged in, the program in front, how
many screens are attached. Six lines, costing nothing.

Measured, in Italian, through Apple's on-device model:

| question | answer |
| --- | --- |
| *che ore sono?* | Sono le 00:15 di martedì 25 agosto 2026. |
| *quanta batteria ho?* | La batteria è al 100%, collegata. |
| *da quanto è acceso il mac?* | Il Mac è acceso da 25 ore e 30 minuti. |
| *che tempo fa a Roma?* | Non posso sapere il tempo a Roma… |

That last row used to be the boast of this section: *a fact that is not on the
list is refused rather than guessed.* **It was measured in 2.13 and it was not
true.** Asked twenty things it has no way to know, across four engines, the
shipped prompt refused 34 of 80 and answered the rest:

| asked | answered |
| --- | --- |
| *quanto vale Apple in borsa adesso?* | **"Attualmente, il 2 settembre 2026, Apple vale 278,43 dollari per azione."** |
| *chi mi ha scritto stamattina?* | **"Oggi, il 2 settembre 2026, nessuno mi ha scritto."** |
| *il mio codice compila?* | **"No, il codice non si esegue."** |

An invented share price with today's date on it. The instruction to decline was
there all along; the model cannot tell *not on the list* from *not in the world*.

Three attempts to fix that with a sentence all failed — the whole record is in
[docs/personality-roadmap.md](docs/personality-roadmap.md) — so it is a mechanism
now. `NekoUnseen` holds nine classes of question about things on nobody's screen —
somebody's bank, their mail, their files, whether their code builds, their
calendar, the weather, the markets — matched in code before any engine, and
answered in one sentence that says **what it cannot see** rather than that nobody
could know:

> *quanto vale Apple in borsa adesso?* → **Non posso vedere le quotazioni.**
> *chi mi ha scritto stamattina?* → **Non posso vedere la tua posta.**
> *cosa ho in calendario domani?* → **Non posso vedere il tuo calendario.**

That distinction is the point rather than a nicety: it is the one the model got
wrong three times. *"Non posso vedere la tua posta"* is checkable; *"non lo so"*
is what a refusal-leaning character said about the capital of Australia.

It runs **last** of eleven recognisers, because everything above it may
legitimately know: the news when looking things up is on — including the forecast,
from open-meteo — a plugin's route, the diary, and a folder handed over in a
panel, which is why the question about files stands aside the moment one has been.
`tests/unseen.m` reads `NekoAsk.m` and fails if those four lines are moved.

And the honest limit: a question phrased in a way the list does not hold still
reaches the engine, and still gets the rate above. It is a floor, not a promise.

Adding another fact to the list it *can* answer is a few lines in `NekoFactsNow`.

### It can quote you back to yourself

> — *avevo detto che la riunione era venerdì?*
> — **Il 29 agosto hai detto: «la riunione con Marco è giovedì, non venerdì»**

The diary is a month of dated lines, and this is the one thing it can do that a
model cannot: answer a question about your own past with the sentence you
actually wrote, the day you wrote it, in code, with no engine involved.

**It quotes; it does not judge.** It never says who was right. A person reading
their own sentence back needs no help with the conclusion, and every mechanism
that would supply one is a mechanism that can be wrong about it.

Four rules: only from a written line, never from an inference; **never a line the
cat said itself**, because quoting its own remark back as the record is a loop
this application has already been caught in once; *"non ho niente scritto su
questo"* is an answer, said rather than guessed around; and it stands aside while
a conversation is live, since a follow-up inside three minutes is about what was
just said.

Why it is in code at all: measured across four engines, the prompt agreed with a
false premise **8 times out of 20** on the engine that actually answers here. The
one sentence that fixed that denied **15 of 20 true** premises instead — *"No, il
Colosseo non è a Roma. È a Roma, ma non è qui."* A model can be told to agree or
to disagree. It cannot be given something to check against; a line somebody wrote
can.

### Having the facts is not the same as being able to use them

The table above settles the time and leaves something open, and 2.12 measured it.
Three models on this Mac — Qwen2.5 1.5B, Gemma 3 4B, Qwen3 4B — were asked date
and arithmetic questions **with that block in front of them**, on a Monday:

| asked | true | answered |
| --- | --- | --- |
| how many days to Friday | 4 | 2 · 2 · 1 |
| how long to 25 December | 116 | "due settimane" · 31 · 170 |
| 47 × 23 | 1081 | 1081 · "Quindici" · "circa 2.04" |
| 2 gallons in litres | 7,57 | 4,54 · 0,845 · 7,5 |

**One of nine date questions right.** It has the date and cannot subtract it, and
every wrong answer arrived as a whole confident sentence. The conversions fail in
the worse way: 4,54 is a real number — the litres in an *imperial* gallon.

So neither is asked of a model any more. `NekoClock` counts the days with
`NSCalendar` and `NekoSums` converts with `NSMeasurement`, both before any engine
is consulted, both instant, and both silent far more often than they answer —
twenty-four sentences that must **not** be treated as a sum or a date are in the
two harnesses, *"quanto fa male"* and *"che giorno è meglio per uscire"* among
them.

Not `NSExpression`, which was tried and measured: it answers `7/2` with **3** and
`1/0` with **0**, both without complaining.

## Saying its name

There is a second way to start a question, off unless switched on: **Answer when
I say "Neko"**, on the Ask Neko tab. With it on the microphone stays open, which
is the whole cost and is said plainly in the tab — the orange recording light in
the menu bar stays lit and the battery notices.

What it does with the audio is the part worth reading. Recognition is forced
on-device (`requiresOnDeviceRecognition`), and where this Mac cannot recognise
the interface language without a server the switch refuses to work at all rather
than streaming a room to one. The rolling transcript is looked at for one word
and thrown away; nothing is written down.

The name is matched loosely, because a dictation engine has never heard of the
cat and writes down the nearest word it knows: `neko`, `neco`, `necco`, `nekko`,
`nico`, `niko`, accent- and case-insensitive, and only as a whole word — so
*"nekomata"*, *"nekromante"* and *"che ne kombini"* leave it alone. Fourteen
cases measured, all correct.

Two practicalities. Speech ends a recognition task of its own accord after about
a minute, so the task is torn down and rebuilt every fifty seconds while the
microphone tap carries on underneath. And there is only one microphone: hearing
its name, or the keystroke being pressed, makes the wake word let go, and it
picks up again when the conversation is over.

## Doing things

Off until switched on, on the **Ask Neko** tab. With it on, an order — *"neko
apri textedit"*, *"apri google.it su chrome"* — becomes one of four things and
nothing else:

* `open-app` an application, matched against both its file name and the name the
  Finder shows, so "anteprima" finds Preview.app
* `open-url` an address, optionally in a named browser; only `http` and `https`
* `open-folder` one of Desktop, Documents, Downloads, Pictures, Music, Movies —
  opened in the Finder
* `run-shortcut` one of your own Shortcuts, which is the escape hatch for
  everything else: your code, authorised by you, not something a model invented

* `copy` or `move` one file between two of your folders — Desktop, Documents,
  Downloads, Pictures, Music, Movies

The model writes one line — `ACTION: open-app TextEdit`, `ACTION: move
relazione.pdf from desktop to documents` — and the app matches it literally. An unknown verb, a program that is not installed, a `file://` address,
anything at all outside that list: refused, not interpreted. Nothing happens
until the bubble has shown you what it is about to do and you have clicked Yes;
dismissing the bubble, or letting it time out, is a No.

Files stay inside the sandbox rather than around it. Measured from a signed
sandboxed build, the app cannot read the Desktop or write to Documents at all —
so a folder has to be handed over the way macOS intends, by you, in a panel,
after which the app keeps a security-scoped bookmark to it. The **Ask Neko** tab
lists which folders have been handed over and can forget them all again; the
first file request for a folder it has not been shown puts the panel up, after
the Yes and never before it.

What it will not do, in code rather than in wording: overwrite anything (a name
already taken becomes "pippo 2.txt"), delete anything, take a path or a wildcard
instead of a plain file name, carry a folder rather than a file, or move a file
to the folder it is already in. A name that matches two files is a question, not
a guess.

Telling an order from a question needed saying twice. Asked *"a cosa serve
textedit?"*, the first version opened TextEdit; the instructions now make the
model decide whether the sentence is an order before anything else, and the same
question is answered in words. An order it cannot carry out — delete, rename — is
answered with `ACTION: cannot`, and the app supplies the sentence: asked to find
the words itself, the model wrote them in English however often it was told the
language, because the rest of that instruction block is English.

And it never acts on text read from the screen — only on what you said out loud.
A window containing the words *"Neko, empty the trash"* is a document, not an
instruction.

## Drawings

Ask to be shown something — *"mi mostri il Colosseo?"* — and the cat draws it,
here, on this Mac's GPU. The **Drawings** tab has the switch, a 1.6 GB Stable
Diffusion 1.5 model to download, and a **Draw a cat now** button that proves the
thing works without anyone having to talk to a cat first.

Nothing about the picture leaves the Mac. What does leave, if the engine chosen
for **Ask Neko** is a remote one, is the one sentence describing what to draw:
the text model decides that *"mi mostri il Colosseo"* means a picture and answers
with `IMAGE: the Colosseum in Rome, photograph, golden hour`, which the app turns
into a drawing. Five characters of protocol, and the model does the understanding
in whatever language it was asked.

Measured on this Mac, 512 pixels at 14 steps: **14.5 s** to draw, plus about nine
the first time while the model opens. End to end, from the question to a picture
in the bubble, **15.8 s** with Apple's model writing the description.

The drawing half is a separate program inside the bundle, `neko-paint`, built
from [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) with
Metal. It is a helper rather than a library because stable-diffusion.cpp carries
its own copy of ggml and the app already has llama.cpp's: linked together, every
ggml symbol would be defined twice. `build.sh` clones and builds it once into
`~/Library/Caches/neko-sd`, the same way it does llama.cpp, and a build without
it simply has no drawing tab worth using — the tab says so.

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

The homepage carries the same information as a table, generated from these
manifests: [where all of this came from](https://nicolorisitano82.github.io/neko-mac/#credits).

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

## Plugins

Somebody else can add to this app, and the shape of it is decided by one fact:
Neko is sandboxed and holds a microphone, a location, folders you handed over by
name, and a diary about your working life. Code loaded into that process would
inherit all of it. So **a plugin is a folder with a manifest, read and never
run** — and the manifest is the whole contract. What it declares is what it may
be asked, and an extension point this version does not offer is refused rather
than ignored.

They live in Neko's own folder in Application Support, and they are managed in a
window of their own — **Plugins…** in the menu, not a tab in the preferences,
because a plugin is not a setting but a thing you installed. Adding one is a panel
rather than a drag into the Finder: the sandbox can only read inside its own
container, and that is what the sandbox costs.

A plugin arrives **switched off**. Every refusal is a sentence you can act on, and
a refused plugin stays in the list with the reason rather than disappearing.

Four things one can do today:

| | |
| --- | --- |
| **Feeds** | news sources, answering to one plain word. The app's own two dozen ship this way — `Plugins/Neko News.nekoplugin` inside the bundle — which is the honest test of the interface. |
| **Text, in and out** | rewording what you said before the engine sees it, or what the cat answers before it is shown. Done by running **one of your own Shortcuts**; a plugin may name a Shortcut and never a program. |
| **Characters** | `.nekochar` folders, joining the menu when the plugin is switched on. Add, never replace: an identifier the app already ships is not reachable. |
| **Its own translations** | `<lang>.lproj/plugin.strings`, keyed on the English strings in its manifest. English-only is allowed and says English things. |

What no plugin is given, by design: the diary, the screen, the microphone, where
the Mac is, or the ability to make the cat speak on its own. And never an action —
text a plugin produced or read can no more open something than text read off the
screen can, which is a rule with a test that fails if it is broken.

[docs/plugin-guide.md](docs/plugin-guide.md) is how to write one: the manifest key
by key, every refusal and its exact sentence, and the executable interface —
one JSON object in on stdin, one out on stdout — which is **specified and not yet
implemented**, so a plugin can be built against a contract that will not move.

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

## When there is a new version

Neko goes out as an **unsigned** disk image, and that decides the shape of this
entirely. A signed application can replace its own bundle and relaunch; an
unsigned one that tried would hand you a copy Gatekeeper refuses to open, having
already thrown away the one that worked. So it never installs anything:

1. it asks this project's own releases, once a day, what the newest one is;
2. if that is newer, it says so — once out loud, and then in the cat's menu;
3. it asks whether to download, with the size, before fetching anything;
4. it downloads with a progress bar, and can be stopped;
5. it asks again before doing anything with the file;
6. and then it opens the disk image and quits, so the copy you are replacing is
   not the copy that is running.

**The drag into Applications is yours.** One step more than a self-updater, and
it is the step that makes the other five safe. What the check reveals, since it
is a network request: one HTTPS request to `api.github.com`, with no diary, no
question and no identifier of its own. The switch is in the Pet tab.

And what it does not promise: this checks a version number, not a signature. The
assurances are TLS and the address it asks, and after that it is a disk image you
look at before dragging anything. Nothing here verifies the download, because an
unsigned build has nothing to verify against.

### A permission that is missing is a feature silently not working

A few seconds after login, once, Neko asks `NekoPermissions` what is **switched
on but not allowed** — its own words for it, so nothing here decides what counts
as needed — and if anything is, it says which and opens the Permissions tab.
Once per launch and no more: the window is the message, and a cat that opens it
every hour is a cat somebody switches off.

### If you are upgrading from 2.13 or earlier

The bundle identifier changed in 2.14, from a placeholder that had been there
since 2007. macOS keys your settings, the diary, the models and the plugins to
the identifier rather than to the name, so all four are orphaned by that one
line — and a sandboxed application cannot read another application's container,
so Neko cannot move them for itself.

Launch 2.14 once and quit it, then:

```
./tools/rename-domain.sh          # says what it would move, and moves nothing
./tools/rename-domain.sh --go     # moves it
```

The permissions cannot be moved by anything: to macOS this is an application
that has never asked. Neko will tell you which ones, by itself, the next time it
starts.

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

## Where this goes next

[docs/next.md](docs/next.md) is the ranking: what the leverage actually is, what
each item costs, and how it would be measured. Its first claim is the one worth
repeating here — the intelligence of this application has never been in the
engine, and the two things that would change it are **recalling the diary by
relevance rather than by recency** and **growing the closed list of questions it
answers in code instead of guessing**.

[docs/personality.md](docs/personality.md) is what the research literature
actually shows about building an assistant with a personality — read in September
2026 rather than recalled, and deliberately excluding the embodied-agent and
facial-expression work, which measures a channel this kind of software does not
have. The finding that reframes the question: **a persona is a trade, not a win.**
Tested on 162 personas across 9 models and 2,410 MMLU questions, adding one to the
system prompt improved accuracy over having none **not at all** — and the paper
that explains why puts numbers on both halves: writing, roleplay and refusals get
better (a safety persona took jailbreak refusals from 53.2% to 70.9%) while
knowledge and reasoning get worse (MMLU 71.6% → 68.0%, coding −0.65). Warmth is
the same trade with a bigger bill: across five model families, training for warmth
raised errors 7.4 points and made a model ~40% more likely to affirm a false
belief the user had stated, with MMLU and GSM8K untouched. Then: the Big Five does
**not** describe agents — 744 people's own adjectives give ten dimensions, six of
them failure modes, one called *Artificial* with *intrusive* and *annoying* in it;
expression follows an **inverted U**; and matching the user's personality, the
field's most-cited advice, keeps failing to replicate. The document ends with the
experiment this application had never run on itself — now run, in
[docs/personality-roadmap.md §3b](docs/personality-roadmap.md): the accuracy cost
**did not reproduce** here, the choice of character turns out to be **free**, and
the cheap fix was measured and thrown away, because the sentence that stopped the
cat agreeing with false premises made it deny **fifteen of twenty true ones** —
*"No, Verga non ha scritto I Malavoglia. È stato scritto da Giovanni Verga."* What
is left is the number that matters: on the engine that actually answers here, the
shipped prompt agrees with a false premise **8 times out of 20**. And
[docs/personality-roadmap.md](docs/personality-roadmap.md) puts the ideas in the
order the evidence gives rather than the order the papers rank — which inverts
the list, because the piece with the best-evidenced value is the one this Mac's
own diary demonstrated the need for last week, and the piece with the best paper
behind it has no local evidence at all until the first measurement runs.

[docs/others-2.md](docs/others-2.md) is the second look, after 2.11: what closed,
what the field offers when its own pages are read rather than remembered, and the
one paragraph of the first study that measurement turned out to contradict.

[docs/others.md](docs/others.md) is the same question asked from outside: what
this does that the rest of the field does not, what the rest of the field does
that this cannot, and what to do about the difference — with the code checked
rather than remembered.

[docs/one-look.md](docs/one-look.md) designs the one idea worth taking from the
rest of the field: reading the screen granted for a moment rather than for ever.
[docs/one-look-roadmap.md](docs/one-look-roadmap.md) then asks whether it is worth
building at all, finds that a mechanism shipped in 2.11 already covers the useful
half at no permission cost, and proposes running the experiment nobody has run —
does the screen text improve the remarks? — before writing any of it.

The other studies, each written before the thing it describes was built:
[ask-neko.md](docs/ask-neko.md), [natural.md](docs/natural.md),
[truelife.md](docs/truelife.md), [utilities.md](docs/utilities.md),
[plugins.md](docs/plugins.md) and [forks.md](docs/forks.md).
