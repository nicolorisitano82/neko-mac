# Neko beside the others

Written after 2.10, from the question *"cosa manca per migliorare ancora neko?"* —
half by reading this code and half by looking at what else exists. Every claim
about this application was checked in the source; every claim about somebody
else's was read from theirs. Where something is a guess it says so.

## 0. The shape of what is here

| | |
| --- | --- |
| source | 19,650 lines of Objective-C, MRR, plus one Swift file and one C++ shim |
| tests | 6,515 lines in 31 harnesses |
| documents | 7,056 lines, most of them written before the thing they describe |
| entitlements | seven, each defensible in a sentence |

The largest files are `NekoController.m` (2,325 lines, 118 methods, 53 instance
variables) and `NekoAsk.m` (1,460). That first number is the one to keep an eye
on; see §4.

## 1. Where this is genuinely ahead, and effort would be wasted

Worth stating first, because it is the half a survey usually gets wrong.

**Knowing when not to speak.** The 2025 CHI study on proactive programming
assistants found the persistent-suggestion condition "distracting" and "annoying",
with a participant preferring the non-proactive assistant *because it did not
interrupt*. That is the industry's open wound, and it is the thing this
application has spent three releases on: breakpoints from Iqbal & Bailey, seams,
pink-noise pacing, the rate rule, and since 2.10 the microphone, the lock and the
sleeping display. Nothing on the market that I could find reasons about
interruption cost at all, let alone from the literature.

**Memory that is recalled rather than merely kept.** Persistent memory is the
feature every assistant list now leads with, and what they mean is *stored*.
Recalling by what a question is about — and staying silent when nothing bears on
it, which is the half that matters — is rarer, and here it is 311 ms of lemmas
with nothing on disk beside a diary anybody can open in TextEdit and delete a line
from.

**The closest thing in the same genre is behind.** `nucket/NekoAI` is the modern
rebuild of exactly this idea — Tauri and Rust, sprite that follows the cursor,
five engines. Its memory is "user facts extracted via pattern matching" in
SQLite, its plugin API is on the roadmap for v1.0, and on Wayland it wants the
user in the `input` group. This has plugins, verbs, routes, four languages, and a
rule that says what a plugin may never be given.

**Running the model locally is no longer unusual** — Ollama passed 100k stars and
LM Studio is a one-click install — so the local engine is on-trend rather than
ahead. The unusual part is not that it can run locally; it is that the diary is
*refused* to a remote engine.

## 2. What is missing, ranked

### 1. Nothing on this Mac can invoke Neko

**Checked:** no App Intents, no Shortcuts action, no URL scheme, no Services
menu entry, no `NSUserActivity`, no Spotlight item. Zero occurrences of any of
them in the source.

The asymmetry is stark once you see it. Neko can **run the user's Shortcuts** —
that is how the verbs work — and nothing in the operating system can run Neko. It
has one door, its own hotkey, and it is the only application on the Mac that
cannot be reached by the mechanisms every other one is reached by.

App Intents is the framework, it is Swift-only, and **this project already links
Swift** for `NekoAppleModel.swift`, so the shim exists. An `AskNekoIntent` with a
string parameter would put the cat in Spotlight, in Shortcuts, on the Action
button, and in Siri, for no new permission and no new promise.

**Cost:** small. **Risk:** the one to think about is that an intent is a door
somebody else can call, so what it may do has to be the same closed list the
hotkey has — a question in, an answer out, no verbs and no actions.

### 2. A calendar and a reminder

[utilities.md](utilities.md) studied this in detail, ranked the `.ics` route first
because it needs **no permission at all**, and it was never built. Every assistant
on every list does this. `NSDataDetector` already parses *"domani alle 15"* in all
four languages for nothing — measured, in that document — so the work is the
title, the default duration, the past-time rule, and the confirmation sentence.

The reminder half is the same study's honest answer: a reminder with a time is a
timer that outlives the application, and this application should hand that to
Reminders through a Shortcut rather than pretend to own it.

**Cost:** a day. **Risk:** the failure that matters is an appointment nobody asked
for, and §7 of that document already says how to measure it.

### 3. The voice is whatever the system happened to pick — *and the advice below was wrong*

> Corrected in [others-2.md §3](others-2.md) after 2.11. This section assumed that
> "macOS ships the better ones as downloads that many people already have".
> Measured: **180 voices installed on this Mac and not one of them enhanced or
> premium**, in any of the four languages. Picking the best installed voice would
> have picked the one it already uses. The assumption was doing all the work.


**Checked:** `-speak:` builds an `AVSpeechUtterance`, sets a pitch multiplier of
1.25 — *"a cat, not a newsreader"* — and speaks it. **No voice is ever chosen.**
`AVSpeechSynthesisVoice` exposes `quality` — default, enhanced, premium — and
macOS ships the better ones as downloads that many people already have.

This is the cheapest perceptual win available. The voice *is* the character, in
the most literal sense, and picking the best installed voice for the language, once,
is a dozen lines. It costs nothing, needs nothing, and changes how the whole thing
feels more than any answer quality would.

**What to measure:** which voices are actually installed on a normal Mac, per
language, and whether the enhanced ones are present without the user having gone
looking. If the good voices are usually absent, the honest move is a line in the
preferences saying where to get them rather than silently sounding worse.

### 4. A conversation is one turn long

**Checked:** `threadForPrompt` carries the **last question and the last answer**,
and only for `NekoThreadLife` = 180 seconds. Ask a follow-up to a follow-up and
the first one is gone.

Whether that is a defect or the character is a real question, not a rhetorical
one. A cat with a three-minute memory of a conversation is defensible and even
charming; it is also the single most common complaint about assistants, which is
having to re-explain. The measured cost of widening it is prompt budget, and this
application knows what a long prompt does to a small model.

**What to measure before changing anything:** how often a third turn actually
happens, from the diary's own record of questions. If it is rare, this is
character. If it is common, it is a defect.

### 5. Six modules no harness names

`NekoWakeWord` (345 lines), `NekoListener` (244), `NekoHotKey` (187),
`NekoPainter` (167), `NekoKeychain` (46), `NekoPhrase` (36).

Two of those are honest: the wake word and the listener need a microphone and a
person, and the suite says so elsewhere rather than pretending. `NekoPhrase` is
exercised through the verbs and the routes. **The hot key and the painter are
testable and untested** — and the hot key is the application's only front door,
which makes it an odd thing to have no check on.

### 6. Focus and Do Not Disturb, which the documents call impossible

`NekoDesktop.h` says macOS keeps that state where no sandboxed application can
read it. That was true when it was written and it is worth **one measurement**
rather than a standing assumption: `INFocusStatusCenter` exists, with the
Communications Notifications entitlement, and the entitlement is one the user
grants. If it works inside the sandbox it is the best "do not speak" signal there
is, better than the three added in 2.10 because it is what the person actually
asked for.

If it does not work, the sentence in that header should say *measured on this
date* rather than *cannot*.

### 7. `NekoController` is doing too much

2,325 lines, 118 methods, 53 instance variables: the status item, the menu, the
character list, every preference, the permissions, the folder menu, the timer
item, the settings notifications. It is where the next bug will be, and it is the
one file in this project that a newcomer could not read in an afternoon.

Not urgent, and not to be done as a rewrite. The pattern that has worked here
already — `NekoPlugins`, `NekoRecall`, `NekoWhen`, `NekoStream` — is to take one
coherent job out at a time, with its own header comment explaining why it exists.
The preferences window is the obvious first tenant.

## 3. What not to do, with reasons

- **A second cat, a marketplace, or a plugin store.** Named in
  [plugins-management.md](plugins-management.md) and still right: a plugin arrives
  because somebody put it there.
- **An agent that acts across applications on its own.** This is where most of the
  market is heading and it is precisely what this application's whole design
  refuses. The rule — *nothing it reads becomes something the Mac does* — is the
  reason it can be this close to somebody's day. Trading it for parity would be
  trading the only unusual thing here for the most crowded thing there.
- **Reading the screen by default.** It is a switch, it is off, and the paragraph
  next to it is honest. Leave it there.
- **A longer prompt.** Measured as harmful on small models, repeatedly.

## 4. If it were one thing

**The voice.** Not because it is the most important, but because it is the largest
change in how the thing feels per line of code in the whole list, and because the
character is the product. Then the App Intent, which is what makes the cat
reachable from the rest of the Mac; then the calendar, which is the utility
everybody expects and the one study in this repository that was written and never
acted on.

---

*Read for this: [nucket/NekoAI](https://github.com/nucket/NekoAI);
[Assistance or Disruption? Proactive AI Programming Support, CHI 2025](https://arxiv.org/html/2502.18658v3);
[Apple's App Intents](https://developer.apple.com/documentation/appintents);
and the 2026 round-ups of local-first assistants — [Vellum](https://www.vellum.ai/blog/best-local-ai-assistants),
[Elephas](https://elephas.app/resources/best-local-ai-assistant-for-mac) — which are
mostly listicles but agree on what the field takes for granted.*
