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
makes the graft unnecessary: it draws an arch at all seven room doors natively,
and all eight focus values were re-checked against it without one needing to
move.

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
the body actually fits on, and **every path waypoint must be resolved through
`cell_nav_point()`, never `cell_to_world()`.** `cell_to_world()` is for fog,
door placement and rendering — anything that describes a cell rather than
walking to it.

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
