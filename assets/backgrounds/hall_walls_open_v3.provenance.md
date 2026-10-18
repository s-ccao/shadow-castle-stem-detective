# Hall Walls Open v3 — provenance

- **Asset ID:** `hall-walls-open-v3`
- **Repository path:** `assets/backgrounds/hall_walls_open_v3.png`
- **Generated:** 2026-08-19
- **Source tool:** OpenAI built-in image generation tool
- **Status:** Visual target approved by automated QA; pending in-engine collision retrace and human playtest
- **SHA-256:** `ddd2c559efdf58310753692dae8399d7b3243821d972718426a9c5025fba4ec1`

## References

- `assets/backgrounds/hall_walls.png` — previous wall geometry and palette
- `assets/backgrounds/hall_floor_bg.png` — floor alignment and lighting
- `assets/backgrounds/castle_floor_1_bg.png` — gothic room and decoration direction
- `docs/evidence/2026-08-13-character-scale/after/02-castle-hall-guardian.png` — native gameplay scale

## Generation intent

Rebuild the isolated 1536×1024 hall wall layer while retaining the large
chase-friendly footprint. Make the Chemistry and Library entrances readable,
unobstructed gothic arches. Keep decoration recessed or wall-mounted so it
does not imply false collision or narrow the pursuit lanes. Preserve the
charcoal stone, pale capstones, antique brass, and restrained violet/cyan
accent language of the shipped game.

The first result placed the Chemistry arch too far left. A second constrained
edit moved that arch toward source coordinate `(230, 82)` while locking the
Library arch and remaining wall footprint.

## Processing

The generated RGB source used a flat `#FF00FF` chroma background. It was
converted to RGBA with the installed image-generation chroma removal helper
using a soft matte and despill. Raster QA confirmed the required 1536×1024
size, alpha channel, transparent pixels, and unclipped content bounds.

Do not replace the runtime wall image until `wall_collisions.tscn`, door focus
coordinates, navigation connectivity, and the Guardian footprint have been
revalidated against this version.
