# The router branch: what is being built, and what is deliberately not

Opened from [many.md](many.md), which read the literature on using several models
together and ended somewhere narrower than it started. This is the working plan
for what survives that reading, so that the branch does not quietly drift into
building the thing the study said not to build.

## The thing being built

**A measurement, not a router.** Run the two paths this application already has
over the diary's real questions, and report where they disagree.

- the **cheap path** — the twelve recognisers of `askAfterPlugins:`, which answer
  in code;
- the **expensive path** — whichever engine is configured;
- the **seed set** — the diary, which is a month of one person's real questions
  rather than a corpus written for the purpose.

This is the training-free half of BoundaryRouter (arXiv 2605.07180) and nothing
else. Its output is not a policy: it is **a list of questions the chain is
losing**, which is the raw material a person turns into phrases. `NekoUnseen`,
`NekoClock` and `NekoSums` were all built exactly that way, from a list of things
that went wrong.

## Why not the router itself

Three reasons, in the order they were found, and all three are numbers rather
than opinions.

1. **There is no signal.** `NekoRate` keeps daily aggregates and every verdict is
   gated by `if(!saidUnasked) return;` — it judges the cat's own unasked remarks,
   never an answer to a question. Nothing records whether an answer was good.
2. **The obvious substitute is confounded.** The literature's implicit signal is
   the retrial (arXiv 2602.02061). Measured here: 23 of 33 consecutive question
   pairs are under a minute apart, median gap one minute — and this application
   already established that questions in quick succession are *conversations*,
   which is why the thread carries three turns. From timing alone a retrial and a
   follow-up are the same event.
3. **And t = 42.** Twelve days of diary, forty-two questions. Every guarantee in
   that literature is asymptotic; the exploration half of a bandit would spend
   real questions on somebody's real Mac deliberately taking the worse path.

## What this branch may not do

Written down because each of these is a tempting next step and each is wrong.

- **It may not change which engine a question goes to.** That is a privacy
  decision somebody made in the preferences, not a quality decision, and two of
  the five engines never leave the Mac. No measurement licenses moving it.
- **It may not ask several models and pick.** First words land in 0.40 s; asking
  three models triples the wait for a cat that answers while you are still
  looking at it.
- **It may not send the diary anywhere.** The seed set is somebody's own writing.
  The comparison runs against whatever engine is already configured, under the
  same rule as every other question, and the report stays on the Mac.
- **It may not learn anything at runtime.** No weights, no policy, no exploration.
  If a boundary moves it is because a person read the report and wrote a phrase.

## How it will be judged

1. **Does it find anything?** A run over the diary that reports zero disagreements
   worth acting on means the chain is already where it should be, and the branch
   closes having proved that. That is a result, not a failure.
2. **Does what it finds survive a person reading it?** The output is a list for
   somebody to judge. A disagreement where the engine's answer is worse is not a
   gap in the chain.
3. **Does it beat writing the list by hand?** The alternative is somebody reading
   their own diary for ten minutes. If the measurement does not beat that, it is
   not worth the code.

---

*Grounding: [many.md](many.md) §2 for BoundaryRouter's numbers, §3 for the
ceiling and the routing-collapse failure, §7 for the signal and the forty-two.*

---

## Step one, run — and it found the thing that stops step one

`tests/reach.m`. Every recogniser in `askAfterPlugins:` is split in two — a pure
`+wantedFor:` / `+matchFor:` that claims the question, and a separate `+act:` /
`+make:` / `+fetch:` that does the thing — so the whole chain can be asked in
order **without a timer starting, an event being written, or Spotify being spoken
to.** The seam was already there; the measurement needed no change to `src/`.

Run over the diary, on a copy, nothing written:

    (the engine)         34
    NekoWeb               6
    NekoSums              1
    NekoTimer             1

    answered in code, before any engine     8 of 42 (19%)
    through to the engine                   34
    rungs a setting made unreachable        NekoPluginRoutes, NekoPluginVerbs

**That 19% is a floor and not a reach, twice over**, and the second reason is the
one that matters.

### a. Two rungs could not run

`+anythingListens` needs plugins the harness does not load. The list of
questions that went through plainly contains *"Metti Apple Music"*, *"Alza
volume"*, *"Metti Taylor Swift"* — `NekoPluginVerbs` would have taken all three.
Environmental, and fixable.

### b. The diary is not a record of the questions

Not inferred from how the lines look — read in the code. `-noteHeard:` calls
`-append:`, which calls `-tidy:`, which calls **`-squeeze:`**, and `squeeze:`
drops filler words on purpose. Its own comment says so:

> "The diary is notes, not a transcript... about a third less of it to read back
> tomorrow — which matters because a small model reads the whole thing before it
> answers anything."

So what is on disk is *"tempo fa"*, *"giorno oggi"*, *"sei"* — not *"che tempo
fa?"*, *"che giorno è oggi?"*, *"dove sei?"*. **The recognisers match phrases, and
the phrases have had exactly the function words removed that several of them key
on.** Replaying the diary through the chain does not measure the chain on real
questions; it measures the chain on a lossy summary of them.

### What that means for this branch

**The seed set the plan assumed does not exist.** The corpus of questions as
somebody actually asked them is nowhere on disk — `lastQuestion` holds one, in
memory, 300 characters, never written. The diary is the only record and it is
squeezed by design, for a reason that is good and that nobody should undo lightly:
every extra word is read back by a small model before it answers anything.

Three ways forward, and the cheap one is not the obvious one:

1. **Keep the raw question too.** Small change, and it costs the diary's own
   promise — more of somebody's words kept on disk, for a benefit that is
   currently hypothetical. Not without deciding that trade deliberately.
2. **Measure the chain against questions phrased as people phrase them**, from
   somewhere other than the diary. But a corpus written for the purpose proves
   nothing, which is the whole reason the diary was chosen.
3. **Fix (a) and read the list as it is.** Load the plugins, re-run, and let a
   person read the thirty-four. Squeezed lines are still recognisable to a human
   as the questions they came from, and the output was always meant to be a list
   for somebody to judge rather than a number. **This is the next step**, and it
   costs an afternoon.

The finding stands on its own either way: **step one as written cannot be done,
and it took one afternoon rather than one week to establish.**

---

## Step two: plugins loaded, and the list read

`NekoPlugins` had no directory override — `NekoMemory` and `NekoModelStore` both
have one, for exactly this reason — so a test binary run out of the bundle
resolved outside the sandboxed container and found nothing. Added, and both
plugin rungs run now.

    (the engine)        28          answered in code    14 of 42 (33%)
    NekoWeb              6          through to engine   28
    NekoPluginVerbs      5          plugins loaded       5
    NekoSums             1
    NekoTimer            1
    NekoPluginRoutes     1

Nineteen per cent became **thirty-three**, and `NekoPluginVerbs` alone took five —
*"Metti Apple Music"*, *"Alza volume"*, *"Metti Taylor Swift"*. That half of the
floor is now measured rather than guessed at.

### Reading the twenty-eight

Almost every remaining line is a question the chain **has a rung for**: *"tempo
fa"*, *"giorno oggi"*, *"ore"*, *"sei"*, *"quotazione oggi borsa Apple"*. The
suspicion writes itself — the chain would have caught them as they were spoken.

Guessing at what somebody originally said would prove nothing, so the harness
does not guess. It takes phrasings **verified to be caught as spoken**, puts each
through `-[NekoMemory squeeze:]` — the very method the diary writes with — and
asks the same chain again:

| as spoken | after the diary |
| --- | --- |
| *che giorno è oggi?* → `NekoClock` | *giorno oggi?* → the engine |
| *che ore sono?* → `NekoClock` | *ore* → the engine |
| *cosa è successo oggi nel mondo?* → `NekoWeb` | *cosa successo oggi mondo?* → the engine |
| *che tempo fa a Vicenza?* → `NekoWeb` | *tempo fa Vicenza?* → the engine |
| *dove sei?* → `NekoSelf` | unchanged |
| *quanto vale Apple in borsa adesso?* → `NekoUnseen` | unchanged |
| *puoi mettere un timer di 10 minuti?* → `NekoTimer` | unchanged |
| *quanti giorni mancano al 25 dicembre?* → `NekoClock` | unchanged |

    as spoken, the chain catches all of them     8 of 8
    as the diary keeps them, it catches          4 of 8
    so the diary alone loses                     4 of 8

**The diary loses half of them by itself.** Measured, not argued: the same
questions, the same chain, one method in between. So the twenty-eight are not a
list of gaps — they are mostly a list of things `squeeze:` broke, and the seed-set
plan is confirmed dead in the form it was written.

### But choosing that list found two gaps that are real

Neither has anything to do with the diary. Both fail **as spoken**:

    che tempo fa?                    → the engine
    che tempo fa oggi?               → the engine
    quanti giorni mancano a Natale?  → the engine
    che giorno era il 3 marzo 2026?  → the engine

1. **The weather is only recognised when a place is named.** *"che tempo fa a
   Vicenza?"* works; *"che tempo fa?"* — the phrasing people actually use — goes
   to the engine, which is precisely what `NekoWeb` exists to prevent. The diary
   has that bare question **twice**.
2. **The clock does duration arithmetic only** — how long until a date, how long
   since one. It does not answer *what day a date fell on*, and a holiday by name
   is not a date it can read.

**And the second of those was a published claim.** The site's Ask Neko section
said the chain handles *"How many days until Christmas, what day was the 3rd of
March"*, and **both examples are ones it does not answer**. Corrected on the page
to what it actually does, with the limit stated rather than implied.

That is the honest yield of two steps: the measurement the branch was opened for
is dead, and the by-catch is two real gaps and one false claim taken off a public
page — none of which anybody was looking for.
