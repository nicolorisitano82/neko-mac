# Useful things: timers, appointments, and the rest

A study, in the same shape as the others: what the platform actually allows, what
it costs in permissions, and what the app should do about it. The measurements in
section 1 were taken on this Mac while writing it, and they decide most of the
design.

## 0. The rules this has to fit inside

Nothing here gets an exemption from what the app already promises:

1. **The app decides what a request is; the model does not.** This is the lesson
   of 2.1 and 2.2, twice measured: a 4B invented a headline when asked to read
   the news, and Apple's model answered `ACTION: cannot` to *"mi conviene fare
   una pausa?"*. Intent is recognised in code, before any engine is consulted.
2. **Every deed is read back and waits for a yes.** `NekoAction propose:` shows
   the sentence and performs on a click; a dismissed bubble is a no.
3. **Nothing acts on text it read.** Not from the screen, not from a feed, not
   from a plugin. Only on what the person said out loud or typed.
4. **A new permission has to earn itself.** Five entitlements today, each
   defensible in a sentence. A sixth needs to buy more than it costs.

## 1. What macOS already understands, measured

`NSDataDetector` parses dates out of ordinary sentences, and it does it in the
app's four languages without a model, without a network, and without a
permission. Run against fourteen phrases on this Mac (Wednesday 26 August, 22:53):

| said | understood |
| --- | --- |
| appuntamento **domani alle 15** | Thu 27 Aug 15:00 |
| riunione **venerdì alle 9:30** | Fri 28 Aug 09:30 |
| pranzo **il 3 settembre a mezzogiorno** | Thu 3 Sep 12:00 |
| chiamare Marco **lunedì mattina** | Mon 31 Aug 09:00 |
| meeting **tomorrow at 3pm** | Thu 27 Aug 15:00 |
| dentist **on 3 September at noon** | Thu 3 Sep 12:00 |
| svegliami **alle 7** | Wed 26 Aug 07:00 — *today, already past* |
| metti un timer di **10 minuti** | nothing |
| ricordamelo **fra 20 minuti** | nothing |
| set a timer for **10 minutes** | nothing |
| remind me **in 20 minutes** | nothing |
| quanto fa sette per otto | nothing — correctly |
| che tempo fa a Roma | nothing — correctly |

Three findings, and they shape everything below.

**Absolute dates are free.** "Domani alle 15" and "venerdì alle 9:30" arrive as
`NSDate`s, with the matched range so the rest of the sentence can become the
title. Nothing needs to be asked of a model, which means nothing can be
hallucinated: the failure mode of "add an appointment" done by prompt is an
appointment on the wrong day, and this removes it entirely.

**Relative durations are not.** *"Fra dieci minuti"*, *"in 20 minutes"*, *"un'ora
e mezza"* — none of them. That is a small, closed, testable piece of parsing to
write: a number, a unit, in four languages, with the words for a half and a
quarter. Twenty lines and a table-driven test.

**Times in the past need a rule.** "Alle 7" at eleven at night resolves to seven
this morning. The rule is the obvious one and it must be stated: a bare time that
has passed means tomorrow. It is the single most likely way this feature gets
something wrong.

## 2. A timer

### What the platform offers

There is no public way to set the Clock app's timer. What exists:

- **The app's own timer.** An `NSTimer`, and when it fires the cat walks over and
  says so. No permission, no framework, and it already has a way to come over and
  speak — that is what 2.2 built.
- **A local notification** (`UserNotifications`). Needs authorization, and
  survives the app being in the background — but not being quit.
- **A Shortcut.** If the user has one that starts a system timer, the app can run
  it; `NekoShortcutProvider` already does exactly this for questions.

### What this app should do

**The cat is the timer.** It is the one utility on this list that the app is
already better at than the system: a bubble that follows you across Spaces, from
something that will come over and sit down to say it. No permission is asked, and
nothing is scheduled that outlives the app — which is honest, because a desktop
pet that is not running cannot remind you of anything.

The design, in the shape the code already has:

- A closed verb, `ACTION: timer <duration>`, recognised by the app from the
  question before any engine sees it, on the same mechanism as `NekoWeb
  wantedFor:`.
- The confirmation says the time it will land, not the duration: **"Ten minutes —
  I will tell you at 23:07."** A confirmation that repeats the words back proves
  nothing about whether they were understood.
- On firing: the cat turns toward the pointer, comes over, and says it. If the
  moment is bad — a full-screen window, a password field — it waits, because the
  seam machinery from 2.1 is already there and a timer somebody set is exactly the
  case where "wait two seconds for a gap" is right and "never speak" is wrong.
- One timer at a time, visible in the status-bar menu while it runs, cancellable
  from there. Two would need a list, and a list needs a window.
- **A notification only as a fallback**, and only if the person has already
  granted it for something else: if the screen is asleep or the app is not
  frontmost when the timer fires, the bubble is not enough. Asking for
  notification permission for this alone is not worth it.

### What it must not do

Reschedule itself, survive a quit, or fire while the Mac is asleep. If somebody
needs a timer that outlives the app, the honest answer is one sentence: *"Use the
Clock — I only exist while I am running."*

## 3. An appointment

### What the platform costs

Three routes, and they differ mostly in what they ask of the user:

| route | permission | what the user sees |
| --- | --- | --- |
| **EventKit, write-only** | `com.apple.security.personal-information.calendars` plus `NSCalendarsWriteOnlyAccessUsageDescription`; `requestWriteOnlyAccessToEvents` | one system prompt, once; the event simply appears |
| **An `.ics` file, opened** | none | Calendar opens with the event and its own Add button |
| **A Shortcut** | none of ours | whatever their Shortcut does |

Write-only is the right level for this app and did not exist before macOS 14: it
can create an event and cannot read the calendar. That distinction is worth
having in the sentence shown to the user — *"it can put something in your
calendar and cannot see what is in it"* — because it is true and it is unusual.

### What this app should do

**Ship the `.ics` route first, and the EventKit one behind a switch.**

The file route needs no permission at all, and the confirmation ends in the app
the appointment belongs to. It is slower by one click, and that click is in
Calendar where somebody can see the whole event before it exists. For a cat on a
desktop that is a better default than a permission prompt.

EventKit becomes worth it exactly when somebody says the extra click is annoying —
and then it is a switch, a usage description, and a sentence that says what
write-only means.

Either way the parsing is the same and it is section 1's: the date from
`NSDataDetector`, the title from what is left of the sentence after the matched
range, the duration from a following "per un'ora" or the default of one hour. The
confirmation reads it back in full:

> **Thursday 27 August, 15:00–16:00 — "riunione con Marco"** in *Calendar*. Shall
> I?

## 4. A reminder

Same shape as the appointment, and a smaller question: EventKit's reminders half
(`com.apple.security.personal-information.reminders`), or a Shortcut, or nothing.

The honest position: **a reminder with a time is a timer that outlives the app**,
and this app should not pretend to own that. Hand it to Reminders through a
Shortcut, or write it in the diary — which is the one thing here the app is
genuinely good at, and needs no permission because the diary is already its own.

## 5. The rest of the list, sorted by whether it is worth doing

| utility | how | verdict |
| --- | --- | --- |
| convert units, currency | `NSMeasurement` locally; a rates feed for money | **yes** — no permission, and the feed machinery exists |
| a note in a folder somebody handed over | `NekoFolderAccess`, already there | **yes** — one verb, no new permission |
| copy something to the clipboard | `NSPasteboard`, allowed with user intent | **yes**, and trivially confirmable |
| open an app, an address, a folder | already shipped in 2.0 | done |
| do not disturb, volume, brightness | no public API; a Shortcut can | **only through a Shortcut**, and say so |
| "tell me when the build finishes" | would need to watch another app | **no** — it is the screen-reading problem wearing a hat |
| send a message, an email | outward-facing, irreversible | **no**, and the confirmation rule is not enough for it |

## 6. What to build, in order

1. **The duration parser and the timer.** No permission, no framework, and it
   uses the walking-over machinery that already exists. Half a day, plus a
   table-driven test in four languages including the awkward ones — *un'ora e
   mezza*, *quarter of an hour*, *90 secondi*.
2. **The date parser and the `.ics` appointment.** `NSDataDetector` does the hard
   part; the work is the title, the default duration, the past-time rule, and the
   confirmation sentence. A day.
3. **Units and the clipboard**, which are two more verbs on the same rails.
4. **EventKit, behind a switch**, if and only if the extra click in Calendar turns
   out to annoy somebody.

## 7. What to measure

- **The past-time rule**: "alle 7" said at 23:00, at 06:00 and at 07:30, and the
  same in the other three languages. This is where a wrong answer is most likely
  and least visible.
- **Duration parsing**: a table of forty phrases, four languages, including the
  ones that should parse to nothing.
- **False positives**: the fourteen phrases in section 1 include two that must
  stay unrecognised, and the real test is a hundred ordinary questions producing
  no timer and no appointment. The failure that matters is not a missed timer; it
  is an appointment nobody asked for.
- **The confirmation**: that every path shows a sentence containing the resolved
  time, and that dismissing it does nothing — the same test `tests/screen.m`
  already runs for the existing verbs.

## 8. Where this meets the plugin work

Everything in section 5's "yes" column is a verb, a bit of parsing and a
confirmation. That is precisely the shape [plugins.md](plugins.md) describes for
`Extends.Verbs` and `Extends.Routes` — so the question worth asking before
building any of it is whether the timer should be the first plugin rather than the
next built-in.

The argument for built-in: the timer needs the cat to walk over and speak, which
no plugin may do. The argument for plugin: units, clipboard and notes need nothing
the app has, and if the plugin interface cannot express them it is not an
interface yet.
