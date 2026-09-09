# Held-out heldout-v2 — annotation worksheet

**Protocol:** `heldout-v2` · **Scenarios:** 48 · **State fingerprint:** `e1979c1a75a83326f58770a86b937150c9381ed7b96333b8640fbe4dc0fd0404`

> **No selector was run to build this file.** `Candidate hints` lists every
> hint declared for that character in the static catalogue — it is *not* a
> prediction, and no Condition A / B / C logic was consulted.
>
> Fill in **Valid hints**, **Rationale** and **Ambiguity** yourself. Ground
> truth may contain **one or more** hint ids, and answers *"which hints are
> reasonable for this player state?"* — not *"which one should the selector
> pick?"*

> **Why v2 supersedes v1.** A source audit found that heldout-v1 placed every
> scenario in `castle_hall`, where no NPC is reachable: `game_world.gd` spawns
> the three characters but has no interaction dispatch for them, and commit
> `505f008` deleted the dialogue it once called. v2 places each character in
> the room where their dialogue is actually reachable and adds the door flag
> that entering that room requires. **No evidence and no knowledge state was
> changed to improve balance.** heldout-v1 is preserved byte-identical and
> marked `PRE-EVALUATION SUPERSEDED`; it was never annotated and no selector
> was ever run against it.


## Hint reference

| Hint | NPC | Source | Teaches (PKM) | Requires evidence | Requires ABSENT | Requires story flag | Soft preference |
|---|---|---|---|---|---|---|---|
| `h_butler_knows_rule` | butler | authored | — | — | `fake_red_stain` | — | `indicator_reaction` |
| `h_butler_no_evidence` | butler | legacy_grounded | `dual_lock_rule` | — | `fake_red_stain` | — | — |
| `h_butler_stain` | butler | legacy_grounded | — | `fake_red_stain` | — | — | — |
| `h_gardener_knows_reflection` | gardener | authored | — | — | `greenhouse_pollen` | — | `reflection` |
| `h_gardener_leaf_colour` | gardener | authored | `reflection` | — | — | — | — |
| `h_gardener_no_evidence` | gardener | legacy_grounded | — | — | `greenhouse_pollen` | — | — |
| `h_gardener_pollen` | gardener | legacy_grounded | — | `greenhouse_pollen` | — | — | — |
| `h_mechanic_knows_resistance` | mechanic | authored | — | — | `deliberate_short_circuit` | — | `circuit_fault_isolation` |
| `h_mechanic_no_evidence` | mechanic | legacy_grounded | — | — | `deliberate_short_circuit` | — | — |
| `h_mechanic_series_basics` | mechanic | authored | `circuit_continuity` | — | — | — | — |
| `h_mechanic_short_circuit` | mechanic | legacy_grounded | — | `deliberate_short_circuit` | — | — | — |

> **`teaches`** names a real PKM v1 concept only where the hint text
> genuinely explains it. **Soft preference** (`preferred_when_demonstrated`) marks a hint as *especially* appropriate
> once a concept is DEMONSTRATED. It is **not** a prerequisite: an
> unsatisfied preference never makes a hint invalid and is never a state
> violation. Condition A ignores it entirely.
>
> **Story flags constrain contextual appropriateness only.** Satisfying one
> implies nothing about comprehension.


### Hint text

- **`h_butler_knows_rule`** — "I heard glass break in this room, followed by quick, heavy footsteps heading toward the greenhouse wing."
- **`h_butler_no_evidence`** — "I was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms."
- **`h_butler_stain`** — "I already told you, I only cleaned the hallway. That red stain has nothing to do with me."
- **`h_gardener_knows_reflection`** — "That dark pollen is the wrong kind for anything I grow here. Something carried deep-room traces onto my tools."
- **`h_gardener_leaf_colour`** — "You want to know why my beds look the way they do? A healthy leaf takes in the red and blue light and throws the green back at you. What reaches your eye is the light it did not keep."
- **`h_gardener_no_evidence`** — "I was working near the greenhouse earlier. I did not enter the locked rooms."
- **`h_gardener_pollen`** — "Pollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything."
- **`h_mechanic_knows_resistance`** — "The blackout did not start at these generators. Someone came through the workshop's maintenance route and left them to take the blame."
- **`h_mechanic_no_evidence`** — "The lights in this castle fail all the time. Old wiring, old walls, old problems."
- **`h_mechanic_series_basics`** — "Castle wiring runs in series. Every link has to conduct or the whole run stays dark — and a resistor still counts as a conductor, it only slows the current. That is the first thing anyone learns at my bench."
- **`h_mechanic_short_circuit`** — "A short circuit? I maintain the castle wiring, but anyone could have damaged that panel."

---

## Batch 1 of 6  ·  scenarios 1–8

### `h_chem_both_stain_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=DEMONSTRATED, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `butler_challenge_complete`, `butler_challenge_given`, `chemistry_change_sorted`, `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_butler_stain_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=DEMONSTRATED, `physical_chemical_change`=LEARNING
- **Story flags:** `butler_challenge_complete`, `butler_challenge_given`, `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_all_three_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_circuit_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_none_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_circuit_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_stain_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_stain_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_intro_stain_pollen_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 2 of 6  ·  scenarios 9–16

### `h_chem_sorted_none_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `chemistry_change_sorted`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_sorted_pollen_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `chemistry_change_sorted`, `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_sorted_pollen_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_change_sorted`, `door_circuit_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_sorted_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `chemistry_change_sorted`, `door_circuit_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_sorted_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_change_sorted`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_chem_sorted_stain_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_change_sorted`, `door_chemistry_unlocked`, `dual_lock_rule_taught`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_all_benches_none_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_all_benches_pollen_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 3 of 6  ·  scenarios 17–24

### `h_circuit_all_benches_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_all_benches_short_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_power_restored`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_one_bench_all_three_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `indicator_reaction`=LEARNING
- **Story flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_one_bench_none_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_one_bench_pollen_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_one_bench_pollen_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_regulation_none_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_regulation_pollen_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 4 of 6  ·  scenarios 25–32

### `h_circuit_regulation_stain_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED, `indicator_reaction`=LEARNING
- **Story flags:** `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_studied_none_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_studied_none_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_circuit_studied_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `circuit_repair_map_studied`, `door_circuit_unlocked`, `dual_lock_rule_taught`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_additive_filed_reflection_solved_none_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_additive_filed_reflection_solved_pollen_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_additive_filed_reflection_solved_stain_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_all_filed_none_solved_none_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 5 of 6  ·  scenarios 33–40

### `h_library_all_filed_none_solved_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_all_filed_none_solved_short_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `reflection`=LEARNING, `spectrum`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_circuit_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_all_solved_all_three_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_all_solved_pollen_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_all_solved_stain_pollen_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED, `spectrum`=DEMONSTRATED
- **Story flags:** `door_circuit_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_green_filter_earned`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_rgb_puzzle_solved`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_filed_none_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=LEARNING
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_filed_stain_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=LEARNING
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_filed_stain_pollen_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=LEARNING
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 6 of 6  ·  scenarios 41–48

### `h_library_reflection_solved_none_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_solved_pollen_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_solved_pollen_circuit_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `door_circuit_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_reflection_solved_stain_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_spectrum_filed_pollen_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `spectrum`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_spectrum_filed_short_circuit_butler`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `spectrum`=LEARNING
- **Story flags:** `blackout_deliberate`, `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_two_filed_one_solved_none_mechanic`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=LEARNING, `spectrum`=DEMONSTRATED
- **Story flags:** `door_circuit_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `h_library_two_filed_one_solved_short_circuit_gardener`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=LEARNING, `spectrum`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `library_red_filter_earned`, `library_reflection_knowledge_learned`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

