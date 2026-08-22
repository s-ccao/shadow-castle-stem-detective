# Shadow Castle: STEM Detective

**Shadow Castle: STEM Detective** is a 2D pixel-art mystery game made in Godot 4. Players investigate a blackout at a magical castle, gather evidence, solve science-based locks, test suspect alibis, and make a final accusation.

**▶ Play in your browser: [play.shadowcastledetective.com](https://play.shadowcastledetective.com/)** — no install required. Progress saves locally, and an optional account carries a run across devices.

| Greenhouse | Castle Hall under pursuit | Library optics lab |
| --- | --- | --- |
| ![Greenhouse](docs/screenshots/greenhouse.png) | ![Castle Hall](docs/screenshots/hall.png) | ![Library](docs/screenshots/library.png) |
| Segmented herb plots that regrow on a clock | Contact estimate, escalation tier, and fog-limited sight | RGB filters feeding the archive layer |

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
- A renewable greenhouse: ten segmented harvest points across four plantings, each growing its own herb on a real-time regrowth clock, feeding refining recipes that turn herbs into the reagents every potion needs.
- A guided opening that teaches without stopping the game: the Wake Room's six-step first lead, a Hall crossing paced so it stays survivable whether the player sprints or reads every label, and a scripted near-miss at the Chemistry door.

## Technology

- **Engine:** Godot 4.7
- **Language:** GDScript
- **Format:** 2D pixel art, 1024 × 768 viewport
- **Web build:** single-threaded WebAssembly export, served with a custom loading shell and a service worker that hands new versions to the game rather than reloading the page underfoot
- **Cloud saves:** optional accounts backed by serverless functions and private blob storage, using salted scrypt hashing, per-IP and per-account rate limiting, and revision checks so a stale device cannot overwrite newer progress

## Testing

Gameplay systems are covered by headless regression suites that run the real
scenes rather than mocks — a chase test instantiates the Hall, drives the
Guardian, and asserts on what the player would experience.

```bash
# Run one suite (exit code reports pass/fail)
godot --headless --path . --script res://tests/potion_economy_test.gd
```

Some suites encode design guarantees that are easy to regress silently:

| Suite | What it protects |
| --- | --- |
| `guardian_tutorial_chase_test.gd` | The guided first crossing stays survivable at any pace and still ends on a near-miss. |
| `potion_economy_test.gd` | Every potion is reachable from renewable input — it crafts the whole list, refining reagents on demand. |
| `panel_overflow_test.gd` | No panel renders text outside its own frame, measured against font extents rather than control rects. |
| `interaction_stops_walk_test.gd` | Interacting always halts a click-move, so the character never walks off on its own. |
| `room_spatial_audit.gd` | Every interactable is reachable from walkable floor. |

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
