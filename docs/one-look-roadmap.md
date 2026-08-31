# One look: is it worth building, and in what order

The design is in [one-look.md](one-look.md). This is the part that should have come
first: **what the thing is actually worth**, measured against what the application
already does, followed by a roadmap that puts the pieces in the order the analysis
gives rather than the order the design happened to list them in.

The short version, and it is uncomfortable for the idea: **the design's own
ordering is wrong.** The piece it called "most of the value" is the piece with the
least marginal value, because 2.11 shipped a better-shaped version of it a week
ago. The valuable half is the half that takes a promise away.

## 1. What screen reading is worth today, counted

Every consumer of screen text, exhaustively, from the source:

```
src/NekoDesktop.m:466  - (NSString *)nearbyText     ← the reader
src/NekoDesktop.m:573    [self nearbyText]          ← the one caller
```

That one caller is `NekoDesktop summary`, and the summary has exactly one
consumer: `NekoAdvisor context` — the remarks the cat makes without being asked.
Nothing else in twenty thousand lines reads the screen.

So the whole present value of the capability is: **it makes the unprompted remarks
better informed.** `NekoRate` starts at twelve remarks a day and adapts downward
when they are ignored, so the capability is worth *up to twelve slightly better
sentences a day*, to somebody who has granted Accessibility and turned a switch on.

That is not nothing. It is also a good deal less than the paragraph in the
preferences implies, and less than the effort the design proposes.

## 2. The uncomfortable comparison: 2.11 already did the valuable half

The design's §2.1 — *"guarda qui"*, one look, one answer — is a way to **ask a
question about what is on screen**. That is the genuinely useful thing screen
access buys, and it is much more useful than better remarks.

But **"Ask Neko about this" shipped in 2.11**, and on every axis that matters it is
the better mechanism:

| | Services entry (2.11) | one-shot look (proposed) |
| --- | --- | --- |
| permission needed | **none** — the system hands over the pasteboard | Accessibility |
| what is read | exactly what somebody selected | whatever the API finds near the caret |
| precision about it | perfect, by construction | a guess that is usually right |
| where it works | every application | applications the Accessibility API cooperates with |
| how it is invoked | menu, or a keyboard shortcut somebody assigns | a spoken or typed phrase |

The one-shot's remaining territory is **text somebody cannot or will not select**:
an error dialog, a field mid-typing, a view that does not support selection. That
is a real set and a narrow one, and the honest estimate of its size is *I do not
know, and neither does anybody else without asking people*.

**Nobody has asked for this.** In 168 commits and this project's whole history, the
requests have been plugins, verbs, the music players, the diary, the timer, routes,
the calendar, Wikipedia, characters, faster answers. Screen reading has never come
up once. The idea came from reading a competitor's feature list, which is a
legitimate way to find ideas and a poor way to rank them.

## 3. The experiment that should come before any of it

Before reshaping the permission, there is a cheaper question that has never been
asked: **does the screen text improve the remarks at all?**

It is measurable, and with the machinery this project already has:

- stage the same desktop context twice, once with `nearbyText` returning a
  realistic paragraph and once with it returning nil;
- ask the on-device model for its one remark, the way `NekoAdvisor` does;
- and count how often the remark **uses** what it read — names a word from it,
  refers to what the text is about — rather than being the same sentence about
  Xcode and forty minutes either way.

`tests/persona.m` already asks a model three staged questions and reads the
answers, so the shape exists. Twenty staged contexts is an afternoon.

**Why this comes first:** if the remarks are the same either way, the honest move
is not to reshape the permission but to **delete the capability** — which is
cheaper than all three pieces of the design, removes the most-objected-to sentence
in the README, and makes the promise simpler rather than better worded. That
outcome is entirely possible: a small model handed eleven facts about the desktop
and one paragraph of text tends to talk about the facts.

If they are better with it, the design is worth building and §4 says in what order.

## 4. The three pieces, ranked by what they buy

The design listed them in the order they occurred to it. Ranked by value per day of
work, the order inverts:

### First — a look stays on this Mac (design §2.2)

**Cost:** an hour. **Buys:** the promise the application already makes about the
diary, extended to the more sensitive thing. Today screen text follows the chosen
engine to ChatGPT or Claude; the diary refuses to, on the stated grounds that a
promise which only holds on some days is worth less than a cat that forgot.

This is one condition and one sentence in the preferences, and it turns the
uncomfortable paragraph into a plain one. It does not depend on §3's outcome —
it is worth doing even if the capability is later deleted, because it is right
today.

### Second — the time box, and retiring the switch (design §2.3)

**Cost:** half a day on `NekoTimer`'s existing machinery. **Buys:** access for the
people this application is for. A permission you must remember to revoke is one
careful people decline permanently; a stretch of time that expires by itself is
one they will try. It also removes the standing grant, which is the thing that is
out of character.

**The catch, stated plainly:** this buys *adoption of a capability worth twelve
sentences a day*. If §3 says those sentences are no better with it, this is half a
day spent making an unhelpful feature easier to turn on.

### Third — the one-shot phrase (design §2.1)

**Cost:** half a day plus a phrase table in four languages and its negative half —
*"guarda che ore sono"* must not trigger it — which is the part that always takes
longer than the feature. **Buys:** questions about text somebody did not select,
over and above a mechanism that shipped last week and needs no permission at all.

**Recommendation: do not build this until somebody asks for it.** Not because it is
bad, but because the Services entry covers the same want at a lower cost, and
because the honest measure of demand for it is currently zero.

## 5. The roadmap

Four stages, each shippable on its own, each with the thing that would stop it.

| stage | work | ship when | stop if |
| --- | --- | --- | --- |
| **0. Does it help?** | `tests/glance.m`: twenty staged contexts, with and without the text, counting remarks that use it | never — it is a harness | — |
| **1. It stays here** | one condition in `NekoAdvisor`, one sentence in four languages | immediately | — |
| **2. Or it goes** | if stage 0 says the remarks are no better: delete `nearbyText`, the switch, the paragraph, the Accessibility request | immediately | stage 0 says they are better |
| **3. The time box** | `NekoGlance`, on `NekoTimer`'s pattern: a stretch, the menu item with a countdown, auto-revoke, the switch retired | after stages 0–2 | stage 2 happened |
| **4. The one-shot** | the phrase table, the refusals, the four sentences | when somebody asks | nobody does |

Stage 0 and stage 1 together are an afternoon and are worth doing whatever happens
next. Stage 2 is the outcome most people would not plan for and the one this
project should be most willing to reach.

## 6. What to measure, per stage

**Stage 0** — the only one that is a real experiment:
twenty staged desktop contexts, each asked twice; count remarks that use a word
from the text, and read all forty by eye once, because "used a word from it" and
"was better for it" are not the same claim and only a person can say the second.

**Stage 1** — that with a remote engine chosen, the instruction block handed to it
contains nothing from the screen. `tests/brains.m` already makes this check for the
diary; this is the same assertion with a different source.

**Stage 3** — that the window closes measured from the reading side rather than
from the menu label; that it never survives a quit; and that with the old switch
retired there is exactly one way to grant this.

**Stage 4** — the negative table, which is the whole of the work: every sentence
with *guarda*, *look*, *regarde*, *mira* in it that is not a request to read the
screen.

## 7. What would make this analysis wrong

Stated so that somebody can check rather than argue:

- **If Accessibility is already granted on most Macs** for other reasons, the
  permission cost of the one-shot drops to nothing and §4's third place is too
  harsh. Checkable: ask five people.
- **If the remarks are markedly better with the text**, stage 0 says so and the
  whole feature moves up rather than down.
- **If somebody actually wants to ask about the screen** and says so, stage 4 stops
  being speculative and the ranking changes that afternoon.
- **If a future consumer appears** — a route that wants the current selection, a
  verb that acts on what is in front of you — the capability is worth more than one
  caller's worth, and this whole analysis is about the world with one caller in it.

## 8. The recommendation, in one paragraph

Build stage 0 and stage 1 this week: an experiment that has never been run, and a
promise that should have been made when the diary's was. Then let the experiment
decide between stage 2 and stage 3 — and be genuinely willing to arrive at stage 2,
which is deleting a feature nobody asked for that makes twelve sentences a day
marginally better informed at the cost of the most quoted objection to software of
this kind. Leave stage 4 alone until somebody asks for it out loud.
