# Where this goes next

Written after 2.8, from the question *"voglio continuare a rendere neko il più
utile possibile e il più intelligente possibile"*. It is a ranking rather than a
list: what the leverage is, what it costs, and how each one would be measured.

Two things were checked before any of it was written down, because a plan built on
a guess about your own code is worth nothing:

- **`NekoFolderAccess` still opens its panel app-modally** (`runModal`,
  [`NekoFolderAccess.m`](../src/NekoFolderAccess.m)). That is the shape that made
  2.5's Add button appear to do nothing — an app-modal panel from an application
  with no Dock icon opens behind whatever somebody is looking at. There is an old
  *"does nothing"* report against the folder handover that was never closed.
- **The diary is recalled by recency, not by relevance.** `contextForPrompt`,
  `durableLines`, `standingLines`. There is nothing that answers *"what did I say
  about X"*.

## 0. What "more intelligent" cannot mean here

The measured history of this application says one thing, repeatedly: **the
intelligence is not in the engine.**

- A 4B asked to read the news invented a headline. A 1.5B repeated the question
  back.
- Apple's own model answered `ACTION: cannot` to *"mi conviene fare una pausa?"*.
- Every part that works well — the news, the weather, the verbs, the players — works
  because **the application recognises the intent in code**, before any engine is
  consulted, and the model only speaks afterwards.
- A longer prompt measurably makes a small model worse. The instruction budget
  exists for that reason.

So a bigger model and a longer prompt are not the road. The two things that are:
**knowing about the person**, and **never having to guess**.

## 1. Memory that recalls by relevance

**The biggest lever, and the one most in character.**

Today the diary reaches the prompt by recency. A question about something decided
three weeks ago does not find it, however well it was written down. Distillation
keeps the month from growing without bound, and that is not the same as recall.

What to build: an embedding per diary line, and a recall that returns *the lines
that bear on this question* instead of *the last N*. `NLEmbedding` is on the
machine already — on-device, no network, no permission, no download. The diary
never leaves the Mac, which is the rule that makes this feature allowed to exist at
all.

The distinction worth drawing at the same time, because it is what makes an
assistant feel like it knows somebody:

| kind | example | lives for |
| --- | --- | --- |
| a durable fact | *works on neko-mac; writes in Italian; hates being interrupted before coffee* | until it stops being true |
| an event of the day | *spent Thursday on the plugin panel* | thirty days, then distilled |

**How it is measured.** A staged diary with known content, twenty questions, and
the days that have to come back for each. Plus the negative half, which matters
more: questions that must recall **nothing**, so that every answer does not drag
somebody's whole month into the prompt.

**Cost**: a few days. **Risk**: low. Nothing here is sent anywhere, and if recall
finds nothing the behaviour is exactly today's.

## 2. The closed list of things it must never guess

The verbs, the news and the weather are all the same idea: the application answers
in code, and the model is not asked. Every entry added to that list removes a class
of confidently wrong answer.

What belongs on it, in order:

1. **A timer.** Studied in [utilities.md](utilities.md) and never built. It is the
   one utility on that list where this application is genuinely **better than the
   system**: a bubble that follows you across Spaces, from something that walks
   over and sits down to tell you. No permission, no framework, and the
   walking-over machinery is already there. The relative-duration parser is twenty
   lines and a table-driven test in four languages.
2. **Dates and times.** *"What day is it", "how long until Friday"* — `NSDataDetector`
   already parses the hard half, and a model asked the date will invent one.
3. **Arithmetic and conversions.** `NSMeasurement`, locally.

**How it is measured.** The tables already described in
[utilities.md §7](utilities.md#7-what-to-measure): the past-time rule, forty
duration phrases across four languages, and a hundred ordinary questions that must
produce **no** timer and **no** appointment. The failure that matters is not a
missed timer; it is a timer nobody asked for.

**Cost**: the timer is half a day. **Risk**: low, and it is the item somebody
notices the same afternoon.

## 3. Routes — the missing half of the plugin interface

A plugin can *be* things (feeds, characters, translations, a text filter) and, since
2.6, *do* things (verbs). It cannot **answer**.

A route is the mechanism `NekoWeb wantedFor:` already is, generalised: *when the
question is of this shape, fetch this, and hand it to the engine as somebody
else's words*. It multiplies what plugins are worth without giving them one new
power — the quoted text still cannot become an action, which is the rule
`tests/screen.m` fails on if it is ever broken.

It is harder than verbs and worth being honest about why: **a verb only decides
that a phrase was said. A route decides what a question is about.** That is the
judgement this application has always kept for itself, so the shape has to be
narrow — a closed pattern, not a plugin-supplied guess.

**Cost**: the largest item here. **Risk**: the design risk of the whole plugin
system in one slice.

## 4. Perceiving without reading

The rule stands and is not up for negotiation: **nothing read from the screen ever
becomes something the Mac does**, and remote engines never see the screen, the
diary or the reflections.

But there is signal that is not content: which application is frontmost, whether
the microphone or camera is in use, how long somebody has been still, the time of
day. `NekoDesktop` already uses some of it for the seams. More of it makes the
*timing* right — remarks that arrive in a gap rather than across a sentence — which
is the whole difference between an animal that seems attentive and one that seems
intrusive.

**Cost**: small. **Risk**: the temptation to creep from "which application" toward
"what is in it". The line is in the code and in `tests/screen.m`; it does not move.

## 5. Latency, which is felt as intelligence

The answer arrives all at once. Streaming it into the bubble as it comes changes
how clever the thing feels more than any change of model would, and it costs
nothing but plumbing. The pacing work of 2.1 and 2.2 already decided how fast it
may speak; this is about when it *starts*.

## What not to do

- **Longer prompts.** Measured as harmful on small models. The budget stays.
- **New permissions that have not earned themselves.** Six today, each defensible
  in one sentence.
- **A second cat.** Two would need a list, and a list needs a window.
- **Anything that lets a plugin, a feed or the screen decide what happens.** That
  is the one line this application has never crossed, and it is why the rest of it
  is allowed to be this close to somebody's day.

## The two open bugs, which come before any of it

1. **The folder handover panel** — section 0. Promised as *measured, then fixed*,
   twice, and still `runModal`.
2. **The plugins window is not covered by `tests/layout.m`**, which is the harness
   that opens every tab and checks every pair of controls. It was left out
   deliberately when the window was new; it is not new any more.
