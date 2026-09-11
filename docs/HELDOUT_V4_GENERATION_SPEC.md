# Held-out v4 — generation and analysis specification

**Status: FROZEN before any v4 scenario exists.**

This document is written at a point where the v4 benchmark has not been
generated. No v4 scenario artifact exists on disk, no generator has been run, no
condition has been executed against v4, and no human has annotated a v4 state.
That ordering is the whole point: every degree of freedom that could be used to
shape the benchmark toward a result is spent here, in public, before any result
is visible.

Everything below is either a procedure that a program will later follow without
discretion, or a measurement of the game's legal state space that is true
independently of which states v4 ends up containing.

**This document contains no v4 scenarios.** The statistics it reports describe
the candidate pool — the set of all legal states the game can reach — not a
selection from it.

---

## 1. Scope

### 1.1 What v4 is for

v4 is a prospective held-out benchmark for the final A/B/C comparison:

- **Primary research question.** Can a unified Player Knowledge Model improve
  NPC hint relevance and reduce redundant guidance in an educational detective
  game?
- **Secondary.** Does an LLM-based hint selector provide meaningful advantages
  over deterministic adaptive rules?

The benchmark must not be constructed to make any condition win. Section 5.1
lists the features selection is allowed to see, and the list is deliberately
short: it contains nothing that any selector produces, and nothing a human has
judged.

### 1.2 What this document freezes

- the candidate-state generation procedure (§3)
- state identity and the contamination exclusion set (§4)
- the structural feature encoding, including weights (§5)
- the order in which the two strata are selected (§6)
- STRESS selection (§7)
- CORE selection (§8)
- deterministic tie-breaking (§9)
- scenario identifiers, ordering and artifact schema (§10, §11)
- chronology validation (§12)
- the canonical PKM requirement (§13)
- the generator's integrity constraints (§14)
- the order of all future operations (§15)
- the statistical analysis plan (§16)

### 1.3 What this document does not do

It does not generate v4. It does not run Condition A, B or C. It does not call a
model. It does not read, and did not read, any v3 human annotation label or any
v3 A/B result row.

The v3 experiment is closed and immutable. Nothing here modifies it, and §16.6
explains why v3 is not recomputed under any metric introduced below.

---

## 2. Prior art this reuses

v4 is not a new pipeline. It is a new *selection* from the same legal state space
that v3 drew from, using the same chronology machinery. The novelty is which
states are chosen and how the analysis is preregistered — not the model of the
game.

| Component | Reused from | Changed for v4? |
| --- | --- | --- |
| Progression model (`STEPS`) | `tools/generate_heldout_v3.py` | **No** — byte-identical, hash-pinned in Appendix B |
| Witness-path walker, prerequisite closure, key chain | `tools/generate_heldout_v3.py` | **No** |
| Chronology rules (16, source-cited, fault-injected) | `tests/heldout_v3_chronology_test.gd` | **No** — same rule table |
| Canonical PKM serialization | `tools/pkm_reference.py` | **No** — but v4 is the first data set *required* to use it |
| Metric definitions | `docs/EVALUATION_PROTOCOL.md` §5–§6 | **No** for the primary metric; §16 adds two clearly-labelled new secondaries |
| Feature encoding and selection | — | **Yes** — specified here |
| Two-stratum design | — | **Yes** — specified here |

---

## 3. Candidate-state generation

### 3.1 The progression model

Candidate states are produced by the witness-path walker in
`tools/generate_heldout_v3.py`, unchanged. Its `STEPS` table is a transcription
of the live room scripts with file-and-line citations on each entry; it models
the real chain

```
Wake -> Chemistry -> Greenhouse -> Circuit -> Dining     (Library is off-chain)
```

including which step yields which key, which flags each step sets, and which
evidence each step grants.

**Chronology here is a property of construction, not a post-hoc filter.** A state
exists as a candidate only because a legal ordering of real steps produced it.
The validators in §12 are a check on that construction, not the thing that makes
it legal.

### 3.2 Legality

`close(chosen)` takes a requested set of steps and returns a legal superset, or
`None`. A path is legal only if:

1. every prerequisite of every chosen step is transitively included;
2. every mandatory step implied by the chosen steps is included;
3. the resulting step set is topologically orderable — no cycle, no step whose
   prerequisites arrive after it;
4. every room entered was entered with a key the player already held, where the
   key was granted by an earlier step in that same ordering.

Any requested set that fails is discarded. Nothing is repaired.

### 3.3 The NPC's room

Each NPC exists in exactly one live room, and a v4 scenario places the NPC only
there:

| NPC | Room | Door step |
| --- | --- | --- |
| `butler` | `chemistry_room` | `door_chem` |
| `gardener` | `greenhouse_room` | `door_green` |
| `mechanic` | `circuit_room` | `door_circuit` |

This is also a contamination safeguard — see §4.4.

### 3.4 The candidate pool

The walker enumerates, per NPC, every combination of optional steps in the
chemistry, greenhouse, circuit and library threads that closes legally, at each
reachable room-chain depth. Candidates are deduplicated on state identity
(§4.1), so each retained candidate carries exactly one canonical witness path.

Measured pool size — a property of the game, computed read-only:

| NPC | Candidates | By stage | Witness-path length |
| --- | --- | --- | --- |
| `butler` | 19,440 | chemistry 648, greenhouse 1,944, circuit 16,848 | 5 – 32 |
| `gardener` | 18,792 | greenhouse 1,944, circuit 16,848 | 8 – 32 |
| `mechanic` | 16,848 | circuit 16,848 | 12 – 32 |
| **Total** | **55,080** | | |

All 55,080 fingerprints are distinct. This matters twice: it is what makes the
tie-break in §9 a strict total order, and it is what makes "distinct witness
paths" and "distinct state fingerprints" the same requirement rather than two.

The pool is three orders of magnitude larger than the 72 states v4 needs, so the
selection procedures below are not operating under scarcity.

---

## 4. State identity and contamination exclusion

### 4.1 Fingerprint definition

A **state fingerprint** is

```
sha256( json.dumps({
    "npc":             npc,
    "room":            room,
    "evidence_items":  sorted(evidence_items),
    "knowledge_items": sorted(knowledge_items),
    "story_flags":     sorted(story_flags),
}, sort_keys=True, separators=(",", ":")) )
```

Two properties are deliberate:

- **It carries no identifier and no label.** State identity must not depend on
  what a state is called or on what anyone concluded about it. This differs from
  the `state_fingerprint_sha256` field recorded inside
  `heldout_v3_scenarios.json`, which includes the scenario `id` and therefore
  cannot be used to compare states across data sets. v3's fingerprints are
  **recomputed** under this definition for the exclusion below.
- **It is computed from raw state only.** Building the exclusion set requires no
  access to any annotation. No v3 relevance label, failure category, rationale or
  ambiguity level is read at any point in v4 generation.

### 4.2 The exclusion set

v4 must contain no exact state duplicate of any earlier benchmark or fixture.

| Source | Scenarios | Distinct fingerprints |
| --- | --- | --- |
| `docs/heldout/heldout_v2_scenarios.json` | 48 | 48 |
| `docs/heldout/heldout_v3_scenarios.json` | 48 | 48 |
| **Union** | **96** | **96** (v2 ∩ v3 = ∅) |

Exclusion-set digest — `sha256` of the 96 hex fingerprints sorted ascending and
joined with `\n`:

```
27ae5ddb750dec4c04ee3338f239ef44cd242b5f919747356c1297706eb32ecf
```

v3 is excluded because the task requires it. v2 is excluded because including it
costs one additional file read and removes the need to argue about it.

**Measured intersection with the legal pool: 48 candidates, all of them v3** (16
per NPC). None of v2's 48 states appear in the pool at all — v2 predates the
chronology machinery and contains states this walker cannot produce. The v4
candidate pool after exclusion is **55,032** (butler 19,424, gardener 18,776,
mechanic 16,832).

Near-neighbour states are allowed. A state that differs from a v3 state by one
flag is a different state, is independently reachable, and is not excluded.
Exclusion is exact-match only.

### 4.3 Generation-time assertion

The generator recomputes the exclusion set from disk and aborts unless it
contains exactly 96 fingerprints with the digest above. It then asserts that no
selected v4 state's fingerprint is in that set. A hard-coded digest that is never
recomputed would be decoration.

### 4.4 The room partition, as a backstop

The exclusion set above is enumerative: it works because v2 and v3 are files that
can be read. Synthetic fixtures are not files — they are state dictionaries built
inside GDScript test helpers from arguments supplied at call sites, and
exhaustively extracting them statically is not reliably possible. Claiming an
enumeration of them would be claiming more than can be checked.

There is a structural argument instead, and it is stronger. Every synthetic and
development state in the repository places the NPC in `castle_hall`:

| File | `room` literals |
| --- | --- |
| `tests/condition_c_selector_test.gd` | `castle_hall` ×2 |
| `tests/condition_c_transport_test.gd` | `castle_hall` ×1 |
| `tools/condition_c_live_smoke.gd` | `castle_hall` ×1 |
| `tests/adaptive_hint_baseline_test.gd` (20 development scenarios) | `castle_hall` ×20 |
| `docs/heldout/heldout_v1_scenarios.json` (48) | `castle_hall` ×48 |

v4 places each NPC only in their live room (§3.3). `castle_hall` is not a v4
room, so **no v4 state can equal any of these, whatever their contents.** The
Condition C smoke fixture and every unit-test-only synthetic scenario are
excluded by construction, not by enumeration.

The checker asserts this partition holds. If someone later adds a synthetic
fixture in a live room, the check fails and this argument must be replaced rather
than quietly relied upon.

---

## 5. Structural features

### 5.1 Allowed and forbidden inputs

Selection may read **only** raw game state (`evidence_items`, `knowledge_items`,
`story_flags`), the witness path that produced it, the canonical PKM derived from
that state, and hard-prerequisite/`teaches`/`preferred_when_demonstrated`
metadata from the shared hint catalogue.

Selection may **not** read, and this specification's objective contains none of:
Condition A output; Condition B output; Condition C output; whether A and B
disagree; whether any selector would be judged relevant; human `VALID_HINTS`; any
v3 failure category; any v3 relevance result; any v3 redundancy result; a
predicted winner; or any manual judgement about which condition should perform
better.

No hint relevance judgement of any kind appears in the CORE objective or in the
STRESS bin predicates.

### 5.2 Derived catalogue sets

These are computed by parsing the frozen catalogue, not restated by hand:

```
associated_concepts(npc) = { c in teaches(h) u preferred_when_demonstrated(h)
                             : h owned by npc, c is a PlayerKnowledgeModel concept }
```

| NPC | Hints | `teaches` ∩ PKM | `preferred_when_demonstrated` ∩ PKM | **Associated concepts** |
| --- | --- | --- | --- | --- |
| `butler` | 3 | — | `indicator_reaction` | `indicator_reaction` |
| `gardener` | 4 | `reflection` | `reflection` | `reflection` |
| `mechanic` | 4 | `circuit_continuity` | `circuit_fault_isolation` | `circuit_continuity`, `circuit_fault_isolation` |

`h_butler_no_evidence` declares `teaches: ["dual_lock_rule"]`, which is a legacy
catalogue concept and **not** a `PlayerKnowledgeModel` concept; it is therefore
excluded. Using `teaches` alone would leave the Butler with no associated concept
and make two STRESS bins vacuous for one NPC, which is why the union with
`preferred_when_demonstrated` is used.

### 5.3 Feature definitions

Every feature is a deterministic function of raw state plus the derived sets
above. `L(c)` is witness-path length; `own(npc)` is the NPC's own major evidence
item (`butler`→`fake_red_stain`, `gardener`→`greenhouse_pollen`,
`mechanic`→`deliberate_short_circuit`).

| # | Feature | Domain | Definition |
| --- | --- | --- | --- |
| F1 | `stage` | chemistry / greenhouse / circuit | room-chain depth of the witness path |
| F2 | `progression_bucket` | early / middle / late | §5.4 |
| F3 | `own_evidence` | bool | `own(npc) ∈ evidence_items` |
| F4 | `other_major_count` | 0–2 | count of the other two major evidence items held |
| F5 | `eligible_count` | int | number of catalogue hints owned by the NPC whose hard prerequisites the state satisfies |
| F6 | `associated_concept_states` | tuple | canonical PKM mastery of `associated_concepts(npc)`, ordered by concept id |
| F7 | `pkm_profile` | (u, l, d) | count of UNSEEN / LEARNING / DEMONSTRATED across all 8 PKM concepts |
| F8 | `room_investigation_complete` | bool | §5.5 |
| F9 | `destination_reached` | bool | §5.6 |
| F10 | `prior_npc_interaction` | bool | any raw NPC-interaction flag for this NPC is set — §5.7 |
| F11 | `evidence_shape` | (F3, F4) | joint |
| F12 | `shape_x_associated` | (F3, F4, F6) | joint |

F11 and F12 are explicit interaction terms. Marginal coverage alone permits a
selection that covers every value of every feature while covering few of their
combinations; the joints apply pressure toward the combinations the research
question is actually about.

### 5.4 `progression_bucket`

Room-chain stage alone cannot express progression depth for every NPC — the
Mechanic is reachable at exactly one stage (§3.4), so `stage` is constant for
them. `progression_bucket` supplies an early/middle/late axis that is meaningful
for all three NPCs, defined per NPC over that NPC's own legal pool:

Let `lo` and `hi` be the minimum and maximum witness-path length over the NPC's
full legal pool and `span = hi - lo`. For a candidate with length `L`:

```
early   iff  3*(L - lo) <  span
middle  iff  span <= 3*(L - lo) < 2*span
late    iff  3*(L - lo) >= 2*span
```

Integer arithmetic only — no floats, no rounding rule, no magic numbers. Thirds
of the *range*, not of the distribution: the length distribution is sharply
peaked by combinatorics, and distribution tertiles would put a 5-step state and a
21-step state in the same "early" bucket.

Measured thresholds and populations over the full pool:

| NPC | lo | hi | span | early | middle | late | Populations (e / m / l) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `butler` | 5 | 32 | 27 | L ≤ 13 | 14 ≤ L ≤ 22 | L ≥ 23 | 567 / 8,937 / 9,936 |
| `gardener` | 8 | 32 | 24 | L ≤ 15 | 16 ≤ L ≤ 23 | L ≥ 24 | 630 / 10,815 / 7,347 |
| `mechanic` | 12 | 32 | 20 | L ≤ 18 | 19 ≤ L ≤ 25 | L ≥ 26 | 760 / 13,191 / 2,897 |

`lo`, `hi` are taken over the **full** pool, before exclusion, so the bucket
boundaries do not shift as a function of what was excluded.

### 5.5 `room_investigation_complete`

True when every flag and evidence item contributed by any step inside the NPC's
own room has been obtained. Derived from the `STEPS` table, evaluated against raw
state:

| NPC | Required flags | Required evidence |
| --- | --- | --- |
| `butler` | `chemistry_cabinet_secret_found`, `mrs_lin_lab_note_seen`, `chemistry_change_sorted`, `butler_challenge_given`, `butler_challenge_complete`, `chemistry_butler_interviewed` | `fake_red_stain` |
| `gardener` | `greenhouse_circuit_key_found` | `greenhouse_pollen` |
| `mechanic` | `circuit_repair_map_studied`, `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_power_restored`, `blackout_deliberate` | `deliberate_short_circuit` |

This is a mechanical property of the step graph. It involves no judgement about
hints.

### 5.6 `destination_reached`

The terminal progression marker of the NPC's own room thread:

| NPC | Flag | Set by |
| --- | --- | --- |
| `butler` | `butler_challenge_complete` | `butler_complete` |
| `gardener` | `greenhouse_circuit_key_found` | `green_survey` |
| `mechanic` | `circuit_power_restored` | `circuit_power` |

Each was identified from the `STEPS` dependency graph as a terminal marker of
that room's thread. The generator asserts that each named flag exists in `STEPS`
and is set by a step belonging to that NPC's room set; a renamed flag fails
generation rather than silently making the feature constant.

**No hint text, hint metadata or selector was consulted to choose these.** This
feature exists because the task allows "investigation target already reached /
not yet reached when this can be determined from raw progression flags without
using a selector", and these three flags are that determination.

### 5.7 `prior_npc_interaction` — a feature that is constant for two NPCs

The task permits "prior NPC interaction flags **if they actually exist** in raw
game state". They exist only for the Butler:

- `butler_challenge_given`, `butler_challenge_complete`,
  `chemistry_butler_interviewed` — all real flags in `STEPS`.
- The Gardener and Mechanic have no interaction flag reachable through the
  walker. (`gardener_circuit_map_explained` exists in the legacy concept table
  but no modelled step sets it.)

So F10 takes two values for the Butler and exactly one for the Gardener and
Mechanic. It is retained because it is real where it is real, and recorded here
because a feature that cannot vary contributes no coverage pressure, and that
should be visible rather than assumed. The checker asserts this per-NPC domain;
if a Gardener or Mechanic interaction flag is ever added, the check fails and
this note must be updated.

### 5.8 `eligible_count` is collinear with `own_evidence`

No hint in the frozen catalogue declares `requires_story_flags` or
`requires_concept`. Hard eligibility therefore depends on `evidence_items` alone,
and within each NPC it is a bijection of `own_evidence`:

| NPC | own evidence absent | own evidence present |
| --- | --- | --- |
| `butler` | 2 eligible | 1 eligible |
| `gardener` | 3 eligible | 2 eligible |
| `mechanic` | 3 eligible | 2 eligible |

Both features are named in the task and both are retained, but the consequence is
stated rather than left implicit: **covering `own_evidence` fully is the same act
as covering `eligible_count` fully**, and including both in the objective gives
that single bit double weight. That is the only non-uniformity in an otherwise
uniformly weighted objective, it is disclosed here, and the checker asserts the
collinearity so that if the catalogue ever gains a flag- or concept-gated hint
this note becomes false loudly instead of silently.

### 5.9 Reachable value counts

Measured over the post-exclusion pool. This is what the coverage objective has to
work with:

| Feature | butler | gardener | mechanic |
| --- | --- | --- | --- |
| `stage` | 3 | 2 | **1** |
| `progression_bucket` | 3 | 3 | 3 |
| `own_evidence` | 2 | 2 | 2 |
| `other_major_count` | 3 | 3 | 2 |
| `eligible_count` | 2 | 2 | 2 |
| `associated_concept_states` | 3 | 3 | 5 |
| `pkm_profile` | 45 | 45 | 45 |
| `room_investigation_complete` | 2 | 2 | 2 |
| `destination_reached` | 2 | 2 | 2 |
| `prior_npc_interaction` | 2 | **1** | **1** |
| `evidence_shape` | 6 | 5 | 4 |
| `shape_x_associated` | 12 | 15 | 20 |

`pkm_profile` has 45 reachable values against 16 CORE slots per NPC, so it can
never be fully covered; it functions as coverage pressure, not as a guarantee.
Section 8.4 states which features carry a hard guarantee.

### 5.10 Weights

**All features carry weight 1.** Coverage gain is the count of newly covered
`(feature, value)` pairs.

No weighting scheme was adopted because none can be justified without reference
to outcomes, and choosing weights by looking at outcomes is the exact failure
mode this freeze exists to prevent. The single effective non-uniformity is the
F3/F5 collinearity disclosed in §5.8.

---

## 6. Selection order: STRESS first, then CORE

STRESS is selected first, from the exclusion-filtered pool. CORE is then selected
from that pool minus the 24 STRESS states.

The task presents CORE first, and this reverses it deliberately. CORE is required
to "approximate broad structural coverage of **ordinary** legal states rather
than adversarially targeting selector weaknesses". A greedy coverage optimizer
run first would take the extreme states — the shortest path, the longest path,
the maximal candidate counts — because extremes are exactly what maximizes
marginal coverage. CORE would then be the boundary set and STRESS would get the
leftovers, which inverts both strata's purpose.

Selecting STRESS first removes 24 boundary states before CORE runs, leaving CORE
to draw from the ordinary bulk. The cost is that CORE loses 24 candidates out of
55,032; §5.9 shows no required-coverage feature has so few reachable states that
this could matter.

This is a documented design decision, recorded here rather than in a commit
message, and it makes CORE *less* favourable to any condition that benefits from
boundary handling — not more.

---

## 7. STRESS selection (24 = 8 + 8 + 8)

### 7.1 Bins

Each NPC gets exactly 8 STRESS scenarios, one per bin, filled in the fixed order
B1 … B8. Every predicate is a function of raw state, the witness path, and
catalogue structure. None of them encodes a judgement about what a hint should
say.

| Bin | Task boundary condition | Predicate |
| --- | --- | --- |
| **B1** `very_early` | very early progression | `L` is minimal among the NPC's remaining candidates |
| **B2** `very_late` | very late progression | `L` is maximal among the NPC's remaining candidates |
| **B3** `max_candidates_pref_active` | multiple eligible candidates | `eligible_count` is maximal for the NPC **and** ≥1 concept in `preferred_when_demonstrated(npc)` is DEMONSTRATED |
| **B4** `associated_demonstrated` | DEMONSTRATED teaching concepts | ≥1 concept in `associated_concepts(npc)` is DEMONSTRATED |
| **B5** `associated_learning` | LEARNING teaching concepts | ≥1 concept in `associated_concepts(npc)` is LEARNING **and** none is DEMONSTRATED |
| **B6** `no_own_evidence_plain` | no own evidence | own evidence absent **and** no `preferred_when_demonstrated(npc)` concept is DEMONSTRATED |
| **B7** `evidence_after_progression` | evidence held after related progression has advanced | own evidence present **and** `room_investigation_complete` |
| **B8** `destination_reached` | directional information whose destination may already have been reached | `destination_reached` |

B1 and B2 are relative to the remaining candidates so that an exclusion can never
empty them.

B3 and B6 both involve "own evidence absent" — see §5.8 — and are made disjoint
by the preference-active conjunct, so the two task bullets they serve produce two
structurally different states rather than the same one twice.

### 7.2 The eighth boundary condition

The task's eighth bullet is "combinations where SILENCE may plausibly be useful",
together with an explicit instruction not to decide that a state should be
silence. These cannot both be satisfied by a bin that names silence, so no bin
does.

Instead, **B8 is the structural analogue**: a state where the NPC's own thread has
already reached its terminal marker. Whether that makes any hint pointless is
precisely the question the human annotator answers and the conditions are scored
on. This specification takes no position on it. The within-bin ranking in §7.3
then prefers the B8 candidate that is *also* loaded with the other boundary
markers, which is as close to "silence may plausibly be useful" as a raw-state
predicate can honestly get.

### 7.3 Within-bin ranking: boundary load

Within a bin, candidates are ranked by **boundary load** — the number of the
eight bin predicates the candidate satisfies — descending, then by the tie-break
in §9. B1/B2 are evaluated against the NPC's full pool when computing load, so
load is a stable property of a state rather than of the order bins were filled.

One uniform rule, applied to every bin. No per-bin hand-tuning, and therefore no
per-bin opportunity to steer.

### 7.4 Measured bin populations

Over the full legal pool, before exclusion:

| Bin | butler | gardener | mechanic |
| --- | --- | --- | --- |
| B1 `very_early` | 1 | 1 | 1 |
| B2 `very_late` | 1 | 1 | 1 |
| B3 `max_candidates_pref_active` | **0** | 216 | 5,184 |
| B4 `associated_demonstrated` | 6,480 | 6,264 | 12,960 |
| B5 `associated_learning` | 9,720 | 6,264 | 2,592 |
| B6 `no_own_evidence_plain` | 6,480 | 432 | 3,240 |
| B7 `evidence_after_progression` | 783 | 17,496 | 648 |
| B8 `destination_reached` | 6,480 | 17,496 | 5,184 |

**Butler B3 is empty, provably and permanently.** The Butler's only
`preferred_when_demonstrated` concept is `indicator_reaction`, whose DEMONSTRATED
state requires `butler_challenge_complete`, which by chronology rule
`C8_butler_challenge_needs_stain` requires `fake_red_stain`. Holding the stain
makes `h_butler_stain` the only hard-eligible Butler hint — count 1, not the
maximum 2. "Maximal candidate count" and "preference active" are mutually
exclusive for the Butler. This is the same structural asymmetry already recorded
in the evaluation protocol.

That is 23 populated bins out of 24, known before generation rather than
discovered during it.

### 7.5 Backfill

If a bin has no remaining candidate, the slot is recorded as
`stress_bin: "<id>", bin_empty: true` and filled from the boundary-load ranking
over that NPC's entire remaining pool. The artifact records which bins were
empty; the checker recomputes the emptiness set and fails on disagreement, so
`bin_empty` cannot be used as an escape hatch.

Given §7.4, exactly one backfill is expected: Butler B3.

---

## 8. CORE selection (48 = 16 + 16 + 16)

### 8.1 Bucket quota

Per NPC, 16 slots are distributed across `progression_bucket` as 5 / 5 / 5, with
the sixteenth slot going to the bucket holding the **largest surviving candidate
population** for that NPC — a deterministic, purely structural rule that needs no
arbitrary choice about which third deserves the extra state.

| NPC | early | middle | late | Extra slot | Quota |
| --- | --- | --- | --- | --- | --- |
| `butler` | 560 | 8,929 | 9,935 | late | 5 / 5 / 6 |
| `gardener` | 622 | 10,807 | 7,347 | middle | 5 / 6 / 5 |
| `mechanic` | 747 | 13,188 | 2,897 | middle | 5 / 6 / 5 |

(Populations are post-exclusion and pre-STRESS; the generator recomputes them
after STRESS is removed and applies the same rule. A tie is broken by bucket name
ascending: `early` < `late` < `middle`.)

### 8.2 The greedy

```
covered = {}                                # set of (feature, value) pairs
chosen  = []
cycle   = [early, middle, late]  repeated, skipping exhausted buckets

for slot in 1..16:
    bucket     = next bucket in cycle with quota remaining
    candidates = remaining pool for this NPC in that bucket
    gain(c)    = |cells(c) \ covered|        # cells(c) = the 12 (feature,value) pairs
    if max gain == 0:
        covered = {}                         # saturated: begin a second layer
        recompute gain
    winners = argmax gain
    pick    = min(winners, key = tie_break)  # §9
    chosen.append(pick); covered |= cells(pick); quota[bucket] -= 1
```

Buckets are visited round-robin rather than in blocks so that no single bucket
consumes the coverage set before the others compete for it.

The reset on saturation is inherited from the v3 generator: once every reachable
cell is covered, coverage restarts so the remaining slots continue to spread
rather than degenerating into the tie-break order.

There is no randomness anywhere. No seed exists because none is needed.

### 8.3 CORE is not adversarial

The objective contains only the twelve features in §5.3. It contains no selector
output, no relevance judgement, and no boundary-seeking term. The boundary states
were removed before CORE ran (§6). CORE is a spread over ordinary legal states,
and that is all it is.

### 8.4 Acceptance criterion

Generation **fails** — no artifact is written — unless, for each NPC, the 16 CORE
scenarios cover **every reachable value** of:

- `progression_bucket`
- `own_evidence`
- `eligible_count`
- `associated_concept_states`

These are the four dimensions the task names as required. §5.9 shows the maximum
reachable value count across them is 5 (the Mechanic's associated-concept tuple),
comfortably inside 16 slots, so the criterion is satisfiable — but it is enforced
rather than assumed.

Coverage of the remaining eight features is reported, not required; `pkm_profile`
in particular cannot be fully covered and no fiction is maintained that it can.

---

## 9. Deterministic tie-breaking

A single total order, used by both strata, applied after each stratum's own
ranking:

1. shorter witness path (`L` ascending)
2. fewer `story_flags`
3. fewer `evidence_items`
4. lexicographically smallest state fingerprint

Steps 1–3 prefer the structurally simpler of two otherwise equal states — a
stable preference that is independent of any selector.

**Step 4 is a strict total order, by construction.** Candidates are deduplicated
on fingerprint, and all 55,080 pool fingerprints were measured distinct (§3.4),
so no two surviving candidates can tie at step 4. The procedure has no
undetermined branch and needs no fallback.

---

## 10. Identifiers and ordering

Scenario ids are `v4_{stratum}_{npc}_{nn}` with `nn` zero-padded from 01, e.g.
`v4_core_butler_01`, `v4_stress_mechanic_08`.

The artifact lists scenarios in this frozen order, with `ordinal` 1 … 72:

1. stratum: `CORE` before `STRESS`
2. npc: `butler`, `gardener`, `mechanic`
3. within an NPC: selection order — CORE in greedy pick order, STRESS in bin
   order B1 … B8

Selection order is retained rather than sorted away because it is auditable: the
`n`-th CORE pick is reproducible by re-running the greedy for `n` steps, and the
`n`-th STRESS pick names the bin that justified it.

---

## 11. Artifact schema

`docs/heldout/heldout_v4_scenarios.json`:

```json
{
  "version": "heldout-v4",
  "spec": "docs/HELDOUT_V4_GENERATION_SPEC.md",
  "spec_sha256": "<sha256 of this file at generation time>",
  "generated_by": "tools/generate_heldout_v4.py",
  "pkm_serialization": "canonical",
  "pkm_model_sha256": "<tools/pkm_reference.py model_sha256()>",
  "exclusion_digest": "27ae5ddb...",
  "exclusion_count": 96,
  "strata": { "CORE": 48, "STRESS": 24 },
  "selector_was_run": false,
  "annotations_present": false,
  "coverage_report": { "<npc>": { "<feature>": { "covered": n, "reachable": m } } },
  "stress_bin_report": { "<npc>": { "<bin>": { "empty": bool } } },
  "scenarios": [ ... ]
}
```

Each scenario:

```json
{
  "id": "v4_core_butler_01",
  "ordinal": 1,
  "stratum": "CORE",
  "stress_bin": null,
  "bin_empty": false,
  "npc": "butler",
  "room": "chemistry_room",
  "stage": "chemistry",
  "progression_bucket": "middle",
  "evidence_items": [...],
  "knowledge_items": [],
  "story_flags": [...],
  "pkm_states": { "<concept>": "UNSEEN|LEARNING|DEMONSTRATED" },
  "witness_path": [...],
  "state_fingerprint_sha256": "...",
  "structural_features": { "<F1..F12>": ... },
  "valid_hints": [],
  "annotation": null
}
```

`valid_hints` is empty and `annotation` is null at generation. They are populated
only by the annotation step in §15, and only after the scenario set is frozen.

---

## 12. Chronology validation

Three independent layers. Each is capable of failing.

**Layer 1 — construction.** §3.2. A state exists only because a legal ordering of
real steps produced it.

**Layer 2 — the v3 rule table, unchanged.** `tests/heldout_v4_chronology_test.gd`
reuses the 16 source-cited rules from `tests/heldout_v3_chronology_test.gd`
verbatim:

```
C1_stain_needs_chemistry          C6_bench_needs_map_study
C2_pollen_needs_greenhouse        C6b_regulator_bench
C2b_greenhouse_needs_chemistry_cabinet   C6c_diagnostic_bench
C3_circuit_implies_pollen         C7_power_needs_master_switch
C4_short_circuit_needs_circuit    C8_butler_challenge_needs_stain
C5_short_circuit_pairs_with_blackout     C9_library_filter_needs_knowledge
C5b_blackout_pairs_with_short_circuit    C9b_red_filter
C10_door_implies_dual_lock        C9c_blue_filter
```

The v4 test must carry **fault injection for every rule**: for each rule, build a
state that satisfies it, remove exactly one consequence, and require the checker
to detect the violation. A chronology check that cannot fail proves nothing, and
the v3 test is the pattern.

The rule table is hash-pinned in Appendix B. If
`tests/heldout_v3_chronology_test.gd` changes, the spec checker fails and the
claim "v4 used the same rules as v3" must be re-established rather than assumed.

**Layer 3 — the independent invariant checker.**
`AdaptiveHintData.reachability_violations()` is applied to every v4 state. It was
written for a different purpose, by a different route, and agrees or the
generation fails.

Any state failing any layer is rejected. Nothing is repaired, adjusted, or
excepted.

---

## 13. Canonical PKM

v4 is the **first** data set required to serialize the Player Knowledge Model
canonically.

- `pkm_states` must be produced by `tools/pkm_reference.py :: serialize()`, which
  parses the `CONCEPTS` table out of `scripts/player_knowledge_model.gd` rather
  than restating it, so the Python path cannot drift from the GDScript one by
  transcription.
- The artifact must carry `"pkm_serialization": "canonical"`.
- `tests/pkm_serialization_canonical_test.gd` then proves **in Godot**, against
  the real `PlayerKnowledgeModel`, that every serialized value equals canonical
  derivation for every concept in every state. Zero tolerance: one mismatch
  fails.

This is cross-language, cross-implementation validation — a Python program's
output checked by a GDScript program running the actual engine class. It is the
strongest check available here, and v3 could not use it because v3 predates it
(v3's recorded drift is pinned and grandfathered, not rewritten).

`knowledge_items` is carried through the schema because the model's signature
takes it, but `PlayerKnowledgeModel` never reads it. It is dead state and v4 will
record it as empty.

---

## 14. Generator integrity

`tools/generate_heldout_v4.py` **must not** import or call:

- `select_condition_a`
- `select_adaptive`
- any part of Condition C
- any relevance scorer
- any redundancy scorer based on a selector decision

It **may** import the shared hint catalogue, and only for:

- hard prerequisite metadata
- hard-eligible candidate count
- hint-to-NPC identity
- `teaches` / `preferred_when_demonstrated`, solely to build the structural
  concept bins in §5.2

**It must never ask which hint any condition would select.** Producing a
candidate's feature vector requires knowing which hints are *hard-eligible*; it
never requires knowing which one would be *chosen*, and the generator must not
compute that.

The checker scans the generator for the forbidden symbols with whole-line
comments stripped first, so the file may name them in prose to record the
commitment without breaking the check. The scanner is self-tested against a
synthetic violating string, so it cannot pass by failing to look. **Until
`tools/generate_heldout_v4.py` exists the scan is reported as DEFERRED, never as
PASS.**

---

## 15. Order of future operations

This order is frozen. Each step must complete before the next begins.

1. **Generate v4** under this specification. Run the chronology test (§12), the
   canonical PKM test (§13), and the spec checker. Commit and tag the scenario
   set. It is immutable from that moment.
2. **Human annotation.** After the scenario set is frozen, before any condition
   runs. The annotator records, per scenario: `VALID_HINTS`, a rationale, and an
   ambiguity level of LOW / MEDIUM / HIGH. `NONE` (an empty `VALID_HINTS` with a
   non-empty rationale) remains allowed. The annotator must not see Condition A,
   B or C output — none of it exists yet, which is the point of the ordering.
   Commit and tag the annotations. They are immutable from that moment.
3. **Run A, B and C** on the frozen, annotated set — once.
4. **Score and report** under §16.

The **frozen annotation rubric in `docs/EVALUATION_PROTOCOL.md` §8b remains
authoritative.** It may be revised only if a true contradiction with v4 state
representation is discovered, and any such revision must be committed with its
justification before annotation begins. It must **not** be revised after viewing
v4 scenarios merely because annotation turns out to be difficult.

---

## 16. Statistical analysis plan

Preregistered here, before v4 exists and therefore before any number can be seen.

### 16.1 Strata are reported separately

CORE (n = 48) carries the **primary confirmatory** analysis. STRESS (n = 24) is a
**preregistered secondary robustness/boundary analysis** and is reported
separately.

**CORE and STRESS are never combined into a single headline metric.** No
composite score is created.

### 16.2 Primary metric — `RelevantHintRate` (unchanged from v3)

```
relevant   = selected hint id is non-empty AND selected hint id in HUMAN VALID_HINTS
numerator  = count of relevant selections
denominator= all attempted scenarios in the stratum
```

**SILENCE is never relevant.** A silent scenario is a relevance failure even when
the human label is `NONE`. Silence is not free: it also lowers `Coverage` and is
never excluded from the denominator.

This is the v3 rule, byte-for-byte in meaning, and it is not amended. It
preserves the closed v3 protocol, the v3 implementation, the frozen Condition C
specification (`docs/CONDITION_C_SPEC.md` §B.7 asserts exactly this), direct
v3↔v4 metric continuity, and symmetry of the headline metric across conditions.

### 16.3 Other metrics carried forward from v3

| Metric | Definition | Denominator |
| --- | --- | --- |
| `Coverage` | delivered ÷ attempted | attempted |
| `StateViolationRate` | hard-prerequisite violations ÷ delivered | delivered |
| `RedundantHintRate` | redundant ÷ delivered | delivered |
| `RedundantWhenTeachable` (secondary) | redundant teaching hints ÷ teaching hints delivered | teaching hints delivered |

Numerator and denominator are always reported. If the teaching denominator is 0,
report exactly `N/A (0 teaching hints delivered)`.

### 16.4 New v4 secondary metrics

These are **new prospective v4 outcomes**. They were **not** part of the closed v3
analysis and must never be presented as if they were.

**`AppropriateActionRate` — SECONDARY.**

```
correct_action = (delivered AND selected hint in VALID_HINTS)
                 OR (silence AND VALID_HINTS is empty)
AppropriateActionRate = correct actions / all attempted scenarios
```

It exists to separate two questions the primary metric deliberately fuses: *was
the hint relevant*, and *should any hint have been delivered at all*. The primary
metric answers the first. This answers the broader decision.

**`CorrectSilenceRate` — DESCRIPTIVE ONLY.**

```
numerator   = NONE-labelled scenarios on which the selector chose SILENCE
denominator = NONE-labelled scenarios
```

If the denominator is 0, report `N/A (0 NONE scenarios)`. This is **not** merged
into `RelevantHintRate`, and no inferential test is preregistered for it.

### 16.5 Inferential plan (CORE)

A/B/C see the same scenarios, so relevance comparisons are **paired**.

**PRIMARY.** `RelevantHintRate`, three preregistered pairwise comparisons —
A vs B, A vs C, B vs C — by **exact McNemar** on the discordant pairs. For each
comparison report:

- each condition's numerator and denominator
- the absolute percentage-point difference
- the discordant pair counts `b` and `c`
- the exact p-value
- the direction of the effect

**SECONDARY.** `AppropriateActionRate`, the same three pairwise exact McNemar
comparisons, the same reporting — explicitly labelled SECONDARY wherever it
appears.

**Multiplicity.** The three pairwise comparisons are the complete preregistered
family. Unadjusted exact p-values are the preregistered primary reporting;
Holm-adjusted p-values across the family of three are reported alongside them.
Any claim of significance must state which is being used.

**Sparse data.** A p-value may never be reported without its discordant counts.
A comparison with `b + c < 5` carries an explicit low-information caveat. This is
a reporting requirement, not a rule for suppressing results.

**Descriptive first.** `Coverage`, `StateViolationRate`, `RedundantHintRate` and
`RedundantWhenTeachable` are reported as numerators and denominators. No
significance is claimed from redundancy metrics when the denominators are sparse.

**Everything else is exploratory.** Any inferential analysis beyond the
comparisons named above — including anything on STRESS — is labelled
secondary/exploratory.

The exact test is implemented in `tools/mcnemar_exact.py`, committed with this
specification and self-tested, so the analysis code predates the data it will be
applied to.

### 16.6 v3 is not recomputed

The closed v3 artifacts are not altered, and v3 is **not** recomputed under
`AppropriateActionRate` as part of the primary study.

It may be noted analytically that Conditions A and B produced zero silent
scenarios on v3, so their closed `RelevantHintRate` figures would be unchanged
under an abstention-aware reading. That is an observation about arithmetic. **No
retroactive v3 headline metric is created.**

### 16.7 Condition C run discipline

Frozen before v4 generation:

- **exactly one primary C inference per scenario**
- a fresh subprocess per scenario — no conversation persistence
- the frozen schema retry only; a transport retry is **not** a new model sample
- no rerun because a decision looks bad
- no manual correction of a decision
- no prompt edits
- no model substitution
- no selection among responses
- **no repeated runs of C to choose a favourable result**

Every scenario must log: the **requested** model `claude-opus-5`; the **resolved**
model from the Claude Code envelope; the raw response; the parsed decision; the
retry count; the transport attempt count; the candidate ids offered; the
canonical PKM; the prompt hash; and the C freeze tag
`condition-c-pre-v4-freeze-v2`.

A transport failure aborts the run rather than recording an abstention. An outage
scored as SILENCE would be a fabricated data point.

---

## 17. What would invalidate this freeze

Stated so that the failure modes are testable rather than rhetorical:

- any change to `tools/generate_heldout_v3.py`, `tests/heldout_v3_chronology_test.gd`,
  `tools/pkm_reference.py`, `scripts/player_knowledge_model.gd` or
  `scripts/adaptive_hint_data.gd` — the pinned hashes in Appendix B would no
  longer match, and the measured numbers throughout this document would need
  re-deriving;
- a synthetic fixture placed in a live NPC room — §4.4's partition argument would
  collapse;
- a hint gaining `requires_story_flags` or `requires_concept` — §5.8's
  collinearity note would become false;
- a Gardener or Mechanic interaction flag becoming reachable — §5.7 would become
  false;
- any edit to this document after the tag `heldout-v4-generation-pre-freeze`.

A change to a frozen artifact is a **new version**, never an in-place edit.

### 17.1 One disclosed amendment made by this freeze

Adding §12 to `docs/EVALUATION_PROTOCOL.md`, as the v4 task requires, collided
with the Condition C freeze manifest, which pinned that file's whole-file hash.
Recorded here rather than left in the git log:

- the protocol change is provably append-only — the first 38,198 bytes of the
  current file hash to `1a211f6b…`, exactly the value the manifest recorded and
  exactly the content at `condition-c-pre-v4-freeze-v2`; the diff is 174
  insertions and 0 deletions;
- `supporting_hashes.evaluation_protocol` therefore became an **append-only
  pin**: the same hash, now scoped to a recorded prefix length. This is a
  narrower claim than before for that one entry. It is disclosed rather than
  presented as a strengthening, and it gains one thing a whole-file hash lacked:
  truncation is reported as truncation;
- `check_hashes` in `tools/check_condition_c_freeze.py` gained the
  `frozen_prefix_bytes` branch. Every entry without that key is still compared
  byte-for-byte, so nothing that constrains Condition C is checked more loosely.
  That checker pins its own hash, so the manifest now carries both the new and
  the previous value with a note naming what changed;
- `check_heldout_v4_spec.py::check_protocol_append_only` verifies the same
  property from the other side, against the git object store, so the recorded
  prefix length has to be the true one. A mistyped offset would satisfy the
  manifest's internal arithmetic and fail there.

Condition C reads no protocol text at run time. Nothing in this amendment
touches the prompt template, the selector, the model configuration, the
transport, or any heldout-v3 artifact; the tag
`condition-c-pre-v4-freeze-v2` is unmoved.

---

## Appendix A — frozen parameters (machine-readable)

`tools/check_heldout_v4_spec.py` parses this block. It is authoritative where it
overlaps the prose above, and the checker verifies that the two agree.

```json
{
  "version": "heldout-v4",
  "npc_order": ["butler", "gardener", "mechanic"],
  "strata": {
    "CORE": {"total": 48, "per_npc": 16},
    "STRESS": {"total": 24, "per_npc": 8},
    "TOTAL": 72
  },
  "selection_order": ["STRESS", "CORE"],
  "npc_rooms": {
    "butler": "chemistry_room",
    "gardener": "greenhouse_room",
    "mechanic": "circuit_room"
  },
  "pool": {
    "total": 55080,
    "per_npc": {"butler": 19440, "gardener": 18792, "mechanic": 16848},
    "distinct_fingerprints": 55080,
    "after_exclusion": 55032,
    "after_exclusion_per_npc": {"butler": 19424, "gardener": 18776, "mechanic": 16832}
  },
  "exclusion": {
    "fingerprint_fields": ["npc", "room", "evidence_items", "knowledge_items", "story_flags"],
    "id_included": false,
    "sources": [
      "docs/heldout/heldout_v2_scenarios.json",
      "docs/heldout/heldout_v3_scenarios.json"
    ],
    "count": 96,
    "digest": "27ae5ddb750dec4c04ee3338f239ef44cd242b5f919747356c1297706eb32ecf",
    "pool_intersection": 48,
    "room_partition_rooms": ["castle_hall"]
  },
  "core_objective_features": [
    "stage",
    "progression_bucket",
    "own_evidence",
    "other_major_count",
    "eligible_count",
    "associated_concept_states",
    "pkm_profile",
    "room_investigation_complete",
    "destination_reached",
    "prior_npc_interaction",
    "evidence_shape",
    "shape_x_associated"
  ],
  "feature_weights": "uniform",
  "required_coverage_features": [
    "progression_bucket",
    "own_evidence",
    "eligible_count",
    "associated_concept_states"
  ],
  "forbidden_selection_features": [
    "condition_a_output",
    "condition_b_output",
    "condition_c_output",
    "a_b_disagreement",
    "selector_relevance",
    "human_valid_hints",
    "v3_failure_category",
    "v3_relevance_result",
    "v3_redundancy_result",
    "predicted_winner",
    "manual_condition_judgement"
  ],
  "progression_bucket": {
    "rule": "integer thirds of the per-NPC witness-path length range over the full pool",
    "butler": {"lo": 5, "hi": 32, "early_max": 13, "middle_max": 22},
    "gardener": {"lo": 8, "hi": 32, "early_max": 15, "middle_max": 23},
    "mechanic": {"lo": 12, "hi": 32, "early_max": 18, "middle_max": 25}
  },
  "core_bucket_quota": {
    "base": 5,
    "extra_slot_rule": "bucket with the largest surviving candidate population; ties by bucket name ascending"
  },
  "associated_concepts": {
    "butler": ["indicator_reaction"],
    "gardener": ["reflection"],
    "mechanic": ["circuit_continuity", "circuit_fault_isolation"]
  },
  "destination_flags": {
    "butler": "butler_challenge_complete",
    "gardener": "greenhouse_circuit_key_found",
    "mechanic": "circuit_power_restored"
  },
  "stress_bins": [
    "B1_very_early",
    "B2_very_late",
    "B3_max_candidates_pref_active",
    "B4_associated_demonstrated",
    "B5_associated_learning",
    "B6_no_own_evidence_plain",
    "B7_evidence_after_progression",
    "B8_destination_reached"
  ],
  "stress_within_bin_rank": "boundary_load descending, then tie_break",
  "stress_empty_bins": {"butler": ["B3_max_candidates_pref_active"], "gardener": [], "mechanic": []},
  "tie_break": [
    "witness_path_length_ascending",
    "story_flag_count_ascending",
    "evidence_count_ascending",
    "state_fingerprint_lexicographic_ascending"
  ],
  "eligible_count_collinear_with_own_evidence": true,
  "constant_features": {
    "stage": ["mechanic"],
    "prior_npc_interaction": ["gardener", "mechanic"]
  },
  "generator_forbidden_symbols": [
    "select_condition_a",
    "select_adaptive",
    "adaptive_hint_selector",
    "CONDITION_A_TIERS",
    "condition_c_selector",
    "condition_c_client"
  ],
  "chronology_rule_source": "tests/heldout_v3_chronology_test.gd",
  "chronology_rule_count": 16,
  "pkm_serialization": "canonical",
  "metrics": {
    "primary": ["RelevantHintRate", "Coverage", "StateViolationRate", "RedundantHintRate"],
    "secondary": ["RedundantWhenTeachable", "AppropriateActionRate"],
    "descriptive": ["CorrectSilenceRate"],
    "silence_is_relevant": false,
    "new_in_v4": ["AppropriateActionRate", "CorrectSilenceRate"],
    "composite_score": false,
    "strata_combined": false
  },
  "inference": {
    "primary_outcome": "RelevantHintRate",
    "secondary_outcome": "AppropriateActionRate",
    "stratum": "CORE",
    "test": "exact_mcnemar",
    "paired": true,
    "comparisons": [["A", "B"], ["A", "C"], ["B", "C"]],
    "multiplicity": "holm_reported_alongside_unadjusted",
    "sparse_caveat_threshold": 5,
    "implementation": "tools/mcnemar_exact.py"
  },
  "condition_c": {
    "primary_inferences_per_scenario": 1,
    "process_per_scenario": true,
    "schema_retry_only": true,
    "transport_retry_is_new_sample": false,
    "reruns_allowed": false,
    "requested_model": "claude-opus-5",
    "freeze_tag": "condition-c-pre-v4-freeze-v2"
  },
  "operation_order": ["generate_v4", "freeze_v4", "human_annotation", "freeze_annotations", "run_abc", "score"]
}
```

## Appendix B — pinned hashes

The measured numbers in this document are derived from these exact files. If any
hash changes, the derivation must be redone rather than trusted.

```json
{
  "tools/generate_heldout_v3.py": "94402567c646ea4227a76883b45cae4bb2d2d546a71ffdeb0d5b39fde9866ee8",
  "tools/pkm_reference.py": "e585b01e7ea05159dcc8c58f0ee14fb1c2ea4963a833746a9dd4691d3533db60",
  "tests/heldout_v3_chronology_test.gd": "0b66a2b46450d0b925c4d73eaf06e04f7b285b63d301448241fdf4e2a9fa60f1",
  "scripts/player_knowledge_model.gd": "55ffe8bedb654813959a357d2ce427c068ea57ec37d9c76b50291eb40cd65cac",
  "scripts/adaptive_hint_data.gd": "a957ef713b4f80f9e4a423d8e950aa29b0dd55819caa4b0a7ea59ccec78e2036",
  "scripts/adaptive_hint_selector.gd": "c4a2c31201143fde1616e97f8bec5544ccb775c1f0b3605c1fc8d89fea3a8cb2",
  "tools/run_heldout_v3_ab_evaluation.gd": "0045a3747404eba03f3314a7057b06dcff3f96e3f855008e27cc5c69d8bddb51",
  "docs/heldout/heldout_v2_scenarios.json": "a55b208005c87c370f34b86386125423e3c1b90e8fe017f956dd39937b77fd45",
  "docs/heldout/heldout_v3_scenarios.json": "dc093e987571d58bd22186c0ea15356df2354c29e99bca4386d1c3063754cd78",
  "docs/heldout/heldout_v3_annotated.json": "9d7285c794b824753af3f6a221cef3bc754bc542fe9d0cae52cb2cd09644dc9e",
  "docs/heldout/heldout_v3_ab_raw.json": "ff6d0b2162770eefff73646414dbc3dee21953429cca9cbbd5d57029ceefd28a",
  "docs/heldout/heldout_v3_ab_metrics.json": "bb461bf8ac76b88fe7e65556c2a2e7deb5fd651262c2b622f499ade5aec35066"
}
```

The four `heldout_v3_*` entries are the closed experiment. They appear here for
one reason: to be recomputed by the checker, so that "v3 was not touched" is a
statement that fails loudly rather than a promise.
