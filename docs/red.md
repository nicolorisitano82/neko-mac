# The two checks that go red, and what is actually wrong with each

Written after 2.15.1 because both were reported to somebody as one thing and were
in fact the other. The characterisation below is measured; the one I gave first
was not, and it had the two of them **backwards**.

|  | what I said first | what six runs say |
| --- | --- | --- |
| `persona` | stable, not intermittent | **intermittent** — 3 of 3 passed on re-run |
| `timer` | intermittent | **not intermittent** — 6 of 6 failed |

The lesson is the one this project keeps relearning: a harness run twice is a
guess. Neither of these had been run more than twice when I described them.

---

## 1. `persona` — the engine answers with nothing

**Status: intermittent, cause outside this code, one product question inside it.**

The failing check wants two characters given the same question to give two
different answers, and it requires both to be non-empty:

```objc
ok(one != nil && two != nil && ![one isEqualToString:two],
    @"and they do not answer identically", nil);
```

What was seen on the run that failed:

```
wizard: Sì, la pausa ti conviene: sono le diciotto e trenta minuti di venerdì…
cat:    (nothing)
```

The wizard arm answered. The cat arm returned **nothing at all** — from Apple
Intelligence, on the identical question, differing only in the character
sentence. Three runs immediately afterwards all passed, with both arms answering
normally, so it is not a broken code path and it is not the persona.

**What to investigate, in order:**

1. **How often.** Twenty runs of that single pair, counting empties. Anything
   above a couple of per cent is worth knowing about, because it is not confined
   to the harness — the same provider answers real questions.
2. **Whether an empty answer is handled.** This is the half that is *this*
   project's problem rather than Apple's. If `NekoAppleProvider` can hand back
   nil or an empty string, the question is what the cat then does: an empty
   bubble, a bubble that never appears, or an honest sentence. Two of those three
   look exactly like the bug fixed in 2.15.1 — something happens, nothing is
   shown — and that one took a night of somebody's time to find.
3. **Then, and only then, the check.** If empties are real and handled, the
   harness should say so out loud rather than fail: this project has
   `notMeasured()` for exactly that, and a check that fails for the engine's
   mood teaches nobody anything.

**What not to do:** loosen the check to `one != nil` and move on. The check is
asking the right question.

---

## 2. `timer` — the harness is measuring the display, not the patience

**Status: fails every time, and the code is behaving as designed. The check is
the defect, plus one real question underneath it.**

Six consecutive runs, asked for a two-second timer:

| run | fired after |
| --- | --- |
| 1 | 30.2 s |
| 2 | 387.1 s |
| 3 | 30.2 s |
| 4 | 30.2 s |
| 5 | 30.1 s |
| 6 | 403.0 s |

Never the twelve seconds the check allows, and never anywhere near it. Two
clusters, and both have the same cause.

`NekoTimer` has two branches before it speaks, and only the second is what the
check has in mind:

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

`NekoTimerPatience` is 8 s, and `tests/timer.m` allows 12. But
`-whyNobodyIsThere` returns non-nil for three reasons, and the third is
**`CGDisplayIsAsleep`**. The suite runs unattended; the display sleeps; the timer
takes the *first* branch and waits for somebody to come back, which is exactly
what its comment says it should do.

- **The 30.2 s cluster** is the harness's own `while` loop giving up after 30 s
  with the timer still running.
- **The 387 s and 403 s** are longer than that loop can possibly run, which means
  the Mac itself slept mid-wait and the wall clock jumped. Same cause, one level
  up.

**What to do about the check:** stage the condition, the way `tests/flee.m`
already stages `+[NSEvent mouseLocation]` after that harness failed for the same
kind of reason — reading the real machine instead of a controlled one. Swizzle
`-[NekoDesktop nobodyIsThere]` to return NO for the duration, and the check then
measures `NekoTimerPatience`, which is what it is named after.

**And the real question underneath, which is not a test problem:**

> `-whyNobodyIsThere` treats *the display is asleep* the same as *the screen is
> locked* and *somebody else is logged in*. Those are not the same. A locked
> screen means somebody chose to step away. A sleeping display can mean somebody
> is sitting right there reading something on paper — and a timer they set
> themselves is the one thing in this application worth waking a display for.

`NekoTimer.m`'s own comment argues that a timer eight seconds late is fine and
twenty is not. An hour is neither, and nobody has decided whether it should be.
Measuring first: how often does a timer land while the display is asleep but
somebody is still there? That is answerable from the diary.

---

*Both of these are checks, not shipped defects. 2.15.1 went out with `persona`
red and that was said out loud in the release rather than quietly. Neither is a
reason to hold a build; both are a reason not to trust the suite's green until
they are settled, which is the whole cost of leaving a check red.*
