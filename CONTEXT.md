# CONTEXT

Shared terminology and invariants for **Shadow Castle: STEM Detective**, a
Godot 4.7 top-down detective game. This file records the things that are not
obvious from reading a single script — the constraints that have already
caused bugs. Architectural decisions belong in `docs/adr/`; player-facing
setup belongs in `README.md`.

## Vocabulary

Keep these distinct; the codebase does, and conflating them produces flags
that never fire.

| Term | Meaning | Lives in |
|---|---|---|
| **Evidence** | Case facts the player collects to build deductions | `GameState.evidence_items` |
| **Knowledge** | STEM facts taught by the hall exhibits; gates the door questions | `GameState.knowledge_items`, `hall_knowledge_*_collected` flags |
| **Clue** | A NoteHub journal entry; the presentation layer for evidence and knowledge | `NoteHud.add_clue()` |
| **Material** | Crafting ingredients for the alchemy workbench | `GameState.inventory_items` |
| **Key** | A physical unlock for one door | `GameState.key_items` |
| **Story flag** | A named boolean of world progression | `GameState.story_flags` |
| **Room** | A separate scene under `scenes/floor_1/` plus the Wake Room | `*_ROOM_SCENE_PATH` |
| **Checkpoint** | The save-restore anchor after a death | `checkpoint_valid` in the save |

A room door is a **double lock**: a key *and* a knowledge question. Having the
key without the knowledge flag shows the "study the exhibit first" message
rather than the question.

## The hall has two background images, and they do not agree

This is the single most expensive trap in the project.

| File | Size | Scale to the 1920x1280 world | Role |
|---|---|---|---|
| `assets/backgrounds/hall_floor_bg.png` | 1448x1086 | 1.3260 x **1.1786** (non-uniform) | Floor, glows, lighting |
| `assets/backgrounds/hall_walls.png` | 1536x1024 | **1.25** uniform | The walls and archways the player actually sees |

They are **different layouts at different vertical scales**. `hall_walls.png`
is the authority for anything the player looks at or bumps into; it is also
what `scenes/wall_collisions.tscn` was traced from. Coordinates derived from
the floor image land tens of pixels away from the matching wall feature, which
is exactly how every door's interaction prompt ended up floating on empty
floor below its archway.

To check a world coordinate against what the player sees, composite both at
runtime resolution — walls over floor, since `hall_walls` sits at `z_index`
-50 above the floor's -100:

```python
floor = Image.open('hall_floor_bg.png').convert('RGBA').resize((1920, 1280), LANCZOS)
walls = Image.open('hall_walls.png').convert('RGBA').resize((1920, 1280), LANCZOS)
composite = Image.alpha_composite(floor, walls)
```

## Door constants come in pairs

Every hall door has two coordinates and they are not interchangeable:

- `*_DOOR_POSITION` — the player-side anchor: the return spawn used by
  `get_floor_one_spawn_position()`, the guardian's stakeout anchor, and the
  pathfinding target. Users have hand-placed these; moving one changes where
  the player lands coming back out of the room.
- `*_DOOR_FOCUS_POSITION` — where the door is *drawn* on `hall_walls.png`.
  `get_interaction_rect()` builds its rect around this one, and that rect does
  double duty: it positions the corner bracket **and** it decides whether the
  player is near enough to be offered the prompt. It is not cosmetic. Push it
  far enough into the wall and the room stops being enterable.

The two were once filled with the same value, which drew every bracket on a
patch of empty floor in front of the door. The focus values are measured off
the wall art (1536x1024 scaled x1.25 onto the 1920x1280 map, so image
coordinates x1.25 are world coordinates); each constant carries the stone-frame
bounds it was taken from. Two merges have already reset them, and the damage
does not look like a bug in a diff, so `tools/check_static.py` now asserts that
every door's rect still has walkable floor within the 14px interaction margin,
**and** that the floor connects to `HALL_FIRST_ARRIVAL_POSITION`. Floor beside
the door is not enough on its own: the hall is a maze, so a wall edit can fence
a doorway's approach into a pocket that passes the margin test and is still
impossible to walk into. The connectivity pass scan-converts the wall polygons
into one bitmask per scanline, dilates by the 14x8 body with whole-row integer
shifts, and unions runs between adjacent rows, which keeps the whole check
around six seconds. Its raster decides coverage at the pixel centre, making it
marginally more permissive than `_player_fits` — deliberately, so it can never
invent a wall and fail the build for a corridor that is really open.

Every room entrance in the hall is drawn as a stone arch on `hall_walls.png`,
and the focus constant is measured off that arch. The Chemistry doorway was the
exception for a while: that stretch of wall had nothing on it but a row of
golden cabinets, so the bracket framed a blank alcove and players read the whole
north-west corner as a dead end and reported the room as unreachable. It never
was — a flood fill from the arrival spawn found 8171 walkable pixels inside its
interaction margin, all in the spawn's own connected region. `442c317` patched
that by grafting the Greenhouse arch into the recess. The 2026-08-19 wall layer
makes the graft unnecessary: it draws an arch at all seven room doors natively.

Reachability survived that swap untouched, which made it easy to believe the
constants had. They had not: every bracket was 20 to 40px off its new arch and
half of them were half again too big, because the sizes were measured against
art that no longer existed. `check_static.py` cannot see this — a bracket
floating beside the door is as reachable as one on it. **After any wall change,
re-measure the focus rects by eye against the new art**, and be careful how:
reading extents off a zoomed crop is unreliable, and the automated attempts
here — darkest blob, wall-top profile, magenta keying — all found something
other than the door. What worked was scoring each candidate centre by the
mirror symmetry of the silhouette and shading around it, then confirming the
winner against the current value on a 5x crop, one line each. Symmetry alone is
not enough either; it put the Library door 70px onto a neighbouring structure.

The Service Wall door is the one focus rect with no arch under it, and that is
deliberate. It is a sealed door in the hall's east wall that only opens once the
Dining Hall yields the Service Corridor Key, so plain masonry is the point — the
script tells the player it is there, and there is nothing to find before then.

The lesson generalises: `check_static.py` can prove a door is *reachable*, but
nothing can prove it is *findable*. A focus constant that lands on blank wall is
as good as a locked door, so a new entrance needs art before it needs geometry.

Doors are embedded in walls, so `*_DOOR_POSITION` sitting inside a collision
polygon is normal and expected. What matters is that standable floor remains
within the interaction margin of the focus rect.

## An interaction the player cannot reach is a dead run, not a cosmetic bug

Everything the player interacts with in the hall and the rooms is offered by
the same test: is the player's body within `INTERACTION_MARGIN` (14px) of the
interaction rect. Nothing in the editor shows when that fails. A knowledge
exhibit sits happily on top of the masonry, looking exactly as intended, and is
simply uncollectable — and since each exhibit teaches the answer to one door's
knowledge lock, an unreachable exhibit locks the run.

`tools/check_static.py` asserts reachability for the doors, the exhibits and the
four hall props, and that what it finds is on the same island as the arrival
spawn. The props matter most and were checked last: `FinalKeyMachine1..3` hold a
third of the Final Room Key each, so one sealed into the masonry does not cost a
collectable, it ends the run. Their `*_POSITION` constants prove nothing either
way, because `get_interaction_rect` measures them off the scene node and only
falls back to the constant when the node is missing — which is why the check
reads the node names out of `game_world.gd` and the rects out of the scene.

Its wall data must match what the engine treats as solid, which is
**only bodies on the wall layer**: each exhibit also carries an `InteractionArea`
whose shape is an Area2D on layer 2 and disabled besides, and counting those
walls the exhibits in and produces confident false alarms.

Reachable is the floor, not the ceiling. The exhibits passed every check while
being scattered across the middle of the maze at wildly different sizes — the
Dining Hall clock was drawn 79x217, three times the player's height and nearly
three times the smallest exhibit, and two of the five carried a non-uniform
scale that stretched the art. Each exhibit now stands against the stone beside
the door it teaches, 76 to 103px away, and all five are drawn to one height
(104px) at a uniform scale. Two rules for touching them again: **the exhibit
belongs beside its own door**, because that is what makes "study this, then
answer the door" legible without a word of text; and **scale uniformly**, since
the non-uniform pair are the same mistake the floor image section below is
about.

Where an interaction rect comes from, in order of preference:

1. the sprite's opaque box via `RoomSpatialRuntime.get_visual_rect()` — used
   whenever the prop exists as a scene node, and always correct by construction
2. an explicit `interaction_rect` in the item's dictionary — needed when the
   prop is painted into the background and has no node
3. a fixed `Rect2(position - (44, 34), (88, 68))` fallback

The fallback is the same defect the doors had: a small fixed box floating near
the thing rather than on it. The greenhouse's two herb beds were the last
items reaching it — they are 125x655 and were being framed by an 88x68 square
over their lower third.

### The Wake Room candle note: no sprite, three different boxes

The first interaction in the game had no node at all. Its geometry lived in
three places that had drifted apart: a 90x70 mouse hotspot, a 48x36 focus rect,
and a proximity test using the second. All three were centred 57px above the
candles and the open note painted on the window sill, so clicking the note did
nothing and clicking the empty stained glass above it worked.

Its `clue_approach_position` was worse than misplaced — it was inside the top
wall's collision, and the focus rect was 80px from the nearest tile the player
could occupy, so `is_actor_near_rect()` could not return true anywhere in the
room. The E-key branch and the focus bracket were written but unreachable.

`clue_interaction_rect` is now the single source for all three. Two rules came
out of it:

- **A recessed interaction needs a deeper contact band than 14px.** The sill sits
  in a wall alcove that stops the player 28px short of it, so `_is_near_clue()`
  passes 32px. Widening the rect to close the gap instead was tried and looks
  wrong: the bracket spills onto the floor and the neighbouring chest.
- **An interaction with no sprite still has to be measured against the art.**
  There is nothing to derive a rect from and nothing in the editor that shows it
  is wrong, so the numbers have to come from reading the background pixels.

## Walking into a wall freezes the player permanently

`player.collision_mask = 0`. Movement is resolved per axis in
`move_with_floor_constraint()` by asking `is_player_position_walkable()`, not
by the physics engine. Nothing pushes an overlapping body back out.

A position spawned inside a wall is therefore **unrecoverable** — every
direction tests as blocked. `resolve_spawn_position()` exists to push anchors
out to the nearest standable point; new spawn anchors must go through it.

The player's collision box is `14x8` with the shape offset `(0, -4)`
(`scenes/player.tscn`), so it occupies `x in [px-7, px+7]` and
`y in [py-8, py]`. `is_player_position_walkable()` probes five points at
`(±8, ±5)` and the centre.

## Two different grids, both 60x40-ish, neither interchangeable

| Grid | Cell | Dimensions | Purpose |
|---|---|---|---|
| Navigation / walls | `CELL_SIZE = 32` | `MAP_WIDTH 60` x `MAP_HEIGHT 40` | A* and the legacy wall grid |
| Fog of war | `FOG_CELL_SIZE = 16` | `FOG_COLS 120` x `FOG_ROWS 80` | Vision, sight blockers |
| Map HUD exploration | 32 | 60 x 40 | Persistent "where have I been" |

Fog cells are half the size of exploration cells. Mixing them up doubles or
halves a radius silently.

## Fog of war invariants

`has_world_line_of_sight()` quantises **both** endpoints to 16px cells.
Therefore, for a fixed player cell, the set of visible cells is a constant.
`update_fog_of_war()` relies on this to cache visibility across frames and
rebuild only on a cell crossing; any change that makes line of sight depend on
sub-cell position invalidates that cache and must remove it.

The player's own cell is deliberately skipped while walking the Bresenham
line. The 14x8 collision box is smaller than a 16px fog cell, so standing
against a wall puts the cell centre inside the wall; treating it as a blocker
makes every direction opaque and blacks out the whole screen. The loop steps
before it tests so this cannot regress, and a ray that starts inside a wall is
allowed to leave it before the next wall stops it — without that, a player
standing on a pseudo-3D wall cap sees nothing but the wall they are on. This
was a real bug across 190 patches of standable floor.

Sight blockers are rasterised from `scenes/wall_collisions.tscn`, so
decorative art without a collision polygon does not block vision.

## Three grids disagree about what a wall is, and the player lives in the gap

The hall answers "is this a wall?" three times, at three resolutions:

| System | Resolution | Test |
|---|---|---|
| Physics | exact | the authored polygons |
| A* grid | 32px cells | can the player's body fit *anywhere* in the cell |
| Fog | 16px cells | is the cell centre inside a polygon |

Both grids are coarser than the 14x8 player body, so the player can stand
somewhere a grid calls solid. Every system that assumes otherwise breaks in a
way that looks like something else entirely:

- `find_path()` refuses any request whose endpoint is solid, and the endpoint
  is wherever the player is standing. A Guardian that cannot be sent to the
  player simply stops, which reads as "the Guardian does not chase".
- `is_sight_line_clear()` sampling the player's own cell makes the Guardian
  blind to someone standing right in front of it.
- `has_world_line_of_sight()` starting inside a blocker blacks out the torch.

The A* grid used to probe only the cell centre, which stranded 12.7% of the
standable hall across 246 patches and cut the open region into pieces that left
half the door anchors unreachable. It now probes a 4x8 grid inside each cell
and opens the cell if the body fits anywhere; `find_path()` additionally slides
either endpoint to the nearest open cell within three cells. Both are needed:
the probe grid fixes connectivity, the endpoint slide covers what is left.

The wall art feeds this grid, so redrawing the walls redraws the Guardian's
world. It is worth measuring both ways after any swap, because the numbers move
a long way and neither shows up in play until someone reports the Guardian
standing still. The hand-authored walls left the grid in **four** disconnected
regions — pockets no path could ever enter — and 0.38% of standable floor in a
cell the grid called solid. Generating collision from the 2026-08-19 art put the
grid in **one** region of 1738 cells, with 0.09% stranded. Fewer, larger, better
connected: the same probe code, a kinder map.

### A cell that is open somewhere is not open at its centre

Opening a cell because the body fits *somewhere* inside it and then steering to
its geometric *centre* is a contradiction, and it cost the hall 428 of its 1292
navigation cells: a third of every path ran at a point buried in stone. Movers
never got within the 4px arrival threshold, so they pressed into the wall until
`enemy.gd`'s stall timer wrote the step off, four tenths of a second at a time.
It reads in play as a Guardian that has given up the hunt.

`build_navigation_grid()` therefore caches the probe nearest each centre that
the body actually fits on. `cell_to_world()` is for fog, door placement and
rendering — anything that describes a cell rather than walking to it.

### One point per cell cannot describe a maze finer than the cell

Caching a reachable point per cell fixed the endpoints and left the *steps*
unchecked, and that turned out to be the whole problem. A* said two neighbouring
cells were both open; the mover walked the straight line between their two
points; nothing had ever asked whether that line was walkable. Measured against
the 2026-08-19 walls with the real 14x8 body, **356 of 2850 adjacent transitions
— 12.5% — crossed stone.** One step in eight was a step into a wall, the stall
timer wrote it off, the repath returned the same step, and it did that forever.
That is the "Guardian gets caught on a short wall and keeps walking into it"
report, and no amount of picking a better point inside the cell fixes it:
choosing the roomiest point instead of the most central still left 3.5% blocked
and broke the graph into nine pieces, because a cell with a wall through it
needs two points and has one.

So movement no longer uses the cell grid at all. `build_navigation_lattice()`
puts a node every `NAV_LATTICE_SPACING` (16px) of standable floor and joins
neighbours only where the body can walk the step:

- **16px is chosen against the body, not the tile.** The body is 14 wide, so it
  overlaps itself between neighbours and a step is walkable whenever both ends
  and the midpoint are. That rule agrees with a full sweep on all 8431
  orthogonal edges — no false opens, no false closes.
- **Diagonals need no extra collision query.** One is allowed only when both
  ways round the corner are already open, which cannot cut a corner through
  stone. It refuses 324 legal diagonals to do it, and the cost of refusing one
  is the Guardian taking the long way round a corner.
- It is **cheaper** than what it replaces: 18k shape queries against about 37k,
  because there is no 32-probe sweep per cell.
- Measured over 400 random reachable player positions, every route exists and
  **all 31261 waypoint steps are clear.** Verify it that way after any wall
  change; "the doors are reachable" does not imply "the steps between them are".

The 32px grid stays for what it is good at — `is_sight_line_clear()` samples its
solidity, and `cell_nav_point()` still serves the route trail and click-to-move.

### A Guardian with nowhere to go must still go somewhere

Three separate ways the hunt stalled, all of which read as "it gave up":

- **PATROL walked to one fixed doorway and stood on it.** The patrol route was
  built, published to `GameState` and never walked: nothing advanced
  `guardian_patrol_index` while the player was in the hall, only the offscreen
  simulation ever moved it. `get_guardian_patrol_target()` now hands out the
  route, `advance_guardian_patrol_target()` steps it on arrival, and the
  stakeout survives as the thing the loop is aimed at — when the room the player
  needs changes, the patrol re-enters beside that doorway.
- **SEARCH stared at the last sighting.** Standing on the spot the player used
  to be is not searching; stepping out of the room was enough to be safe. The
  Guardian now walks a fresh point around the sighting each time it arrives at
  one.
- **CHASE without sight ended at the last sighting and stopped.** Arriving there
  and finding nobody is what losing someone *is*, so it reports the loss and
  drops into SEARCH.

`_choose_next_target()` is the one place that answers "and now what". It must be
fired **once per planning cycle, not once per frame** — the guard for that is
`awaiting_new_target`, cleared in `update_path()`. Without it a Guardian
standing still walks twenty patrol waypoints between two repaths.

### The Guardian's footprint is the player's footprint

The Guardian used to carry a 24x24 box centred on its origin while the player
carries 14x8 at its feet — three times the vertical footprint, extending 12px
*below* the ground point its sprite is anchored to. Sharing one navigation grid
between two different bodies means the grid is lying to one of them: the
Guardian could occupy 616 of 1297 cells and reach only 472 of them from its
spawn, so 63% of every route it was handed was impassable. Rebuilding the grid
from the Guardian's body instead was measured and is worse — it disconnects the
hall.

Both bodies are now 14x8 at `(0, -4)`, which takes the hunt from 36.4% of the
hall to 99.6%. The Guardian's size on screen is unaffected: `GuardianCore` is a
child sprite at `(0, -44.8)` scaled 0.8, fully decoupled from the body. Keep it
that way — growing the collision shape to "match the art" re-breaks the hunt.

`enemy.gd` still writes off a waypoint it has failed to approach for 0.4s. That
is now a net for the obstacles the grid cannot know about (the player's own
body, geometry finer than the 32px sampling), not the difference between
hunting and standing still.

## `scenes/wall_collisions.tscn` is the authority for the hall

Both collision and sight blocking read it. The node structure must stay
`WallCollisions -> <StaticBody2D> -> <CollisionPolygon2D>`;
`build_sight_blockers()` walks exactly that shape and silently sees nothing
if the hierarchy changes. It does not care what the bodies are called, only
that a wall is a `CollisionPolygon2D` under a `StaticBody2D` that is a direct
child of the root.

The scene is no longer hand-authored. Collision is generated from the opaque
pixels of `hall_walls.png` at 4px, decomposed into axis-aligned rectangles, and
grouped into `WallBlock_C*R*` bodies by screen position so the tree stays
navigable. That is the point: collision cannot disagree with the painted stone
by more than the quantisation, so an air wall is not expressible. The props —
the two visual sprites, the storage rack, the three final-key machines and the
five knowledge exhibits — are hand-placed and must survive any regeneration.

## Save format constraints

`user://shadow_castle_save.json` is plain JSON, written through a `.tmp` file
and renamed so a crash mid-write cannot truncate it.

**JSON object keys must be strings.** `hall_explored_cells` therefore uses
`"x,y"` string keys and must keep them. The fog dictionaries
(`sight_blockers`, `discovered_fog_cells`) are runtime-only and use `Vector2i`
keys, which Godot hashes without allocating — do not "unify" the two.

`SAVE_VERSION` is checked on load and a mismatch discards the save, so any
change to the payload shape needs the version bumped.

## Per-frame cost lives in `game_world._process()`

`_process()` drives fog, chase state, camera zoom and hall exploration every
frame, including while a dialogue panel is open. Anything added there runs
60 times a second for the whole session. Before adding work, check whether
the result can only change when the player crosses a cell — most of it can.

## Awareness is not the same as reporting it

`enemy.gd` keeps a local `can_see_player`, and `GameState` keeps the shared
`guardian_mode`. Only `report_player_seen()` moves the second one. Under the
tracking serum `_update_awareness()` used to set the local flag and return, on
the reasoning that an omniscient Guardian does not need the line-of-sight path
— but the line-of-sight path is the only caller of `report_player_seen()`, so
the hunt sat in PATROL for the whole game.

PATROL neither catches nor moves. `check_player_collision()` opens with a guard
requiring `Behavior.CHASE`, so the player could walk into the Guardian and
nothing happened; and `_current_target_position()` answered the serum case with
`get_guardian_hall_position()`, which is the Guardian's *own* live position —
`move_along_path()` writes it back every frame — so the body was ordered to walk
to where it already stood. One missing call, three symptoms, all of which look
like a pathfinding or collision bug and none of which are.

The serum branch now reports every frame it is active, so anything that demotes
the mode is corrected on the next tick. `tests/guardian_awareness_flow_test.gd`
states the contract: "The serum keeps the Guardian in CHASE".

## A readout that decays on its own is not a readout

The Guardian contact estimate counts down by `delta` every frame so the clock
looks live between the 0.12s re-measurements, and rate-limits recovery so that
gaining ground eases the number back instead of snapping it. Both halves are
right; the rate was not. `GUARDIAN_ETA_RELIEF_RATE` was 0.85, which is less
than the 1.0s/s the display takes away, so the estimate could not even hold
still. A Guardian standing motionless 25 seconds away drained the readout by
0.15s/s until it reached 00.0 in about two minutes, and once there it could
never climb back: the panel showed "IMMINENT — REACH A ROOM" for the rest of
the session while the Guardian was across the hall. Any relief rate at or below
1.0 has this failure; 3.0 leaves a net +2s/s recovery.

Relief is also priced against the time that actually elapsed since the last
sample, not against the nominal interval, so a long frame cannot quietly lose
ground the same way.

The panel withdraws beyond `GUARDIAN_ETA_DISPLAY_HORIZON` and returns with
hysteresis. Past the horizon the urgency bar fills to zero anyway, so leaving
the panel up drew a large number over an empty gauge for the whole game. A
warning that is always on screen tells the player nothing about when to run.

## Being caught has to be shown, not just recorded

The Guardian usually lands its catch from behind or beside the player, so the
last frame of gameplay is ordinary floor. Raising the death UI on that same
frame ended the run without ever showing what ended it, and it read as the game
closing rather than as something the Guardian did. `_play_capture_sequence()`
pushes a camera onto the midpoint of the two bodies, names the capture, and
holds for about two seconds before `_show_game_over_screen()`.

It borrows the reveal's overlay, and it borrows the reveal's hub lockout for a
specific reason: opening a hub pauses the tree, which would strand the
sequence's tweens and leave the player frozen under the title card. That lockout
lives on autoloads, so `_show_game_over_screen()` has to give it back or the
suppression follows the player into the next run.

## Walk cycles are driven by distance, not by time

Both bodies play an eight-frame cycle authored at 5 fps, and both used to play
it at a flat `speed_scale` whenever they moved. That is a fixed number of steps
per second against a speed that varies by a factor of five: a Swiftness Potion
moved the detective 40% faster without moving their legs at all, and the same
leg speed served the Guardian's 44px/s stakeout shuffle and its 232px/s
tier-five charge. Playback is now `speed * WALK_CYCLE_SECONDS /
WALK_CYCLE_DISTANCE`, so one stride always covers one stretch of floor. The
Guardian is the larger body and gets the longer stride.

## The Guardian's cinematic freeze is a leak waiting to happen

`setup_enemy()` arms `cinematic_hold` and two separate sequences are trusted to
release it — the reveal and the power-restoration scan. Both release it only
after a chain of `await`s, and both chains return early if the scene is being
torn down. Either one leaving the flag set produces a Guardian that is visible,
tracked on the map, allowed to catch the player, and physically unable to move,
which reads in play as no hunt at all rather than as a bug.

`_release_stale_guardian_hold()` clears it after six seconds of "hunt running,
still frozen". The grace period is what separates a broken chain from the few
frames between `setup_enemy()` arming the hold and the reveal claiming it —
releasing immediately cancels the reveal.

**The watchdog deliberately does not stand down while a cinematic flag is set.**
The first version excused itself whenever `guardian_entry_sequence_active` or
`power_route_scan_active` was true, which is precisely the state a broken chain
leaves behind: the reveal's two early returns sit between the freeze and the
thaw, so a leak sets *both* the hold and the flag. A watchdog that trusts the
flag is blind to the only case it exists for. Neither cinematic keeps the
Guardian frozen for more than ~1.5s, so six seconds is a wide margin.

Recovery has to undo the whole freeze, not the measured part of it. Both
sequences also stop the player and suppress HUD surfaces, and the reveal swaps
in its own camera and a full-screen title card, so
`_force_end_guardian_cinematic()` restores those too. Thawing only the Guardian
would leave the player rooted under a black overlay.

## Localization

`CaseLocale` holds UI chrome as `"key": {"en": ..., "zh": ...}` and falls back
to English for a missing key or language.

Game **content** tables do not use it. Where option text is paired with a
`"correct"` index (`DOOR_QUESTIONS`, `FINAL_SYNTHESIS_QUESTIONS`) the
translation lives in the same record as `question_zh` / `options_zh`, resolved
by `_localized_field()`. Splitting those into a separate table risks the
options and the answer index drifting apart in one language only.

Room prose is translated **at the sinks**, not at the call sites.
`present_feedback`, `show_message`, `set_dialogue_text` and `NoteHud.add_clue`
each run their argument through `CaseLocale.line()`, which looks the English
up in `CaseScriptZh.LINES` and returns it unchanged when there is no entry.
The English literal in the room script is both the source text and the lookup
key, so adding a translation touches no logic and a reworded line cannot
silently point at a stale entry.

All 287 player-facing lines are translated. Run
`python3 tools/check_translations.py` after any text change; CI runs it too.
It fails on a translation whose English no longer exists, and on one whose
format specifiers, BBCode tags or line breaks drift from the original — the
first is dead weight, the other two crash or misrender at runtime.

Two traps that cost time here. Nearly all long prose is a parenthesised chain
of concatenated string literals, so any tool reading this source has to fold
`"a" + "b"` the way the engine does or it will measure strings that never
exist at runtime and miss every one that does. And formatting half a sentence
before concatenating the rest (`"... %s" % x + " rest."`) splits one sentence
into two translation units at an arbitrary English clause boundary, which no
other language's word order can follow.

**Mrs. Lin's register is a teacher addressing a student they think highly
of.** She explains rather than simplifies, names things properly, and when
the player is wrong she says where the reasoning went sideways instead of
softening it. The source already reaches for this — "Do not guess — read,
observe, understand", "Obvious is not the same as proven. You know how often
I say that", and her notebook conceding "Perhaps I taught you something after
all." New lines should match that voice rather than talking down to the
player.

## Minigames

Every room has a minigame, and each one teaches that room's own hall exhibit
subject. They all extend `MinigameShell` (`scripts/minigame_shell.gd`), which
owns the panel chrome, stage counter, instruction line, result banner, clear
effect and level flow. A concrete game overrides two methods:

```gdscript
func level_count() -> int
func build_level(index: int) -> void   # add widgets to `content`
```

and calls `report_level_cleared()` / `report_level_failed()`. Rooms launch
them through `MinigameLauncher.launch(...)`, which spawns, freezes, awaits and
cleans up in one call and enforces one game at a time.

| Room | Game | Teaches |
|---|---|---|
| Greenhouse, left bed | Photosynthesis Bench | growth = min(light, water, CO2) |
| Greenhouse, right bed | Moonlight Harvest | periodic cycles, timing |
| Chemistry | Sample Tray | new substance = chemical change |
| Library | Optical Bench | additive colour mixing |
| Circuit | Repair Bench | conductors, closed circuits |
| Dining Hall | Timeline | rate x time, discarding an outlier |

Everything is built in code; no minigame needs a `.tscn`. New text is
bilingual from the start via the shell's `_text(english, chinese)` helper.

**Level tables must be proven solvable before shipping.** Hand-authoring
budgets and targets has already produced two levels that could not be
completed at all, which is a hard progression block. Solve every level
exhaustively against a port of the rules, and also assert the lesson cannot
be bypassed — that no photosynthesis stage can be cleared by dumping the
whole ration into one supply, that no sorting stage is single-category, that
every conductor bin holds both a conductor and an insulator, and that the
outlier's value is actually offered as a pickable wrong answer.

Drawing code has to be checked too, not just the numbers. The supply bars
originally scaled to each channel's own cap, so the limiting supply could be
drawn taller than a healthy one and the picture contradicted the lesson.

**A shell must be added to the tree before it is configured.** `_ready()` is
where `MinigameShell` builds its widgets, and `_ready()` only runs on tree
entry, so `configure()` before `add_child()` writes into null labels and
throws. `MinigameLauncher` gets this right; anything that hand-rolls the
sequence has to as well. This is the general shape of the bugs that survive
static checking — solvability, geometry and colour maths can all be proven
offline, but Godot's node lifecycle, signal timing and modal input state
cannot. Code written without being run needs a review pass aimed
specifically at runtime semantics.

## Audio

`AudioManager` (autoload) creates the Music, SFX and UI buses at runtime
rather than shipping a binary bus layout, and resolves sounds by name from
`assets/audio/<id>.wav`:

```gdscript
AudioManager.play_ui("ui_click")
AudioManager.play_sfx("potion_drink")
```

Volumes are stored linear 0-1 and converted at the bus; zero uses the mute
flag because `linear_to_db(0)` is negative infinity. Preferences share
`user://shadow_castle_preferences.cfg` with the language setting, so the file
must be re-read before writing or the language choice is wiped.

Missing files are a silent no-op by design; audio must never crash the game.
Eight voices round-robin, and a 45ms guard stops one sound retriggering into
a noise wall.

The shipped sounds are **procedurally synthesised placeholders**, generated
from sine tones and filtered noise rather than sourced from any library.
Swapping in real recordings is a file swap with no code change.

## Potion feedback

`PotionHud` (autoload) reacts to `GameState.potion_applied` and
`potion_expired` — `state_changed` cannot distinguish those two cases. The
vignette sits on canvas layer 25 (below the room UI at 30, so it never covers
dialogue); the status chips sit at 43 (above the bag and map at 42). Nothing
overrides `process_mode`, so the HUD freezes in lockstep with the GameState
countdown when the tree is paused.

Effect colours are the hue of the halo each bottle casts in its own artwork,
with saturation raised only enough to read at low alpha.

## Answer options are shuffled at display time

Every `"correct"` index in `DOOR_QUESTIONS` and `FINAL_SYNTHESIS_QUESTIONS` is
`0`. That is safe **only** because `_show_door_question()` and
`_show_final_synthesis_question()` shuffle the button order every time. The
numbered list printed into the dialogue panel is generated from that same
shuffled order — if you regenerate one without the other, the panel tells the
player an answer number that maps to a different button.

## Validating without opening Godot

`gdparse` proves a file is *syntactically* well-formed and nothing more. Godot
rejects several things it accepts, and all of them fail at **load** time, which
means the first symptom is a scene that will not run — usually every scene,
because the offending file is usually an autoload.

Three have actually bitten this project, all of them merge artifacts:

- **A duplicate key in a dictionary literal.** Bringing the same block of
  entries in twice parses clean and then refuses to load. This is how
  `case_locale.gd` broke: two copies of `potion.swift_short`.
- **A duplicate top-level `func`/`const`/`signal`.** Same shape, same silence.
- **A `res://` path whose target was deleted.** Removing a script during a
  merge without updating the scenes that reference it leaves scenes that cannot
  be instantiated.

One more that fails at runtime rather than load, and belongs to the same family
of things a parser waves through:

- **`"a %s" + "b" % args`.** `%` binds tighter than `+`, so the format applies
  to the last literal alone. With the placeholders in an earlier segment the
  call fails and Godot hands back the string unformatted, so the player reads a
  literal `%s`. Long prose here is nearly always a concatenation chain, which
  makes this easy to write and easy to miss -- it shipped in two minigames'
  wrong-answer explanations, the one line those screens exist to deliver. Wrap
  the chain in parentheses before applying `%`.

`python3 tools/check_static.py` covers all four and CI runs it. Run it after
any merge, rebase or conflict resolution — that is when this class of damage
appears, and it is the one class a parser cannot warn you about.

It also carries three checks that are about geometry and reward flow rather
than syntax, added because each failure shipped: a completion handler that
underscores both of its arguments, a hall door whose focus rect no longer has
walkable floor within the interaction margin, and a knowledge exhibit placed
where the player can never stand close enough to collect it. The last two need
the sprite's opaque box, so the file carries a small standard-library PNG
reader; it handles 8-bit RGBA only and skips anything else rather than guessing.

## A minigame that unlocks nothing is a worksheet

Every minigame has to close a three-part loop: the room raises a question, the
play teaches the concept, and clearing it hands back something the case needs —
evidence, a key, a device, a route. Two of the eight failed that test and were
easy to miss, because both *looked* wired up:

- The greenhouse set `greenhouse_<bed>_mastered` on a full clear and nothing in
  the repository ever read it. The herb payout was real, but mastery bought
  nothing. It now grants a bonus yield and files what the bed actually taught,
  including where that herb turns up in Mrs. Lin's counter-formula.
- The chemistry sorter is reached from `scenes/floor_1/chemistry_room.gd`, not
  `scripts/`. A grep confined to `scripts/` says it is orphaned. Four of the
  room scripts live under `scenes/`, so an audit that only walks `scripts/`
  will draw the wrong conclusion twice over.

When adding a minigame, grep for its completion flag and confirm something
*reads* it. Writing a flag is not a reward.

## The minigame data is the lesson, so it is under test

`tests/minigame_science_contract_test.gd` asserts the properties the teaching
rests on, not that the code runs:

- the sorter's colour-is-substance encoding reproduces every authored
  `chemical` flag, and every substance and texture it names is one the dish can
  actually draw;
- every photosynthesis stage has an allocation that fits the ration;
- a gear train's ratio depends only on its first and last gear;
- a timeline stage's reliable clues agree and its liar is a whole number that
  reaches the answer buttons;
- no two jars in a flame stage burn for the same time, which is what makes the
  failure hint's "it goes out sooner" strictly true.

These fail silently in play — a wrong encoding teaches the opposite lesson
without erroring — so they are worth more than any smoke test. Run with
`godot --headless --script tests/minigame_science_contract_test.gd`.

## Underscoring a completion handler's arguments gives the reward away

`MinigameLauncher` hands the room two things: whether every stage was cleared,
and how many actually were. The wake room's handler underscored both, so
opening the candle drill and closing it immediately granted Dr. Lin's scroll,
the notes tool and the field kit — and because the same handler set the flag
the desk reads to decide what to offer, the drill then vanished for good. The
player's words were "the system seems to think I finished it".

The intent behind the unconditional grant was sound and is preserved: the
scroll carries progression, so it must never be locked behind clearing all
eight stages or a child who cannot beat the drill is stuck in the first room.
The fix separates the two. Clearing one stage earns the scroll; clearing none
earns nothing and the desk offers the drill again; only a full clear switches
the desk over to the scroll, so the remaining stages stay reachable.

The other four rooms already branch on `cleared_all`. `check_static.py` now
fails a handler that underscores both parameters, because the omission is
invisible on the page — underscoring a parameter is exactly how you say you
meant to ignore it.

## The hall's floor image must contain no walls

`hall_floor_bg.png` and `hall_walls.png` are separate images and only the wall
one is authoritative: the 44 collision polygons and all seven door positions
were derived from it.

The floor image shipped for months as a complete dungeon in its own right —
its own walls, rooms and coloured archways — while the code described the pair
as one map's floor and walls "aligned" at an exact scale. They never
corresponded. Phase correlation between them peaked at 6.1x the mean, where
the same test against a shifted copy of one image measures 614339x, and a
search across scale 0.9-1.2 and offset ±160 never cleared 2.1% overlap. The
player saw two sets of walls at once, and could walk through one of them.

It is now ground only: tile, grates, pipe runs and coloured light, 1152x768
scaled uniformly by 1.666667. Both images are 3:2 like the map, so neither is
distorted.

**Keep it that way.** A floor image with structure in it puts walls on screen
that the player can walk through, and no scale or offset can repair that —
there is no alignment to find, only two maps.

## Hall collision is derived from the wall art, and nothing else

This used to be a hand-drawn set of 34 `Wall_*` polygons plus 163 `WallFix_*`
patches that tried to catch up with what the art painted, and it never fully
did: a quarter of everywhere the player could stand was inside a painted wall,
three alcoves had to be left deliberately open because the art sealed doors the
level design needed, and every art change reopened the whole argument.

Collision is now generated from the wall image, so there is no argument to
have. The opaque pixels are quantised to 4px and decomposed into axis-aligned
rectangles — 1396 of them at the time of writing — which puts art and collision
within 1.66% of the map of each other, in both directions. An air wall is not
something that can be expressed any more, and neither is a wall you can walk
through.

That moves the responsibility upstream: **the wall image is the level design.**
A door that is not painted is a door that does not exist, and a corridor painted
shut is shut. Regenerating is cheap; arguing with the picture is not.

Any regeneration has to preserve the hand-placed nodes — the two visual sprites,
the storage rack, the three final-key machines, the five knowledge exhibits —
and then re-check reachability. `tools/check_static.py` covers the doors and the
exhibits, including whether their footing connects to the arrival spawn. It does
not cover the NPC and clue markers, and the 2026-08-19 swap put seven of those
inside stone. They were moved to the nearest standable floor **with room around
it**, not to the nearest standable pixel, which wedges a body against a wall.

## A potion the player cannot see is a potion they will not use

Every potion runs on the same two lines of `GameState`: a countdown in
`potion_effects` and a pair of signals. That is enough to *be* an effect and not
nearly enough to *read* as one. Three of the six shipped with no presentation at
all — `EFFECT_STYLE` in `potion_effects_hud.gd` covered `swift`, `vision` and
`green`, and `_on_potion_applied()` returns early on an unknown effect, so
drinking a Shroud Potion produced no burst, no chip and no aura. The Guardian
went blind and nothing on screen said so.

Presentation is split by the question it answers, and the split is worth
keeping:

- **`PotionHud` (autoload) answers "how long".** Entry burst, corner chip with a
  ring countdown, edge aura. It is screen space and it outlives the room.
- **`PotionFieldEffects` (`scripts/potion_field_effects.gd`) answers "what is it
  doing".** The detective fading under Shroud, the afterimage trail under
  Swiftness, the Guardian's footprints under the Revealing Draught, the mire
  itself. It is world space and it belongs to the hall.

Neither may set `process_mode`. Opening the backpack, keys, notes or map calls
`get_tree().paused = true`, and because `enemy.gd`, `enemy.tscn` and
`game_state.gd` all leave `process_mode` at its default, that one line freezes
the Guardian body, the Guardian timers, the offscreen patrol and every potion
countdown together. Marking any of them `PROCESS_MODE_ALWAYS` would let the
Guardian walk while the player reads a map. **Check that before adding one.**

Two details that are easy to get wrong and invisible until played:

- The afterimage drops **per distance travelled, not per second**. Time-based
  spacing makes the trail thin out exactly when the potion speeds the player up,
  which is backwards — the same mistake the walk cycle used to make.
- The mire slow is applied inside `get_guardian_*_speed()` rather than in
  `enemy.gd`, so the contact estimate on the HUD prices the slow at the rate the
  legs actually move at, and the walk cycle slows with it for free.

`green_potion` had `"effect": ""` and no recipe: it existed in the tables and did
nothing anywhere. It is the Toxic Mire now. New potion art was derived rather
than drawn — `tools/derive_counterplay_item_art.gd` already hue-shifts
`recipe_vision.png` into the counterplay recipes, and two more entries there give
the mire and the draught their own pages.

### An effect gated behind a condition is an effect that does not exist

The Vision Potion read as doing nothing, and it very nearly was. Its flashlight
widening sat *inside* `if not power_restored or GameState.chase_mode:`, so the
moment the player restored power — a mid-game milestone they keep — drinking it
changed the beam not at all, and the only thing left was a 15% camera zoom that
nobody can see. The potion had been quietly dying for most of the game. The
widening is a multiplier on whatever beam is in force now, so the tight pursuit
beam still reaches the 430/160 it always did and the restored-power beam grows
with it.

The Daze Potion had the opposite problem: the mechanic worked perfectly and
nothing said so. It calls `stun_guardian()` directly and never
`apply_potion_effect()`, so it emitted no `potion_applied`, so PotionHud gave it
no burst, no chip and no aura — and a stunned Guardian looks exactly like a
patrolling one between waypoints, from behind, possibly off screen. It now
registers a display-only timed effect alongside the stun, and wears an orbiting
mark while it lasts. **Nothing reads `is_potion_active("daze")` for gameplay;
that entry exists to be looked at.**

The lesson both share: the potion tables are the wrong place to check whether a
potion works. `is_potion_active` returning true proves the countdown is running,
not that a single pixel changed.

## 装饰框的内腔比它的外框小得多

`bag_detail_frame.png` 画在 `(504,120)` 的 `359x420` 上，但那圈铜饰本身很厚：
实测内腔只有 `x 568..799`（宽 231）、`y 200..456`。框里的四个标题与描述标签
原本一律是 `526` 起、`316` 宽 —— 比内腔宽出 85px，两侧各戳出约 42px，中英文
都一样。`DETAIL_TEXT_X` / `DETAIL_TEXT_W` 现在把它们收在腔内。

内腔是量出来的，不是估的：沿贴图中线取亮度剖面，从两端向内找铜饰亮度掉下去
的位置。换框图就得重量一次。

## 中文全是豆腐块，因为界面根本没指定过字体

房间里的标签一个都没调用过 `add_theme_font_override`，项目也没有全局主题，
于是它们统统落在引擎自带的默认字体上 —— `Open Sans SemiBold`，只有拉丁字母。
英文时毫无破绽，一切到中文，目标面板、对话框、提示语整片变成方块。菜单反而
是好的，因为 `ArchiveUi.apply_label()` 会显式指定字体，两条路一直不一样。

修法是把默认字体本身换掉（`gui/theme/custom_font`），而不是去几十个 Label 上
逐个补 override。

**但 `project.godot` 的段内注释会让紧随其后的键被静默忽略。** 我第一版把说明
写在 `[gui]` 和 `theme/custom_font=` 之间，导出、重跑、截图，豆腐块纹丝不动；
`ProjectSettings.get_setting()` 读出来是空字符串 —— 键存在（引擎内置），值却
没被吃进去。把注释挪走，同一行立刻生效。这个文件里**不要**在段内写注释，要
解释就写在这里。

判断字体到底行不行，一行就够，不必靠肉眼看截图：

```gdscript
print(Label.new().get_theme_font("font").has_char("行".unicode_at(0)))
```

### 界面文案和正文走的是同一张表

`CaseLocale.line(english)` 以英文原句为键，`CaseScriptZh.LINES` 是那张表。
行囊、钥匙栏、获得物品提示原本把英文直接贴在 `.text` 上，所以中文玩家拿到
钥匙看到的还是英文。现在这些都在显示处过一道 `line()`，整张 `KEY_INFO` 数据表
因此一次性被覆盖，不必逐条改数据。

`tools/check_translations.py` 曾经把这些误判为“陈旧”。它的判据写成了
`translated - set(found)`，而 `found` 只收“到达特定 sink”的句子；文档里说的却
是“这句英文在源码里已经找不到了”。界面文案躺在数据表里、一个 sink 都不沾，
于是整批被判死。现在按它自己声明的语义查全部字面量。**它报 100%，指的只是
那几个 sink 覆盖的范围，不是全部界面文字。**

## 三块加载 / 转场画面，都不能是引擎给的那一块

**网页加载屏**（`web/shell/loading_shell.html`）用的是游戏自己的标题画面当底，
上面压一块和 case intake 同款的档案面板。位置不是随手摆的：舞台按引擎的规矩
做成 1024x768 等比居中的信箱框，面板钉在 `31.45% / 57.33% / 37.11%`，也就是
真面板的设计坐标 `(322, 440)` `380x297` 换算出来的比例。所以淡出的那一帧画面
完全不动 —— 玩家看到的不是“换了个界面”，而是同一块板上的字变了。**改动
start_ui 里的面板高度常量，就必须回来同步这三个数。**

底图是内嵌的 base64（1024x768 的 webp，约 60KB）。这一屏必须在网络还在搬
130MB 的时候就画好，多一个请求都是在拖它后腿；内嵌之后本地起服务、离线打开
也都长得一模一样。

**开启案卷的转场**曾经是穿模的。它把 1536x1024 的 `menu_banner_frame.png`
（宽高比 1.5）塞进一个 500x156 的框（宽高比 3.2），`KEEP_ASPECT_CENTERED`
于是把牌子画成 234 宽，而压在上面的文字是按 404 宽排的 —— 字比牌子宽了将近
一倍，两头都戳在外面。现在牌子改用 `panel_style()` 画，尺寸写死在
`PLATE_RECT`，文字排在 `PLATE_PAD` 的内边距里，比例对不上这种事不可能再发生。
**拿一张固定比例的图去当可变尺寸的框，迟早是这个下场。**

## 存档原本会在开新案件时被删掉

游戏只有一个自动存档位，而“开始新案件”做的第一件事是
`GameState.delete_saved_game()` —— 没有确认、没有备份，上一轮的进度当场消失。
主菜单还会火上浇油：`resume_label()` 读的是内存里的实时状态，而主菜单上根本
还没读过档，于是明明有存档，界面却写着“尚无进行中的案件”。玩家有充分理由
认为自己的存档已经没了。

现在有两层：

- **快照库**（`scripts/save_slots.gd`）。每抵达一个新房间留一张，开新案件之前
  再留一张，存在 `user://saves/`。快照就是自动存档文件的整份拷贝，不另外维护
  索引 —— 索引迟早会和真实存档漂移，而存档本身已经带着复盘所需的全部字段，
  列表上那几行一律从快照自己身上读。
- **存档记录界面**（`scripts/save_slots_ui.gd`）。主菜单上始终可见的入口，和
  通关后才解锁的剧情档案 `CaseArchiveUi` 是两回事，别把两者混起来。

写快照的时机合并进了自动存档：`save_room_checkpoint()` 只置一个
`_snapshot_pending`，真正的拷贝发生在 `_flush_queued_save()` 里、而且必须在
`save_to_disk()` 返回成功之后 —— 早一步拷到的是上一次的内容。

同一个房间、同样的证据与知识数量会被判为“还停在原地”而跳过，否则在一个房间
里来回走几趟就能把有用的旧快照挤出 24 张的上限。

## 手机和电脑共用一份网页版

触摸操作层（`autoload/touch_controls.gd`）是自己决定去留的：收到
`InputEventScreenTouch` 就现身，收到键盘事件就退场。不做一次性的设备检测，
因为同一台机器随时会换手（手机接键盘、笔记本有触屏），一次性判断必然有一半
人是错的。

它只做移动这一件事，而且不碰玩家速度：摇杆按住 `move_*` 四个动作，
`player.gd` 那句 `Input.get_vector(...).normalized()` 照原样吃下去。方向对了
就够，移动、走路动画、药水加速全都沿用同一条路径，一行都不用改。

三个位置上的约束，少一个就出问题：

- **层号 15**，低于所有 UI（房间 UI 是 30，最低的面板是 20）。摇杆被面板盖住
  是对的——面板开着时本来也不该走路。
- **输入走 `_unhandled_input` 而不是 `_input`**。对话框、检查面板、小游戏都是
  会吃输入的 Control，先经过它们，落在面板上的手指就不会把角色推着走。
- **`player.gd` 要问一句 `TouchControls.blocks_world_point()`**。触摸会被模拟
  成左键按下，不挡的话每次推摇杆都同时派发一条“走到脚下去”的点地指令。

只在 `player` 组里有人时才出现，所以菜单和过场里不会有一个操控不了任何东西的
摇杆浮在标题上。这个组是这次才加的——`scripts/examples/door_puzzle_example.gd`
一直在查它，而在此之前没有任何人加入过。

### 点物品走过去这条路，从来没有真正走通过

`wake_room.gd` 的道具点击只做了一半：它检查完可达性，把
`pending_mouse_interaction` 设上，然后就返回了。那个变量只驱动
“Walking to the interaction...”这句提示，没有任何人因此走起来。于是玩家盯着
提示、角色一步不动，而到达回调永远等不到。门和线索都老老实实调了
`begin_mouse_interaction*()`，只有道具漏了；连 `PROP_INTERACT_RADIUS` 那个常量
都定义好了却从没被引用过，正是这条路半途而废的痕迹。

键盘玩家自己走过去按 E，走的是另一条分支，所以桌面上永远撞不到。手机上点击
就是主要交互方式，它是致命的。

补上调用之后还差第二段：落脚点必须用建表时算好的 `p["position"]`。
`_get_visual_interaction_approach()` 已经沿着 13.5px 的接触带挑出了一个可行走
的点，那正是判定要求玩家站的位置；自己按半径绕着 `position` 推算，落脚不是差
在带外就是踩进不可走的像素里——而 `calculate_room_path()` 对不可达目标直接返回
空路径，不做任何吸附。

第三段是算术：接触带 13.5px、判定带 14px，只剩 0.5px 余量，而
`move_along_path()` 允许在目标点前 `click_stop_distance`（6px）就停下。角色明明
已经贴到物品上，仍然会被判为不够近。到达判定因此用 `CLICK_ARRIVAL_MARGIN`
（22px）而不是默认的 14px —— 玩家是被送到一个本来就在带内的点上的，停在它
六像素外不该算失败。

## A CanvasLayer cannot fade, and it will not tell you

Both screen transitions built their overlay as a `CanvasLayer` with the veil,
frame and labels as children, faded the children *in*, and then faded the whole
layer *out* with `tween_property(layer, "modulate:a", 0.0, ...)`. `CanvasLayer`
derives from `Node`, not `CanvasItem`, so it has no `modulate` at all: the
tweener was never created, the tween ran empty, and the overlay was freed at
full opacity. Every case-open and every room change ended in a hard cut that was
supposed to be a fade, in both directions, for as long as the code existed.

The overlay now hangs off a full-rect `Control` inside the layer and the fade
acts on that. Anything that needs to fade as one piece needs a CanvasItem to
fade.

What made this survive is how differently it reports itself. The editor build
says `The tweened property "modulate:a" does not exist` and names the class; the
exported build takes another path and says `Type mismatch between initial and
final value: Nil and float`, with no property, no object and no script line —
and `Nil` there is precisely the missing property. Neither message appears
unless someone is watching a console, which on the web build means opening
devtools. Checking `layer.get("modulate")` in a headless one-liner answers it in
seconds and is worth doing whenever a fade "does nothing".

## A deploy that returns 200 is not a deploy that works

The web build ships as four fixed filenames totalling 131MB, and every way the
upload can go wrong still leaves a URL that responds. The `.vercelignore` trap
is the sharp one: the Vercel CLI falls back to `.gitignore` when a directory has
no `.vercelignore`, and `web/game/.gitignore` is `*` — so the deploy reports
success having uploaded `vercel.json` and nothing else. Serving `index.wasm` as
`application/octet-stream` fails differently and just as quietly, because the
browser cannot stream-compile it.

Check the payload, not the status code: sizes must match `ls -l web/game/`
exactly, `index.wasm` must be `application/wasm`, and both large files are
self-identifying (`GDPC` and `\0asm` in their first four bytes). `web/README.md`
carries the commands, along with the two DNS traps that cost the most time here
— Vercel never retrying a certificate for a domain that was added before its
DNS resolved, and macOS `mDNSResponder` serving a stale address to `curl` and
browsers while `dig` reports the correct one.

### The browser is a different platform, so play it there

Both bugs above were invisible until the exported build ran in an actual
browser: one is web-only, the other only *reports* itself usefully off the web.
A third was too — `AudioStreamGenerator` cannot be sampled, and the web export
defaults every `AudioStreamPlayer` to sample playback, so the intro's procedural
score was silent in a browser and fine on desktop. It needs
`playback_type = AudioServer.PLAYBACK_TYPE_STREAM`, which costs nothing
anywhere else. Loading the scene headless found none of the three; opening the
deployed URL with a console visible found all three in one run.
