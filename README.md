# Shadow Castle: STEM Detective

**Shadow Castle: STEM Detective** is a 2D pixel-art mystery game made in Godot 4. Players investigate a blackout at a magical castle, gather evidence, solve science-based locks, test suspect alibis, and make a final accusation.

The project combines a narrative detective loop with accessible STEM reasoning. Clues are not merely collectibles: the player must distinguish a lead from proof, connect evidence across rooms, and use what they learn to unlock the next part of the case.

## Playable highlights

- Top-down castle exploration with click-to-move and camera follow.
- A chase system using A* pathfinding, physical collision, and a game-over/retry loop.
- A two-phase Guardian: it tracks you anywhere while a serum runs in your blood and gains 12% speed per recovered room key, until you brew the Purification Potion. After that it hunts by a real sight cone, stakes out your next objective doorway, and can be answered with Daze and Shroud potions.
- Investigation rooms for chemistry, biology, circuits, archives, dining, and the final deduction.
- STEM-inspired locks and evidence: alchemy ingredients, pollen evidence, an electrical repair sequence, and timeline reasoning.
- Dialogue, evidence board, notes, maps, objective panel, inventory, checkpoint, and main-menu flows.
- A unified detective field kit with four task-specific Hubs: Bag files everything under four authored tabs (All, Potions, Materials, Papers), while Key, Note, and Map act as lock register, dossier reader, and tactical survey table. Their redesigned grids sit inside fitted original artwork with rendered-text, containment, and coordinate contracts.
- A power-gated exploration model: before the Circuit generator is restored, walls and walked routes disappear into pure black outside the flashlight on both maps; afterward, walked ground becomes persistent gray memory while unwalked ground remains black.
- A staged Circuit-restoration milestone with generator impact, workshop light flicker, original synthesized electrical audio, progressive Hall route scanning, an explicit route-memory-online status and an immediate Map reward.
- Measured pre-Circuit pacing on the real A* route: three safe-room-separated darkness exposures and at least 4.32 seconds of Hall-return reaction at Tier 2 Guardian escalation.
- Five animated pixel NPCs: Dr. Lin, Butler, Gardener, Mechanic, and Castle Guardian.
- A two-layer finale: an ordinary case against the Butler, followed by optional sealed-archive review that exposes the Mechanic's forged command chain.
- A manual alchemy interaction: three player-loaded material nodes, a violet stabilizer core, non-destructive error feedback, and a brass extraction lever.
- A Library optics laboratory: read three knowledge records from distant shelves, then clear three five-stage light games — prism dispersion ordering, pigment reflection/absorption, and additive colour mixing — and insert the earned RGB filters to reveal the archive layer.

## Technology

- **Engine:** Godot 4.7
- **Language:** GDScript
- **Format:** 2D pixel art, 1024 × 768 viewport

## Run locally

1. Install Godot 4.7 or a compatible Godot 4 release.
2. Import [`project.godot`](project.godot) in the Godot Project Manager.
3. Run the project with `F6`/`F5` from the editor.

## Portfolio documentation

- [Current project status](docs/PROJECT_STATUS.md) — active development phase, implemented flow, and final acceptance focus.
- [Agent continuation handoff](docs/AGENT_HANDOFF.md) — concrete system map, current safeguards, validation flow, and next priorities.
- [Development history](docs/DEVELOPMENT_HISTORY.md) — versioned milestones reconstructed from Git history plus local review-ready stages, including technical decisions, evidence, and publication status.
- [Character art pipeline](docs/ART_PIPELINE.md) — the three visual passes, why an early concept was rejected, and how the final sprite sheets were imported.

## Project structure

| Folder | Purpose |
| --- | --- |
| `scenes/` | Godot scenes for the castle, rooms, UI, player, and guardian. |
| `scripts/` | Gameplay, room logic, HUD systems, interactions, and NPC animation code. |
| `assets/` | Pixel character sheets, portraits, room backgrounds, props, UI, and navigation data. |
| `autoload/` | Persistent game state and save/checkpoint logic. |
| `docs/` | Development history and art-process documentation for portfolio review. |

## Attribution note

The final NPC images were generated as art-directed source material, then reviewed, selected, made transparent, arranged into gameplay sprite sheets, and integrated in Godot. The art process is documented transparently in [the character art pipeline](docs/ART_PIPELINE.md).
