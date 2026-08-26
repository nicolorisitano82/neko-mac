# Changelog

## Unreleased

### It notices you starting to talk

A sentence used to reach the cat only when it was finished. In conversation the
gap between turns runs about a tenth of a second, while the reply behind it takes
six times that to plan — what fills the gap is the listener visibly reacting, and
that reaction is most of what makes somebody feel heard.

So there are two poses now where there was one. Opening the microphone sits the
cat down, since the bubble already says *Listening…* and the pose had no business
claiming more. The first words put its ears up — in both places the app listens:
a question, and the few seconds it keeps the microphone open after speaking.

Measured at 0.7 ms and 1.0 ms of the app's own time, against the 110–130 ms a
person leaves. It ignores the empty partials the recogniser reports before anybody
speaks, and reacts once per sentence rather than once per word. What could not be
measured here is the recogniser's share of that wait: a test binary cannot be
granted a microphone.

### Its timing drifts instead of scattering

The pauses were drawn from a flat distribution: every value as likely as every
other, each one independent of the last. The idle chain was worse than that — the
poses the cat cycles through when the pointer stops were on **fixed counts**, four
ticks sitting, ten playing, four scratching, six yawning, unchanged since the
original oneko. The comment in the source said the pauses were varied so it would
not tick round like a metronome, which was the right instinct pointed at the
wrong half of the problem.

Perceptual studies of procedural animation are unusually specific here: motion
driven by 1/f — pink — noise is judged natural, while the same motion with no
jitter or with white jitter is picked as the least natural of the three. The
difference is not the range of the values, it is that neighbouring values are
related.

So the waits now come from a stream that drifts. Measured over 4096 values: the
slope of the power spectrum moves from 0.07 to −0.80, and what one value tells you
about the next from −0.01 to 0.75, while the spread stays within a sixth of the
flat draw's. Each idle pose keeps its old average and loses its old count —
sitting 2 to 6 ticks against a fixed 4, playing 6 to 13 against 10 — and
scratching now comes in bursts about one time in six, because blinking does.

### It stops an arm's length short

The curious antics used to walk to the pointer and sit on it. People keep their
distance from something that attends to them, and the closer and more head-on the
attention, the more they compensate — so the cat now stops 60 to 90 points short
of whatever it came to look at, and 40 to 70 degrees off the line it walked in on,
either side. Measured over 500 staged approaches: every one inside both bands,
both sides used, and something in the corner of the screen does not push the cat
off the edge.

Pouncing on the cursor was left exactly as it was, because pouncing beside the
cursor is not pouncing.

And it can change its mind when it gets there. Typing hard is what sends it over,
so it may still be happening on arrival — if it is, the cat says nothing and
leaves. Nothing was said, so nothing counts against the day's remarks either:
that was a visit rather than an interruption.

### It turns toward you before it says anything

Attention, in a character, is mostly orientation — and this one had none: the
sprite faced wherever it last walked. So it now takes a step toward whoever it is
about to talk to, and sits up alert when it arrives: when a question starts, and
before a remark nobody asked for. The words wait for the turn, because a speech
bubble is placed against the cat and one placed mid-step would be left behind.

Two things the plan promised turned out not to be buildable, and the sprites said
so before any code was written. Facing without moving is impossible with these
frames: the eight directional poses are a gallop, and a frozen one reads as a cat
stuck rather than a cat looking. And looking away while thinking is already true —
the thinking pose is the cat scratching its ear with its eyes shut, which has been
aversion since 1989 for entirely different reasons.

Measured: the right direction in 8 of 8 staged angles, 29 points travelled toward
something 800 points away, and no fussing at all for anything already close. The
first version of it stepped 44 points when the radius at which the cat considers
itself arrived is 48, so it set off and stood still; the step is derived from that
radius now.

### The location button did nothing

Reported from real use: the row said “not asked yet” however often it was
pressed. It was asking macOS for a position and for permission in the same
breath, and CoreLocation answers a position request from an app nobody has
authorised by refusing it immediately — the request unwinds and the dialog never
gets its chance. Permission is asked for on its own now, and the position only
once there is an answer to act on.

Two smaller halves of the same bug. The location manager was being created for
one question and released afterwards, so it was never around to hear an answer
that arrives seconds later; it is kept for the app's life now. And the
Permissions tab was rebuilt on a timer a second and a half after the click, which
is well before anybody has finished reading a dialog — it is told now, by a
notification, and redraws when the answer actually arrives.

The order is what broke, so the order is what is tested: `tests/place.m` stands a
recorder in for CoreLocation and checks that nothing is asked of the system
before permission, that the position is asked for the moment permission arrives,
and that a refusal asks for nothing at all. A test may not ask for a real
permission — a refusal can only be undone in System Settings.

## 2.1 “truelife” — 2026-08-26

The codename is the branch this was written on, and the question it was written
to answer: how close can a cat on a desktop get to something worth talking to.
The reading behind it is in [docs/truelife.md](docs/truelife.md) and the order of
work in [docs/truelife-roadmap.md](docs/truelife-roadmap.md); both are honest
about what the literature says will fail.

The short version of that reading: the hard part is not the model. Interruptions
cost about ten minutes of task switching and another ten or fifteen before the
original work resumes, and the cost depends almost entirely on *when* they land.
So this release spends most of its effort on timing, memory and answerability,
and almost none on making the cat cleverer.

### It waits for a seam in your work

The interval in the preferences used to be a trigger: when it expired, the cat
spoke. Now it is a floor, and a remark also needs a seam — a program you have
just left after a long stretch, a return from a real break, a burst of typing
that has ended, a pause with work either side of it. Four seams, each measured on
its own, each lasting twelve seconds and then gone.

Two doors stay shut whatever the clock says: nothing specific to say, or a window
filling the screen while you present or watch something. Focus and Do Not Disturb
cannot be read at all — macOS keeps that state in a file no application may open
and publishes no API for it — so the full-screen check is the proxy, and the
preferences say so rather than implying otherwise.

### How often it speaks is a budget for a day

Replayed over one staged day, the old rule produced 19 remarks at the default
ten-minute interval and 9 at thirty — and exactly the same number whether every
remark was answered or every one was waved away. That is a notification with a
slider.

It now keeps three things: how many remarks today, how they landed, and how much
of the day was actually spent at the Mac. Answered is worth one more a day, let
go one fewer, clicked away two fewer. Over five staged days that settles at 15 a
day when everything is answered, 8 when half are, and 4 when none are. The
interval you set is still the ceiling on frequency: at once an hour, the day
produced 8 remarks and the closest two were 60 minutes apart.

When the day’s remarks are spent the cat still walks over, sits down and looks at
you, and leaves without saying anything.

### You can answer it

A remark you cannot reply to is a notification. So after the cat speaks the
microphone stays open for six seconds and the bubble says so, in as many words.
Speaking while it is still being read stops it: the bubble stops counting down
and the spoken voice is cut off mid-word in 5 ms. Silence closes the microphone
and says nothing at all.

It only does this where speech was already allowed for a question — a remark
nobody asked for is not an occasion to ask for a microphone — and there is a
switch beside the voice for people who do not want it.

Holding the same keystroke opens a line to type in instead, which is the half of
this that works in an open-plan office, in a meeting, and on a Mac where the
microphone was refused; that last case now falls back to it rather than
complaining.

And one turn of history goes into the next question, so a follow-up has something
to point at. Asked “And when?” after being told Tolkien wrote The Hobbit, Apple
Intelligence answers 1937; without that turn, it reads out the time.

### It keeps a diary, and reduces it every night

A plain-text file a day under Application Support: what it noticed, what it said,
what you said. Plain text because it is a file about a person — you can read it,
and delete it in the Finder if you do not trust the button. Thirty days, then the
old days go. Each night the previous day becomes at most four lines that would
still mean something on Monday; measured on a staged day, 2.0 s and four lines,
after the prompt learned to throw away “Xcode was open for forty minutes”.

The notes are written the way somebody writes in a margin rather than the way a
log writes — “notato build Xcode nuovo lenta, terza volta oggi” — which is 34%
fewer characters for the same information, and matters because every line is read
back to a model tomorrow. Negations, numbers, versions, times and names are never
dropped. The same note twice running is written once.

The diary reaches a model only through an engine that keeps it on this Mac, which
is checked in code for all five engine settings rather than promised in a
document. ChatGPT, Claude and a Shortcut answer questions and never see it.

### How it sounds

A mood that moves with the hour and the day, so the same question asked on Monday
morning and at one in the morning does not come back in the same words: measured,
20% of the wording shared between the two. An opening that knows when it last saw
you — the first time today, back after a week, one in the morning — and says
nothing at all the second time you start it in a morning.

And the assistant taken out of it: no compliment before the answer, no closing
sentence that says the opening one again. Asked for in the instructions and
removed in code when it arrives anyway.

### It can look something up

Asked what had happened today, a model answered “Oggi il tempo nel mondo è
incerto” — a confident sentence about a day it knows nothing about. Worse, the 4B
model this Mac is set to invented a headline: “Oggi a Milano è stato annunciato il
nuovo piano per la mobilità sostenibile.”

So the cat can now fetch one of two dozen feeds, every one of them tried and
counted first — and tried with this application’s own name on the request, since
a feed that answers a browser and refuses Neko is no use here. ANSA (ultima ora,
mondo, tecnologia, politica, cultura, sport), la Repubblica, Corriere della Sera,
Il Fatto Quotidiano, Il Sole 24 Ore (Italia and economia), RaiNews, Tgcom24, AGI,
La Gazzetta dello Sport, Wired Italia, DDay, Focus, MeteoAlarm’s warnings for
Italy, Hacker News, BBC News, The Guardian, The New York Times, NPR. Il Post is
the one that got away: 403 whatever it is asked with. The plain forecast comes
from open-meteo, because neither 3B Meteo nor meteo.it publishes a feed any more,
and the cat names the source in the answer.

**And it can know roughly where it is.** Two tiers: the time zone, which costs no
permission and is enough to know that “the news” means an Italian wire; and, if
you press the button for it on the Permissions tab, the town — one position from
macOS at the accuracy it calls reduced, turned into the name of a town and of a
region, which is all that is kept. There is nowhere in this app where a latitude
would be useful, and a file with somebody’s latitude in it is a different kind of
file. With that, “che tempo fa” needs no city named and “che notizie ci sono qui”
fetches the ANSA feed for your own region; all twenty of those were fetched
before they went in. Outside Italy there is nothing local to offer yet, and it
says so rather than guessing.

A model is shown eight names rather than twenty-four: an instruction that lists
two dozen words costs a small model more than the choice is worth, and the app
recognises the rest by itself.

Two rules make this safe enough to ship. **The model never names an address** —
only one of twelve words, decided in the app before any engine is consulted,
because a small model cannot be relied on to admit it does not know. And an
answer built on text fetched from the web **may not open, copy or move
anything**: a headline is written by a stranger, and there is a test that fails if
that ever stops being true.

The headlines are shown as they were written. Handed them to retell, the 4B
turned “la ceca Ce Industries” into “la Cecoslovacchia”; somebody else’s
sentences are not improved by a small model.

Off until you switch it on, in the Ask Neko tab.

### Words that do not exist

Reported from real use: the cat said "hai togliuto il file". There is no such
participle — a small model conjugating Italian by guesswork produces exactly
that, and no amount of instruction fixes it, because the model does not know it
is wrong.

macOS knows, though. Anything the cat says on its own is now checked against the
system dictionary in the language the app is running in, and a line containing a
word that does not exist is thrown away rather than said. Tried against a page of
real output: names and versions pass because a word with a digit or an inner
capital is not the dictionary's business — Xcode, TextEdit, Safari, dates,
numbers, colloquialisms all come through — while "togliuto" and "cazzuta" do not.

The grammar checker was tried too and left out: it accepts "il gatto sono andato
al mare" without complaint, so it would only cost time.

Two limits worth stating. Nonsense that is spelled correctly still gets through:
this catches an invented word, not an invented thought. And answers to questions
asked out loud are deliberately not filtered — dropping one would leave somebody
who asked something staring at a silent cat, which is worse than a clumsy
sentence.

### Smaller things, most of them found by a test

The preferences learned to check themselves: every pair of controls in every tab,
every paragraph against the space it was given, and — after a sixth permission
row pushed the last explanation nine points below the bottom edge — inside
whatever scrolls, too. The permissions list scrolls now. It found five Italian labels
that had been cut off for releases — the permissions summary, the drawing
explanation, the interval label — and one paragraph in the Suggestions tab short
of **424 points**, which is to say most of the page explaining what that feature
can see had never been readable. The two long paragraphs scroll now.

The typed line asked for the keyboard once, before activation had landed, which is
why it sometimes opened without focus; it asks again the moment the application
becomes active. An action-shaped line in a remark is thrown away rather than shown.
The diary’s thousand-character cap could be pushed to 1002 by the mark that says
it was cut.

### The measurements are in the repository now

Every number above came from a harness, and every harness used to live in a
temporary directory. They are in [tests/](tests) now — ten of them, run with
`tests/run.sh` — including the one this project had promised and never written:
`screen.m`, which fails if text read from a screen ever gains a route to an
action. Three things they cannot measure say so out loud instead of passing
quietly: Focus and Do Not Disturb, the microphone itself, and a real week of use.

## 2.0.3 — 2026-08-25

### It kept asking why you change programs so often

Because it was told to. The app works out the one thing that stands out and hands
it to the model, and the switch counter was both first in that list and easily
triggered: eight changes of front window in a quarter of an hour, which for most
people is a Tuesday. Bouncing between an editor and a browser all afternoon
counted as twenty switches.

It counts different programs now, not changes — five visits between two programs
is two, not five — and the threshold is seven of them. Every candidate that
applies is collected and one is picked, rather than the first always winning, and
the one used last time is skipped. When it is the only true thing, the cat is
told nothing stands out instead: the same observation twice is where a remark
becomes a complaint.

Four more candidates were added so there is something to rotate to — all mouse
and no keyboard, a Mac awake all day at evening, the weekend, early morning — and
two thresholds were raised, typing "very fast" from 150 to 200 keys a minute and
idling from one minute to two.

## 2.0.2 — 2026-08-25

### One clock for everything it says

Reported: suggestions arriving far more often than the five minutes set for them.
They were not — two things were talking. The suggestions kept to their interval,
and the curious antics kept to their own, which was forty-five to a hundred and
twenty seconds, and from the outside that is one cat interrupting every minute or
two.

There is one clock now, kept in the defaults so quitting the app does not reset
it, and the interval on the Suggestions tab governs everything the cat says
unasked: a suggestion, a curious question, whatever comes later. The label says
"Speaks at most every" rather than "At most every", because that is what it now
means.

The antics themselves are rarer — ninety seconds to four minutes rather than
forty-five to two — and, inside the quiet period, silent: the cat still walks
over, sits down and looks at you, then goes away without saying anything. The
walk was never the interruption.

Measured: with the interval at five minutes, a first remark passes, a second is
refused, the advisor refuses too, four hundred seconds later it passes again, and
a clock that has moved backwards does not lock the cat out for ever.

## 2.0.1 — 2026-08-25

### The permissions tab, laid out properly

The Screen recording row came down on top of the note about restarting and about
ad hoc signing — the note had been added after the tab was last measured, so
nothing had caught it. The two buttons moved up beside the summary, the rows are
spaced 63 points, and the explanations stop short of the button column: widening
them to the full width had put each one a single point under the Ask button of
the row below, which is the sort of thing only a machine notices and every
machine notices.

All six tabs measured again by intersecting every pair of frames: nothing
overlaps.

## 2.0 — 2026-08-25

### A crash, asking the time

Reported: "che ore sono" and the app was gone. The crash log put it in
`llama_decode` calling `ggml_abort` — the instructions had grown to carry the
facts, the drawing rule and the six verbs, and a prompt of about 950 tokens went
into a decode with a batch size of 512. llama.cpp does not return an error for
that; it aborts, and takes the app with it.

The prompt now goes in a batch at a time, the context is 4096 rather than 2048,
and a prompt that genuinely cannot fit is refused with a sentence instead of an
assert. Measured after: the same three questions through the 1.5B model, answered
in half a second each, no crash.

Two things came out of the same run. The instructions for drawing and for doing
were cut to about a third, because a small model given three long English blocks
answered everything with IMAGE: — the time, the day, the battery. And markers are
now read through markdown: the 1.5B writes `**ACTION: open-app TextEdit**`, which
used to be a sentence and is now an action.

### Half a model is not a model

Both 4B downloads had been interrupted, leaving files at a half and a seventh of
their size. The app saw a file, called it installed, and answered every question
with "that model file could not be read". A model shorter than nine tenths of its
published size is now treated as absent, and the tab says the download did not
finish and offers to resume it rather than pretending there is nothing there.

### The wake word never asked to be allowed to hear

Reported: saying "Neko" does nothing. Speech recognition had never been
authorised — the permission used to be asked for by the keystroke, the first time
anyone pressed it, and someone who only ever turned on the wake word was never
asked at all. A recogniser without that permission accepts a task, returns no
results, and says nothing about it.

The switch now asks when it is turned on, and the tab says which of the three
states it is in: listening and hearing, microphone open but nothing coming back,
or not listening because the permission is missing. The feature is labelled beta,
since how well it hears a name is not something the app can promise.

### Screen recording that would not stick

Granted in System Settings, still refused in the app. Two reasons, both real, and
now both written in the tab. macOS applies a change to screen recording only when
the app is restarted — there is a Restart Neko button for that — and this build
is signed ad hoc, so every rebuild is a different app to the system. Measured: a
one-character change to a source file moves the code hash from 700ae442… to
48c17472…, and everything granted to the previous hash stops applying.

### An hourglass while it draws

Fifteen seconds of one unchanging sentence looked like nothing was happening.
The drawing now turns an hourglass over twice a second and works through five
occupations — mixing the colours, sharpening the pencil, deciding where the light
comes from — until the picture arrives. Measured on a 384 pixel drawing: 30
distinct frames over 11 seconds, then the picture.

### The Ask buttons that did nothing

Two of them. **Accessibility**: macOS shows that alert exactly once in an app's
life, and every call after it returns no and puts nothing on screen — which is
precisely what "the button does nothing" looks like. It now asks, waits a moment,
and opens the pane where the answer can be changed if the answer is still no.
**Your folders** is not one permission but six, so its button now opens the same
folder menu the Ask Neko tab uses, instead of silently assuming the Desktop.

### A window wide enough for its tabs

Six tabs in a 494 point window had their labels shoulder to shoulder. The window
is 624 wide now, the tab views 600, and every paragraph in it went from 430 to
556 points — which is the difference between a wrapped sentence and a truncated
one. All six tabs checked again: no overlapping controls anywhere.

### A permissions tab

Five permissions, one place: microphone, speech recognition, accessibility, your
folders, screen recording. Each row shows what macOS currently thinks, whether
what needs it is switched on, and a button that does the only thing still
possible — ask, or open the pane where a refusal can be undone. The line at the
top names anything switched on and not allowed. Rebuilt on every opening, because
all five can change outside the app.

### Questions with an answer on this Mac

"Che ore sono?" had no honest answer: a model has no clock and invents one. The
things a question is most likely to be about — time, date, uptime, battery, the
program in front, how many screens — are now looked up and handed over with the
question, so the answer comes from the Mac rather than from the model's
imagination. A question about anything else is refused in one sentence instead of
guessed at.

Two rounds of measurement went into the wording. The first put the facts in
English in the middle of the instructions, and the answers came back in English;
the language rule now comes last, after every English block, which is the same
lesson the action verbs taught. The first version also apologised after every
answer — "I cannot know what day it is about anything else" — so it is now told
to answer and stop.

### The preferences had two controls on top of each other

The wake word switch was laid over the API key field: 220 by 7 points of overlap,
found by walking the tab views and intersecting every pair of frames. The window
is 80 points taller now, every row moved with it, and the paragraph at the bottom
of the Ask Neko tab has 86 points instead of 30 — it had been truncating for a
while. All five tabs check clean.

### The wake word went deaf

It answered sometimes and not others. Speech ends a recognition task of its own
accord when it decides a sentence is finished, and until the fifty second timer
came round the audio after that went to nobody. It is now rebuilt the moment a
result comes back final, the new request is put in place before the old task is
cancelled so the tap is never appending to nothing, and a watchdog rebuilds it
anyway if the recogniser has said nothing at all for twenty seconds.

### It answers to its name

A second way in, off until switched on: **Answer when I say "Neko"**. The
microphone stays open for it, and the tab says so — orange light, battery, the
lot — because that is the actual price and it should not be discovered later.

Recognition is forced on-device, and where the interface language cannot be
recognised without a server the switch refuses rather than quietly streaming the
room to one. The transcript rolls past, is looked at for one word, and is thrown
away.

The name is matched loosely: a dictation engine has never met the cat and writes
the nearest word it knows, so `neko`, `neco`, `necco`, `nekko`, `nico` and `niko`
all wake it, accents and case ignored, whole words only. Fourteen cases measured,
including the ones that must not wake it — "nekomata", "nekromante", "che ne
kombini" — and all fourteen came out right.

Speech drops a recognition task after about a minute of its own accord, so it is
rebuilt every fifty seconds with the microphone tap running underneath. And since
there is only one microphone, hearing the name or pressing the keystroke makes
the wake word let go, and -finish gives it back.

### The Local model tab offered to download what was already there

Opening the preferences read the selected model out of the menu before putting
the menu where the settings said, so it asked the first model in the catalogue
whether it was installed. With Qwen 1.5B chosen and on disk, the button still
said Download. Measured after: menu on Qwen2.5 1.5B Instruct, button says Remove,
detail line matches.

### And now it can carry a file

Two more verbs: `copy` and `move`, one file at a time, between Desktop,
Documents, Downloads, Pictures, Music and Movies. *"neko sposta relazione.pdf
dalla scrivania nei documenti"* becomes `ACTION: move relazione.pdf from desktop
to documents`, which becomes a bubble asking *"Sposto «relazione.pdf» da
Scrivania a Documenti?"*, which becomes a moved file once you say yes.

The sandbox stays on. Measured from a signed sandboxed build, the app cannot read
the Desktop or write to Documents, so folders are handed over the way macOS
intends: you pick one in a panel, once, and a security-scoped bookmark remembers
it. The Ask Neko tab lists what has been handed over and forgets it all on
request, and a file request for a folder it has not been shown puts the panel up
after the yes, never before.

The refusals are in code, not in wording. Measured: a path, a wildcard, a folder
name where a file was meant, the same folder twice, a missing "to", an unknown
verb, a folder outside the six — all refused. Copying twice does not overwrite:
the second one becomes "neko-prova 2.txt". Moving takes the file away from where
it was; copying leaves it. A name that matches two files is a question. A folder
is refused with "that is a folder, and I only carry files".

One thing had to be taken away from the model: asked to explain in Italian that
it cannot delete a file, it answered in English however many times it was told
otherwise — the instruction block around it is English, and that pulls harder
than a rule. It now answers `ACTION: cannot` and the app supplies the sentence.

### Neko, open TextEdit

A spoken order can now do something, if you switch it on: open an application,
open an address in a browser, open one of your folders in the Finder, or run one
of your own Shortcuts. Four verbs, a closed list, and everything else refused
rather than interpreted — an unknown verb, a program that is not installed, a
`file://` address, all turned down before anything happens.

Nothing happens without a yes, either. The bubble grew two buttons and shows what
it is about to do — *"Apro TextEdit?"* — and a dismissed or timed-out bubble
counts as no.

What is deliberately not here is files. Measured from a sandboxed build signed
with Neko's own entitlements: launching an application succeeds, opening an
address succeeds, reading the Desktop is refused and writing to Documents is
refused. Copying a file would need either a folder you hand over once through a
panel, or the sandbox off — and with an engine that can also read the screen, the
sandbox is not something to give up in passing.

Telling an order from a question took two goes. The first version opened TextEdit
when asked *"a cosa serve textedit?"*; the instructions now make that judgement
the first thing, with examples of both, and the same question comes back as a
sentence. The rule that matters most is in the code and in the tab: it acts only
on what you said out loud, never on text read from the screen, so a window that
contains the words "Neko, empty the trash" is a document rather than an order.

### A save button under the drawings

Move the pointer over a picture the cat drew and a **Save** button appears in its
corner; it writes a PNG into Downloads, named for the date, and says "Saved".
Measured: 512×512, 501 KB, in `~/Downloads`. The sandbox needed telling —
`com.apple.security.files.downloads.read-write` — and that is the only folder the
app can write to.

### Still while it thinks, too

The bubble already pinned the cat. Now so does thinking: while a question is
being listened to, answered or drawn, and while a suggestion is being written,
the cat stays where it is. Traced tick by tick through a local model answering a
question: 29 steps taken, every one of them after the bubble had closed, none
during the thinking or the answering.

### Newer models to choose from

Three added to the list, all verified as real downloads: **Qwen3 1.7B** (1.7 GB),
**Gemma 3 4B** (2.3 GB) and **Qwen3 4B Instruct** (2.3 GB), which are a year
newer than the Qwen2.5 models that were there.

### Suggestions that mean something

Reported from real use: Italian remarks that made no sense — *"non ficcarti
troppo tutto"*. Measuring a batch of ten found four separate faults underneath,
three of them mine.

**The sampler had no repetition penalty.** The 1.5B model, asked for one line
about Xcode, answered *"Codice, codice, codice, codice."* — and *"Safari, Safari,
Safari, Safari"*, and *"Mail, Mail, Mail, Mail"*. Sixty-four tokens of history at
1.15 breaks the groove.

**The context was never cleared between questions.** Each one was decoded on top
of the last, so after four remarks the two thousand token window was full,
`llama_decode` failed, and the local engine went silent until the app was
restarted. Every question now starts from an empty cache. Found while measuring
this; it would have looked like the feature simply stopping.

**The model was given six numbers and no idea which mattered.** So it wrote
whatever fitted any afternoon: *"Safari ti tiene compagnia mentre il tempo scorre
lento"*, twice, for two different programs. The app now works out the one thing
that stands out — forty-two minutes without leaving a program, fourteen jumps in
a quarter of an hour, half past eleven at night — and says so in the description.
The difference, same engine: *"Quindici salti in venticinque minuti."*, *"È
mezzanotte e tu sei ancora qui."*

**It was inventing complaints about programs.** *"Safari è lento"*, *"Mail è
lento, prova a chiudere quella scheda"* — Mail has no tabs, and nothing in the
description says anything is slow. The instructions now forbid saying a program
is slow, broken, busy or waiting, since none of that can be seen from here.

Last, a filter. `NekoSense` throws away a line that repeats a word three times,
comes back in the wrong language (checked with `NLLanguageRecognizer`, and only
when it is sure), is one of the example lines handed straight back, or runs to a
paragraph. A thrown-away line means the cat says nothing at all that round, which
is always the better of the two.

The Suggestions tab now also says plainly that the small local models are bad at
this and that Apple Intelligence is better at it and free, rather than leaving
that to be discovered.

### It stays put while you read

Asked for, and it turned out to be half missing: the cat kept its errands and its
wandering while a bubble was on screen, so a remark could walk off mid-sentence.
Now a visible bubble pins it — no walking, no wandering, no errands, and an
errand in progress is dropped — while the in-place animations carry on, so it
still sits and washes and blinks at you. When the bubble goes, it moves again;
when another one opens, it stops again.

Measured over twenty seconds in the roaming behaviour: 2 168 pt travelled with no
bubble, **0 pt** with one open (not one step in twenty-two seconds of tracing),
1 643 pt again once it closed, 0 pt when a second bubble opened.

### Show me the Colosseum

Ask the cat to be shown something and it draws it, on this Mac's GPU, with
nothing sent anywhere. A new **Drawings** tab holds the switch, a 1.6 GB Stable
Diffusion 1.5 model to download, the effort and size of the picture, and a button
that draws a cat on the spot so the feature can be judged without talking to
anyone.

The understanding is the text model's, not the app's: told it may draw, it
answers *"mi mostri il Colosseo?"* with `IMAGE: the Colosseum in Rome,
photograph, golden hour` instead of a sentence, and the app recognises five
characters and hands the rest to the painter. Whatever language the question was
in, and whatever "show me" turns out to mean, is the model's problem.

Measured here: 14.5 s to draw 512 pixels at 14 steps, about nine more the first
time while the model opens, 15.8 s from question to picture in the bubble. The
bubble learned to hold a picture above its words, sized to the drawing or to the
text, whichever is wider.

`neko-paint` is a separate program in the bundle rather than a linked library,
because stable-diffusion.cpp brings its own ggml and llama.cpp is already in
there with another: together they would define every ggml symbol twice. A crash
in it also costs a picture rather than the cat. Apple's own Image Playground was
tried first and refused: `ImageCreator`, the headless API, answers `notSupported`
on macOS 27 where it is deprecated in favour of a panel the user has to drive.

### The cat asks about what you are actually doing

The curious questions were written in and localized: five of them, picked at
random. They are now asked of whichever engine Ask Neko is set to, while the cat
is still walking over, so the errand covers the wait; the written-in lines stay
as the fallback for no engine, an error, or an answer that arrives after the cat
has already wandered off.

More to the point, the cat can now be told what you are working on. **Reading the
text you are working on** is a new switch on the Suggestions tab, off until you
turn it on, and it asks for the Accessibility permission when you do. With it on,
the field you are typing in — or whatever is under the pointer — is read and
included in the description the engine is given.

The difference, measured on the same desktop with a file open in TextEdit:
without the text, *"Cosa stai scrivendo?"*; with it, *"Cosa stai scrivendo nelle
note di rilascio?"*. The 1.5B model, given the same context, went for the window
title: *"Cosa stai facendo con questo file prova-neko.txt?"*.

What it will not do: password fields are refused by subrole, nothing at all is
read while macOS has secure keyboard entry on, only the last few hundred
characters are taken, and the tab prints the exact block that would be sent
whether the switch is on or off. With a remote engine that block goes to that
service, and the paragraph says so.

Behind it, one class — `NekoDesktop` — now holds everything the cat can tell
about your day, where the suggestions and the antics each used to keep half of
it and neither could see the other's half.

### The model that was chosen but never downloaded

Picking a model in the menu and not downloading it left the local provider
unconfigured for ever: questions fell back to the canned reply, the roaming cat
went quiet, and nothing anywhere said why. Found on a real machine, where the
preferences pointed at Qwen 3B and only the 1.5B was on the disk. A model that is
actually there now wins over one that was merely chosen, and the Local model tab
says which is answering and why.

## 1.9.1 — 2026-08-22

### The cat crosses desktops

Reported: launch the app, the cat chases the cursor, swipe to another desktop with
three fingers and it is left behind on the old one. Two displays were never
affected, which made the whole thing look mysterious.

It is not mysterious. Belonging to a Space is a property of the window, not of
where the window is on screen, and a window that says nothing about it belongs to
the Space it was created in — for ever. Two displays are only geometry: the cat
crossing a display border keeps the Space it already had, which is why that case
always worked.

So the cat's panel and its speech bubble now declare the four flags the Dock and
the menu bar extras use: `CanJoinAllSpaces` so they are present on every desktop,
`Stationary` so they are not dragged along by the switching animation, and
`IgnoresCycle` and `FullScreenAuxiliary` to stay out of window cycling and to be
allowed above a full screen app. The preferences window takes the opposite flag,
`MoveToActiveSpace`, so opening it from the menu bar brings it to the desktop you
are on instead of throwing you across to where it first appeared.

Measured with the window server's own `kCGWindowIsOnscreen`, switching desktop
six seconds in and back again later. Two test windows, identical but for the
behaviour: the plain one vanished from the current Space at the swipe and came
back only on returning, the one with the new flags never left. Then the same
check against the shipped 1.9 and the new build: 1.9's cat dropped off the
current desktop at the swipe and stayed off, the new one stayed present through
the whole sequence.

## 1.9 — 2026-08-22

### Sheets that draw outside the lines

Three redrawn sheets — Pinup, Gandalf, Frodo — came back with the figures taller
than the cells they belong to and sitting high in them, so the feet of one row
lay over the hair of the next. No empty gutter anywhere, and 100 to 500 opaque
pixels crossing every horizontal boundary: the plain grid cut took off shoes and
hat tips, and snapping each cut to the quietest line still left thirty of the
thirty-two poses touching an edge.

`grid2char.py --split` stops cutting. The grid places one seed per cell, and then
every opaque pixel is shared out between the seeds by a breadth-first sweep from
all of them at once, travelling only inside the figures. Each pose comes out as
its own image: a neighbour's foot stays with the neighbour, and two figures drawn
into each other are separated along the line where they meet — 884, 732 and 606
pixels of genuine overlap across the three sheets, which is a shoe against some
hair and invisible at 48 points. Loose clumps like the Zzz over a sleeper or the
marks beside a startled pose are kept and filed with the pose whose cell they
fall in; single specks are dropped.

`--snap`, which moves each cut to where the fewest pixels cross it and picks the
horizontal cuts per column, is in there too: not enough for these sheets, but the
right thing for one that is merely a few pixels out.

### TS and OR, Gandalf, Frodo, and a new Pinup

**Gandalf**, **Frodo** and two musicians — **TS** with a pink guitar, **OR** with
a purple one — join the drawn characters at 48 and 64 points, and **Pinup** was
redrawn. Every one of these sheets needed `--split`, and the earlier three were
imported again once it existed. 43 characters now.

### A cat that roams like it means it

Roaming was too sedentary and fell asleep almost at once. Two numbers were wrong:
the pause between errands, now one to four seconds instead of twelve, and the
target, now somewhere at least a third of the desk away rather than uniformly
anywhere — uniform points landed next door often enough that the cat looked
indecisive. Sleep is on a clock of its own: five minutes awake and roaming before
a nap is earned, half a minute of it, then five minutes again. The idle chain
otherwise put it to sleep three seconds into its first pause, which reads as
broken rather than sleepy.

Measured: over 150 s it walked 10 650 pt across 14 trips, on its feet 57% of the
time and asleep for none of it; over a 400 s run, 27 793 pt across 35 trips, 57%
on its feet again and 6% asleep — the nap arriving once the five minutes were
up, and lasting the half minute it is meant to.

### A cat that gets curious

Roaming now comes with antics, no setting and no engine involved. Every 45 to 120
seconds, and never while nobody is at the keyboard, the cat takes an interest:
typing fast brings it over to the pointer to sit down and ask what you are
writing — measured, it crossed 275 pt, stopped 58 pt from the cursor, and only
then said *"Serve una mano? Io ho solo zampe."*, a lot of mouse movement gets the cursor pounced on, twenty seconds of
nothing sends it to claw the edge of the screen, and otherwise it just wanders
over to have a look.

The signals are counters the system hands out without any permission —
`CGEventSourceCounterForEventType` for keys and mouse moves, and the seconds
since the last one. Not which keys, not where. The line waits until the cat has
arrived: "what are you writing?" from the far side of the screen is a worse joke,
so the errand has a two-part clock — getting there, then doing the thing — and
gives up rather than walking into a wall for ever.

### A third behaviour, and a cat with opinions

**Roams on its own** joins *Follows the cursor* and *Lives on the Dock*: the cat
walks wherever it likes on the desk, sits for a dozen seconds and sets off again,
and the pointer is neither a destination nor something to avoid — moving the mouse
does not interrupt it. Measured over 45 s with the pointer parked: following, the
cat closed to 16 pt of it; roaming, it never came within 439 pt, covering 875 pt
of desk in the meantime.

**Suggestions** is the new tab, and it exists only inside that behaviour: a cat
chasing the cursor has its attention elsewhere and one on the Dock is already
busy. Switched on, the roaming cat glances at what you are doing and now and then
says something about it through whichever engine Ask Neko is set to — a tip, a
nudge, or a joke.

It sees five shallow things, none of which need a permission: the application in
front, how long you have been in it, how often you have been switching, whether
you are at the keyboard, and the time. Window titles are included only if this
Mac has already granted Neko screen recording; the permission is never asked for.
Nothing is read from inside documents. The tab prints the exact text that would
be sent, before the switch is turned on, and says plainly that a remote engine
receives it like any other question.

Interruption was the hard part, not the asking. It stays quiet while you are away
from the keyboard, waits twenty-five seconds into an application, allows one
remark per interval — two to sixty minutes, ten by default — and doubles that
before speaking twice about the same application. An attempt that produced
nothing still costs the interval, so a model that declines cannot turn into a
loop.

The prompt took four measured attempts. Three paragraphs of rules made the 1.5B
model worse, not better: markdown, a sentence in French, and *"Claude, Claude,
Claude, Claude."* — it had latched onto the application name as the person's
name. What works is short, first-person context ending in an instruction rather
than in numbers, three localized examples instead of a description of the tone,
and an explicit escape hatch — a single hyphen — for having nothing to say. Two
smaller fixes came out of the same runs: markdown and quotation marks are
stripped from the reply, and the sampler is seeded afresh each time, because with
llama.cpp's fixed default seed the same desktop produced the same sentence word
for word.

Quality is the engine's, not the plumbing's. Apple's on-device model answers in
0.6–1.3 s with something like *"Safari ti tiene incollato come una fusa senza
fine"*; the 1.5B GGUF, same context, offers *"Navigo verso i siti web"*.

Also fixed on the way: the controller asked the advisor to start from inside its
own `-init`, and the advisor asked the controller whether it should — which built
a second controller, which asked again. The app hung on launch until the start
moved to where the shared instance already exists.

## 1.8 — 2026-08-22

### Four places an answer can come from

The provider list now reads Apple Intelligence, ChatGPT, Claude, a Shortcut of
mine. ChatGPT is asked directly, with a key of its own: each provider keeps its
key under its own Keychain account, so switching between them loses neither, and
the Keychain code they were both growing copies of moved into one class.

Apple's own ChatGPT integration still cannot be reached from another
application — it answers inside Siri and the writing tools, never to a program —
so the Shortcut remains the sanctioned route to it.

### A model of your own, running here

The **Local model** tab downloads a GGUF over HTTPS into the app's own
Application Support folder and answers from it, with nothing else installed: no
daemon, no package manager, no second application to keep running. llama.cpp is
built once as a static library and linked in, Metal and all, so the model runs on
the GPU of the Mac it was downloaded to.

Four models are offered rather than two, because size is the whole decision here
and the differences matter more than the names suggest:

| Model | Size | What it is for |
| --- | --- | --- |
| Qwen2.5 0.5B Instruct | 468 MB | fits anywhere, and gets simple facts wrong |
| Qwen2.5 1.5B Instruct | 1.0 GB | the smallest one worth believing |
| Llama 3.2 3B Instruct | 1.9 GB | warmer wording, slower |
| Qwen2.5 3B Instruct | 2.0 GB | the best answers of the four |

Measured on the 1.5B build, on this Mac: the first answer after launch takes
**0.40 s** to its first word and **0.45 s** in full, and once the model is in
memory the next question comes back in **0.03 s**. The answer streams, like the
Apple one.

Opening a model means reading a gigabyte and compiling Metal kernels, which is
seconds the first time — so it happens on a queue of its own. Doing it on the
main thread froze the cat, the bubble and the spinner meant to say something was
happening, which was exactly the wrong moment to be frozen.

A **Remove unused models** button says how many models are not the one selected
and how much disk they hold, asks before deleting gigabytes that took a while to
fetch, and sweeps stray files that are no longer in the catalogue. The tab also
prints how much of the disk the models take altogether.

### A cat visibly thinking

Between the question and the answer the bubble now shows the cat at work rather
than the question sitting still: a paw pacing back and forth, growing dots, and
five things a cat might plausibly be doing — sniffing the question, scratching
its head, consulting the ball of yarn, staring out of the window, chasing the
thought — one every two seconds. The question stays above it, and the first word
of the answer ends the whole animation.

### Faster where it was actually slow

The twelve second figure was a timeout, not a wait: the on-device model was
already answering in under two seconds. What felt slow was elsewhere, and both
have been dealt with.

The answer now streams. `streamResponse` hands over snapshots as they are
generated, so the first words reach the bubble in **0.42 s** where the complete
answer took **1.89 s** — measured on the same question, which also finished
sooner streaming (1.35 s). The bubble is redrawn ten times a second at most,
because the model produces snapshots far faster than that and resizing a window
on each one looks like a stutter.

The listener waited two and a half seconds of silence before deciding a sentence
was over — dead time after you stopped talking, and the largest single delay in
the feature. It is a second and a half now, and the recogniser usually declares
the sentence finished on its own first.

Timeouts came down with it: eight seconds for the two direct providers, ten for
a Shortcut, whose clipboard is now watched every 80 ms instead of every 150.

## 1.7.1 — 2026-08-22

### The answer sounds like whoever is on screen

A character's manifest can carry a `Persona`, a phrase saying who it is, and the
question goes out with it: Merlin answers like a wizard, Owl like something
solemn and pedantic, Alien describes this planet from the outside. Eighteen of
the bundled characters have one; the rest answer as themselves, by name.

Getting this right took three attempts, all of them measured against the same
questions. Given a character and nothing else, the on-device model dropped the
facts entirely and explained a blue sky with dancing crickets and candy floss.
Told that truth comes first, it became correct and completely flat — every
character returning the same bare sentence. What works is both, in that order:
truth as the first duty, the character confined to the wording, and one explicit
line saying a small touch is enough even when the answer is a single fact.

The answer is pinned to the language Neko runs in, named outright: "reply in
Italian", not "reply in the same language as the question", which a small model
honours for a sentence and then abandons. Asked in English while running in
Italian, it now answers in Italian.

The instructions no longer mention the bubble or the sprite, either: describing
the display made one model narrate it back, answering inside a
`<small sprite 32px: …>` tag.

`grid2char.py` and `sheet2char.py` take `--persona`, so a new character can
arrive with a voice.

## 1.7 — 2026-08-22

### Ask Neko

Off by default: ⌃⌥N, a question out loud, an answer in a bubble beside the cat,
which holds still while you talk to it.

One slot in the menu carries it, changing identity rather than greying out:
**Set up Ask Neko…** opens its preferences tab while the feature is off, and
becomes **Ask Neko (⌃⌥N)** once it is on. A disabled item that does nothing
teaches nobody anything, and a checkmark would have hidden the five settings
behind it.

The bubble used to cut the end off short answers. It measured the text with
`boundingRectWithSize:` and drew it in an `NSTextField`, which keeps insets of
its own: a sentence that measured as one line needed two inside the field, and
the second one fell outside the frame. It is now measured by the cell that draws
it. The question also stays on screen while the cat thinks, instead of being
replaced by a row of dots, so you can see what it understood.

The keystroke is a Carbon hotkey registration rather than an event monitor,
which is why it needs no Accessibility permission and works in the sandbox. The
microphone is requested the first time the feature is used, after a sheet that
says what is about to happen, and it is open only between the keystroke and the
end of the sentence. `SFSpeechRecognizer` is weakly linked and keeps recognition
on the Mac when the language allows.

Answers come from one of three providers behind a one-method protocol.

**Apple's on-device model** is the default: the one behind Apple Intelligence,
free, private and offline, answering in about two seconds. It is reached through
`src/NekoAppleModel.swift`, the first Swift file in this project —
`FoundationModels` is Swift-only and ships no headers, so there is no other way
in. The Intel slice of the universal binary omits it, because the Command Line
Tools carry the Swift compatibility libraries for arm64 only and Apple
Intelligence needs Apple silicon regardless; the provider reports itself
unavailable when the class is missing, which is what already happens on macOS
older than 26.

The other two: a Shortcut the user owns, which returns its answer through the
clipboard and gets the previous contents put back, or the Anthropic API with a
key kept in the Keychain. With none of them available the cat answers in
character.

Asking for a Shortcut that does not exist used to mean twelve seconds of waiting
and a vague apology while Shortcuts complained on its own behalf; the name is now
checked against `shortcuts list` first, and the cat says which name it could not
find.

The deployment target moves from 10.13 to 11, which is what mixing Swift in
costs.

Siri itself is not involved, and cannot be: no public API hands a Siri answer
back to another application. `docs/ask-neko.md` records that, the design, and the
three places where the implementation deliberately differs from it.

## 1.6 — 2026-08-21

### The cat claws at what it cannot pass

Every bundled character has always carried four wall-scratching animations this
port could not reach, because nothing told it where the walls were. It does now:
the edge of the combined screens, and the top of the window the cat is standing
on when the pointer is inside that window. The cat also stays on screen, which
it did not before — it could walk off the edge following a pointer at the
border.

### Two behaviours, not one with an extra switch

**Behaviour** replaces what started as a checkbox, because chasing the pointer
and living on window edges fight each other: one wants the cat to rest wherever
it stopped, the other pulls it down onto the nearest surface, and having both at
once made the cat arrive at the pointer, slide to the floor, climb back and
start over.

*Follows the cursor* is the classic behaviour, unchanged. *Lives on the Dock*
ignores the pointer: the cat lives on top of the Dock, and when the Dock is
hidden or sits on a side of the screen it runs to a window that is not filling
the screen and lives on its top edge instead. Gravity applies, so hiding the Dock
or closing that window drops it.

The Dock's own Quartz window covers the whole screen and tells you nothing, so
the space it reserves is read from the difference between a screen's `frame` and
its `visibleFrame`, and the cat is kept over the middle of that edge where the
Dock actually is. Window rectangles come from `CGWindowListCopyWindowInfo`, which
works inside the sandbox and needs no permission; the list is refreshed every few
ticks, since windows do not move eight times a second.

**Wander off when idle** is disabled in the second behaviour rather than
fighting it: a cat on the Dock is already moving about on its own.

### Designed, not built

`docs/ask-neko.md` plans **Ask Neko**: a hotkey, a spoken question, an answer in
a bubble beside the cat. It is a design document only — no code — and it records
what cannot work as first imagined, since Siri has no public API that hands an
answer back to another app.

### It goes for a walk, once it has actually rested

**Wander off when idle** now waits for the cat to arrive, sit down and be left
alone for half a minute, and then sends it *away* from the pointer rather than
to a random spot. Moving the pointer cancels the errand immediately.

## 1.5.2 — 2026-08-21

### Opens at login

A new preference asks the system to launch Neko when you log in. It goes
through `SMAppService`, so there is no helper bundle to ship and no preference
of our own: the system holds that state and the checkbox reads it back, which
also means the checkbox follows what the system agreed to rather than what was
clicked. macOS may ask for approval under Login Items before it takes effect,
and says so when it does.

`ServiceManagement` is linked, since a framework that is never linked is never
loaded and the class would be invisible to the runtime lookup. The framework has
existed since macOS 10.6 while the class arrived in 13, so the app still starts
on older systems, where the checkbox is simply disabled.

### Characters that face the right way

A generated sheet rarely holds eight coherent directions: the walks come out as
sitting poses and left-facing rarely matches right-facing. `grid2char.py
--mirror` builds every left-facing frame by flipping its right-facing twin, so
the two halves match by construction, and every generated character was
reimported with it. Pinup was redrawn against the rewritten prompt in
`tools/sprite-prompt.md`, which now says what each view has to show — walking up
is seen from behind, with no face at all, which is what was missing.

`--alpha-floor` clears a near invisible wash before anything else. One sheet
arrived with 44% of its area at alpha 1 to 16: invisible on screen, but enough
that no row read as empty and every cell's bounding box covered the whole cell,
so the trimming quietly did nothing and each pose was scaled from its cell
rather than from itself.

## 1.5.1 — 2026-08-21

### Stops short of the pointer

A new preference, **Stops short by**, is the ring the cat keeps around the
cursor: 0 to 200 points, 48 by default. At 0 it sits right under the cursor, the
way it always did. The step towards the pointer is capped by the distance left
over the ring, so the cat settles on it instead of stepping across and jittering
back, and anything under a point counts as arrived — the deltas are whole
points, so without that the cat could creep a fraction of a point per tick
without ever finishing.

The web version gained the same `stopRadius` option, replacing a hard-coded
48-point cushion that quietly doubled at 2× scale.

### The interface speaks four languages

English, Italian, French and Spanish, in `Resources/<lang>.lproj`. The English
text is the lookup key, so a missing translation falls back to English on its
own. The preferences window was widened to fit the longest of them, checked by
measuring every string against the control that holds it.

### Six new characters

Generated pixel art, imported with the new `tools/grid2char.py`: **Merlin** the
wizard cat and **Owl** at 48 points, **Merlin XL** and **Owl XL** at 64,
**Alien** and **Pinup** at 48. They are the first characters larger than the
32-point sprites oneko drew, which the manifest always allowed and nothing had
exercised.

`grid2char.py` keys the background out by flooding in from the border, so white
fur inside a character survives a white backdrop, and it compares alpha as well
as colour — a sprite outlined in black shares its colour with transparent black,
and an earlier version ate the outlines. `--autogrid` takes the cell boxes from
where the poses actually are rather than splitting the image evenly.

`char2sheet.py` now scales oversized characters down to 32 points for the web
sprite sheet instead of leaving them out.

### Fixed

- A character that fails to load no longer sizes the window to nothing.
- `tools/sprite-prompt.md` documents the cell-by-cell layout of a sheet, so a
  new character can be drawn to fit.

## 1.5 — 2026-08-21

The cat that chases your cursor, now with a menu bar item, preferences, 28
characters, and a web version. First release since the fork, so everything below
is new.

### A menu bar item

Neko has no dock icon, and until now the only way to quit it was `killall`. It
now lives in the menu bar:

- **Pause / Resume** — hide and freeze the cat, or bring it back
- **Character ▸** — switch sprite set; the menu bar icon follows it
- **Preferences…** (⌘,) — character, speed, size, idle behaviour
- **About Neko**
- **Quit Neko** (⌘Q)

The icon is drawn as a template image only when the sprites are greyscale, so
the classic cats adapt to a light or dark menu bar while the colourful ones keep
their colours.

### Preferences

| | |
|---|---|
| Character | any of the 28 below |
| Speed | 4 to 30 points per tick, shown in points per second |
| Stops short by | 0 to 200 points to keep from the pointer, 48 by default; 0 sits on the cursor |
| Size | 1× (32px) or 2× |
| Fall asleep when idle | on or off |

Settings live in `NSUserDefaults` (`NekoCharacter`, `NekoSpeed`,
`NekoStopRadius`, `NekoScale`, `NekoIdleSleep`, `NekoPaused`) and apply
immediately, no restart. The step towards the pointer is capped by the distance
left over the stop ring, so the cat settles on it rather than stepping across
and jittering back.

### 28 characters

From oneko itself, public domain: **Neko**, **Tora**, **Dog**, **Sakura**,
**Tomoyo**, plus **Kuro**, an inverted recolour.

From the oneko.js ecosystem: Ace, Black, Bunny, Calico, Eevee, Esmeralda, Fox,
Ghost, Gray, Jess, Kina, Lucy, Maia, Maria, Mike, Moka, Silver, Silversky,
Snuupy, Spirit, Valentine, Vaporwave.

Each one is a folder in `Resources/Characters` with a `character.plist`
manifest, added to the project as a folder reference — a new character is a
folder drop and a rebuild, no project change. Sprite size and per-state frame
timing come from the manifest, and a character that only describes some states
still animates: diagonals fall back to the nearest cardinal direction, wall
scratching falls back to grooming, everything else to sitting still.

Internally this replaced the state machine's comparison of `NSArray` pointers
with a `NekoState` enum, which is what made runtime character switching
possible at all.

### A web version

`web/` holds a TypeScript port of oneko.js wearing the same 28 characters,
packaged as a standalone Angular component plus a framework-agnostic engine:
live character swap, 1×/2× scale, adjustable speed, pause, idle sleep,
`prefers-reduced-motion` support, and inert under server side rendering.

Its sprite sheets and character registry are generated from the same folders the
app uses, so the two versions cannot drift. `web/INTEGRATION.md` covers adding
it to an app that already exists.

### For contributors

Three converters in `tools/`:

- `xbm2char.py` — an oneko animal (bitmap + bitmask XBM pairs) into a character
- `sheet2char.py` — an oneko.js 256×128 sprite sheet into a character
- `char2sheet.py` — a character back into a sheet, and the TypeScript registry

They check themselves: converting oneko's own cat reproduces the sprites already
in the tree pixel for pixel, and packing a character back reproduces the sheet
it came from. `--verify` runs those comparisons.

`./build.sh` builds the app with just the Command Line Tools, no Xcode.
`./dmg.sh` builds the disk image, background and window layout included. The
project also builds on a current macOS again: `SDKROOT` was pinned to the 10.9
SDK, which no longer exists.

### Installing

Open `Neko-1.5.dmg` and drag Neko to Applications.

**The app is signed ad hoc, not notarised.** macOS will report it as damaged the
first time, because it arrived from the internet. Clear the quarantine flag
once:

```sh
xattr -dr com.apple.quarantine /Applications/Neko.app
```

Universal binary, x86_64 and arm64, built for macOS 10.13 and later.

To quit it, use **Quit Neko** in the menu bar.

### Known limitations

- The wall-scratching animations are unreachable: they need screen edge
  detection, which this port does not do yet.
- No launch at login.
- The pet does not change the mouse cursor, unlike the X11 original.

### Credits and licences

Based on the public domain oneko by Masayuki Koba, and on Matthew Donoughe's
Cocoa port. The web engine is a port of
[oneko.js](https://github.com/adryd325/oneko.js), MIT, © 2022 adryd.

The sprites do not share one licence. The oneko animals are public domain.
Sakura and Tomoyo derive from Card Captor Sakura artwork. The oneko.js skins
come from community collections that state no licence, and several are fan art
of other people's characters. Each character's provenance is recorded in its
manifest.
