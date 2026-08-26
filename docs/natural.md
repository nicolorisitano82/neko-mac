# Making the character natural: a second reading

[truelife.md](truelife.md) asked *when* a desktop companion should speak and
*what* it should remember, and 2.1 built the answers. This asks a different
question: given all that, what makes the thing on screen read as *someone*
rather than as a program with a good schedule.

It deliberately does not repeat the first reading. Interruption cost, memory
architectures, sycophancy, the parasocial risk and prompt injection are settled
there. What follows is the literature on **behaviour** — timing, reaction,
motion, gaze, distance, and the stability of a personality — and what each paper
implies for code that already exists in this repository.

## 0. The finding, before the details

Across five separate literatures the same answer keeps appearing, and it is not
the one a language model tempts you into: **naturalness lives in timing and
reaction, not in vocabulary.** Conversation runs on gaps of about 200 ms while
the utterances that fill them take over 600 ms to plan. Listeners are judged by
what they do *while* somebody is talking. Idle motion is believable in proportion
to how its variability is distributed, not how elaborate it is. A chatbot that
answers instantly is perceived as *less* human than one whose delay matches the
weight of what it says.

Neko 2.1 already answers in 0.42 seconds, speaks in a mood, and stops mid-word
when interrupted. Everything below is cheaper than any of those and closer to the
thing the user actually notices.

## 1. React before you answer

**What the literature says.** Inter-speaker gaps in ordinary conversation sit
around 110–130 ms median, with a mode near 200 ms, while producing an utterance
takes 600 ms or more — which means responders begin planning while still
listening and *launch* at the seam (Levinson & Torreira, 2015). Separately, the
listener is not silent: backchannels — a nod, an *mm*, a look — are cued by
prosody, above all a region of low pitch late in the speaker's utterance (Ward &
Tsukahara, 2000), and their **quantity, type and timing** each change how the
listener is perceived (Poppe et al., 2010/2011). Robots that respond to
backchannel-inviting cues produce more fluid interaction and more reported
rapport.

**What Neko does today.** Nothing until the sentence ends. The listener collects
partial transcriptions and shows them as text; the cat holds a pose. Reaction
begins when the answer does.

**What to change.** The cheapest naturalness win available in this codebase: an
**acknowledgement inside 200 ms of speech onset**, drawn from the sprite set
rather than from words — the alert pose, an ear, a head turn toward the pointer.
The partial-results callback already fires; today it only draws text.

**How to measure it.** Time from the first partial result to the pose change
(target: under 200 ms). Then the thing that matters: with acknowledgement on and
off, does anybody speak *over* the beat less often — i.e. does the cat stop
being talked past?

## 2. The answer's own tempo

**What the literature says.** Gnewuch et al. (2018) gave a chatbot response
delays scaled to the complexity of the message and of the reply. Dynamic delays
**increased perceived humanness and social presence, and satisfaction with the
interaction**; a typing indicator mitigated the cost of waiting, though mostly for
users new to chatbots, and in contexts where speed is expected (customer service)
delay still hurt. "Faster is not always better" is the title and the finding.

**What Neko does today.** 0.42 s to first words from Apple's model, with a
walking-paw spinner while it thinks. It is fast, and it is uniformly fast: a
one-word answer and a considered one arrive at the same speed.

**What to change.** Scale the *reveal*, not the computation: hold a short answer
for a beat proportional to its length before showing it, and let a long one start
streaming as it does now. The spinner already exists and is the typing indicator
the paper describes. The rule cuts the other way for anything factual — the time,
the battery — where fast is the whole point.

**How to measure it.** Two builds, twenty questions, same engine: which one gets
called quicker, and which one gets called more considered. This is a preference
question, so it needs a person, not a harness.

## 3. Idle life: pink noise, not uniform random

**What the literature says.** Believable-agent work from the Oz project onward
(Bates, 1994; Loyall, 1997) treats *appropriately timed* behaviour as the core
requirement, borrowing straight from the twelve principles of animation (Thomas &
Johnston, 1981). The modern quantitative version: procedural eye and head motion
built on **pink (1/f) noise** — microsaccadic jitter, pupil unrest — is judged
highly natural, while the same motion with no jitter, or with unfiltered white
jitter, is consistently picked as *least* natural (Duchowski et al.; Peters &
Qureshi's head-movement propensity model). A 2026 study of idle animation found
viewers cannot tell genuine idling from acted idling, but *can* tell
motion-captured from handmade at well above chance — the tell is not the
craftsmanship, it is the statistics.

**What Neko does today.** A 0.125 s tick; rests drawn as
`NekoRoamMinRest + arc4random_uniform(NekoRoamRestSpread)` — uniform,
memoryless, flat-spectrum. The comment in the source says *"a different pause
each time, so it does not tick round like a metronome"*, which is the right
instinct and the wrong distribution: uniform randomness is as recognisable as a
metronome, just differently.

**What to change.** Drive the waiting times, and the choice of idle pose, with
1/f noise instead of a flat draw — a sum of a few octaves of random walks, twenty
lines of C. Same states, same art, different spectrum. And give the blink-like
poses a burst structure rather than an independent chance per tick.

**How to measure it.** Log pose onsets over an hour and plot the power spectrum:
flat before, 1/f after. Then the honest test, which is a person watching two
recordings and saying which cat is alive.

## 4. Where it looks, and how close it comes

**What the literature says.** Gaze is the most studied nonverbal channel in
virtual agents, and the review by Ruhland et al. (2015) is the map: gaze
direction signals attention, turn-taking and intention, and *aversion* signals
cognitive load — people look away while thinking, and an agent that does the same
reads as thinking rather than as frozen. On distance, Mumm & Mutlu (2011) found
that people who disliked a robot compensated for **increased gaze by keeping more
physical distance**, and disclosed less — attention is not free, and an agent that
stares is one people move away from.

**What Neko does today.** Direction comes only from motion: the sprite faces
where it is walking. Standing still, it faces wherever it last walked. The
curious antics walk *to* the pointer and sit there — head on, at zero distance.

**What to change.** Three small things, all inside `MyPanel`:
- Face the pointer when idle near it; face the frontmost window's edge when the
  remark is about that application. Attention is a direction, and this cat has
  eight of them.
- **Look away while thinking.** The thinking pose is currently a scratch;
  aversion during the wait is what the literature says a thinker looks like.
- Stop *short* when approaching, and approach from the side rather than
  head-on. Curiosity at arm's length rather than in the face.

**How to measure it.** Whether the curiosity questions get answered more often
when the cat stopped short — the rate machinery from 2.1 already records exactly
that verdict, which makes this the one item here with a free experiment attached.

## 5. A character that holds still

**What the literature says.** Personality can be measured in a language model's
output with real psychometrics: Serapio-García et al. (2023) established that
Big Five measurements of LLM output are reliable and valid **under specific
prompting configurations**, more so for larger, instruction-tuned models, and that
the traits can be shaped deliberately. And personality does not stay put: Li et
al. (2024) found **significant persona drift within eight rounds** of dialogue,
traced to attention decay over the growing context, with a lightweight mitigation
(split-softmax) and a benchmark for measuring it.

**What Neko does today.** A `Persona` line per character in the manifest, a mood
paragraph, and one trick that the drift literature would recognise: the language
instruction is repeated **last**, with a comment in the source saying *"the last
instruction is the one a model keeps"*. That was arrived at by measurement, and it
is the same mitigation.

**What to change.** Say the persona twice — once at the top as description, once
at the very end as a one-line reminder — the way the language rule already is.
And give each character an explicit trait profile rather than a prose sketch, so
that "Gandalf" and "Pinup" differ along stated axes instead of adjectives.

**How to measure it.** The drift benchmark, in miniature: thirty turns of the
same conversation, ten stable questions asked at turn 1 and turn 30, and a count
of how much the wording and the register moved. `tests/voice.m` already measures
wording overlap between two moods; the same function measures drift between two
points in a conversation.

## 6. Mood should be appraisal, not a clock

**What the literature says.** The standard architecture in affective agents is
two-layered: short-lived **emotion** derived from appraising events (the OCC
model of Ortony, Clore & Collins), and a slower **mood** those emotions push
around — ALMA (Gebhard, 2005) is the canonical implementation, keeping emotion and
mood in a PAD space and letting either shape behaviour. The point of appraisal is
that the feeling follows from *what happened*, which is what makes it legible.

**What Neko does today.** Mood is a pure function of the hour, the weekday and
the day of the year. It is deterministic, it holds still between two questions,
and it is measurably not the same at 9am and 1am — all good properties. It is
also completely deaf to what happened.

**What to change.** The appraisal inputs already exist and are already recorded:
`NekoRate` knows whether the last remarks were **answered, let go, or waved
away**; `NekoMemory` knows the day. That is enough for a slow mood — a cat that is
a little more forward on a day when it has been answered, a little quieter after
being dismissed twice — layered *under* the existing clock, not instead of it.
The rate already changes its *frequency* from those signals; this changes its
*tone*, which is the missing half.

**How to measure it.** Deterministic: stage a week of verdicts and print the mood
line each day. Then check the thing that could go wrong — that it never reads as
sulking (see §7).

## 7. The line not to cross

**What the literature says.** Gray & Wegner (2012) put the uncanny valley
somewhere other than appearance: machines become unnerving when people ascribe
**experience** — the capacity to feel — rather than **agency** — the capacity to
act. A robot that seems to *act* is fine. A robot that seems to *feel* is
disturbing, and the effect holds even without a humanlike face.

**What this means here, concretely.** A cat that stretches, looks away, comes
closer, or goes quiet is displaying agency, and every one of those is fair game.
A cat that says *"I feel ignored"* is claiming experience, and that is the
direction the research says turns a pet into something people find creepy — quite
apart from being a manipulation of the person, which the parasocial section of the
first document already ruled out.

So the mood of §6 must express itself **in behaviour and register**, never in
claims about its inner life. Written as a rule for `NekoSense`, which already
throws away flattery: a line that asserts a feeling is a line to drop.

## 8. What to build, in order

Cheapest first, and each one has the measurement that decides whether it stays:

| | change | measure |
| --- | --- | --- |
| 1 | acknowledge speech within 200 ms, with a pose | latency from the first partial; whether people talk over it less |
| 2 | 1/f timing for idle waits and pose choice | the spectrum of pose onsets, flat → 1/f; then a person picking between two recordings |
| 3 | face what it is attending to; look away while thinking | answered-rate of curiosity questions, which 2.1 already counts |
| 4 | stop short and approach from the side | the same verdict counter |
| 5 | persona restated last, traits per character | drift over thirty turns, with `tests/voice.m`'s overlap measure |
| 6 | mood from verdicts, under the clock | a staged week printed; and no feeling-claims surviving `NekoSense` |
| 7 | reveal short answers on a human tempo | a person, twenty questions, two builds |

Items 1–4 are animation and timing: no model involved, no new permission, nothing
sent anywhere. Items 5–7 touch the prompt and want a person to judge them.

## 9. What the literature does not settle

1. **How much of this survives at 32×32 pixels and eight directions.** Every
   gaze and idle result above comes from faces with eyes, or robots with heads.
   A cat with no visible pupils has *direction* and *pose* and nothing else, and
   whether 1/f timing is perceptible through such a narrow channel is an
   empirical question this project would be answering, not applying.
2. **Whether a pet should be judged by rapport at all.** The virtual-agent
   literature measures rapport, trust and social presence, because its agents are
   assistants and interlocutors. A cat is furniture with opinions. It is possible
   that the right target is *not* being noticed — and there is no instrument for
   that in any of these papers.
3. **Appraisal without an audience.** OCC-style appraisal assumes events that
   matter to the agent's goals. This cat's goals are, honestly, nothing. Deriving
   a mood from "was I answered" is a thin theory of goals, and a defensible one,
   but it is a design decision dressed as a model.
4. **The interaction between §2 and 2.1's whole argument.** Slowing an answer
   down for naturalness spends the very thing the last release optimised — the
   sense that it is not in the way. Those two might simply be in tension, and only
   living with both settles it.

## Sources

- Levinson & Torreira, [*Timing in turn-taking and its implications for
  processing models of language*](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.00731/full),
  Frontiers in Psychology, 2015 — 200 ms gaps against 600 ms planning; see also
  [*Timing in Conversation*](https://journalofcognition.org/articles/10.5334/joc.268),
  Journal of Cognition, and Heldner & Edlund's corpus medians of 110–130 ms.
- Ward & Tsukahara, [*Prosodic features which cue back-channel responses in
  English and Japanese*](https://www.researchgate.net/publication/222686350_Tsukahara_W_Prosodic_features_which_cue_back-channel_responses_in_english_and_japanese_Journal_of_Pragmatics_23_1177-1207),
  Journal of Pragmatics, 2000; Poppe et al., [*Backchannels: quantity, type and
  timing matters*](https://link.springer.com/chapter/10.1007/978-3-642-23974-8_25),
  IVA 2011, and [*Perceptual evaluation of backchannel strategies for artificial
  listeners*](https://link.springer.com/article/10.1007/s10458-013-9219-z), AAMAS.
- Gnewuch et al., [*Faster is not always better: understanding the effect of
  dynamic response delays in human-chatbot interaction*](https://aisel.aisnet.org/ecis2018_rp/113/),
  ECIS 2018; and [*"The chatbot is typing…" — the role of typing
  indicators*](https://aisel.aisnet.org/sighci2018/14/), SIGHCI 2018.
- Bates, [*The role of emotion in believable agents*](https://dl.acm.org/doi/10.1145/176789.176803),
  CACM 1994; Loyall, [*Believable Agents: Building Interactive
  Personalities*](https://www.cs.cmu.edu/Groups/oz/papers/CMU-CS-97-123.pdf),
  CMU 1997; Mateas, [*An Oz-centric review of interactive drama and believable
  agents*](https://eis.ucsc.edu/papers/CMU-CS-97-156.html_.pdf), 1997.
- Peters & Qureshi, [*A head movement propensity model for animating gaze shifts
  and blinks of virtual characters*](https://www.sciencedirect.com/science/article/abs/pii/S0097849310001408),
  Computers & Graphics, 2010; pink-noise jitter and its perceptual evaluation;
  Landa et al., [*Evaluating idle animation believability: a user
  perspective*](https://arxiv.org/html/2509.05023), 2026 — genuine versus acted
  idling is indistinguishable, motion-captured versus handmade is not.
- Ruhland et al., [*A review of eye gaze in virtual agents, social robotics and
  HCI*](https://onlinelibrary.wiley.com/doi/10.1111/cgf.12603), Computer Graphics
  Forum, 2015.
- Mumm & Mutlu, [*Human-robot proxemics: physical and psychological distancing in
  human-robot interaction*](https://dl.acm.org/doi/10.1145/1957656.1957786),
  HRI 2011.
- Serapio-García et al., [*Personality traits in large language
  models*](https://arxiv.org/abs/2307.00184), 2023, and the [*psychometric
  framework*](https://www.nature.com/articles/s42256-025-01115-6) in Nature
  Machine Intelligence, 2025.
- Li et al., [*Measuring and controlling persona drift in language model
  dialogs*](https://arxiv.org/abs/2402.10962), 2024 — drift within eight rounds,
  attention decay, split-softmax.
- Ortony, Clore & Collins, *The Cognitive Structure of Emotions*, 1988 (the OCC
  model); Gebhard's ALMA and the layered emotion/mood architecture, surveyed in
  [*Computational emotion models: a thematic
  review*](https://link.springer.com/article/10.1007/s12369-020-00713-1),
  International Journal of Social Robotics, 2021.
- Gray & Wegner, [*Feeling robots and human zombies: mind perception and the
  uncanny valley*](https://www.sciencedirect.com/science/article/abs/pii/S0010027712001278),
  Cognition, 2012.

Everything said above about *this* app — the 0.125 s tick, the uniform rests, the
mood's inputs, the verdicts already recorded, the language rule repeated last —
was read out of the working copy while writing this, not remembered.
