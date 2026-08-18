---
name: shadow-castle-godot
description: Use when modifying Shadow Castle: STEM Detective gameplay, rooms, HUDs, character assets, narrative flow, or Godot 4.7 GDScript. Read the handoff first, preserve the existing save and transition behavior, validate in Godot, and inspect player-facing changes at the native viewport.
---

# Shadow Castle production workflow

## Orient

1. Read `AGENTS.md` and `docs/AGENT_HANDOFF.md`.
2. Inspect the scene, its attached script, and relevant Autoload state before deciding on an edit.
3. Keep the current dirty worktree intact; make the smallest change that achieves the requested result.

## Build

- Godot 4.7 uses GDScript and a 1024×768 target viewport.
- Keep `GameState` as the persistent source of gameplay state. Room scenes should present and update state; they should not silently reset it.
- Keep `CharacterBody2D` movement/collision independent of art scale. Use `player/VisualRoot` for room-specific presentation calibration.
- Use existing dark-brass, violet, parchment, and pixel-art assets as the UI visual system. Functional labels, button state, and accessibility copy remain code-native.
- Normalize external sprite assets before import: transparent PNG, nearest filtering, shared frame size, and bottom-aligned feet.
- For player-visible potions, ingredients, evidence, and character illustrations, create or import cohesive raster pixel art. Use GDScript to present the asset and drive its state, never as the final drawing medium; record AI-art provenance beside the source asset.

## Validate

Run after code or scene changes:

```bash
/Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
git diff --check
```

For any player-facing change, launch the affected flow and evaluate it at 1024×768. Verify that room transitions restore input, HUD overlays restore pause state, and visual changes do not obscure interaction prompts.

## Handoff

Update `docs/PROJECT_STATUS.md` when a player-visible milestone or a major risk changes. Keep `docs/AGENT_HANDOFF.md` accurate when the active goal, acceptance checks, or crucial implementation locations change.

For every completed user-visible stage, overwrite `docs/AGENT_STAGE_REPORT.md` with the evidence for that one stage, then return the compact `CODEX_SYNC_BRIEF` required by `AGENTS.md`. This lets a separate GitHub maintainer review the work without granting this agent GitHub credentials. Do not commit or push as part of the report.
