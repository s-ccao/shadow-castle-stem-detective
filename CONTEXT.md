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

- `*_DOOR_POSITION` — centre of the interaction trigger circle, **and** the
  return-spawn anchor used by `get_floor_one_spawn_anchor()`. Moving it
  changes where the player can interact and where they land coming back.
- `*_DOOR_FOCUS_POSITION` — where the interaction bracket is drawn. Purely
  cosmetic; safe to nudge.

Doors are embedded in walls, so `*_DOOR_POSITION` sitting inside a collision
polygon is normal and expected. What matters is that the trigger radius
covers standable floor in front of the door.

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
makes every direction opaque and blacks out the whole screen.

Sight blockers are rasterised from `scenes/wall_collisions.tscn`, so
decorative art without a collision polygon does not block vision.

## `scenes/wall_collisions.tscn` is the authority for the hall

Both collision and sight blocking read it. The node structure must stay
`WallCollisions -> Wall_XXX (StaticBody2D) -> Shape (CollisionPolygon2D)`;
`build_sight_blockers()` walks exactly that shape and silently sees nothing
if the hierarchy changes.

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

## Hall collision is derived from the wall art, with three deliberate holes

The 34 hand-drawn `Wall_*` polygons covered only part of what
`hall_walls.png` paints. Measured with the real 14x8 player box, a quarter of
everywhere the player could stand was inside a painted wall, and the entire
out-of-bounds ring outside the dungeon was open — you could walk into the
border masonry and around the edge of the map.

`WallFix_000..162` close that. They are axis-aligned rectangles from a greedy
decomposition of (art ∪ outside) minus the existing polygons, which is exact:
zero overflow, so they never block a pixel the art leaves open. Standing
inside a wall drops from 24.9% of the walkable area to 8.7%, and roughly half
of what remains is the pseudo-3D cap band, where walking behind a wall top is
the intended look.

**Three alcoves are deliberately left open** — the Chemistry door, the Library
door, and the building holding the hidden Library key. The art seals all three;
filling them makes the doors unapproachable and the key uncollectable. That is
a disagreement between the artwork and the level design, and it can only be
settled by redrawing an opening or moving the object, not by editing collision.

Any change here must re-check two things, because both are easy to break and
neither shows up until play: that all nineteen key positions still have
standing room within 60px, and that the Guardian's 24x24 body still shares a
connected region with the player's. Tightening collision to match the art
exactly fails both.
