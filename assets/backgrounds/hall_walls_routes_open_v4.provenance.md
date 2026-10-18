# Hall Walls Routes Open v4 — Provenance

- Asset: `hall_walls_routes_open_v4.png`
- Date: 2026-08-19
- Purpose: corrected Castle Hall wall layer with preserved Chemistry and Library door arches and continuous approach passages.
- Generation method: OpenAI image generation, two precision-edit passes over `hall_walls_open_v3`.
- Project-owned references:
  - `assets/backgrounds/hall_walls_open_v3.png`
  - `assets/backgrounds/hall_floor_bg.png`
  - the existing Hall collision scene and door coordinates.
- Post-processing: sampled magenta chroma removal, spill cleanup, one-pixel matte contraction, RGBA export.
- Canvas: 1536 × 1024 RGBA, intended for the existing uniform 1.25 Hall scale.

## Required geometry preserved

- Chemistry door arch near source coordinate `(230, 82)`.
- Library door arch near source coordinate `(1338, 187)`.
- All other rooms, outer boundaries, wall decorations, and established Hall styling.

## Route corrections

- Chemistry: removed the blocking horizontal wall segment beneath the door chamber and finished the two cut ends.
- Library: removed the blocking vertical wall segment west of the door approach chamber and finished the two cut ends.

## Validation

- Exact 1536 × 1024 dimensions: PASS.
- RGBA transparency and content bounds: PASS.
- Local Chemistry approach connectivity, 14 × 8 world-unit player footprint: PASS.
- Local Library approach connectivity, 14 × 8 world-unit player footprint: PASS.
- Both approaches, 24 × 24 world-unit Guardian footprint: PASS.

This is a candidate art layer. Do not replace `hall_walls.png` without updating and visually testing the matching Godot collision polygons.
