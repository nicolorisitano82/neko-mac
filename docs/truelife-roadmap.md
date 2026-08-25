# Truelife roadmap

The order of work, chosen rather than listed. [truelife.md](truelife.md) has the
reading and the decisions; this is what gets built, in which sequence, and how
each step is checked. Every step is small enough to ship on its own and to
abandon without stranding the ones before it.

## Why this order

The visible decision — a cat that speaks like a colleague, eight to fifteen times
a day rather than two or three — is the one thing that can make the app worse if
it lands first. Raising the rate without improving the timing is exactly the
failure the ambient-agent literature describes, and features that get that wrong
are switched off within a fortnight.

So the rate comes last, not first, and the two things that earn it come before:
**the engine that can say something worth hearing**, and **the timing that stops
it landing badly**. The diary follows, because a colleague who remembers is a
different animal from a colleague who does not, and because everything after it
(openings, moods, threads) needs a history to draw on. Answerability comes next,
since it is what makes a higher rate legitimate. Only then does the rate move.

## 1. One notion of "the best engine on this Mac"

**Why first.** Everything else in this document produces text, and the measured
truth is that a 1.5B model cannot carry it: the same instructions Apple's model
handles turned it into a machine that answered `IMAGE:` to the time of day. And
the diary decision needs a rule in code, not a promise in a document: remote
engines answer questions and never see memory.

**Build.** A single place that answers two questions: which provider should speak
unprompted, and is it good enough to bother. Apple Intelligence when available;
otherwise a local model of about 2 GB or more; otherwise nothing, and the cat
keeps its written-in lines. Remote providers are never eligible. The Suggestions
tab says which one is being used, and says plainly when the answer is "none good
enough".

**Measure.** With each of the four installed engines in turn: what the resolver
picks, and that a remote provider is never picked for an unprompted line even
when it is the one chosen for questions.

**Risk.** Silently overriding the user's choice of engine. Mitigated by saying it
out loud in the tab: the setting governs questions, the on-device rule governs
what the cat says on its own.

**Done.** `NekoBrains` answers both questions in one place. Measured on this Mac,
with three models on disk (1.5B at 1.04 GB, Gemma 3 4B at 2.32, Qwen3 4B at
2.33) and Apple Intelligence available:

| engine set for questions | engine that speaks unprompted |
| --- | --- |
| Apple Intelligence | Apple Intelligence |
| a model on this Mac (1.5B) | Apple Intelligence |
| ChatGPT | Apple Intelligence |
| Claude | Apple Intelligence |
| a Shortcut | Apple Intelligence |

No remote provider is reachable from that path by construction. The question
setting is left exactly as it was — checked after the run: still the 1.5B. With
Apple unavailable the fallback resolves to Qwen3 4B Instruct, the largest
installed model above the threshold, and the local provider honours a preferred
model without touching the preference: asked for the 4B it returns the 4B, asked
for a model that is not installed it falls back to the chosen one rather than
failing.

## 2. Breakpoints, and a bar to clear

**Why second.** This is the step that makes the rate survivable, and it is
measurable without any of the later work.

**Build.** `NekoDesktop` learns to recognise a breakpoint from what it already
sees — an application switch after a long stretch in one place, a burst of typing
that has just ended, a few seconds of idleness after activity — and to name how
coarse it is. The advisor stops treating the interval as a trigger: it becomes a
floor, and the remark also needs a breakpoint plus something specific to say.
Alongside it, the states where nothing is ever said: screen sharing, a
full-screen video, Do Not Disturb, a password field in front.

**Measure.** Remarks per working hour before and after. Whether typing resumes
within a few seconds of a remark, which is our cheap stand-in for resumption lag.
And that the never-interrupt states are honoured, tested by faking each one.

**Risk.** Over-filtering into silence — a cat that never finds a good moment. The
answer is the floor-not-trigger rule: if nothing has been said for much longer
than the interval, a coarser breakpoint will do.

## 3. The diary, and the reflection

**Why third.** It is the largest piece and the one that changes what the cat can
be, but it is worth nothing until 1 and 2 stop it from being read out at bad
moments.

**Build.** A plain-text file per day under Application Support: what was noticed,
what was said, what the person answered. A nightly pass that reduces yesterday to
at most a handful of durable lines. Retrieval into a prompt that stays inside the
budget we measured. A thirty-day window, a "forget this" that works on a line,
and a button that deletes the lot. Nothing about it goes to a remote engine.

**Measure.** Ask it what you were doing yesterday afternoon and check the answer
against the file. Contradict a remembered fact and check the old one stops being
repeated. Confirm the prompt with memory in it stays under the token budget with
the 4B model and does not crash the 1.5B.

**Risk.** A file recording someone's day. Mitigated by being readable, bounded
and deletable — and by never leaving the machine.

## 4. Answerable: a beat of listening, barge-in, and one typed line

**Why fourth.** A remark you cannot reply to is a notification. This is what
makes eight a day a conversation instead of eight interruptions, and it needs the
diary to make a follow-up mean anything ("it" has to resolve to something).

**Build.** After the cat speaks, keep listening for a few seconds with a visible
sign of it, so a reply needs no keystroke. While it is speaking, a word from you
stops it. Holding the keystroke opens a single line beside the cat for answering
with hands instead of voice.

**Measure.** Time from the end of an answer to the microphone being live. Whether
a barge-in stops the voice within a couple of hundred milliseconds. Whether a
follow-up that says "and the other one?" resolves against the previous turn.

**Risk.** An open microphone for longer than people expect. It has to be visible
while it lasts and short by default.

## 5. The rate itself, and an interval that moves

**Why fifth.** Only now is it safe. The rate rises to the colleague band, and the
interval stops being a constant: it widens when remarks are ignored and narrows
when they are answered, with the user's setting as the ceiling it never crosses.

**Measure.** A week of real use: remarks a day, how many were answered, and
whether the interval settles somewhere sensible on its own.

**Risk.** Feeling passive-aggressive rather than tactful. Open question, and the
only honest test is living with it.

## 6. Voice: register, openings, moods, and no flattery

**Why last.** It is the polish that makes the rest sound like someone, and it can
be tuned continuously once the machinery underneath is stable.

**Build.** Openings and closings that know the history — first launch of the day,
after a week away, late at night. A mood that drifts with the time and the day so
the same question does not come back in the same words. And the anti-flattery
pass: no compliment openers, no second sentence restating the first, rejected in
`NekoSense` when the instructions fail to prevent it.

**Measure.** The same twenty questions at 9am and at 1am, checked for repeated
wording. A count of banned openers across fifty generated lines.

**Risk.** Personality drifting into shtick. The five-line limit and the spelling
filter both help; the rest is taste.

## What is deliberately not on this list

A chat window. Modelled emotions with a face. Continuous screen reading. Memory
in the cloud. Anything that lets text read from the screen reach an action —
which is also getting a test that fails if it ever becomes possible.

## Progress

- [x] 0. The reading, the decisions, this roadmap
- [x] 1. One notion of the best engine on this Mac — `NekoBrains`, measured below
- [ ] 2. Breakpoints, and a bar to clear
- [ ] 3. The diary, and the reflection
- [ ] 4. Answerable
- [ ] 5. The rate itself
- [ ] 6. Voice
