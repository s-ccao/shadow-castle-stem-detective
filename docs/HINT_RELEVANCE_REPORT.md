# Improving NPC Hint Relevance with a Player Knowledge Model in an Educational Detective Game

**A held-out evaluation of three NPC hint-selection policies in *Shadow Castle: STEM Detective***

> **Status.** No experiment was run to produce this document. No annotation,
> selector, metric, prompt, dataset or frozen artifact was modified. Every figure
> quoted below is read from a frozen artifact. The related-work citations in
> Section 3.4 remain open placeholders: no external literature review has been
> performed, and related-work and novelty claims remain provisional until one is.

**Author:** Changyang Cao, *[AFFILIATION]*
**Companion design paper:** `docs/PAPER.md` (game design and implementation)
**Evaluation protocol:** `docs/EVALUATION_PROTOCOL.md`
**Evaluation freeze:** commit `1df684e9`, tag `heldout-v4-evaluation`

---

## 1. Title

**Improving NPC Hint Relevance with a Player Knowledge Model in an Educational
Detective Game**

---

## 2. Abstract

Educational adventure games frequently deliver guidance through non-player
characters (NPCs). Choosing *which* line an NPC should say is a selection
problem: the game holds a catalogue of authored lines, and a policy must pick one
that fits the player's current situation — or decline to say anything. This study
asks whether a unified **Player Knowledge Model (PKM)**, a read-only derivation
of what a player has been shown and what they have passed a comprehension check
on, improves NPC hint relevance and reduces redundant guidance in *Shadow Castle:
STEM Detective*, and whether an LLM-based selector offers advantages over
deterministic policies.

**Methods.** Three policies were compared on an identical shared catalogue of
**eleven authored hints** across three NPCs: **A**, a static evidence-depth
baseline that never consults the PKM; **B**, a deterministic PKM-aware selector;
and **C**, a PKM-aware selector driven by `claude-opus-5`, which returns either a
catalogue identifier or `SILENCE` and never writes player-facing prose. The
held-out set comprises **48 CORE scenarios** for primary confirmatory analysis
and **24 STRESS scenarios** for secondary robustness analysis at state
boundaries. Ground truth is human relevance annotation — for each scenario, the
set of hints a human judged reasonable, possibly empty — **frozen, hashed and
tagged before any v4 condition output was observed**. All three conditions were
then run exactly once.

**Primary results.** CORE `RelevantHintRate` was **32/48 (66.7%)** for A,
**32/48 (66.7%)** for B and **33/48 (68.8%)** for C. The A-versus-B comparison
has **zero discordant pairs**, so no exact test is defined. A-versus-C and
B-versus-C each have `b = 1, c = 2` and a two-sided exact McNemar **p = 1.000**.
**No statistically supported confirmatory improvement in relevance was
established** — neither for the PKM over the baseline, nor for the LLM selector
over the deterministic rules. On redundancy, A delivered **1 redundant CORE
hint** while B and C delivered **0**; this evidence is sparse, and no
significance is claimed from it.

**Secondary behaviour.** CORE `AppropriateActionRate`, which credits abstention
when no hint is human-valid, was **32/48** for A and B and **35/48** for C.
Across all 72 scenarios C **correctly abstained on seven `NONE`-labelled
scenarios and falsely abstained once**; A and B cannot abstain at all. The STRESS
stratum showed larger descriptive differences in C's favour, but STRESS is
preregistered as secondary robustness evidence sampled at state boundaries and is
**not** presented as confirmatory.

**Conclusion.** The PKM did not improve overall confirmatory relevance under the
deterministic selector tested here, although the PKM-aware policy did avoid a
small number of redundant teaching selections. The LLM selector produced only a
small, statistically unsupported difference in CORE relevance, with its clearest
descriptive distinction appearing in abstention and action appropriateness. No
claim of significant improvement, of policy equivalence, of overall superiority,
or of learning gains is made or supported: no learning outcome was measured at
any point in this study.

---

## 3. Introduction

### 3.1 The problem

*Shadow Castle: STEM Detective* is an educational detective game in which the
player investigates a castle, gathers physical evidence, and passes short
science comprehension checks in order to open locked rooms. Three suspects — a
**butler**, a **gardener** and a **mechanic** — can be questioned repeatedly, and
each has a small catalogue of authored lines they may say.

Which line should a character say? The naive answer is "whichever one the
current evidence unlocks", and that is roughly what a static policy does. But a
player who has already passed the indicator-reaction check does not need the
indicator-reaction explained again; a player who has already walked past the
greenhouse does not need to be told to go there; and a player who has exhausted
an NPC's usefulness may be better served by that NPC saying nothing than by
receiving a line that is technically valid and practically empty.

Each of those judgements requires knowing something about the player beyond the
evidence in their inventory. That is what the **Player Knowledge Model** is for.

### 3.2 What this study measures, and what it does not

This is a **measurement study of hint selection policy**, not a study of
learning. Nothing here measures whether a player learned anything, retained
anything, or performed better on any assessment. The companion design paper
(`docs/PAPER.md`) states plainly that no formal evaluation of learning outcomes
has been conducted for this game, and this study does not change that. The PKM
state `DEMONSTRATED` means exactly one thing — the player passed the game's
existing designated comprehension check — and Section 6 states the limits of
that signal in detail.

What is measured is narrower and checkable: given a frozen player state and a
frozen catalogue of authored lines, **does the policy pick a line a human
annotator judged reasonable, and does it avoid re-teaching a concept the player
has already demonstrated?**

### 3.3 Why a held-out set was necessary

An earlier development set of 20 hand-authored scenarios exists in this project
and is **contaminated**: the selector was at one point adjusted after its results
on those scenarios were observed, which raised its score from 80% to 100%. The
evaluation protocol records this openly and classifies that number as a
consistency check, not validation (`docs/EVALUATION_PROTOCOL.md` §2–§3). Any
figure computed on those 20 scenarios measures how well the selector was fitted
to them.

The held-out programme exists to escape that. The `heldout-v3` study established
the protocol and produced a closed A-versus-B result on 48 scenarios. The
`heldout-v4` study reported here extends it to 72 scenarios, adds Condition C,
and — critically — fixed the entire scoring and statistical plan *in writing,
committed and tagged, before the v4 scenarios existed*.

### 3.4 Relation to prior literature

*[RELATED WORK CITATION NEEDED]* — No external literature review has been
performed for this hint-selection study. The companion design paper
`docs/PAPER.md` carries its own reference list for game design and science
education; those references belong to that paper's argument and are **not**
reused here, because reusing them would imply a literature review of adaptive
hinting, learner modelling or LLM-based tutoring that has not been done.

Topics where a citation would be required before publication:

- *[CITATION NEEDED]* — prior work on adaptive hint selection and hint policies
  in educational games.
- *[CITATION NEEDED]* — prior work on learner / student knowledge modelling
  (e.g. overlay models, knowledge tracing) and how `DEMONSTRATED`-style states
  are normally justified.
- *[CITATION NEEDED]* — prior work on LLMs as selectors or tutors, and on
  abstention/deferral behaviour in LLM systems.
- *[CITATION NEEDED]* — prior work on human relevance annotation with
  multi-valid ground truth, and on inter-annotator agreement practice.

**Related-work and novelty claims remain provisional until an external literature
review is completed.** Nothing in this report describes the Player Knowledge
Model, the hint-selection policies or the evaluation design as novel, because no
such claim can be supported without that review.

---

## 4. Research Questions

### 4.1 Primary research question

> **Can a unified Player Knowledge Model improve NPC hint relevance and reduce
> redundant guidance in an educational detective game?**

This is the question the frozen protocol names (`docs/EVALUATION_PROTOCOL.md`
§1). It has two halves, and they are measured by different metrics that can move
independently:

| Half of the question | Measured by | Comparison that answers it |
|---|---|---|
| "improve NPC hint relevance" | `RelevantHintRate` (primary) | A versus B on CORE |
| "reduce redundant guidance" | `RedundantHintRate`, `RedundantWhenTeachable` (descriptive) | A versus B on CORE |

Condition A is the no-PKM policy and Condition B is its PKM-aware counterpart,
so the **A-versus-B contrast is the direct test of the primary question**.

### 4.2 Secondary research question

> **Does an LLM-based hint selector provide meaningful advantages over
> deterministic adaptive rules?**

Condition C is the LLM selector, so the **B-versus-C contrast** is the direct
test of this question, with A-versus-C reported alongside for completeness.

### 4.3 Scope boundaries fixed in advance

Three boundaries were set before any v4 result existed, and are restated here so
that the reader knows what this study is not allowed to conclude:

1. **No learning-outcome claim.** No metric in this study observes a player.
2. **No composite score.** The conditions are not ranked by an invented overall
   number; each metric is reported with its own numerator and denominator.
3. **CORE and STRESS are never merged into a single headline figure.** CORE is
   confirmatory; STRESS is secondary robustness and boundary analysis.

---

## 5. System / Game Context

### 5.1 The game

*Shadow Castle: STEM Detective* is built in **Godot 4.7** (GDScript, roughly
51,000 lines) and comprises six investigation rooms. Progress is gated by five
**knowledge locks**: Chemistry, Greenhouse, Circuit, Dining Hall and Library. A
lock opens when the player passes the comprehension check associated with that
room's science content, which is what makes the game "educational" in a
mechanical sense — the science is load-bearing for progression rather than
decorative.

The main chain of progression, as transcribed from the live room scripts into
the generator's step table, is:

```
Wake → Chemistry → Greenhouse → Circuit → Dining        (Library is off-chain)
```

Each of the three questionable NPCs lives in exactly one room:

| NPC | Room | Door step | Own major evidence |
|---|---|---|---|
| `butler` | `chemistry_room` | `door_chem` | `fake_red_stain` |
| `gardener` | `greenhouse_room` | `door_green` | `greenhouse_pollen` |
| `mechanic` | `circuit_room` | `door_circuit` | `deliberate_short_circuit` |

### 5.2 The shared hint catalogue

All three conditions draw from **one shared catalogue of eleven authored hints**
(`scripts/adaptive_hint_data.gd`): three for the butler, four for the gardener,
four for the mechanic. **No hint is withheld from any condition.** An earlier
design gated the three higher-level hints behind hard `requires_concept` checks,
which would have made them structurally unavailable to Condition A; that design
was rejected on the grounds that it would have measured a *content* advantage
and reported it as a *personalisation* effect (`docs/EVALUATION_PROTOCOL.md`
§9b). If a condition never selects a hint, that is its policy, not a restriction
imposed on it.

Six of the eleven lines are **legacy-grounded**: their wording is real and
source-grounded, taken from the shipped dialogue, but the functions that
contained them no longer have callers — the dispatch was deleted in commit
`505f008`. They must **never** be described as shipped, live, or current product
behaviour. The remaining five are authored for this line of work.

Two catalogue properties matter for the results and are stated here rather than
discovered later:

- **Only two of the eleven hints can ever be redundant** under the PKM
  definition in Section 11 — `h_gardener_leaf_colour` (teaches `reflection`) and
  `h_mechanic_series_basics` (teaches `circuit_continuity`). A hint that teaches
  no PKM concept is never redundant, by definition.
- **The butler deliberately has no foundational teaching hint.** He administers
  the indicator-reaction comprehension check himself, so concept-level teaching
  redundancy cannot arise for him at all. This is a design decision, recorded in
  the protocol, not an oversight.

### 5.3 Hard prerequisites versus soft preferences

The catalogue distinguishes two kinds of metadata, and conflating them would
invalidate the study:

| Kind | Fields | Meaning |
|---|---|---|
| **Hard state prerequisite** | `requires_evidence`, `requires_evidence_absent`, `requires_story_flags`, `requires_concept` | The hint is factually or narratively **invalid** without it. Delivering it anyway is a **StateViolation**. |
| **Soft selection preference** | `preferred_when_demonstrated` | The hint is *especially* apt once a concept is `DEMONSTRATED`. Failing it does **not** make the hint invalid, is **not** a StateViolation, and does **not** determine redundancy. |

Condition A ignores `preferred_when_demonstrated` entirely; Condition B may act
on it through the PKM; Condition C receives it as prompt prose but no predicate
in C reads it.

One implementation subtlety is asserted at run time rather than assumed. The
catalogue's authoritative prerequisite checker, `AdaptiveHintData.state_violations()`,
additionally reads `requires_concept`, which Condition B's inline eligibility
filter does not. The two predicates therefore coincide **only while no hint
declares a `requires_concept`** — and none of the eleven does. Both evaluation
harnesses assert this on every run and abort rather than let B and C silently
diverge on eligibility.

---

## 6. Player Knowledge Model

### 6.1 What the PKM is

The PKM (`scripts/player_knowledge_model.gd`) is a **read-only derivation layer**
over existing game state. It stores nothing of its own: every query is answered
by inspecting `GameState.story_flags` and `GameState.evidence_items` at the
moment it is asked. There is no separate persisted knowledge record that could
drift out of step with the game, and there is no write path a selector could use
to alter what the model believes.

It tracks **eight concepts**, in canonical order:

| # | Concept | Thread |
|---|---|---|
| 1 | `indicator_reaction` | Chemistry |
| 2 | `physical_chemical_change` | Chemistry |
| 3 | `spectrum` | Greenhouse / light |
| 4 | `reflection` | Greenhouse / light |
| 5 | `additive` | Greenhouse / light |
| 6 | `circuit_continuity` | Circuit |
| 7 | `circuit_regulation` | Circuit |
| 8 | `circuit_fault_isolation` | Circuit |

### 6.2 The `Mastery` enum states

The enum's name is a legacy identifier in the source and should not be read as a
claim: none of its states asserts mastery, and Section 17.12 sets out at length
what `DEMONSTRATED` does and does not mean.

```gdscript
enum Mastery { UNSEEN, LEARNING, DEMONSTRATED, ASSISTED }
```

| State | Meaning |
|---|---|
| `UNSEEN` | Nothing in the player's state indicates exposure to this concept. |
| `LEARNING` | The player has encountered material for the concept but has not passed its designated check. |
| `DEMONSTRATED` | The player has passed the game's existing designated comprehension check for this concept. |
| `ASSISTED` | **Unreachable in PKM v1.** |

`ASSISTED` exists in the enum but the model declares
`ASSISTED_REQUIRES_NEW_STATE: bool = true` and never returns it: producing it
would require recording whether the player was helped, which the game does not
currently record. It is listed here for completeness of the enum, and the
Condition C prompt deliberately defines only **three** levels, because naming a
state the game cannot produce would invite reasoning about a situation that
cannot arise.

### 6.3 What `DEMONSTRATED` does and does not mean

This is the single most important scoping statement in the study, and it is
copied from the model's own documentation rather than paraphrased upward.

**`DEMONSTRATED` means:** the player has successfully completed the game's
existing designated comprehension check for that concept.

**`DEMONSTRATED` does NOT mean:**

- first-attempt correctness — the checks allow unlimited retries;
- independent mastery — the rules of a check are revealed on failure, so a later
  success may reflect the reveal rather than prior understanding;
- validated learning — the checks were authored as game gates, not as
  psychometric instruments;
- retention — nothing re-tests the concept later;
- unassisted performance — the game records no attempt count, no timing and no
  assistance signal.

Every downstream use of the word `DEMONSTRATED` in this report inherits those
limits. In particular, the redundancy metrics in Section 11 detect "this line
re-teaches something the player has already passed the check on", **not** "this
player already understands this."

Story flags and evidence items never, by themselves, imply `DEMONSTRATED`
(`docs/EVALUATION_PROTOCOL.md` §4). The PKM is the sole authority for redundancy.

### 6.4 Pure evaluation variants

For offline scoring the model exposes pure variants — `state_in(concept,
knowledge, flags, evidence)` and `is_demonstrated_in(...)` — which compute a
concept's state from an explicit state triple rather than from a running game.
This is what allows redundancy to be computed over a frozen scenario table with
no game process alive, and it is the same function Condition C calls to derive
the PKM snapshot it is shown. A serialized `pkm_states` block present in a
dataset is **never** consulted by any condition; PKM is always derived.

---

## 7. Conditions A, B and C

All three conditions solve the same problem — *given this player state, choose
one line from this NPC's catalogue, or stay silent* — and all three receive the
identical eleven-hint catalogue. They differ only in how the choice is made and
in what they are permitted to see.

| | How it chooses | What it may see | Deterministic? | May abstain? |
|---|---|---|---|---|
| **A-4** | fixed evidence-depth tier per NPC | evidence only | yes | no |
| **B** | four deterministic rules over the PKM | evidence, story flags, PKM | yes | no |
| **C** | a language model reads the state and the candidates | evidence, story flags, PKM, room, stage | **no** | yes |

### 7.1 Condition A — A-4 Evidence-depth Static Baseline

A-4 is the no-PKM control. For the NPC being spoken to:

1. **Tier 1** — the character's *own* major evidence is held → evidence response;
2. **Tier 2** — own evidence absent, but at least one *other* major suspect
   evidence item is held → higher-level contextual hint;
3. **Tier 3** — none of the three major items held → introductory line.

| NPC | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| `butler` | `h_butler_stain` | `h_butler_knows_rule` | `h_butler_no_evidence` |
| `gardener` | `h_gardener_pollen` | `h_gardener_knows_reflection` | `h_gardener_leaf_colour` |
| `mechanic` | `h_mechanic_short_circuit` | `h_mechanic_knows_resistance` | `h_mechanic_series_basics` |

A-4 is **deterministic, stateless, order-independent, parameter-free, and never
reads the PKM**. It has no tunable threshold, so there is nothing in it that
could have been fitted to the held-out labels. Its rationale is conventional
static guidance: respond to direct evidence, else give later-investigation
context, else give the introductory line.

Two properties are recorded honestly rather than hidden. An alternative
progression-staged baseline keyed on `door_circuit_unlocked` was **rejected**
because every Mechanic scenario is in the Circuit Room, which requires that flag,
so the discriminator would be constant and the policy would collapse to one
branch. And under A-4 the two `*_no_evidence` hints for the gardener and mechanic
are **unreachable**, because tier 3 prefers the foundational hint where one
exists; both remain in the shared catalogue and remain available to B and C.

### 7.2 Condition B — deterministic PKM-aware selector

B is a four-step cascade that returns from the first step that fires:

```
Rule 1   filter the catalogue to hard-eligible hints for this NPC
Rule 2   return the first eligible hint whose soft preference is satisfied
Rule 3   if the A-4 fallback is redundant, return the first eligible,
         non-fallback, non-redundant alternative
Rule 4   return the A-4 fallback
```

**Rule 2 is where the PKM enters.** Walking the eligible list in catalogue
declaration order, B returns the first hint all of whose
`preferred_when_demonstrated` concepts are `DEMONSTRATED`. **Rule 3 is the
explicit redundancy-avoidance rule**: if the line A-4 would have given re-teaches
a concept the player has already demonstrated, B looks for a non-redundant
alternative. **Rule 4 falls back to exactly what A-4 would have said**, which is
what makes B a strict refinement of A rather than a different policy.

B accepts a `recent_hint_ids` argument but **does not use it**, so scenario
ordering cannot change B's output and the evaluation is order-independent.

B has **no silence branch at all**: it returns a hint for every scenario with a
known NPC, so its `Coverage` is 100% by construction. This is a structural fact
about B, not an achievement, and Section 11 records that B and C are therefore
not directly comparable on `Coverage`.

### 7.3 Condition C — frozen LLM + PKM selector

Condition C (`spec_version` = `condition-c-v1`,
`docs/CONDITION_C_SPEC.md`) is a **selector, not a writer**. It is given the
player state, the derived PKM and the hard-eligible candidate list, and it
returns one JSON object:

```json
{"decision": "<catalogue hint identifier | SILENCE>", "reason": "<one short sentence>"}
```

Ten commitments constrain it. Each is enforced by construction, because a
commitment that is only written down is a promise while one enforced by
construction is a property:

| # | Commitment | Enforced by |
|---|---|---|
| 1 | C selects from the SAME shared catalogue as A and B | the identical `Data.all_hints()` call |
| 2 | C does not generate hint prose | only an identifier crosses the boundary |
| 3 | C returns a catalogue id or `SILENCE` | `validate()` |
| 4 | C receives only hints passing the SAME hard predicate as A and B | `hard_eligible()` → `state_violations()` |
| 5 | C may use canonical PKM state | `pkm_snapshot()` → `PlayerKnowledgeModel.state_in` |
| 6 | `preferred_when_demonstrated` is soft metadata, never eligibility | no predicate in C reads it |
| 7 | evidence / story prerequisites remain hard | re-checked *after* model output |
| 8 | human relevance labels are never input | `INPUT_FIELDS` allowlist |
| 9 | A/B outputs are never input | no call site exists; the fallback is `SILENCE` |
| 10 | scenario ordinal / benchmark identity is never input | `INPUT_FIELDS` allowlist |

**Input allowlist.** C's state filter copies exactly six named fields and drops
everything else, so a field added to a scenario file in future is excluded by
default rather than leaking until someone notices:

```
INPUT_FIELDS = [npc, room, stage, evidence_items, story_flags, knowledge_items]
```

Consequently absent and unable to be re-added by accident: human relevance
labels, annotation rationales, ambiguity levels, Condition A output, Condition B
output, scenario ids and ordinals, protocol version, any evaluation metric, and
any serialized `pkm_states` block.

**The task.** The frozen prompt asks the model to choose the single line giving
this player the most meaningful guidance for their *complete current state*,
weighing six numbered, deliberately **unranked** considerations: investigative
usefulness; staleness; fit to what the player understands; the value of
re-teaching an already-demonstrated concept; prematurity; and whether the line
addresses evidence actually held. They are unranked because specifying a
weighting between them would amount to re-implementing Condition B's rule order
in prose.

**Silence is a permitted answer,** and the prompt states it is "a real answer,
not a failure to answer", warning symmetrically against picking a weak line to
avoid silence and against picking silence merely to be cautious. Silence is not
free: under the frozen primary metric a silent scenario is not relevant, so **C
cannot improve its primary score by abstaining.**

**Validation.** The model is never asked whether a line is *allowed* — that
would put a hard safety property behind a soft judgement. Eligibility is decided
before the model sees anything and re-checked afterwards, through five ordered
gates: `SILENCE` accepted; the identifier must exist in the catalogue; it must
have been among the candidates offered; its hard prerequisites must still hold;
and its `npc` must match. Gates 3 and 4 are deliberately redundant with earlier
ones and are kept because *redundant* and *unnecessary* are different words — a
state-violating hint reaching a player is the failure the protocol exists to
measure. The `reason` field is inert by construction: no predicate reads it.

**Parsing is strict.** One surrounding code fence is stripped as transport
cleanup; nothing else is repaired. No identifier is extracted from prose, no
near-miss is snapped to the nearest candidate, no second JSON object is
considered. A reply that needs interpretation is a rejected reply. A rejected
reply gets **exactly one schema retry**, whose wording addresses format only and
never hints at a preferred answer; if that also fails, the result is `SILENCE`.

**Transport and isolation.** C reaches `claude-opus-5` through an isolated,
one-shot Claude Code subprocess authenticated by a company-managed broker. One
process per scenario; no conversation persistence; `env -i` so the child
environment is built from nothing; a fresh empty `HOME` and a fresh temporary
working directory per invocation so no repository material, user settings file,
project instruction file or plugin is discoverable; no tools, no MCP servers, no
slash commands, no settings sources. There is **no fallback to a direct Anthropic
API endpoint** and no code path that reads a personal API key; the wrapper
refuses to run if the broker would be bypassed. A transport failure **aborts the
run** rather than being recorded as an abstention, because an outage scored as
`SILENCE` would be a fabricated data point.

**Determinism is explicitly not claimed.** `samples_per_scenario` is 1, and
`temperature`, `top_p`, `top_k`, `max_tokens`, `seed` and `stop_sequences` are
**not controllable through this transport** — the CLI exposes no flag for any of
them. They are recorded as `null` meaning *not controllable*, not *defaulted to
something we chose*. Conditions A and B are deterministic; **C is not**, every
raw response is logged verbatim so that a diverging rerun would be visible
rather than silently averaged away, and no comparison in this report may assume
otherwise.

---

## 8. Experimental Design

### 8.1 Paired within-scenario design

All three conditions were run over the **same 72 frozen scenarios** with the
**same catalogue**, so every comparison is **paired**: for each scenario there is
one A outcome, one B outcome and one C outcome on identical inputs. Differences
are therefore attributable to selection policy rather than to scenario
difficulty or to content availability.

### 8.2 Two strata, never merged

| Stratum | n | Per NPC | Role |
|---|---|---|---|
| **CORE** | 48 | 16 | **Primary confirmatory** analysis |
| **STRESS** | 24 | 8 | **Preregistered secondary** robustness / boundary analysis |

CORE occupies ordinals 1–48 and STRESS ordinals 49–72. They are reported
separately and are **never combined into a single headline metric**. An all-72
block is computed and may be quoted, but only as **descriptive**.

**No composite score is created.** Systems are not ranked by an invented overall
number.

### 8.3 Frozen order of operations

Each step completed before the next began, and each produced an immutable,
hashed, tagged artifact:

| Step | What happened | Freeze tag |
|---|---|---|
| 1 | The analysis plan for v4 was written **before v4 existed** | `condition-c-pre-v4-freeze-v2`, `heldout-v4-generation-pre-freeze` |
| 2 | v4 scenarios generated, validated, committed | `heldout-v4-pre-annotation` |
| 3 | **Human annotation**, on the frozen scenarios, before any condition ran | `heldout-v4-post-annotation` |
| 4 | A, B and C run on the frozen annotated set — **once** | `heldout-v4-evaluation` |
| 5 | Metrics and tests computed under the plan fixed at step 1 | — |

The ordering is what gives the study its force. At step 2 the annotator's labels
did not exist, so the scenarios cannot have been chosen to suit the labels; at
step 3 no condition output existed, so the labels cannot have been chosen to
suit any condition; and at step 4 the scoring rules and the statistical tests
were already committed, so the analysis cannot have been chosen to suit the
results.

### 8.4 The no-tuning rule

Once the held-out labels became known, a standing methodological rule applied and
was honoured: **no selector was designed, tuned, modified, repaired, optimized or
reinterpreted using those labels.** The source files for Conditions A and B hash
to the same values they had for the earlier v3 study, which is machine-checked
at the start of every evaluation run, so the two studies demonstrably measure the
same two selectors.

### 8.5 Condition C run discipline

C's run was **one shot**, under discipline frozen before the run:

- exactly **one** primary model inference per scenario;
- a fresh subprocess per scenario, no conversation persistence;
- the frozen single schema retry only — and a *transport* retry is explicitly
  **not** a new model sample;
- no rerun because a decision looked bad; no manual correction; no prompt edit;
  no model substitution; no selection among responses;
- **no repeated runs of C to choose a favourable result.**

Durability was built in rather than hoped for: each scenario's result was
appended to a write-once JSONL log the instant it returned, before the next
scenario started, and the harness **refuses to start over** if a real log already
exists. A restart that pretended nothing had happened would silently resample
completed scenarios, which is the one thing a one-shot run must not do.

### 8.6 Independent verification

Three layers of checking were applied, deliberately not sharing code:

1. The GDScript harnesses wrote **raw per-scenario rows only** and computed no
   metric — a harness agreeing with itself would prove nothing. For A and B the
   harness additionally *reconstructs* each decision trace from the documented
   rules and aborts the run if the reconstruction disagrees with what the
   selector actually returned.
2. A Python tool recomputed relevance, silence and appropriateness from the
   frozen labels and **fails on any disagreement** with the harness flags.
3. An independent integrity checker re-derived every metric and every test
   statistic from the joined table **without importing** the metrics tool or
   reusing its constants, verified that the frozen inputs had not moved, audited
   the one-shot property from the append-only log, verified no condition selected
   outside its hard-eligible set, and confirmed that no evaluation output had
   leaked back into the ground-truth file. Its **fault-injection suite** mutates
   the artifacts nine ways — altering a selection, rewriting a human label,
   reassigning a stratum, inflating a numerator, inflating a denominator, forging
   a p-value, forging a discordant count, selecting outside eligibility, dropping
   a scenario — and requires each mutation to be caught, so the checks are shown
   to be capable of failing.

---

## 9. Dataset Construction

The full generation specification is `docs/HELDOUT_V4_GENERATION_SPEC.md`, frozen
at tag `heldout-v4-generation-pre-freeze`. This section summarises what it fixes.

### 9.1 Scenario states are constructed legally, not filtered afterwards

Candidate states come from a **witness-path walker** whose step table is a
transcription of the live room scripts with file-and-line citations on each
entry. A state exists as a candidate **only because a legal ordering of real
steps produced it**: every prerequisite transitively included, every implied
mandatory step included, the step set topologically orderable, and every room
entered with a key granted by an earlier step in that same ordering. Any
requested set that fails is discarded; **nothing is repaired**. Chronology is
therefore a property of construction, and the sixteen source-cited chronology
rules that run as validators are a check on that construction rather than the
thing that makes it legal.

### 9.2 The candidate pool

| NPC | Candidates | Witness-path length |
|---|---|---|
| `butler` | 19,440 | 5 – 32 |
| `gardener` | 18,792 | 8 – 32 |
| `mechanic` | 16,848 | 12 – 32 |
| **Total** | **55,080** | |

All 55,080 state fingerprints are distinct. The pool is three orders of
magnitude larger than the 72 states v4 needs, so selection is not operating
under scarcity.

### 9.3 Contamination exclusion

A **state fingerprint** is a SHA-256 over `npc`, `room` and the sorted evidence,
knowledge and story-flag lists — **carrying no identifier and no label**, so
state identity cannot depend on what a state is called or on what anyone
concluded about it, and so building the exclusion set requires **no access to any
annotation whatsoever**.

v4 contains no exact state duplicate of any earlier benchmark: the union of
`heldout-v2` (48) and `heldout-v3` (48) gives 96 distinct fingerprints, digest
`27ae5ddb…`, which the generator recomputes from disk and asserts against rather
than trusting the constant. Measured intersection with the legal pool was 48
candidates, all of them v3; the post-exclusion pool is **55,032**. Near-neighbour
states are allowed — a state differing by one flag is a different, independently
reachable state — and exclusion is exact-match only.

Synthetic test fixtures cannot be enumerated reliably, so a **structural**
argument is used instead: every synthetic and development state in the repository
places its NPC in `castle_hall`, and v4 places each NPC only in their live room.
`castle_hall` is not a v4 room, so no v4 state can equal any of them whatever
their contents. The checker asserts that partition still holds.

### 9.4 Structural features

Selection is driven by twelve deterministic functions of raw state, the witness
path, the derived PKM and catalogue structure — never by any judgement about what
a hint *should* say:

| # | Feature | Domain |
|---|---|---|
| F1 | `stage` | chemistry / greenhouse / circuit |
| F2 | `progression_bucket` | early / middle / late |
| F3 | `own_evidence` | bool |
| F4 | `other_major_count` | 0–2 |
| F5 | `eligible_count` | int |
| F6 | `associated_concept_states` | tuple of PKM states |
| F7 | `pkm_profile` | (UNSEEN, LEARNING, DEMONSTRATED) counts |
| F8 | `room_investigation_complete` | bool |
| F9 | `destination_reached` | bool |
| F10 | `prior_npc_interaction` | bool |
| F11 | `evidence_shape` | (F3, F4) joint |
| F12 | `shape_x_associated` | (F3, F4, F6) joint |

F11 and F12 are explicit interaction terms, included because marginal coverage
alone permits a selection that covers every value of every feature while covering
few of their combinations.

### 9.5 STRESS is selected first, then CORE

This deliberately reverses the intuitive order. A greedy coverage optimizer run
first would take the extreme states — shortest path, longest path, maximal
candidate counts — because extremes maximise marginal coverage. CORE would then
*be* the boundary set and STRESS would get the leftovers, inverting both strata's
purpose. Selecting STRESS first removes 24 boundary states before CORE runs,
leaving CORE to draw from the ordinary bulk. This makes CORE **less** favourable
to any condition that benefits from boundary handling, not more.

**STRESS (24 = 8 per NPC), one scenario per bin:**

| Bin | Boundary condition |
|---|---|
| B1 `very_early` | minimal witness-path length among remaining candidates |
| B2 `very_late` | maximal witness-path length |
| B3 `max_candidates_pref_active` | maximal eligible count **and** a soft preference active |
| B4 `associated_demonstrated` | ≥1 associated concept `DEMONSTRATED` |
| B5 `associated_learning` | ≥1 associated concept `LEARNING`, none `DEMONSTRATED` |
| B6 `no_own_evidence_plain` | own evidence absent, no preference active |
| B7 `evidence_after_progression` | own evidence held **and** room investigation complete |
| B8 `destination_reached` | the NPC's own thread has reached its terminal marker |

The task's eighth boundary condition was "states where SILENCE may plausibly be
useful", together with an explicit instruction not to decide in advance that a
state *should* be silence. Those cannot both be satisfied by a bin that names
silence, so **no bin does**; B8 is the structural analogue, and whether reaching
the destination makes any hint pointless is precisely the question the human
annotator answers and the conditions are scored on. Within a bin, candidates are
ranked by **boundary load** — how many of the eight predicates they satisfy —
under one uniform rule with no per-bin hand-tuning and therefore no per-bin
opportunity to steer.

**Butler B3 is provably and permanently empty**: the butler's only
`preferred_when_demonstrated` concept is `indicator_reaction`, whose
`DEMONSTRATED` state requires `butler_challenge_complete`, which by chronology
rule requires `fake_red_stain`, and holding the stain makes `h_butler_stain` the
only hard-eligible butler hint — count 1, not the maximum. "Maximal candidate
count" and "preference active" are mutually exclusive for the butler. Exactly one
backfill was therefore expected and occurred, is recorded in the artifact as
`bin_empty: true`, and the checker recomputes the emptiness set independently so
that `bin_empty` cannot be used as an escape hatch.

**CORE (48 = 16 per NPC)** is a greedy coverage spread over the twelve features,
with slots distributed across `progression_bucket` and buckets visited
round-robin so no single bucket consumes the coverage set before the others
compete for it. Generation **fails and writes no artifact** unless, for each NPC,
the 16 CORE scenarios cover every reachable value of `progression_bucket`,
`own_evidence`, `eligible_count` and `associated_concept_states`. The objective
contains **no selector output, no relevance judgement and no boundary-seeking
term**. There is no randomness anywhere and no seed exists, because none is
needed; ties are broken by a single total order (shorter witness path, then fewer
story flags, then fewer evidence items, then lexicographically smallest
fingerprint).

### 9.6 Resulting dataset shape

| Property | CORE (48) | STRESS (24) |
|---|---|---|
| Scenarios per NPC | 16 | 8 |
| `progression_bucket` | early 15 / middle 17 / late 16 | — (bin-defined) |
| STRESS bins | — | 3 per bin × 8 bins |
| Hard-eligible hint count 1 / 2 / 3 | 9 / 24 / 15 | 5 / 10 / 9 |

The hard-eligible count is small throughout — at most three candidates, and often
one or two. Section 11's `Coverage` and the discussion in Section 17.9 both depend
on this: a selector cannot express a preference among options it does not have.

One structural consequence is recorded in the spec and matters later: **no hint
in the catalogue currently declares `requires_story_flags` or `requires_concept`**,
so hard eligibility is a function of `evidence_items` alone, and within each NPC
the hard-eligible candidate count is collinear with whether the NPC's own
evidence is present.

---

## 10. Human Annotation Procedure

### 10.1 Ground truth is multi-valid, and answers a specific question

For each scenario the annotator supplies `VALID_HINTS` — **the set of hints that
are reasonable for this player state** — plus a free-text rationale and an
ambiguity level. The set may contain several hints, one hint, or **none**.

The frozen rubric is explicit that the question being answered is *"Which hints
are reasonable for this player state?"* and **not** *"Which hint do we want the
selector to choose?"*. Encoding the second would turn ground truth into a target
and the study into a fitting exercise.

Key rubric provisions, frozen before v4 was generated
(`docs/EVALUATION_PROTOCOL.md` §8b):

- **State-only judgement.** Decide from the state shown; do not import
  assumptions about the player.
- **Eligibility is necessary but not sufficient.** A hard-eligible hint may
  still be unreasonable.
- **`NONE` is a valid answer**, not an annotation failure.
- **Conversational premise.** A line whose premise is false in this state is not
  reasonable.
- **Directional guidance, cross-room staleness, teaching value, and
  self-defence** each have their own anchor.
- **Ambiguity anchors** define `LOW`, `MEDIUM` and `HIGH` explicitly.

### 10.2 Annotation order

The order is frozen and was followed:

1. States generated and frozen (hash committed and tagged);
2. Candidate hints presented per scenario in a neutral factual format;
3. The annotator assigns `VALID_HINTS`, rationale and ambiguity;
4. The annotations are frozen with their own checksum and tag;
5. **Only then** are the selectors run.

The `candidate_hints` list shown to the annotator is **not a prediction** and
carries no suggestion of a preferred answer. At the time of annotation **no
Condition A, B or C output for v4 existed at all**, so annotator contamination by
condition output was structurally impossible rather than merely prohibited.

Scenarios were presented **one at a time**, in batches, in a uniform neutral
factual format that avoided evaluative vocabulary — the preparation explicitly
refrained from calling anything stale, timely, redundant, premature, useful or
useless, and refrained from inferring whether an NPC line had or had not been
heard before where the progression model does not record that interaction
history.

### 10.3 Who annotated, and one disclosed exception

The annotator is the researcher. The assistant prepared the presentation
materials and was explicitly **not** the annotator.

One exception is disclosed rather than smoothed over, and it means **the 72
annotations must not be described as all independently originating with the
researcher**:

> **Scenario 72** was an **assistant-proposed adjudication**, derived by applying
> the researcher's own already-established annotation rule (the one previously
> applied to Scenarios 67–70), which the researcher then accepted into the frozen
> annotation set.

This is a real, if narrow, dependency between one label and the assistant, and
the limitations in Section 18 treat it as such.

### 10.4 Resulting annotation distribution

| Property | All 72 | CORE (48) | STRESS (24) |
|---|---|---|---|
| Total hint labels | 105 | 76 | 29 |
| Scenarios labelled `NONE` | 15 | 7 | 8 |
| Ambiguity `LOW` | 62 | 40 | 22 |
| Ambiguity `MEDIUM` | 8 | 8 | 0 |
| Ambiguity `HIGH` | 2 | 0 | 2 |

Every one of the 105 hint labels is hard-eligible in its own scenario. `MEDIUM`
falls at ordinals 6, 11, 12, 15, 22, 29, 30 and 41; `HIGH` at ordinals 58 and 60.
The 15 `NONE` scenarios are ordinals 2, 5, 9, 16, 19, 24, 28, 49, 50, 51, 52, 55,
56, 66 and 71 — ten of them butler, three gardener, two mechanic.

Per the rubric, `NONE` is a real annotation: every scenario carries a non-empty
rationale and an ambiguity level, and it is those, not a non-empty
`valid_hints`, that distinguish an annotated `NONE` from an unfilled blank.

Note that **CORE contains no `HIGH`-ambiguity scenario**, and that the two
`HIGH` cases both fall in STRESS. A consequence for the preregistered ambiguity
sensitivity analysis is noted in Section 12.4.

### 10.5 Annotator notes carried forward

Four notes were recorded by the annotator and form part of the freeze:

1. **Scenarios 58 and 60 are `HIGH` ambiguity** because the progression model has
   **no Gardener interaction-history flags**. Whether `h_gardener_pollen` is
   relevant depends materially on whether the player has already heard that exact
   response, and the state model cannot say.
2. **Gardener and Mechanic interaction history generally is not represented** by
   the frozen state model; prior-conversation facts must not be invented.
3. Scenario 72's label follows the same rule already applied to Scenarios 67–70.
4. The `VALID_HINTS` labels are the human ground truth; normalizing rationale
   wording is editorial prose only and must not alter the labels.

Two clarifications are recorded alongside the notes rather than edited into
them, since the notes are the annotator's text:

- Note 3's descriptive clause is imprecise for ordinals 69 and 70, where
  `circuit_fault_isolation` is `LEARNING` rather than `DEMONSTRATED`. The label
  is identical across ordinals 67–70 and 72, so the note's *conclusion* is
  unaffected; only its description is imprecise. Frozen scenario state and labels
  are authoritative.
- Note 2 is a limitation of the **state model**, not of those two scenarios
  alone: the interaction-flag table declares three flags for the butler
  (`butler_challenge_given`, `butler_challenge_complete`,
  `chemistry_butler_interviewed`) and **none at all** for the gardener or the
  mechanic. Ordinals 58 and 60 are where that gap becomes decision-relevant; the
  same gap applies in principle to every gardener and mechanic scenario, and no
  rationale in the frozen file claims that a gardener or mechanic line has or has
  not been heard before.

### 10.6 The rationale text carries no authority

`annotation_rationale` is normalized English prose recording the state facts in
view and the decision reached. It is **editorial**: several scenarios share an
identical (NPC, evidence, hard-eligible-hint) shape and still carry different
labels, so no rationale claims that the facts it cites *entail* the label. **The
hint identifiers and the ambiguity levels are the ground truth.**

### 10.7 The annotation freeze

The pre-annotation scenario file was **not modified**. The annotated file is a
separate copy, and the two carry identical state content:

| Artifact | SHA-256 |
|---|---|
| Pre-annotation scenarios (unchanged) | `1bb1535f…` |
| Annotated copy | `cd8d9e06…` |
| Annotation-only fingerprint (id, `valid_hints`, rationale, ambiguity) | `29a08dc0…` |
| State-only content (19 state fields, excluding both annotation fields) | `d9289573…` |

The state-only hash is identical for both files, so the state set remains
verifiable without reference to the labels. The annotation-only fingerprint is
computed exactly as v3's was, so the two protocol versions remain comparable. A
materializer reproduces the annotated file byte-for-byte and refuses to run
unless the pre-annotation source still hashes to `1bb1535f…`; a separate
validator re-derives every claim above from the files on disk, re-parsing hint
eligibility from the catalogue source rather than trusting the artifact's own
`eligible_hints` field, and its fault suite injects fifteen mutations and
requires each to be caught.

---

## 11. Metrics

All metrics are reported as **numerator and denominator first**, percentage
second. A zero denominator is reported as explicit `N/A`, **never as 0%**.

### 11.1 Primary metric

**`RelevantHintRate` — PRIMARY, unchanged from the v3 protocol.**

```
relevant    = selected hint id is non-empty AND selected hint id ∈ human VALID_HINTS
numerator   = relevant selections
denominator = all attempted scenarios
```

**`SILENCE` is never relevant — including on a scenario whose human label is
`NONE`.** A silent scenario is a relevance failure, lowers `Coverage`, and is
**never removed from the denominator**.

This definition was deliberately **not** amended for v4, and the reasoning was
recorded before v4 existed. Amending it would have changed the meaning of the
closed v3 headline number; it would have contradicted the frozen Condition C
specification, which tells the model that it cannot improve its score by
abstaining; and it would have done so **asymmetrically**, because only Condition
C can abstain at all. Keeping silence as a relevance failure also closes a gaming
vector: a selector that abstained whenever it was unsure would otherwise be
rewarded for withholding guidance.

### 11.2 Secondary prospective metric

**`AppropriateActionRate` — SECONDARY, new and prospective in v4.**

```
correct_action = (delivered AND selected hint ∈ VALID_HINTS)
                 OR (SILENCE AND VALID_HINTS is empty)
numerator      = correct actions
denominator    = all attempted scenarios
```

This metric separates two questions that `RelevantHintRate` deliberately fuses:
**whether a delivered hint was relevant**, and **whether delivering anything was
the right call**. `RelevantHintRate` answers the first and remains primary.

**Why the two metrics differ, stated explicitly.** Consider a scenario the
annotator labelled `NONE` — no listed line is reasonable. A policy that stays
silent there has done the right thing in ordinary terms, but under the frozen
primary definition it scores a relevance **failure**, because it delivered no
relevant hint; the primary metric has no way to express "correctly said
nothing". `AppropriateActionRate` gives credit for exactly that case. The two
metrics therefore diverge precisely on the `NONE`-labelled scenarios, and only
for a condition capable of silence. Conditions A and B cannot abstain at all, so
for them the two metrics **must** coincide by construction; any gap between
`RelevantHintRate` and `AppropriateActionRate` can only come from Condition C.

This is a real and intentional asymmetry in what the two metrics reward, not a
discrepancy to be reconciled. It is the reason `AppropriateActionRate` was
preregistered as a **separate secondary metric** rather than folded into the
primary one.

**`CorrectSilenceRate` — DESCRIPTIVE ONLY.**

```
numerator   = NONE-labelled scenarios on which the selector chose SILENCE
denominator = NONE-labelled scenarios
```

Reported as `N/A` when the denominator is zero. It is **not** merged into
`RelevantHintRate` and carries **no preregistered inferential test**.

### 11.3 Metrics carried forward from v3

| Metric | Definition | Status |
|---|---|---|
| `Coverage` | delivered ÷ attempted | descriptive |
| `StateViolationRate` | hard-prerequisite violations ÷ delivered | primary safety check |
| `RedundantHintRate` | redundant deliveries ÷ delivered | primary (descriptive reporting) |
| `RedundantWhenTeachable` | redundant-and-teaching ÷ teaching deliveries | secondary |

**`Coverage` is not a fair cross-condition comparison without a caveat.**
Conditions A and B have no silence branch, so their `Coverage` is 100% **by
construction**, not by achievement. Condition C can abstain. Any table that puts
them in one column must carry this note, and this report does.

An unsatisfied `preferred_when_demonstrated` is **never** a `StateViolation`.

### 11.4 Redundancy, and why it is not the same as relevance

A delivered hint is **redundant** iff **every** concept in its `teaches` list is
`DEMONSTRATED` for that player. A hint that teaches no PKM concept is never
redundant. `RedundantWhenTeachable` restricts the denominator to deliveries that
actually teach a PKM concept, which is the only denominator under which the
redundancy question is meaningful; where that denominator is zero the result is
reported as `N/A (0 teaching hints delivered)` and never as 0%.

**Human relevance and non-redundancy are different properties, and they can
disagree.** The annotator answers *"is this a reasonable thing to say to this
player?"* A hint that re-explains a concept the player has already passed the
check on can still be a reasonable thing to say — it may carry narrative or
investigative content beyond the lesson, and the annotator may quite properly
mark it valid. Redundancy, by contrast, is a **mechanical property computed from
the PKM**: it asks only whether every concept the line teaches is already
`DEMONSTRATED`.

It is therefore entirely possible, and in this dataset it actually happens, for
a delivered hint to be **human-labelled relevant and simultaneously counted
redundant**. No human label was rewritten to remove that tension, and no
redundancy result should be read as a claim that the annotator was wrong. The two
metrics measure two things, and the primary research question asks about both.

### 11.5 No composite score

No overall score combining these metrics exists, and none was computed.
Constructing one would require choosing weights, and any weighting chosen after
seeing the results would be a form of tuning.

---

## 12. Statistical Analysis

The analysis plan below was committed **before the v4 scenarios were generated**,
and the exact test implementation was committed alongside it, so the analysis
code predates the data.

### 12.1 Primary inferential analysis — CORE only

Because all three conditions see the same scenarios, relevance comparisons are
**paired**, and the appropriate test is an exact paired binomial test on
discordant pairs (**exact McNemar**).

For a pair of conditions, let

- `b` = scenarios where the **first** condition is correct and the second is not;
- `c` = scenarios where the **second** is correct and the first is not;
- `n = b + c` (the discordant pairs; concordant pairs carry no information).

The two-sided exact p-value is

```
p = min( 1,  2 · Σ_{k=0}^{min(b,c)} C(n, k) / 2ⁿ )
```

with **no continuity correction and no chi-square approximation**. When `n = 0`
the test is **undefined**: the frozen metrics file records the literal string
`N/A (no discordant pairs)`, which this report renders as *undefined* — never as
`p = 1` and never as a null result dressed up as a finding. An undefined test has
no p-value, and therefore nothing for a multiplicity adjustment to act on.

**The complete preregistered primary family is three pairwise comparisons of
`RelevantHintRate` on CORE:**

| Comparison | What it tests |
|---|---|
| **A vs B** | the **primary research question** — does the PKM improve relevance? |
| A vs C | LLM selector against the no-PKM baseline |
| **B vs C** | the **secondary research question** — does the LLM beat deterministic PKM rules? |

For each comparison the report states: each condition's numerator and
denominator, the absolute percentage-point difference, the discordant counts `b`
and `c`, the exact p-value, and the direction of the effect.

### 12.2 Secondary inferential analysis

The same three paired exact McNemar comparisons are run on
`AppropriateActionRate` and are labelled **SECONDARY** wherever they appear.

Any inferential analysis computed on the **STRESS** stratum is
**secondary/exploratory** by definition and is labelled as such. STRESS is not
confirmatory evidence for any claim in this report.

### 12.3 Multiplicity and sparse-data reporting

**Multiplicity.** The three comparisons above are the complete preregistered
family. **Unadjusted exact p-values are the primary reporting**, and
**Holm-adjusted values across the family of three are reported alongside**. Any
significance claim must state which it uses. How this rule was carried out, and
what happens to a comparison that has no exact p-value, is set out once in
Section 13.4.

**Sparse data.** No p-value is reported without its discordant counts, and any
comparison with `b + c < 5` carries an **explicit low-information caveat**. This
is a *reporting* requirement, not a rule for suppressing results: a sparse
comparison is still reported, it is simply labelled as carrying very little
information. **No significance is claimed from redundancy metrics when
denominators are sparse.**

The practical force of this rule in the present study was anticipated and is
flagged in advance: with 48 CORE scenarios and three highly similar policies, the
discordant counts were **expected to be very small**, and a comparison resting on
very few discordant pairs can resolve only large differences. This expectation is
a **qualitative design judgement, not a formal power analysis** — no power
calculation was performed at any point in this study, and none is reported. A
non-significant result here should be read as *"this study could not distinguish
these policies"*, not as *"these policies are proven equivalent"*.

### 12.4 Preregistered sensitivity analysis on annotation ambiguity

Because some scenarios are harder to annotate than others, the plan calls for the
CORE primary analysis to be repeated on the `LOW`-ambiguity subset and on the
`LOW + MEDIUM` subset, to confirm that a conclusion does not rest on the
scenarios the annotator found least clear.

One property of the frozen annotation must be stated up front, because it
determines what this sensitivity analysis can show: **CORE contains 40 `LOW`, 8
`MEDIUM` and 0 `HIGH` scenarios.** The `LOW + MEDIUM` band therefore *is* the
entire CORE stratum, and that band of the sensitivity analysis is **degenerate —
identical to the main CORE analysis by construction**. Only the `LOW`-only band
(n = 40) is informative, and the two `HIGH` scenarios fall in STRESS and can only
ever be examined descriptively.

### 12.5 Everything else is descriptive

`Coverage`, `StateViolationRate`, `RedundantHintRate`, `RedundantWhenTeachable`,
`CorrectSilenceRate`, the per-NPC breakdowns, the per-stratum breakdowns and the
all-72 block are reported **descriptively**, numerator and denominator first,
with no inferential test and no significance claim attached.

### 12.6 The v3 study is not recomputed

The closed v3 artifacts are **not altered**, and v3 is **not** recomputed under
`AppropriateActionRate` as part of this study. It may be noted as arithmetic —
not as a result — that Conditions A and B produced **zero** silent scenarios on
v3, so their closed `RelevantHintRate` figures would be unchanged under an
abstention-aware reading. **No retroactive v3 headline metric is created.**

---

## 13. Results

All figures below are read from the frozen evaluation artifacts produced by the
single scored run at commit `1df684e9` (tag `heldout-v4-evaluation`). No
experiment was run to produce this section, Condition C was not rerun, and no
annotation, selector, metric or artifact was modified.

### 13.1 How to read these results

| Block | Status | May support |
|---|---|---|
| **CORE (n = 48)** | **primary confirmatory** | the conclusions of this study |
| **STRESS (n = 24)** | preregistered **secondary** robustness / boundary | robustness observations only |
| **ALL 72** | **descriptive only** | illustration; no inference |

The strata are reported separately and are never combined into a headline
figure. No composite score exists.

### 13.2 Summary across all three blocks

Numerators and denominators first; percentages are secondary.

| Metric | Block | A | B | C |
|---|---|---|---|---|
| **`RelevantHintRate` (PRIMARY)** | CORE | 32/48 = 66.7% | 32/48 = 66.7% | 33/48 = 68.8% |
| | STRESS | 12/24 = 50.0% | 12/24 = 50.0% | 16/24 = 66.7% |
| | ALL 72 | 44/72 = 61.1% | 44/72 = 61.1% | 49/72 = 68.1% |
| **`AppropriateActionRate` (SECONDARY)** | CORE | 32/48 = 66.7% | 32/48 = 66.7% | 35/48 = 72.9% |
| | STRESS | 12/24 = 50.0% | 12/24 = 50.0% | 21/24 = 87.5% |
| | ALL 72 | 44/72 = 61.1% | 44/72 = 61.1% | 56/72 = 77.8% |
| **`CorrectSilenceRate` (descriptive)** | CORE | 0/7 | 0/7 | 2/7 = 28.6% |
| | STRESS | 0/8 | 0/8 | 5/8 = 62.5% |
| | ALL 72 | 0/15 | 0/15 | 7/15 = 46.7% |
| **`Coverage`** (see caveat) | CORE | 48/48 | 48/48 | 45/48 = 93.8% |
| | STRESS | 24/24 | 24/24 | 19/24 = 79.2% |
| | ALL 72 | 72/72 | 72/72 | 64/72 = 88.9% |
| **`StateViolationRate`** | CORE | 0/48 | 0/48 | 0/45 |
| | STRESS | 0/24 | 0/24 | 0/19 |
| | ALL 72 | 0/72 | 0/72 | 0/64 |
| **`RedundantHintRate`** | CORE | 1/48 = 2.1% | 0/48 | 0/45 |
| | STRESS | 1/24 = 4.2% | 0/24 | 0/19 |
| | ALL 72 | 2/72 = 2.8% | 0/72 | 0/64 |
| **`RedundantWhenTeachable`** | CORE | 1/3 | 0/2 | 0/18 |
| | STRESS | 1/3 | 0/2 | 0/8 |
| | ALL 72 | 2/6 | 0/4 | 0/26 |

**Coverage caveat, restated wherever this table is quoted.** Conditions A and B
have no silence branch and therefore deliver on every scenario **by
construction**; their 100% `Coverage` is a structural property of their design,
not a measured achievement. Condition C can abstain, so its lower `Coverage` is
the arithmetic shadow of a capability the other two do not have. The three
numbers are **not comparable as a quality ranking**, and Section 16 shows that
most of C's non-delivery falls on scenarios the human annotator labelled `NONE`.

### 13.3 The one result that carries no caveat

**`StateViolationRate` is 0 in every condition, in every stratum.** Across 208
delivered hints in total (72 + 72 + 64), not one violated its hard evidence or
story prerequisites. Every delivered hint was factually admissible in the state
it was delivered into, including every hint chosen by the language model.

This is the safety property the protocol exists to guard, it was verified
independently of the harness that produced the selections, and it is the only
outcome in this study that is not qualified by sparse data, sparse discordance or
a structural asymmetry between conditions.

### 13.4 Multiplicity adjustment: preregistration checked

Holm-adjusted p-values are reported below because the requirement was
**preregistered**, not because it seemed advisable afterwards. The frozen
protocol §12.5 states:

> **Multiplicity.** These three comparisons are the complete preregistered
> family. Unadjusted exact p-values are the primary reporting; Holm-adjusted
> values across the family of three are reported alongside. Any significance
> claim must state which it uses.

This text is present in `docs/EVALUATION_PROTOCOL.md` at commit `901315b0`, tag
**`heldout-v4-generation-pre-freeze`** — which precedes the v4 scenario freeze
(`heldout-v4-pre-annotation`, `3cf6e836`), the annotation freeze
(`heldout-v4-post-annotation`, `e43bb365`) and the evaluation
(`heldout-v4-evaluation`, `1df684e9`). The requirement therefore predates the
existence of the scenarios, the labels and the results.

The frozen `heldout_v4_metrics.json` records the exact unadjusted p-values but
does **not** contain the Holm-adjusted values. They are computed here as a
deterministic arithmetic transform of those frozen p-values. **No new data is
introduced and no artifact is modified.**

**The adjustment reported is the preregistered one: Holm across the family of
three.** A single Holm column appears in each results table below; no alternative
family size is substituted, and no second "conservative" column is offered,
because the protocol preregistered one family and one adjustment.

**Why one cell of each family is blank.** The A-versus-B comparison has **zero
discordant pairs** in every one of the three families. Exact McNemar is defined on
the discordant pairs alone, so with `b = c = 0` there is no test statistic and no
exact p-value — the comparison is *undefined*, which is a stronger statement than
"not significant". Holm operates on p-values; with no p-value there is nothing to
adjust. The frozen protocol does not specify a substitute value for an undefined
member of the family, so **none is invented**: the cell is reported as undefined
in both the unadjusted and the adjusted column, and the two defined comparisons
are adjusted at family size three as preregistered.

**The adjustment changes no conclusion, and no frozen result changed.** The
**exact unadjusted p-values are the primary statistical reporting** throughout
this report; the Holm column is the preregistered companion to them. The defined
primary exact p-values are already `1.000`, which no multiplicity correction can
make smaller. Holm is reported because it was preregistered, not because it does
any work here. This is the report's single statement of Holm handling; the tables
below carry the values and do not restate the rule.

---

## 14. CORE Results

CORE is the **primary confirmatory** block: 48 scenarios, 16 per NPC, drawn from
the ordinary bulk of the reachable state space rather than from its boundaries.

### 14.1 Primary outcome — `RelevantHintRate`

| Condition | Relevant / attempted | Rate |
|---|---|---|
| A — evidence-depth static baseline | 32/48 | 66.7% |
| B — deterministic PKM-aware selector | 32/48 | 66.7% |
| C — LLM + PKM selector | 33/48 | 68.8% |

**Exact paired two-sided McNemar, CORE `RelevantHintRate` — the preregistered
primary family:**

| Comparison | b | c | discordant n | exact p | Holm (preregistered family of 3) |
|---|---|---|---|---|---|
| **A vs B** | 0 | 0 | **0** | **undefined (no discordant pairs)** | **undefined** |
| A vs C | 1 | 2 | 3 | 1.000000 | 1.000000 |
| **B vs C** | 1 | 2 | 3 | 1.000000 | 1.000000 |

Here `b` counts scenarios where the first-named condition is relevant and the
second is not, and `c` the reverse. **All three comparisons carry the frozen
low-information caveat (`b + c < 5`).** The A-vs-C and B-vs-C tests rest on three
discordant scenarios each; the A-vs-B test has no discordant scenarios at all and
is therefore undefined rather than null.

**What this does and does not license.**

- **A versus B (the primary research question).** A and B produced an *identical*
  relevance outcome on every one of the 48 CORE scenarios: not merely the same
  total, but the same per-scenario pattern, which is why the discordant count is
  zero and the test is undefined. **The deterministic PKM did not increase
  confirmatory hint relevance in this holdout.** The study provides **no evidence
  that B improves relevance over A**, and — because a test on zero discordant
  pairs has no power whatsoever — it equally provides no evidence that the two
  are the same policy. **They are not described as equivalent.** The correct
  statement is that **this study could not distinguish them on the primary
  outcome**, and Section 16 shows exactly why: they differ in action on only two
  of 72 scenarios, and on both of those *both* choices were human-relevant.
- **A/B versus C (the secondary research question).** C's observed
  `RelevantHintRate` is **2.1 percentage points** above A and B — one additional
  relevant scenario out of 48. The paired evidence is three discordant scenarios
  and `p = 1.000` both unadjusted and Holm-adjusted. **C did not significantly
  improve confirmatory relevance.** The difference is tiny, statistically
  non-significant, and well within what three discordant pairs can produce by
  chance. This study **could not distinguish C from A or B on the primary
  outcome** either.

### 14.2 Secondary outcome — `AppropriateActionRate`

| Condition | Correct actions / attempted | Rate |
|---|---|---|
| A | 32/48 | 66.7% |
| B | 32/48 | 66.7% |
| C | 35/48 | 72.9% |

**Exact paired two-sided McNemar, CORE `AppropriateActionRate` — SECONDARY:**

| Comparison | b | c | discordant n | exact p | Holm (preregistered family of 3) |
|---|---|---|---|---|---|
| A vs B | 0 | 0 | **0** | **undefined (no discordant pairs)** | **undefined** |
| A vs C | 1 | 4 | 5 | 0.375000 | 1.000000 |
| B vs C | 1 | 4 | 5 | 0.375000 | 1.000000 |

With five discordant scenarios these comparisons sit exactly at the frozen
sparse-data threshold and remain **low-information**; `p = 0.375` unadjusted and
`1.000` Holm-adjusted support **no significance claim in either direction**.

A and B score identically on this metric **by construction**: neither can
abstain, so for them `AppropriateActionRate` and `RelevantHintRate` are the same
quantity computed twice. The entire A-to-C gap of 3 scenarios is the sum of C's
relevance gain (+1) and its abstention credit on `NONE`-labelled scenarios (+2),
as itemised in Section 16.3.

### 14.3 Silence, coverage and redundancy on CORE

| Descriptive metric | A | B | C |
|---|---|---|---|
| `CorrectSilenceRate` | 0/7 | 0/7 | 2/7 = 28.6% |
| `Coverage` | 48/48 *(structural)* | 48/48 *(structural)* | 45/48 = 93.8% |
| `StateViolationRate` | 0/48 | 0/48 | 0/45 |
| `RedundantHintRate` | 1/48 = 2.1% | 0/48 | 0/45 |
| `RedundantWhenTeachable` | 1/3 | 0/2 | 0/18 |
| teaching hints delivered | 3 | 2 | 18 |

CORE contains **7 scenarios labelled `NONE`**. A and B delivered a hint on all
seven, because they cannot do otherwise. C abstained on two of them.

The redundancy denominators are **very small** — A delivered a teaching hint 3
times on CORE, B twice. `RedundantWhenTeachable` of 1/3 versus 0/2 is a
difference of **one event**, and no significance is claimed from it, in keeping
with the frozen rule that no significance is claimed from redundancy metrics with
sparse denominators.

C delivered teaching hints **18 times on CORE — six times as often as A** — and
recorded **zero** redundant deliveries among them. That is a descriptive
observation about a different behavioural profile, not a demonstrated advantage:
with A's own redundancy denominator at 3, the comparison has almost no resolving
power.

### 14.4 Preregistered ambiguity sensitivity

| CORE subset | n | A | B | C |
|---|---|---|---|---|
| `LOW` only | 40 | 28/40 = 70.0% | 28/40 = 70.0% | 30/40 = 75.0% |
| `LOW + MEDIUM` | 48 | 32/48 = 66.7% | 32/48 = 66.7% | 33/48 = 68.8% |

The `LOW`-only band reproduces the main CORE pattern: A and B identical, C ahead
by two scenarios out of 40. Removing the eight scenarios the annotator found less
clear does not change which conclusion the data supports.

**The `LOW + MEDIUM` band is degenerate and provides no independent sensitivity
result.** CORE contains 40 `LOW`, 8 `MEDIUM` and **0 `HIGH`** scenarios, so
`LOW + MEDIUM` *is* the entire CORE stratum and the row above is arithmetically
identical to the confirmatory analysis by construction. This is stated rather
than presented as a second confirmation of the first. Both `HIGH` scenarios fall
in STRESS and can only be examined descriptively (Section 16.5).

The frozen artifact records the governing note: *"Sensitivity only. The
confirmatory CORE analysis uses all 48 frozen labels; ambiguous cases are NOT
excluded."*

### 14.5 A large block of shared failure

On **14 of the 48 CORE scenarios, all three tested conditions were relevance
failures** — none of A, B or C selected a hint the annotator had listed. The
observed CORE scores span **32 to 33**, and the primary outcome was decided inside
a one-scenario band.

This is context for reading a 2.1-percentage-point difference as small: across the
three policies actually tested, the scenarios on which they could differ were few.

**What this block of shared failure does not show.** It does **not** establish a
theoretical maximum, a design-imposed ceiling or an upper bound on what any
selector could achieve. The statement supported by the data is only that *these
three policies failed on the same 14 scenarios*. An untested selector — a
different rule ordering, a different prompt, a different model, or simply a
different tie-break — might have chosen a human-valid hint on some of them. Shared
observed failure across three related policies is evidence about those three
policies, not about the space of possible policies.

---

## 15. STRESS Results

STRESS is a **preregistered secondary** block of 24 deliberately selected
boundary states — three per NPC in each of eight boundary bins. It is
**robustness and boundary evidence only**. Nothing in this section overrides the
CORE confirmatory conclusion, and none of it is confirmatory for any claim in
this report.

### 15.1 Outcomes

| Metric | A | B | C |
|---|---|---|---|
| `RelevantHintRate` | 12/24 = 50.0% | 12/24 = 50.0% | 16/24 = 66.7% |
| `AppropriateActionRate` | 12/24 = 50.0% | 12/24 = 50.0% | 21/24 = 87.5% |
| `CorrectSilenceRate` | 0/8 | 0/8 | 5/8 = 62.5% |
| `Coverage` | 24/24 *(structural)* | 24/24 *(structural)* | 19/24 = 79.2% |
| `StateViolationRate` | 0/24 | 0/24 | 0/19 |
| `RedundantHintRate` | 1/24 = 4.2% | 0/24 | 0/19 |
| `RedundantWhenTeachable` | 1/3 | 0/2 | 0/8 |

Eight of the 24 STRESS scenarios are labelled `NONE` — a third of the stratum,
against 7 of 48 in CORE. This is by design: STRESS bins were built to sit at
progression and evidence boundaries, where an NPC is more likely to have nothing
useful left to say.

### 15.2 Paired comparisons — exploratory

**A correction to the figures as supplied.** The frozen metrics file contains
exactly three McNemar blocks: `CORE_mcnemar_PRIMARY_RelevantHintRate`,
`CORE_mcnemar_SECONDARY_AppropriateActionRate` and
`STRESS_mcnemar_RelevantHintRate_secondary`. The STRESS block with
`b = 0, c = 4, p = 0.125` is the **`RelevantHintRate`** block (12 successes
versus 16), not an `AppropriateActionRate` block. **The frozen artifact contains
no STRESS `AppropriateActionRate` McNemar test**, and none is manufactured here.

**Exact paired two-sided McNemar, STRESS `RelevantHintRate` — SECONDARY /
EXPLORATORY:**

| Comparison | b | c | discordant n | exact p | Holm (preregistered family of 3) |
|---|---|---|---|---|---|
| A vs B | 0 | 0 | **0** | **undefined (no discordant pairs)** | **undefined** |
| A vs C | 0 | 4 | 4 | 0.125000 | 0.375000 |
| B vs C | 0 | 4 | 4 | 0.125000 | 0.375000 |

Four discordant scenarios is **below the frozen sparse-data threshold**, so both
defined comparisons are explicitly **low-information**. Even so, note the
structure of the discordance: `b = 0`. **C was relevant on every STRESS scenario
on which A or B was relevant, and on four more besides.** Eight STRESS scenarios
were relevance failures for **all three tested conditions**; C therefore recorded
the highest STRESS relevance score of the three policies tested here. That is a
descriptive fact about this run. It is **not** a claim of optimality, **not** a
statement that 16/24 is an attainable maximum for some other selector, and **not**
confirmatory evidence.

The largest observed STRESS gap is on `AppropriateActionRate` — **A 12/24, B
12/24, C 21/24**. Although that difference is numerically large, **no
corresponding inferential test was included in the frozen evaluation artifact, so
it is reported descriptively rather than supplemented with a post-hoc test.**
Adding one now would be exactly the kind of after-the-fact analysis the freeze
discipline exists to prevent. The comparison is secondary by definition and
remains descriptive evidence only.

### 15.3 Where the STRESS difference lives

| Stratum | NPC | A relevant | B relevant | C relevant | C appropriate | C coverage |
|---|---|---|---|---|---|---|
| STRESS | butler | 1/8 | 1/8 | 2/8 | 7/8 | 3/8 |
| STRESS | gardener | 5/8 | 5/8 | 8/8 | 8/8 | 8/8 |
| STRESS | mechanic | 6/8 | 6/8 | 6/8 | 6/8 | 8/8 |

The butler row is the clearest illustration of the two metrics measuring
different things. Six of the eight butler STRESS scenarios are labelled `NONE`;
C abstained on five of them. Under `RelevantHintRate` those five abstentions are
**failures** and C scores 2/8; under `AppropriateActionRate` they are **correct
actions** and C scores 7/8. The behaviour is identical; only the metric's
definition of success differs.

The mechanic row is equally instructive in the opposite direction. C chose a
different hint from A and B on most mechanic scenarios (Section 16.4) and its
relevance score was **exactly the same**, 6/8 — a large behavioural difference
producing no measured effect at all.

### 15.4 Scope of the STRESS evidence

A defensible reading is that **C showed stronger behaviour in boundary states,
particularly its ability to abstain when no human-valid hint existed.** That
reading is bounded in three ways:

1. STRESS is not confirmatory and must not be used to override the CORE result.
2. STRESS was **deliberately constructed** from boundary bins and therefore does
   **not** represent the prevalence of such states in real play. A third of it is
   `NONE`-labelled; ordinary play is not.
3. The comparisons are low-information (`n = 4`).

**STRESS does not show that C is superior overall.**

---

## 16. Error and Disagreement Analysis

### 16.1 How much the three conditions actually differed

**38 of 72 scenarios** contain at least one differing action among A, B and C.
Almost all of that is C against the other two:

| Pair | Scenarios with a different selected action |
|---|---|
| A vs B | **2 of 72** |
| A vs C | 38 of 72 |

The two studies agree on this shape: in `heldout-v3` A and B diverged on exactly
one scenario out of 48; here on two out of 72.

### 16.2 A versus B: why relevance cannot separate them

A and B chose differently on **ordinals 29 and 59 only**, both gardener
scenarios, both with the same three hard-eligible candidates, and — critically —
both with **all three candidates on the human `VALID_HINTS` list**:

| Ordinal | Stratum | Ambiguity | A selected | B selected | Human labels |
|---|---|---|---|---|---|
| 29 (`v4_core_gardener_13`) | CORE | MEDIUM | `h_gardener_leaf_colour` — relevant, **redundant**, teaching | `h_gardener_knows_reflection` — relevant, not redundant | all three candidates valid |
| 59 (`v4_stress_gardener_03`) | STRESS | LOW | `h_gardener_leaf_colour` — relevant, **redundant**, teaching | `h_gardener_knows_reflection` — relevant, not redundant | all three candidates valid |

**These two scenarios are the entire measured difference between the two
policies, and they are exactly the two redundant deliveries in the whole study.**
Both of A's redundant selections were **also human-labelled relevant**: a line
that re-explains `reflection` to a player who has already passed the reflection
check still described something the annotator judged reasonable to say.

This is the mechanical reason `RelevantHintRate` cannot distinguish A from B.
The metric asks "was the chosen hint on the human list?" and both answers were
yes. The difference between them is invisible to relevance and visible only to
redundancy — which is a **measurement and design limitation of the study**, and
is recorded as such rather than hidden.

### 16.3 How B's PKM advantage actually arose

Reconstructing which cascade rule fired on each scenario, from the frozen decision
traces:

| B rule | Fired (all 72) | Fired (CORE) |
|---|---|---|
| Rule 2 — soft preference satisfied *(PKM enters here)* | 9 | 5 |
| **Rule 3 — explicit redundancy avoidance** | **0** | **0** |
| Rule 4 — A-4 fallback | 63 | 43 |

Two observations follow, and both matter more than the headline numbers.

**Rule 3 never fired.** The rule written specifically to avoid redundant teaching
did not execute once in 72 scenarios. Both of B's redundancy avoidances came
through **Rule 2**, the soft-preference rule, which happened to return a
non-teaching hint before the fallback was ever reached. B's redundancy result is
therefore a **side effect of soft preference ordering**, not a demonstration that
the redundancy-avoidance mechanism works. That mechanism remains **untested by
this holdout**.

**PKM changed the answer twice.** Rule 2 fired 9 times but produced a different
hint from A on only 2 of them. On the other 7, the PKM-preferred hint was the
same hint the fallback would have returned anyway.

### 16.4 Condition C's selection tendencies

C's selections are distributed quite differently from A's and B's. Over all 72
scenarios:

| Hint | A | B | C |
|---|---|---|---|
| `h_butler_stain` | 14 | 14 | 6 |
| `h_butler_knows_rule` | 4 | 4 | **10** |
| `h_butler_no_evidence` | 6 | 6 | **0** |
| `h_gardener_pollen` | 15 | 15 | 5 |
| `h_gardener_leaf_colour` | 6 | 4 | **16** |
| `h_gardener_knows_reflection` | 3 | 5 | 2 |
| `h_gardener_no_evidence` | 0 | 0 | 1 |
| `h_mechanic_short_circuit` | 9 | 9 | 6 |
| `h_mechanic_knows_resistance` | 15 | 15 | 8 |
| `h_mechanic_series_basics` | **0** | **0** | **10** |
| `SILENCE` | 0 | 0 | 8 |

Three tendencies are visible. **They are reported descriptively. None of them is
claimed to be intrinsically better**, and each is related to the human labels
where the labels speak to it.

1. **C prefers `h_butler_knows_rule` over `h_butler_no_evidence`.** Where the
   labels distinguish them, this went C's way: on ordinals 7 (CORE) and 53
   (STRESS), A and B selected `h_butler_no_evidence`, which was not on the human
   list, while C selected `h_butler_knows_rule`, which was. Ordinal 7 is one of
   the two scenarios producing C's entire CORE relevance gain.
2. **C prefers `h_gardener_leaf_colour` over `h_gardener_pollen`.** Again the
   labels favoured C where they distinguished them: on ordinals 25 (CORE) and 61,
   63, 64 (STRESS), `h_gardener_pollen` was not on the human list and
   `h_gardener_leaf_colour` was. This accounts for C's other CORE relevance gain
   and three of its four STRESS gains. It is also the largest single behavioural
   shift in the study — the hint A never picks more than 6 times, C picks 16.
3. **C prefers `h_mechanic_series_basics`, which A and B never select at all.**
   A and B cannot reach it: it is A-4's tier-3 line for the mechanic, and no
   mechanic scenario in v4 reaches tier 3. C selected it 10 times. **This changed
   what was said on a substantial fraction of mechanic scenarios and changed the
   measured relevance by exactly nothing** — A, B and C all scored 13/16 on CORE
   mechanic and 6/8 on STRESS mechanic. A large difference in behaviour with no
   difference in outcome is as much a result as a gap would have been.

### 16.5 Condition C's abstentions

C produced **8 `SILENCE` outputs**, all on butler scenarios: ordinals 2, 15, 16,
50, 51, 52, 55, 56.

| Ordinal | Stratum | Human `VALID_HINTS` | Verdict |
|---|---|---|---|
| 2, 16 | CORE | *(empty — `NONE`)* | correct abstention |
| 50, 51, 52, 55, 56 | STRESS | *(empty — `NONE`)* | correct abstention |
| **15** | CORE | `["h_butler_stain"]` | **false abstention** |

**Seven of the eight abstentions landed on scenarios the annotator had labelled
`NONE`** — states where, in the annotator's judgement, no listed line was a
reasonable thing to say. One, ordinal 15, was wrong: `h_butler_stain` was both
hard-eligible and on the human list, and C stayed silent anyway. Ordinal 15 is
`MEDIUM` ambiguity and is the single scenario on which C is worse than A and B
under both metrics — it is the `b = 1` in every CORE comparison above.

**The primary-metric tension, stated plainly.** Under the frozen definition of
`RelevantHintRate`, **all eight of these abstentions are relevance failures —
including the seven that were correct.** The metric requires a delivered hint
that appears on the human list; silence delivers no hint, so it can never be
relevant, even on a scenario whose human label is exactly "nothing here is
reasonable to say."

This is not a defect discovered after the fact. It is the frozen v3 definition,
carried forward deliberately, for reasons recorded before v4 existed: amending it
would have changed the meaning of the closed v3 headline, would have contradicted
the Condition C specification's own statement that C cannot improve its score by
abstaining, and would have done so **asymmetrically**, since only C can abstain
at all. Keeping it also closes a gaming vector — a selector that abstained
whenever unsure would otherwise be rewarded for withholding guidance.

`AppropriateActionRate` exists precisely to measure what the primary metric
cannot, and this is where the gap between the two comes from. On CORE, C's
`RelevantHintRate` of 33/48 and `AppropriateActionRate` of 35/48 differ by
exactly the 2 correct abstentions; on STRESS, 16/24 and 21/24 differ by exactly
the 5 correct abstentions. For A and B the two metrics are identical, because
they never abstain. **Every point of divergence between the two metrics in this
study is an abstention by C.**

### 16.6 Failures shared by all three conditions

**22 of the 72 scenarios (14 CORE, 8 STRESS) were relevance failures for every
condition.** On these, no policy tested here selected a hint the annotator had
listed. They are not attributable to any selector's logic: they mark states where
the available catalogue, the A-4 tier structure and the model's judgement all
pointed away from what the human considered reasonable.

Of the 15 `NONE`-labelled scenarios, A and B delivered a hint on all 15 — every
one an automatic relevance failure they had no mechanism to avoid. That accounts
for 15 of A's and B's 28 failures across all 72 scenarios. **More than half of
A's and B's total measured error is structurally unavoidable given that they
cannot decline to speak.**

### 16.7 The two `HIGH`-ambiguity scenarios

Ordinals **58** (`v4_stress_gardener_02`) and **60** (`v4_stress_gardener_04`)
are the only scenarios the annotator marked `HIGH`, both in STRESS, both gardener.
Each has a single human label, `h_gardener_pollen`, and **all three conditions
selected it**. Both scenarios are therefore relevant for A, B and C alike and
contribute nothing to any discordant count.

The annotator marked them `HIGH` for a specific structural reason: whether
`h_gardener_pollen` is a reasonable thing to say depends materially on **whether
the player has already heard that exact response**, and the frozen state model
records no gardener interaction history at all. The interaction-flag table
declares three flags for the butler and **none** for the gardener or the
mechanic. The annotator did not invent prior-conversation facts, which is the
correct behaviour under the rubric, and the resulting uncertainty was recorded as
ambiguity rather than resolved by guesswork.

So the two hardest-to-annotate scenarios in the study produced **no
differentiation between the conditions**. The gap they expose is in the **state
representation**, not in any selector.

---

## 17. Discussion

### 17.1 The deterministic PKM did not increase confirmatory relevance

On the primary confirmatory outcome, **Condition B did not improve
`RelevantHintRate` over Condition A**: both scored 32/48, with zero discordant
scenarios. The direct answer to the first half of the primary research question,
under the selector design tested here, is that **the unified PKM did not raise
overall hint relevance**.

The zero discordant count means the comparison carries no statistical
information in either direction, so the two policies are **not described as
equivalent** — this study simply **could not distinguish them** on relevance.

### 17.2 The PKM did show a narrow advantage in avoiding redundant teaching

B recorded **0 redundant deliveries** where A recorded **2** (ordinals 29 and 59,
both `h_gardener_leaf_colour`). On the second half of the primary research
question — reducing redundant guidance — the PKM did exactly what it was built to
do, on the only two occasions in 72 scenarios where the opportunity arose.

### 17.3 The redundancy evidence is very sparse and must not be overstated

Two events out of 72. Teaching denominators of 6 (A), 4 (B) and 26 (C) across the
full set, and of 3, 2 and 18 on CORE. No significance test is applied and none
would be meaningful, in keeping with the frozen rule that no significance is
claimed from redundancy metrics with sparse denominators.

Two structural facts bound this finding further. **Only 2 of the 11 catalogue
hints can ever be redundant**, because only two teach a PKM concept, so the
catalogue offers very few opportunities for a redundancy difference to appear at
all, before any policy runs. And **Rule 3 — B's explicit redundancy-avoidance
rule — never fired**; both
avoidances came through the soft-preference rule instead. The mechanism actually
designed to prevent redundancy therefore **remains untested by this holdout**,
and B's redundancy result should be read as a favourable side effect of
preference ordering rather than as a validated mechanism.

### 17.4 The LLM selector did not significantly improve confirmatory relevance

C scored 33/48 against 32/48, a **2.1 percentage-point observed increase** — one
scenario — on 3 discordant pairs, `p = 1.000` unadjusted and Holm-adjusted, below
the sparse-data threshold. **No significant improvement in relevance is
demonstrated**, and the answer to the secondary research question on the primary
outcome is that this study **could not distinguish the LLM selector from the
deterministic rules**.

### 17.5 C showed a larger descriptive difference on action appropriateness and boundary states

The picture changes when the measure changes, and this is worth stating carefully
because it is the most interesting pattern in the data:

| Measure | A / B | C | Status |
|---|---|---|---|
| CORE `RelevantHintRate` | 32/48 | 33/48 | primary; non-significant |
| CORE `AppropriateActionRate` | 32/48 | 35/48 | secondary; `p = 0.375`, low-information |
| STRESS `RelevantHintRate` | 12/24 | 16/24 | secondary; `p = 0.125`, low-information |
| STRESS `AppropriateActionRate` | 12/24 | 21/24 | secondary descriptive; no frozen test |

The differences grow as the measure moves away from "did it deliver a
human-listed hint" and toward "was delivering anything the right call", and as
the scenarios move from ordinary states toward boundary states. **None of these
comparisons reaches significance, and the two largest are not confirmatory
evidence at all.** A defensible reading is that **C behaved more appropriately in
boundary states, particularly in choosing not to speak** — bounded by the fact
that STRESS was deliberately built from boundary bins and does not represent
ordinary prevalence.

### 17.6 C's distinctive capability is abstention

The single behavioural difference that separates C from both deterministic
policies is that **C can decline to speak and A and B cannot**. Every divergence
between `RelevantHintRate` and `AppropriateActionRate` in this study is an
abstention by C. C abstained 8 times, 7 of them on scenarios the human annotator
had labelled `NONE`, and once — ordinal 15 — where a valid hint existed and
silence was simply wrong.

Two qualifications keep this in proportion. All 8 abstentions were on **butler**
scenarios, so the observed abstention behaviour is concentrated in one NPC rather
than demonstrated across the game. And abstention is a **capability**, not an
unalloyed good: it is right on a `NONE` state and wrong on ordinal 15, and this
study saw both.

### 17.7 The primary metric deliberately cannot reward correct silence

`RelevantHintRate` treats every `SILENCE` as a relevance failure, including on
`NONE`-labelled scenarios. Under this definition, C's seven correct abstentions
score as seven failures.

This is a deliberate, preregistered property of the metric, with reasons recorded
before the v4 data existed (Sections 11.1 and 14.3). It is a
**measurement/design limitation**, and it is reported as one rather than resolved
retroactively. Amending the metric after seeing that it penalises exactly the
behaviour that distinguishes one condition would be precisely the kind of
post-hoc adjustment this protocol was built to prevent.

### 17.8 `AppropriateActionRate` captures the separate property

`AppropriateActionRate` was preregistered as a **secondary prospective** metric
before v4 was generated, exactly so that "was speaking the right call?" could be
measured without altering the primary definition or the closed v3 result. It
worked as intended: it is the only metric in the study that gives credit for
correct silence, and it is where C's largest observed differences appear.

Two properties keep it in its place. It is **secondary**, so it cannot carry a
confirmatory conclusion. And it is **structurally incapable of distinguishing A
from B**, since neither can abstain — on every A-versus-B comparison in this study
it returns exactly what `RelevantHintRate` returns.

### 17.9 The hint catalogue may limit measurable relevance gains

Hard eligibility yields at most three candidates, and often one or two: on CORE,
9 scenarios had 1 eligible hint, 24 had 2 and 15 had 3. A selector cannot express
a preference among options it does not have, and on a single-candidate scenario
every condition necessarily makes the same choice.

The human labels compound this. Where A and B did diverge — ordinals 29 and 59 —
**all three candidates were on the human list**, so no relevance difference was
possible however the selector chose. When most eligible options are both few and
jointly acceptable, selector intelligence has **limited opportunity to produce
different relevance outcomes**, and the large block of shared failure in Section
14.5 (the same 14 CORE scenarios defeated all three tested conditions) is the same
constraint seen from the other side. Neither observation licenses a claim about
policies that were not tested.

### 17.10 A and B are a strict refinement pair

B's Rule 4 returns **exactly what A-4 would have returned**. B can only differ
from A when an earlier rule fires, which happened on 9 of 72 scenarios and
changed the answer on 2. Large relevance differences between a policy and a
strict refinement of itself are **structurally unlikely** when the alternatives
the refinement reaches are also human-valid.

This is a property of the comparison design, and it was visible in advance rather
than discovered in the results — `heldout-v3` produced the same shape, with a
single A/B divergence in 48 scenarios. It is a reason to expect few discordant
pairs in the A-versus-B contrast, not a reason to discount that contrast after the
fact.

### 17.11 What player-state modelling appears more useful for

Taking the confirmatory and secondary evidence together, and staying inside what
each supports: under this catalogue and these policies, player-state modelling
appears **more useful for controlling redundancy and action appropriateness than
for raising broad relevance**. Relevance was decided within a two-scenario band on
CORE; redundancy and abstention were where the conditions actually differed in
observable behaviour.

The qualifier "under this catalogue and these policies" is doing real work: with
only 2 of 11 hints capable of redundancy, most scenarios offering 1–3 eligible
candidates, and B a strict refinement of A, the design constrained how large any
relevance difference could be.

### 17.12 No learning-outcome conclusion is permitted

Nothing in this study observed a player. No metric here measures understanding,
retention, engagement or performance, and no claim about learning outcomes is
made or supported.

`DEMONSTRATED` means only that the player passed the game's existing designated
comprehension check. It does **not** mean first-attempt correctness (retries are
unlimited), independent mastery (rules are revealed on failure), validated
learning (the checks are game gates, not instruments), retention (nothing
re-tests) or unassisted performance (no attempt count, timing or assistance is
recorded). Every redundancy result in this report inherits those limits: it
detects "this line re-teaches a concept the player has already passed the check
on", **not** "this player already understands this concept."

---

## 18. Limitations

**Sparse discordance and sample size.** The confirmatory stratum is **48
scenarios**. Discordant counts were 0, 3 and 3 on the primary family and 0, 5 and
5 on the secondary family — at or below the frozen sparse-data threshold in every
defined case. **The comparisons actually realized therefore had very little
capacity to resolve small differences**, and every non-significant result should
be read as *"this study could not distinguish these policies"* rather than as a
finding of no difference. No formal power analysis was performed (Section 19.4);
the limitation described here is the observed sparseness of the discordant pairs,
not a computed power figure.

**Catalogue and NPC scope.** Eleven hints and three NPCs, with at most three
hard-eligible candidates per scenario. Only 2 of the 11 hints can ever be
redundant. Two of the eleven (`h_gardener_no_evidence`, `h_mechanic_no_evidence`)
are unreachable for A by construction. Results are specific to this catalogue.

**State representation omits conversational history.** The frozen state model
records evidence, story flags and room/stage, but not what an NPC has already
said. The interaction-flag table declares three butler flags and **none for the
gardener or the mechanic**, so repeated-dialogue judgements cannot be made for two
of the three NPCs. **Scenarios 58 and 60 are `HIGH` ambiguity for exactly this
reason.**

**Single-annotator, researcher-led ground truth.** All labels come from one
annotator, who is the researcher. There is **no second annotator and therefore no
inter-rater agreement statistic**. Multi-valid relevance labelling is inherently
subjective: the rubric constrains it but does not make it reproducible by an
independent party, and several scenarios share an identical (NPC, evidence,
eligible-hints) shape while carrying different labels.

**One assistant-proposed adjudication.** **Scenario 72's label was proposed by
the assistant**, by applying the researcher's already-established rule (as used
for scenarios 67–70), and was then accepted into the frozen set. The 72
annotations **must not** be described as all independently originating with the
researcher.

**`DEMONSTRATED` is not mastery.** It means only that the player passed the
game's existing designated comprehension check; see Section 17.12. All redundancy
results inherit this limit.

**Condition C is not reproducible by regeneration.** `temperature`, `top_p`,
`top_k`, `max_tokens` and `seed` are **not controllable through this transport** —
the CLI exposes no flag for any of them, and they are recorded as `null` meaning
*not controllable*, not *defaulted to a chosen value*. **Determinism is not
claimed.** The frozen outputs are fully **auditable** — every raw response is
logged verbatim — but a rerun could differ, and the artifact could not be
reproduced by rerunning the model.

**One sample per scenario.** `samples_per_scenario` is 1. Nothing here
characterises C's run-to-run variability, and a single sample cannot separate a
policy tendency from a sampling outcome.

**Coverage comparison is structurally asymmetric.** A and B deliver on every
scenario because they have no silence branch; C's lower `Coverage` is the
arithmetic consequence of a capability the others lack. The three numbers are not
a quality ranking.

**STRESS is not representative prevalence.** STRESS was deliberately constructed
from eight boundary bins. A third of it is `NONE`-labelled, against roughly a
seventh of CORE. It cannot be used to estimate how often these situations arise
in real play.

**No learning or player-experience experiment.** No player was observed. No
learning, engagement, enjoyment or comprehension outcome was measured.

**One mechanism was not exercised.** B's Rule 3 never fired, so the explicit
redundancy-avoidance mechanism is untested by this holdout.

---

## 19. Threats to Validity

### 19.1 Construct validity — does the measurement match the question?

The primary metric **deliberately cannot reward correct silence**, so it does not
fully capture "good hinting behaviour" in the ordinary sense. This is a known,
preregistered gap, mitigated but not closed by the secondary metric.

Human relevance and non-redundancy are **different constructs that can disagree**,
and in this study they did: both redundant deliveries were also human-labelled
relevant. Neither metric alone measures the primary research question, which is
why both are reported.

`DEMONSTRATED` is a **proxy** for concept exposure, not a measure of
understanding. Redundancy is defined against that proxy.

### 19.2 Internal validity — could the result be an artifact of procedure?

The strongest protections in this study are here, and they are structural rather
than procedural promises.

- **Ground truth could not be influenced by results:** at annotation time **no v4
  condition output existed**, so contamination was impossible rather than merely
  prohibited.
- **Selectors could not be fitted to labels:** A's and B's sources hash to their
  v3 values, machine-checked at the start of every run.
- **The analysis could not be chosen to suit the results:** the metric
  definitions, the three preregistered comparisons, the exact-test implementation,
  the Holm requirement and the sparse-data rule were all committed at
  `heldout-v4-generation-pre-freeze`, before the scenarios existed.
- **C could not be re-rolled:** one inference per scenario, appended to a
  write-once log, with the harness refusing to restart over an existing log.
- **Scoring was independently recomputed** by a checker that does not import the
  metrics tool, and whose nine-mutation fault suite demonstrates the checks can
  fail.

Two residual internal threats remain, both disclosed rather than mitigated: the
**single annotator**, and the **one assistant-proposed label** (scenario 72).

### 19.3 External validity — how far do these results generalise?

Narrowly. One game, three NPCs, eleven hints, one annotator, one model, one
sample per scenario, and a state model that omits conversational history for two
of three NPCs. The CORE scenarios are drawn from a legally reachable state space
of 55,032 candidates and cover every reachable value of four structural features
per NPC, which supports generalisation **within this game's state space** — and
says nothing about other catalogues, other games or other models.

The 20-scenario development set remains **contaminated** and no figure from it
appears in this report.

### 19.4 Statistical conclusion validity — the dominant threat

This is the weakest link in the study, and it should be read as such.

Every defined comparison rests on 3–5 discordant scenarios. **Given the three
discordant CORE pairs actually observed, the realized A-versus-C and B-versus-C
comparisons had extremely limited inferential resolution; even a 3–0 split would
yield a two-sided exact p-value of 0.25.** The A-versus-B comparison has zero
discordant pairs and is undefined, carrying no information at all.

Two things must be kept apart here.

- **Realized discordance** is what the data turned out to contain: three
  discordant pairs on the primary comparison. This is an observed quantity, and it
  is what makes the reported p-values uninformative.
- **Prospective statistical power** is a property of the design *before* the data
  existed — how likely the study was to detect a difference of some size had one
  been present. **No formal power analysis was performed for this study**, at any
  stage, and none is reported. The freeze anticipated sparse discordance as a
  qualitative judgement (Section 12.3), but that judgement was never quantified.

Because of this distinction, the honest statement is *the comparisons that were
actually realized could not resolve a difference*, **not** *the design could never
have produced a significant result under any possible outcome*. Had the conditions
diverged much more widely than they did — had, say, twelve CORE scenarios been
discordant rather than three — the same 48-scenario design and the same exact test
could have produced a significant result. It did not, because the policies behaved
almost identically, not because significance was ruled out in advance.

The design was preregistered with the risk of sparse discordance visible; it is
not a post-hoc excuse. But the summary stands: **the realized confirmatory
analysis had very little capacity to detect anything**, and the absence of
significance here is closer to absence of evidence than to evidence of absence.
**No condition is described as equivalent to another on the strength of a
non-significant result.**

Holm adjustment was applied as described in Section 13.4. It changes no
conclusion: nothing was significant before adjustment.

### 19.5 A threat that did not materialise

`StateViolationRate` was **0 across all 208 delivered hints**, including all 64
delivered by the language model. The risk that a model-driven selector would
deliver a hint whose hard prerequisites were unmet — the single failure mode the
protocol was most concerned to prevent — **did not occur**, under a scoring path
that re-checked prerequisites after the model's output and was verified
independently of the harness that produced it.

---

## 20. Future Work

All items below are **prospective**. None is a post-hoc adjustment to the present
evaluation, and none should be implemented by modifying the frozen v4 artifacts
or by re-scoring v4 under a changed rule.

**Represent NPC interaction history explicitly.** The clearest single gap. Adding
gardener and mechanic interaction flags comparable to the three the butler already
has would let both annotators and selectors reason about whether a line has been
heard before — the exact uncertainty that made scenarios 58 and 60 `HIGH`
ambiguity. This is a change to the **game's state model**, and any selector
consuming it must be designed before the next holdout is generated.

**Expand the catalogue with genuinely competing hint types.** With 1–3 eligible
candidates per scenario and only 2 of 11 hints capable of redundancy, the present
catalogue constrains how large a measurable difference is likely to be. A
catalogue with more
hints per NPC, more hints that teach a PKM concept, and more scenarios where
plausible options genuinely conflict would give selector intelligence room to
show an effect. The correct response to A and B scoring identically is to build a
**harder and more discriminating catalogue**, not to reinterpret the current
evaluation.

**Design future selectors before generating the next holdout.** The ordering that
gave this study its force — plan, freeze, generate, annotate, freeze, run once —
should be preserved. Any new selector must be specified and frozen **before** the
next scenario set exists, and must never be tuned against labels already known.

**Use multiple independent annotators and report agreement.** At least two
annotators labelling independently under the frozen rubric, with a reported
agreement statistic appropriate to multi-valid set labels. This is the main
mitigation for the single-annotator limitation, and it would also give an
empirical basis for the ambiguity levels, which are currently one annotator's
self-report.

**Size the next study from an expected discordance rate.** A confirmatory
comparison that realizes only three discordant pairs cannot resolve a small
difference, whatever the design intended. This study performed no formal power
analysis; a future one should. It should also size its confirmatory stratum from
an **expected discordance rate** — which the present results now give an empirical
estimate of — rather than from a round number of scenarios, since it is the
discordant pairs, not the scenario count, that carry the paired evidence.

**Evaluate actual player interactions.** Everything here is offline scoring
against frozen states. Observing hints delivered in live sessions would test
whether offline relevance corresponds to anything a player notices, and would be
the first evidence that these metrics track something outside the evaluation
harness.

**Collect attempt, assistance and timing data before making any learning claim.**
The `ASSISTED` state exists in the PKM enum and is unreachable precisely because
the game records no assistance signal. Recording attempt counts, help usage and
timing would make that state reachable, would let `DEMONSTRATED` be qualified by
how it was reached, and is a **precondition** for any future study that wants to
say anything about learning.

**Study stochastic robustness under a separate preregistration.** If C's
run-to-run stability matters, it should be measured by a **separately
preregistered replication** drawing multiple samples per scenario, and ideally
more than one model. That is a different study with a different question; it must
not be conducted by rerunning the frozen v4 Condition C and comparing against the
present numbers.

**Keep v4 frozen.** The `heldout-v4` scenarios, labels, raw outputs, metrics and
tags are closed. Future work should generate a **new** holdout under the same
freeze discipline, with the v4 fingerprints added to the exclusion set exactly as
v2 and v3 were added for v4. No future result should be obtained by touching these
artifacts.

---

## 21. Conclusion

This study compared three NPC hint-selection policies on 72 frozen scenarios
under a preregistered protocol, with human relevance labels fixed before any
condition output existed. The conclusions below are stated at the strength the
evidence actually supports, which in several places is weaker than the design
had hoped for.

### 21.1 Primary research question

> *Can a unified Player Knowledge Model improve NPC hint relevance and reduce
> redundant guidance in an educational detective game?*

**On relevance, the answer in this study is no.** Under the tested deterministic
refinement, adding the PKM **did not increase** confirmatory relevance: Condition
A scored **32/48** on CORE `RelevantHintRate` and Condition B scored **32/48**.
The two policies matched not merely in total but scenario by scenario, which is
why the paired comparison has **zero discordant pairs** and no exact p-value at
all.

That result must be read carefully in both directions. It is **not** evidence
that the PKM made things worse, and it is **not** evidence that A and B are the
same policy. **A and B are not described as equivalent.** A test with no
discordant pairs carries no information, so the defensible statement is that
**this study could not distinguish them on the primary outcome** — and Section
17.10 explains the structural reason: B is a strict refinement of A whose earlier
rules fired on 9 of 72 scenarios and changed the selected hint on only 2, and on
both of those the alternative was also human-valid.

**On redundancy, the answer is a narrow yes.** Across all 72 scenarios, A
delivered **two redundant teaching hints** — both `h_gardener_leaf_colour`,
re-teaching `reflection` to a player who had already passed the game's
comprehension check for it — and B delivered **none**. Both of A's redundant
hints were also labelled *relevant* by the annotator, which is precisely the point
of measuring the two properties separately.

Three qualifications keep this from being a strong result:

1. **It is sparse.** Two events in 72 scenarios. A delivered a teaching hint only
   6 times in total and B only 4; `RedundantWhenTeachable` of 2/6 versus 0/4 is a
   difference of two events on single-digit denominators, and **no significance is
   claimed from it**, as the frozen protocol requires.
2. **The mechanism designed for the job never ran.** B's Rule 3 — the explicit
   redundancy fallback, the component actually written to prevent re-teaching —
   **never fired on any of the 72 scenarios**. The rule-firing distribution was
   Rule 4 on 63 scenarios and Rule 2 on 9, with Rule 3 at zero. Both observed
   avoidances came through **Rule 2, the soft-preference behaviour**, which
   down-ranks a hint teaching an already-`DEMONSTRATED` concept without ever
   treating redundancy as a hard condition.
3. **Therefore the specific redundancy mechanism was not validated.** What the
   experiment provides is a **narrow observation that a PKM-aware preference
   ordering avoided the two redundant selections a PKM-blind policy made**. It is
   not evidence that the redundancy fallback works, because that fallback was
   never exercised.

### 21.2 Secondary research question

> *Does an LLM-based hint selector provide meaningful advantages over
> deterministic adaptive rules?*

**On the primary outcome, no advantage was established.** Condition C scored
**33/48** on CORE `RelevantHintRate` against **32/48** for A and B — a single
additional scenario, 2.1 percentage points. The paired evidence is **3 discordant
pairs** for A-versus-C and **3** for B-versus-C, with a two-sided exact McNemar
**p = 1.000** in both cases, unchanged by the preregistered Holm adjustment. Both
comparisons fall below the frozen sparse-data threshold and are explicitly
low-information. **No statistically supported confirmatory improvement in
relevance was established.**

**C's more distinctive observed behaviour was not relevance but action
appropriateness — deciding whether to speak at all.** On the secondary metric,
CORE `AppropriateActionRate` was **35/48** for C against **32/48** for A and B
(5 discordant pairs, `p = 0.375`, still low-information). On STRESS the
descriptive gap is much larger: **21/24** against **12/24**. STRESS is
**secondary robustness and boundary evidence by preregistration**, deliberately
sampled at the edges of the state space, and nothing in it is confirmatory or
representative of ordinary play.

The concrete behaviour behind those numbers: of the 15 scenarios the annotator
labelled `NONE` — no hint in the catalogue is relevant here — **C abstained
correctly on 7**, while A and B delivered a hint on all 15 because neither is
capable of silence. **C also abstained once when it should have spoken**
(scenario 15, where `h_butler_stain` was the sole eligible and sole valid hint).
Seven correct abstentions against one false one, on a capability the other two
conditions do not have at all.

C's abstentions were genuine decisions, not artefacts: the run log records
`fallback_used: false` on all 72 scenarios, so none of the eight silences arose
from a schema-retry falling back to silence.

**C is not described as having "won", as "better overall", or as proven
superior.** On the primary confirmatory outcome the study could not distinguish
it from the deterministic rules. Its observed differences lie on a secondary
metric and in a secondary stratum, and one of them — the abstention advantage —
is concentrated almost entirely in butler scenarios, which is where most of the
`NONE` labels happen to sit.

### 21.3 Synthesis

The unified Player Knowledge Model did not improve overall confirmatory hint
relevance under the deterministic refinement tested here, though the PKM-aware
policy did avoid the small number of redundant teaching selections that the
PKM-blind baseline made. The LLM-based selector produced only a small,
statistically unsupported increase in CORE relevance, while showing larger
descriptive differences in action appropriateness and in boundary-state
abstention. Taken together, and within the limits of this catalogue and these
policy designs, player-state modelling appears more informative for governing
**what not to repeat and when not to speak** than for substantially raising broad
hint relevance.

That is a narrower conclusion than the study set out to test, and it is the one
the data supports.

---

## 22. AI Assistance and Tooling Disclosure

This section is deliberately more detailed than disclosure norms require. The
project was built with substantial AI assistance, and a reader cannot evaluate
the work honestly without knowing where that assistance began and ended.

### 22.1 What the researcher did

The researcher **designed the study**: the research questions, the game and its
content, the choice of conditions, the definition of the metrics, the decision
that `SILENCE` is never relevant under the primary metric, the decision to add
`AppropriateActionRate` as a prospective secondary, the strata design, the freeze
discipline and its ordering, the interpretation criteria, and the standard of
evidence applied throughout this report.

The researcher **led the human annotation**. Scenarios were labelled one at a
time against neutral state summaries, without any selector output in view. The
researcher made the labelling decisions, set the ambiguity levels, wrote the
annotator notes, and **accepted the final frozen label set** as ground truth.

The researcher **inspected and directed the engineering**. Where an agent's
output was wrong, incomplete, or made a claim the researcher did not accept, it
was sent back. Several of the tightest constraints in this project — no API
fallback, no rerunning Condition C, no tuning against known labels, no composite
score — were researcher-imposed and repeatedly re-imposed.

### 22.2 What AI coding agents did

AI coding agents contributed **substantially** to this project. Their
contributions include, and are not limited to: implementing game systems and the
Player Knowledge Model; implementing Conditions A, B and C; writing the
generation, materialization, evaluation, metrics and manifest tools; writing the
independent integrity checkers and their fault-injection suites; auditing frozen
artifacts and verifying hashes; preparing neutral scenario summaries for
annotation; performing the statistical computation; and **drafting this report**,
including this sentence.

Development typically followed a loop: **the researcher specified requirements →
an agent implemented them → the researcher inspected the behaviour or the results
and iterated.** Review was directed at behaviour, outputs and claims.

**This report therefore does not claim that every source line was manually
authored, line-by-line reviewed, or independently audited by the researcher.** A
project of roughly 51,000 lines of GDScript plus its evaluation tooling was not
hand-verified in full by one person, and asserting otherwise would be false. What
*was* independently checked is narrower and more specific: the frozen artifacts
were re-verified by checkers that do not import the tools that produced them, and
whose fault-injection suites demonstrate that the checks can fail (Section 19.2).

No precise human-versus-AI split is offered, because no meaningful one exists.
Attaching a percentage to a collaboration of this kind would be an invented
number, and this report does not invent numbers.

### 22.3 The one label that was not independently the researcher's

**Scenario 72's final label was an assistant-proposed adjudication.** It was
proposed by applying a rule the researcher had already established and applied to
scenarios 67–70, and the researcher **accepted it into the frozen ground truth**.

It is therefore inaccurate to describe all 72 annotations as independently
originated by the researcher, and this report does not describe them that way.
The same disclosure is recorded inside the frozen evaluation manifest, so it
travels with the artifacts rather than only with the prose.

### 22.4 Condition C is an experimental variable, not assistance

**Condition C used `claude-opus-5` as the experimental hint selector.** This is
categorically different from the AI assistance described above. In Condition C the
model is **an object of study** — one of the three policies being measured — not a
tool used to build or analyse the study. Its inputs were restricted by allowlist
to six state fields, it could only return an identifier from the eleven-hint
catalogue or abstain, and its output was scored by the same frozen scorer applied
to A and B.

### 22.5 Separation between the assistance and the measurement

Three separations matter, and all three held:

- **No AI selector output was visible when the v4 human labels were frozen.** At
  annotation time no v4 condition had been run. Both frozen files record
  `selector_was_run: false`, and the annotation freeze predates the evaluation
  commit. Contamination of the ground truth by condition output was structurally
  impossible, not merely forbidden.
- **No v4 condition was rerun or tuned against the frozen labels.** Conditions A
  and B hash to their pre-existing v3 values, machine-checked at the start of
  every run. Condition C was invoked **exactly once per scenario** against a
  write-once log.
- **The report was drafted after the results were frozen and did not change
  them.** Every figure in this document is read from a frozen artifact. Writing
  this report modified no annotation, selector, metric, dataset, prompt or frozen
  artifact.

---

## 23. Reproducibility and Artifact Provenance

### 23.1 Provenance table

All hashes are SHA-256 over file bytes. All commits and tag objects are from this
repository. Every value in this table was re-verified against the files on disk
while this report was written.

**Stage 1 — specification, frozen before the scenarios existed**

| Item | Value |
|---|---|
| Generation spec | `docs/HELDOUT_V4_GENERATION_SPEC.md` |
| Generation spec SHA-256 | `d7fecb28254b06f998a67615cb0dc77ddcf3dbd2ed4655d7cbeb74910b8feda4` |
| Spec tag | `heldout-v4-generation-pre-freeze` |
| Spec tag object | `7b99bf7b9096e5af08985c0c6c7fe709c0b94eda` |
| Spec commit | `901315b096ce1b1332c97206af7da7c1a4f175cf` |
| Condition C spec | `docs/CONDITION_C_SPEC.md`, SHA-256 `39dc32e6c1182ed515470fcce94713875913932d5a2ee4db4d04beb79bc477eb` |
| Condition C freeze tag | `condition-c-pre-v4-freeze-v2`, tag object `3adbbd81a353a44b2ed31885da2dea260beb6723`, commit `6d2f6c4a37b7f01f72e4b5ffdd60cf841378b18e` |

**Stage 2 — scenario generation, before annotation**

| Item | Value |
|---|---|
| Scenario artifact | `docs/heldout/heldout_v4_scenarios.json` |
| SHA-256 | `1bb1535f64168fe4c5e6fe767aabe841761d5bc248a2e17234d29942c3a0a23d` |
| State aggregate SHA-256 | `03d2c7443932da408eda1774b404207224c4e729dc761d6b8d4f44206ec769f2` |
| Exclusion digest | `27ae5ddb750dec4c04ee3338f239ef44cd242b5f919747356c1297706eb32ecf` (96 excluded fingerprints) |
| Pre-annotation commit | `3cf6e83610a7939bec91d93155242aa4505b5379` |
| Pre-annotation tag | `heldout-v4-pre-annotation` |
| Pre-annotation tag object | `5038e1ba29a393d6a488945441c3858d7bc9dc40` |
| Record in file | `annotations_present: false`, `selector_was_run: false` |

**Stage 3 — human annotation freeze, before any condition was run**

| Item | Value |
|---|---|
| Annotated artifact | `docs/heldout/heldout_v4_annotated.json` |
| SHA-256 | `cd8d9e06d9c2bfd0035e19ec6962af7c6ac377693b17c5d410d9037a9b55b13c` |
| Annotation-only SHA-256 | `29a08dc05593366b77f77b745d33af31b8cf191c939e62cbc394ade0ecc858b2` |
| State-only content SHA-256 | `d9289573df1fd90107ac9043318b506a603aef790228949af3721397f857621a` |
| State aggregate SHA-256 | `03d2c7443932da408eda1774b404207224c4e729dc761d6b8d4f44206ec769f2` *(unchanged from Stage 2)* |
| Post-annotation commit | `e43bb3651b9bd8e2dbd77b73ec5d64ec8bb4fdbf` |
| Post-annotation tag | `heldout-v4-post-annotation` |
| Post-annotation tag object | `808147e4cfb5f8d9dde466bef68f8aca8931bd29` |

The annotated file is an **annotated copy**. The pre-annotation file was not
modified and remains byte-identical at `1bb1535f…`, which is why the state
aggregate is the same in both and why the state set stays verifiable without
reference to the labels.

**Stage 4 — evaluation, run once**

| Item | Value |
|---|---|
| Evaluation commit | `1df684e94d6c456731ae1b62721e4dac3bb43cb2` |
| Evaluation tag | `heldout-v4-evaluation` |
| Evaluation tag object | `3d1d295b320c44c4144af41d31427c6f2d56ebe2` |
| A/B raw output | `docs/heldout/heldout_v4_ab_raw.json` — `1a78e1899481c096a441ffed2712b19c1d47cde4bcd55294597519e006d58b77` |
| C raw output | `docs/heldout/heldout_v4_c_raw.json` — `052e25f8c48186ae174cd1546c8ec21537cf0cbb3f5bbaa0740b0fcaae964c42` |
| C append-only run log | `docs/heldout/heldout_v4_c_run.jsonl` — `048ac67edab10cc51b5a22842dccfc3aae6386c99d7b1ca8cdee2f1a76924741` |
| Per-scenario table | `docs/heldout/heldout_v4_evaluation_table.json` — `d72f1ede9651f290ae0c3f1a54ec2fd4dbb20e09b4c96a520d95a6ad6f3aebec` |
| Metrics and tests | `docs/heldout/heldout_v4_metrics.json` — `66d4e62a17bb2fa06d943c1cc32b254b52e9001bdad053d6b6362fe930f816c3` |
| Evaluation manifest | `docs/heldout_v4_evaluation_manifest.json` — `c04ace32d588972051ef16cd5e180ef55cdf9fc893403c2085c8f91997d811f7` |

**Selector and tooling sources at the evaluation commit**

| File | SHA-256 |
|---|---|
| `scripts/player_knowledge_model.gd` | `55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac` |
| `scripts/adaptive_hint_data.gd` (shared 11-hint catalogue) | `a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036` |
| `scripts/adaptive_hint_selector.gd` (Conditions A and B) | `c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2` |
| `scripts/condition_c_selector.gd` | `f2cab2d0d3c9bb204724bd9ffe94301744fc81eff77bf0c3c6752279208f7e2d` |
| `scripts/condition_c_client.gd` | `d9071a9a8321f777a05c4c3c309f7b2ab244d90f74a55ec8d08f1a586bb5b107` |
| `prompts/condition_c_selector_v1.txt` | `c4848c52329d625efef4b4cd2b237787d02c5e2e1e015cc195aa6ff3976a9d93` |
| `config/condition_c_model_v2.json` | `9889a63f56b7d0e8416217aed106948274ed73558039201b32b81380c256be1e` |
| `tools/condition_c_claude_invoke.sh` | `c8ab07a1bec297adab89fc159273a766f1987efad73121cfe0f2d6b48af7229e` |
| `tools/mcnemar_exact.py` | `c768ec5e50e07e7c595ed703957f173d518b592235fade821bd0815011958346` |
| `tools/run_heldout_v4_ab_evaluation.gd` | `30935041e6eae79e2c5453de82e2c7119947a403518dc06080c47c767bb9a032` |
| `tools/run_heldout_v4_c_evaluation.gd` | `66ab97cb27fbaae3f29d342adfb3e3dbf77bb73f814d175240ec2f840ddd8d78` |
| `tools/generate_heldout_v4.py` | `0afcbaa624b8c6eea33beab9beda433ce2958fbf1ba5858ed9f9ae7124cbab10` |
| `tools/materialize_heldout_v4_annotations.py` | `d341b28445961af83a6ad96f35f2e33378811aaee95b7ebba59fd4d387fb5617` |
| `tools/check_heldout_v4_evaluation_integrity.py` | `f9fb3a027686e87850d7ce60ba4eb6a87402920f4648974ec47a1315d50efdc8` |
| `tools/write_heldout_v4_evaluation_manifest.py` | `f0c31e0227114d0954ffe049005e31bbd9a4dff274f81c23b4b2a36d372a6b61` |
| Engine | `Godot Engine v4.7.stable.official.5b4e0cb0f` |

**Protocol document.** `docs/EVALUATION_PROTOCOL.md` hashes to
`1d1690c8bc6a5347b9a045aa7c2b54d05b924086c378100ac978c10e9c3a91b1` at the
generation and pre-annotation tags, and to
`ea2bb851d1a6268f7f9d27966da3819b6c6e3d993390b509c29f94af0676dc86` at the
post-annotation and evaluation tags. The difference is an **append only**: §12.10,
the annotation freeze record. Lines 1–955 are byte-identical across all four tags,
so **every preregistered analysis rule — the metric definitions, the three
comparisons, the exact test, the Holm requirement and the sparse-data rule — is
unchanged from before the scenarios existed through to the evaluation.**

### 23.2 Condition C run facts

| Property | Value |
|---|---|
| Model requested | `claude-opus-5` |
| Model resolved | `claude-opus-5` on 72 of 72 scenarios |
| Scenarios completed | 72 / 72 |
| Transport invocations | **exactly one per scenario** (72 total) |
| Schema retries | **0** — `retry_count` is 0 on every record |
| Schema-retry fallbacks to silence | **0** — `fallback_used` is false on every record |
| Transport failures | **0** — no backoff delay was ever applied |
| Run flags | `one_shot: true`, `complete: true`, `aborted: false`, `resumed: false` |
| Run log | 72 lines, append-only, write-once |
| Manual corrections to model output | **none** |
| Samples per scenario | 1 |
| `temperature` / `max_tokens` | `null` — not controllable through this transport |

**Determinism is not claimed and must not be claimed.** Condition C ran through
an isolated company-managed Claude Code transport in which `temperature`,
`top_p`, `top_k`, `max_tokens` and `seed` are **not controllable**. The frozen
output is fully **auditable** — every prompt, every response and every resolved
model name is recorded — but it is **not reproducible by regeneration**. Re-running
the model on these scenarios would not be expected to reproduce these selections,
and any such rerun would be a *new* experiment, not a replication of this one. The
frozen artifact records this in its own provenance block:
`"determinism": "NOT claimed; sampling parameters are not controllable through
this transport"`.

### 23.3 Disclosed engineering amendments

Two engineering amendments were made during the project and are disclosed here
rather than buried. **Neither altered any frozen scenario, human label, selector
decision or observed result.**

**1. Pre-evaluation checker allowlist amendment.** The spec-conformance checker
`tools/check_heldout_v4_spec.py` carried an allowlist of expected v4 artifact
filenames that **predated the annotation step** in the protocol's own order of
operations. When the protocol-mandated annotated copy was produced, the checker
would have flagged `heldout_v4_annotated.json` as an unexpected file. The
allowlist was amended to include it. This happened **before the evaluation**. The
substantive guard the check exists to enforce was not weakened: the checker still
asserts against `heldout_v4_scenarios.json` specifically that it records
`annotations_present: false` and carries no label on any scenario, and that it
hashes to the value its own generation audit pinned.

**2. Unused transport-backoff wrapper amendment.** `config/condition_c_model_v2.json`
declares `transport_retry.backoff_seconds: [2, 8]`, but the frozen selector counts
transport retries without sleeping between them. The delay was supplied by a
composition wrapper in the runner rather than by editing the frozen selector. It
changed no retry count, no retry budget and no abort condition. **It was never
exercised**: there were zero transport failures across all 72 scenarios, so no
backoff delay was ever applied. It is recorded in the frozen C transport manifest.

Both amendments are also recorded in the frozen evaluation manifest's
`limitations` block, so the disclosure travels with the artifacts.

### 23.4 What an independent reader can check

Without rerunning any experiment, a reader with this repository can verify:

- every artifact hash in Section 23.1, with `shasum -a 256`;
- that the tags resolve to the commits listed, with `git rev-parse`;
- that the pre-annotation scenario file is byte-identical to its frozen hash and
  still records `annotations_present: false` and `selector_was_run: false`;
- that `tools/materialize_heldout_v4_annotations.py` regenerates the annotated
  file byte-for-byte and refuses to run against a modified source;
- that `tools/check_heldout_v4_evaluation_integrity.py` recomputes every metric
  and every McNemar test from the raw outputs without importing the metrics tool,
  and that its nine-mutation fault suite causes it to fail as designed;
- that every Holm value in this report is the deterministic family-of-three
  transform of the exact p-values in `heldout_v4_metrics.json`;
- that the exact-test implementation in `tools/mcnemar_exact.py` was committed
  before any v4 data existed.

What cannot be verified by re-execution is Condition C's model output, for the
reason given in Section 23.2. It can be audited, not regenerated.

---

## 24. Claims Supported by the Data

Each item below is a statement this study's frozen artifacts support, stated at
the strength they support it.

1. **A and B had identical CORE `RelevantHintRate` in this study** — 32/48 each,
   and identical scenario by scenario, giving zero discordant pairs.
2. **Adding the PKM did not increase confirmatory relevance under the tested
   deterministic selector.** B scored no higher than A on the primary outcome.
3. **B produced no redundant delivered hints while A produced two.** Across all
   72 scenarios: A 2/72, B 0/72. Both of A's redundant hints were also labelled
   relevant by the annotator.
4. **A and B differed in action on only 2 of 72 scenarios** (ordinals 29 and 59),
   and on both, every eligible candidate was on the human valid list.
5. **B's explicit redundancy fallback (Rule 3) never fired.** The two avoidances
   arose through Rule 2 soft-preference behaviour.
6. **C had a slightly higher observed CORE `RelevantHintRate`** — 33/48 versus
   32/48 — **without a statistically supported paired difference** (3 discordant
   pairs, exact two-sided `p = 1.000`).
7. **C had a higher observed CORE `AppropriateActionRate`** — 35/48 versus 32/48
   — on 5 discordant pairs, `p = 0.375`, which is below the frozen sparse-data
   threshold and supports no significance claim. **The A-versus-B result on this
   metric is not independent supporting evidence:** because neither A nor B can
   abstain, `AppropriateActionRate` and `RelevantHintRate` are the same quantity
   computed twice for those two conditions, so their matching 32/48 restates
   claim 1 rather than corroborating it (Sections 14.2 and 17.8).
8. **C correctly abstained on seven `NONE` scenarios and falsely abstained once.**
   Of 15 `NONE`-labelled scenarios, C was silent on 7; it was also silent once
   (scenario 15) where a valid hint existed. A and B abstained on none of the 15,
   because neither can.
9. **C's abstentions were genuine model decisions.** `fallback_used` is false on
   all 72 records, so none of the eight silences came from schema-retry
   exhaustion.
10. **C had zero state violations.** Across 64 delivered hints, every one was
    admissible in the state it was delivered into. Across all three conditions,
    `StateViolationRate` was 0 for all 208 delivered hints.
11. **C showed larger descriptive `AppropriateActionRate` differences on STRESS**
    — 21/24 versus 12/24 — in a stratum that is secondary and boundary-sampled by
    preregistration.
12. **Relevance and redundancy captured distinct properties.** A hint can be
    human-relevant and simultaneously redundant; scenarios 29 and 59 are worked
    examples. The labels were not rewritten to remove that tension.
13. **All three tested conditions failed on the same 14 CORE scenarios and the
    same 8 STRESS scenarios.** This is an observation about these three policies.
14. **The analysis rules preceded the data.** The metric definitions, the three
    comparisons, the exact test, the Holm requirement and the sparse-data rule
    were all frozen before the scenarios existed, and the protocol's first 955
    lines are byte-identical across all four freeze tags.
15. **The human labels could not have been influenced by condition output**,
    because no condition had been run when they were frozen.

---

## 25. Claims Not Supported by the Data

Each item below is a claim this study **does not** support. Several are claims a
casual reader might expect a report like this to make.

1. **"PKM significantly improves hint relevance."** Not supported. B matched A
   exactly on the primary outcome (32/48 versus 32/48), and the comparison has no
   discordant pairs and no p-value.
2. **"A and B are equivalent."** Not supported. A comparison with zero discordant
   pairs carries no information. Failing to find a difference is not finding
   sameness, and this report never describes them as equivalent.
3. **"C significantly improves CORE relevance."** Not supported. One scenario of
   observed difference, 3 discordant pairs, exact `p = 1.000`.
4. **"C is better overall."** Not supported. C's observed advantages are on a
   secondary metric and in a secondary stratum; it also had lower coverage
   (64/72), one false abstention, and no significant advantage on the primary
   confirmatory outcome.
5. **"LLM selectors are generally superior to deterministic rules."** Not
   supported. One model, one prompt, one sample per scenario, one game, eleven
   hints, three NPCs. Nothing here generalises to LLM selectors as a class.
6. **"The game improves learning."** Not supported. **No learning outcome was
   measured at any point in this study.** No pre-test, no post-test, no retention
   measure, no transfer measure, no player was observed. Hint relevance is a
   property of a selection, not of a learner.
7. **"`DEMONSTRATED` means mastery or retention."** Not supported. `DEMONSTRATED`
   means exactly one thing: the player passed the game's existing designated
   comprehension check for that concept. It is explicitly **not** first-attempt
   correctness, independent mastery, validated learning, retention, or unassisted
   performance.
8. **"The STRESS results represent normal gameplay prevalence."** Not supported.
   STRESS was deliberately sampled at boundaries — a third of it is `NONE`-labelled
   against 7 of 48 in CORE — precisely because those states are rare in ordinary
   play.
9. **"The Condition C result is deterministically reproducible by rerunning the
   model."** Not supported, and explicitly disclaimed. Sampling parameters are not
   controllable through this transport. The output is auditable, not
   regenerable.
10. **"The explicit Rule 3 redundancy mechanism has been empirically validated."**
    Not supported. Rule 3 never fired on any of the 72 scenarios. The mechanism
    designed to prevent redundancy was never exercised by this holdout.
11. **"34/48 on CORE or 16/24 on STRESS is a ceiling."** Not supported. Those
    numbers arise from scenarios on which the three *tested* policies happened to
    fail together. Shared observed failure does not prove that no alternative
    selector could have chosen a human-valid hint on those scenarios.
12. **"The design could never have produced a significant result."** Not
    supported. The realized comparisons had very limited resolution because only
    three discordant pairs occurred, but a larger realized discordance under the
    same design could have produced one. No formal power analysis was performed.
13. **"C never re-teaches."** Not supported as a property of the model. C
    delivered 26 teaching hints across all 72 scenarios with zero redundant among
    them, but that is an observation over 26 events under one sample, not a
    demonstrated guarantee.

---

## 26. Claims Where Evidence Is Too Weak for a Strong Statement

These are open questions rather than negative findings. In each case the study
points somewhere, and the pointer is too weak to lean on.

**Whether the small redundancy difference generalises.** The entire redundancy
result rests on **two events in 72 scenarios**, both involving the same hint
(`h_gardener_leaf_colour`) and the same concept (`reflection`). Only 2 of the 11
hints in the catalogue can ever be redundant, so the measurement had very few
opportunities to fire at all. A catalogue with more teaching hints might show a
larger difference, a smaller one, or none. Two events cannot distinguish these.

**Whether C's abstention advantage generalises beyond butler-heavy `NONE`
states.** C's seven correct abstentions were **all butler scenarios**, and 10 of
the 15 `NONE` labels are butler scenarios. The butler is also the only NPC with
interaction-history flags in the state model. It is genuinely unclear whether C
learned to recognise "there is nothing useful to say here" in general, or whether
it learned something narrower about butler states — and this study cannot tell
those apart. C's single false abstention was also a butler scenario.

**Whether C's STRESS advantage would replicate.** STRESS is 24 scenarios, three
per NPC in each of eight boundary bins, with 4 discordant pairs on the relevance
comparison. It is secondary by preregistration and boundary-sampled by
construction. The 21/24 versus 12/24 `AppropriateActionRate` gap is the largest
observed difference anywhere in this study and has **no frozen inferential test at
all**. It is a striking descriptive observation and nothing more.

**Whether a larger catalogue would produce larger A/B differences.** B is a strict
refinement of A: its Rule 4 returns exactly what A would have returned, so the two
can only diverge when an earlier rule fires. That happened on 9 of 72 scenarios
and changed the selection on 2. With 1–3 hard-eligible candidates per scenario and
frequent multi-valid labels, the design gave the refinement very little room to
express itself. Whether a richer catalogue would reveal a real difference, or
confirm there is none, is untested.

**Whether multiple annotators would preserve the same relevance labels.** There
was **one annotator**. Two scenarios were self-rated `HIGH` ambiguity and eight
`MEDIUM`, but those levels are the same annotator's self-report, not an inter-rater
statistic. No agreement coefficient exists for this dataset. Since relevance is
the primary outcome and its ground truth is one person's judgement, this is the
single assumption on which the most depends and for which there is the least
evidence. One label (scenario 72) was additionally an assistant-proposed
adjudication that the researcher accepted.

**Whether different LLMs or different samples would preserve C's pattern.** One
model, one prompt template, **one sample per scenario**, with sampling parameters
outside the experimenter's control. C's selection profile differs strikingly from
A's and B's — it chose `h_gardener_leaf_colour` 16 times where A chose it 6, and
delivered 26 teaching hints against A's 6 — but whether that reflects a stable
disposition of this model, an artefact of this prompt, or ordinary sampling
variation is **completely untested**. Establishing it would require a separately
preregistered replication with multiple samples and more than one model, not a
rerun of the frozen v4 Condition C.

**Whether offline relevance corresponds to anything a player experiences.** Every
figure in this report comes from offline scoring against frozen states. No player
saw any of these hints. Whether a hint scored relevant here would be noticed,
understood, or useful in live play is outside what this study measured.

*[RELATED WORK CITATION NEEDED] — the placeholders in Section 3.4 remain
unresolved. No external literature review was performed for this study, and no
source is cited anywhere in this report. Any claim of novelty, or any comparison
to prior adaptive-hinting, learner-modelling or LLM-selector results, requires
that review first.*

---
