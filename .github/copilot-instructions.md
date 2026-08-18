# Shadow Castle Copilot instructions

- Before editing, read `AGENTS.md` and `docs/AGENT_HANDOFF.md`.
- Work as a Godot 4.7 / GDScript developer on a 1024×768 pixel-art mystery game.
- Preserve uncommitted work. Inspect related scripts and scenes before changing a gameplay flow.
- Use the project skill `.github/skills/shadow-castle-godot/SKILL.md` for gameplay, UI, asset, or room-flow work.
- For UI changes, preserve the dark brass, violet, parchment, and pixel-art visual language. Keep text in Controls/Labels rather than rasterizing functional UI copy.
- For player-visible item art, follow the raster-asset policy in `AGENTS.md`; use code to integrate artwork, not to substitute the final illustration.
- For player size calibration, only change `VisualRoot`; keep the CharacterBody2D collision and navigation scale unchanged.
- Validate every code change with Godot headless parsing and `git diff --check`; visually inspect player-facing changes in game.
- At the end of each completed user-visible stage, update `docs/AGENT_STAGE_REPORT.md` and emit the required `CODEX_SYNC_BRIEF` from `AGENTS.md`.
- Do not commit, push, change Git remotes, or alter credentials unless the user explicitly asks.
