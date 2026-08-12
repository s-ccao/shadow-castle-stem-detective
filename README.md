# Shadow Castle: STEM Detective

**Shadow Castle: STEM Detective** is a 2D pixel-art mystery game made in Godot 4. Players investigate a blackout at a magical castle, gather evidence, solve science-based locks, test suspect alibis, and make a final accusation.

The project combines a narrative detective loop with accessible STEM reasoning. Clues are not merely collectibles: the player must distinguish a lead from proof, connect evidence across rooms, and use what they learn to unlock the next part of the case.

## Playable highlights

- Top-down castle exploration with click-to-move and camera follow.
- A chase system using A* pathfinding, physical collision, and a game-over/retry loop.
- Investigation rooms for chemistry, biology, circuits, archives, dining, and the final deduction.
- STEM-inspired locks and evidence: alchemy ingredients, pollen evidence, an electrical repair sequence, and timeline reasoning.
- Dialogue, evidence board, notes, maps, objective panel, inventory, checkpoint, and main-menu flows.
- Five 4-direction animated pixel NPCs: Dr. Lin, Butler, Gardener, Mechanic, and Castle Guardian.

## Technology

- **Engine:** Godot 4.7
- **Language:** GDScript
- **Format:** 2D pixel art, 1024 × 768 viewport

## Run locally

1. Install Godot 4.7 or a compatible Godot 4 release.
2. Import [`project.godot`](project.godot) in the Godot Project Manager.
3. Run the project with `F6`/`F5` from the editor.

## Portfolio documentation

- [Development history](docs/DEVELOPMENT_HISTORY.md) — six development milestones reconstructed from the Git history, including technical decisions and lessons learned.
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
