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
