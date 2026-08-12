# Development History

This page turns the repository history into a concise portfolio narrative. The milestone labels below are retrospective groupings of the dated Git commits, so the timeline can be audited from the commit log rather than treated as a vague claim of progress.

## v0.1 — Foundation: movement, maze, and atmosphere

**July 10, 2026**

The project began as a Godot prototype with player movement and a castle maze. The first visual-system iterations focused on limited visibility: a circular flashlight fog was implemented, then refined so walls blocked vision rather than simply darkening the whole map.

**What this established:** a readable top-down control scheme, a playable castle space, and a strong mystery atmosphere.

**Representative commits:** `7b84be9`, `349b4ab`, `6ecc8dd`.

## v0.2 — Investigation loop and consequence system

**July 11, 2026**

The next pass gave exploration stakes. A Castle Guardian uses A* pathfinding to chase the player; collision triggers a failure state. Dialogue pauses the chase so reading and decision-making remain fair rather than becoming a reflex test.

**What this established:** the tension/release rhythm of exploring, observing, talking, and escaping.

**Representative commits:** `530726f`, `c8698e6`.

## v0.3 — Castle expansion and detective structure

**July 12, 2026**

The prototype became a detective game rather than a maze. This version added a larger castle map and camera follow, evidence-board views, named suspects, biology evidence, a final deduction room, an accusation ending, a collapsible objective panel, and restart/menu shortcuts.

**Design decision:** evidence was written to be suggestive without being automatically conclusive. This supports the central detective skill: separating a clue from proof.

**Representative commits:** `ae74183`, `a64a450`, `fe5c2e2`, `0804d87`, `afb6f4f`, `7196553`, `be89982`, `43d6f4b`, `401a5e3`.

## v0.4 — STEM gates and cross-room reasoning

**July 13, 2026**

This pass added locked-door STEM puzzles and required players to learn a relevant clue before attempting a lock. The goal was to make the educational material part of the game loop, not a disconnected quiz screen.

**What this established:** a concrete connection between observation, knowledge, and progression.

**Representative commits:** `ca385da`, `8a45b9f`.

## v0.5 — Onboarding and information clarity

**July 14–15, 2026**

The project received an animated intro, clearer main-menu handling, a wake-room background pass, a first knowledge gate, and a notes tool shown above puzzle overlays. These changes addressed a key usability problem: players needed to understand both their immediate objective and where to revisit evidence.

**Representative commits:** `f94f95a`, `0e7b2c7`, `6d67566`, `0c96509`, `ed59f82`.

## v0.6 — Production polish: saves, room integration, and animated NPCs

**August 12, 2026**

The final polish pass focused on a more complete delivery: menu and checkpoint work, interaction cleanup, dedicated room backgrounds/props, and an NPC art-system replacement. The final NPCs use transparent 4 × 4 sprite sheets with four walking frames in each of four directions.

| Character | Gameplay role | Final placement |
| --- | --- | --- |
| Dr. Lin | Missing researcher / memory clue | Blue-tinted vision-memory echo in the Chemistry Room |
| Butler | Suspect | Chemistry Room |
| Gardener | Suspect | Greenhouse Room |
| Mechanic | Suspect | Circuit Room |
| Castle Guardian | Pursuer | Castle Hall chase system |

The reusable [`AnimatedNpc`](../scripts/animated_npc.gd) component turns each sheet into walk and idle animations, adds optional small patrol movement, and keeps all ordinary NPCs consistent. The Guardian uses the same art-sheet specification inside its own pathfinding scene.

See [Character Art Pipeline](ART_PIPELINE.md) for the documented visual iterations.

## v0.7 — Archive-system redesign: evidence chains, reversible failure, and dual endings

**August 12, 2026**

The closing sequence was rebuilt after a design review found that the old final room behaved like a linear quiz. The replacement is an Ashford analysis table: the player selects two or three raw records, forms one of five case conclusions, and seats each conclusion in a matching radial brass slot. A wrong pairing dims the connection and explains the contradiction, but does not erase progress or consume evidence.

The ordinary resolution deliberately identifies the **Butler as the executor**, not the full author of the crime. The follow-up path avoids an automatic “perfect ending” unlock. After the ordinary case closes, three unmarked Sealed Archives can be found by revisiting existing objects in the Dining Hall, Circuit Room, and Library. Players must read and manually pin all three records in Note Hub before the same table reveals a second, three-link command chain:

1. The Butler's pressure and motive to obey an emergency order.
2. The forged Mechanical Office instruction that appeared legitimate.
3. Dr. Lin's decision to deny the Mechanic funding and expose unauthorized copies.

Completing that chain exposes the **Mechanic** as the person who forged the order, weaponized the Butler's trust, and attempted to claim Dr. Lin's research. This structure distinguishes physical action from authorship, so the player has a reason to revisit evidence rather than merely collect every clue.

The alchemy screen was also revised from auto-filled ingredients into a small experiment: choose a recipe, place its three condensed materials into any order across three reaction nodes, preserve the fourth violet stabilizer node, then pull the extraction lever. Incorrect setups create explanatory violet smoke and consume nothing; only a valid arrangement reaches the existing crafting and inventory path.

**Technical decisions:** `FinalCaseBoard` is a dedicated Godot Module with a narrow Interface (`open_case`, `close_case`, and ending signals). It owns the case-board state; `final_room.gd` owns only room state and narrative handoff. Sealed-archive pinning is persisted through the existing Note Hub save payload, so the true-ending investigation survives a restart.

**Representative commit:** this milestone is recorded in the repository immediately after the archive UI foundation commit `4c33790`.

## Reflection

The main lesson from this project is that a feature is only useful when its information is legible to the player. The major revisions repeatedly made hidden game state visible: fog became wall-aware, dialogue paused danger, locks required learned clues, objectives and notes stayed accessible, and character art was revised from an unsuitable realistic concept to small readable pixel sprites that match the player and rooms. The final redesign added a related lesson: a detective game should let the player revise a theory without punishing experimentation, while still making the difference between an executor and the author of a crime meaningful.
