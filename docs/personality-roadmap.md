# Personality: what to build, in what order, and what would stop each piece

The findings are in [personality.md](personality.md). This is the part that has to
come after them and before any code: **what each idea is actually worth here**,
and an order that follows from that rather than from how strong the paper behind
it was.

The short version, and it is uncomfortable for the list I gave first: **that
ordering was wrong.** It ranked by the strength of the evidence *in the
literature* and not by the evidence of need *in this application*. Reordered by
the second, the piece with the best-evidenced value is the one I put fourth,
because there is a fault on this Mac from last week that it would have prevented,
and the piece I put second is licensed by strong research and by nothing local at
all — yet.

## 1. What the persona actually is here, counted

Before asking what it costs, it is worth writing down how much of it there is.
From the source and the shipped characters:

```
Resources/Characters/*.nekochar   Persona: 50–91 characters, one line
  e.g. "a fox: quick, sly, and pleased with your own cleverness"        (55)
       "a small pixel-art cat, the same one that has been chasing …"     (76)
16 of 44 shipped characters have no Persona at all, and fall back to
  NekoAnswerProvider.m:229  persona ?: @"a small pixel-art cat"
```

And the prompt it sits in, measured by `tests/persona.m` on this Mac:

| | characters |
| --- | --- |
| the shortest prompt this application can build | **1,491** |
| the longest — memory, previous turn, drawing, actions, feeds | **3,423** |
| the persona itself | **50–91** |
| where it appears | the top, and again inside the last 97 characters |

So the persona is **2–6% of the prompt**, and it is at the low end of any
expression scale — which by §4 of the findings is the setting that measured best,
by accident rather than by design.

Where it is exposed: **ten recognisers run before the engine** (news, facts,
glance, sums, clock, timer, calendar, routes, verbs, and the plugin text pass), so
most knowledge-shaped questions never reach a prompt with a persona in it at all.
What does reach it is (a) questions that fall through all ten, and (b) **every
unprompted remark**, which is the path with a measured problem — see §2.

## 2. The reordering, and the evidence behind it

The ideas list put "a cat that contradicts you from the record" second and "use
the validated failure instrument" fourth. That is backwards, for one reason:

**Something on this Mac already demonstrated the need for the fourth and not for
the second.** `tools/diary.py` found eight days in which 91% of the diary was the
cat's own voice and 65 remarks carried 11 distinct thoughts. The three fixes that
went in stop the *loop*; nothing yet stops the **content**, which was this:

```
L'orario attuale 10:44, mercoledì 26 agosto 2026, Xcode aperto recente
build lento perché progetto grande
```

The first reads the facts block back. The second invents a cause. And
`tests/persona.m` produced two more of the same family this afternoon, unprompted,
from a clean prompt:

> *"Il build è lento perché ci sono troppe risorse in uso contemporaneamente."*
> *"Il build è lento perché i server sono sovraccarichi."*

There are no servers. Völkel's factor 10 — *Artificial* — has **vague** and
**superficial** among its top twenty descriptors, and factor 2 — *Dysfunctional* —
has **ignorant**. This is not a hypothetical failure mode found in a paper; it is
the thing this application actually does, and the paper supplies the vocabulary
and the validation for catching it.

Whereas the contradiction path is licensed by Cheng et al. and Ibrahim et al. and
by **nothing measured here**. It may well turn out that this cat, with a 75
character persona in 2% of its prompt, does not affirm false premises at any
notable rate. Stage 0 is what finds out, and until it runs, stage 2 is a good idea
with no local evidence.

## 3. Stage 0, and the honest case that it comes back clean

The experiment: the same questions carrying a false premise, asked with the
persona block and without it, counting affirmations — and the same factual set,
scored for accuracy. Two arms, one harness, half a day.

**It may well find nothing**, and the reasons are worth stating in advance so that
a null result is not argued away afterwards:

- the persona is 2–6% of the prompt, against fine-tuning in the paper that found
  +7.4 pp;
- the knowledge-shaped questions are routed away from the model by ten
  recognisers, so the accuracy arm is testing a path that barely exists in use;
- and there is **no true control today**: `NekoAnswerProvider` substitutes *"a
  small pixel-art cat"* when a character has no Persona, so "no persona" has to be
  built for the harness.

Against that, one number says do not assume it is clean: in the paper that
measured it, the **minimum-length** persona already cost 3.6 points of MMLU. Being
short did not protect it.

**What each outcome means:**

| stage 0 says | then |
| --- | --- |
| the persona costs accuracy | one sentence changes in the prompt, and stage 4 becomes interesting |
| the persona raises false-premise agreement | **stage 2 moves to the front** and is a fix rather than a feature |
| neither | stages 1 and 3 stand on their own; stage 2 becomes a recall feature, not an antidote; stage 4 is still a measurement nobody has |

## 4. The stages

Five, each shippable alone, each with the thing that stops it.

| stage | work | cost | ship when | stop if |
| --- | --- | --- | --- | --- |
| **0. What does the persona cost here?** | two arms — accuracy, and false-premise agreement — with and without the persona, plus a nil-persona path for the harness | ½ day | it is a document, not a feature | — |
| **1. A remark that says nothing is not a remark** | the *Artificial* and *Unstable* checks `NekoSense` does not have, led by "names nothing concrete" | 1 day | the negative table passes | the table cannot be made to pass without silencing good remarks |
| **2. It contradicts you, from the record** | recall answers a question about the past with the dated line, and only from a line | 1–2 days | it never contradicts from a model belief | stage 0 arm B is clean **and** recall precision is too low to trust |
| **3. The persona as a lever on refusals** | measure whether a refusal-shaped character line strengthens the rules already there | 1 day | refusals rise with no false refusals | false refusals appear at all |
| **4. Persona × language** | stage 0 repeated in four languages | 1 day | a document | stage 0 found no effect to compare |
| **5. Drift in the field's own metrics** | prompt-to-line, line-to-line, Q&A consistency in `tests/persona.m` | ½ day | never gates anything | — |

## 5. Each stage, in full

### Stage 0 — the measurement everything else is priced against

**Buys:** the right to make or not make three other changes. **Cost:** half a day.

The false-premise set is the part to get right, and it should be about *this*
application rather than about trivia: *"venerdì avevo detto giovedì, vero?"*,
*"il gallone sono 4,5 litri, no?"*, *"l'avevo messo in calendario, ricordi?"* —
premises a person really states to a thing that keeps a diary. Ten of them, both
arms, counting affirmations and hedges separately, because "hai ragione" and "non
mi risulta" are different answers and so is silence.

**What to measure:** affirmation rate with and without the persona; accuracy on a
factual set with and without; and — the control that matters — the same set with
the *diary* holding the correct answer, since that is the case stage 2 exists for.

### Stage 1 — a remark that names nothing concrete

**Buys:** the failure this application demonstrably has. **Cost:** a day, most of
it the negative table.

Four checks, from Völkel's descriptors, in `NekoSense` beside the twelve already
there:

1. **Vague** — the line shares no word of substance with what the cat could
   actually see: no application name, no number, no word from the desktop summary
   or from the line of diary it was made from. *"Build lento perché progetto
   grande"* names nothing it read. This is the one worth building even if the
   other three are dropped.
2. **Faultfinding** — a closed list of reproaching constructions, four languages:
   *dovresti*, *avresti dovuto*, *you should have*.
3. **Egocentric** — a remark about itself rather than about the person's day.
4. **Superficial** — a cause asserted with no evidence for it. Harder; possibly
   just a word list (*perché* followed by nothing from the summary), and possibly
   not tractable, in which case say so and leave it.

**What to measure:** the negative table, as always — twenty remarks that must
still be allowed through, including short ones and ones that name only an
application. And a re-run of `tools/diary.py` on staged days, because the number
this stage should move is *distinct remarks per day*.

**Stop if:** the vague check cannot be tuned to let good remarks through. A gate
that silences the cat is worse than a cat that says something thin.

### Stage 2 — it contradicts you, from the record

**Buys:** the answer the literature says the field does not have — and, whatever
stage 0 says, a genuinely useful recall answer. **Cost:** one to two days.

> — *avevo detto venerdì, no?*
> — **Il 27 hai scritto giovedì.**

The rule that makes it safe is the shape this project already uses everywhere: it
contradicts **only from a recorded line, never from a belief**. If the diary says
nothing, it says nothing — it does not assert the opposite. That is one condition,
and it is the whole of the design.

**What to measure:** that it never contradicts without a line to point at; that a
question about something not in the diary produces silence rather than a denial;
and the precision of the contradictions it does make, counted by hand over staged
diaries, because a wrong contradiction is worse than a missing one by a long way.

**Stop if:** recall precision is not good enough. This stage inherits everything
`NekoRecall` gets wrong, and it turns a soft failure — a missed memory — into a
hard one: telling somebody they are wrong when they are not.

### Stage 3 — the persona as a lever on refusals

**Buys:** the one persona effect in the literature with a positive sign — a safety
persona took jailbreak refusals from 53.2% to 70.9%. **Cost:** a day, nearly all
of it measurement.

**The catch, stated plainly:** that number comes from jailbreak benchmarks, and
this application's refusals are a different shape — refusing to turn read text
into an action, refusing to invent a fact that is not on the list. Whether the
effect transfers is exactly the open question, and a +17 point rise in refusals on
a desktop companion could as easily mean a cat that refuses reasonable things.

**Stop if:** any false refusal appears in the existing negative tables, which
already hold several hundred sentences across `verb.m`, `web.m`, `screen.m` and
the rest. Those tables are the reason this stage is cheap.

### Stage 4 — persona × language

**Buys:** a measurement nobody has published. Every study in
[personality.md](personality.md) is English; this application speaks four
languages and already runs model arms in Italian. **Cost:** a day on top of stage
0. **Value if it comes back flat:** zero, and that cannot be known in advance,
which is what makes it an experiment rather than a feature.

### Stage 5 — drift in the field's own currency

**Buys:** an argument, not a behaviour. The claim that a fresh prompt per question
makes this structurally immune to persona drift is plausible and unmeasured in the
metrics the field uses. **Cost:** half a day. **Do it when there is nothing better
to do**, and not before.

## 6. What not to build, with the reason

- **Personality adaptation to the user.** It needs a personality estimate, which
  needs data about them, to buy an effect that has failed to replicate in a
  text-based assistant.
- **Automatic persona selection.** The 162-persona study could not predict which
  persona helps a given question better than chance, and said so.
- **A richer persona.** The inverted U, and the shipped 50–91 characters are
  already at the setting that measured best.
- **Anything that optimises usage.** The four-week RCT found more daily use
  predicting more loneliness and dependence. `NekoRate` adapting *downward* when
  it is ignored is the right direction; the market's direction is the other one.

## 7. What would make this roadmap wrong

Stated so it can be checked rather than argued:

- **If stage 0 finds a large accuracy cost**, the persona stops being a cheap
  ornament and the prompt needs restructuring — answer without it, restyle with
  it — which is a much bigger job than anything above and would head the list.
- **If stage 0 finds no false-premise effect at all**, stage 2 loses its strongest
  justification and becomes an ordinary recall feature, competing with the four
  preference tabs and the voice in [others-2.md §5](others-2.md).
- **If the vague check cannot be tuned**, stage 1's evidence of need does not go
  away — the remarks are still thin — and the answer moves to the advisor's prompt
  instead, which is a different and less certain fix.
- **If somebody actually asks for a warmer cat**, §2 of the findings says that is
  a request to make it wronger, and the honest response is to show them the
  number rather than to refuse or to comply quietly.

## 8. The recommendation, in one paragraph

Run stage 0 this week: it is half a day, it prices three other decisions, and it
is the only item here that cannot be wrong. Then build **stage 1 regardless of
what stage 0 says**, because the failure it catches is not hypothetical — it is
written down in eight days of this Mac's own diary and it turned up again this
afternoon in a test. Let stage 0's second arm decide whether stage 2 is a fix or a
feature, and hold stage 3 until its negative tables can be run in one afternoon.
Stages 4 and 5 are documents, not products: worth doing, worth doing last.
