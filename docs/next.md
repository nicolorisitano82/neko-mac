# Where this goes next

Written after 2.8, from the question *"voglio continuare a rendere neko il più
utile possibile e il più intelligente possibile"*. It is a ranking rather than a
list: what the leverage is, what it costs, and how each one would be measured.

Two things were checked before any of it was written down, because a plan built on
a guess about your own code is worth nothing:

- **`NekoFolderAccess` opens its panel app-modally** (`runModal`,
  [`NekoFolderAccess.m`](../src/NekoFolderAccess.m)) — which is the shape that made
  2.5's Add button appear to do nothing, so it was written down here as a bug.
  **It is not one.** Measured immediately afterwards, in the real bundle and on
  both paths — the method called directly, and somebody pressing Yes in the bubble
  — the panel comes up visible, key, on the active space, with the application
  frontmost. The `activateIgnoringOtherApps:` that precedes it is doing its job.
  What *was* broken is in the next line.
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

### The same argument, one floor down

That principle was written here from measurements on this Mac. It turns out to be
the same claim a 2026 paper from Peking University and DeepSeek-AI makes about the
inside of a model — *Conditional Memory via Scalable Lookup* (arXiv 2601.07372),
whose module is confusingly also called Engram and is unrelated to the Go tool of
that name.

Its argument: language modelling is **two different jobs** — compositional
reasoning, which wants deep computation, and knowledge retrieval, which is static
and stereotyped — and a plain transformer is forced to *simulate* the lookup with
computation it should not have to spend. So they give it a real one: constant-time
hashed access into embedding tables, beside the Mixture-of-Experts rather than
instead of it. Against an iso-parameter baseline they report MMLU +3.4, BBH +5.0,
and a long-context needle test at 97.0 against 84.2, with the best split around
80% experts and 20% lookup.

**That is this document's §0, one floor down.** What the paper does inside the
model — stop making it simulate a lookup, give it one — is what this application
does around it: the news, the weather, the timer, the verbs, the routes and the
diary recall are all lookups done in code, and the model is left to compose a
sentence. The reason found here was a 4B inventing a headline; the reason found
there is a benchmark. Same shape.

**What it does not mean is that anything here changes.** This project does not
train models; it uses Apple's, a local GGUF, or somebody's API. There is nothing
to build from this paper.

There is one thing worth watching, and it is falsifiable. If lookup modules of
this kind reach the small local models, the weakest engine on this list gets
better at precisely what it is worst at — and the measurement that justified the
application's own routing (`tests/web.m`, a 4B inventing *"Oggi a Milano è stato
annunciato…"*) should be **re-run rather than quoted** when the local models
change. The routing would still be right for the safety reason; it might stop
being right for the accuracy one.

## 1. Memory that recalls by relevance ✅ *shipped in 2.9 — and the plan here was wrong*

**The biggest lever, and the one most in character.**

Today the diary reaches the prompt by recency. A question about something decided
three weeks ago does not find it, however well it was written down. Distillation
keeps the month from growing without bound, and that is not the same as recall.

What was built is the second half of that: a recall that returns *the lines that
bear on this question* instead of *the last N*.

**Not the first half.** This section said to use `NLEmbedding`, and measuring it
first — which is the only reason anybody found out — put it at 5 of 10 against 8
of 10 for counting lemmas, at twenty times the cost and 3.7 MB on disk. The table
is in `NekoRecall.h` and in 2.9's changelog. What does the work is lemmas, word
class and rarity, all from `NLTagger`, in four languages, with nothing stored
beside the diary.

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

1. ~~**A timer.**~~ **Shipped in 2.9.** Studied in [utilities.md](utilities.md) and, until then, never built. It is the
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

## 3. Routes — the missing half of the plugin interface ✅ *shipped in 2.9*

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

**What it cost, now that it is built**: less than this section feared, because
the shape got narrower rather than wider. The sketch in plugins.md had a `Match`
with words and a language and a `Do` with three choices; what shipped has phrases
and one https address, and the matcher is the verbs' matcher, extracted rather
than rewritten.

**And one thing this section did not foresee**, which turned out to be the most
important sentence in the feature: *a route carries your words*. The application's
own feed requests carry no question at all; a route with a `%@` in its address
necessarily sends part of what somebody said to whoever owns that address. It is
disclosed in the plugins window, with the host named, from the manifest rather
than from anything the plugin claims about itself.

## 4. Perceiving without reading ✅ *first slice shipped after 2.9*

The rule stands and is not up for negotiation: **nothing read from the screen ever
becomes something the Mac does**, and remote engines never see the screen, the
diary or the reflections.

But there is signal that is not content: which application is frontmost, whether
the microphone or camera is in use, how long somebody has been still, the time of
day. `NekoDesktop` already uses some of it for the seams. More of it makes the
*timing* right — remarks that arrive in a gap rather than across a sentence — which
is the whole difference between an animal that seems attentive and one that seems
intrusive.

**What went in**: three more flags, each a counter or a boolean and none of them
content — the microphone being open somewhere, the screen being locked or
somebody else being at the console, and the display being asleep. All three are
readable from inside the sandbox, none prompts for anything, and two hundred
samples of two of them cost 0.02 ms each.

Two things worth recording:

- **A signal that is always "no" is not a signal.** The microphone flag was
  watched going cold, hot while a tap was open on the input, and cold again.
  `tests/senses.m` still does that, every run.
- **The cat's own microphone had to be excluded.** The wake word holds the input
  open for as long as it is switched on, so without that exception the flag would
  have been stuck at *"somebody is talking"* whenever Neko was listening for its
  name — silencing the cat permanently, and looking like a different bug
  entirely.

And one thing it changed elsewhere: **nobody being there is not a bad moment, it
is no moment.** A bad moment passes in seconds and is worth sitting out for eight;
a locked screen does not pass at all, so a timer that lands against one waits for
somebody to come back — for an hour, after which what it was going to say is no
longer news. Saying it to an empty room and counting it as said is the one way a
timer can fail silently.

**Risk**: the temptation to creep from "which application" toward "what is in it".
The line is in the code and in `tests/screen.m`; it does not move.

## 5. Latency, which is felt as intelligence ✅ *shipped after 2.9 — and half of it already existed*

This section said the answer arrives all at once. **For the two local engines it
did not**: `NekoAsk` had streamed since the optional method went into the provider
protocol, and Apple's model and the local GGUF both implemented it. Reading the
code before writing any is what found that, and it is the second time in this
document that a section described the application as it was imagined rather than
as it is.

What was actually missing was the half where it matters most:

- **The two remote engines did not stream at all.** ChatGPT and Claude are the two
  that go over a network — the two where somebody waits — and they were the two
  that made you wait for the whole answer. Both speak server-sent events; the
  formats differ only in where the text sits inside each event, so the reading is
  one shared piece (`NekoStream`) and the difference is one block each.
- **Two of the three paths did not stream either**, and they were the slow ones: a
  question answered after fetching the news, and one answered after a plugin's
  route. Both fetch first and only then start thinking, so they are exactly where
  the first words landing early is worth the most. There is one method now and all
  three doors go through it.

**How it was measured.** Not by calling either service: an API call costs the
person running the suite money and would tie the harness to somebody else's
uptime. `tests/stream.m` feeds bytes instead — split mid-word, split between the
two bytes of an accented character, with keep-alives and rubbish in between, and
with an error body instead of a stream — and checks that all-at-once and
one-byte-at-a-time end in the same sentence. Those are the things that actually go
wrong when reading one of these.

**What was left alone**: when the cat starts *speaking*. The pacing of 2.1 and 2.2
is measured and delicate, and starting the voice on a half-finished sentence is a
different feature with a different risk. This is about when the words appear.

## What not to do

- **Longer prompts.** Measured as harmful on small models. The budget stays.
- **New permissions that have not earned themselves.** Six today, each defensible
  in one sentence.
- **A second cat.** Two would need a list, and a list needs a window.
- **Anything that lets a plugin, a feed or the screen decide what happens.** That
  is the one line this application has never crossed, and it is why the rest of it
  is allowed to be this close to somebody's day.

## The open bug, and the one that turned out to be elsewhere

1. **Synonyms in the diary recall** — still open, and now with two measured dead
   ends written down so nobody spends the afternoon on either. `NLEmbedding`'s
   word neighbours: no threshold exists, because *gatto↔cane* (0.660) is closer
   than *versione↔release* (0.922) — distributional similarity is not synonymy.
   The system dictionary: reachable from inside the sandbox, which is worth
   knowing, but it answers with definitions, and the Italian entry for
   *impostazione* opens on its architectural sense. The table is in
   `NekoRecall.h`.

   The idea worth trying next is **the person's own diary as the source**: words
   that turn up in the same lines are related in their vocabulary, and an
   expansion drawn from what somebody actually wrote cannot import a concept from
   outside it. It needs a real month of diary to measure, and measuring it against
   a corpus written for the purpose would prove nothing — that is the shape of
   passing for the wrong reason this project keeps catching itself in.

2. **The folder handover refused in silence** — fixed in 2.9, and worth recording
   because the diagnosis in section 0 was wrong and the measurement found the real
   thing next door. Choosing a folder that is not the one asked for was refused by
   returning `NO`, and all three callers ignored the answer. Nothing appeared,
   nothing was said, and the folder was not handed over: *"does nothing"*, exactly
   as reported, and nothing to do with the panel being modal. It says which folder
   it got and which it wanted now, in the bubble, in the menu and in the settings
   window.
3. ~~**`tests/persona.m` has one check that can fail without a defect.**~~ Fixed
   while building §1: it asserts the trimming, which is ours and deterministic,
   and reports how often the engine needed trimming as information rather than as
   a verdict. What follows is what it used to say. *"And still
   opens with the answer"* counts replies that began with flattery — which is a
   thing the engine does or does not do on the day, not a thing this code decides.
   It failed once during 2.9 and passed on the next run with nothing changed. A
   check that fails for reasons that are not defects teaches people to ignore the
   suite, and this one should either assert the **trimming** (which is ours and
   deterministic) or be marked as not measured.
4. ~~**The plugins window is not covered by `tests/layout.m`.**~~ Covered now, and
   it found three clipped paragraphs the first time it ran — one of them the
   sentence saying what a plugin sends off this Mac, cut off after a line and a
   half. Rows measure their own text now instead of being a fixed height, and the
   harness **counts** a clipped paragraph instead of printing one: it had been
   printing that complaint about the Permissions tab for some time, and a
   complaint nobody fails on is a comment.

The lesson is the one this project keeps relearning and keeps writing down: a
defect that is obvious from reading the code is a hypothesis, and the measurement
is what says whether it is the one somebody is actually hitting. Two of the three
"the button does nothing" reports in this application had a cause other than the
first plausible one.
