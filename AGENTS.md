# Shadow Castle: STEM Detective — Agent Guide

## Start here

Read [`docs/AGENT_HANDOFF.md`](docs/AGENT_HANDOFF.md) before editing. It is the current source of truth for game state, current polish work, validation, and next priorities.

## Project rules

- Godot 4.7, GDScript, 1024×768 pixel-art mystery game.
- Preserve the existing dirty worktree. Treat uncommitted changes as intentional in-progress work unless the user explicitly asks to discard or replace them.
- Use `apply_patch` for source edits. Keep changes scoped to the requested system.
- Keep gameplay simulation and visual presentation separate. Character per-room size changes belong on `player/VisualRoot`, not the `CharacterBody2D` root or collision shapes.
- Keep UI text code-native; use the existing pixel assets for ornament and frames rather than baking functional text into images.
- Treat potion, ingredient, clue, and character artwork as raster pixel-art deliverables. Generate or import a cohesive PNG asset, then use code only for layout, state, animation, and interaction; record the source/provenance when an AI image becomes a shipping asset.
- Retain the existing save/checkpoint and room-transition flows when redesigning UI or room content.

## Validation

At minimum, run:

```bash
/Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
git diff --check
```

For player-facing work, also launch the game and inspect it at the native 1024×768 viewport. Follow the focused acceptance checks in `docs/AGENT_HANDOFF.md`.

## Stage sync with Codex

When a discrete, user-visible stage is complete, update [`docs/AGENT_STAGE_REPORT.md`](docs/AGENT_STAGE_REPORT.md) before replying. Record the exact files changed, gameplay effect, visual evidence, validation commands/results, known risks, and proposed next stage.

In the final reply, print one short fenced block headed `CODEX_SYNC_BRIEF` that repeats the stage name, outcome, verification, risks, and the exact GitHub documentation update proposed. The user will paste that block into Codex for review and GitHub synchronization.

Do not commit, push, change remotes, or handle GitHub credentials as part of this handoff. The GitHub maintainer performs those actions after reviewing the report.

## Agent customizations

- Repository-wide Copilot guidance: [`.github/copilot-instructions.md`](.github/copilot-instructions.md)
- Project skill: [`.github/skills/shadow-castle-godot/SKILL.md`](.github/skills/shadow-castle-godot/SKILL.md)
