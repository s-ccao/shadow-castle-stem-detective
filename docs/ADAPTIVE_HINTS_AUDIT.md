# Day 1 — State audit

Everything here was read out of the shipped game. No id in this document is
invented; each one appears in `scripts/` or `autoload/` and can be grepped.

Audit date: 2026-09-01.

---

## A. The guidance surfaces

Three characters can be questioned, all instantiated in
[`scripts/game_world.gd`](../scripts/game_world.gd) and offered as accusation
options in [`scripts/final_room.gd`](../scripts/final_room.gd).

| NPC | Dialogue function | Branches on | Variants |
|---|---|---|---|
| Butler | `show_butler_dialogue()` — `game_world.gd:4258` | `evidence_items.has("fake_red_stain")` | 2 |
| Gardener | `show_gardener_dialogue()` — `game_world.gd:4378` | `evidence_items.has("greenhouse_pollen")` | 2 |
| Mechanic | `show_mechanic_dialogue()` — `game_world.gd:4501` | `evidence_items.has("deliberate_short_circuit")` | 2 |

Two further characters exist as world props only — `MechanicNPC` in
`circuit_room.gd:475` and `GardenerNPC` in `greenhouse_room.gd:387` — and carry
no dialogue. `AnimatedNpc` states the design position plainly:

> The cast stands its ground. […] Each one holds its authored mark and its
> authored pose, and the only thing that changes is that it turns to meet a
> player who comes over.

### The finding that motivates the whole project

**Every branch in the shipped hint system tests evidence. None tests
knowledge.** The Butler's no-evidence line explains that "Lord Ashford built
those knowledge locks everywhere" — and it says that whether or not the player
has already been taught the dual-lock rule, which the game separately records as
the `dual_lock_rule_taught` story flag.

So redundant guidance is not an occasional slip. It is structural: the state
that would prevent it is tracked, and never consulted.

This is Condition A, and it is a *real product baseline* rather than a weak one
built for the experiment.

## B. Where "demonstrated knowledge" actually lives

The audit's most consequential surprise. Knowledge is **split across two
systems**, and a naive adaptive selector that reads only one would be wrong
about most of the game.

**1. `GameState.knowledge_items`** — exactly one id reaches it:

| Knowledge id | Granted at |
|---|---|
| `current_resistance` | `game_world.gd:5717` via `add_knowledge_item()` |

**2. `GameState.story_flags`** — the library's three science concepts are
recorded here instead, by `_on_library_knowledge_recorded()` at
`library_room.gd:740`, which writes `"library_%s_knowledge_learned"`:

| Concept | Flag | Record defined in |
|---|---|---|
| `spectrum` | `library_spectrum_knowledge_learned` | `library_knowledge_shelf_ui.gd:8` |
| `reflection` | `library_reflection_knowledge_learned` | `library_knowledge_shelf_ui.gd:20` |
| `additive` | `library_additive_knowledge_learned` | `library_knowledge_shelf_ui.gd:32` |

Additional teaching flags that mark a concept as delivered:

| Flag | Meaning |
|---|---|
| `dual_lock_rule_taught` | Player has been taught that doors need key **and** knowledge |
| `greenhouse_refining_learned` | Refining procedure taught |
| `gardener_circuit_map_explained` | Circuit map explained by the Gardener |
| `blackout_deliberate` | Player has concluded the blackout was deliberate |
| `dining_timeline_reconstructed` | Timeline reasoning completed |
| `circuit_repair_map_studied` | Repair map studied |
| `hall_first_route_core_studied` | Opening route reasoning studied |

**Consequence for the design:** "what the player has demonstrated" must be read
as `knowledge_items ∪ {concepts implied by story flags}`. Building the adaptive
selector against `knowledge_items` alone would see one concept out of eleven.

## C. Evidence

19 ids, via `add_evidence()`, `has_evidence()` and direct `evidence_items.has()`:

```
ashford_archive_record      deliberate_short_circuit   dining_red_cloth
dining_timeline             fake_red_stain             final_archive_document
greenhouse_pollen           library_rgb_archive_layer  master_archive_route
mechanic_missing_glove      mrs_lin_body               mrs_lin_glove_fragment
mrs_lin_notebook            mrs_lin_violet_fiber       service_corridor_dark_trail
service_corridor_fiber      stopped_midnight_clock     vault_vision_symbols
violet_insulating_fiber
```

Note `fake_red_stain` and `greenhouse_pollen` are granted by
`collect_red_stain_evidence()` (`game_world.gd:4044`) and
`collect_pollen_evidence()` (`game_world.gd:4359`), both of which call
`GameState.add_evidence()` **with the argument on a following line**.

A single-line regex over `add_evidence("...")` misses all three collectors, and
a first pass caught these two ids only incidentally, through the separate
`evidence_items.has(...)` reads in the dialogue branches. The same weakness was
hit twice during this audit.

**Extraction rule adopted as a result:** always match across newlines. The
reproducible form is:

```python
re.compile(r'(?:add_evidence|has_evidence|evidence_items\.has)\s*\(\s*"([a-z_0-9]+)"', re.S)
```

Re-running all three extractions multiline-aware confirms the counts in this
document — 19 evidence ids, 79 story flags, 1 knowledge id — so the numbers were
right, but an earlier draft's *explanation* of why these two ids were elusive
was wrong and has been corrected here.

## C2. Evidence mutation paths — is there more than one?

Chased to completion, because a harness that mocks only `add_evidence()` while
the game mutates state some other way would be constructing states with the
wrong semantics.

**There are three write paths, and they are not equivalent.**

| Path | Where | Semantics |
|---|---|---|
| `GameState.add_evidence()` | `game_state.gd:1084` | appends, then emits `state_changed` **and** `item_acquired` |
| `_add_debug_evidence()` | `game_state.gd:1346` | appends **silently** — no signals |
| `grant_developer_inventory()` | `game_state.gd:2053` | appends `DEV_EVIDENCE_IDS` **silently** |
| *(restore)* | `game_state.gd:355` | replaces wholesale from a save payload |

The two bypasses are **developer-only** — reached from the debug chapter-jump at
`game_state.gd:1259-1295` and from developer mode. No production gameplay path
avoids `add_evidence()`, so the game's normal semantics are single-path.

`DEV_EVIDENCE_IDS` lists 18 ids; adding `library_rgb_archive_layer` (absent from
that list) accounts for exactly the 19 catalogued above, which independently
confirms the catalogue is complete.

**Consequence for the harness.** The experiment builds state as plain
dictionaries, which matches the *debug* semantics — append without signals —
rather than production. That is harmless for the current metrics, none of which
observe `item_acquired`. It stops being harmless the moment a condition reacts
to a signal, and it is recorded here so that is a decision rather than a
surprise.

## D. Story flags

79 total. The full list is reproducible with:

```bash
grep -rhon 'set_story_flag("[a-z_0-9]*"\|has_story_flag("[a-z_0-9]*"' \
  scripts autoload --include=*.gd | sed 's/.*("//;s/"//' | sort -u
```

Groups that matter for hinting: `door_*_unlocked` (6 rooms), `*_key_found`,
the knowledge flags above, and the progression flags `hall_*`, `wake_*`,
`circuit_*`, `dining_*`, `final_*`.

## E. Rooms

`GUARDIAN_OBJECTIVE_ROOM_ORDER`, `autoload/game_state.gd:78`:

```
chemistry_room → greenhouse_room → circuit_room → library → dining_hall
→ final_deduction_room
```

## F. Knowledge dependency graph

Concepts the player can demonstrate, and what each one gates. Prerequisites are
drawn from the puzzle structure described in
[`docs/PAPER.md`](PAPER.md) and the shelf records.

```
dual_lock_rule_taught ──► (gates every locked door: key AND knowledge)

spectrum ──────┐
               ├──► library_rgb_puzzle_solved ──► library_rgb_archive_layer
additive ──────┤                                  (sealed archive access)
reflection ────┘
   │
   └──► photosynthesis reasoning (greenhouse)

current_resistance ──► circuit_power_restored ──► blackout_deliberate
                                                   │
                                                   └──► deliberate_short_circuit

greenhouse_refining_learned ──► tracking_serum_purified

dining_timeline_reconstructed ──► stopped_midnight_clock ──► dining_timeline
```

Eleven concepts is inside the 10–20 target. Not expanding further: the
scenario set has to annotate each one by hand, and a graph larger than the
scenarios can cover is decoration.

## G. Hint catalogue — the two shipped variants per NPC

Verbatim, so the redundancy claim can be checked rather than believed. Ids are
assigned by this project (`h_*`); everything else is quoted from the game.

| hint_id | NPC | Fires when | Redundant once |
|---|---|---|---|
| `h_butler_no_evidence` | Butler | `fake_red_stain` absent | `dual_lock_rule_taught` — **confirmed** |
| `h_butler_stain` | Butler | `fake_red_stain` present | — |
| `h_gardener_no_evidence` | Gardener | `greenhouse_pollen` absent | — |
| `h_gardener_pollen` | Gardener | `greenhouse_pollen` present | — |
| `h_mechanic_no_evidence` | Mechanic | `deliberate_short_circuit` absent | — |
| `h_mechanic_short_circuit` | Mechanic | `deliberate_short_circuit` present | — |

### The confirmed case

`dual_lock_rule_taught` is set in the opening at `wake_room.gd:2306`, and the
lesson it delivers is described in the source as:

> a key opens the door, a question guards it, and the answer is always
> something learned somewhere else.

`h_butler_no_evidence` then says "Lord Ashford built those knowledge locks
everywhere… That explains why many paths require scientific reasoning." That is
the same rule, re-delivered to a player who has already been taught it and
cannot have reached the Butler without passing through the opening.

### A claim this audit withdrew

An earlier draft listed `h_mechanic_short_circuit` as redundant once
`current_resistance` is known. **That was wrong, and checking it mattered.**
Neither Mechanic line explains current or resistance; the line that does —
"A short circuit creates a path with very low resistance" at
`game_world.gd:4477` — belongs to Mrs. Lin's clue dialogue, not the Mechanic.

A second hypothesis, that a player might hold `blackout_deliberate` while
lacking `deliberate_short_circuit` and so hear the Mechanic call the blackout
routine, is also **unreachable**: `circuit_room.gd:609-610` sets both on
adjacent lines, so they are permanently in lockstep.

### The real ceiling, stated plainly

**One of six shipped lines is redundancy-prone.** On the shipped catalogue
alone, the maximum achievable reduction in redundant hinting is therefore small,
and no amount of modelling will change that.

This is the single most important number in the audit, and the temptation is to
inflate it by inventing hints the game does not contain. That would make every
downstream result meaningless. Two honest options remain:

1. **Report the real ceiling** on the shipped catalogue, and let the headline
   number be small.
2. **Author additional knowledge-conditioned hints** as a deliberate, declared
   contribution — the game currently has *none*, since every branch tests
   evidence. New hints must then be presented as new game content that the
   experiment evaluates, never as pre-existing behaviour.

Both are legitimate. Doing 2 while describing it as 1 is not.

## H. What this means for the experiment

1. Condition A is genuinely evidence-only, so `RedundantHintRate > 0` is
   demonstrable rather than assumed — but on the shipped catalogue it is driven
   by exactly one line.
2. Condition B must read knowledge from **both** `knowledge_items` and
   `story_flags`, or it will be blind to ten of eleven concepts.
3. `blackout_deliberate` and `deliberate_short_circuit` are always set together.
   A rule-based selector must not treat them as independent signals, and a
   scenario that sets one without the other is testing an unreachable state.
4. `no_leak` and `no_fabrication` from the earlier design become largely moot
   once the system *selects* authored hints instead of generating text — a
   selector cannot confabulate. They stay relevant only if free generation is
   ever revisited.
5. Because the shipped ceiling is small, the honest headline for Week 1 is
   likely to be *"the shipped system is redundant in one identifiable place, and
   a deterministic selector removes it"* — not a large percentage improvement.
