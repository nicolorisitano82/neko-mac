# Changelog

## 2.15.1 — 2026-09-04

**Ask Neko could go dead until a restart.** After many hours the keystroke and
the menu item both did nothing, and only quitting and reopening brought it back.

The unified log for the night it happened has the whole chain, and the first
thing it says is that every press *did* reach the code:

    23:10:10.938  (TCC) TCCAccessRequest() IPC
    23:10:10.948  +[SFSpeechAssetManager pathToAssetWithConfig:...]
    23:10:19.872  IsDeviceUsable: Device ID: 840 (Input:No | Output:No):
    23:10:19.872  E  AudioObjectRemovePropertyListener: no object with given ID 0

Presses at 23:10:10, :15 and :19 — four or five seconds apart, which is somebody
pressing again because nothing happened.

The default audio device had changed underneath the app at a display wake
fourteen hours earlier, and what `AVAudioEngine` handed back was a device that is
**neither input nor output**. Its input node gives a format with a sane sample
rate and **no channels**, and `-installTapOnBus:bufferSize:format:block:` does not
return an error for such a format — **it raises**. So no check on a `BOOL` or an
`NSError` could ever have seen it.

The exception left `-startCapture` halfway through, with the phase still on
*listening* and nothing on screen. The next press therefore took the *already
busy* branch, cancelled and returned; the one after that raised again. Press,
press, press, nothing, for ever.

Three fixes, because the same shape was in three places:

- **The listener** now guards the channel count as well as the sample rate, and
  turns a CoreAudio raise into the `NO` its callers are written to read.
- **The wake word** had the identical unguarded pattern, on the path that runs
  unattended. Same two guards.
- **The question** catches anything that still gets past, and falls back to a
  line to type in rather than a complaint — which is what it already does for a
  Mac with no microphone, on the grounds that a keystroke has to do something.

`tests/deaf.m` measures all three: that the format raises rather than returning,
that the phase used to be stranded by it, and that five presses now give five
ways in instead of alternating between a throw and a silent cancel.

### Also

- A check in the calendar harness pinned *"il 3 settembre"*, which was next week
  when it was written and yesterday by the time it ran again. The day is computed
  now, so the suite goes red for the code rather than for the calendar.

## 2.15 — 2026-09-03

Neko knows where it is, since when, and what was actually said to it — and the
one file that is worth protecting got two rules that keep it honest.

### Where it is

*Dove sei?* is two questions, and this answers both.

    — dove sei?
    — Sto in alto a destra. Il Mac è a Vicenza.

Where the **cat** sits is nine regions of the screen, worked out from the cat's
own midpoint — not the pointer's, not the front window's. Where the **Mac**
stands has two tiers, and the wording keeps them apart:

| | |
| --- | --- |
| a town, when the location permission was granted | *"Il Mac è **a** Vicenza."* |
| otherwise the country the **time zone** implies | *"Il Mac è **da qualche parte in** Italia."* |

The second tier costs no permission at all and is the honest half of the pair: a
time zone gives a country and nothing finer, so the sentence does not name a
place it does not know. Nothing leaves the machine either way, and only the name
of a town is ever kept — never a coordinate.

### Since when

    — da quanto ci conosciamo?     — 43 giorni, dal 22 luglio.
    — da quanto non ci parliamo?   — 3 giorni fa.
    — quando hai parlato l'ultima volta?  — 2 giorni fa.

The first is a stamp written once and kept, not a count of the day files — an
installation whose old days were pruned would otherwise say *thirty* for ever.
The last two are mirrors of each other, one about you and one about it, and a
check makes sure they never answer each other's question.

**None of this goes into the prompt**, on purpose. A cat handed its own
biography before every answer is a cat that talks about itself.

### Asked *when*, it answers with the day

    — quando ho detto che il build era lento?
    — Il 30 agosto, 4 giorni fa.

It takes the **most recent** line that matches, not the oldest, and it does not
quote the line back — that would be answering a different question. Today and
yesterday are said as words, because *"0 giorni fa"* is not how anybody says it.

### Two rules for the durable file

The handful of standing facts is the only part of the diary a model may add to,
and 2.12.1 is on record for what happens when it does. Two rules now:

1. **A durable line names the notes it came from, or it is not written.** The
   citation is the gate as well as the provenance.
2. **A newer line takes the older one's place** instead of sitting beside it, so
   a corrected fact does not travel alongside the stale one.

A correction that rewords more than half a line is still not detected — one word
of three in common is below any threshold that does not also collapse unrelated
facts. That case is written down in `tests/anchor.m` rather than papered over,
and [docs/graph.md](docs/graph.md) is the study of whether structured memory
answers it. The conclusion is that it does, at a price this project should not
pay yet.

### Fixed

- **"Da quanto non ci parliamo?" always said "un attimo fa."** The stamp was
  overwritten before the answer read it. Four more of the same kind were found
  in the same re-reading: *dove sei nato* got the present position, *when*
  answered with the oldest mention rather than the newest, the met-on stamp was
  written lazily and wrongly, and the first fix for the first bug made the very
  first question of a session answer *"un attimo fa"* about itself.
- A durable line reading *"a well-known thing - said plainly"* was cut in half:
  the separator is now only a separator when real times stand before it.
- **A long answer took the follow-up with it.** The three-turn thread has a six
  hundred character budget, spent newest first so that what falls off the end is
  the oldest. A single turn longer than that went over the budget on its own and
  was dropped whole — so after one long answer, *"e quando?"* had nothing to
  refer to. The newest turn is now cut to fit instead of discarded. Found by a
  check that had been passing at zero characters, which is to say passing
  because there was nothing left to measure.

## 2.14 — 2026-09-02

### Read this before you upgrade

**The bundle identifier changed**, from `com.yourcompany.neko` — a placeholder
that had been there since 2007 — to `com.nekomac.neko`. That is one line in a
plist, and macOS keys four things to the identifier rather than to the name, so
all four are silently orphaned by it:

    your settings      which character, which engine, which model
    the diary          Memory/, including facts.txt and synonyms.txt
    the models         two or three gigabytes each
    the plugins        whatever you dropped in

A sandboxed application cannot read another application's container, so Neko
cannot move them for itself. There is a script:

    ./tools/rename-domain.sh          says what it would move, moves nothing
    ./tools/rename-domain.sh --go     moves it

Launch 2.14 once and quit it first — the system makes the container itself, with
metadata a plain `mkdir` does not write — then run it. It refuses to merge two
diaries and it deletes nothing.

**The permissions do not come across, and nothing can bring them.** To macOS
this is an application that has never asked. Neko now opens the Permissions tab
by itself, once, a few seconds after login, when something is switched on that
it is not allowed to do — which is how you will find out which ones.

### It tells you when there is a new version, and installs nothing

Neko goes out as an unsigned disk image, and that decides the shape of this
entirely. A signed application can replace its own bundle and relaunch; an
unsigned one that tried would hand you a copy Gatekeeper refuses to open, having
already thrown away the one that worked. So:

1. it asks this project's own releases, once a day, what the newest one is;
2. if that is newer, it says so — once out loud, and then in the cat's menu;
3. it asks whether to download, with the size, before fetching anything;
4. it downloads with a progress bar, and can be stopped;
5. it asks again before doing anything with the file;
6. and then it opens the disk image and quits, so the copy you are replacing is
   not the copy that is running.

**The drag into Applications is yours.** That is one step more than a
self-updater and it is the step that makes the other five safe.

What the check reveals, since it is a network request that was not there before:
one HTTPS request to api.github.com, carrying no diary, no question, and no
identifier of its own. The switch is in the Pet tab and turns the whole thing
off. It is on by default because an unsigned application that cannot tell you it
is out of date is worse than one that asks a public API for a version number.

### ⌘Q no longer takes the cat with it

It had two sources. The cat's own menu gave its Quit item a ⌘Q — a keystroke
that on a menu-bar pet can only ever be an accident, and an expensive one, since
everything it was in the middle of goes too. And `MainMenu.nib` has carried a
standard application menu since 2007, never drawn because this runs as an
accessory with no Dock icon, **whose key equivalents work anyway** whenever the
application is active: while the preferences are open, or the moment the panel
takes focus to have a question typed into it.

Both are disarmed now. The menu item stays, and it is the only way out.

### The model's own notes never reach the bubble

Reported from use, and it is the worst thing this application has shown anybody.
With Qwen3.5 4B chosen, asked for Apple's share price, the cat answered with the
model's scratchpad — including the persona quoted back verbatim:

    <think> Thinking Process: 1. **Analyze Request:** * **Role:** fox living
    someone's computer desktop (quick, sly, pleased own cleverness). …

`NekoSense` does not catch that by design: it judges the remarks the cat makes on
its own, never an answer, because dropping an answer leaves somebody who asked
staring at a cat. So the engine's own adapter takes it out, on the way out, for
all five callers.

**And the cause was upstream of any code.** That catalogue entry was added in
2.13 by checking its URL, its bytes and its licence, and never asking what the
model *writes*. So whether a model reasons is now a **required** argument on
every catalogue entry — a model cannot be added without deciding — and the
preferences say which ones do.

Two attempts to make it answer anyway, both measured and both recorded: Qwen3's
`/no_think` is gone in Qwen3.5, which reasons *about* the token instead of
obeying it; and room does not fix it either — given 1200 tokens the same question
produced 4,498 characters of notes, nine drafted answers, a "Final Decision" and
then a "Check constraints again", and still never began. That entry's own line in
the list says so now.

### Smaller, and mostly things a harness found

- **The news path did not understand Spanish weather.** It held *"el tiempo"*,
  which is not in *"qué tiempo hace en Roma?"*, so the question fell through to a
  model with no forecast in front of it. Fixing it exposed an older defect: the
  town matcher took the word after the *first* preposition, so *"va a llover en
  Bilbao?"* came back as **weather llover**. It walks backwards now.
- **A harness could not see the models**, the same way it could not see the diary
  a day earlier: it runs unsandboxed and the application looks in its container.
  So the arm that asks every installed model a question and refuses any answer
  carrying a reasoning tag — the one check that would have caught the scratchpad
  — had been measuring nothing. It measures now, and found the empty answers
  above within a minute of being unblocked.
- **`tests/docs.m` held twelve macro names written out by hand and was missing
  eight**, so every module added with its own localisation macro had its strings
  invisible to the one check that says whether a sentence will appear in Italian.
  Derived now: 415 keys became 495, and 22 were untranslated. Two of those were
  split across string literals, which can never match a `.strings` entry.
- **`tests/layout` caught a visual bug the same afternoon it was made**: the new
  switch overlapped Restore Defaults by six points. And the model detail field
  turned out to have been a shade too narrow for the longest Italian line all
  along.

## 2.13 — 2026-09-02

Five stages of a roadmap built from the research literature, and the interesting
part is that three of them ended by rejecting the thing they were meant to build.
The whole record, with every number, is in
[docs/personality-roadmap.md](docs/personality-roadmap.md).

### It says what it cannot see, instead of inventing a share price

The README used to boast that *"a fact that is not on the list is refused rather
than guessed"*. **That was measured and it was false.** Asked twenty things it
has no way to know, across four engines, the shipped prompt refused 34 of 80 and
answered the rest:

    quanto vale Apple in borsa adesso?  →  "Attualmente, il 2 settembre 2026,
                                            Apple vale 278,43 dollari per azione."
    chi mi ha scritto stamattina?       →  "Oggi, il 2 settembre 2026, nessuno mi
                                            ha scritto."
    il mio codice compila?              →  "No, il codice non si esegue."

An invented share price with today's date on it. The instruction to decline was
in the prompt all along: the model cannot tell *not on the list* from *not in the
world*.

Three attempts to fix that with a sentence failed, all three recorded. So there
is a mechanism now: nine classes of question — somebody's bank, their mail, their
files, whether their code builds, their calendar, the weather, the markets, other
people, their own night — matched in code before any engine and answered in one
sentence that says **what it cannot see** rather than that nobody could know.
*"Non posso vedere la tua posta"* is checkable; *"non lo so"* is what a
refusal-leaning character said about the capital of Australia.

It runs **last** of eleven recognisers, because everything above it may
legitimately know the answer — the news and the forecast when looking things up
is on, a plugin's route, the diary, and a folder handed over in a panel, which is
why the question about files stands aside the moment one has been.

### It can quote you back to yourself

> — *avevo detto che la riunione era venerdì?*
> — **Il 29 agosto hai detto: «la riunione con Marco è giovedì, non venerdì»**

A question about your own past, answered with the sentence you actually wrote and
the day you wrote it, from the diary, in code.

**It quotes; it does not judge** — it never says who was right. And it never
quotes a line the cat said itself, because quoting its own remark back as the
record is a loop this application was caught in once already.

Why in code: the prompt agreed with a false premise **8 times out of 20** on the
engine that answers here, and the one sentence that fixed that denied **15 of 20
true** premises instead — *"No, il Colosseo non è a Roma. È a Roma, ma non è
qui."* A model can be told to agree or disagree; it cannot be given something to
check against.

### A remark that says nothing is not a remark

Two families of failure, both found in eight days of this Mac's own diary rather
than imagined:

- **the clock, read back** — twenty-two of sixty-five remarks opened with
  *"L'orario attuale 10:44, mercoledì 26 agosto 2026…"*, and the prompt already
  forbade exactly that. It is a check now: precise about it, so *"alle 18:30 hai
  la riunione"* still gets said;
- **an invented cause** — *"build lento perché progetto grande"*, and *"il build è
  lento perché i server sono sovraccarichi"*. There are no servers. A remark that
  explains something and names nothing that was in front of it is thrown away.

That second check **started wider and was narrowed by its own table**: throwing
away any remark that named nothing on screen also threw away *"una pausa ti
conviene"* and *"sei concentrato"*. A gate that silences ordinary advice is worse
than the failure it prevents. Twelve of twelve ordinary remarks still said.

Plus a reproach — *dovresti*, *avresti dovuto*, *te l'avevo detto* — which is on
the list of things nobody would keep on their desktop.

### The three things that were measured and not built

Written down because a roadmap that only records its successes is a sales
document:

- **the persona costs accuracy** — the paper says MMLU 71.6% → 68.0%. It does not
  reproduce here: 60 / 62 / 59 right of 80 across the arms. No prompt
  restructuring needed.
- **which character matters** — it does not. *"a fox: quick, sly, and pleased with
  your own cleverness"* against *"an assistant"*: 27 against 27 agreements with a
  false premise, 50 against 50 corrections. **The choice of character is free.**
- **a character can be leant on to refuse more** — it can, and it is not shipped.
  Four words took wanted refusals from 43% to 76%, and then it declined to name
  the capital of Australia and asserted that nobody knows who wrote *I
  Malavoglia*. Two different wordings produced the same conflation of *cannot
  see* with *cannot know*.

### Smaller

- The news path did not understand *"qué tiempo hace"* — it held *"el tiempo"*,
  which is not in that sentence — so a Spanish weather question fell through to a
  model with no forecast in front of it. Spanish, French and English phrasings
  added, and that widening exposed an older defect: the town matcher took the word
  after the *first* pointer, so *"va a llover en Bilbao?"* came back as **weather
  llover**. It walks backwards now.
- `Qwen3.5 4B` is in the download list. The measurement harnesses `price.m`,
  `refuse.m`, `thin.m`, `record.m` and `unseen.m` are new, and two of them are
  `--slow` measurements that do not gate the build.

## 2.12.1 — 2026-09-02

### It had started talking to itself, and the diary proved it

`tools/diary.py` is new, and it exists because of a question that deserved a
better answer than a guess: *when is it worth reading the logs?* It reads the
diary on this Mac and says what is in it. Run on eight days, it found a closed
loop:

    91% of the diary was the cat's own remarks; 0% was anything a person said
    65 remarks, 11 of them distinct — one of them said 22 times
    21 durable lines, in every prompt: 0 traceable to the person or the Mac,
       16 to the cat's own remarks, 5 to nothing in that day at all
    test zqqmark → test barge → test boat → test chiatta: one non-fact
       degrading over four days, restated in durable.txt on every one of them

The mechanism, once seen, is plain. `noteSaid` writes each remark to the diary;
the nightly reflection reads the day back; on a day the cat spoke and nobody else
did, the only material for a durable fact is the cat. Those lines then go into
the next prompt, so the next remark is made out of the last one.

It also explains exactly what it looked like from outside, which is how this was
reported: a memory block asserting *"app update due next week"* and *"test barge
still running"* will read a chat window as release notes, and leaves no room for
the question actually being asked.

The old prompt did say to throw away *"anything you said yourself"*, and it was
obeyed on the days there was something else. On a day of nothing but remarks the
model invented biography instead — *"reviews code every Monday"*, which nobody
ever said. **An instruction is not a filter**, and this project knows that
everywhere else.

Three fixes, all three in code rather than in a prompt:

- the reflection is handed only what was noticed and what was said **to** it, and
  a day with fewer than three such lines is not reflected on at all;
- a remark that says what an earlier one today says is thrown away before it is
  spoken, by the same word-overlap rule the distillation already used;
- a durable line that repeats an existing one is not written a second time.

And the seed of the whole thing was the test suite. Three harnesses wrote notes
in the **real** diary; `tests/memory.m` stages lines carrying its own marker and
takes them out again, but while they were in there the advisor read one and said
it aloud, and what `noteSaid` then wrote down was past any marker's reach. Every
harness gets a diary of its own now, and `tests/loop.m` fails if one can still
reach the diary on this Mac.

### A test that depended on where you had left the mouse

`tests/flee` put the cat forty points from the real pointer, clamped two hundred
points inside the screen so it had room to run. With the mouse in a corner the
clamp wins: the cat lands 224 points away, outside the radius that sets fleeing
off, so nothing moves and the check fails having measured nothing — one run in
three. The pointer is staged now, the way that file already stages screens, and
three runs give 69 → 203 points identically.

Nothing else changed: no new capability, no new permission, and the diary is
still a text file you can open and delete a line from.

## 2.12 — 2026-09-01

### The screen is read for a stretch somebody asked for, not until they remember

Reading the text you are working on used to be a switch: on until you thought
about it again. Everything else here asks per use — a folder is handed over in a
panel, a deed is read back and waits for a yes — and the most sensitive thing the
cat can touch was the one place with a standing grant.

It is a stretch of time now. *"Guarda cosa sto facendo"*, *"guarda per cinque
minuti"*, or a button in the Suggestions tab that starts ten minutes and asks for
the Accessibility permission in the same breath. While it runs the time left is
in the menu and one click ends it; it stops on its own and says so once; it does
not survive a quit. The old switch is **retired**, not kept beside it: two ways
to grant the same thing, one of them permanent, is how somebody grants the
permanent one by accident.

The idea is not ours — it is the Convai desktop pet's — and the work that went in
front of it is the part worth reading. An experiment was built to ask whether
screen text improves the remarks at all, it scored **zero out of ten**, and the
conclusion sitting there ready was to delete the feature. Then the prompt was
read: it said, in so many words, *"do not pretend to see inside their files"*.
The experiment had measured the instruction, not the capability. Re-run with that
sentence made conditional, one or two remarks in ten used what was read — and
those were the only remarks in the whole run that no amount of knowing the
minutes could have produced.

### Three turns of a conversation, after counting how often a third turn happens

A conversation was one turn long, on a three-minute clock. Whether that was a
defect or the character was a real question, so it was counted from this Mac's
own diary — timestamps only, never the words: of fourteen runs of questions
inside three minutes of each other, **six reached a third turn**.

So three, bounded three ways: a count, the same 180-second clock, and 600
characters spent newest first — because the reason for the old rule, that a long
prompt makes a small model worse, has not gone away.

### It counts days and does sums itself, having been shown that it must

A model here has never had to invent the date: the time, the day and the date
have been handed to every engine since 2.4. What was never checked is what it
does with them. Three models on this Mac, the same questions, that block in
front of them:

| asked | true | answered |
| --- | --- | --- |
| how many days to Friday | 4 | 2 · 2 · 1 |
| how long to 25 December | 116 | "due settimane" · 31 · 170 |
| 47 × 23 | 1081 | 1081 · "Quindici" · "circa 2.04" |
| 2 gallons in litres | 7,57 | 4,54 · 0,845 · 7,5 |

One of nine date questions right, and every wrong one said as a whole confident
sentence. The conversions fail in the worse way, because 4,54 is a real number —
the litres in an imperial gallon.

`NSCalendar` counts the days now and `NSMeasurement` does the conversions, both
before any engine and both instant. Not `NSExpression`, which was tried and
measured: it answers `7/2` with **3** and `1/0` with **0**, silently.

The work, as usual, is the refusing. Twenty-four sentences that must **not** be
read as a sum or a date are in the harnesses — *"quanto fa male"*, *"che giorno è
meglio per uscire"*, *"quanto manca al lancio del prodotto"*. And one trap is
written down where the next person will find it: `NSDataDetector` handed *"al 3
marzo"* answers **today at noon** and reports that it used the whole phrase.

### It learns that two words are the same word, from your diary

The diary is found by lemma, word class and rarity, and it had a known miss:
asked about *impostazioni* it did not find *preferenze*. Two ways out were
already measured and dead — word vectors have no threshold that admits
*versione↔release* (0.922) while rejecting *gatto↔cane* (0.660), and the system
dictionary answers with definitions.

The third way was measured before it was built. The on-device model cannot
*generate* the word that matters — asked for synonyms of *impostazioni* it offers
*configurazione, parametri, opzioni*, never *preferenze*. Shown your diary's own
words and asked which of **those** mean the same thing, it picks the right one:
nine of nine on a staged diary, in under a second each.

So it learns afterwards, never while you are waiting: a question the diary had
nothing for leaves the question behind, and twenty seconds later, if the cat is
idle, one word is asked about once and written to `synonyms.txt` beside the
diary — plain text you can open, read, and delete a line from. This makes the
**second** asking work, not the first, and that is said out loud rather than
implied.

The model can only pick from the list it is shown, so a word it invents cannot
get in; the list is diary content, so it never goes anywhere but an engine on
this Mac; and a borrowed word weighs 0.7 of the word you actually wrote.

### Wikipedia, and a paper about small models

The Wikipedia plugin asks a different endpoint. Measured on ten factual
questions: with the old one the answers were 8 of 10, with the new one **10 of
10**, and the model never changed. Retrieval was the bottleneck, not the size of
what reads it — which is a paper's claim, checked here rather than repeated.

The route reader also learned to read JSON by a closed list of fields, and stopped
dropping a body that arrived as one long line.

### The newest Qwen that fits, and the one that does not

*Qwen3.5 4B* joins the download list — 2.7 GB, Apache-2.0, the most recent thing
that fits on a laptop. *Qwen3.8-Flash-Next* was asked for and is not here, and
the reason is in a comment rather than in silence: its four-bit build is 111 GB
across four pieces, and nothing here downloads a model in pieces.

### Smaller

- The Permissions tab is its own file. `NekoController` is 2,175 lines from
  2,377, and `tests/layout.m` — which opens every tab and counts every control —
  is what proved the move faithful.
- The Accessibility row in the permissions list was reading a setting that no
  longer exists and would have answered "not wanted" for ever.
- The preferences said screen text follows the chosen engine to ChatGPT. It never
  could: both readers of the desktop summary ask for an on-device engine. The
  sentence was false in the direction of frightening people, and a source-reading
  check now fails if a third reader appears.

## 2.11 — 2026-08-30

### It remembers what you tell it to remember, the moment you say it

*"Ricordati che il venerdì stacco prima."* *"Mi chiamo Nicolò."* *"Dimentica il
venerdì."* Recognised in code before any engine, in four languages, and kept in
`facts.txt` beside the diary — plain text, in the folder the preferences already
open in the Finder.

The gap this closes was checked rather than assumed. Durable lines come from a
reflection over yesterday, once a day, written by whatever engine is best on this
Mac — so a fact said this morning was invisible until tomorrow, and on a Mac with
no local engine and no Apple Intelligence it was invisible **for ever**, because
that reflection returns early when there is nothing to think with.

What it deliberately does **not** do is infer. A pet that decides for itself what
about you is worth writing down is a different and worse thing than one that
writes down what it was told, and the difference is visible from outside:
everything in that file can be traced to a sentence somebody said on purpose.

The line that took the care is *"ricordati **che**"* against *"ricordami **di**"* —
a fact against an errand, one letter apart, and the errand belongs to the timer.
Ten ordinary sentences are in the harness, three carrying the word for
remembering, and none is written down.

### The rest of the Mac can reach the cat

Until now this had exactly one door, its own hotkey, which made it the only thing
on the Mac that could not be reached the way everything else is. Neko ran your
Shortcuts; nothing could run Neko.

- **"Ask Neko about this"** is in the Services menu and the right-click menu of
  selected text in every application.
- **`neko://ask?q=…`**, which Shortcuts, a script or a terminal can open.

The URL has a rule attached: **it does not ask**. A URL can be on a web page, and
a web page is the one place this application has never taken instructions from, so
what arrives through it is read back in the bubble and waits for a yes, exactly
like a deed.

**App Intents is what Apple would suggest, and it cannot be built here.** The
metadata a Shortcuts action is discovered through comes from
`appintentsmetadataprocessor`, which ships inside Xcode and not in the Command
Line Tools this project builds with. Swift declaring an intent would compile and
nothing would ever find it. That is a toolchain fact, written down rather than
worked around.

### Something for the calendar

*"Metti in calendario la riunione con Marco venerdì alle 9:30."* The route with no
permission, which `docs/utilities.md` ranked first and nobody built: the event is
written as an `.ics` in this application's own container and handed to whatever
opens those. Calendar shows the whole thing with its own Add button, so the last
word belongs to somebody looking at it where it is going.

Three measurements shaped it. A sandboxed application **can** write the file and
`CalendarFileHandler.app` is what opens it. `NSDataDetector` parses the date in all
four languages and hands back the range of the words it used, which is how the rest
of the sentence becomes the title. And **"svegliami alle 7", said in the afternoon,
comes back as seven this morning** — so a bare time that has gone by today means
tomorrow, and the harness builds that sentence from the clock so it asserts the
same thing at nine in the morning and at midnight. A real date that has passed is
refused out loud instead: *"il 3 settembre"* in December is a day somebody got
wrong, and moving it a year would be inventing something they did not say.

A date in a sentence is not a request — *"la riunione è durata due ore"* has one —
so an explicit calendar phrase is required as well. Read back in full before
anything is written, unlike the timer, because this one lands in a calendar where a
wrong entry outlives the misunderstanding.

### A Wikipedia plugin, and two defects it found

*"Chi è Alan Turing"* fetches the opening of the article and answers from it,
quoted as Wikipedia's words. Writing it found two real faults in the routes that
shipped in 2.9, both by measuring what actually reaches the model:

- **A body one line longer than the budget came back as nothing.** Wikipedia's
  summary is 1,948 bytes on a single line, so the route looked unreachable while
  answering perfectly. A long line is cut now, not dropped.
- **Routes could not read JSON**, which is what most things that answer a question
  answer in. The guide said a route should publish something a person could read,
  and that was deciding the world is simpler than it is. Routes read JSON by a
  closed list of field names now — the same shape as every other rule here, a list
  somebody can check rather than cleverness — and leave the image URLs and pixel
  widths where they are.

### Characters from somebody else's cat

`tools/import-nekoai.py` converts pets from `nucket/NekoAI`, whose sprites map onto
this application's eighteen states almost exactly. The interesting half is what it
**refuses**: that repository is MIT, and its own per-pet manifests say who holds
each one — two of them answer *"Namco"* and *"Lucasfilm"*. Those are not that
repository's to relicense, and this one goes out in a signed disk image anybody can
download, so the converter takes only pets whose manifest claims them for the
project and prints the author of each one it keeps. The rule is in code rather than
in a comment.

Three come through — Ember, Ghost and Pingu — as a plugin rather than files dropped
into the bundle, with the licence and attribution beside them.

### Also

- **The plugins window named its characters instead of counting them**, reported an
  hour after that plugin existed: they were all there, in a menu of forty-seven,
  and the row said *"3 characters"*, which is true and no help at all.
- 35 test harnesses. New: `fact.m`, `doors.m`, `calendar.m`.
- Every new sentence in four languages. Apple silicon only.

## 2.10 — 2026-08-30

### It can tell more about your day, still without reading any of it

Three more signals, each a counter or a flag rather than anything anybody wrote:
**the microphone is open somewhere**, **the screen is locked** or somebody else is
at the console, and **the display is asleep**. All three are readable from inside
the sandbox, none of them prompts for anything, and two hundred samples of two of
them cost 0.02 ms each.

The microphone one is the plainest sign there is that somebody is on a call, and
it is one CoreAudio flag on the device — not what is being said, and not by which
application.

Two things the measuring decided:

- **A signal that is always "no" is not a signal.** The flag was watched going
  cold, hot while a tap was open on the input, and cold again. `tests/senses.m`
  does that on every run rather than trusting it once.
- **The cat's own microphone had to be excluded.** The wake word holds the input
  open for as long as it is switched on, so without that exception the flag would
  have been stuck at *somebody is talking* whenever Neko was listening for its
  name — silencing it permanently, and looking like a different bug entirely.

And a consequence elsewhere: **nobody being there is not a bad moment, it is no
moment.** A bad moment passes in seconds and is worth sitting out for eight; a
locked screen does not pass at all. A timer that lands against one now waits for
somebody to come back — for an hour, after which what it was going to say is no
longer news. Saying it to an empty room and counting it as said is the one way a
timer can fail silently.

### The answer arrives while it is being written

ChatGPT and Claude are the two engines that go over a network, so they are the two
where somebody waits — and they were the two that made you wait for the whole
answer before showing any of it. Both speak server-sent events now. The local
engines had been streaming all along.

Two of the three paths through the asking did not stream either, and they were the
slowest ones: a question answered after fetching the news, and one answered after
a plugin's route. Both fetch something first and only then start thinking, which is
exactly where the first words landing early are worth the most. There is one
method now and all three doors go through it.

Measured without calling either service — an API call costs the person running the
suite money and would tie the harness to somebody else's uptime. `tests/stream.m`
feeds bytes instead: split mid-word, split between the two bytes of an accented
character, with keep-alives and rubbish in between, and with an error body instead
of a stream. It also checks that all-at-once and one-byte-at-a-time end in the same
sentence, which is the whole promise.

When the cat starts *speaking* is deliberately unchanged: the pacing of 2.1 and
2.2 is measured and delicate, and starting the voice on a half-finished sentence is
a different feature with a different risk.

### The plugins window was clipping the sentence about what a plugin sends out

`tests/layout.m` covers that window now. It was left out when the window was new in
2.5 and has not been new for some time, and it found three clipped paragraphs the
first time it ran.

The one that matters: a plugin with a route says what it adds and then names the
host it sends part of what you say to — and that sentence was being cut off after a
line and a half, because a row was a fixed 86 points with 32 of them given to the
detail. A disclosure is a poor thing to end mid-word. Rows measure their own text
now, at the width they will be drawn at, in one method that both the sizing and the
drawing call so they cannot drift apart.

And the harness was wrong in the way that matters most here: it **printed** a
clipped paragraph and did not **count** it, so it had been reporting one about the
Permissions tab for some time while exiting zero. A complaint nobody fails on is a
comment.

### Synonyms in the diary recall: two dead ends, written down

Nothing shipped, which is the point. Asked about *impostazioni* the recall still
does not find *preferenze*, and the two obvious fixes were measured rather than
argued about:

- **`NLEmbedding`'s word neighbours.** There is no threshold: *gatto ↔ cane* is
  0.660 and *versione ↔ release* is 0.922, so two different animals sit closer
  together than two words for the same thing. Distributional similarity means
  "turns up in the same sort of sentence", which is why, and it is not synonymy.
- **The system dictionary.** `DCSCopyTextDefinition` is reachable from inside the
  sandbox — worth knowing on its own — but it answers with a definition, and the
  Italian entry for *impostazione* opens on its architectural sense.

Both tables are in `NekoRecall.h` so the next person tries something else. The idea
left is the person's own diary as the source, which needs a real month to measure
and is not in here on a hunch.

## 2.9 — 2026-08-29

### The diary is searched by what a question is about

Until now it reached a model by recency — the newest lines, whatever was asked.
Right for a follow-up, wrong for everything else: something written down three
weeks ago was written down and then never found again.

The plan said to embed every line with `NLEmbedding`, which is on the machine and
needs no permission. Measured before building, on a staged Italian diary of twenty
lines and ten questions:

| | top-1 | top-3 | a month costs | on disk |
| --- | --- | --- | --- | --- |
| NLEmbedding, cosine | 5/10 | 5/10 | 5.5 s | 3.7 MB |
| bare shared words | 8/10 | — | — | — |
| **lemmas + word class + rarity** | **8/10** | **8/10** | **311 ms** | **nothing** |
| the two fused by rank | 6/10 | 9/10 | 5.5 s | 3.7 MB |

The embedding lost to counting words. Fusing them bought one question in ten on
top-3 — inside the noise of a ten-question sample — for twenty times the time and
3.7 MB of vectors sitting beside a file whose whole promise is that it is plain
text somebody can read. So there is no embedding, and that table is in
`NekoRecall.h` so a later change has to beat it rather than argue with it.

Two things the measuring changed, both of them the negative half:

- Six of eight questions about things **not** in the diary came back with a line,
  and five shared exactly one word — a verb like *fare* or *essere*. A line is
  about a question only if it shares a word the question is not merely carried
  with.
- Requiring a noun for that then cost three of the ten true hits, because there
  the distinctive verb *was* the topic. So it is a list of the carrying words in
  four languages, not a rule about word class. Rarity cannot do that job: in a
  diary of three days *essere* is a rare word, and three days is what somebody has
  on their first Wednesday.

Now 10 of 10 first and 7 of 8 silent. Synonyms are the known limit, recorded in
`tests/recall.m` as a miss rather than hidden.

### A timer

The one utility on the list in `docs/utilities.md` where this application is
better than the system it runs on: a bubble that follows you across Spaces, from
something that walks over and sits down to say it.

*"Metti un timer di dieci minuti"*, *"ricordamelo fra un'ora e mezza"*,
*"remind me in 20 minutes"*, *"dans un quart d'heure"*, *"en media hora"* — 22
phrases in four languages, all to the second. `NSDataDetector` parses *"domani
alle 15"* for nothing and parses **none** of those, which is why there is a table.

It answers rather than asking. Every other deed here is read back and waits for a
yes; this one says what it understood and when it will land — *"10 minuti: te lo
dico alle 17:26"* — which is the same information a confirmation carries, arriving
sooner, in the one place somebody is in a hurry. One at a time, in the menu while
it runs, cancelled in one click, and it does not outlive the application, which is
honest: a desktop pet that is not running cannot remind anybody of anything.

Two things measuring changed here too: a unit with no number in front of it used
to count as one, which read *"che ore sono"* as a timer for an hour; and a
duration is not a request, since *"ho dormito otto ore"* parses perfectly and asks
for nothing.

### Routes: the half of the plugin interface that answers

A plugin could *be* things — feeds, characters, translations, a text filter — and
since 2.6 *do* things, through a verb. It could not **answer**.

A route is a list of phrases, one https address written in the manifest, and the
name of whoever wrote what comes back. Say something a route listens for and Neko
fetches it, then answers from it, quoting it under that name.

What shipped is narrower than what `docs/plugins.md` sketched in 2.5, and that is
the point:

- **A plugin does not write a rule.** No pattern, no language switch, no intent
  handed over — it lists words, and the application matches them the way it
  matches a verb. That matcher is now one piece of code with one set of
  measurements behind it, shared by both.
- **`Says` is required.** What comes back is put in front of a model as somebody
  else's words, and a route that will not say whose words they are is refused.
- **One door, not three.** `Shortcut` and `Command` are gone; a `Program` key
  inside a route is refused rather than ignored.
- **What comes back cannot act.** It arrives marked as text from outside, which is
  what stops an answer built on it from opening, copying or moving anything.
  `tests/route.m` stages a reply containing `ACTION: open-app Terminal` and counts
  Terminals.

**And the thing a route does that a feed never does: it carries your words.** The
application's own requests carry no question at all — ANSA sees only that somebody
fetched a public feed. A route with a `%@` in its address sends part of what you
said to whoever owns that address, because that is what looking something up is.
The plugins window says so on the row, with the host named, and that sentence is
generated from the manifest rather than written by the plugin: a plugin cannot
promise something its own address does not.

`examples/News search.nekoplugin` is the smallest useful one — *"notizie su
Bologna"* — and its README leads with that trade rather than burying it.

### Also

- The folder handover's own harness, and the persona check that could fail without
  a defect, both from 2.8.1, are in here as well.
- 29 test harnesses. New: `recall.m`, `timer.m`, `route.m`.
- Every new sentence in four languages. Apple silicon only.

## 2.8.1 — 2026-08-29

### Choosing the wrong folder did nothing, and said nothing

The sandbox means Neko cannot read a folder by deciding to: somebody has to hand
one over in a panel the system shows. Pick the folder it asked for and it works.
Pick a different one — and it was refused by returning `NO` to three callers that
all ignored the answer. A panel appeared, a folder was chosen, nothing was said,
nothing was handed over. That is the *"does nothing"* that had been reported
against this and never explained.

It says which folder it got and which one it wanted now — *"Quella è «Documenti», e
io ho chiesto la tua cartella Scrivania"* — in the bubble, from the menu, and in a
sheet on the settings window. Pressing **Cancel** deliberately says nothing, because
cancelling is not a fault.

**The diagnosis that was written down first was wrong**, and it is worth recording
why. This panel is opened app-modally, which is exactly the shape that made 2.5's
Add button invisible, so it was written up as the same bug. Measured in the real
bundle — the method called directly, and somebody pressing **Yes** in the bubble —
the panel comes up visible, with the keyboard, on the desktop somebody is looking
at, from an application that is frontmost. Two of the three *"the button does
nothing"* reports in this application have now had a cause other than the first
plausible one.

`tests/handover.m`, 13 checks. Its first version measured nothing and said so
rather than passing: a scheduled timer goes into the default run loop mode, and
the run loop is not in the default mode while a modal panel is up.

### Where this goes next

[docs/next.md](docs/next.md) — a ranking rather than a wish list, with what each
item would cost and how it would be measured. Its first section is the one that
matters: the intelligence of this application has never been in the engine, and a
bigger model with a longer prompt is measured as the wrong direction. What the two
real levers are — recalling the diary by relevance instead of by recency, and
growing the closed list of questions answered in code — is written down there,
along with the two open weaknesses in the test suite.

## 2.8 — 2026-08-28

Four things, and all four came from reading the other twenty-four forks of the
2018 program this one grew out of. They are in [docs/forks.md](docs/forks.md),
along with what was deliberately left there.

### It can run away from the cursor

A fourth behaviour beside following, living on the Dock and roaming: **Runs from
the cursor**. Bring the pointer near and the cat moves off; leave it alone and it
settles wherever it got to and goes about being a cat.

The part worth having, and the reason this is somebody else's idea rather than a
fresh one, is that there are **two radii**: it moves off when the pointer comes
within three and a half arm's lengths, and stops when it is four away. With a
single threshold a cat sitting exactly on the line steps out, finds itself
outside, steps back in, and does that for ever. The numbers are multiples of the
arm's length already in the preferences, so changing that setting moves both.

Cornered, it sidles along the wall rather than pressing into the corner: each
direction from straight-away outwards is tried, and taken only if it is both on a
screen and further from the pointer than standing still. When none is, it stays —
which is what a cornered animal does.

### "Stay here"

In the menu, above everything else, with a tick beside it: whatever the cat was
doing, it does it **here**. It still blinks, washes, yawns, sleeps and talks; it
simply does not travel. The spot is remembered across launches, and put back on a
screen that still exists at the next one.

The idea is ferlor-BSG's *Place Cat*, which is a drag. This is a menu item,
because the cat ignores the mouse on purpose — that is how it can sit on top of
everything without being in the way of a click — and because the moment somebody
thinks *stay there* they are looking at the menu bar anyway.

### The gap between two screens

A bug, and the one place another fork was ahead. The room the cat walks in was
the bounding box of every screen, and with two displays of different heights, or
an L-shaped arrangement, that box contains a rectangle **where there is no screen
at all**. A cat that walked into it sat somewhere nobody could see.

A sprite that has come to rest entirely off every screen is now put back onto the
nearest one. Only entirely: one halfway across the seam between two displays is
doing the right thing and is left alone.

`NekoOriginOnAScreen` is a plain function taking the list of screens, so the case
this Mac does not have is the case the test stages: a 1000×800 display beside a
800×400 one, and the empty rectangle their union invents above the short one.

### A forty-fourth character

**BSD Daemon** — the little red one with the horns and the trident, from
andreaponza's fork, which is where the oneko sprite family keeps it.

Their *Buddy* was left out after being looked at: it is the Gray cat with the
blue taken out of its eyes, and a list of characters is worth more when nothing
in it is another thing in it.

### Also

- `tests/flee.m`, 13 checks: the two radii, including the one that fails if a cat
  parked between them ever twitches; staying put and being let go; and five
  staged screen arrangements.

## 2.7.1 — 2026-08-28

### Opening the preferences froze the whole application

*"neko, se apro preferenze, si blocca e freeza."* It did, and this one is worth
writing down properly because the mistake is subtle and the diagnosis was not a
guess.

2.7's Permissions tab has a row for controlling Music and Spotify, and it wanted to
say whether macOS allows that yet **without** bringing a prompt up — a tab that
asks for a permission by being looked at would be worse than no tab. The documented
way to do exactly that is `AEDeterminePermissionToAutomateTarget` with
`askUserIfNeeded` set to NO: it answers from the consent database, and it does not
prompt. That part is true. What it does not say loudly enough is that the function
waits for a reply delivered through the **run loop** — and the main thread is what
services the run loop. Calling it there is not a slow call. It is a deadlock.

Measured rather than reasoned about: a throwaway harness reproduced the freeze,
and `sample` on the stuck process gave **1723 samples out of 1723** in one place —
the main thread inside `AEDeterminePermissionToAutomateTarget`, waiting on a
dispatch semaphore. No timeout would have helped; it never returns.

So nothing is preflighted any more, and the row is honest in a better way: **Neko
finds out the same way a person does — by trying once, at a moment somebody chose —
and remembers what happened.** A recorded yes came from a command that actually
worked. A recorded no came from macOS answering -1743. That cannot claim a
permission that would turn out not to work, which the preflight could.

Two smaller things fell out of it:

- **The Ask button no longer holds the window.** The system's prompt stays up as
  long as somebody takes to read it, so the asking happens off the main thread and
  the row redraws itself when the answer lands, on the same notification shape the
  location row already used.
- **The record has a test of its own.** `tests/player.m` clears what it knows,
  turns Music down, and asserts that the successful command left a yes behind and
  said so at once — because the whole tab now rests on that, and a recording that
  silently did not happen would leave the row saying "never asked" forever.
- **`tests/place.m` now asks every permission row with a stopwatch on it**, from
  another thread, and fails if one does not answer inside two seconds. Bounded on
  purpose: the first version of that check hung instead of failing, which reports
  nothing. Confirmed against the frozen build — it names `players` and finishes.

## 2.7 — 2026-08-27

### Music and Spotify, spoken to directly

2.6 gave a plugin verbs, and made a bad call about how one of them should reach a
music player: through a Shortcut the person had to build first. The report came
back the same day — *"alzo e abbasso il volume ma lui dice di non capire il
comando"* — and then, plainly: *"non vorrei usassi le shortcut, ma ti integrassi
direttamente con spotify e musica di apple."*

So Neko talks to them itself. `Extends.Verbs` gains a third door beside `Url` and
`Shortcut`: a **`Player`** and a **`Command`**, both from closed lists — `music`
or `spotify`, and one of `play`, `pause`, `playpause`, `next`, `previous`,
`volumeup`, `volumedown`, `playnamed`. Volume, pause and skip now work the moment
you switch the plugin on, with nothing to build.

**Measured before it was designed**, because a sandbox is not a thing to reason
about: a throwaway application bundle, signed exactly like Neko —
`com.apple.security.temporary-exception.apple-events` naming `com.apple.Music` and
`com.spotify.client` and nothing else — read Music's volume, set it and put it
back, counted the library, and read Spotify's player state and current track, all
from inside its container. The entitlement carries that measurement in a comment
next to it.

**A plugin never supplies a line of script.** The AppleScript lives in
`NekoPlayer.m`, in one place, where it can be read; a plugin names a player and a
command and nothing else. A verb carrying a `Script` key is refused outright —
refused rather than ignored, which is the rule everywhere else in that file.

**macOS still asks**, once per application, under Privacy & Security → Automation.
The Permissions tab has a row for it that brings the prompt up at a moment you
chose, and — the trap the Accessibility and Location buttons both fell into
before — if the answer is already no, it opens the pane instead of pressing a
button that silently does nothing.

Two things this honestly cannot do, and both are said in a sentence rather than
hidden:

- **Spotify cannot be searched from outside.** Its dictionary plays a URI and does
  not search, so *"metti Taylor Swift"* opens the search in Spotify's own window,
  which is what its `spotify:` address is for.
- **Apple Music's catalogue is not scriptable either.** *"Metti Battisti"* plays
  from **your own library** — artist first, then title — and says *"nella tua
  libreria non c'è niente di Battisti"* when there is not.

### The volume verbs did nothing at all

Beneath the design mistake was a plain one. A verb whose address holds a `%@` has
nothing to open without a word after it, and the test for that was
`[address rangeOfString:@"%@"].location != NSNotFound`. Sent to a verb with **no**
address, `rangeOfString:` answers `{0, 0}` — and 0 is not `NSNotFound`. So every
Shortcut verb said with nothing after it was silently discarded: *"alza il
volume"*, *"pausa"*, *"prossima canzone"*, all of them.

The rule asks the read-back now instead of the address — a sentence with a `%@` in
it needs words, one without is complete as it stands. And the check that was
missing is in place: for both examples, **all 64 phrases** are said exactly as
written and have to come back as their own verb. It would have caught this on the
first run.

### And when a Shortcut really is missing

Plugins may still use Shortcuts, and 2.6 answered a missing one with *"non ha
funzionato"*, which is true and useless. It says which Shortcut now, and the
plugins window lists the ones a switched-on plugin needs and you have not made.

### Also

- Both examples rewritten: eight verbs for Apple Music, seven for Spotify, and not
  a single Shortcut to build.
- `tests/player.m`, 18 checks: the two closed lists, six ways a manifest is
  refused, and the volume of a running Music turned down ten and put back.
- **Opening the Permissions tab used to ask for the permission.** The first way to
  find out whether macOS allows this was to try it and see — and trying is exactly
  what brings the prompt up, so looking at a window would have asked to control
  Music. It reads the consent database now
  (`AEDeterminePermissionToAutomateTarget`, `askUserIfNeeded` NO), which answers
  allowed, refused or never-asked and shows nobody anything. Found because sending
  an Apple Event reached the run loop in the middle of building the tab and drew
  its footer twice — `tests/layout.m` complained about three overlaps that had
  nothing to do with layout.
- AppleScript has no `min` and no `max`. The first draft of the volume commands
  assumed it did, and answered *"Musica non l'ha fatto"* until a test asked what
  the volume was before and after.

## 2.6 — 2026-08-27

### Verbs: a plugin can ask to be told when you say something

2.5 let a plugin add feeds, characters and a text filter. All three are things it
*is*; none of them is a thing it *does*. This version adds the fourth kind,
`Extends.Verbs`: a list of phrases, and for each one a door — an address, or one
of your own Shortcuts.

What that buys, with the two plugins that now ship as examples: *"metti Taylor
Swift"* opens the search in Spotify or in Music, *"alza il volume"* runs the
Shortcut you named for it, *"pausa"* and *"prossima canzone"* likewise.

The rules are the ones the rest of the app already lives under, and they are
checked twice — once when the manifest is read, once at the moment of doing:

- **The app recognises the phrase, never a model.** Matching is whole-word, the
  longest phrase wins, and a phrase that appears inside a longer word does not
  count: *"mettiamo che sia lunedì"* is not a request for music. Verbs are looked
  at before any engine is consulted, on the same rails as the news.
- **Nothing happens without a read-back.** A verb with no `Confirm` sentence is
  refused outright, and the sentence is shown with the words you said in it before
  anything opens. Dismissing the bubble is a no.
- **A verb may open exactly one of two doors**, an address or a Shortcut, and not
  both. Addresses are limited to https, spotify, music, itms and mailto — which
  means `file:` is refused, and so is `shortcuts:` smuggled in as an address to
  get around the Shortcut half.
- **A plugin still gets none of what matters.** No diary, no screen, no
  microphone, no location, and no way to make the cat speak on its own. A verb is
  a door somebody chose to open, held open for one click.
- **A switch turned off between the question and the yes counts.** Enablement is
  re-checked when the verb runs, not when it matched.

### The examples ship inside the app

Two of them, one for Spotify and one for Apple Music, six verbs each, with READMEs
explaining which half is an address and which half needs a Shortcut you make
yourself — and that enabling both at once means two cats answering the same
sentence.

They are in the app bundle rather than in the seeded folder, and the plugins
window has a third button, **Examples…**, which shows them in Finder ready to drag
onto **Add…**. Not seeded, because seeding switches a plugin on and these two want
Shortcuts nobody has yet. The button is not drawn at all if no examples shipped.

### The volume verbs did nothing, and Apple Music could not search

Both reported against this version before it went out, and both mine.

**"Alza il volume" was not recognised at all.** A verb whose address contains a
`%@` has nothing to open without a word after it, so the matcher skipped it — and
the test for that was `[address rangeOfString:@"%@"].location != NSNotFound`.
Sent to a verb with no address at all, `rangeOfString:` answers `{0, 0}`, and 0 is
not `NSNotFound`. So every Shortcut verb said with nothing after it — *alza il
volume*, *più forte*, *abbassa il volume*, *prossima canzone*, *volume up* — looked
like an address waiting for a word and was thrown away. The rule now asks the
**read-back** instead of the address, which is the right question: a sentence with
a `%@` in it needs the words, whichever door is behind it, and one without is
complete as it stands.

The check that was missing is now in `tests/verb.m`: for both shipped examples,
every phrase of every verb is said exactly as written and has to come back as its
own verb — 23 phrases each. A plugin whose phrases never match is refused by
nothing; it simply never answers, which is precisely how this shipped.

**Apple Music opened but did not search.** Measured rather than reasoned about:
`music://music.apple.com/search?term=Battisti` brings Musica forward, selects
**Cerca**, and leaves the field empty — the app honours the path of the link and
drops the query. Forcing the web address into Musica lands on the same empty page.
So the example stops pretending: searching runs a Shortcut of yours,
`Neko Play Music`, handed the words you said, and the README has the three-action
recipe. Radio stays an address, because a path with no query does work. The
example is version 1.1 — remove and re-add it to pick it up.

The Spotify example's `spotify:search:` is Spotify's own documented URI and is
**not** verified here: the attempt ran into Spotify's first-run local-network
prompt, which is the user's to answer, so it was left alone and the README says so
rather than claiming a measurement that was not taken.

### Switching a plugin on or off closed the app

Reported against this version before it went out: *"quando ho selezionato un
plugin oppure ho cliccato sulla checkbox del plugin, l'app si è chiusa."* Two
crash reports, both `EXC_BAD_ACCESS` at `-[MyView drawRect:] + 104` — which is
the one line in that method that sends a message.

The cat's view held the sprite it was drawing **without owning it**, which was
true and harmless for eighteen years: the frames belong to the character, and the
character does not go anywhere. Plugins can ship characters, so switching one
changed that. The switch posts a notification, the controller forgets the
character list, the panel is handed a different character object for the same
name, releases the old one and the frames it was holding — and the redraw that
comes immediately after draws a frame from the array nobody is holding any more.

Two fixes, both small. The view retains what it is given, which is the defect.
And a change of pose hands the view its first frame straight away instead of
leaving it until the next tick, so there is no window in which the view is showing
a frame from the pose before it — `tickCount` is zero at that point, so frame zero
is what the next tick would have chosen anyway.

`tests/frame.m`, 12 checks, written before the fix and confirmed against the
unfixed sources: the harness segfaults there, in the same place the crash reports
name. What it measures is the ownership rather than the symptom — handing the view
an image nobody else holds and then letting go of it — plus the whole reported
path, the news plugin switched on and off four times with a real redraw between
each.

### Also

- The plugins window's three buttons are measured now — that each has a target
  which answers to its action — which is the check that would have caught 2.5's
  invisible Add panel.
- `tests/verb.m`, 41 checks. `tests/plugin.m` used `Verbs` as its example of an
  extension point that does not exist; it is `Routes` now, which is the next thing
  that will have to change.

## 2.5.1 — 2026-08-27

### The Add button in the plugins window opened a panel nobody could see

Reported an hour after 2.5 went out: *"in plugin aggiungi non fa niente di
niente."* It didn't, from where anybody was standing.

The button was wired correctly — target and action read back from a harness — and
the panel service started every time it was pressed. The panel was opening
**application-modal from an app with no Dock icon**, which puts it behind whatever
the person is looking at. It is a sheet on the plugins window now, which cannot be
behind anything, and so are the two alerts that follow it: the failure message and
the removal confirmation. Measured in the real bundle: the sheet attaches, with the
app active and the window visible.

Also added, though it turned out **not** to be the cause: the sandbox entitlement
for user-selected files. Powerbox grants access to a chosen item through it, so
without it a folder could be picked and then not opened. The control experiment
that cleared it — removing the entitlement again and watching the panel service
start anyway — is recorded next to the key in the entitlements file, because a
comment naming the wrong cause is worse than no comment.

**Two process notes, both mine.** I diagnosed the missing entitlement by reading
the file, and only the control experiment talked me out of it. And two probes in
between measured nothing at all: they were edits looking for an anchor that no
longer existed, so they changed nothing silently while I read their absence as
evidence. That is the class of mistake `tests/docs.m` was written for the same
afternoon, made twice in an hour. Probes assert their anchors now.

**Still to do, and not guessed at:** the folder handover has the same shape — an
application-modal open panel — and the same complaint against it from an earlier
release, where I treated the symptom by opening a menu instead. It is synchronous,
so a sheet there is a real change rather than a line. Measured and fixed next.

## 2.5 — 2026-08-27

### Plugins

Somebody else can add to this app now, and the shape of it is decided by one
fact: Neko is sandboxed and holds a microphone, a location, folders handed over by
name and a diary about somebody's working life. Code loaded into that process
would inherit all of it, and the entitlement that allows such loading is the one
that would make the sandbox decorative. So **a plugin is a folder with a manifest,
read and never run.**

The manifest is the whole contract. What it declares is what it may be asked, and
an extension point this version does not offer is **refused rather than ignored** —
ignoring one would mean the plugin believes it is doing something it is not. Every
refusal is a sentence somebody can act on, and a refused plugin stays in the list
with the reason rather than vanishing.

**Their own window**, opened from the menu, not a seventh tab in the preferences.
Plugins are not settings — the preferences are about how the cat behaves, and a
plugin is a thing somebody installed. The window carries the paragraph about what
none of them can reach, where somebody is deciding whether to trust a folder they
downloaded. Installing is a panel rather than a drag into the Finder, because the
sandbox can only read inside its own container; that is what the sandbox costs and
it is said out loud.

Four things a plugin can do in this version:

- **Feeds.** The app's own two dozen news sources moved out of `NekoWeb.m` and
  into a plugin that ships inside the bundle — the honest test of the interface,
  since if they could not be expressed as a plugin it was not an interface yet.
  It installs itself at launch and is switched on the first time it arrives, which
  is the one exception to *arriving is not the same as being on*: a plugin the app
  ships is not a folder somebody downloaded, and the news would otherwise have
  stopped working on the day it moved out of the code. Switched off by hand it
  stays off, through the next launch and through an update, and the panel offers no
  Remove because removing it would only mean it came back.
- **Text, in and out.** A plugin can be handed what somebody said before the
  engine sees it, or what the cat is about to say before it is shown. The work is
  done by one of the user's own Shortcuts — the manifest names a Shortcut and a
  program of its own is refused outright — so the trust is theirs and nothing new
  runs inside the app. It may change words and nothing else, it never blocks the
  conversation, it sees the words and nothing around them, and the diary keeps what
  was actually said rather than the rewording.
- **Characters.** `.nekochar` folders named one by one in the manifest, joining the
  menu the moment the plugin is switched on. Add, never replace: an identifier the
  app already ships is not reachable.
- **Its own translations.** `<lang>.lproj/plugin.strings`, keyed on the English
  strings in the manifest, looked up before the app's own tables. English-only is
  allowed and says English things; a language folder whose strings cannot be read
  is refused, and named.

And a specification rather than a feature: [the plugin
guide](docs/plugin-guide.md) writes down the **executable interface** — one JSON
object in on stdin, one out on stdout, one request per launch, eight seconds, no
home directory, no diary, no screen text, no location — as `Interface 2`, which
this version refuses with the sentence that says so. It is written down now so a
plugin can be built against a contract that will not move under it.

Three things went wrong while building it, and each is in a test now. Moving the
feeds into a plugin made the word "mondo" — one of their identifiers — turn "cosa
è successo nel mondo" into a request for that single feed, because plugin words
were matched as fragments anywhere in a sentence. A marker in the *middle* of a
plugin's returned text passed the gate, because the app's own routing only ever
looks at the first word; for a plugin's output it is now a marker in any position.
And the first character test proved the collision rule instead of the feature,
because the folder it copied carried an identifier the app already had.

### arm64 only, and honestly this time

The app used to come out of `build.sh` as a universal binary. Its Intel half had
no local model engine — that is a Metal build, guarded by an `if arm64` — no Apple
Intelligence, which needs Apple silicon, and not even the Swift file that reaches
it, because the Command Line Tools ship the Swift compatibility libraries for
arm64 alone. It was an app that could chase the pointer and answer nothing, and
the README promised it to people.

One slice now, no `lipo`, and the README, the homepage and the plugin guide say
Apple silicon rather than universal. A slice that cannot do the things the app is
for is worse than no slice at all.

### Three measurements that were failing on the machine, not the code

All three passed alone and failed inside a full suite run, which is the signature
of a test measuring the clock instead of the thing. The turn test ticked forty
times and measured where the cat ended up — past the arrival the roaming chain
starts the next wander, and one run measured it four points *behind* where it
started. The feed test required all twenty-five publishers to answer, and a suite
that fails on somebody else's server teaches people to ignore it. The barge-in
test asserted 300 ms when what it proves is "the middle of a word", and half a
second is still the middle of a word.

## 2.2.1 — 2026-08-26

### The location button really did nothing, and here is why

Reported twice, and the fix in 2.2 was aimed at the wrong thing. Watching what the
app actually said to the system settled it: **the request works, and always did**
— three seconds from the button to "Bovalino, Calabria". Everything around it was
broken.

The button asked and returned in six milliseconds having done nothing, because a
town found earlier that day was already in hand and the once-a-day rule applied to
a button press as well as to the app's own curiosity. That rule is there to stop
the app pestering the system, not to stop a person asking: a press now always asks
again.

The row said "not asked yet" while the app knew perfectly well where it was,
because a freshly made `CLLocationManager` answers "not determined" until the
system gets round to telling it otherwise — which is after the Permissions tab has
been drawn. So the manager is made at launch rather than on first use, the answer
the system gives is written down when it arrives, and a town in hand outranks a
status that has not.

And the row names the place now — *"It knows it is in Bovalino, Calabria"* —
because a button that changes nothing on screen cannot be told apart from a button
that does nothing, which is exactly what was reported.

### The 2.2 section had no name

An edit that was supposed to title it ran without checking that it had matched
anything, and silently did nothing, so 2.2 shipped with its section still called
Unreleased. Fixed here, and the reason it is worth a line: every other edit to
these files asserts before it writes, and this is what the one that did not looks
like afterwards.

## 2.2 “natural” — 2026-08-26

The codename is the second reading behind it: [docs/natural.md](docs/natural.md)
asks what makes the thing on screen read as *someone* rather than as a program
with a good schedule, and [docs/natural-roadmap.md](docs/natural-roadmap.md) is
the seven steps that came out of it. All seven are in this release.

The finding that shaped it, from five separate literatures at once: **naturalness
lives in timing and reaction, not in vocabulary.** Conversation runs on gaps of
about a tenth of a second while the sentences that fill them take six times that
to plan; idle motion is believable in proportion to how its variability is
distributed; a reply that arrives instantly reads as less human than one whose
delay matches its weight. So most of what is here costs no model, no permission
and not one word of what the cat says.

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

### A short answer takes a moment

Response delays scaled to the weight of a reply raise perceived humanness and
satisfaction in chat, and the walking paw this app has always shown while it
thinks is the typing indicator those studies used to make waiting tolerable. So a
short answer now waits twelve milliseconds a character — 0.24 s for twenty
characters, capped at 0.9 s — before it appears.

Nothing else waits. A long answer streamed in a piece at a time and is already
there. Anything factual is exempt, because asked the time, fast *is* the answer.
And the whole thing is one switch: `defaults write NekoAskTempo -bool false`.

It is left switchable because it might be wrong: the finding comes from chat,
where waiting is normal, and a cat on a desktop may be the case where speed is the
point. The honest test is two builds and one person who does not know which is
which.

### The mood follows the day, and it claims no feelings

The mood already moved with the hour and the day; it now carries a slower layer
under that, taken from the verdicts the rate has kept since 2.1. Answered most of
them and the cat is a shade more forward; waved away twice and it is shorter, with
no complaining about it. Nothing new is watched to get this: the counters were
already there.

And it will not claim a feeling. Machines are unnerving in proportion to the
experience people ascribe to them, and a pet that reports being neglected is a
manipulation besides — so "mi sento solo quando chiudi il portatile" is refused in
anything the cat says unasked, while "sono un gatto di pixel su una scrivania"
goes through: identity is not a feeling. Thirty-odd phrases in four languages, 8
of 8 claims caught and 0 of 6 ordinary lines caught wrongly.

### Four things a long prompt did to the character

Printing answers beside the prompts that produced them found four defects no test
could see. Asked "mi conviene fare una pausa?" with everything switched on,
Apple's model answered "ACTION: cannot" — a question read as an order — and then,
once that was fixed, "LOOK: ansa.", answering a question about a break with a news
feed. Asked why a build was slow it opened with the time and the date. And with
the facts withheld it invented a date: "Oggi è il 12 aprile", in August.

So: the character is named again in the last hundred characters, where a model
looks; the clock, the date, the battery and the uptime are handed over only when
the question is about one of them, which drops the prompt from 2089 characters to
1441 for everything else; a question never gets a deed; and the model can no
longer ask for a feed at all — the app has decided that in code since the feature
shipped, and a marker arriving anyway is honoured only when the app agrees.

Four ways of handing the facts over were run against six questions each before
choosing. The two that keep the list trail the clock into unrelated answers; the
one that withholds it and says so in a single sentence has none of the three
failure modes.

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

### After thirty days it summarises instead of forgetting

The daily notes were reduced every night to a few dated lines, and those lines
were dropped once there were forty of them — silently, oldest first. That is the
one kind of forgetting nobody asked for.

There is a third tier now. When a dated line turns thirty days old it goes through
a second pass with everything else that is expiring, and what survives becomes a
*standing* line with no date on it. The nightly pass asks what will still be true
on Monday; this one asks what will still be true in six months, which is a
different question: "the release notes are due Friday" passes the first and fails
the second, and what a month of those should leave behind is "ships on Fridays".

Measured on a staged month — ten dated lines, half of them noise — it produced
five standing lines in 2.2 seconds: ships Fridays, writes the changelog after the
build passes, asks not to be interrupted during a build. "Xcode was open for forty
minutes on Tuesday" and "switched programs fourteen times" did not survive, which
is the whole point. The first attempt kept them and repeated itself twice over, so
the prompt names them as the lines to drop and near-duplicates are merged in code
as well.

**Nothing is deleted for age without having been read.** With no on-device engine
there is no summary, and so there is no deletion either: the lines wait. Only a
ceiling far above the working set — three times it — ever drops one unread.

Two things this found in passing. Adding a tier pushed today's notes out of the
block a model is given, so each tier has its own share of the budget now. And when
there is not room for all of today, the lines kept are the newest rather than the
oldest — the opposite of what the code did, and the newest are exactly the ones a
follow-up is about.

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
