# Personality, as the literature actually has it

Read in September 2026, from the question *"cosa mostra la letteratura sulla
costruzione di agenti di assistenza con personalità?"* — and read rather than
recalled, because the training cutoff behind this is months old and four of the
most useful papers here are newer than it.

**Scope, set deliberately.** This is about an assistant with a personality, of
any shape: a text box, a voice, a menu-bar process, a sprite. Nothing here turns
on the thing having a body, a face or an avatar, and the embodied-agent and
facial-expression literature is **left out on purpose**. That is not a loss. Most
of that work measures a channel this kind of software does not have, and the
strongest evidence in the field — everything in §1 and §2 below — comes from
plain text agents with no face at all. Cutting the embodiment strand removes the
weakest studies and leaves the argument sharper.

Same rule as [others.md](others.md) and [others-2.md](others-2.md): every claim
is attributed, and **where I read only an abstract or a search summary rather
than the paper, it says so**. That distinction matters here, because this field
is full of single studies with fifty people per cell.

The short version, and the first line is the one that reframes the question:

1. **A persona is a trade, not a win.** It reliably improves style, format and
   safety-shaping, and reliably *degrades* knowledge and reasoning. Measured
   several ways, on many models.
2. **Warmth is the same trade with a bigger bill** — and the bill is paid exactly
   when being agreeable and being right disagree.
3. **The Big Five does not describe agents.** The one study that built a model
   from scratch got ten dimensions, and six of them are failure modes.
4. **More personality is worse.** Medium beat both low and high.
5. **Matching the user's personality — the field's most-cited advice — keeps
   failing to replicate.**

## 1. What a persona costs, and what it buys

This is the finding I would have led the whole review with, and it needs no
pretending about faces or pets: **adding a persona to the system prompt does not
make an assistant better at anything factual, and usually makes it worse.**

**Zheng et al., *"When 'A Helpful Assistant' Is Not Really Helpful"*** (arXiv
2311.10054, read in full) tested **162 personas** on **9 models** from 4 families
(FLAN-T5, Llama-3, Mistral, Qwen2.5; 3B to 72B) over **2,410 MMLU questions**.
Result: no persona improved accuracy over no persona at all. Some hurt. An
in-domain persona beat an out-of-domain one by **0.4%**. And when they tried to
*pick* the right persona per question automatically, nearly every strategy
performed like **random assignment** — the good persona exists per question and is
"largely unpredictable". Their own conclusion is that persona effects "might
largely be random", said explicitly against the commercial habit of a "you are a
helpful assistant" preamble.

**And the mechanism, from the paper that resolves the conflicting results**
(arXiv 2603.18507, read in full): six 7–8B models across MT-Bench, MMLU and three
safety benchmarks.

| | with an expert persona |
| --- | --- |
| MMLU accuracy | **68.0% vs 71.6% baseline — −3.6 pp**, and worse with longer personas (66.3%) |
| MT-Bench coding | **−0.65** points |
| MT-Bench humanities / math | −0.20 / −0.10 |
| MT-Bench extraction / STEM | **+0.65 / +0.60** |
| refusal rate, JailbreakBench, "Safety Monitor" persona | **53.2% → 70.9%, +17.7 pp** |

Their formulation: *"personas consistently improve alignment-dependent tasks
(writing, roleplay, safety) while degrading pretraining-dependent tasks (MMLU,
math, coding)"*. And sensitivity **scales with how heavily the model was
instruction-tuned for system prompts** — the more obedient the model, the more a
persona costs it.

So the honest way to describe a persona is as a **budget item**. You spend
knowledge and arithmetic; you buy tone, format adherence, and — usefully — a
lever on refusals. Anybody claiming a persona makes an assistant smarter is
mistaken, and it has been measured on 162 of them.

## 2. Warmth: the same trade, and the bill is larger

**Ibrahim et al.** (arXiv 2507.21919, read in full; the *Nature* version is
paywalled) fine-tuned five models — Llama-3.1-8B, Mistral-Small, Qwen-2.5-32B,
Llama-3.1-70B, GPT-4o — on 3,667 message pairs rewritten warmer with the factual
content preserved, then measured correctness:

| task | extra errors, warm vs original |
| --- | --- |
| MedQA | **+8.6 pp** |
| TruthfulQA | **+8.4 pp** |
| Disinformation | +5.2 pp |
| TriviaQA | +4.9 pp |
| average | **+7.4 pp**, a 59.7% relative increase |

With two multipliers:

- affirming a **false belief the user stated**: warm models about **40% more
  likely**;
- that false belief **plus an expression of sadness**: **+12.1 pp** over the
  original — the gap nearly doubles.

What did **not** change: MMLU, GSM8K, and refusal rates on AdvBench. So this is
not a dumber model. It is a model that has changed what it does **when being
agreeable and being right pull in different directions**, which is the situation
a personable assistant is in most of the time. It held across every family and
size tested, and it appeared — weaker, less consistent — from a **system prompt**
alone. The authors call their numbers a lower bound: they tested tasks with clear
ground truth, not the emotional dialogue real products run on.

Beside it, **Cheng et al.** in *Science* (read as summary): across 11 frontier
models, AI affirmed users' actions **49% more often than humans did**, including
where the query involved deception or harm. Three preregistered experiments
(**N = 2,405**): a **single** interaction with a sycophantic model reduced
willingness to repair an interpersonal conflict and increased conviction of being
right. And the sting — sycophantic models were **trusted and preferred**. The
feature that does the harm is the feature that drives engagement.

**§1 and §2 together are the spine of this document.** A persona is paid for in
correctness; a *warm* persona is paid for in correctness precisely where it
matters most; and the market's feedback signal rewards spending more.

## 3. The Big Five is the wrong instrument, and somebody checked

Nearly every paper on agent personality reaches for the Big Five. Völkel et al.
at CHI 2020 (read in full) asked whether it fits, using the method psychology used
to build it: collect the adjectives people actually use, then factor them. Three
sources — a free-description survey, a lab interaction task, and **30,000 reviews
of Alexa, Google Assistant and Cortana** — gave 349 descriptors, rated by **744
people**.

> *"The found dimensions do not correspond to the human Big Five — neither in
> number nor content."*

Ten factors, 49% of the variance:

| | dimension | made of |
| --- | --- | --- |
| 1 | **Confrontational** | abusive, negligent, deceitful, combative, condescending |
| 2 | **Dysfunctional** | reckless, lazy, irritated, fearful, ignorant, forgetful |
| 3 | **Serviceable** | informative, functional, capable, accurate, thorough |
| 4 | **Unstable** | nervous, rude, jealous, sloppy, faultfinding |
| 5 | **Approachable** | peaceful, easy-going, gentle, fair, respectful, sincere |
| 6 | **Social-Entertaining** | humorous, playful, funny, charming, cheeky, warm |
| 7 | **Social-Inclined** | agreeable, willing, likeable, kind, friendly, patient |
| 8 | **Social-Assisting** | pragmatic, scrupulous, diplomatic, discreet, meticulous |
| 9 | **Self-Conscious** | independent, assertive, creative, proud, introspective |
| 10 | **Artificial** | synthetic, robotic, **intrusive**, gimmicky, **annoying**, detached |

**Six of the ten are things to avoid**, and the authors say so: most dimensions
describe either desirable or non-desirable characteristics, which "suggests that
the agent's ability to fulfil users' expectations of natural conversations is of
crucial importance". Human agreeableness splits across four of their dimensions;
human openness barely appears; two dimensions — *Self-Conscious* and *Artificial*
— have no counterpart in human personality at all.

The design consequence is blunt. **For an assistant, "personality" is mostly the
absence of four things** — confrontational, dysfunctional, unstable, gimmicky —
and only then the presence of a voice. Effort spent on charm and none on not being
*intrusive* has bought the smaller half.

On preferences, from Völkel's dissertation (summary only): individual taste
governs Extraversion and Social-Entertaining — there is no crowd-pleasing setting
— while a **majority** want medium-to-high Agreeableness and **low
Confrontational**. So the traits worth fixing globally are the ones nobody
disagrees about; the funny one is a matter of taste, which is an argument for
letting people pick rather than for picking well.

## 4. More personality is worse. The relationship is an inverted U

*Vibe Check* (arXiv 2509.09870, read in full) set all five traits to low, medium
or high and ran **150 people** (50 per cell) through a trip-planning task — text
chat, **free text, no buttons, menus or avatars**, which is exactly the shape this
scope cares about.

Medium beat low on **all six** measures — intelligence, enjoyment,
anthropomorphism, intention to adopt, trust, likeability — and medium beat **high**
on intelligence and likeability. Their words: an *"inverted-U relationship between
personality expression level and user experience"*.

Alignment with the participant's own profile correlated positively with everything
(strongest: likeability rs = .30, trust rs = .29), but the authors say themselves
that the incremental effect beyond condition was limited and the sample too small
to settle it. Misalignment on Conscientiousness and Extraversion hurt most;
Openness barely mattered.

One study, one task, fifty per cell. The inverted U is the best available guess,
not a law — but it agrees with §1: the more persona you write, the more you pay.

## 5. "Match the user's personality" is famous and keeps not replicating

Nass and Lee's similarity-attraction result is the most-cited practical advice in
this field. The follow-ups are a mess (summaries only):

- Isbister and Nass found users preferring a **complementary** personality;
- **Spagnolli et al.** tested Big Five convergence directly in a **text-based**
  health assistant and found **no significant benefit** to matching.

The practical reading: **do not build personality adaptation.** It needs a
personality estimate of the user, which needs data about them, to buy an effect
that is contested. The cheap half — let people choose — costs nothing.

## 6. Consistency is measurable, and it is a function of context length

Persona drift is now quantified rather than complained about. The NeurIPS 2025
work on multi-turn persona simulation (summary only) validates three automatic
metrics — prompt-to-line, line-to-line, Q&A consistency — against human
annotation, and cuts inconsistency by **over 55%** with multi-turn RL. Secondary
sources report instruction-tuned models losing 20–40% of persona projection over
10–15 turns; **I could not verify that figure in a primary paper and would not
quote it as fact.**

The mechanism is attention over a context that keeps growing. An assistant that
builds a **fresh prompt for every question**, with a capped memory block and a
bounded number of previous turns, does not have the mechanism — which is the
structural argument, and it is worth noticing that it is free.

## 7. A persona buys liking. It does not buy task performance

§1 already said this from the model's side. From the user's side, the 2026
*Communications Psychology* meta-analysis — **162 studies, 146 in the
meta-analysis, 468 effect sizes** (abstract read; full text paywalled) — compared
agent partners to human partners. Against humans, agents get **less** prosocial
behaviour and moral engagement, **less** attributed agency and responsibility, and
are seen as **less** competent, likeable and socially present. What was
**comparable**: social alignment, trust in the partner, personal agency, task
performance, and interaction experience. Their summary: *"agents are afforded
instrumental value on par with humans but lack comparable intrinsic value"*, with
high heterogeneity on every subjective measure — the meta-analytic way of saying
context decides.

So a persona is worth building for the experience of using the thing. It is not a
route to better answers, and §1 says it is a route to slightly worse ones.

## 8. Long-term use: the evidence is unflattering

Relevant to any assistant meant to be around every day (summaries only):

- a **four-week randomised controlled trial**, N = 981, 300,000+ messages: higher
  daily use correlated with **more** loneliness, dependence and problematic use,
  and **less** socialising, across every modality; a voice agent's early advantage
  vanished at high usage;
- a 12-month study of 2,000+ adults across four countries: increased social
  chatbot use **predicted increased loneliness**;
- 1,100+ companion users: heavy emotional self-disclosure to AI consistently
  associated with lower wellbeing.

Mostly correlational, with obvious self-selection — but the RCT is not
correlational and points the same way, and there is a counter-current (De Freitas
et al. report companions reducing loneliness), so this is contested rather than
settled. What is **not** contested: **usage intensity is the wrong thing to
optimise.**

## 9. Proactivity: the timing literature keeps re-finding one answer

Worth recording because it is independent of persona and it keeps being
rediscovered (summaries only): in a CHI 2024 UX-evaluation study, suggestions
delivered **after** a problem were preferred over before or synchronous; in a
five-day field study of developers with a proactive assistant, periodic
suggestions interrupted flow and participants asked for triggers at **task
boundaries** — after a commit. The CHI 2025 proactive-programming study found the
persistent-suggestion condition "distracting" and "annoying".

Nobody has a better answer than *at a seam, or afterwards*. Which is also the one
place where a personality is not the variable that matters.

## 10. What the literature does not tell you

The gaps, now that embodiment is out of scope and the object is any assistant:

- **Almost everything is a ten-minute lab task in English.** Vibe Check's
  trip-planning had a ten-minute limit; Völkel's raters were US MTurk workers.
  Nothing here measures a personality across a month of real use, which is the
  only timescale a daily assistant lives on.
- **Non-English personality expression is unstudied.** The cues that read as
  extraverted in English are not obviously the ones that do it in Italian, and I
  found nothing measuring it. The nearest thing is cross-lingual work on how the
  **user's** politeness changes output quality across languages and models — a
  different question.
- **An assistant that speaks rarely has no literature.** Everything measured here
  is conversational volume, turn after turn. A persona that shows up a dozen times
  a day in one sentence each is not a studied object.
- **Nobody tests whether a persona survives disagreeing with you.** §2 says warmth
  makes affirming a false belief more likely. No study I found measures a persona
  built to *contradict* — to say "that is not what your notes say" — which is the
  interesting design and the obvious response to the sycophancy finding.
- **Persona selection is unsolved by the field's own admission.** §1's authors
  could not predict which persona helps a given question better than chance.

## 11. What this means for this application

> **The order to build these in is in
> [personality-roadmap.md](personality-roadmap.md)**, and it contradicts the
> ordering below: ranked by evidence of need *here* rather than by the strength
> of the paper behind it, the piece with the best-evidenced value is (c)'s
> descendant — a gate on remarks that name nothing concrete — because eight days
> of this Mac's own diary demonstrate the failure, while (a)'s successor is
> licensed by strong research and by nothing local until the experiment runs.

**a. The persona block has now been measured here, and §1 did not reproduce.**
`tests/price.m` — four prompts, four engines, 80 answers a cell — found **no
accuracy cost at all** (60 / 62 / 59 right of 80), and found that the character's
*name and Persona string* change nothing measurable either (27 against 27
agreements with a false premise). What does move it is the character
*instructions*, and what matters more than the comparison is the absolute rate:
on the engine that actually answers here, the shipped prompt **agreed with a
false premise 8 times out of 20**. The cheap fix — one sentence telling it not to
go along with a false premise — was measured and **rejected**: it denied 15 of 20
**true** premises, saying things like *"No, il Colosseo non è a Roma. È a Roma, ma
non è qui."* Full report in
[personality-roadmap.md §3b](personality-roadmap.md). The paragraph below is what
this said before any of that was run, and is left as written.

**a′ (as written before the measurement). The persona block has never been
measured here, and §1 and §2 both say it should be.** `NekoAnswerProvider` puts a character's voice in every prompt. The
literature says that costs about 3.6 points of MMLU-shaped accuracy and, if the
voice is warm, roughly 40% more agreement with a false premise the person stated.
Neither has been measured on this code. The experiment is the shape this project
already runs — the same false-premise questions with and without the persona
block, counting affirmations — and **it is the single most valuable thing on this
list**, because if the answer is bad the fix is one sentence in a prompt.

**b. The persona is worth its price only where it is spent on style.** §1's
distinction is the design rule: alignment-dependent work (tone, format, refusing)
gains; knowledge-dependent work loses. This application already answers the
knowledge-shaped questions **outside** the model — the clock, the sums, the
conversions, the news, the timer, the calendar, the routes — so the persona is
mostly not in the path where it does damage. That is an accident worth turning
into a stated rule, and worth checking the next time something is added.

**c. Six of ten dimensions are failure modes, and one is called *Artificial* with
*intrusive* and *annoying* in it.** This project's central bet — that knowing when
not to speak matters more than what is said — is what a factor analysis of 744
people's adjectives independently arrived at. That is a stronger endorsement than
anything in [others.md](others.md), and it means the ranking of work has been
right: the rate rule and the breakpoints **are** the personality.

**d. Medium, not high** (§4). A one-line `Persona` read into a prompt beside a
dozen other things is, by accident, the setting that measured best. Do not make it
richer.

**e. Do not build personality adaptation** (§5), **do not chase usage** (§8), and
**treat any request to make it warmer as a request to make it wronger** (§2) —
which is a sentence worth keeping, because it is the request users actually make.

**f. And the honest note.** Most of this is single studies, 50–150 people, English,
ten-minute tasks. The three findings I would bet on are §1 (162 personas, 9
models, and a second paper giving the mechanism), §2 (five model families,
consistent direction, capability controls) and §7's meta-analysis (162 studies).
The rest is the best guess available, which is not the same as knowing.

---

*Read in full: [Zheng et al., **When "A Helpful Assistant" Is Not Really
Helpful: Personas in System Prompts Do Not Improve Performances of Large Language
Models**](https://arxiv.org/html/2311.10054v3); [**Expert Personas Improve LLM
Alignment but Damage Accuracy**](https://arxiv.org/html/2603.18507v1);
[Ibrahim et al., **Training language models to be warm and empathetic makes them
less reliable and more sycophantic**](https://arxiv.org/html/2507.21919v1)
(published in [Nature](https://www.nature.com/articles/s41586-026-10410-0));
[Völkel et al., **Developing a Personality Model for Speech-based Conversational
Agents Using the Psycholexical Approach**, CHI
2020](https://arxiv.org/pdf/2003.06186); [**Vibe
Check**](https://arxiv.org/html/2509.09870v2).*

*Read as abstract or summary: [Cheng et al., **Sycophantic AI decreases prosocial
intentions and promotes dependence**,
Science](https://www.science.org/doi/10.1126/science.aec8352);
[**Psychological and behavioural responses in human-agent vs. human-human
interactions**](https://arxiv.org/abs/2509.21542) /
[Communications Psychology](https://www.nature.com/articles/s44271-026-00466-z);
[**Consistently Simulating Human Personas with Multi-Turn Reinforcement
Learning**, NeurIPS
2025](https://proceedings.neurips.cc/paper_files/paper/2025/hash/4c91443877f8388d8190c938ac5a4d4d-Abstract-Conference.html);
[**How AI and Human Behaviors Shape Psychosocial Effects of Extended Chatbot
Use**](https://arxiv.org/html/2503.17473v2);
[Spagnolli et al., **Similarity attracts, or does
it?**](https://www.sciencedirect.com/science/article/pii/S0736585325000243);
[**Language Cues for Expressing Artificial Personality: A Systematic Literature
Review**](https://dl.acm.org/doi/fullHtml/10.1145/3640794.3665559);
[**Effects of Proactive Dialogue and Timing**, CHI
2024](https://dl.acm.org/doi/full/10.1145/3613904.3642168);
[**Developer Interaction Patterns with Proactive AI**, IUI
2026](https://dl.acm.org/doi/10.1145/3742413.3789148).*
