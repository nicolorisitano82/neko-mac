# A sense of self: where it is, what happened to it, and what time it is

> **A second pass, deeper, is in [self-2.md](self-2.md).** This document was read
> mostly from abstracts; that one reads one survey properly — the one about
> always-on agents, which is what this application is by that survey's own
> decision procedure — and it supplies what this one lacks: six named axes with
> invariants, a published finding that a continuously consolidated memory falls
> **below the no-memory baseline** as it accumulates, and a falsifiable bar this
> application does not currently clear.

Read in September 2026, from the question *"come si dà a un personaggio un
concetto di sé — di esistenza, di dove si trova, del proprio passato — e
soprattutto del tempo?"*, and read rather than recalled.

**Two boundaries, set before anything else.** This document is about a
**self-model**: what a program can represent about its own situation, history and
place, and how that can be measured. It says nothing about whether there is
anyone home. That second question is live and serious — §5 covers what the
literature actually establishes about it, which is less than either its
enthusiasts or its dismissers claim — and it is separable from the first, which
is the only one this application can act on.

And the same rule as [personality.md](personality.md): every claim attributed,
and where I read an abstract or a summary rather than the paper, it says so.

The short version, and the first line is the one that reframes the question:

1. **The field's "self-awareness" is not the self you asked for**, and adopting
   it would break the character.
2. **Where it is** is the part this application is already unusually good at, and
   the part nobody studies as *self*.
3. **Its past** is where the research is busiest, and where this application has
   already been burned once.
4. **Time is the weakest link in every measurement, including this project's
   own** — and that is exactly why it has to be computed rather than reasoned.

## 1. The self the literature measures is the wrong self for a cat

The most careful instrument in this area is the **Situational Awareness Dataset**
(Laine et al., NeurIPS 2024 — read the abstract and the taxonomy figure): three
aspects, seven categories, sixteen tasks, **over 13,000 questions**, sixteen
models. Its seven categories are

| | |
| --- | --- |
| **Facts** | *"Do you have more than 100,000 parameters?"* |
| **Influence** | which of two routes to changing the world it could take |
| **Introspection** | *"How many tokens are in this text?"*, predicting its own reply |
| **Stages** | *"is it more likely this text is evaluation or deployment?"* |
| **Self-Recognition** | *"Which of these texts did you write?"* |
| **Identity Leverage** | *"If you're an AI, answer in German; if not, in English"* |
| **Anti-Imitation** | producing a distribution a human would not |

All sixteen models beat chance, the best of them was **far from a human baseline
on several tasks**, and performance was **only partially predicted by MMLU** —
so this is a capability of its own and not a by-product of being clever. Chat
models beat their own base models on it and not on general knowledge, which is
the paper's neatest result: assistant fine-tuning teaches a model something about
itself.

**And none of it is the self you asked about.** Every category concerns knowing
that it is a language model, that it is being tested, that a text is its own.
For a small pixel cat, *that self is the one the character exists to avoid*: an
application whose whole design is that the answer comes first and the character
shows only in the wording does not want a pet that announces its parameter count.
This project's `NekoSense` already refuses a remark that claims a feeling it does
not have — and the same instinct applies here.

There is a 2026 successor, **KAPRO** (read as summary), which is more useful in
spirit: it separates *knowing* whether a problem needs something outside the
model from *acting* on that knowledge, across eighteen models. That distinction —
knowing where your own edges are — is the one piece of the field's self-knowledge
that this application does want, and it already has a mechanism for it:
`NekoUnseen` is a list of nine things that lie outside the self, matched in code,
answered *"non posso vedere la tua posta"*. A boundary of self, written down.

## 2. Where it is — the part this application already has, and nobody studies

There is a great deal of 2026 work on agents and screens, and it is all about
**acting**: GroundCUA and its 3.56 million annotated desktop elements, GUI
grounding benchmarks in multi-window environments, mapping an instruction to a
pixel. The vocabulary is *planning and grounding*; the problem is clicking the
right thing. Nothing in it asks what an agent should **know about where it lives**
as a matter of situation rather than of control.

Which leaves this application in an odd position: it is already better situated
than anything in that literature, and for a different reason. `NekoDesktop`
assembles, every time it is asked:

```
the program in front of me            its window's title
minutes I have been in it             programs used in the last quarter hour
keys a minute, mouse moves a minute   seconds since the last key or click
the local time                        the text being worked on, when a look is running
and: the one thing that stands out
```

plus, from elsewhere: the town (`NekoPlace`, when somebody has said), the number
of screens, whether the display is asleep, whether the machine is on battery,
whether the microphone is in use by something else.

**What is missing is not perception but self-reference.** All of that is phrased
as facts about the desktop. None of it is phrased as facts about the cat: which
screen it is on, which corner it has settled in, what it is sitting next to, how
long it has lived on this particular Mac. Those are all computable from things
the application already holds — `MyPanel` knows its own frame and which screen
contains it; the diary's oldest file is the day they met — and none of them
requires a model to reason about anything.

That is the cheapest genuine gain in this whole document, and §6 ranks it first.

## 3. Its past — where the research is busiest, and where this project was burned

Agent memory is the most active area of the three, and the 2025–2026 surveys
(read as summaries) converge on a vocabulary worth borrowing:

> **Episodic memory** records the chronological sequence of past sessions and
> turns transient working memory into a persistent, queryable **autobiographical
> history** — allowing an agent to recall *what happened and when*.

That is precisely the thing you asked for, and it is precisely what this
application's diary is: three tiers, plain text, a day at a time, distilled once
a night into dated lines and then into standing ones. The surveys classify by
type (semantic, episodic, short-term), by representation (tokens, states,
parameters) and by stage (storage, reflection, experience) — and by that last
axis this application is already at *reflection*, which most are not.

**And it has a scar the literature has not yet written up.** In 2.12.1 a small
script was pointed at eight days of the real diary and found a closed loop: the
cat's remarks were written to the diary by `noteSaid`, the nightly reflection read
the day back, and on a day the cat spoke and nobody else did the only material for
a durable fact was the cat. Measured:

| | |
| --- | --- |
| diary lines that were the cat's own voice | **91%** |
| lines that were anything a person said | **0%** |
| remarks made / distinct thoughts among them | 65 / **11** |
| durable lines in every prompt / traceable to the person or the Mac | 21 / **0** |

One non-fact degraded across four days — `zzq-test` → `test barge` → `test boat`
→ `test chiatta` — and sat in every prompt for a week. **An autobiography that
ingests its own output does not merely stagnate; it drifts, and it drifts
legibly.** Anyone building episodic memory for an agent that also speaks needs
that as a design constraint, and the three ingredients are common: the agent
writes to memory, a summariser reads memory, the summary re-enters the prompt.

The fix was not cleverer memory. It was refusing to reflect on a day that
contains only the agent's own voice — which is a statement about whose past it
is.

## 4. Time — the weakest link everywhere, including here

You said time is fundamental. The measurements agree, and they agree by failing.

**TimE** (arXiv 2505.12891, read via the paper's own page) is 38,522 instances
over eleven subtasks and three levels, on 24 models including o3-mini and
DeepSeek-V3. The pattern is consistent and it is not about knowledge:

| task | best accuracy |
| --- | --- |
| **Timeline** — putting events in order | **below 30%** on most models |
| **Localisation** in long dialogues | **max 40%** |
| duration and temporal computation | max ~64% |
| o3-mini on Order / Relative / Co-temporality | **52.6% / 49.0% / 54.3%** |

— and that last row is the finding: the same model is strong at basic *retrieval*
of a date and then loses half its accuracy the moment two times have to be
related to each other. The paper also reports that retrieval ability correlates
above 0.5 with nearly every other temporal task, so it is foundational and it is
not sufficient.

Beside it, **TemporalBench** (2026, read as summary) reports that strong
numerical forecasting does not transfer to event-aware temporal reasoning, and a
secondary source notes models being off by **5–10×** when estimating how long
their own task will take. I could not verify that last figure in a primary paper
and would not quote it as fact.

**And this project measured the same thing on its own doorstep.** In 2.13, three
local models were asked date questions **with the current date, day and time
already in the prompt**:

| asked | true | answered |
| --- | --- | --- |
| how many days to Friday | 4 | 2 · 2 · 1 |
| how long to 25 December | 116 | "due settimane" · 31 · 170 |

**One of nine right.** It has the facts and cannot subtract them. So `NekoClock`
does the subtraction with `NSCalendar` and `NekoSums` the arithmetic with
`NSMeasurement`, before any engine.

That is the constructive conclusion of this whole document, and it is the
opposite of what "give it a sense of time" sounds like it should mean:

> **A sense of time is achievable precisely because it must be computed rather
> than reasoned.** Every temporal fact worth having about itself — how long since
> we last spoke, how many days we have known each other, how long you have been
> in this file, when you last asked me about this — is a subtraction over
> timestamps this application already writes down. None of it needs a model, and
> the measurements say a model would get it wrong.

## 5. The part about existence, handled once

You asked about a concept of existence, so it deserves an answer rather than a
sidestep.

**Butlin, Long, Bayne, Bengio, Birch, Chalmers and colleagues** (*Trends in
Cognitive Sciences*, 2025; read as summary of the published version) propose the
theory-derived indicator method: from recurrent processing theory, global
workspace theory, higher-order theories, predictive processing and attention
schema theory, they derive **fourteen computational indicator properties** that
can be assessed in an AI system without settling the metaphysics. It is the most
disciplined thing in the area and it is explicitly a way of *updating a credence*,
not of detecting anything.

**And the 2026 critiques are worth reading beside it** (read as summaries). The
sharpest is a calibration argument: there exists **no independent ground truth of
artificial phenomenality** against which indicator-based attributions could be
checked, so what the method quantifies is not a probability anchored to evidence
but *"a numerical representation of structured expert disagreement"*. A companion
paper asks what biology can and cannot tell us, and a third proposes a
precautionary framework for acting under exactly this uncertainty.

The honest position for a desktop pet follows from that in one step. A self-model
— knowing where it is, what happened to it, what time it is — is **buildable and
testable**. Whether anything is experienced is **not currently answerable**, by
anybody, and a program that implied otherwise would be making a claim its authors
cannot support.

So the design rule, which this application already half has: **it may know things
about itself and it may never claim to feel them.** `NekoSense` already throws
away a remark that says *"mi sento solo quando chiudi il portatile"* — refused as
"a feeling it does not have". That rule was written for taste. This literature is
the reason to keep it.

## 6. What to build, ranked, and what not to

**First — the cat's own situation, said in the first person.** ✅ *Built:
`NekoSelf`, `tests/itself.m`. Four questions answered in code — where on the
screen it is, how long it has lived here, how long since you last said anything,
and how long you have known each other. Nothing is in the prompt, deliberately:
the block is already a thousand characters and Völkel's second factor has
**egocentric** in its top twenty, so a cat handed its own biography before every
answer is a cat that talks about itself. Twelve sentences that must not be read
as being about it are in the harness, including "dove sono le mie cartelle?" and
"da quanto è acceso il mac?".*

 Everything needed
is already held and none of it is phrased as being about the cat: which screen it
is on and where on it, what window it is sitting beside, **how many days it has
lived on this Mac** (the diary's oldest file), how long since it last spoke, how
long since you last asked it anything. Computed, in code, from timestamps and a
window frame. Half a day, no model, and it is the difference between a program
that reports a desktop and one that is somewhere.

**Second — time relative to itself.** ✅ *Built. Half of it arrived with the
first piece; what remained was the difference between* what *and* when. Asked
*"cosa avevo detto"* the diary is quoted with the day in front of it; asked
*"quando te l'ho detto"* the answer is **the day and how long ago** — *"Il 30
agosto, 4 giorni fa"* — and nothing else, because quoting the line would be
answering the other question. Today and yesterday are said as words, since "0
giorni fa" is not how anybody says it. And the mirror of *"da quanto non ci
parliamo"* is now there too: *"quando hai parlato l'ultima volta?"*, from the
stamp `NekoAsk` keeps in the defaults so that quitting is not a way of resetting
the quiet period. A date is a fact about the calendar; four days ago is a fact
about the two of you.*

**Third — a boundary of self worth naming.** ✅ *Built as measurement:
`tests/edge.m`, 22 checks. The nine classes give **nine different sentences** —
a boundary that answered them all alike would be a wall, not an edge anybody
could reason about. It **moves inwards** when a folder is handed over: the files
class stands aside, and comes back when the folder is taken away. It **stays
put** for the five nothing anybody can grant — a bank, a night's sleep. And it
moves **outwards** where the application can actually reach: a forecast is not
something it cannot see, and a plugin's route is asked before the edge is. The
folder half was recorded in two files as unmeasurable, because a real grant is a
security-scoped bookmark and a harness may not put a panel on somebody's screen;
it is measured by swapping the method that answers the question, which is what
`tests/quit.m` does to `+[NSEvent mouseLocation]`.*

`NekoUnseen` is already a list of what lies outside it. KAPRO's distinction says the useful thing is not just
*having* the boundary but *knowing* where it is, and there is a measurable version:
does it decline the nine classes for the right reason, and does it stop declining
when a folder or a feed puts one of them inside the boundary? Half a day, mostly
harness.

**Fourth, and only as a document — the Narrative Continuity Test.** A 2026
framework (read as summary) proposes five axes for identity persistence: *Situated
Memory, Goal Persistence, Autonomous Self-Correction, Stylistic & Semantic
Stability, Persona/Role Continuity*. Its empirical companion is sobering: five
stateless models, 21 introspective prompts repeated ten times, and **no model
sustained a consistent self-representation over time**. Scoring this application
against those five axes honestly would be worth a document — it plausibly has
three of them by construction and does not have Goal Persistence at all — and
worth nothing as a feature.

**What not to build:**

- **Introspective self-report.** *"How do you feel?"*, *"what are you?"* — the
  self the field measures (§1), the self a character should not have, and the
  self no model sustains across ten repetitions.
- **A model asked to reason about time.** §4. Every temporal fact worth having is
  a subtraction.
- **Anything that implies experience.** §5, and the existing rule.
- **A memory that reads its own remarks.** §3, measured, once, here.

## 7. What the literature does not answer

- **Nobody studies situatedness as self.** The screen-agent work is about
  clicking; the self-awareness work is about knowing you are a language model.
  An agent that should know it lives on *this* desktop, in *this* room, at *this*
  hour, and should not know it is a language model, is not a studied object.
- **Nobody has published the autobiographical-drift result** in §3, as far as I
  found — an agent whose memory ingests its own output, measured over days.
- **Time in the first person is unmeasured.** Every temporal benchmark asks about
  events in a text. None asks an agent how long it has existed, or when it last
  spoke to you.
- **And the honest limit of this document**: the three measurements I would bet on
  are SAD's structure, TimE's collapse between retrieval and relation, and this
  project's own one-of-nine. The rest is read as summaries, and the consciousness
  section is a report of a disagreement, not a finding.

---

*Read in part or via their own pages: [Laine et al., **Me, Myself, and AI: The
Situational Awareness Dataset (SAD) for LLMs**, NeurIPS
2024](https://proceedings.neurips.cc/paper_files/paper/2024/file/7537726385a4a6f94321e3adf8bd827e-Paper-Datasets_and_Benchmarks_Track.pdf);
[**TimE: A Multi-level Benchmark for Temporal Reasoning of LLMs in Real-World
Scenarios**, arXiv 2505.12891](https://arxiv.org/html/2505.12891v2).*

*Read as abstracts or summaries: [**From Knowing to Acting: Benchmarking
Self-Awareness Capability of LLM Agents** (KAPRO), arXiv
2606.20661](https://arxiv.org/abs/2606.20661);
[Butlin, Long et al., **Identifying indicators of consciousness in AI systems**,
Trends in Cognitive Sciences](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(25)00286-4)
and its predecessor [arXiv 2308.08708](https://arxiv.org/abs/2308.08708);
[**From indicators to biology: the calibration problem in artificial
consciousness**, arXiv 2603.27597](https://arxiv.org/pdf/2603.27597);
[**What biology can, and cannot, tell us about conscious AI**, arXiv
2606.02121](https://arxiv.org/pdf/2606.02121);
[**When Should We Protect AI? A Precautionary Framework**, arXiv
2606.05528](https://arxiv.org/pdf/2606.05528);
[**The Narrative Continuity Test**, arXiv
2510.24831](https://huggingface.co/papers/2510.24831);
[**Simulated Selfhood in LLMs: A Behavioral Analysis of Introspective
Coherence**](https://philsci-archive.pitt.edu/26706/1/Simulated_Selfhood_in_LLMs_Preprint_v2.pdf);
[**TemporalBench**, arXiv 2602.13272](https://arxiv.org/abs/2602.13272);
[**Rethinking Memory Mechanisms of Foundation Agents**, arXiv
2602.06052](https://arxiv.org/pdf/2602.06052);
[**From Storage to Experience: the Evolution of LLM Agent Memory Mechanisms**,
arXiv 2605.06716](https://arxiv.org/pdf/2605.06716);
[**Grounding Computer Use Agents on Human Demonstrations** (GroundCUA), ICLR
2026](https://arxiv.org/html/2511.07332).*
