# Held-out heldout-v3 — annotation worksheet

**Protocol:** `heldout-v3` · **Scenarios:** 48 · **State fingerprint:** `1b934b73123561d0e88daf14bfc8044dba0e72781f3a7a8192095c939a961c5d`

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

### `v3_chemi_butler_f_dem_libl_08`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `indicator_reaction`=DEMONSTRATED
- **Story flags:** `butler_challenge_complete`, `butler_challenge_given`, `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: examine and record the red stain → Library: read the additive shelf → Chemistry: answer the Butler's stain question correctly → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_chemi_butler_f_uns_libn_03`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** — (all UNSEEN)
- **Story flags:** `door_chemistry_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: examine and record the red stain → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_chemi_butler_none_lea_libd_08`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: read Mrs. Lin's lab note → Library: read the additive shelf → Library: solve the Additive Relay → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_chemi_butler_none_lea_libd_08_2`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: read Mrs. Lin's lab note → Library: read the reflection shelf → Library: solve the Reflection Matrix → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_chemi_butler_none_lea_libd_08_3`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING, `spectrum`=DEMONSTRATED
- **Story flags:** `door_chemistry_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_library_collected`, `library_red_filter_earned`, `library_spectrum_knowledge_learned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: read Mrs. Lin's lab note → Library: read the spectrum shelf → Library: solve the Spectrum challenge → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_butler_dfg_dem_libl_17`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `indicator_reaction`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `butler_challenge_complete`, `butler_challenge_given`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Chemistry: answer the Butler's stain question correctly → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_butler_dg_uns_libn_13`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_butler_fg_dem_libd_19`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED, `indicator_reaction`=DEMONSTRATED
- **Story flags:** `butler_challenge_complete`, `butler_challenge_given`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Chemistry: answer the Butler's stain question correctly → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Circuit: clear the regulator bench → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 2 of 6  ·  scenarios 9–16

### `v3_circu_butler_fg_lea_libd_14`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: read Mrs. Lin's lab note → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_butler_g_lea_libd_14`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: read Mrs. Lin's lab note → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_dfg_dem_libd_14`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: workbench journal (deliberate short circuit) → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_dfg_uns_libn_13`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_fg_dem_libd_13`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_fg_lea_libl_14`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `reflection`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_g_dem_libd_13`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_g_dem_libd_14`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `butler_challenge_given`, `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 3 of 6  ·  scenarios 17–24

### `v3_circu_gardener_g_dem_libd_14_2`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `physical_chemical_change`=DEMONSTRATED, `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `chemistry_change_sorted`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: complete the sample-tray sorting → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_gardener_g_lea_libd_18`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED, `reflection`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Circuit: clear the regulator bench → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dfg_dem_libd_16`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dfg_lea_libl_14`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dfg_lea_libl_14_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `reflection`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dg_dem_libd_18`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Circuit: clear the regulator bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dg_dem_libd_18_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=DEMONSTRATED, `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Circuit: clear the regulator bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_dg_lea_libd_15`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 4 of 6  ·  scenarios 25–32

### `v3_circu_mechanic_dg_lea_libd_15_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `deliberate_short_circuit`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `blackout_deliberate`, `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: workbench journal (deliberate short circuit) → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_fg_dem_libn_12`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=DEMONSTRATED, `circuit_regulation`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_diagnostic_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Circuit: clear the diagnostic (master switch) bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_fg_dem_libn_12_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_bench_regulator_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Circuit: clear the regulator bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_fg_lea_libd_14`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_fg_lea_libd_14_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=LEARNING, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_g_dem_libd_15`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_g_dem_libd_15_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_g_dem_libd_15_3`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `circuit_continuity`=DEMONSTRATED, `circuit_fault_isolation`=LEARNING, `circuit_regulation`=LEARNING, `spectrum`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `circuit_bench_continuity_cleared`, `circuit_repair_map_studied`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_red_filter_earned`, `library_spectrum_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the spectrum shelf → Hall: study the greenhouse exhibit → Library: solve the Spectrum challenge → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Circuit: study the repair blueprint on site → Circuit: clear the continuity bench → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 5 of 6  ·  scenarios 33–40

### `v3_circu_mechanic_g_uns_libd_13`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_circu_mechanic_g_uns_libd_13_2`

- **NPC:** mechanic  ·  **Room:** `circuit_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_circuit_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `greenhouse_circuit_key_found`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_circuit_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_mechanic_no_evidence`, `h_mechanic_short_circuit`, `h_mechanic_series_basics`, `h_mechanic_knows_resistance`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Greenhouse: inspect all 7 features (Circuit Room Key) → Hall: study the circuit exhibit → Hall: answer the Circuit knowledge lock → Return to circuit_room and talk to the mechanic

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_f_dem_libd_12`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=DEMONSTRATED
- **Story flags:** `butler_challenge_complete`, `butler_challenge_given`, `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Chemistry: answer the Butler's stain question correctly → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_f_lea_libd_11`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: read Mrs. Lin's lab note → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_fg_dem_libl_11`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=LEARNING, `indicator_reaction`=DEMONSTRATED
- **Story flags:** `butler_challenge_complete`, `butler_challenge_given`, `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: first words with the Butler (test issued) → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the additive shelf → Chemistry: answer the Butler's stain question correctly → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_fg_lea_libd_11`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: read Mrs. Lin's lab note → Chemistry: examine and record the red stain → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_g_uns_libn_06`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** — (all UNSEEN)
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_butler_none_lea_libd_11`

- **NPC:** butler  ·  **Room:** `chemistry_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `indicator_reaction`=LEARNING, `physical_chemical_change`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `mrs_lin_lab_note_seen`
- **Candidate hints:** `h_butler_no_evidence`, `h_butler_stain`, `h_butler_knows_rule`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: read Mrs. Lin's lab note → Library: read the additive shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Return to chemistry_room and talk to the butler

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |


---

## Batch 6 of 6  ·  scenarios 41–48

### `v3_green_gardener_f_dem_libd_10`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_f_uns_libn_06`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** — (all UNSEEN)
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: answer the Chemistry knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_fg_dem_libd_10`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_fg_lea_libl_09`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `fake_red_stain`, `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Chemistry: examine and record the red stain → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_g_dem_libd_10`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_g_lea_libd_11`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** `greenhouse_pollen`
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `reflection`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Greenhouse: workbench parchment (dark pollen evidence) → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_none_dem_libd_10`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `reflection`=DEMONSTRATED
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_green_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Reflection Matrix → Hall: answer the Greenhouse knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

### `v3_green_gardener_none_lea_libd_11`

- **NPC:** gardener  ·  **Room:** `greenhouse_room`
- **Evidence:** —
- **Knowledge items:** —
- **PKM (non-UNSEEN):** `additive`=DEMONSTRATED, `reflection`=LEARNING
- **Story flags:** `chemistry_cabinet_secret_found`, `door_chemistry_unlocked`, `door_greenhouse_unlocked`, `door_library_unlocked`, `dual_lock_rule_taught`, `hall_knowledge_chemistry_room_collected`, `hall_knowledge_greenhouse_room_collected`, `hall_knowledge_library_collected`, `library_additive_knowledge_learned`, `library_blue_filter_earned`, `library_reflection_knowledge_learned`
- **Candidate hints:** `h_gardener_no_evidence`, `h_gardener_pollen`, `h_gardener_leaf_colour`, `h_gardener_knows_reflection`
- **Witness path:** New game → Wake Room: read the briefing, take the Chemistry Room Key → Hall: study the chemistry exhibit → Hall: find the Library key and study the library exhibit → Hall: answer the Chemistry knowledge lock → Hall: answer the Library knowledge lock → Chemistry: open the potion cabinet (Greenhouse Key) → Library: read the additive shelf → Library: read the reflection shelf → Hall: study the greenhouse exhibit → Library: solve the Additive Relay → Hall: answer the Greenhouse knowledge lock → Return to greenhouse_room and talk to the gardener

| Field | Value |
|---|---|
| **Valid hints** | |
| **Rationale** | |
| **Ambiguity (low/med/high)** | |

