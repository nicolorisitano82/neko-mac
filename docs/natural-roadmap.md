# Natural-character roadmap

The order of work from [natural.md](natural.md), chosen for what can actually be
built and checked in this codebase rather than for what reads best in a document.
Every step is small enough to ship alone, and every step names the number that
decides whether it stays.

## Why this order

Two rules did the sorting.

**Cheap and self-contained first.** Steps 1 to 4 are animation and timing: no
model, no new permission, nothing sent anywhere, no localisation, and no change to
a single sentence the cat says. They are also where the literature says most of
the perceived naturalness lives, which makes them the best ratio of effort to
effect in the whole document.

**Anything that touches the prompt comes after them**, because the prompt is
shared with the answers, the remarks and the reflection, and a change there has to
be measured against all three. The one change that is in open tension with the
last release — slowing answers down on purpose — comes last, alone, so it can be
abandoned without disturbing anything else.

Two of the early steps have a free experiment attached: 2.1 already records
whether an unasked remark was **answered, let go, or waved away**. That counter is
the only real instrument in this project for "did the cat land better", and steps
3 and 4 can be judged by it without asking anybody anything.

## 1. Acknowledge before answering

**Why first.** The cheapest thing in the document and the one a person notices
immediately: today the cat does nothing at all until a sentence is finished.
Conversational gaps in human speech run 110–130 ms while the reply takes 600 ms
or more to plan — the listener's *reaction* is what fills that, and there is a
whole literature on backchannels being cued, timed and judged.

**Build.** In `NekoAsk`, the partial-results callback already fires while somebody
is still talking; today it only draws text. Change the pose the moment the first
partial arrives — alert, turned toward the pointer — and again at the end of the
sentence. Nothing else moves.

**Measure.** Latency from the first partial result to the pose change; target
under 200 ms, which is generous given the callback is already on the main thread.
Then the thing that matters, from the diary: does the count of remarks answered
during the listening beat go up.

**Risk.** A cat that twitches at every stray noise the recogniser picks up. The
guard is the one already in `NekoSense`'s neighbourhood: only react to a partial
with actual words in it.

**Effort.** An afternoon.

**Done.** Two poses where there was one. Opening the microphone now sits the cat
down — the bubble already says *Listening…*, and the pose no longer says anything
more than that — and the **first partial result with words in it** puts its ears
up, in both places the app listens: a question, and the moment it holds the
microphone open after speaking.

| | measured |
| --- | --- |
| app's share of the reaction, question | **0.7 ms** |
| app's share of the reaction, the beat after it speaks | **1.0 ms** |
| the gap a person leaves between turns | 110–130 ms |

Three things it does not do, each tested: it does not react to the empty partials
the recogniser reports before anybody speaks; it does not react again for the rest
of the sentence, which would be a twitch per word; and it does not lose the sign
that says the microphone is open.

**What could not be measured.** The recogniser's own latency, from somebody
starting to speak to the first partial arriving. A test binary cannot be granted
a microphone — measured in this project before: TCC kills an auxiliary executable
inside a bundle the moment it asks for anything private — so the numbers above are
the app's share of the wait and not the whole of it. The literature's target is
the whole of it, and whether SFSpeechRecognizer leaves room inside 200 ms is a
question for the app on a real desk.

## 2. Pink noise instead of a flat draw

**Why second.** Same reason: no model, no words, and the literature is unusually
concrete — procedural motion driven by 1/f noise is judged natural, the same
motion with no jitter or with white jitter is picked as *least* natural.

**Build.** A small generator — Voss-McCartney, a sum of a few octaves of random
walks, about twenty lines — and then use it in two places in `MyPanel`: the roam
rest (`NekoRoamMinRest + arc4random_uniform(NekoRoamRestSpread)` today) and the
choice of which idle pose comes next. Same states, same art, different spectrum.
Give the blink-like poses a burst structure while there: two or three in quick
succession, then nothing for a while.

**Measure.** This one is honestly measurable without a person: generate ten
thousand rests, take the power spectrum, and check the slope moves from flat
toward −1. Then log real pose onsets for an hour of roaming and do the same. A
harness can assert the slope; a person decides whether it reads as alive.

**Risk.** 1/f noise clusters, which means longer long pauses — a cat that looks
switched off. Cap the tail at the current maximum rest and check the histogram
still has nothing beyond it.

**Effort.** A day, most of it the spectrum test.

**Done, and the plan was wrong about where the metronome was.** The roaming rest
was at least drawn from something. The idle chain — the poses the cat cycles
through when the pointer stops — was on **fixed counts**: four ticks sitting, ten
playing, four scratching, six yawning, then asleep. Every time, identically, since
1989. That is where "it ticks round like a metronome" was literally true.

`NekoNoise` is Voss-McCartney: eight random walks, each redrawn half as often as
the one before, added together, with its own generator so a test can replay the
same afternoon twice. Measured over 4096 values against the flat draw it
replaces:

| | pink | the flat draw |
| --- | --- | --- |
| slope of the power spectrum | **−0.80** | 0.07 |
| what one value says about the next | **0.75** | −0.01 |
| spread | 0.236 | 0.287 |

Adding eight uniform draws narrows the result toward the middle, and a cat whose
pauses are all nearly average is not the point — so the values are stretched back
out around the centre by a factor of 2.4, which brings the spread to within a
sixth of the flat draw's while keeping the slope. That constant was measured, not
guessed.

The chain now keeps its old averages and stops keeping its old counts:

| pose | was | is now |
| --- | --- | --- |
| sitting | 4 ticks | 2–6, mean 4.2 |
| playing | 10 | 6–13, mean 9.6 |
| scratching | 4 | 2–6, mean 4.2 |
| yawning | 6 | 4–8, mean 6.3 |
| scratching a wall | 10 | 6–14, mean 10.4 |

And scratching now comes in bursts about one time in six, because blinking does
and one scratch every time is the tell.

**Found while building it.** Wall-scratching shared its fixed count with the
playing pose, so a careless edit gave it a dwell drawn for a different pose — it
is on the list properly now. Nothing waits for ever: every value is bounded by
construction, which is the answer to the risk above, and the histogram is checked
for it.

## 3. Face what it is attending to

**Why third.** With eight directions and no eyes, orientation is the only
attention signal this character has, and it is currently a side effect of walking.
Gaze is the most studied nonverbal channel in virtual agents; aversion is what
thinking looks like from outside.

**Build.** `MyPanel` gains one method — face a point, picking the nearest of the
eight directions — and three callers: face the pointer when idle near it, face the
front window's side when the remark is about that application, and face *away*
while the model is thinking, replacing the scratch pose that stands in for it now.

**Measure.** The verdict counter: answered rate for curiosity questions and
remarks, a week before and a week after. Plus a harness assertion that the
direction chosen is the nearest of eight to the true angle, for a couple of dozen
staged angles.

**Risk.** Staring. The proxemics literature is blunt about it: more gaze from an
agent somebody has not warmed to buys more distance and less disclosure. Aversion
while thinking is part of the mitigation; the rest is not facing the pointer
constantly.

**Effort.** A day.

**Done, and the plan did not survive looking at the art.** Before writing any of
it the sprites were opened and enlarged. Two of the three things this step
promised turned out to be impossible or already true:

- **Facing without moving cannot be done with these frames.** The eight
  directional poses are a *gallop* — the cat stretched out mid-stride — because
  oneko never needed a standing pose that faces sideways. Frozen, one of them
  reads as a cat stuck, not a cat looking. The only pose that faces the viewer at
  rest is the sitting one, and the only alert pose is sitting up with its ears
  twitching. So orientation here can only be said by *moving*: attention is a
  step, not a stare.
- **Looking away while thinking is already true.** The thinking pose is the cat
  scratching its own ear with its eyes shut. That is aversion, arrived at in 1989
  for other reasons. Nothing to build.

So what was built is `turnToward:` — a step or two toward whatever it is
attending to, ending sitting up alert — called when a question starts and before
an unasked remark, with the words waiting for the turn to finish because a bubble
is placed against the cat's frame and speaking mid-step would leave it behind.

| | measured |
| --- | --- |
| direction chosen, over eight staged angles | **8 of 8** correct |
| distance travelled toward a target 800 points away | **29 points** |
| something inside the stopping radius | no turn, no pose change |

**The mistake worth recording.** The first version stepped 44 points; the radius
at which the cat considers itself arrived is 48. It set off and stood still,
insisting it was on its way — and three of the eight directions passed anyway
because the vertical reference point was half a sprite out, which made those
distances just long enough to move. Both are fixed, both are in the test, and the
step is now derived from the stopping radius rather than from a number that looked
about right.

**What still needs a week rather than a harness.** Whether any of this raises the
answered rate. The counter is there; the week is not.

## 4. Stop short, and come in from the side

**Why fourth.** The curious antics currently cross the screen and sit *on* the
pointer. Personal space applies to a 32-pixel cat more than it seems to: the
approach is the part people react to.

**Build.** In `NekoAntics`, the errand target becomes a point 60 to 90 pixels
from the pointer at an angle off the direct line, rather than the pointer itself;
and if the person keeps typing after it arrives, it withdraws instead of waiting.

**Measure.** The verdict counter again, and a harness check on the geometry: never
closer than the radius, angle inside the intended band, and a withdrawal when
typing continues.

**Risk.** A cat that never quite arrives reads as broken rather than polite. The
number to watch is whether anybody still notices it came over at all — which is
the answered rate.

**Effort.** Half a day.

**Done.** The curious antics stop 60 to 90 points short of whatever they came to
look at, and 40 to 70 degrees off the line they walked in on — either side,
varied through the same pink-noise stream as everything else. Measured over 500
staged approaches: distance 60–90 every time, angle 40–70 every time, both sides
used, and a thing in the corner of the screen does not push the cat off the edge.

One antic was left alone on purpose: pouncing on the cursor still lands on the
cursor, because pouncing *beside* it is not pouncing.

**And it can change its mind on arrival.** Typing hard is what sends the cat over
in the first place, so it may well still be happening when it gets there. If it
is, the cat says nothing and leaves — and because nothing was said, nothing counts
against the day's remarks either. That was a visit, not an interruption.

**What needs a person.** The withdrawal itself: it wants somebody typing hard at
the moment the cat arrives, which is a desk and not a harness. And the question
the whole step exists for — whether stopping short reads as tact or as a cat that
never quite arrives — is the answered rate over a week.

## 5. A persona that survives thirty turns

**Why fifth.** First step that touches the prompt. Persona drift is measurable and
arrives within eight rounds of dialogue, from attention decay over a growing
context; the mitigation that this codebase already uses for the language rule —
say it last, because the last instruction is the one a model keeps — is the same
one the paper reaches for.

**Build.** Append a one-line persona reminder at the very end of the
instructions, after the language rule. And replace the prose `Persona` in the
character manifests with a short trait profile for a few characters, keeping the
prose as a fallback so the other forty still work.

**Measure.** Thirty turns of one conversation, the same ten questions asked at
turn 1 and turn 30, and the shared-wording measure `tests/voice.m` already has,
comparing register rather than content. The number to beat is whatever the current
build scores; the paper's finding says it will be bad.

**Risk.** A longer instruction block, which the measured history of this project
says is exactly how a small model gets worse. Watch the 4B, not Apple's model.

**Effort.** A day, plus the drift test.

## 6. Mood from what happened, and no claims about feelings

**Why sixth.** The two halves belong together: appraisal gives the mood something
to follow, and the filter keeps it from turning into an assertion about an inner
life. Machines are unnerving when people ascribe *experience* to them rather than
agency — a cat that goes quiet is fine, a cat that says it feels ignored is the
uncanny direction and a manipulation besides.

**Build.** `NekoVoice` reads the counters `NekoRate` already keeps and derives a
slow offset — a little more forward on a day that has been answered, a little
quieter after being waved away twice — layered under the existing time-of-day
mood, not replacing it. And `NekoSense` gains one more rejection: a line that
asserts a feeling in the first person.

**Measure.** Deterministic for the first half: stage a week of verdicts and print
the mood line each day, checking it moves and stays inside its band. Table-driven
for the second: a dozen staged lines in four languages, half of them feeling
claims, none of the ordinary ones caught.

**Risk.** Sulking. A quieter cat after being ignored is either tactful or
passive-aggressive, and this is the same open question the rate raised in 2.1 —
which is an argument for keeping the offset small and the band narrow.

**Effort.** A day and a half.

## 7. The tempo of an answer

**Why last, and why alone.** Response delays scaled to the weight of a reply
raise perceived humanness, social presence and satisfaction — and this app spent
the last release making sure it was never in the way. Those two goals are in
tension, and this step is where the tension gets tested rather than argued about.

**Build.** Hold a short answer for a beat proportional to its length before
revealing it, while long answers keep streaming as they do now. The spinner is
already the typing indicator the literature describes. Anything factual — the
time, the date, the battery — is exempt: there, fast *is* the answer.

**Measure.** A person, twenty questions, two builds, blind: which one felt
quicker, which one felt more considered. There is no harness for this one and
pretending otherwise would be the wrong kind of tidy.

**Risk.** It makes the app worse and the paper still right — the finding comes
from chat, where waiting is the norm, and a desktop pet may be exactly the context
where speed is expected. Abandonable in one revert, which is why it is last.

**Effort.** Half a day to build, a week of living with it to judge.

## What is deliberately not on this list

Eyes, a face, or any change to the sprite art — the whole point is that the
existing eighteen poses are enough. Emotion claims of any kind (see step 6). A
model in the loop for animation timing. Anything that needs a permission the app
does not already have. And the thing the literature would suggest next and this
project should not do: expressive *speech* synthesis with prosody, which on a
32-pixel cat would land somewhere between uncanny and comic.

## The honest caveat

Every gaze, idle-motion and proxemics result behind steps 2 to 4 comes from faces
with eyes or robots with heads. Whether any of it is perceptible through eight
directions and a 32-pixel sprite is a question this project would be *answering*,
not applying. That is a reason to do the cheap ones first and to keep the
measurement honest — not a reason to skip them, since if it turns out invisible,
one afternoon and a day are the whole cost.

## Progress

- [x] 0. The reading — [natural.md](natural.md), and this roadmap
- [x] 1. Acknowledge before answering — measured below
- [x] 2. Pink noise instead of a flat draw — measured below
- [x] 3. Face what it is attending to — became *turn* toward it; measured below
- [x] 4. Stop short, and come in from the side — measured below
- [ ] 5. A persona that survives thirty turns
- [ ] 6. Mood from what happened, and no feeling claims
- [ ] 7. The tempo of an answer
