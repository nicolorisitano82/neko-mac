# The two checks that go red, and what is actually wrong with each

Written after 2.15.1 because both were reported to somebody as one thing and were
in fact the other. The characterisation below is measured; the one I gave first
was not, and it had the two of them **backwards**.

|  | what I said first | what six runs say |
| --- | --- | --- |
| `persona` | stable, not intermittent | **intermittent** — 3 of 3 passed on re-run, then 0 empty in 24. Settled below |
| `timer` | intermittent | **not intermittent** — 6 of 6 failed. Fixed below |

The lesson is the one this project keeps relearning: a harness run twice is a
guess. Neither of these had been run more than twice when I described them.

---

## 1. `persona` — the engine answers with nothing ✅ *settled after 2.15.1*

**Was: intermittent, cause outside this code. Now: measured, and the one thing
worth fixing was not the thing I expected.**

The three questions this section set, answered in order.

### How often — rarer than 1 in 24, and that is all 24 samples can say

`tests/empty.m` asks the same pair repeatedly and keeps **both** halves of the
completion, which the persona harness did not: its helper wrote
`said = [text retain]` and dropped the `NSError`, so from inside it *nothing* and
*an error* looked identical.

    answers asked for                    24
    came back empty                       0 of 24 (0%)
    two characters answered identically   0 of 12 rounds

Zero of twenty-four, against one empty seen earlier in the day. So it is rare —
and twenty-four samples put no useful ceiling on *how* rare, which is why the
harness prints a rate and refuses to pass or fail on it. It runs two pairs in the
suite to keep the path exercised, and the full dozen under `--slow`.

### Whether an empty answer is handled — yes, and this was the good news

Traced rather than assumed:

```objc
if([answer length] > 0)  [self answer:answer];
else                     [self failed:error];
```

`-failed:` says a sentence in character and sets `phase` back to idle. So an
empty answer produces something visible and strands nothing — it is **not**
another 2.15.1. The worry in the first draft of this document was reasonable and
turned out to be wrong, which is worth leaving on the page.

### But the reason was being thrown away, and that is the defect

`NekoAppleProvider` wraps whatever the framework said in the error:

```objc
completion(nil, [NSError errorWithDomain:NekoAskErrorDomain
                                    code:NekoAskErrorNoAnswer
                                userInfo:failure != nil
    ? [NSDictionary dictionaryWithObject:failure forKey:NSLocalizedDescriptionKey]
    : nil]);
```

and `-failed:` sends `NekoAskErrorNoAnswer` through `default: break`. That is
right for the *bubble* — what the cat says should be its own sentence, not a
framework's. But the framework's sentence was then dropped on the floor: **no
bubble to read it in, and no line in the log either.** An engine that answered
with nothing left nothing at all to diagnose, which is exactly the position this
section started from.

Fixed: `-failed:` now logs the reason whenever there is one and it is not what is
being said out loud. One line, and the next occurrence leaves evidence — which is
how the 2.15.1 bug was actually solved.

### And the check now makes one claim instead of two

It used to require, in a single `ok()`, that the engine answered *and* that two
characters answered differently. Only the second is about personas. They are
separated now, and when the engine gives nothing the harness says so with
`notMeasured()` rather than failing. The claim is exactly as strong as it was —
what changed is that it no longer goes red for the engine's mood.

**What was deliberately not done:** loosening the check to `one != nil`. It is
asking the right question.

---

## 2. `timer` — the harness was measuring the display, not the patience ✅ *fixed*

**Was: fails every time, and the code behaving as designed. The check was the
defect. Fixed, and the question underneath turned out to have an answer.**

Six consecutive runs, asked for a two-second timer: **30.2, 387.1, 30.2, 30.2,
30.1 and 403.0 seconds**. Never the twelve the check allows, and never near it.

`NekoTimer` has two branches before it speaks, and only the second is the one the
check had in mind:

```objc
if([[NekoDesktop sharedDesktop] nobodyIsThere]
   && -[landsAt timeIntervalSinceNow] < NekoTimerWaitsForYou) {
        [self scheduleAnotherLook];
        return;                       /* up to an hour */
}
if(![NekoAsk mayInterruptNow] && putOff * NekoTimerRetry < NekoTimerPatience) {
        putOff++;
        [self scheduleAnotherLook];   /* up to eight seconds */
        return;
}
```

`-whyNobodyIsThere` returns non-nil for three reasons and the third is
**`CGDisplayIsAsleep`**. The suite runs unattended, the display sleeps, and the
timer takes the *first* branch — exactly what its own comment says it should do.
The 30.2 s cluster is the harness's `while` loop giving up with the timer still
running; the 387 s and 403 s are longer than that loop can possibly run, which
means the Mac itself slept mid-wait.

**Fixed** by staging the condition, the way `tests/flee.m` stages
`+[NSEvent mouseLocation]` after failing for the same kind of reason — reading the
real machine instead of a controlled one. `-[NekoDesktop nobodyIsThere]` is
swizzled to NO, and the check now reads:

    ok    it goes off by itself, waiting for a decent moment   asked for 2 s, went off after 10.3 s
    ok    and never waits longer than its patience             10.3 s

Ten point three: two seconds of timer and eight of patience, which is
`NekoTimerPatience` exactly. That is the number the check was named after and had
never once measured.

**And the branch above it is pinned now too**, because nothing checked it at all —
which is how it came to be what the suite was accidentally measuring:

    ok    a timer does not go off into an empty room, it waits  still running 6 s after a 2 s timer

### The question underneath, which turned out to have an answer

This document previously argued that *the display is asleep* should not be
treated like *the screen is locked* — that somebody reading paper at their desk is
still there, and a timer they set is worth waking a display for.

**That argument does not survive one line of the code.** `NekoAskSpeakKey`
defaults to **NO**: unless somebody turned the voice on, a timer that lands
produces a **bubble and nothing else**, and a bubble on a sleeping display is not
a late timer — it is a timer that failed in silence and counted itself as said.
Which is precisely the failure the existing comment says it is avoiding.

So the current behaviour is right for the configuration almost everybody runs,
and the case for changing it narrows to one: **when the voice is on**, sound
reaches somebody whose display has slept, and waiting is then pure lateness.

That is a real but small improvement, and it carries the risk the design already
weighs — a display asleep usually means somebody left, and speaking into an empty
room consumes the timer. Nothing here measures how often a display sleeps with
somebody still in front of it, and nothing in the diary records it either. So it
stays open, deliberately, as a change with a known cost and an unknown benefit
rather than an obvious win.

---

*Both of these are checks, not shipped defects. 2.15.1 went out with `persona`
red and that was said out loud in the release rather than quietly. Neither is a
reason to hold a build; both are a reason not to trust the suite's green until
they are settled, which is the whole cost of leaving a check red.*
