# Neko beside the others, a second look

Written after 2.11. The first one is [others.md](others.md), from after 2.10, and
this is not a replacement for it: it is what changed, what was wrong in it, and
what the field looks like read again rather than remembered.

Same rule as before. Every claim about this application was checked in the source
or measured on this Mac; every claim about somebody else's was read from theirs.

## 0. Three of the seven are closed

| the last study said | now |
| --- | --- |
| nothing on this Mac can invoke Neko | **closed** — a Services entry and `neko://ask`; App Intents measured as unbuildable without Xcode |
| no calendar | **closed** — the `.ics` route, with the past-time rule |
| the voice is whatever the system picked | **still true, and the advice was wrong** — see §3 |
| a conversation is one turn long | still: `NekoThreadLife` is 180 seconds |
| six modules no harness names | still six: `NekoWakeWord`, `NekoListener`, `NekoHotKey`, `NekoPainter`, `NekoKeychain`, `NekoPhrase` |
| Focus and Do Not Disturb called impossible | still unmeasured |
| `NekoController` is doing too much | worse: 2,337 lines, 118 methods |

The application is 20,569 lines with 7,014 lines of harness across 34 of them.

## 1. What the field actually offers, read rather than recalled

**Raycast AI** is the serious Mac layer, and reading its own feature page is
sobering in one direction and reassuring in another. It attaches screenshots, PDFs
and CSVs; it has extensions for Calendar, Slack, Linear, Finder, Things, Jira; it
will block calendar time, move files to the trash, set a Slack status, and run
multi-application workflows; it takes your own OpenAI or Anthropic key and it
speaks to Ollama for a local model. What it has **no** notion of is when to speak:
every feature is user-triggered, and there is no proactivity or scheduling
anywhere in it.

**The pet genre has grown up, and mostly in one direction: the voice.** The
Convai desktop pet does real-time WebRTC voice conversation with per-character
voices and a whisper mode, and needs a Convai API key to do anything at all, with
long-term memory behind a paid tier. `nucket/NekoAI` — the closest rebuild of this
same idea — keeps "user facts extracted via pattern matching" in SQLite and still
has its plugin API on a roadmap. The 2026 round-ups of the genre agree on what is
now table stakes: long-term memory, a voice worth listening to, and screen vision.

**And one of them has a better idea than anything here.** See §4.

## 2. Where this is ahead, still, and effort would be wasted

- **Knowing when not to speak.** Raycast, the most capable thing on this list, has
  nothing at all here. The pets that do speak unprompted do it on a timer or on
  idleness. This application has breakpoints from the interruption literature,
  seams, pink-noise pacing, a rate rule, and since 2.10 the microphone, the lock
  and the sleeping display.
- **Nothing it reads can become something the Mac does.** Everything else on this
  list is racing the other way — Raycast will move a file because a model said so.
  That is the crowded direction; this is the unusual one.
- **It works with no account and no key.** Two of the four engines never leave the
  Mac, and the diary is refused to the two that do.
- **Plugins that ship, with routes and verbs**, against a rival's roadmap.

## 3. The correction: the voice advice in the last study was wrong

[others.md §2.3](others.md) said the voice was the cheapest perceptual win in the
whole list, because *"macOS ships the better ones as downloads that many people
already have"*, and that picking the best installed voice was a dozen lines.

**Measured on this Mac: 180 voices installed, and not one of them enhanced or
premium in any of the four languages.**

| language | default | enhanced | premium |
| --- | --- | --- | --- |
| it-IT | 9 | 0 | 0 |
| en-US | 28 | 0 | 0 |
| fr-FR | 9 | 0 | 0 |
| es-ES | 9 | 0 | 0 |

What Neko speaks with today is `Alice`, quality 1 — the compact one. Picking "the
best installed voice" would have picked exactly what it already uses, and the
dozen lines would have changed nothing audible. The assumption in that paragraph
was doing all the work.

So the recommendation changes shape rather than going away, and it is now two
things and in this order:

1. **Say that the better voices exist**, in the Voice preferences, with the path
   to get them — System Settings → Accessibility → Spoken Content → System Voice →
   Manage Voices. An application whose character is its voice should not sound
   compact by default and say nothing about why.
2. **Then** pick the best installed one, which is a dozen lines and becomes worth
   something the moment somebody follows that sentence.

The competitors' answer to the same problem is a paid API and a WebRTC session,
which is a different application than this one.

## 4. The one idea worth taking from somebody else

The Convai pet grants screen vision with **a timed permission**: a countdown badge,
auto-revoke, and a one-shot *"take a look"* — and it says frames are never stored.

That is a better *shape* than the one here for the same capability. This
application's screen reading is `NekoReadTextKey`: a switch, on or off, standing
until somebody remembers to turn it off. Everything else in this application asks
per use — a folder is handed over in a panel, a deed is read back and waits, a
verb re-checks its plugin at the moment of doing — and the screen, which is the
most sensitive thing it can touch, is the one place with a standing grant.

**A one-shot "have a look at this" is more in character than the switch is**, and
it would let somebody use the feature who will never turn the switch on. It is
also the smaller promise: the sentence in the preferences stops being *"it can read
the text you are working on"* and becomes *"it reads it when you ask, once".*

That is the recommendation of this study, and it is designed in
[one-look.md](one-look.md) — including the thing the design found that this
section had missed: the standing switch does not grant *a read*. What it unlocks
is appended to the desktop summary, and the summary is what the **advisor** reads
— so it grants a read on the advisor's own schedule, for as long as it is on, and
with a remote engine chosen that text follows the engine.

## 5. What is still missing, ranked, after that

1. **The one-shot look**, above.
2. **A conversation two or three turns deep.** Still 180 seconds and one turn. The
   last study said to find out from the diary how often a third turn is attempted
   before changing anything; that measurement has still not been made, and it is an
   afternoon.
3. **A notification when the timer lands and nobody is there.** 2.10 taught the
   timer to wait for a locked screen, for an hour. A local notification is the
   honest fallback for the hour after that, and `utilities.md` said so before any
   of this was built: only if the person has already granted it for something else.
4. **`NekoController`.** 2,337 lines and 118 methods, and now the biggest thing in
   the project by a factor of two. The pattern that has worked five times — take
   one coherent job out, with a header comment saying why it exists — has not been
   applied to it once.
5. **The hot key has no harness**, and it is the application's only front door.

## 6. What not to do, unchanged and now better evidenced

- **Screen vision as a standing capability.** Everyone else is adding it; the whole
  argument of this application is on the other side of that line.
- **An account, a key, or a tier.** The pet genre's memory is now behind paid
  plans. This one's is a text file somebody can open.
- **A model that decides what a question is.** Raycast can afford it because a
  person triggered every request. This one speaks unprompted, which is exactly the
  case where a wrong guess is not a wrong answer but an interruption.

---

*Read for this: [Raycast AI](https://www.raycast.com/core-features/ai);
[convai-desktop-pet](https://github.com/AkshitIreddy/convai-desktop-pet);
[nucket/NekoAI](https://github.com/nucket/NekoAI); and the 2026 round-ups of the
desktop-companion genre, which agree on memory, voice and screen vision as the
three things it now takes for granted.*
