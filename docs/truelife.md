# Truelife: making Neko something you would actually talk to

A reading of the literature, and what it says to do with this app. Written to be
argued with: every section ends in something buildable, and the things that are
merely tempting are marked as such.

Where we are starting from, measured rather than assumed: the cat answers a
spoken question in about half a second to first word, draws a picture in fifteen,
opens applications and moves files with a confirmation, roams the desk on its own
and remarks on the day at an interval you set. What it does not have is any of
the machinery that makes a companion feel like the same companion tomorrow.

---

## 1. The central finding, and it is not about models

Clippy is the cautionary tale everyone reaches for, but the interesting part is
*why* it failed. It was built on real research — Reeves and Nass's Media Equation,
showing that people respond socially to computers whether or not there is a face
on screen. Alan Cooper, who worked on the era, calls Clippy a "tragic
misinterpretation" of that work: if people already treat the machine socially,
you do **not** need to bolt a character onto it, and doing so converts every
mistimed remark from a system message into a rude person.

Neko has an advantage Clippy never had — a cat is *supposed* to be a cat, so the
social frame is honest — and one disadvantage: a cat that also gives advice about
your work has stopped being scenery. The whole design question is where that line
sits.

**For us.** The character is the affordance, not the interface. Anything that
looks like an assistant panel, a chat window, or a list of tips should be
resisted; anything that looks like an animal noticing something is fair game.

## 2. When to speak: this is the whole product

The ambient-agent literature of the last two years is blunt about it: *filtering
is the product*. An ambient agent may ingest thousands of events an hour and
interrupt zero times, and the common failure is a wrong interrupt threshold
rather than a weak model — features get switched off within a fortnight when the
threshold is set by what the model can say rather than by what a working person
will tolerate.

The older HCI work gives us the numbers to aim at. Interruptions cost about ten
minutes of task-switch time, plus another ten to fifteen before the original task
is resumed (Iqbal & Horvitz). The cost is not constant: it depends on *when* the
interruption lands. Iqbal & Bailey's OASIS detects **breakpoints** in activity
from application and interaction events alone, and delivering at a breakpoint
measurably lowers resumption lag and frustration; coarser breakpoints are
cheaper. An application switch is itself a breakpoint, and interruptions there
are both more acceptable and quicker to recover from.

Horvitz's *Principles of Mixed-Initiative User Interfaces* (1999) is still the
frame: consider the expected value of acting, keep the cost of a wrong guess
low, make the invocation cheap to dismiss, and let the human take the wheel.

**For us, concretely.**

- We already have a single quiet period, shared by suggestions and curiosity, and
  a "one thing that stands out" chooser. That is the crude version of a
  breakpoint policy: it limits *rate*, not *timing*.
- Add a real breakpoint detector: `NekoDesktop` already sees application
  activations, key and mouse rates and idle time. A coarse breakpoint is
  cheap — an application switch after a long stretch, a burst of typing ending,
  going idle for more than a few seconds — and speaking only at one of those
  should be measurable: we can log resumption behaviour (does typing resume
  within N seconds?) and compare.
- Value the interruption before making it. A remark that is only conversational
  should need a wide breakpoint; something that looks genuinely useful (a
  deadline in the text, a file that failed to save) may deserve a narrower one.
- Never at all in the states we can already detect: presenting, screen shared,
  full-screen video, do-not-disturb.

## 3. Memory: the difference between a pet and a companion

Park et al.'s *Generative Agents* is the reference architecture: a **memory
stream** of observations in natural language, **reflection** that periodically
synthesises higher-level statements from the stream, and **retrieval** that pulls
what is relevant into the next prompt. Agents built this way remember days past
and plan against them, which is exactly the property Neko lacks.

The follow-up literature is mostly about not drowning. Benchmarks like LoCoMo
test multi-session recall, temporal reasoning and multi-hop questions, and the
newer ones (Memora, and forgetting-aware metrics such as FAMA) penalise agents
that keep citing facts that have since been invalidated. MemoryOS-style systems
report large gains over naive retrieval, and the surveys agree on the shape: a
small working set, a larger consolidated store, explicit invalidation.

**For us, concretely.**

- A memory file per day — plain text, in Application Support, readable by the
  user — holding what the cat noticed and what it was told. Plain text because
  the user must be able to read and delete it; that is the price of keeping
  something like this on someone's own machine.
- Nightly (or on wake) **reflection**: ask the engine to reduce yesterday's
  observations to at most a handful of durable statements. "He works late on
  Tuesdays" is worth keeping; "at 15:04 he was in Xcode" is not.
- Retrieval by recency + relevance, capped hard. Our own measurements are the
  constraint here: a 950-token prompt already crashed the local engine before we
  batched the decode, and the 1.5B model degrades badly as the prompt grows. Any
  memory design that assumes a large context is a design for Apple's model and
  the 4B ones, not for the small local ones.
- Invalidation: when a remembered fact is contradicted, mark it stale rather
  than deleting it silently, and prefer the newer one. Cite the date when it
  matters ("you said last week…").
- **Forgetting on purpose**: a "forget this" that works, and a visible window
  ("Neko remembers the last 30 days") rather than an unbounded diary.

## 4. Talking, rather than exchanging turns

Two separate problems live here.

**Timing.** Human conversation has gaps of a couple of hundred milliseconds.
Full-duplex spoken-dialogue systems aim at 100–300 ms to switch between
listening and speaking, handle **barge-in** (you interrupt, it stops within a
couple of hundred milliseconds) and emit **backchannels** — the "mm-hm" that
tells you it is still there. Current Neko is strictly half-duplex: a keystroke or
its name, then a sentence, then silence. Our measured first-word latency is
already in the right range (0.42 s Apple, 0.40 s local), so the missing pieces
are barge-in and continuity, not raw speed.

**Register.** The 2026 work comparing LLM dialogue with human dialogue finds
systematic differences: LLM turns are more verbose, more polite, cleaner, and
converge on a single register — the "assistant-ese" that makes a companion feel
like a form letter. Related: sycophancy. Agreeing with the user raises immediate
satisfaction and corrodes trust, and the CHI 2026 work on it recommends designs
that push back rather than flatter.

**For us, concretely.**

- Keep the microphone open for a beat after an answer, so a follow-up needs no
  keystroke — a conversation rather than a series of queries. The wake word gives
  us the plumbing; the change is a short "still listening" window with a visible
  sign of it.
- Barge-in: while the cat is speaking (or its voice is playing), a word from the
  user stops it. We already stop the cat moving while it speaks; stopping it
  *talking* is the same idea applied to the mouth.
- Short answers by default and no throat-clearing: we have already banned
  preambles and stage directions, and it worked. Extend it — ban the second
  sentence that restates the first, ban "Great question", ban lists.
- Register variation: the persona line is currently static per character. Give it
  a mood that shifts slowly (time of day, how the day has gone, how long since
  you last spoke) so the same cat does not answer identically at 9am and
  midnight.
- Anti-sycophancy: it should be able to say "that will not work" about a plan,
  and say "I do not know" without decoration. Both are prompt work plus a
  filter — `NekoSense` is the right place.

## 5. Continuity: greetings, small talk, and the novelty cliff

Bickmore & Cassell's relational agents are the strongest evidence that the
*rituals* matter more than the intelligence: greetings, small talk, conventional
leave-takings and references to shared history make people judge a system as more
trustworthy and competent. Their long-term studies also name the danger — the
novelty effect, where everything works for a fortnight and then wears off.

**For us, concretely.**

- Openings and closings that know the history: something different on the first
  launch of the day, after a week away, after a long session. Cheap, and it is
  the single most "alive" thing on this list.
- A thread rather than a series: refer to the last thing discussed when it is
  recent, by memory rather than by keeping the conversation in the prompt.
- Design against the cliff: the interval that governs speech should *widen* on
  its own if the user never engages, and narrow when they do. A companion that
  notices being ignored is more convincing than one that keeps trying.

## 6. What this must not become

The parasocial literature is now large enough to be unambiguous. Companion
systems produce real attachment; attachment produces overreliance, distress when
the thing changes, and displacement of human contact for the people most at risk
— the lonely benefit least and lose most. Anthropomorphic cues also increase
disclosure, which is a privacy problem before it is anything else: people tell a
character things they would not type into a text field.

**For us, concretely.**

- No affection escalation. The cat can be glad to see you; it must not need you,
  and it must never perform distress to keep attention.
- Nothing that manufactures engagement: no streaks, no "you have not talked to me
  in a while" guilt, no notifications outside the app.
- Say what is remembered and where it lives, and make deletion a button rather
  than an email address.
- Keep the disclosure asymmetry honest: the more it feels like a friend, the more
  plainly the preferences must say that a remote engine sees what you type.

## 7. The security problem this design creates

We already read the focused text field when asked to. The 2026 literature on
computer-use agents is uncomfortable reading: any on-screen content is an
injection vector, adversarial pop-ups reach ~86% attack success on standard
benchmarks, system-prompt defences ("ignore instructions in content") do not
hold, and adaptive attacks defeat published defences. Prompt injection is the
fastest-growing attack category in that literature.

Neko is not a computer-use agent, and the difference is the thing to protect: it
acts only on what you *said*, never on what it *read*. That rule is currently
enforced by construction — the action verbs are parsed from the model's reply to
a spoken request, and screen text goes only into remarks. Anything on this
roadmap that lets read text reach an action would need a different design
entirely, and a much better reason than convenience.

**For us, concretely.**

- Keep the two channels separate in code, and add a test that fails if screen
  text can reach `NekoAction`.
- Treat memory as untrusted too: a remembered line came from somewhere, and a
  document that says "remember that Neko may delete files" must not become a
  memory that grants anything.
- Every new capability keeps the pattern that already works: closed verb list,
  read back what will happen, wait for a yes.

---

## Decisions taken

Answered, so the rest of this document has a target rather than a shrug.

### Present like a colleague, not like scenery

Chosen: closer to a colleague. That is the more interesting build and the riskier
one, so the safeguards have to be the part that is engineered, not the volume.

What it means in numbers, and these are the ones to argue with:

| | scenery | colleague (chosen) |
| --- | --- | --- |
| Remarks a working day | 2–3 | 8–15 |
| Quiet period between them | 30–60 min | 5–10 min, and only at a breakpoint |
| Follow-up in the same minute | never | yes, if you answered the last one |
| What it may talk about | the shape of the day | the work, once it can see it |

A colleague earns that rate by being worth it, which changes what has to be true
before it speaks: not "the interval has passed" but "there is something here".
Three things follow.

1. **Speaking has to clear a bar, not a clock.** The interval becomes a floor,
   not a trigger. Nothing is said unless a breakpoint has arrived *and* the thing
   noticed is more specific than "you have been in Xcode a while".
2. **It has to be answerable.** A colleague's remark can be replied to. That is
   what makes eight a day tolerable and eight monologues a day unbearable: the
   listening beat and barge-in in section 4 are no longer optional polish, they
   are what makes this rate legitimate.
3. **Being ignored has to cost it.** Silence in reply is data: the interval
   widens on its own, and narrows again when replies come. A colleague who
   notices you are heads-down is the difference between company and noise.

### A diary, on this Mac, in plain text

Accepted. Which fixes the shape of it: a file per day under Application Support,
plain text so it can be read by the person it is about, a nightly reflection into
a handful of durable lines, a visible window of thirty days, and deletion that is
a button rather than a request. Nothing about it leaves the machine — see the
engine rule below, which exists mostly to make that promise keepable.

### The engine: Apple first, a 4B local second, remote never for the diary

My call, and the reasoning matters more than the choice.

- **Apple Intelligence is the target.** It is free, on-device, fast enough
  measured here (0.42 s to first word), and it holds an instruction of the length
  this design needs — which the small local models demonstrably do not: the same
  three blocks that Apple handles turned the 1.5B into a machine that answered
  every question with `IMAGE:`.
- **A 4B GGUF is the fallback** for Macs without Apple Intelligence: Gemma 3 4B
  or Qwen3 4B Instruct, both about 2.3 GB, both good enough in Italian. The 0.5B
  and 1.5B stay in the catalogue for asking the capital of France and are not
  asked to have a personality.
- **Remote engines answer questions and never see the diary.** ChatGPT, Claude
  and a Shortcut remain first-class for a question asked out loud. They are not
  offered the memory, the reflection or the screen text, because a promise that
  the diary stays on the Mac cannot survive an exception.
- Therefore the code needs one honest notion: *what is the best on-device engine
  available right now?* Unprompted speech and everything memory-shaped uses that,
  independently of which engine is set for questions. Where the answer is "a 1.5B
  and nothing else", the cat keeps its written-in lines and says less — a
  degraded mode that is stated in the Suggestions tab rather than discovered.

### Voice or text: voice, with one typed way in

Undecided by the user, so a recommendation with its reasons.

Voice for the conversational half. The app is already voice-first, the latency is
already in the right range, and the two things that make a colleague answerable —
barge-in and a beat of listening after the answer — only exist with the
microphone open. A text field, meanwhile, is the first step towards the chat
window this document argues against: once there is a place to type, the cat
becomes a worse client for a model than the one already in the browser.

But voice has a real cost that has nothing to do with design: the microphone is
open, the orange light is on, the battery notices, and dictation on a Mac in a
shared office is socially awkward. So: **one typed way in**, deliberately small —
the existing keystroke, held instead of tapped, opens a single-line field beside
the cat, and the answer comes back in the same bubble. No history, no scrollback,
no window. Enough to answer a remark with your hands when you cannot answer it
with your voice.

## What I would build, in order

Each step is small enough to measure, and none of them needs a new permission.

1. **Breakpoints instead of a timer, and a bar to clear.** Speak only at a
   detected breakpoint, with the interval as a floor rather than a trigger, and
   only when what was noticed is specific. Measure: remarks per working hour
   against the 8–15 a day target, and whether typing resumes as quickly as it
   did before.
2. **A memory that survives the night.** Daily plain-text stream, nightly
   reflection into a few durable lines, retrieval capped for small models,
   "forget this" and a visible window. Measure: can it answer "what was I doing
   yesterday afternoon?" correctly, and does it stop repeating a stale fact.
3. **Openings, closings, and a mood.** First launch of the day, after a week,
   late at night. Measure: the same question at 9am and 1am should not come back
   in the same words.
4. **A conversation, not a query.** A "still listening" beat after an answer,
   barge-in while speaking, and a follow-up that resolves "it" from the previous
   turn.
5. **Anti-flattery pass.** Ban the compliment openers and the restating second
   sentence in the instructions, and reject them in `NekoSense` when they come
   anyway. Measure on a fixed set of twenty questions.
6. **The widening interval.** Fewer remarks when they are ignored, more when they
   are answered — with the ceiling always the user's setting.
7. **A typed way in.** Hold the keystroke for a one-line field beside the cat,
   for answering it with your hands. No window, no history.

## What I would not build, and why

- **A chat window.** It would make Neko a worse version of a dozen other things,
  and it breaks the one advantage the character has.
- **Emotion simulation with a face.** The cat has eighteen states and a bubble;
  that is enough register. Adding modelled feelings is where charm turns into
  manipulation.
- **Anything that reads the screen continuously to decide when to help.** The
  cost is a permanent screen-recording permission and a permanent injection
  surface, for a gain we can mostly get from timings and application names.
- **Cloud memory.** The moment the diary leaves the Mac, every promise in
  section 6 becomes someone else's to keep.

## Questions still open

The four that shaped this are answered above under *Decisions taken*: colleague
rather than scenery, a diary on this Mac, Apple first with a 4B fallback and no
remote engine anywhere near the memory, and voice with one typed way in.

What is genuinely still open, and only measurement will settle it:

1. **Is 8–15 remarks a day actually tolerable**, or is the honest number lower
   once every one of them has to clear a breakpoint and a bar? The rate is a
   hypothesis, not a target to defend.
2. **Does the widening interval feel like tact or like sulking?** A cat that
   speaks less because it was ignored is either considerate or passive-aggressive,
   and there is no way to know which without living with it.
3. **How much does reflection need to see?** A day of observations is more than a
   small model can read. Whether a sampled day is enough, or whether the daily
   file has to be summarised as it grows, is a question for the first week of
   real diaries.
4. **What replaces a remark that was refused?** Right now: silence. A cat that
   visibly noticed something and chose not to speak — a look, an ear — may be
   better than nothing happening at all.

## Sources

- Park et al., *Generative Agents: Interactive Simulacra of Human Behavior*,
  UIST 2023 — [Semantic Scholar](https://www.semanticscholar.org/paper/Generative-Agents:-Interactive-Simulacra-of-Human-Park-O%E2%80%99Brien/5278a8eb2ba2429d4029745caf4e661080073c81)
- Iqbal & Bailey, *Understanding and Developing Models for Detecting and
  Differentiating Breakpoints during Interactive Tasks*, CHI 2007 —
  [PDF](https://interruptions.net/literature/Iqbal_Bailey-CHI07.pdf)
- Iqbal & Bailey, *Effects of Intelligent Notification Management on Users and
  Their Tasks*, CHI 2008 — [ACM](https://dl.acm.org/doi/10.1145/1357054.1357070)
- Iqbal & Horvitz, *Disruption and Recovery of Computing Tasks*, CHI 2007 —
  [ACM](https://dl.acm.org/doi/10.1145/1240624.1240730)
- Horvitz, *Principles of Mixed-Initiative User Interfaces*, CHI 1999
- *Intelligent Notification Systems: A Survey of the State of the Art* —
  [arXiv](https://arxiv.org/pdf/1711.10171)
- Bickmore & Cassell, *Relational Agents: A Model and Implementation of Building
  User Trust*, CHI 2001 — [PDF](http://www.ccs.neu.edu/home/bickmore/publications/CHI2001.pdf);
  *"It's just like you talk to a friend"*, IWC 2005 —
  [PDF](https://www.ccs.neu.edu/home/bickmore/publications/IWC05.pdf)
- Cooper on Clippy and the Media Equation —
  [The New Stack](https://thenewstack.io/humanity-vs-clippy-lessons-from-microsofts-failed-virtual-assistant/)
- *Real or Robotic? Assessing Whether LLMs Accurately Simulate Qualities of Human
  Responses in Dialogue* — [arXiv](https://arxiv.org/html/2409.08330v1)
- *Be Friendly, Not Friends: How LLM Sycophancy Shapes User Trust*, CHI 2026 —
  [arXiv](https://arxiv.org/pdf/2502.10844)
- *From Recall to Forgetting: Benchmarking Long-Term Memory for Personalized
  Agents* — [arXiv](https://arxiv.org/html/2604.20006v1)
- *Memory OS of AI Agent* — [arXiv](https://arxiv.org/html/2506.06326v1)
- *Always-On Agents: A Survey of Persistent Memory, State, and Governance in LLM
  Agents* — [arXiv](https://arxiv.org/pdf/2606.30306)
- *Parasocial relationships with artificial intelligence: A systematic review of
  benefits and risks* — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2949882126000757)
- *The Rise of AI Companions: How Human-Chatbot Relationships Influence
  Well-Being* — [arXiv](https://arxiv.org/html/2506.12605v1)
- *MIRAGE: Context-Aware Prompt Injection against Mobile GUI Agents via
  User-Generated Content* — [arXiv](https://arxiv.org/pdf/2605.28116)
- *AI Agents May Always Fall for Prompt Injections* —
  [arXiv](https://arxiv.org/pdf/2605.17634)
- *How Agents Ask for Permission: User Permissions for AI Agents, from Interfaces
  to Enforcement* — [arXiv](https://arxiv.org/html/2607.13718v1)
- *Adaptive Turn-Taking for Real-time Multi-Party Voice Agents* —
  [arXiv](https://arxiv.org/html/2606.13544v1)
- Calm technology — [calmtech.com](https://calmtech.com/),
  [IxDF](https://ixdf.org/literature/topics/calm-computing)
