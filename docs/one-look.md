# One look

A design, in the shape of the others: what is there, what is wrong with the shape
of it, what to build, and what to measure. Written after 2.11, from
[others-2.md §4](others-2.md) — the one idea in the field worth taking, which
belongs to the Convai desktop pet: screen vision granted **for a moment** rather
than **for ever**, with a countdown, an automatic revoke, and a one-shot *"take a
look"*.

## 0. What is here now, checked in the source

Reading the screen is `NekoReadTextKey`: a switch in the Suggestions tab, off
until somebody turns it on. With it on and Accessibility granted,
`NekoDesktop nearbyText` reads the field being typed in or the text under the
pointer, trimmed to a few hundred characters, refusing password fields and
silent entirely while macOS has secure keyboard entry on. All of that is good and
none of it changes.

What is worth looking at again is where that text **goes**. It is appended to
`NekoDesktop summary`, and the summary is what the **advisor** reads — the part
that speaks without being asked. So:

- the switch is a **standing** grant, on until somebody remembers it;
- what it grants is not one read but **a read on the advisor's own schedule**,
  for as long as it is on;
- and with ChatGPT or Claude chosen, that text goes to that service. The
  preferences say so, in a paragraph that is honest and uncomfortable in equal
  measure.

Nothing here is hidden. The shape is simply the wrong one for this application.

## 1. Why the shape is wrong

Everything else in Neko asks **per use**, and says so:

| capability | how it is granted |
| --- | --- |
| a folder | chosen in a panel, one folder, each time |
| a deed | read back in the bubble, waits for a yes |
| a verb | the plugin re-checked at the moment of doing |
| a question from a URL | read back before it is asked |
| the diary | never leaves the Mac, whatever engine is chosen |
| **the screen** | **a switch, on until turned off** |

The most sensitive thing this application can touch is the one place with a
standing grant. That is not a security hole — it is a switch somebody set on
purpose, next to a paragraph that says exactly what it does — but it is out of
character, and being out of character has a cost: **people who would use it once
will never turn it on.** A permission you have to remember to revoke is one most
careful people decline permanently, which means the feature is off for exactly the
audience this application is built for.

The Convai pet's answer is better and it is not more complicated: a countdown
badge, auto-revoke, one-shot, frames never stored.

## 2. The design

Three pieces, and the first one is most of the value.

### 2.1 "Guarda qui" — one look, one answer

A phrase, recognised in code before any engine, on the same rails as the news, the
timer, the verbs and the routes:

> *guarda qui* · *guarda cosa sto facendo* · *dai un'occhiata* ·
> *look at this* · *have a look* · *regarde ça* · *mira esto*

What happens: the text is read **once**, at that moment, used for **that one
answer**, and dropped. It is not put in the summary, not carried into the next
question, and not written to the diary.

The cat says what it did before it answers, because a sentence somebody can check
is the whole of the consent here:

> **Ho guardato una volta.** *(and then the answer)*

And when it cannot look — no Accessibility permission, secure input on, a password
field, nothing there — it says which, rather than answering as though it had
looked.

There is already a door of this shape, shipped in 2.11: **"Ask Neko about this"**
in the Services menu takes *selected* text. This is the same idea for the text you
have **not** selected, which is most of it, and the two should say the same sort of
sentence.

### 2.2 A look that stays on this Mac

**A look is refused to a remote engine, the way the diary is.**

This is the one place the design does more than change a shape. Today, screen text
follows the chosen engine wherever it goes. The diary already refuses to: *"a
question answered by ChatGPT is answered without it: better a cat that forgot than
a promise that only held on some days."* The screen deserves the same sentence and
for the same reason.

So: with Apple Intelligence or a local model, a look works. With ChatGPT, Claude or
a Shortcut chosen, the cat says it will not look, and why. That is one sentence in
the preferences instead of the uncomfortable paragraph, and it is a promise that
holds every day rather than most days.

### 2.3 A window, when once is not enough

For the case the switch exists for — somebody working through something and
wanting remarks about it — the standing switch becomes a **stretch of time**:

> *guarda per dieci minuti* — or a menu item, **Guarda per un po'**

While it runs it behaves exactly as the switch does today, and:

- the menu carries it with the time left, the way the timer already does, and one
  click stops it;
- it expires on its own, and the cat says so once: *"Non guardo più."*;
- it never survives a quit.

`NekoTimer` already does the whole of that machinery — a countdown in the menu
redrawn when the menu opens, a cancel, and no survival past a quit — so this is
the same shape with a different consequence.

The old switch is then **retired rather than kept beside it**. Two ways to grant
the same thing, one of them permanent, is how somebody ends up granting the
permanent one by accident.

## 3. What it must never do

- **Become an action.** Unchanged and already tested: nothing read from a screen
  can make the Mac do anything, and `tests/screen.m` fails if it ever can.
- **Be remembered.** A look is not written to the diary, not distilled, not
  recalled. What was on screen at 15:40 on a Tuesday is not something this
  application should be able to tell somebody about a month later.
- **Be taken unasked.** Nothing looks without having been asked in that sentence,
  or without the stretch of time being running and visible in the menu.
- **Reach a remote engine.** §2.2.
- **Read a password field, or anything while secure input is on.** Already true;
  the harness that proves it stays.

## 4. What to measure

The negative half is the half that matters, as usual:

1. **That one look is one look.** Ask, answer, and then ask something else — the
   second answer must contain nothing from the screen. This is the check the whole
   design exists for.
2. **That the window really closes.** A stretch set for ten seconds stops reading
   at ten seconds, measured from the reading side and not from the menu label.
3. **That a look never leaves the Mac.** With a remote engine chosen, the cat
   refuses; and the instruction block handed to that engine contains nothing from
   the screen. `tests/brains.m` already makes this shape of check for the diary and
   is where this one belongs.
4. **That nothing from a look reaches the diary**, before or after a reflection.
5. **That the refusals still refuse**: no Accessibility, secure input, a password
   field, an empty field — four sentences, four different ones.
6. **And the ordinary questions.** *"Guarda che ore sono"* is not a request to read
   the screen. The phrase list needs the same treatment the timer's got: a table of
   sentences that must **not** trigger it, including the ones with the word *guarda*
   in them.

## 5. What this costs, and what it is worth

Half a day for §2.1, an hour for §2.2, half a day for §2.3 on top of `NekoTimer`'s
machinery, and a harness of about the size of `tests/timer.m`.

What it buys is not a capability — the capability is already there and switched
off. It buys the **shape**: a screen reading that a careful person will actually
use, because using it once does not mean living with it always. That is the whole
of the idea, and it came from somebody else's cat.
