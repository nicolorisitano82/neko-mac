# Does the diary need to be a graph, and would that break the product

Written because [self-2.md](self-2.md) listed graph memory under *what not to
take* and the instruction was to check that properly — **including whether the
right answer breaks the foundations of the product.** So the promise that the
diary is a text file somebody can open in TextEdit does not get to decide the
analysis. It is the thing being tested.

The short version, and it is not either of the two positions I have held:

1. **The graph survey is a taxonomy, not evidence.** It reports **no** head-to-head
   comparison against a simpler store. That settles nothing either way, and it
   means anyone adopting a graph on its strength is adopting a diagram.
2. **The real argument is elsewhere and it is precise**, and it names exactly the
   thing this application measured itself failing at last week.
3. **And it does not require breaking anything.** The architecture that makes the
   argument keeps a lossless episode log and derives the structure from it — which
   is the shape this application already has.

## 1. What the graph literature actually offers

*Graph-based Agent Memory: Taxonomy, Techniques, and Applications* (arXiv
2602.05665, read via its own page) organises the design space on four axes —
temporal scope, cognitive type, knowledge versus experience, and structural versus
non-structural — and claims four intrinsic advantages: relational modelling,
hierarchical compression, time-aware edges with validity windows, and multi-hop
retrieval. It observes, neatly, that "plain memory can be regarded as a degenerate
graph with trivial relationships".

And then:

> **No head-to-head accuracy comparisons between graph and vector retrieval. No
> latency or scalability curves. No ablation isolating the benefit of the graph
> structure.** The systems it cites — Mem0, Zep, Graphiti, HyperGraphRAG — are
> described qualitatively and never evaluated numerically against a simpler
> baseline.

Its own open problems include that **LLM-based triple extraction reliability is
unquantified**, and that it "motivates graph memory for grounding but reports no
comparative evidence that graphs reduce hallucinations better than vector
retrieval with external verification".

For a project that keeps a table of the time sentence embeddings lost to counting
words — 5 of 10 against 8 of 10, at twenty times the cost, in
[NekoRecall.h](../src/NekoRecall.h) — that is not a case. It is a vocabulary.

## 2. The argument that is real, from the other survey

[self-2.md](self-2.md)'s survey covers structured stores in §5.4, and its sentence
is the one that matters:

> "The structured substrate contributes what the vector store lacks: **the ability
> to express that a fact held during an interval, was superseded, and descends
> from a source.**"

It then names the one system in 435 works that serves three governance axes at
once — **Engram**, which "writes lossless episodes on a fast path and
**asynchronously** distils subject-predicate-object facts into a bi-temporal
knowledge graph carrying both valid-time and transaction-time, supporting
point-in-time as-of retrieval, and **resolves conflicts by invalidate-never-delete
so that every fact retains a provenance supersession chain**."

Read against this application's own scorecard in self-2.md §2, that is three of
the six axes and they are the three it scored worst on:

| axis | Neko | what the structure gives |
| --- | --- | --- |
| provenance | now the times of the notes a line came from | the chain of what superseded what |
| mutability | uniform ageing, and a correction that is not detected | valid-time updates that do not destroy history |
| recoverability | none — deletion, not rollback | as-of retrieval, which is a read-time rollback |

And the blind spot is named in the same paragraph, which is worth quoting because
it is the reason not to take the whole thing: "graph construction is often offline
and static, and few works address edge deletion, node versioning, graph-integrity
validation under concurrent updates, **or who is authorized to rewrite a
relation**."

## 3. The measured need, which is one need and not four

Yesterday's measurement, in `tests/anchor.m`:

> *"the release ships on Friday"* and *"the release slipped to Monday"* share
> **one word of three**, and the rule that collapses restatements wants half of
> the shorter. So both survive, and the stale one is in every prompt beside the
> true one.

That is the whole of the case for structure here, and it is a real case: no
amount of word-overlap tuning fixes it, because the two sentences genuinely are
mostly different words. What identifies them as the same fact is that they share a
**subject and a predicate** — *the release* and *when it ships* — which is what a
triple is and what a sentence is not.

The other three claimed advantages do not apply:

- **multi-hop retrieval** — the diary is a month of one-line notes and a dozen
  durable facts. There are no hops.
- **hierarchical compression** — already there: day files, dated lines, standing
  lines. Three tiers, and self-2.md quotes the finding that *more* consolidation
  is where the harm accumulates.
- **relational modelling of entities** — a person's week does not have an entity
  graph in it worth traversing. It has a handful of things that were true for a
  while.

## 4. So: does it break the product?

**No, and that surprised me.** The promise is that the diary is a text file
somebody can open and delete a line from, and I had been treating "graph" as the
opposite of that. Engram's architecture says otherwise: the episodes stay lossless
on the fast path and the structure is **derived, asynchronously**. This
application already has that shape — the day files are the episode log and
`durable.txt` is the distillate.

So the question is not *text file or graph*. It is: **should the distillate be
triples instead of sentences?**

And there the answer is no, for a reason that is measured rather than aesthetic.
Turning a sentence into a triple requires an extraction step performed by a model,
and this application has measured what a model does to that file: the loop of
2.12.1, where eight days of consolidation produced twenty-one durable lines none
of which traced to anything. The graph survey's own open problem is that
"LLM-based triple extraction reliability is unquantified". Adding an unquantified
model step to the one file that has already been poisoned once, in order to gain a
capability, is the trade this project keeps declining and should decline again.

## 5. What to take instead, which is one line of file format

**Invalidate-never-delete.** Engram's conflict rule is not the graph; it is a
discipline that works in a text file, and it is the piece that closes the bar
self-2.md §4 says this application does not clear.

Today, when a newer durable line supersedes an older one, the older is **removed**
(as of `df2759b`). Instead, keep it, marked:

```
2026-08-28	09:00	build slow because project big
2026-09-02	11:00	project large, build slow	← supersedes 2026-08-28 09:00
```

One more field, still a text file, still deletable by hand. What it buys, exactly:

- **identify** — which update caused a regression, by reading the chain;
- **de-authorise** — a superseded line is not offered to a prompt, but is not gone;
- **revert** — put it back, which is as-of retrieval done by a person.

That is the falsifiable criterion the survey states — *"adaptation is net-positive
only when the system can identify, de-authorise and revert the specific state
update that later caused a regression"* — met with a column rather than a
database.

**What it still does not do** is detect that Monday supersedes Friday. That needs
subject and predicate, which needs extraction, which is §4. So the chain records
supersessions that the existing rule already finds, and the contradiction case
stays open and stays written down.

## 6. What would change this

Stated so somebody can check rather than argue:

- **If a head-to-head appears** — a graph memory against a flat store, same
  corpus, same model, with an ablation isolating the structure — the first
  section of this document is out of date and the case should be re-read.
- **If extraction fidelity gets quantified** and is high, §4's objection weakens,
  because the risk is that the extraction is a second consolidation with no
  measured error rate.
- **If the diary ever grows entities worth traversing** — several people, several
  projects, references between them — then multi-hop stops being hypothetical. A
  month of one-line notes is not that.
- **And if the contradiction case turns out to matter in use**: it is currently a
  measured possibility with no observed instance. Nobody has been given a stale
  answer because of it yet, that anybody noticed.

---

*Read via its own page: [**Graph-based Agent Memory: Taxonomy, Techniques, and
Applications**, arXiv 2602.05665](https://arxiv.org/html/2602.05665v1).*

*Read in the PDF: [**Always-On Agents**, arXiv
2606.30306](https://arxiv.org/pdf/2606.30306) §5.3–5.4 on vector and structured
substrates, which is where Engram, HippoRAG, FluxMem, AtomMem, H-Mem and the
temporal-benchmark lineage are named, and where the "mutation under access" blind
spot is stated.*
