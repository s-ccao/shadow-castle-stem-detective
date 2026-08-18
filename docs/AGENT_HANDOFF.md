# Shadow Castle: STEM Detective — Continuation Handoff

**Date:** 2026-08-14  
**Project:** Godot 4.7 / GDScript / 2D pixel-art mystery  
**Viewport:** 1024×768  
**Current phase:** feature-complete prototype; polish, visual QA, regression testing, and portfolio-ready GitHub documentation remain.

## Start-of-task brief

You are continuing a late-stage student portfolio game. Preserve the current in-progress changes. Make focused, playable improvements; validate every change and report concrete evidence. Do not replace systems wholesale unless the user asks for a redesign.

## Player journey implemented now

1. **Main Menu → opening cutscene → Wake Room.** The cutscene establishes Dr. Lin, Ashford Castle, and the investigation.
2. **Wake Room tutorial.** The desk unlocks the portable investigation kit and Dr. Lin's partial Hall map. The bed awards the Wake Room key. The bookshelf gives the oxygen rule and Chemistry key. The door then accepts the answer and opens.
3. **Castle Hall arrival.** The unlocked Bag, Key, Note, and Map hubs remain visible. A one-time blue floor route guides the player to the Chemistry door, a brass core, and back. The player may still return to Wake Room during this guide.
4. **Investigation rooms.** Chemistry, Greenhouse, Circuit, Dining, Library, and Final Room each use room-specific clues, locks, inventory/knowledge state, and return paths.
5. **Finale.** The final case board supports the ordinary Butler conclusion and the optional sealed-record route revealing the Mechanic's forged command chain.

## Recent completed work

### UI and flow

- Audio is owned entirely by the `GameAudio` autoload against a `Master / Music / SFX / UI` bus layout. Call `GameAudio.play(&"event_id")` with a name from `SFX_CATALOG`; never load a stream or touch `AudioServer` directly from gameplay code. The three music layers are started together and must never be stopped or restarted — intensity is a gain change only, and `audio_contract_test` fails if a layer stops. Regenerate assets with `node tools/generate_audio_set.mjs`.
- Rebuilt the final deduction board as a standalone UI scene after an earlier compass-based layout was too cramped.
- Reworked the alchemy workbench into an image-led, readable three-reagent interface; it uses code-native labels and interaction feedback. Its captions sit on brass-edged specimen plaques rather than over the painted plate, and rack rows reserve their icon's width in the row stylebox — never with padded text, which is how names previously ended up drawn under their own icons. `ui_design_contract_test` asserts that clearance per row.
- Improved the Case Ledger / clue journal and the Bag and Map hubs. Bag now has filing categories/counts, item inspection feedback, keyboard focus, and a compact open animation. Map now has a player marker, a survey ledger, room/key legend, and exploration state.
- Main menu, death/retry, game-over, and intro-cutscene systems received visual passes. Treat them as implemented, but include them in visual QA.

### Room and state reliability

- Chemistry exit previously left the player without movement; its pause/input restoration was fixed. Re-test this on every room-flow change.
- First Hall route markers are temporary and are cleared once the three-step route completes.
- `GameState.grant_wake_room_toolkit()` repairs older saves where the desk was previously read but no actual map reward existed.

### Character presentation

- All eight playable rooms now use one furniture-calibrated player `VisualRoot` scale, producing an approximately 91-pixel opaque standing height. In Chemistry this is about 27% of the authored alchemy-table depth instead of the earlier bottle-sized 13%. The `CharacterBody2D`, collision shape, movement speed, navigation, and interaction radii remain unchanged.
- Chemistry's Butler and Dr. Lin memory echo, Greenhouse's Gardener, and Circuit's Mechanic now use asset-specific visual scales plus explicit foot anchors through `AnimatedNpc.set_visual_foot_anchor()`.
- The Castle Guardian uses scale `1.0` with a bottom-aligned anchor, keeping it slightly larger than the detective without changing its body or collision. The Final Room's fallen Mrs. Lin illustration uses `0.08`; its authored blocking collision is unchanged.
- Native 1024×768 before/after/furniture-corrected captures for Wake Room, Hall, Chemistry, Greenhouse, Circuit, Dining, Library, and Final Room live under `docs/evidence/2026-08-13-character-scale/`. Alpha-bound reports document source-frame dimensions and direction rows.
- Existing character art was sufficient for this calibration; no new PixelLab or generated character assets were required.
- Source/provenance note: `assets/characters/animated_pixel_v5/README.md`.

### Guardian hunt and tracking

- Castle Hall now activates the Guardian hunt on the player's first arrival. `GameState.GuardianMode` is the authoritative `DORMANT / CHASE / PATROL` FSM; legacy `chase_mode` and `enemy_chase_active` remain compatibility mirrors.
- In Hall, the rendered Guardian follows the player through the existing A* grid at a fair chase speed below the detective's base movement speed. Entering any investigation room records its Hall position and switches it to persistent off-scene patrol along an A*-validated loop; returning to Hall restores chase without spawning it directly on the player.
- `MapHud` displays a persistent bottom-right Guardian minimap. Hall chase shows blue player + red Guardian signals; safe rooms hide the player signal but continue to advance/show the Guardian's Hall patrol. Full Map and minimap share the power-gated fog: no architectural leak before Circuit power, gray walked memory afterward.
- Entering pursuit or opening a full-screen Hub dismisses queued reward/unlock cards so chase, map, and interaction prompts never compete for the same screen space.
- Normal Hall loads stage a short, non-lethal reveal before control returns: a dedicated camera pans to the Guardian, it pauses and faces the detective, begins marching, then the player camera resumes and lethal capture is enabled. The first powered return replaces this with the safe route-memory scan. The reveal temporarily hides fog over the Guardian, Hub shortcuts, and minimap chrome, restoring all three afterward.
- A top-center `GuardianContactCountdown` displays a live A*-path contact estimate, recalculated every `0.12s` from current Guardian/player positions and the Guardian's effective `chase_speed`. It becomes an urgent red warning under four seconds. The existing red minimap marker continues to update in Hall and during off-scene patrol.
- Hall entry enforces an `800px` preferred separation. The real A* pressure audit showed 520px gave only 2.76s reaction at pre-Circuit Tier 2; 800px yields 4.32s without weakening +12% escalation. A real Guardian-body overlap retains a `22px` catch fallback in addition to slide-collision detection; CHASE contact is one-hit fatal and opens checkpoint recovery.

### Guardian awareness, escalation and counterplay

- `GameState.GuardianMode` now spans `DORMANT / CHASE / PATROL / SEARCH / STUNNED`. `SEARCH` and `STUNNED` were **appended** to the enum so previously persisted integers keep their meaning.
- Escalation is **derived**, never stored: `get_guardian_escalation_tier()` counts held keys in `GUARDIAN_ESCALATION_KEY_IDS` and caps at `GUARDIAN_MAX_ESCALATION_TIER` (6). `get_guardian_escalation_multiplier()` is `1.0 + tier * 0.12`, so `get_guardian_chase_speed()` runs 145 → 249 px/s. Old saves therefore resolve to the correct tier with `SAVE_VERSION` unchanged.
- `guardian_tracking_serum` starts `true` and defaults to `true` on load. While it is active the Guardian is omniscient and `enemy.gd` skips line-of-sight entirely. `purify_tracking_serum()` clears it permanently, sets the `tracking_serum_purified` story flag, and drops the Guardian to patrol.
- After purification the Guardian targets `get_guardian_stakeout_anchor()` — the door anchor of `get_guardian_objective_room_id()`, registered by `game_world.gd::_guardian_room_door_anchors()` through `configure_room_door_anchors()` during `setup_enemy()`. Unaware movement is `GUARDIAN_STAKEOUT_SPEED` (44 px/s).
- `enemy.gd::_has_line_of_sight_to_player()` is the single detection seam: it returns false when `GameState.is_player_shrouded()`, true inside `GUARDIAN_PROXIMITY_ALERT_RADIUS` (78px) with a clear segment, false beyond `GUARDIAN_SIGHT_RANGE` (300px), and otherwise tests `GUARDIAN_SIGHT_HALF_ANGLE_DEGREES` (46°) against `facing_direction`.
- Occlusion uses `game_world.is_sight_line_clear()`, which samples `astar_grid.is_point_solid()` every `GUARDIAN_SIGHT_SAMPLE_STEP` (24px). It deliberately does **not** use `is_player_position_walkable()`, because door cells are non-walkable but must stay visible — otherwise a player standing in a doorway is invisible.
- Edge transitions call `report_player_seen()` (→ CHASE, records last-known position) and `report_player_lost()` (→ SEARCH for `GUARDIAN_SEARCH_DURATION` 6s at 96 px/s). `_update_guardian_timers()` counts stun down first, then search, returning to patrol in both cases.
- Counterplay items live in `POTION_INFO`/`RECIPE_INFO`: `purification_potion` (`purify`), `daze_potion` (`daze`, 7s stun), `shroud_potion` (`shroud`, 12s). `inventory_hud.gd::_use_entry` dispatches on `effect_id`. All three blueprints are granted together by `dining_hall_room.gd::_grant_counter_serum_blueprints()`.
- `game_world.gd::_update_guardian_awareness_readout()` drives the bilingual `GuardianAwarenessStrip`. Any new Guardian state must be added there or the HUD will silently under-report.
- Coverage: `tests/guardian_awareness_flow_test.gd` (logic) and `tests/guardian_awareness_visual_capture.gd` (7 captures). Note that the headless Hall intro leaves `dialogue_active` true, so tests must call `guardian.call("_update_awareness")` directly rather than waiting for physics.
- The six new item textures were produced by `tools/derive_counterplay_item_art.gd`, a headless hue-band rotation over existing hand-authored art. Re-run it after changing a source texture; it preserves outlines, cork and brass by skipping low-saturation pixels.

### Room spatial contracts

- `RoomSpatialRuntime` is the shared geometry seam for alpha-bounded visual rectangles, 14px interaction contact, 10px focus padding, visual-bottom depth reversal, and physics-query safe spawn resolution.
- Wake, Hall, Chemistry, Greenhouse, Circuit, Dining, Library, and Final Room now use visible prop footprints rather than broad center-point radii. Player behind/above a prop draws below it; player in front/below draws above it.
- Wake interactions separate visible footprint from approach navigation. `_get_visual_interaction_approach()` samples physically walkable points on an exact 13.5px edge band while `interaction_rect` remains the opaque visual rectangle. The shelf art's +6px floor-edge correction aligns that band with the collision polygon and walkable mask; changing shelf art/collision must rerun both Wake and room-spatial suites.
- The Hall default entry plus all eight named return IDs resolve to zero static overlaps and at least three open cardinal exits. The formerly blocked Final Room start resolves to `(724, 770)` with three exits.
- `tests/room_spatial_audit.gd` proves 48 exact 14px boundary checks, 25 front/behind z reversals, 25 Hall interaction footprints/focus boxes, eight room starts, and nine Hall return starts. Native evidence contains safe-spawn, behind, and front captures for all eight areas.

### Orthogonal route and item models

- The first Hall route still uses the real A* grid, but its presentation is collision-safely smoothed into horizontal/vertical L segments. Arrows are snapped to cardinal directions, every turn gets a dedicated 90-degree glyph, the useless start-cell U-turn is removed, and marker spacing is now `96px`.
- `GameState.ITEM_VISUAL_INFO` is the single item-art catalog used by Bag, alchemy, Chemistry reference views, and reward cards. It covers both formula blueprints, five ingredients, three potions, and the castle ration.
- New text-free models live under `assets/ui/item_models/`: two formula sheets plus Distilled Water, Iron Salt, and Prism Dust. Existing Blue Blossom, Moonleaf, Swiftness Potion, and Vision Potion art remains because it already met the visual target.
- Bag slots now present catalogued items on accent-backed specimen plates; recipe glyph placeholders are gone. The alchemy archive displays blueprint art beside formula names and uses the same ingredient textures in the reagent rack and reaction sockets.

### Hub and room-device polish

- `ArchiveUi.decorate_hub()` adds shared brass corner structures, a mode stamp and a concise task-protocol rail without reparenting production controls. Bag, Key, Note and Map therefore share one field-kit identity while retaining four distinct working structures.
- Bag Hub has exactly four files: `all`, `potions`, `materials`, `papers`. `CATEGORY_BUTTON_RECTS` are the four authored top-tab rectangles at the 960×640 board size; the controls are transparent hit/text layers over those recesses, not a `GridContainer`. Materials combines `herb_counts`, `material_counts`, `dish_counts` and `final_key_fragments`; Papers combines `recipe_items` and `map_items`. Category counts remain independent `CategoryCount` labels. The widened detail stack is measured against the longest title, six-line description and requirement.
- Key Hub is an eight-profile lock register rather than the former scaled picture grid. Explicit slot coordinates do not overlap; every slot exposes index and RECOVERED/LOCKED state, while progress pips and a dedicated 680×138 chamber present the selected key.
- The Key source board's baked 4×2 recesses use the old narrower geometry. `BOARD_ART_SOURCE_RECTS` selects its top row, bottom row and parchment; `BOARD_ART_TARGET_RECTS` fits those regions beneath the redesigned cards in `_create_fitted_board_artwork()`. The full board remains underneath for its title, outer frame and corner stones. Keep the cards authoritative: do not move them back to the source coordinates and do not cover-crop the full board.
- Note Hub has one functional scrollbar system and a real focusable `JournalCloseButton`. The narrower index, 24px column gap and wider dossier page improve long-form reading; its home page shows live record and sealed-archive progress rather than empty parchment.
- Map Hub preserves the full 720×540 authored map, moves it left and widens the survey ledger to 220px (192px copy width). Long pursuit/status text is wrapped at 10px and checked by the rendered-text contract.
- Artwork-fit metadata is deliberately explicit on all four Hubs. Bag uses `full_frame`; Key uses `full_frame_with_fitted_regions`; Note uses `full_frame_content_safe`; Map art and fog use `full_frame_coordinate_locked`. `tests/hub_room_polish_contract_test.gd` enforces the actual sizes and Key containment. Map must never adopt aspect-cover/cropping unless its fog and marker transforms are changed at the same time.

### Circuit-powered blackout memory

- `GameState.story_flags["circuit_power_restored"]` is the single progression authority and is already persisted. `scripts/circuit_room.gd::_update_switch_puzzle_state()` sets it only after the Master switch resolves the completed sequence.
- `game_world.gd::update_fog_of_war()` always starts from alpha 1. Before power, only the current 230px/80px-clear, wall-occluded flashlight overwrites that black image; `discovered_fog_cells` is recorded but never rendered. Guardian chase no longer determines whether route memory exists.
- `GameState.reveal_hall_position()` continues recording the player's 32px Hall cells during blackout. On the first powered Hall update, `_hydrate_powered_hall_memory()` expands each saved cell to the 2×2 set of 16px world-fog cells, including history from before a room transition or save/load.
- After power, discovered world cells render at `DISCOVERED_DARKNESS` (0.68). Current flashlight cells can still be clear; every unwalked cell remains alpha 1.
- `map_hud.gd::_refresh_fog_texture()` is fully black before power. After power, `_shade_map_circle()` paints walked/visited areas at `POWERED_MEMORY_DARKNESS` (0.66), never transparent. `GuardianMiniMapFog` reuses that exact `ImageTexture`, preventing minimap information leaks.
- `tests/power_blackout_flow_test.gd` is the state contract. `tests/power_blackout_visual_capture.gd` waits for the Guardian reveal (which intentionally hides fog) before capturing normal gameplay; do not remove that wait or the evidence becomes false.

### Power-restoration milestone and pressure audit

- The Master switch sets `power_restoration_sequence_pending`, unlocks Map and defers `_play_power_restoration_impact()`. The impact owns two generator rings, a generator settle tween, short camera-offset shake, a two-flash `PowerRestorationFlash` and `PowerSurgeAudio`.
- `assets/audio/sfx/power_restore_surge.wav` is original deterministic synthesis, not a downloaded sample. Regenerate it with `node tools/generate_power_restore_sfx.mjs`; provenance and format are in `assets/audio/README.md`. Its Godot player is -7dB to preserve headroom.
- First powered Hall return calls `_begin_power_restoration_return_sequence()` instead of `_begin_guardian_entry_sequence()`. It sorts saved 32px route keys radially from `CIRCUIT_DOOR_POSITION`, reveals them over `POWER_ROUTE_SCAN_DURATION` (1.20s), and drives `PowerRestorationStatus` plus `PowerRouteScanWave`.
- Scanning and the 1.15s completion hold disable Guardian catch/physics and hide ETA/awareness UI. The player and Hub rail return at scan completion so Map can be opened immediately. `power_restoration_sequence_seen` prevents replay; `power_map_reviewed` clears the temporary route-panel/objective copy.
- `tests/standard_flow_pressure_audit.gd` uses the real Hall A* path and current speeds. Pre-Circuit Hall exposures are 14.76s, 16.53s and 7.64s (38.93s total, separated by two safe rooms). Worst return reaction is 4.32s at Tier 2 with the 800px separation. Raw evidence lives in `docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md`.
- `tests/power_restoration_milestone_test.gd` is the state/timing contract; `tests/power_restoration_visual_capture.gd` owns four native captures. Keep the Map-visible assertion: it caught an old-save/toolkit condition hiding the whole Map CanvasLayer despite successful state acknowledgement.
- The staged red-stain flow uses three catalogued trace models—Cleaning Powder, Indicator, Broken Glass—in the dialogue's evidence rack. Tests prove the Bag feature card remains hidden through inspection and evidence recording.
- Final Case Board still validates evidence combinations and slot roles, but the lever now reads `SEAL ACCUSATION` / `TRACE COMMAND` rather than naming either suspect before the resolution.
- Library explicitly separates knowledge from questions. The tall wavelength case teaches spectrum order, the violet reflection cabinet teaches reflection/absorption, and the reinforced light archive teaches additive mixing through a dedicated parchment reader. Players must explicitly file each record. The paired question terminals remain on the central research, east writing, and west globe desks; they show only a filed-reference notice and the challenge, never the solution.
- Interaction selection is FIRST-MATCH over `INTERACT_ITEMS`, so an earlier entry whose rect overlaps a knowledge shelf silently makes that shelf unfindable. Two shelves previously sat at the room's top edge (y 37–215) with their plaques drawn at y≈21, which is why players could only find one of three. `tests/library_knowledge_access_test.gd` now walks real standable positions and fails if any shelf drops below 100 selectable spots, is covered by an earlier entry, or has a plaque above y=80.
- The desk games are now five-stage mini-games in `LibraryLightLabUI`. Prism Cascade orders 3, 4, 5, 6 then 7 spectral bands on a dispersion rail; Pigment Bench explains a green leaf, red apple, yellow lemon, white chalk and black soot with live incoming/outgoing beams and a perceived-colour swatch; Additive Relay renders cyan, magenta, yellow, white and amber from additively blended lamp discs with off/half/full intensity per lamp. Every game shows stage pips, a progress bar, score, hint count, a hint that never solves the stage, and a per-stage reset. Wrong answers explain the failed model and consume nothing. Clearing all five stages awards one persistent filter; empty central slots reject interaction until that filter is earned. Inserting all three reveals the pale-neutral archive layer.
- Knowledge progress uses `library_{spectrum|reflection|additive}_knowledge_learned`; challenge rewards use `library_{red|green|blue}_filter_earned`; central insertion retains `library_*_filter_active`. Legacy saves with an earned/active filter automatically receive the corresponding knowledge flag.
- `CircuitLayout` is the shared source for all three switch positions/sizes/sequence labels. Circuit Room creates distinct Auxiliary, Regulator, and Master switch models at those locations; Map Hub projects repair markers directly from the same vectors onto the 636×478 room image. No hand-copied map coordinates remain.

### Archive UI experience

- `ArchiveUi` now owns shared void/panel/brass/violet tokens, semantic status stamps, stronger physical button feedback, focus-cycle support, and Hub-entry arbitration.
- Bag/Key/Note/Map entries sit on a labelled field-kit rail. Full-screen Hubs retract the rail and restore it on close; safe rooms automatically use a compact three-tool rail because the full Hall map entry is unavailable there.
- Note Hub's accidental white full-screen veil is replaced with the intended dark archive veil. Key unlock cards and other transient rewards dismiss when their destination screen opens.
- Alchemy presents a visible `1 Formula → 2 Reagents → 3 Extract` procedure. The final board presents a visible `1 Pin Evidence → 2 Form/Seat Claims → 3 Accuse` protocol for ordinary and sealed routes.
- Start, interrupted/death, and ordinary/true ending screens retain their unique authored backgrounds and now add factual case metadata or semantic status stamps rather than sharing one generic card template.
- UI before/after gallery: `docs/evidence/2026-08-14-ui-redesign/`. Guardian chase/minimap evidence: `docs/evidence/2026-08-14-guardian-hunt/`.
- New evidence: `docs/evidence/2026-08-14-guardian-pressure/` (close-up, ETA/minimap, orthogonal route), `docs/evidence/2026-08-14-item-models/` (Bag and both formulas), and `docs/evidence/2026-08-15-room-spatial/` (eight-room safe/behind/front triptychs).

## Important implementation locations

| System | Main files |
| --- | --- |
| Persistent state/save/checkpoint | `autoload/game_state.gd` |
| Player movement and visual scale | `scripts/player.gd`, `scenes/player.tscn` |
| Castle Hall and first-arrival route | `scripts/game_world.gd`, `scenes/game_world.tscn`, `scenes/wall_collisions.tscn` |
| Shared interaction/depth/spawn geometry | `scripts/room_spatial_runtime.gd`, `scripts/room_interaction_runtime.gd` |
| Wake Room tutorial | `scripts/wake_room.gd`, `scenes/wake_room.tscn` |
| Chemistry / Butler / alchemy | `scenes/floor_1/chemistry_room.gd`, `scenes/floor_1/chemistry_room.tscn`, `scripts/alchemy_workbench_ui.gd`, `scenes/ui/alchemy_workbench_ui.tscn` |
| Other rooms | `scripts/greenhouse_room.gd`, `scripts/circuit_room.gd`, `scripts/dining_hall_room.gd`, `scripts/library_room.gd`, `scripts/final_room.gd` |
| Bag / Map / Notes | `scripts/inventory_hud.gd`, `scripts/map_hud.gd`, `scripts/clue_journal.gd` |
| Guardian | `scripts/enemy.gd`, `scenes/enemy.tscn` |
| Menu / cutscene / death / ending | `scripts/main_menu.gd`, `scripts/intro_cutscene.gd`, `scripts/death_ui.gd`, `scripts/game_over_ui.gd` |
| Item models and visual catalog | `autoload/game_state.gd`, `assets/ui/item_models/`, `scripts/inventory_hud.gd`, `scripts/alchemy_workbench_ui.gd` |
| Hub/room polish | `scripts/clue_journal.gd`, `scenes/clue_journal.tscn`, `scripts/final_case_board.gd`, `scripts/library_room.gd`, `scripts/circuit_layout.gd`, `scripts/circuit_room.gd`, `scripts/map_hud.gd` |
| Library knowledge + light games | `scripts/library_room.gd`, `scripts/library_knowledge_shelf_ui.gd`, `scenes/ui/library_knowledge_shelf_ui.tscn`, `scripts/library_light_lab_ui.gd`, `scenes/ui/library_light_lab_ui.tscn` |

## Required validation

Run after source or scene edits:

```bash
/Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
git diff --check
```

Manual acceptance flow:

1. Start a **New Case** from the main menu.
2. Finish the Wake Room chain in desk → bed → bookshelf → door order.
3. Confirm all four unlocked hubs persist in Hall, then follow the one-time floor route to Chemistry.
4. Enter and exit Chemistry; player input must resume in Hall.
5. Open Bag (`Tab`) and Map (`U`) in Hall; closing either must restore input and unpause.
6. Inspect the alchemy UI, clue journal, final board, death/retry, and ending at 1024×768.
7. Trigger the Guardian chase once; check that the new Guardian's feet do not drift and that collision remains fair.
8. Re-enter Hall from at least two different rooms. Confirm the close-up plays each time, the Guardian starts far from the doorway, the ETA changes as either actor moves, and the red minimap dot matches the rendered Guardian.
9. Inspect Papers and Materials in Bag, then load both formulas at the alchemy desk. No blueprint, herb or reagent may fall back to a text glyph.
10. Open Note Hub with enough records to scroll. Check the centered dossier, focusable X, and both functional brass scrollbars. Open Bag and verify only ALL/POTIONS/MATERIALS/PAPERS exist, each in one top metal tab. Confirm herbs/reagents/fragments/food appear in Materials and formulas/maps in Papers.
11. Open Key Hub with all eight keys. Every 132×132 card must be visually enclosed by one of the enlarged gold recesses from the original image, and the 680×138 detail chamber must sit inside the enlarged parchment. The `SHADOW CASTLE` title, outer frame and four corner stones must remain visible. Confirm Bag fills its workbench, Note fills its parchment, and Map art/fog/markers still align edge-for-edge.
12. Before solving Circuit, cross several Hall corridors and double back: only the current flashlight may remain visible; crossed walls, full Map and minimap architecture must be black. Restore Circuit power: confirm generator impact, two light flickers and electric surge. Return to Hall: scan must replace the Guardian close-up, routes must restore progressively, exact online status must appear, and Map must open immediately and clear the temporary objective.
13. Inspect the Chemistry red stain and confirm the three trace models appear without a Bag toast. In Circuit compare each physical switch to markers 1/2/3 on the repair map.
14. In Library first find and file the three marked knowledge shelves — the tall wavelength case, the violet reflection cabinet and the reinforced light archive. Verify each question desk stays locked before its record is filed. Then visit the central research, east writing, and west globe desks, submit a wrong answer in each interface, and clear all five stages of each game. Confirm the central slots stay empty until rewards are earned and produce neutral white light only after all filters are inserted.
15. Open the main menu, the interruption report and both endings and confirm each is lit by the shared atmosphere: corners fall off, one lamp flickers, dust drifts and the backdrop breathes very slowly. Confirm the record panel reads as a physical dossier (corner brackets, rivets, bound left spine) and that the true ending retints that chrome, the panel border and the lamp to arcane violet while the sealed review stays brass.
16. Open the survey Map before Circuit power. The field must be pure black with only live player/Guardian signals. If any building outline is visible, the light-layer exclusion in `map_hud.gd` has been undone — do not re-add an atmosphere layer to that hub.
17. Enter Circuit Room before and after pulling the master switch. Before, the wall lamps are low and the cracked bus arcs roughly once a second; after, the lamps rise and the arcing calms to a rare discharge. In Library confirm each challenge beacon is dim while dormant, brighter once its knowledge record is filed and steady once its filter is earned.
18. Finish either ending, return to the main menu and open **CASE ARCHIVE** at the lower left. Check all five sections in both languages: evidence names must match the accusation table, each row must name the conclusion it supports, the timeline must list only rooms actually visited, and the verdict stamp must differ between the ordinary and true endings. Restart the game and confirm the entry is still present; on a fresh save it must be absent.

## Next priorities

1. **First-time human Wake→Circuit playtest.** The deterministic audit is green, but record unfamiliar-player wrong turns, deaths, time-to-power, flashlight readability and whether 4.32s minimum return reaction feels actionable.
2. **Hall visual scale pass.** The user requested smaller player/Guardian visuals in Hall. Preserve visual feet, collision and catch geometry; update character-scale contracts and native furniture comparisons.
3. **Resolution-screen Archive entry.** The postgame Case Archive now exists (`scripts/case_archive_ui.gd`) and is reachable from the main menu once either ending flag is set. Decide whether the resolution screen should also offer a direct entry; its three actions currently occupy fixed measured regions, so a fourth needs its own layout pass.
4. **Adaptive BGM and release audio.** Add Music/SFX/UI/Voice buses, menu/explore/pursuit/powered/ending music states, settings and dialogue ducking. Keep provenance explicit as with the generated power surge.
5. **Cross-platform release preparation.** Add responsive touch controls, safe-area QA, Web/desktop/Android/iOS presets, platform SDK/signing checklist and real exported-build smoke tests.
6. **Release cleanup and portfolio handoff.** Gate remaining developer output; verify Continue/Retry/Checkpoint behavior; then select final screenshots/GIFs and preserve art provenance.

## Version publication

- `docs/DEVELOPMENT_HISTORY.md` preserves the committed milestones plus thirteen unpublished local stages, `UX-20260814-03` through `UX-20260814-15`.
- The latest stage is the shared archive atmosphere, room light rigs and the postgame Case Archive; evidence is under `docs/evidence/2026-08-14-ui-redesign/release-visual-overhaul/`, `docs/evidence/2026-08-14-hub-room-polish/`, `docs/evidence/2026-08-14-library-light-challenges/`, `docs/evidence/2026-08-15-room-spatial/` and `docs/evidence/2026-08-14-power-blackout/`.
- Do not push the current dirty worktree directly. The GitHub/Codex maintainer should review and split the thirteen local stages into auditable commits, retaining stage IDs and evidence paths.

## Git and ownership warning

The currently configured remote and Git author identity are not confirmed as the player's own. Do **not** push, rewrite remotes, or configure credentials until the repository owner supplies their own GitHub username/repository URL and authenticates locally. See the human handoff message for the recommended migration commands.
