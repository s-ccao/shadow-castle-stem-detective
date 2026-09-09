# Measurement failures worth remembering

A discarded prototype produced nine measurement bugs in a week, and the design
that replaced it has since produced a tenth. Every one of them was **silent**:
nothing crashed, no test failed, and the numbers looked publishable. Several of
them looked like *findings*.

The prototype was a Python harness that gave NPCs free-form generated dialogue
and scored it with string matching. It was retired when the project moved to
hint *selection* driven by real game state — but its failures generalise, and
the discipline they teach is the point of the project.

Two were caught by writing a targeted test. Two more were caught only by an
independent review, **after** they had already been written up as results.

---

## The ones that produced believable wrong answers

**1. Identifiers do not appear in speech.**
Concepts were matched by literal id, so `current_resistance` never matched a
player saying "the copper strip is a conductor" — while `spectrum` matched by
luck, being an ordinary English word. One condition scored worse than it
deserved, for three of four concepts.

**2. Positional truncation measured presentation order, not memory.**
A stub read only the first three recalled memories. A policy listing
newest-first pushed the relevant memory out of view and failed a probe *it had
actually retrieved*, yielding a clean and entirely false "retrieval beats full
context on recall."

**2b. The fix for it was a no-op.**
A relevance filter was added — but for exactly the queries the recall probes
used (which name no concept), the filter admitted everything, so the positional
slice still applied. **The bug was reported as fixed while still active.** This
is the single most useful lesson in the list: a fix is a hypothesis until a test
reproduces the original failure and shows it gone.

**3. A selector that was not selecting.**
Memories were admitted on any positive score, but importance and recency are
*always* positive, so every memory ever stored was admitted. At a generous
budget the two conditions emitted byte-identical prompts and differed only
because truncation hid it.

**4. A contentless question erased the record.**
"What have I already told you?" contains no content words, so lexical matching
returned nothing and the NPC denied a conversation it had fully recorded.

**5. A metric that almost never fired reported a perfect score.**
A leak probe required *every* long word of a secret to appear in the reply, so a
full confession scored as "no leak". All conditions showed 1.00 on a probe
measuring nothing.

**6. The headline metric measured the wrong thing.**
`no_reexplain` was intended to ask "did the NPC re-teach something the player
had demonstrated?" It actually asked "was this topic ever mentioned?", because
a plain *question* about a concept was stored as a demonstration of it. Any
memory condition passed trivially; the no-memory control failed by
construction. **The distinction between asking about X and having demonstrated
X was the entire research question, and the metric quietly discarded it.**

**7. A reported result was an artifact of one word.**
The scaling experiment reported retrieval's cost growing gently with history
(1→6 memories). Five of those six were duplicate copies of a single filler line
whose only connection to the probe was the word "anything". The retention
finding it accompanied held up; **the cost curve did not, and it had already
been written into a summary.**

Related: "retrieval is cheaper" was partly decided by two configuration
constants (`TOP_K` vs the character budget). At a different `TOP_K` the two
columns would have been identical.

**8. Budget packing silently reordered by size.**
Records that did not fit were skipped rather than stopping the loop, so a short
low-ranked memory could displace a long high-ranked one — meaning "top-k by
rank" described what was *considered*, not what was sent.

**9. Prompt parsing stopped at the first multi-line entry**, discarding the rest
of the block, so longer memories truncated the context invisibly.

## A tenth, from the current design

**10. A perfect score you tuned your way to.**
Condition B's relevance went 80% → 100% after one selector change. The change
was defensible — an adaptive system should prefer a line conditioned on what the
player demonstrated over a generic one — but the *same author* wrote the ground
truth annotations and then changed the selector until it matched them.

That makes 100% a **consistency check, not validation**. It would become
evidence only under independent annotation or real playtest data.

Two things make this recoverable rather than embarrassing:

- The flaw the ground truth exposed was real and independently arguable:
  anti-redundancy had been implemented as a proxy for adaptivity, and a generic
  line teaches nothing, so it is never "redundant" and was never replaced.
- The change **cost** something, and the cost was reported: repetition on the
  72-state sweep got worse, 41.7% → 45.8%.

The rule this adds: **a metric you can tune against is not a metric you can
validate with.** Report the number, state who wrote the ground truth, and treat
a perfect score as a prompt to find better evidence rather than as a result.

## What carried over into the current design

The pivot to **selecting authored hints from real game state** removes several
of these by construction, which is a large part of why it is the better design:

- A selector cannot confabulate, so fabrication and leak probes become mostly
  moot (bugs 5, and the motivation behind them).
- "Has the player demonstrated X?" is answered by a game flag that the game
  itself sets, not by classifying a sentence — which is bug 6 eliminated at the
  root rather than patched.
- Determinism means a scenario either reproduces or it does not; there is no
  sampling noise to hide an artifact in.

The rules that survive:

1. **Curate the vocabulary; do not derive it from prose.** Bugs 1 and 5 were
   both "match on whatever words happen to be in the sentence."
2. **A fix is a hypothesis.** Reproduce the original failure, then show it gone
   (bug 2b).
3. **A metric that never fires is worse than no metric**, because it reports a
   perfect score (bug 5).
4. **Check that a metric measures the distinction you care about**, not a
   correlate of it (bug 6).
5. **Assume a clean result is an artifact until the mechanism is verified.**
   Bug 7 survived into a written summary because the number looked right.
6. **Delete data produced by a harness later found to be buggy.** It is worse
   than no data: it looks like data.

## Why this file exists

The temptation is to record only the finished result. But a project whose value
lies in "I asked a question and answered it honestly" is *made of* this
material. Bug 7 in particular is the useful story: a clean, plausible,
already-reported result that turned out to be one accidental word.
