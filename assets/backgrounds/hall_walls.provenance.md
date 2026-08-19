# Hall Walls — Provenance

- Asset: `assets/backgrounds/hall_walls.png`
- Replaced: 2026-08-19
- Source: `hall_walls_routes_open_v5_doors.png`, supplied by the project owner.
  Three candidate versions were on disk and they differ only in small patches,
  so pixel overlap could not tell them apart — v3, v4 and v5 all scored around
  0.93 against the supplied file. What identified it was checking the supplied
  file inside the patches that separate the versions: v4 opens the chemistry and
  library corridors that v3 walls off, and the supplied file is 4–7% stone
  there; v5 then adds arch masonry back at those two doors, and the supplied
  file is 100% stone there. Only v5 matches both.
- Canvas: 1536 × 1024 RGBA, drawn for the hall's uniform ×1.25 scale onto the
  1920 × 1280 map. Do not change that to the floor image's non-uniform ratio.

## Why it was replaced

The wall layer this replaces was the one the project shipped with, plus a patch:
`442c317` had to graft the Greenhouse arch into the Chemistry recess because the
original art painted nothing there but a row of golden cabinets, and players read
the whole north-west corner as a dead end. The corridor was open the entire time
— the art simply never said so.

This layer removes the need for that kind of repair. Every room entrance is
drawn as a real arch by the artist, in one consistent pass, so the picture and
the level design agree without anything being pasted in afterwards. The one
focus rect still on plain masonry is the Service Wall door, which is meant to be
invisible until the Dining Hall key opens it.

## What was regenerated with it

`scenes/wall_collisions.tscn` collision is derived from this image, so it had to
be rebuilt. The opaque pixels are quantised to a 4px grid and decomposed into
axis-aligned rectangles — 1396 of them, grouped into 40 `WallBlock_C*R*` bodies
by screen position purely so the scene tree stays navigable. Collision therefore
cannot disagree with the painted stone by more than the quantisation, measured
at 1.66% of the map.

The two visual sprites, the storage rack, the three final-key machines and the
five knowledge exhibits were not touched: their nodes, transforms and editor
notes carry over unchanged.

## Validation

Collision was rasterised back out of the committed `.tscn` and compared with the
image it came from: intersection-over-union 0.95, with 1.72% of the map blocked
where the art is clear (the 4px quantisation, always on the wall's own side) and
0.28% clear where the art is stone.

Then, against the 14 × 8 player body flood-filled from
`HALL_FIRST_ARRIVAL_POSITION`:

- All eight door focus rects have standable floor inside the 14px interaction
  margin *and* that floor is on the spawn's island. The tightest is the Wake
  door at 5391 connected pixels; the rest are between 6824 and 16566.
- All five knowledge exhibits likewise, tightest `ChemistryRoomKnowledge` at
  2297.
- Storage rack and all three final-key machines likewise.
- Standable ground splits into six regions and only one of them matters: the
  spawn's, at 940224 px, which is every tile inside the painted maze. Of the
  rest, 257424 px is the dead border outside the art that no player can enter,
  8696 px is two chambers the maze seals on purpose (x1115..1192 y132..235 and
  x1715..1776 y212..231), and 16 px is two single-tile specks.
- `tools/check_static.py` re-checks the doors and the exhibits, including the
  connectivity half, on every push.

The Guardian's A* grid is built from this collision too, and it came out better
than the hand-authored walls on every measure. Open cells rose from 1311 to
1738, and they went from **four** disconnected regions — pockets no path could
enter, which is one of the ways the Guardian appears to stop hunting — to a
single region containing both the arrival spawn and `HALL_ENEMY_START_POSITION`.
Standable floor that the grid nevertheless calls solid fell from 0.38% to 0.09%.
Only two authored constants sit in a solid cell now, `SERVICE_WALL_DOOR_POSITION`
and `HIDDEN_LIBRARY_KEY_POSITION`, and both are markers embedded in masonry by
design: the player stands beside them and presses interact, never on them.

Seven position constants that the new walls put inside stone were moved to the
nearest standable floor with room around it: `BUTLER_POSITION`,
`GARDENER_POSITION`, `MECHANIC_POSITION`, `CIRCUIT_NOTE_POSITION`,
`CIRCUIT_DOOR_POSITION`, `LIBRARY_DOOR_POSITION` and
`DINING_HALL_DOOR_POSITION`. The last three are the player-side anchors, not
the focus rects: no `*_DOOR_FOCUS_POSITION` needed to move, because the new art
draws an arch exactly where every one of them already pointed.
