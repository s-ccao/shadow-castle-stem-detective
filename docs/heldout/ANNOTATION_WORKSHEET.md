# Held-out v1 — annotation worksheet

**Protocol:** `heldout-v1` · **Scenarios:** 48 · **State fingerprint:** `1648a508ef41dca62f4eed5028069617d65bc7beddca11435ea1000c015c615a`

> **No selector was run to build this file.** `Candidate hints` lists every hint
> declared for that character in the static catalogue — it is *not* a prediction.
>
> Fill in **Valid hints**, **Rationale** and **Ambiguity** yourself. Ground truth
> may contain **one or more** hint ids, and should answer *"which hints are
> reasonable for this player state?"* — not *"which one should the selector pick?"*

> **Pre-evaluation semantic corrections (2026-09-04, owner-approved).**
>
> 1. `h_mechanic_knows_resistance` — untied from PKM (Option C). It combines a
>    partial circuit-continuity idea with a forensic inference no PKM concept
>    covers, so it is a **contextual/forensic** hint.
> 2. `h_butler_knows_rule` — `dual_lock_rule` is **not** a PKM concept
>    (Option B). `dual_lock_rule_taught` is written by pressing "Continue" and
>    has no comprehension check, so it records **tutorial exposure**. The
>    prerequisite is retained as `requires_story_flags`, a story/context
>    requirement that never implies comprehension.
>
> Both hint ids are historical and deliberately unchanged. **No scenario state
> was altered by either correction.**


## Hint reference

| Hint | Source | Teaches | Requires evidence | Requires ABSENT | Requires story flag (context) | Requires concept (PKM) |
|---|---|---|---|---|---|---|
| `h_butler_knows_rule` | authored | — | — | `fake_red_stain` | `dual_lock_rule_taught` | — |
| `h_butler_no_evidence` | shipped | `dual_lock_rule` | — | `fake_red_stain` | — | — |
| `h_butler_stain` | shipped | — | `fake_red_stain` | — | — | — |
| `h_gardener_knows_reflection` | authored | — | — | `greenhouse_pollen` | — | `reflection` |
| `h_gardener_no_evidence` | shipped | — | — | `greenhouse_pollen` | — | — |
| `h_gardener_pollen` | shipped | — | `greenhouse_pollen` | — | — | — |
| `h_mechanic_knows_resistance` | authored | — | — | `deliberate_short_circuit` | — | — |
| `h_mechanic_no_evidence` | shipped | — | — | `deliberate_short_circuit` | — | — |
| `h_mechanic_short_circuit` | shipped | — | `deliberate_short_circuit` | — | — | — |

> **Story flags constrain contextual appropriateness only.** Satisfying one
> implies nothing about comprehension and takes no part in redundancy analysis.

### Authored text

- **`h_butler_knows_rule`** — "You already know how Ashford sealed this place, so I will not lecture you on locks. What I can tell you is that the hallway floor was wet when I started, and I was not the one who wet it."
- **`h_butler_no_evidence`** — "I was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms."
- **`h_butler_stain`** — "I already told you, I only cleaned the hallway. That red stain has nothing to do with me."
- **`h_gardener_knows_reflection`** — "You have been reading about how leaves take their colour, so you will understand this: the deep-room pollen is the wrong shade for anything I grow. Whatever carried it in did not come from my benches."
- **`h_gardener_no_evidence`** — "I was working near the greenhouse earlier. I did not enter the locked rooms."
- **`h_gardener_pollen`** — "Pollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything."
- **`h_mechanic_knows_resistance`** — "You have had your hands on the bench, so you know what a low-resistance path does to a line. Old wiring fails slowly. Whatever happened here did not fail slowly."
- **`h_mechanic_no_evidence`** — "The lights in this castle fail all the time. Old wiring, old walls, old problems."
- **`h_mechanic_short_circuit`** — "A short circuit? I maintain the castle wiring, but anyone could have damaged that panel."

---

## Batch 1 of 6  ·  scenarios 1–8

### `h_chem_both_stain_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_both` — Both chemistry checks completed.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `butler_challenge_complete`, `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=DEMONSTRATED, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_butler_stain_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_butler` — Passed the Butler's test; indicator reaction demonstrated.
- **Evidence held:** `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `butler_challenge_complete`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=DEMONSTRATED, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_all_three_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_none_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_stain_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_stain_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_intro_stain_pollen_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_intro` — Read Mrs. Lin's lab note; nothing demonstrated yet.
- **Evidence held:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |


---

## Batch 2 of 6  ·  scenarios 9–16

### `h_chem_sorted_none_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_sorted_pollen_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_sorted_pollen_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_sorted_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_sorted_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_chem_sorted_stain_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `chem_sorted` — Cleared the sample tray; classification demonstrated.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `chemistry_change_sorted`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_all_benches_none_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_all_benches` — All three benches cleared; power restored.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_all_benches_pollen_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `circuit_all_benches` — All three benches cleared; power restored.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |


---

## Batch 3 of 6  ·  scenarios 17–24

### `h_circuit_all_benches_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_all_benches` — All three benches cleared; power restored.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_all_benches_short_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `circuit_all_benches` — All three benches cleared; power restored.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_one_bench_all_three_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_one_bench` — Cleared Junction Bench I only; continuity demonstrated.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `indicator_reaction`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_one_bench_none_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_one_bench` — Cleared Junction Bench I only; continuity demonstrated.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_one_bench_pollen_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `circuit_one_bench` — Cleared Junction Bench I only; continuity demonstrated.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_one_bench_pollen_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `circuit_one_bench` — Cleared Junction Bench I only; continuity demonstrated.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_regulation_none_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_regulation` — Cleared Bench II; regulation demonstrated, fault isolation not.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_regulation_pollen_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `circuit_regulation` — Cleared Bench II; regulation demonstrated, fault isolation not.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |


---

## Batch 4 of 6  ·  scenarios 25–32

### `h_circuit_regulation_stain_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_regulation` — Cleared Bench II; regulation demonstrated, fault isolation not.
- **Evidence held:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED, `indicator_reaction`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_studied_none_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `circuit_studied` — Studied the repair map on site; no bench cleared.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_studied_none_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_studied` — Studied the repair map on site; no bench cleared.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_circuit_studied_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `circuit_studied` — Studied the repair map on site; no bench cleared.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **PKM states (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_additive_filed_reflection_solved_none_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_additive_filed_reflection_solved` — Additive filed but unsolved; reflection filed and solved.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `reflection`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_additive_filed_reflection_solved_pollen_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_additive_filed_reflection_solved` — Additive filed but unsolved; reflection filed and solved.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `reflection`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_additive_filed_reflection_solved_stain_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_additive_filed_reflection_solved` — Additive filed but unsolved; reflection filed and solved.
- **Evidence held:** `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_all_filed_none_solved_none_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_all_filed_none_solved` — All three records filed; no challenge solved yet.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |


---

## Batch 5 of 6  ·  scenarios 33–40

### `h_library_all_filed_none_solved_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_all_filed_none_solved` — All three records filed; no challenge solved yet.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_all_filed_none_solved_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `library_all_filed_none_solved` — All three records filed; no challenge solved yet.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_all_solved_all_three_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_all_solved` — All three library concepts filed and all three solved.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_all_solved_pollen_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_all_solved` — All three library concepts filed and all three solved.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=DEMONSTRATED, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_all_solved_stain_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `library_all_solved` — All three library concepts filed and all three solved.
- **Evidence held:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_filed_none_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_reflection_filed` — Filed the reflection record; challenge not attempted.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_filed_stain_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_reflection_filed` — Filed the reflection record; challenge not attempted.
- **Evidence held:** `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_filed_stain_pollen_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_reflection_filed` — Filed the reflection record; challenge not attempted.
- **Evidence held:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |


---

## Batch 6 of 6  ·  scenarios 41–48

### `h_library_reflection_solved_none_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_reflection_solved` — Solved the reflection challenge; green filter recovered.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_solved_pollen_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_reflection_solved` — Solved the reflection challenge; green filter recovered.
- **Evidence held:** `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_solved_pollen_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `library_reflection_solved` — Solved the reflection challenge; green filter recovered.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_reflection_solved_stain_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_reflection_solved` — Solved the reflection challenge; green filter recovered.
- **Evidence held:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **PKM states (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_spectrum_filed_pollen_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_spectrum_filed` — Filed the spectrum record only; challenge not attempted.
- **Evidence held:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `spectrum`=LEARNING
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_spectrum_filed_short_circuit_butler`

- **NPC:** butler  ·  **Room:** castle_hall
- **Stage:** `library_spectrum_filed` — Filed the spectrum record only; challenge not attempted.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `spectrum`=LEARNING
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_two_filed_one_solved_none_mechanic`

- **NPC:** mechanic  ·  **Room:** castle_hall
- **Stage:** `library_two_filed_one_solved` — Spectrum and reflection filed; only spectrum solved.
- **Evidence held:** _none_
- **Knowledge items:** _none_
- **Progression flags:** `door_library_unlocked`, `dual_lock_rule_taught`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=LEARNING, `spectrum`=DEMONSTRATED
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_knows_resistance`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

### `h_library_two_filed_one_solved_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** castle_hall
- **Stage:** `library_two_filed_one_solved` — Spectrum and reflection filed; only spectrum solved.
- **Evidence held:** `deliberate_short_circuit`
- **Knowledge items:** _none_
- **Progression flags:** `blackout_deliberate`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_spectrum_knowledge_learned`
- **PKM states (non-UNSEEN):** `reflection`=LEARNING, `spectrum`=DEMONSTRATED
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_knows_reflection`
- **Reachability:** validated

| Field | Your answer |
|---|---|
| **Valid hints** (≥1) | |
| **Rationale** | |
| **Ambiguity note** | |

