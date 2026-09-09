# Evaluation protocol — adaptive NPC guidance

**Status:** frozen by the project owner. Protocol version **`heldout-v2`**.

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

## 9. Freeze procedure

- **Deterministic ids** — `h_<stage>_<evidence>_<npc>`, no RNG anywhere
- **Sorted serialisation** — scenarios sorted by id; JSON with sorted keys
- **State fingerprint** — SHA-256 over state fields only, excluding annotations,
  so the state set can be verified independently of the ground truth
- **Protocol version** — `heldout-v2` recorded in the file
- **Regeneration** — `python3 tools/generate_heldout_v2.py` reproduces the file
  byte-for-byte; `python3 tools/render_annotation_worksheet.py <json>` reproduces
  the worksheet, parsing the catalogue rather than duplicating it

Current state fingerprint (`heldout-v2`):

```
e1979c1a75a83326f58770a86b937150c9381ed7b96333b8640fbe4dc0fd0404
```

File SHA-256 (`heldout-v2`):

```
a55b208005c87c370f34b86386125423e3c1b90e8fe017f956dd39937b77fd45
```

Superseded `heldout-v1` fingerprint, retained for provenance:

```
1648a508ef41dca62f4eed5028069617d65bc7beddca11435ea1000c015c615a
```

A second fingerprint covering scenarios **plus** annotations will be recorded
once the annotator supplies ground truth.

## 9b. Frozen matched catalogue and Condition A-4

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
