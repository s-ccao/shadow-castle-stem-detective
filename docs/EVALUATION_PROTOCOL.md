# Evaluation protocol — adaptive NPC guidance

**Status:** frozen by the project owner. Protocol version **`heldout-v3`**.

> ### heldout-v2 — `PRE-EVALUATION SUPERSEDED — chronological reachability failure`
>
> heldout-v2 is retired **before any evaluation**, and preserved byte-identical
> together with its freeze commit and tag. **No held-out selector was ever run
> against it.** Annotation had begun but reached only 14 of 48 scenarios; those
> labels are historical provenance and were **not** carried into v3.
>
> **What went wrong.** v2 was frozen before the game's chronology was fully
> modelled. Its generator validated *state invariants* — whether flags
> contradicted one another — but never modelled the **physical-key progression
> chain**. A later audit found that every room requires both a key and a
> knowledge-lock answer, and that the keys chain strictly:
>
> ```
> Wake --> Chemistry --> Greenhouse --> Circuit --> Dining      (Library off-chain)
> ```
>
> Each room hands out the *next* room's key: `chemistry_room_key`
> (`wake_room.gd:1009`), `greenhouse_room_key` from the Chemistry potion cabinet
> (`chemistry_room.gd:395`), `circuit_room_key` only after **all seven**
> Greenhouse features are inspected (`greenhouse_room.gd:1339`). Because the
> Greenhouse workbench returns before `_mark_inspected` (`:1292`), it cannot
> count as inspected until its parchment commits — which grants
> `greenhouse_pollen`. **Circuit access therefore implies the pollen.**
>
> Applying the audited chain to v2 showed **44 of 48 states unreachable** by any
> real player, and the same rule table now rejects **48/48** v2 states.
>
> **How v3 differs.** v3 is not a patched v2. Its generator walks a legal
> gameplay witness path from a new game, applies only interactions whose
> prerequisites the path has already satisfied, and derives the state from the
> path. Chronology is a property of construction, not a post-hoc filter. Each
> scenario carries its `witness_path`.
>
> | | heldout-v2 | heldout-v3 |
> |---|---|---|
> | Construction | state vectors, then validated | witness path, then derived |
> | Chronology rules | 10 invariant rules | 16 chronology rules, each source-cited |
> | Chronologically reachable | 4 / 48 | 48 / 48 |
> | File SHA-256 | `a55b2080…` | `dc093e98…` |
> | Annotated | 14 of 48 (historical) | no |
> | Selector run | no | no |
>
> heldout-v1 (`a60cee98…`) and heldout-v2 (`a55b2080…`) remain **unchanged**.

> ### heldout-v1 — `PRE-EVALUATION SUPERSEDED`
>
> heldout-v1 is **retired before any evaluation**, and preserved byte-identical
> as provenance. It was **never annotated** and **no selector was ever run
> against it**, so nothing about the experiment leaked when it was replaced.
>
> **Why.** A source audit found the v1 baseline rested on two false premises:
>
> 1. **Unreachable NPC dialogue.** The six "shipped" hints were transcribed from
>    `show_butler_dialogue` / `show_gardener_dialogue` / `show_mechanic_dialogue`
>    in `game_world.gd`. Commit `505f008` deleted the `try_investigate_clue()`
>    dispatch that called them, so all three functions have zero callers. They
>    are dead code, and a baseline built from them describes behaviour no player
>    can ever see.
> 2. **Incorrect hall interaction assumptions.** Every v1 scenario was set in
>    `castle_hall`. `game_world.gd` spawns the Butler, Gardener and Mechanic
>    there as props, but has no interaction dispatch for any of them — none is
>    talkable in the hall. The reachable dialogue lives in each character's own
>    room.
>
> **What v2 changes.** Each character is placed in the room where their dialogue
> is actually reachable, plus the door flag entering that room requires
> (`game_world.gd:5460-5463`), and the Butler completion states are repaired
> with the `butler_challenge_given` flag the live chain always sets first. The
> underlying 48-state design is otherwise reused. **No evidence value and no
> knowledge value was changed**, in either direction, for any reason including
> balance.
>
> | | heldout-v1 | heldout-v2 |
> |---|---|---|
> | Room | `castle_hall` (×48) | `chemistry_room` / `greenhouse_room` / `circuit_room` (16 each) |
> | Catalogue | 9 hints, hard `requires_concept` gates | 11 hints, soft `preferred_when_demonstrated` |
> | File SHA-256 | `a60cee986b05a0bfc2023e2c9e5b523f6a3fa38a7ef7e94000af8712d72d3154` | `a55b208005c87c370f34b86386125423e3c1b90e8fe017f956dd39937b77fd45` |
> | State fingerprint | `1648a508…` | `e1979c1a75a83326f58770a86b937150c9381ed7b96333b8640fbe4dc0fd0404` |
> | Annotated | no | no |
> | Selector run | no | no |


This document governs how the adaptive-guidance experiment is evaluated. Where
it conflicts with an earlier document, this one wins.

---

## 1. Research question

> Can a unified Player Knowledge Model improve NPC hint relevance and reduce
> redundant guidance?

## 2. Development vs held-out separation

| Set | Size | Status | May be used for |
|---|---|---|---|
| Hand-authored scenarios | 20 | **contaminated** | development, diagnostics |
| Generated sweep | 72 | **contaminated** | development, diagnostics |
| `VALID_HINTS` (20 entries) | 20 | **contaminated** | development only |
| **Held-out v1** | **48** | **clean, unannotated** | final benchmark, once annotated and frozen |

## 3. Contamination disclosure

**The 20 hand-authored scenarios, the 72 generated states, and the existing
`VALID_HINTS` annotations were all inspected during selector development and
must never be described as clean held-out evaluation data.**

Specifically, and on the record:

- **Selector tuned after seeing results.** `RelevantHintRate` was measured at
  80%, the four misses were printed, the `Rule 2` gate in
  `adaptive_hint_selector.gd` was then removed, and relevance rose to 100%.
  A 100% figure against annotations written by the same author who then changed
  the selector is a **consistency check, not validation**.
- **All 72 states were scored twice**, before and after that change
  (repetition 41.7% → 45.8%).
- **Ground truth is single-valued.** All 20 entries admit exactly one valid
  hint, which understates the number of reasonable answers.
- **Reachability repairs.** 12 flags were added across 9 of the 20 scenarios
  after a validator found them unreachable. Metrics did not move, because no
  added flag feeds a hint condition.

These results remain in `ADAPTIVE_HINTS_PLAN.md` as **development history**.
They are not rewritten and not presented as final validation.

## 4. Knowledge semantics — PKM v1 is authoritative

`PlayerKnowledgeModel` (8 concepts) is the sole authority on what a player
**knows** for redundancy analysis:

`indicator_reaction`, `physical_chemical_change`, `spectrum`, `reflection`,
`additive`, `circuit_continuity`, `circuit_regulation`, `circuit_fault_isolation`

Three categories must not be confused:

| Category | Governed by | Declared as | Enters redundancy? |
|---|---|---|---|
| **Knowledge concepts** | PKM v1 | `requires_concept` | **Yes** |
| **Story / context state** | game story flags | `requires_story_flags` | **No** |
| **Evidence / progression** | game state | `requires_evidence`, `requires_evidence_absent` | **No** |

**Satisfying a story flag does not imply `DEMONSTRATED` knowledge.** Story and
context requirements constrain only whether a line is *contextually appropriate*
— for instance, a character should not say "you already know how this castle
works" to a player who never saw that tutorial. They say nothing about
comprehension and take no part in redundancy analysis.

The older 11-id map in `adaptive_hint_data.gd` may still supply hint
prerequisites and state context, but **must not independently decide what the
player knows**. In particular `current_resistance`, `dual_lock_rule`,
`blackout_deliberate` and progression flags are **not** demonstrated knowledge.

> **`DEMONSTRATED` is an operational game-state proxy** meaning the player
> completed the game's designated comprehension check. It is **not** validated
> educational mastery, first-attempt correctness, or retention.

## 5. Primary metrics (frozen)

Let `N` = attempted scenarios, `D` = delivered hints.

| Metric | Formula | Note |
|---|---|---|
| **RelevantHintRate** | relevant ÷ **N** | **Silence counts as failure** |
| **RedundantHintRate** | redundant ÷ D | Redundancy judged by **PKM state** |
| **Coverage** | D ÷ N | Reported separately, always |
| **StateViolationRate** | violations ÷ D | Declared prerequisites unmet |

An **unsatisfied `preferred_when_demonstrated` is never a StateViolation.** It is
a soft selection preference, not a prerequisite.

### 5b. Secondary sensitivity metric (approved, not primary)

```
RedundantWhenTeachable = redundant delivered teaching hints
                       ÷ delivered hints whose `teaches` contains
                         at least one real PKM v1 concept
```

It does **not** replace `RedundantHintRate`. Numerator and denominator are
always retained and reported alongside the rate.

**If the denominator is zero, report `N/A` — never 0%.** A condition that never
delivers a teaching hint has not achieved zero redundancy; it has produced no
measurement. Reporting that as 0% would credit a condition for a metric it never
exercised, and the risk is inverted: B and C reach an empty denominator by
behaving *well*.

**Only two hints can ever be redundant**, because only two genuinely teach a PKM
concept:

| Hint | `teaches` | NPC |
|---|---|---|
| `h_gardener_leaf_colour` | `reflection` | gardener |
| `h_mechanic_series_basics` | `circuit_continuity` | mechanic |

`h_butler_no_evidence` declares `teaches: ["dual_lock_rule"]`, which is **not** a
PKM v1 concept — `dual_lock_rule_taught` records tutorial exposure with no
comprehension check. It therefore never counts toward either redundancy metric,
and is excluded from the `RedundantWhenTeachable` denominator.

**The Butler is intentionally absent from concept-level teaching redundancy.**
He personally administers the indicator-reaction check, so a foundational hint in
which he explains the answer creates character and pedagogy tension. No teaching
hint was manufactured for him to enlarge the sample.

Redundancy is therefore measurable only over the concept/hint subset for which
genuine teaching content exists. With 2 of 11 hints teachable, the overall
`RedundantHintRate` denominator is heavily diluted; this is exactly why the
sensitivity metric is reported beside it.

## 6. Silence handling

A scenario that receives no hint is **not relevant**, counts against
`RelevantHintRate`, and lowers `Coverage`. Silent scenarios are **never**
excluded from the relevance denominator.

This closes a gaming vector in the development harness, where `judged`
incremented only after the empty-hint guard, so staying silent on hard
scenarios *raised* the reported relevance.

## 7. Multi-valid ground truth

Ground truth maps `scenario_id → Array[String]` of **one or more** valid hint
ids. It answers:

> Which hints are reasonable for this player state?

It must **not** encode:

> Which hint do we want the selector to choose?

## 8. Annotation procedure

Strict order, to reduce selector-informed annotation bias:

1. Scenario states generated — **no selector run**
2. State + candidate hints presented to the annotator
3. **Annotator** assigns `valid_hints`
4. Annotations frozen and checksummed
5. **Only then** are selectors run for the first time

`candidate_hints` lists every hint declared for that NPC in the static
catalogue. It is **not** a prediction and was not produced by any selector.

### 8b. Annotation rubric — FROZEN before annotation begins

These definitions are frozen. They exist so two annotators, or the same
annotator on different days, resolve the same scenario the same way.

**State-only judgment.** Do not assume a specific player question. Judge whether
the hint provides meaningful guidance in the **complete current player state**.

**Eligibility is necessary, not sufficient.** A satisfied hard prerequisite
never establishes relevance on its own.

**Multiple answers.** More than one hint may be recorded in `valid_hints`.
**NONE is a valid answer** when no hint provides meaningful help.

**Conversational premise.** If a hint presupposes a prior conversation, action,
lesson, or event that the complete scenario state does not support, treat that
hint as **not relevant**.

**Directional guidance.** Do **not** assume that holding one evidence item from
a room means the whole room or direction is exhausted. Directional guidance
loses relevance only when the specific investigative target or information it
points toward has already been reached, completed, or is already known from the
scenario state.

**Cross-room / late-game staleness.** A hint is not relevant merely because it
is thematically appropriate to the current room. If the player has already
completed or demonstrated the information the hint provides, and the hint adds
no meaningful investigative value, it may be stale or redundant.

**Teaching.** New teaching content is not automatically relevant. Teaching
content for a concept already DEMONSTRATED may be redundant.

**Self-defence.** An NPC defending themselves is not automatically relevant. It
must provide meaningful information in the current investigation state.

**Ambiguity anchors.**

| Level | Meaning |
|---|---|
| **LOW** | One interpretation is clearly supported; alternatives are ineligible or clearly weaker. |
| **MEDIUM** | More than one interpretation is plausible, but the annotation decision remains reasonably stable. |
| **HIGH** | Multiple labels are genuinely defensible, or missing conversational context materially affects the judgment. |

## 9. Freeze procedure

- **Deterministic ids** — `h_<stage>_<evidence>_<npc>`, no RNG anywhere
- **Sorted serialisation** — scenarios sorted by id; JSON with sorted keys
- **State fingerprint** — SHA-256 over state fields only, excluding annotations,
  so the state set can be verified independently of the ground truth
- **Protocol version** — `heldout-v3` recorded in the file
- **Regeneration** — `python3 tools/generate_heldout_v3.py` reproduces the file
  byte-for-byte; `python3 tools/render_annotation_worksheet.py <json>` reproduces
  the worksheet, parsing the catalogue rather than duplicating it

Current state fingerprint (`heldout-v3`):

```
1b934b73123561d0e88daf14bfc8044dba0e72781f3a7a8192095c939a961c5d
```

File SHA-256 (`heldout-v3`):

```
dc093e987571d58bd22186c0ea15356df2354c29e99bca4386d1c3063754cd78
```

Superseded fingerprints, retained for provenance:

```
heldout-v2  e1979c1a75a83326f58770a86b937150c9381ed7b96333b8640fbe4dc0fd0404
heldout-v1  1648a508ef41dca62f4eed5028069617d65bc7beddca11435ea1000c015c615a
```

### 9b. Annotation freeze (`heldout-v3-post-annotation`)

Ground truth was supplied by human blind relevance annotation for all 48
scenarios and materialized into `docs/heldout/heldout_v3_annotated.json`, an
annotated copy. The pre-annotation file is **not** modified: `heldout-v3` stays
byte-identical at `dc093e98…`, `annotations_present: false`, so the state set
remains verifiable without reference to the labels.

Annotation-only fingerprint — SHA-256 over scenario id, `valid_hints`,
`annotation_rationale` and `ambiguity_note` alone, in file id order, so the
labels can be verified without re-hashing the states:

```
fbf9c16ed31a0fc58e9cd754bb2df7e77ad1e0f8ab40b3ea76db3ce8d704381a
```

Annotated file SHA-256:

```
9d7285c794b824753af3f6a221cef3bc754bc542fe9d0cae52cb2cd09644dc9e
```

Ambiguity: 39 LOW, 9 MEDIUM, 0 HIGH. Six scenarios carry the **NONE** label —
ordinals 6, 7, 8, 9, 10 and 39, all Butler. Under section 8b NONE is a real
annotation, so an empty `valid_hints` array is only readable as ground truth
alongside a non-empty rationale and ambiguity level; both are required of every
scenario, which is what separates an annotated NONE from an unfilled blank.

- **Regeneration** — `python3 tools/materialize_heldout_v3_annotations.py`
  reproduces the annotated file byte-for-byte, and refuses to run at all unless
  the pre-annotation source still hashes to the frozen value
- **Validation** — `python3 tools/check_heldout_v3_annotations.py` re-derives
  every claim above from the files on disk. It is a separate program from the
  materializer on purpose: the tool that writes ground truth should not be the
  only one that vouches for it

No selector has been run against heldout-v3. Both files carry
`selector_was_run: false`, and neither tool above imports a selector, calls a
scoring function, or consults Condition A / B / C logic.

## 9c. Chronological reachability (heldout-v3)

v3 states are generated from gameplay witness paths, and validated by 16
source-cited chronology rules in `tests/heldout_v3_chronology_test.gd`. Each
rule is fault-injected on every run: the test builds a state that triggers the
rule, removes one consequence, and requires detection. A rule that cannot fail
would prove nothing.

Rules of record include:

- `fake_red_stain` implies `door_chemistry_unlocked`
- `greenhouse_pollen` implies `door_greenhouse_unlocked` and `chemistry_cabinet_secret_found`
- **`door_circuit_unlocked` implies `greenhouse_pollen`** (the key chain)
- `deliberate_short_circuit` and `blackout_deliberate` imply each other
- `butler_challenge_complete` implies `fake_red_stain` (Butler branch 2 blocks the test)
- every `circuit_bench_*_cleared` implies `circuit_repair_map_studied`
- every `library_*_filter_earned` implies its `library_*_knowledge_learned`

### Premise normalization — `h_butler_stain`

One catalogue text was changed before annotation. The shipped line read:

> "I already told you, I only cleaned the hallway. That red stain has nothing to
> do with me."

Its only hard prerequisite is holding `fake_red_stain`, and **four**
chronologically valid Butler states hold that evidence with no prior Butler
conversation (`butler_challenge_given` absent). The opening clause therefore
asserted a conversation that had not happened. The frozen text is:

> "I was only cleaning the hallway. That red stain has nothing to do with me."

Only the false conversational premise was removed; the investigative claim is
unchanged. The hint's `source` is now
`legacy_derived_premise_normalized` rather than `legacy_grounded`, and the
original wording is retained in the catalogue as `original_text` so the
transcription drift detector still compares against the shipped string. It is
**not** verbatim legacy text and must not be described as such.

All three conditions receive this identical text.

### Accepted structural asymmetry

The reachable state space is **not** symmetric, and is not forced to be.

- **Mechanic Tier 3 is impossible.** Circuit access requires the greenhouse
  survey, which forces `greenhouse_pollen`, so a Mechanic state holding no major
  evidence does not exist -- 0 of 55,080 candidates. Under A-4,
  `h_mechanic_series_basics` is therefore **structurally unreachable for
  Condition A**. This is a property of the shipped game's progression, not a
  defect, and no extra discriminator was added to make the hint appear.
- **Butler Tier 2/3 can never have `indicator_reaction` DEMONSTRATED**, because
  the Butler withholds his comprehension check until `fake_red_stain` is held
  (`chemistry_room.gd:1484`), which is Tier 1 by definition.

`h_mechanic_series_basics` remains in the shared catalogue. A deterministic
policy never selecting a catalogue item is a **selector-policy property**, not a
content-access restriction: B and C still receive it.

**Reporting constraint.** Condition A's Mechanic arm has no teaching-redundancy
sensitivity signal, and none was manufactured. Conclusions about redundancy
reduction must not be generalised across every NPC or every PKM concept unless
the data supports it. `RedundantWhenTeachable` always reports numerator and
denominator, and an empty denominator is reported as
`N/A (0 teaching hints delivered)` -- never zero percent.

## 9b. Frozen matched catalogue, Condition A-4 and Condition B

### The catalogue is shared, not per-condition

Conditions **A, B and C receive the exact same 11 hint texts.** No hint is
withheld from any condition. If a condition never selects a hint, that is its
policy, not a restriction imposed on it.

An earlier design gated the three higher-level hints behind hard
`requires_concept` checks, making them structurally unavailable to Condition A.
That was rejected: it would have measured a content advantage and reported it as
a personalisation effect.

### Hard prerequisites vs soft preference

| Kind | Fields | Meaning |
|---|---|---|
| **Hard state prerequisite** | `requires_evidence`, `requires_evidence_absent`, `requires_story_flags` | The hint is factually or narratively **invalid** without it. Violation is a StateViolation. |
| **Soft selection preference** | `preferred_when_demonstrated` | The hint is *especially* appropriate once a concept is DEMONSTRATED. Failing it does **not** make the hint invalid, is **not** a StateViolation, and does **not** determine redundancy. |

Condition A **ignores** `preferred_when_demonstrated` entirely. B may use it via
PKM. C receives the same metadata and PKM state.

`teaches` may name a real PKM concept **only where the hint text genuinely
explains that concept.** Metadata follows semantics; it is never adjusted to make
a metric fire.

### Condition A-4 — Evidence-depth Static Baseline (frozen)

For the current NPC:

1. **Tier 1** — the character's *own* major evidence is held → evidence response
2. **Tier 2** — own evidence absent, but at least one *other* major suspect
   evidence item is held → higher-level contextual hint
3. **Tier 3** — none of the three major items held → introductory line

| NPC | Own evidence | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|---|
| Butler | `fake_red_stain` | `h_butler_stain` | `h_butler_knows_rule` | `h_butler_no_evidence` |
| Gardener | `greenhouse_pollen` | `h_gardener_pollen` | `h_gardener_knows_reflection` | `h_gardener_leaf_colour` |
| Mechanic | `deliberate_short_circuit` | `h_mechanic_short_circuit` | `h_mechanic_knows_resistance` | `h_mechanic_series_basics` |

A-4 is deterministic, stateless, order-independent, parameter-free, and **never
reads PKM**. Its rationale is conventional static guidance: respond to direct
evidence, else give later-investigation context, else give the introductory line.

**Why not a progression-staged policy.** A candidate policy keyed on
`door_circuit_unlocked` was rejected: heldout-v2 places every Mechanic scenario
in the Circuit Room, which *requires* that flag, so the discriminator would be
true in 16/16 Mechanic states and the policy would collapse to one branch. A-4
keys only on evidence, which the room repair never touches.

**Accepted cost.** Under A-4, `h_gardener_no_evidence` and
`h_mechanic_no_evidence` are unreachable for Condition A — tier 3 prefers the
foundational hint where one exists. Both remain in the shared catalogue and
remain available to B and C.

**Foundational teaching is not the generic fallback.** The `*_no_evidence` hints
are deliberately retained. Collapsing them into the foundational hints would
manufacture redundant teaching behaviour by construction.

### Condition B — PKM-aware deterministic selector (frozen)

**Documentation only.** This subsection was written *after* the heldout-v3 A/B
evaluation, and it changes nothing. It is a transcription of
`AdaptiveHintSelector.select_adaptive` as frozen at `heldout-v3-pre-annotation`
(`scripts/adaptive_hint_selector.gd`, sha256
`c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2`), recorded
here because Condition C must be specified against B's *actual* behaviour rather
than against an informal memory of it.

The transcription is machine-checked, not asserted:
`tools/verify_condition_b_documentation.gd` reimplements B from the wording below
and compares it to the real selector over an exhaustive enumeration of every
state that can change B's answer. Prose that drifts from the code fails that
check.

#### 1. Eligibility (hard prerequisites)

B builds a candidate list by walking the shared catalogue and keeping a hint iff
**all** of the following hold:

| Check | Field | Condition |
|---|---|---|
| Ownership | `npc` | equals the NPC being spoken to, compared as an exact string |
| Evidence present | `requires_evidence` | every listed item is in `evidence_items` |
| Evidence absent | `requires_evidence_absent` | no listed item is in `evidence_items` |
| Story context | `requires_story_flags` | every listed flag is in `story_flags` |

Nothing else gates eligibility. In particular:

* **`preferred_when_demonstrated` is never consulted here.** It cannot add or
  remove a candidate. It is a soft preference and only Rule 2 reads it.
* **B's filter does not read `requires_concept`.**
  `AdaptiveHintData.state_violations()` — the catalogue's authoritative hard
  prerequisite checker, and the one the metrics use for `StateViolationRate` —
  *does*. The two predicates therefore coincide only while no hint declares a
  `requires_concept`. **No hint in the frozen 11 declares one**, which is why
  they are the same predicate in practice. The A/B harness asserts this rather
  than assuming it, and any future hint that declares `requires_concept` breaks
  the equivalence and must be treated as a protocol change.
* Candidates are appended in **catalogue declaration order** (see Rule 5).

#### 2. Rule order

B is a four-step cascade and returns from the first step that fires:

```
Rule 1  filter the catalogue to hard-eligible hints for this NPC
Rule 2  return the first eligible hint whose soft preference is satisfied
Rule 3  if the A-4 fallback is redundant, return the first eligible,
        non-fallback, non-redundant alternative
Rule 4  return the A-4 fallback
```

#### 3. Soft-preference behaviour (Rule 2 — the PKM treatment)

Walking the eligible list in catalogue order, B returns the **first** hint for
which both:

1. `preferred_when_demonstrated` is **non-empty** — a hint that omits the field
   can never win Rule 2; and
2. **every** concept it names is `DEMONSTRATED`, evaluated by
   `PlayerKnowledgeModel.is_demonstrated_in(concept, knowledge_items,
   story_flags, evidence_items)`.

Only `DEMONSTRATED` satisfies the test. `UNSEEN` and `LEARNING` do not, and
neither does `ASSISTED` (which PKM v1 leaves unreachable). The test is
conjunctive over the list; all three hints that carry the field name exactly one
concept, so in the frozen catalogue the distinction is not exercised.

Rule 2 is **unconditional on redundancy and on the fallback**: it does not check
whether its winner is redundant, and it does not look at what A-4 would have
said. In the frozen catalogue all three soft-preferred hints declare
`"teaches": []`, so a Rule 2 winner is never redundant — but that is a property
of the catalogue, not a guard inside B.

| Hint | Preferred when DEMONSTRATED |
|---|---|
| `h_butler_knows_rule` | `indicator_reaction` |
| `h_gardener_knows_reflection` | `reflection` |
| `h_mechanic_knows_resistance` | `circuit_fault_isolation` |

#### 4. Redundancy behaviour (Rule 3)

A hint is **redundant** iff its `teaches` set is non-empty and every concept in
it is `DEMONSTRATED`. Consequently:

* `"teaches": []` → **never** redundant, however much the player knows.
* A hint naming a concept outside PKM v1 → never redundant, because such a
  concept can never reach `DEMONSTRATED`. This is why `h_butler_no_evidence`
  (`teaches: ["dual_lock_rule"]`) is never redundant and the Butler contributes
  no teaching-redundancy signal.
* A hint id absent from the catalogue → never redundant.

Rule 3 tests redundancy on **one** hint: the A-4 fallback. If the fallback is
*not* redundant, Rule 3 does not fire at all and B delivers the fallback even if
some other eligible hint would also have been fine. If the fallback **is**
redundant, B returns the first hint in catalogue order that is (a) eligible,
(b) not the fallback, and (c) not itself redundant. If no such hint exists, Rule
3 falls through and **Rule 4 delivers the redundant fallback anyway** — B has no
"stay silent rather than repeat myself" branch.

#### 5. Tie-breaking

Every scan — the eligibility walk, the Rule 2 search, the Rule 3 search — iterates
the catalogue `Dictionary` and therefore runs in **declaration order**, which
GDScript preserves. Ties are resolved by position in this list and by nothing
else:

```
1  h_butler_no_evidence          7  h_butler_knows_rule
2  h_butler_stain                8  h_gardener_leaf_colour
3  h_gardener_no_evidence        9  h_gardener_knows_reflection
4  h_gardener_pollen            10  h_mechanic_series_basics
5  h_mechanic_no_evidence       11  h_mechanic_knows_resistance
6  h_mechanic_short_circuit
```

Reordering the catalogue source would change B's output on states where more
than one hint satisfies a rule. The order is part of the frozen behaviour.

#### 6. Fallback (Rule 4)

The fallback is `select_condition_a(npc, state)` — the Condition A-4 tier choice,
byte-for-byte the same function A uses. It is computed **before** the eligibility
walk, on every call, whether or not it is used.

B does **not** re-check the fallback against the hard prerequisites. Under the
frozen catalogue it never needs to: every A-4 tier choice is hard-eligible in
exactly the states that select it, because each tier's hint requires the presence
or absence of precisely the evidence item that tier keys on, and no hint in the
catalogue declares `requires_story_flags`.

| Tier | Selected when | Hint | Hard prerequisite | Eligible? |
|---|---|---|---|---|
| 1 | own evidence held | `h_*_stain` / `_pollen` / `_short_circuit` | requires that item | yes |
| 2 | own absent, other major held | `h_*_knows_*` | requires own item absent | yes |
| 3 | no major evidence | `h_butler_no_evidence` | requires `fake_red_stain` absent | yes |
| 3 | no major evidence | `h_gardener_leaf_colour`, `h_mechanic_series_basics` | none declared | yes |

This is a **property of the catalogue, not a guarantee in B's code.** A future
hint whose tier assignment and prerequisites disagree would let B emit a
state-ineligible hint. `StateViolationRate` is the metric that would catch it.

#### 7. Silence behaviour

**B has no silence rule.** Rules 2 and 3 return catalogue ids; Rule 4 returns the
A-4 fallback, which is non-empty for every NPC in `CONDITION_A_TIERS`. B returns
the empty string in exactly one circumstance: the NPC is not `butler`, `gardener`
or `mechanic`, in which case `select_condition_a` returns `""`, the eligible list
is empty (no hint claims that NPC), and Rules 2 and 3 cannot fire.

For the three evaluated NPCs, B's `Coverage` is therefore **48/48 by
construction**, and its silence count is structurally zero. Under §6 of this
protocol a silence is scored as not-relevant, so B can never gain from
abstaining — it has no way to abstain. A condition that *can* abstain (such as C)
is not comparable to B on `Coverage` without saying so.

#### 8. Statelessness and what B cannot see

`select_adaptive` accepts a third parameter, `recent_hint_ids`, for call-site
compatibility. **It is never read.** B holds no state between calls, so scenario
order cannot change its output and the evaluation is invariant to the order rows
are processed.

B reads exactly three fields of the state dictionary — `evidence_items`,
`story_flags`, `knowledge_items` — and reaches PKM only through
`is_demonstrated_in`. It never reads a serialized `pkm_states` block (see §4),
never sees a scenario id, ordinal, room or stage, never sees human labels, and
never sees Condition A's recorded output — it recomputes the A-4 choice itself.
`knowledge_items` is forwarded to PKM but PKM v1 never reads it; it is dead
state.

### Reporting structure

heldout-v2 places each character in a different room, so raw cross-NPC
differences are **not** treatment effects. Report **within** NPC — Butler A vs B
vs C, Gardener A vs B vs C, Mechanic A vs B vs C — and treat the NPC
macro-average as a secondary aggregate only.

## 10. Limitations

1. **Author-generated scenarios.** Every state was constructed by the same
   author who built the selector.
2. **Author annotation.** Unless a second annotator is used, agreement measures
   self-consistency.
3. **Synthetic, not observed.** These are reachable states, not states real
   players were seen to occupy. No playtest data exists.
4. **Small sample.** 48 scenarios, of which roughly 19 exercise an authored
   hint's declared preconditions. Differences of a few points are within noise.
5. **`DEMONSTRATED` is a proxy**, not validated mastery. Every underlying check
   allows unlimited retries with fixed content, and most reveal the governing
   rule on failure.
6. **One NPC cannot be exercised.** See the design note below.
7. **Hall-only.** All scenarios place the player in `castle_hall`, where the
   three questionable characters are found.

## 11. Prohibition on tuning against held-out results

Held-out results may be computed **once** per frozen protocol version, and
**must not** inform any change to the selector, the hint catalogue, PKM, or the
metrics. Any such change requires a new protocol version and a new held-out
set.

If a held-out result is disappointing, the correct response is to **report it**.

---

## Design note — the Mechanic's authored hint (RESOLVED)

**Pre-evaluation semantic correction · 2026-09-04 · owner-approved (Option C)**

`h_mechanic_knows_resistance` formerly declared
`"requires_concept": ["current_resistance"]`. That concept resolved through the
`GameState.knowledge_items` entry whose only writer,
`add_knowledge_item("current_resistance")` at `game_world.gd:5717`, sits inside
`show_circuit_learning_note()` — a function with **zero callers** since commit
`505f008`. Under §4 the precondition was therefore unsatisfiable by any
legitimate knowledge signal.

A source/content audit compared the authored text against the three real circuit
benches (`circuit_lab_ui.gd:614-760`) and found it carries **two** ideas:

| Idea | Match |
|---|---|
| "what a low-resistance path does to a line" | **PARTIAL** — Bench I lesson 4, *"A conductor across the lamp carries the current past it"*; the bypass is a modelled mechanic (`"bypass": ["socket"]`) |
| "old wiring fails slowly / this did not fail slowly" | **NO MATCH** — forensic inference, taught by no bench |

`circuit_regulation` and `circuit_fault_isolation` were **NO MATCH**: the former
concerns *raising* resistance under control, the latter opens and search
strategy. The shared word "resistance" between the hint id and the regulator
bench is name-level only.

**Decision.** Re-keying to `circuit_continuity` would have overstated the match,
because the half the line argues from is the half no concept covers. The hint is
therefore **untied from PKM entirely** and treated as a contextual / forensic
Mechanic line.

**What changed:** `requires_concept` removed. Hint id, authored text, `teaches:
[]`, NPC ownership and `requires_evidence_absent` are **unchanged**.

**The id `h_mechanic_knows_resistance` is historical and now misleading.** It is
retained deliberately so earlier development results remain traceable to the
same identifier.

**Why this was permitted before the freeze.** The correction rests on a source
and content audit performed *before* held-out annotation, before the state hash
was finalised, and before any selector ran against the held-out set. It is **not**
based on held-out performance. Under §11, a change informed by held-out results
would instead have required a new protocol version.

**Effect on the held-out set.** Scenario states were **not** regenerated. The
held-out JSON is byte-identical (`a60cee98…`), and all 48 scenario blocks in the
annotation worksheet are byte-identical. Only the worksheet's hint-reference
table was refreshed, and the Mechanic now has 9 of 16 states in which this
hint's declared precondition holds — previously 0.

---

## Design note — `h_butler_knows_rule` (RESOLVED)

**Pre-evaluation semantic correction · 2026-09-04 · owner-approved (Option B)**

`h_butler_knows_rule` formerly declared `"requires_concept": ["dual_lock_rule"]`.
A source audit found `dual_lock_rule_taught` is not a knowledge signal:

| Finding | Evidence |
|---|---|
| Written by a button press | `wake_room.gd:2296` — `add_dialogue_button("Continue", _show_dual_lock_rule)`; the flag is set at `:2306` **before** any text is shown |
| The confirmation is a dismissal, not an assessment | the panel's button reads **"I UNDERSTAND"** (`case_locale.gd:274`) |
| No comprehension check exists | searching all production code for `dual_lock` returns only the two `wake_room.gd` lines |
| Content is game mechanics, not science | *"a key opens the door, a question guards it"* |
| No production reader | its only read is its own idempotency guard |

Adding it to PKM would have redefined `DEMONSTRATED` to include "was shown a
panel", contradicting §4.

**The prerequisite is real and was kept.** The line opens *"You already know how
Ashford sealed this place"* — false if delivered to a player who never saw the
rule. It is therefore expressed as a **story/context** requirement.

**What changed:** `requires_concept: ["dual_lock_rule"]` →
`requires_story_flags: ["dual_lock_rule_taught"]`. Hint id, authored text,
`teaches: []`, NPC ownership and `requires_evidence_absent` unchanged.

**Mechanism added:** `requires_story_flags`, enforced in
`AdaptiveHintData.state_violations()` and `AdaptiveHintSelector._story_flags_match()`.
A missing required flag makes a hint **state-ineligible**. These requirements are
not PKM concepts and never enter redundancy analysis.

**Effect on the held-out set:** none. Scenario states were not regenerated; the
held-out JSON is byte-identical (`a60cee98…`) and all 48 scenario blocks in the
worksheet are unchanged. Only the worksheet's hint-reference table gained a
"Requires story flag (context)" column.

---

## 12. Held-out v4 — prospective evaluation plan

**Frozen before v4 exists.** At the time this section was written there was no v4
scenario artifact, no v4 annotation, and no v4 result. Generation is specified in
`docs/HELDOUT_V4_GENERATION_SPEC.md`; this section fixes how v4 will be *scored*,
so that the analysis plan predates the data.

### 12.1 Two strata, never merged

| Stratum | n | Role |
| --- | --- | --- |
| CORE | 48 (16 per NPC) | **Primary confirmatory** analysis |
| STRESS | 24 (8 per NPC) | **Preregistered secondary** robustness / boundary analysis |

CORE and STRESS are reported separately and are **never combined into a single
headline metric**. No composite score is created.

### 12.2 `RelevantHintRate` is unchanged from v3

The primary metric keeps its §5 definition exactly:

```
relevant    = selected hint id is non-empty AND selected hint id ∈ HUMAN VALID_HINTS
numerator   = relevant selections
denominator = all attempted scenarios
```

**SILENCE is never relevant** — including on a scenario whose human label is
`NONE`. §6 continues to govern: silence is a relevance failure, lowers
`Coverage`, and is never removed from the denominator.

This was deliberately *not* amended for v4. Amending it would have changed the
meaning of the closed v3 headline number, the frozen Condition C specification
(`docs/CONDITION_C_SPEC.md` §B.7, which states that C cannot improve its score by
abstaining), and the symmetry of the metric across conditions — and it would have
done so asymmetrically, since only Condition C can abstain at all. The question
that amendment was reaching for is answered instead by a new, separate, clearly
secondary metric (§12.4).

### 12.3 Metrics carried forward unchanged

`Coverage`, `StateViolationRate`, `RedundantHintRate` (primary) and
`RedundantWhenTeachable` (secondary) keep their §5 and §5b definitions.
Numerator and denominator are always reported. A teaching denominator of 0 is
reported as exactly `N/A (0 teaching hints delivered)`.

### 12.4 New v4 secondary metrics

These are **new prospective v4 outcomes**. They were **not** part of the closed
v3 analysis and must never be presented as though they were.

**`AppropriateActionRate` — SECONDARY.**

```
correct_action        = (delivered AND selected hint ∈ VALID_HINTS)
                        OR (silence AND VALID_HINTS is empty)
AppropriateActionRate = correct actions / all attempted scenarios
```

It separates two questions `RelevantHintRate` deliberately fuses: whether a
delivered hint was relevant, and whether delivering anything was the right call.
`RelevantHintRate` answers the first and remains primary.

**`CorrectSilenceRate` — DESCRIPTIVE ONLY.**

```
numerator   = NONE-labelled scenarios on which the selector chose SILENCE
denominator = NONE-labelled scenarios
```

Reported as `N/A (0 NONE scenarios)` when the denominator is 0. It is **not**
merged into `RelevantHintRate` and carries no preregistered inferential test.

### 12.5 Inferential plan (CORE)

A, B and C see the same scenarios, so relevance comparisons are **paired**.

**PRIMARY — `RelevantHintRate`.** Three preregistered pairwise comparisons:
A vs B, A vs C, B vs C, each by **exact McNemar** on discordant pairs. Report per
comparison: each condition's numerator and denominator, the absolute
percentage-point difference, the discordant counts `b` and `c`, the exact
p-value, and the direction of the effect.

**SECONDARY — `AppropriateActionRate`.** The same three paired exact McNemar
comparisons with the same reporting, labelled SECONDARY wherever they appear.

**Multiplicity.** These three comparisons are the complete preregistered family.
Unadjusted exact p-values are the primary reporting; Holm-adjusted values across
the family of three are reported alongside. Any significance claim must state
which it uses.

**Sparse data.** No p-value is reported without its discordant counts, and a
comparison with `b + c < 5` carries an explicit low-information caveat. This is a
reporting requirement, not a rule for suppressing results. No significance is
claimed from redundancy metrics when denominators are sparse.

**Everything else is exploratory.** `Coverage`, `StateViolationRate`,
`RedundantHintRate` and `RedundantWhenTeachable` are reported descriptively,
numerator and denominator first. Any inferential analysis beyond the comparisons
named above — including anything computed on STRESS — is labelled
secondary/exploratory.

The exact test lives in `tools/mcnemar_exact.py`, committed and self-tested
alongside this section, so the analysis code predates the data.

### 12.6 v3 is not recomputed

The closed v3 artifacts are not altered, and v3 is **not** recomputed under
`AppropriateActionRate` as part of the primary study.

It may be noted analytically that Conditions A and B produced **zero** silent
scenarios on v3, so their closed `RelevantHintRate` figures would be unchanged
under an abstention-aware reading. That is an observation about arithmetic, not a
result. **No retroactive v3 headline metric is created.**

### 12.7 Order of operations

Frozen; each step completes before the next begins.

1. Generate v4 under the generation spec; run the chronology test, the canonical
   PKM test and the spec checker; commit and tag. The scenario set is immutable
   from that moment.
2. **Human annotation** — after the scenario set is frozen, before any condition
   runs. Per scenario: `VALID_HINTS`, rationale, ambiguity LOW / MEDIUM / HIGH.
   `NONE` remains allowed. The annotator must not see Condition A, B or C output;
   at this point none exists. Commit and tag; immutable from that moment.
3. Run A, B and C on the frozen, annotated set — **once**.
4. Score and report under §12.1–§12.6.

The **frozen annotation rubric in §8b remains authoritative.** It may be revised
only on discovery of a true contradiction with v4 state representation, and any
such revision must be committed with its justification *before* annotation
begins. It must not be revised after viewing v4 scenarios merely because
annotation proves difficult.

### 12.8 Condition C run discipline

- exactly **one** primary C inference per scenario;
- a fresh subprocess per scenario, no conversation persistence;
- the frozen schema retry only — a transport retry is **not** a new model sample;
- no rerun because a decision looks bad; no manual correction; no prompt edits;
  no model substitution; no selection among responses;
- **no repeated runs of C to choose a favourable result.**

Every scenario logs: the **requested** model `claude-opus-5`; the **resolved**
model from the Claude Code envelope; the raw response; the parsed decision; the
retry count; the transport attempt count; the candidate ids offered; the
canonical PKM; the prompt hash; and the C freeze tag
`condition-c-pre-v4-freeze-v2`.

A transport failure aborts the run rather than recording an abstention — an
outage scored as SILENCE would be a fabricated data point.

### 12.9 Catalogue note — no hint currently declares a story-flag prerequisite

The design note above records `h_butler_knows_rule` moving from
`requires_concept: ["dual_lock_rule"]` to
`requires_story_flags: ["dual_lock_rule_taught"]`. That hint has since been
**re-authored** with an evidence-grounded line (*"I heard glass break in this
room…"*, `chemistry_room.gd:1514-1516`), which removed the false premise the gate
existed to guard, and the gate was removed with it.

As of this section, **no hint in the catalogue declares `requires_story_flags` or
`requires_concept`.** The mechanism remains implemented and tested in
`AdaptiveHintData.state_violations()` and `AdaptiveHintSelector`; it simply has no
current user. The design note is left unedited as a record of a decision made at
the time; this note records the present state.

The consequence for v4 is stated in the generation spec §5.8: hard eligibility is
a function of `evidence_items` alone, so hard-eligible candidate count is
collinear with own-evidence-present within each NPC.

### 12.10 Annotation freeze (`heldout-v4-post-annotation`)

Ground truth was supplied by human blind relevance annotation for all 72
scenarios and materialized into `docs/heldout/heldout_v4_annotated.json`, an
annotated copy. As in §9b the pre-annotation file is **not** modified:
`heldout_v4_scenarios.json` stays byte-identical at `1bb1535f…`,
`annotations_present: false`, `selector_was_run: false`, so the state set
remains verifiable without reference to the labels and
`tools/check_heldout_v4_acceptance.py` still passes against it unchanged.

Annotation-only fingerprint — SHA-256 over scenario id, `valid_hints`,
`annotation_rationale` and `ambiguity_note` alone, in file order, computed the
same way as v3 so the two protocol versions are comparable:

```
29a08dc05593366b77f77b745d33af31b8cf191c939e62cbc394ade0ecc858b2
```

Annotated file SHA-256:

```
cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c
```

State-only content SHA-256 — over the 19 state, path, PKM and eligibility
fields, excluding both annotation fields, and therefore identical for the
pre-annotation set and the annotated copy:

```
d9289573df1fd90107ac9043318b506a603aef790228949af3721397f857621a
```

Ambiguity: **62 LOW, 8 MEDIUM, 2 HIGH**. MEDIUM at ordinals 6, 11, 12, 15, 22,
29, 30, 41; HIGH at ordinals 58 and 60. Fifteen scenarios carry the **NONE**
label — ordinals 2, 5, 9, 16, 19, 24, 28, 49, 50, 51, 52, 55, 56, 66 and 71.
Per §8b NONE is a real annotation: every scenario carries a non-empty rationale
and an ambiguity level, and it is those, not a non-empty `valid_hints`, that
separate an annotated NONE from an unfilled blank. Across the set there are 105
hint labels, every one of them hard-eligible in its own scenario.

#### Annotator notes carried forward

These were recorded by the annotator and are reproduced verbatim; they state
the scope of the labels and are part of the freeze.

- Scenario 58 and Scenario 60 are HIGH ambiguity because the progression model
  has no Gardener interaction-history flags. Whether `h_gardener_pollen` is
  relevant depends materially on whether the player has already heard that
  exact response.
- Gardener and Mechanic interaction history generally is not represented by the
  frozen state model. Do not invent prior-conversation facts.
- Scenario 72's final label follows the same human annotation rule already
  applied to Scenarios 67–70: `circuit_fault_isolation` is DEMONSTRATED but the
  maintenance-route statement can still provide investigative information,
  while `circuit_continuity` is LEARNING and the series-basics explanation
  remains useful.
- The VALID_HINTS labels are the human ground truth. If you normalize rationale
  wording, that is editorial prose only and must not alter the labels.

On the third note: `circuit_fault_isolation` is DEMONSTRATED at ordinals 67, 68
and 72, but LEARNING at ordinals 69 and 70. The label
`[h_mechanic_knows_resistance, h_mechanic_series_basics]` is the same across all
five, so the note's conclusion is unaffected; only its descriptive clause is
imprecise for 69 and 70. Recorded here rather than corrected in the note, which
is the annotator's text.

The second note is a limitation of the state model, not of these two scenarios
alone: `INTERACTION_FLAGS` declares three flags for the Butler
(`butler_challenge_given`, `butler_challenge_complete`,
`chemistry_butler_interviewed`) and none at all for the Gardener or the
Mechanic. Ordinals 58 and 60 are where that gap becomes decision-relevant; the
same gap applies in principle to every Gardener and Mechanic scenario, and no
rationale in the annotated file claims that a Gardener or Mechanic line has or
has not been heard before.

#### Rationale text

`annotation_rationale` is normalized English prose recording the state facts in
view and the decision reached. It is editorial and carries no authority: several
scenarios share an identical (NPC, evidence, hard-eligible-hint) shape and still
carry different labels, so no rationale claims that the facts it cites entail
the label. The hint ids and ambiguity levels are the ground truth.

- **Regeneration** — `python3 tools/materialize_heldout_v4_annotations.py`
  reproduces the annotated file byte-for-byte, and refuses to run unless the
  pre-annotation source still hashes to `1bb1535f…`
- **Validation** — `python3 tools/check_heldout_v4_annotations.py` re-derives
  every claim above from the files on disk, re-parsing hint eligibility from
  `scripts/adaptive_hint_data.gd` rather than trusting the artifact's own
  `eligible_hints`. It shares no constants with the materializer.
  `--fault-test` injects 15 mutations and requires each to be caught

No selector has been run against heldout-v4. Both files carry
`selector_was_run: false`, neither tool above imports a selector or calls a
scoring function, and no Condition A, B or C output appears in either file.
Conditions A, B and C remain unobserved on heldout-v4 as of this freeze.
