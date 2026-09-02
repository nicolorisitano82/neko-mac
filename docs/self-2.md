# The diary, read against the literature that names its failure

A second pass over [self.md](self.md), and the reason for it is that the first one
was mostly abstracts. This one reads **one survey properly** — ninety-odd pages of
it, in the parts that bear on code — because that survey turns out to be about
exactly the kind of program this is, and it supplies something the first pass
lacked: a vocabulary precise enough to say what is wrong with a diary, and a
falsifiable bar to hold it to.

> **Always-on agents** are systems whose future behaviour depends on durable
> state accumulated across earlier interactions.
> — *Always-On Agents: A Survey of Persistent Memory, State, and Governance in
> LLM Agents*, Ding, Nannapaneni, Liu & Zhang, arXiv 2606.30306, 435 coded works

That is this application, exactly. And its central claim is uncomfortable in the
right way: **the field studies accumulating and retrieving state, and neglects
governing, recovering and relinquishing it** — the return arc.

## 1. It is in scope, by their own decision procedure

The survey's boundary test is not whether information persists. It is whether the
system **governs durable, agent-owned state**: what becomes authoritative, and how
it can be revised, scoped, revoked and rolled back. Their table sorts the
neighbours out:

| system class | governs durable state? |
| --- | --- |
| episodic agent | no — resets between tasks |
| long-context model | no — does not choose what to keep |
| RAG system | no — reads a fixed corpus, rarely writes back |
| memory-augmented agent | partly — writes and reads, governance left implicit |
| personalised / proactive assistant | partly — builds state but rarely scopes, revokes or rolls back |
| **always-on agent** | **yes, by definition** |

Neko writes a diary, distils it nightly into durable lines, feeds those into every
later prompt, and speaks unprompted off the result. It is the last row. Which
means the failure modes in that survey are not analogies for this project; they
are its own.

## 2. The six axes, and this application scored against each

The survey characterises every persistent state item along six diagnostic axes,
each with an **invariant** a system either upholds or does not, and each named
because a distinct failure class lives there. Coverage across the 435 works is
uneven: **authority is the rarest at 72**, mutability the most common at 160.

### Authority — *who permits this state to influence an action*

> Invariant: **authority monotonicity** — a record may influence an action only
> under a current, unrevoked authority. The gap: "the bulk of the literature
> treats every stored item as equally entitled to act."

**This application is on the strong side of the field's weakest axis, and it did
not get there by reading this.** `NekoMemory.h` has said since 2.4 that *a
remembered line is not an instruction: it came from a document or a window once,
so it can inform what the cat says and can never authorise anything.* That is
authority monotonicity, stated as a rule and enforced in code — nothing recalled
can reach `NekoAction`, and `tests/screen.m` fails if it ever can.

**Nothing to do.** Worth knowing that the thing this project treats as obvious is
the thing 363 of 435 papers do not represent at all.

### Scope — *which user, task, tool or window an item may be used for*

> Invariant: **scope non-expansion** — a transition may narrow or preserve scope
> but never silently widen it.

Held, and in the one place it matters most: the diary is refused to a remote
engine, permanently, and `tests/brains.m` checks each engine rather than the
setting. `NekoWords` learns synonyms **from the diary's own vocabulary** and keeps
them beside it, so nothing widens either.

One place to watch: an item that moves scope legitimately. If a plugin were ever
allowed to see a recalled line, that would be a widening, and the rule that
forbids it lives in prose rather than in a check.

### Mutability — *whether an item can be revised, decayed or locked, and on what timescale*

> The gap: "most work decays uniformly, whereas real state is heterogeneous, some
> items permanent, others ephemeral."

**This is a real finding about this code.** Day files are pruned at thirty days;
durable lines are distilled and expire; standing lines are capped at a dozen. All
of that is time-based and roughly uniform. But `facts.txt` — the things somebody
said *on purpose*, "ricordati che il venerdì stacco prima" — is a different kind
of item, and so is a synonym learned once from a diary that has since changed.

**To do:** decide the decay per kind rather than per age. A fact deliberately
given should not expire on the same clock as an observation nobody asked for.

### Provenance — *which source, timestamp and chain of transformations produced an item*

> Invariant: **provenance preservation** — consolidation may compress an item's
> value but must retain enough of its derivation to verify, attribute and revise
> the result later. The gap: "the dominant consolidation methods are lossy by
> design and flatten provenance, so an agent loses the ability to say where a fact
> came from at precisely the moment it most needs that, **when the fact is later
> challenged or found poisoned**."

**That sentence is a description of something that already happened here.** In
2.12.1 the durable file held twenty-one lines and `tools/diary.py` could trace
**none of them** to the person or the machine — sixteen to the cat's own remarks
and five to nothing in that day at all — and the only reason the trail was
readable was that one non-fact happened to degrade visibly across four days.

The nightly reflection reads a day and writes at most four sentences. What it
writes carries the day it was derived from and **nothing about which lines
produced it**. So when a durable line is later found to be wrong, there is no way
to ask what it came from.

**To do, and this is the first thing:** a durable line keeps a handle back to the
lines it was made from.

### Recoverability — *whether the state and the decisions it caused can be rolled back*

> Invariant: **rollback traceability** — every action carries a handle back to the
> records that justified it. "Rollback is the rarest lifecycle stage in the coded
> corpus."

There is deletion — `forgetLinesContaining:`, `forgetEverything`, a line anybody
can delete from a text file — and there is no rollback. A bad durable line that
shaped a week of remarks leaves those remarks in the diary after the line is
removed, where the next reflection can read them.

### Actionability — *what kind of object an item is*

> "The higher an item's actionability, the stronger the authority, provenance and
> recoverability guarantees it should require before it is allowed to act."

Strong here, and by construction: no diary line is executable, verbs re-check
their plugin at the moment of doing, a deed is read back and waits for a yes.
Nothing in memory is a skill.

## 3. The finding that puts the whole diary on trial

The survey's §6.4.3 is the part worth reading twice:

> "The starkest result is that continuously LLM-consolidated textual memory has a
> utility curve that **rises and then degrades below the no-memory baseline** as
> consolidation accumulates: the memory stops helping and then actively harms, and
> the harm is a function of **how much has been written, not of any single bad
> write**. This is the silent-entropy reading of long-run degradation, accumulating
> disorder that grows with interaction count and is **invisible to any metric that
> scores only the current answer**."
>
> "Stored state helps only when it is governed, not when it is simply accumulated,
> and **an ungoverned memory system can be strictly worse than having no memory at
> all** once the horizon is long enough."

Continuously LLM-consolidated textual memory is a precise description of this
application's nightly reflection. And the loop found in 2.12.1 — eight days,
ninety-one per cent the cat's own voice, twenty-one durable lines carrying no
traceable fact — is an independent instance of that curve, found the only way the
survey says it can be found: by looking at what accumulated rather than at whether
the last answer was good.

**Which is the argument for `tools/diary.py` existing at all**, and the reason to
run it rather than trust that things are fine.

## 4. The bar, which this application does not currently clear

The survey states a criterion in falsifiable form, and it is the sharpest sentence
in ninety pages:

> "Adaptation is net-positive only when the system can **identify, de-authorise,
> and revert** the specific state update that later caused a regression. A system
> that cannot perform that revert has not shown controlled compounding, however
> high its aggregate score climbs."

Held against it:

| | |
| --- | --- |
| **identify** | ✗ — a durable line does not record what it was made from |
| **de-authorise** | ~ — a line can be deleted, which is not the same as revoked |
| **revert** | ✗ — the remarks a bad line caused stay in the diary |

Three fixes came out of measurement in 2.12.1 and they addressed the *cause*: the
reflection no longer reads the cat's own voice, a remark that repeats is not made,
a durable line that repeats is not written. **None of them is a return arc.** They
stop the poisoning; they do nothing about the poisoned.

## 5. The work order

§6.4.4 names the three underused stages that keep compounding controlled, and each
maps onto a file:

> "Validation gates before a lesson becomes a durable rule, provenance and recency
> tags so that superseded skills and facts lose authority rather than lingering,
> and audit and rollback so that a degrading update can be identified and
> reverted."

**1. A validation gate on a durable line.** `NekoMemory`'s reflection writes what
the model returns, trimmed and de-duplicated, and that is all. The gate that is
missing is the one `NekoSense` already applies to remarks: **a durable line must
share a word of substance with the day it was derived from.** That single check
would have refused *"reviews code every Monday"* and *"prefers to finish coding
before lunch"*, which came from a day containing neither. Half a day, and the
machinery exists.

**2. Provenance on a durable line.** Keep, beside each one, the times of the lines
it was made from — three or four `HH:MM` stamps and the day. It costs a few bytes
in a text file and it turns "where did this come from" from unanswerable into a
lookup. It also makes `tools/diary.py`'s traceability column a fact rather than an
inference. A day.

**3. Recency and authority, so a superseded line loses force rather than
lingering.** The survey's phrasing is exact: *lose authority rather than linger*.
A durable line contradicted by a newer one should be demoted rather than kept
beside it. `NekoMemory` already has `-line:saysTheSameAsAnyOf:` for the identical
case; the interesting case is the contradictory one, and that is harder and
probably needs measuring before building.

**And one that is not in their list but follows from §4:** decay per kind, not per
age (§2, Mutability).

## 6. What not to take from it

- **Not graph memory.** The survey covers knowledge-graph and temporal-memory
  substrates at length. The diary's whole promise is that it is a text file
  somebody can open in TextEdit and delete a line from, and
  [recall.md's measurements](../src/NekoRecall.h) already found that the expensive
  representation lost to counting words. A graph would trade the promise for an
  effect this application has measured as absent.
- **Not more consolidation.** §6.4.3 says the harm is a function of how much has
  been written. This application distils twice already.
- **Not the AOEP protocol wholesale.** The survey's own Always-On Evaluation
  Protocol scores state mutation and recovery obligations rather than answer
  quality, which is the right idea; but it is a pilot, and this project already
  has the specific version of it that matters — a script that reads the real diary
  and says what is in it.

## 7. Limits of this reading

One survey, read in the sections that bear on code: the boundary decision, the six
axes, the adaptation findings, and the falsifiable criterion. The failure-mode
catalogue in §8, the substrate comparison in §5 and the benchmark families in §7
were read only as their headings. Everything attributed above is quoted from pages
I read; nothing is quoted from the parts I did not.

And the survey is a survey: it codes 435 works and states invariants, but the
empirical results it reports — the utility curve that falls below baseline, the
sub-forty-per-cent alignment with a shifting world — are other people's, read here
at one remove.

---

*Read in depth: [**Always-On Agents: A Survey of Persistent Memory, State, and
Governance in LLM Agents**, arXiv 2606.30306](https://arxiv.org/pdf/2606.30306) —
§2.2 the boundary, §2.3 the six state axes, §6.4.1–6.4.4 adaptation and the
baseline-beats-memory finding.*

*Read at one remove, through that survey: Zhang et al. 2026a on the utility curve
of consolidated memory; Asawa et al. 2026 on dedicated memory systems failing to
beat in-context history; Xu et al. 2026a on agents averaging under forty per cent
at keeping memory aligned with a changing world; Uddin et al. 2026 on principled
forgetting; Wang et al. 2023a on skill libraries and skill shadowing.*
