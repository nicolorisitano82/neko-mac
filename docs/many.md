# More than one model, and a memory that learns how to use them

A parallel study, from the proposal: *"potremmo creare una rete neurale con modelli
multipli in cui ottimizziamo l'interazione tra un modello e l'altro in base
all'esperienza acquisita nel tempo, quindi la memoria diventa un punto cruciale."*

That is a real research programme with a real name, real results, and a
well-documented ceiling. This reads it against what this application actually is,
and the conclusion is narrower and more useful than either yes or no: **the
mechanism works, the published gains are smaller than the headlines, and the
largest part of the routing space is closed to this project by its own privacy
promise — which leaves exactly one door open, and it is the door worth walking
through.**

---

## 0. A warning about how this document was written

The first draft of §2 quoted a summariser rather than a paper. It reported that
routing gains cap at "2–5% above the strongest single model" and that controlling
for prompt sensitivity shrinks apparent advantages "by 40–60%".

**Both numbers are invented.** Neither appears in the paper. Read directly, the
paper says the opposite in one place: the exact-match routing gain on MMLU is
**13 pp *larger*** than the judge-derived one, not smaller.

Every number below was read off the paper itself, and the reading depth is
marked. This is the same failure this project keeps catching in its own engine —
a fluent, confident, well-formatted answer with nothing behind it — and it is
worth recording that it happened while writing a document *about* trusting
multiple models.

---

## 1. What the field calls this

*Harnessing Multiple Large Language Models: A Survey on LLM Ensemble* (arXiv
2502.18036) sorts the whole space into seven families: **weight merging,
knowledge fusion, mixture-of-experts, reward ensemble, output ensemble, routing,
and cascading.**

The proposal above is two of them at once:

- **routing** — one model per query, chosen by something;
- and the *"in base all'esperienza acquisita nel tempo"* part, which is what turns
  a router into a **learned** router. That is the live research question, not a
  settled technique.

What it is **not** is a "neural network of models" in the literal sense — nobody
backpropagates through a graph of frozen LLMs. The interaction is optimised at
the level of *which one is asked*, not of weights. Worth saying plainly, because
the difference decides what memory has to hold: not gradients, but **a record of
what worked**.

## 2. The best evidence that it works

**BoundaryRouter** (*Learning Agent Routing From Early Experience*, arXiv
2605.07180, ICLR 2026 Lifelong Agent Workshop — **read in the paper, pp. 1–2**) is
the closest published thing to the proposal, and its shape is almost exactly the
one described:

> It "builds a compact experience memory by executing both systems on a shared
> seed set and retrieves similar cases at inference time to guide routing
> decisions" — and it is **training-free**.

Two systems: cheap direct inference, and an expensive agent. Run both on a small
seed set, keep what happened, and at question time retrieve the nearest past
cases to decide which path to take. No fine-tuning, no gradient, no labels — the
memory *is* the model.

Its numbers, on its own RouteBench:

| | |
| --- | --- |
| inference time against always using the agent | **−60.6%** |
| performance against always using direct inference | **+28.6%** |
| against prompt-based routing | **+37.9%** |
| against **retrieval-only** routing | **+8.2%** |

The last row is the one to keep. Retrieval alone — no experience memory, just
finding similar things — is **8.2% behind**, not 40%. Most of the win is in
*having a cheap path and an expensive path at all*; the learned part adds a
tenth of it.

The production line of work agrees on shape and differs on machinery:
**OrcaRouter** (arXiv 2605.30736) casts routing as a contextual bandit with
offline initialisation and optional online updates; **BaRP** (arXiv 2510.07429)
trains under bandit feedback with preference-tunable inference. Both are
*learned from outcomes over time*, which is the proposal, and both need a signal
saying whether the answer was good.

## 3. The ceiling, and the failure mode nobody advertises

*Unsolvability Ceiling in Multi-LLM Routing: An Empirical Study of Evaluation
Artifacts* (arXiv 2605.07395, Garg & Sagtani — **read in the paper, pp. 1–6**).
206,756 query-model pairs, 51,689 queries, six benchmarks, four Gemma 4 tiers on
self-hosted H100s.

Three things it establishes, all of them inconvenient:

**a. Much of the measured headroom is an artifact.** Three named sources: the
judge disagreeing with exact-match by −10 to −24 pp on MMLU; a **65% truncation
rate** on MMLU and 57% on MedQA under fixed token budgets; and parse failures of
5.4–12.4% that "preferentially inflate apparent unsolvability for smaller tiers".

**b. The optimal route is overwhelmingly *the cheapest model*.** Their oracle
distribution: E2B optimal for **50.3%** of queries, and 17.0% solvable by nothing
at all. On their training split the smallest tier is optimal **79.3%** of the
time.

**c. And that is what breaks the learned router.** Routers trained on those
labels "collapse entirely to majority-class prediction" — they learn to always
say *use the small one*. Confirmed by random-feature and shuffled-label controls.
The opportunity cost is **13–17 percentage points**.

That third point is the practical warning for anything built on the proposal: a
router learned from experience, on a workload where one option is usually right,
learns to always pick that option and stops being a router at all. It will look
like it is working — its accuracy will be high — because the majority class is
high.

And the wider result for multi-model systems, from *Why Do Multi-Agent LLM Systems
Fail?* (arXiv 2503.13657, NeurIPS 2025 — **read as summary**): despite the
enthusiasm, gains on popular benchmarks "are often minimal", with failures
sorting into bad specification (~42%), coordination breakdown (~37%) and weak
verification (~21%).

## 4. What this means here, specifically

**This application is already a router, and a good one.** `askAfterPlugins:` runs
twelve recognisers in code before any engine sees a question — a sum, a date, a
line from the diary, what it cannot see. That is a cheap path and an expensive
path with a hand-written boundary between them, which is BoundaryRouter's
architecture with the memory replaced by somebody's judgement.

So the proposal, translated honestly into this codebase, is **not** "add models".
It is: *should any of those boundaries be learned from experience instead of
written down?* Three candidates, and they are not equal.

### ✗ Choosing between engines — closed, and not by the evidence

Apple Intelligence, a local GGUF, ChatGPT, Claude, a Shortcut. A learned router
would pick among them by quality.

**It cannot.** That choice is not a quality decision in this application, it is a
**privacy decision somebody made on purpose**, and two of the five never leave the
Mac. A router that sends a question to ChatGPT because experience says the answer
is better has broken the one promise the whole design rests on. The literature
has no such constraint and so offers no help here; this is settled by the product,
not by a benchmark.

### ✗ Ensembling several answers into one — the wrong shape

Output ensembles and fusion assume you can afford to ask several models and pick
or blend. On a laptop, with a 4B model, first words in 0.40 s and a whole answer
in a couple of seconds, asking three models triples the wait for a cat that is
supposed to reply while you are still looking at it. §3's evidence says the gain
would be small; §5 of this project's own measurements says latency **is** the
felt intelligence.

### ✓ Learning when the chain should hand over — open, and worth it

The one live question. Today the boundary between *answer this in code* and *ask
the model* is a set of hand-written phrase lists, and the honest limit is written
into `NekoUnseen.h`: **"what this cannot do is cover a question phrased in a way
the list does not hold."**

That is precisely the cold-start problem BoundaryRouter addresses, and everything
it needs is already here and already local:

- **the seed set** — the diary, which is a real month of one person's real
  questions rather than a corpus written for the purpose;
- **the experience** — which questions the chain answered, which reached the
  engine, and what became of them, all of which this application already records
  (`NekoRate` counts answered against ignored);
- **the retrieval** — `NekoRecall`, lemmas and word class and rarity, 8 of 10 at
  267 ms, already built and already measured against the alternative that lost.

**And §3.c is the reason to be careful rather than a reason not to try.** This
workload is exactly the shape that collapses a router: the recogniser chain
stands aside for most questions, so *"send it to the engine"* is the majority
class by a wide margin. Any learned boundary here must be measured against the
trivial baseline of always doing that — and the survey's own controls
(random-feature, shuffled-label) are the way to prove it learned something rather
than counting.

## 5. What would have to be true

Stated so somebody can falsify it rather than argue about it.

1. **There is a signal.** A learned router needs to know whether an answer was
   good. This application has a weak one — `NekoRate`'s answered / dismissed /
   ignored — and it was built to pace remarks, not to judge answers. Whether it
   correlates with a good answer at all is **unmeasured**, and nothing should be
   built on it until it is. That is the first experiment and it is cheap.
2. **It beats the majority class.** With controls, on this Mac's own diary. If a
   shuffled-label router scores the same, there is nothing there.
3. **It stays inside the promise.** Nothing learned may move a question to an
   engine somebody did not choose. That is not negotiable and it is not a
   research question.
4. **It costs nothing to be wrong.** Routing a question to the chain when the
   engine would have done better costs one bad answer. The reverse costs a couple
   of seconds. Asymmetric, and the cheap direction is the safe one.

## 6. What not to take from this

- **Not a graph of models with learned weights.** Nothing in the literature does
  this; the optimisation is over *which model is asked*, and calling that a
  neural network invites building the wrong thing.
- **Not more engines.** The gain in §2 comes from having a cheap path and an
  expensive one, which already exists here. Adding a third engine adds a
  dimension to the routing problem and nothing to the answer.
- **Not a learned router before the signal is measured.** §5.1 is a week's work
  and it decides whether the rest is possible. Doing it in the other order is how
  a project ends up with a router that has learned to say *"use the small one"*
  and a benchmark that congratulates it.

---

*Read in the paper: [**Unsolvability Ceiling in Multi-LLM Routing**, arXiv
2605.07395](https://arxiv.org/pdf/2605.07395), pp. 1–6; [**Learning Agent Routing
From Early Experience** (BoundaryRouter), arXiv
2605.07180](https://arxiv.org/pdf/2605.07180), pp. 1–2.*

*Read via their own pages or as summaries: [**Harnessing Multiple Large Language
Models: A Survey on LLM Ensemble**, arXiv
2502.18036](https://arxiv.org/pdf/2502.18036); [**Why Do Multi-Agent LLM Systems
Fail?**, arXiv 2503.13657](https://arxiv.org/abs/2503.13657), NeurIPS 2025;
[**OrcaRouter**, arXiv 2605.30736](https://arxiv.org/html/2605.30736v1);
[**Learning to Route LLMs from Bandit Feedback** (BaRP), arXiv
2510.07429](https://arxiv.org/abs/2510.07429); [**Dynamic Model Routing and
Cascading for Efficient LLM Inference: A Survey**, arXiv
2603.04445](https://arxiv.org/html/2603.04445v2); [**RouterEval**, arXiv
2503.10657](https://arxiv.org/pdf/2503.10657).*

*Related here: [red.md](red.md) for the two open checks, [graph.md](graph.md) for
the memory question this one leans on, and `NekoRecall.h` for the measurement
that says counting words beat embeddings on this diary.*
