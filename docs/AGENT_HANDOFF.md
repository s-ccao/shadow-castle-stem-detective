# Shadow Castle: STEM Detective — Continuation Handoff

**Date:** 2026-08-14  
**Project:** Godot 4.7 / GDScript / 2D pixel-art mystery  
**Viewport:** 1024×768  
**Current phase:** feature-complete prototype; polish, visual QA, regression testing, and portfolio-ready GitHub documentation remain.

## Start-of-task brief

You are continuing a late-stage student portfolio game. Preserve the current in-progress changes. Make focused, playable improvements; validate every change and report concrete evidence. Do not replace systems wholesale unless the user asks for a redesign.

### Current polish notes (2026-09-05)

- Chemistry's new investigation uses `ChemistryCaseState` (persistent `chemistry_case_*` story flags) and `ChemistryCaseUI`, wired by the actual room interactions. Observation, hypothesis, control/comparison, filing and evidence-linked questioning are separate steps. Keep the original evidence/reward IDs; an old `fake_red_stain` save is migrated without losing progress.
- The case never preselects the useful witness/report pair or disables interpretation submission solely because the selected hypothesis is wrong. Wrong interpretations receive feedback and remain revisable; records distinguish facts, working hypotheses and confirmed conclusions. The finale requires the actual interview for new cases, retaining its evidence-only fallback for legacy saves.
- `ArchiveUi.prepare_hub_open()` transfers pause ownership before another Hub opens. `begin_motion()` / `settle_motion()` restore position, scale, rotation, pivot and modulation on cancellation. Do not animate map art independently of its CPU fog mask.
- Journal records may provide `title_en/title_zh`, `content_en/content_zh`, `observed_detail/observed_detail_zh`, and `room_id`; existing `*_key` localization remains authoritative. Map links only unlocked records in visited rooms after power restoration. Rendering must not invent facts or rewrite saved record content.
- `FlameJarView` shows exactly one wick and flame per candle. `burn` is an oxygen-consumption multiplier, NOT a wick count: use `wick_width()` and `flame_dimensions()` for visible thickness/intensity. Keep code-native phase labels and `FlameAirMinigame`'s original burn/vent timing and answers.
- `MinigameShell.clear_feedback()` clears obsolete attempt feedback. Long failures remain readable until the player acts; restart/close must cancel pending level-advance work.
- Character turns preserve animation frame progress. Movement cadence comes from actual post-collision displacement, not intended velocity. Keep the body scale, foot anchors and stationary interview-NPC roles intact.
- The Hall's scripted Guardian presentation must not call `face_toward()` every render frame: that resets locomotion. `present_scripted_step()` derives the pose from authored travel without altering safe placement.
- Run tests with an isolated `HOME` on macOS to keep `user://` away from the player's save. Check script/runtime errors as well as exit status and PASS text; eager CLI preloads of scripts using autoloads previously hid a failed science check.
- The user authorized syncing completed fixes to `/Users/yaleshen/shadow-castle-stem-detective`. Preserve that checkout's uncommitted collision/art changes and `data/hall_tutorial_route.json`; syncing local files is not blanket authorization to publish.

## Player journey implemented now

1. **Main Menu → opening cutscene → Wake Room.** The cutscene establishes Dr. Lin, Ashford Castle, and the investigation.
2. **Wake Room tutorial.** The desk unlocks the portable investigation kit and Dr. Lin's partial Hall map. The bed awards the Wake Room key. The bookshelf gives the oxygen rule and Chemistry key. The door then accepts the answer and opens.
3. **Castle Hall arrival.** The compact field-kit toolbar keeps unlocked tools available. Footprints first lead to the visible Chemistry knowledge core, including edits to its Sprite child. Movement stops in interaction range; E/click opens the lesson, and **FILE KNOWLEDGE** is required before movement and the onward Chemistry route return. No onward trail or pursuit readout competes with the required stop.
4. **Investigation rooms.** Chemistry, Greenhouse, Circuit, Dining, Library, and Final Room each use room-specific clues, locks, inventory/knowledge state, and return paths.
5. **Finale.** The final case board supports the ordinary Butler conclusion and the optional sealed-record route revealing the Mechanic's forged command chain.

## Recent completed work

### Hall route, footprints and props (2026-10-21)

- **Route planning:** `scripts/hall_route_planner.gd` (`HallRoutePlanner`) plans the tutorial trail on the Guardian's own 16px collision lattice (`build_navigation_lattice()`), so it needs no collision queries of its own.
  - Costs: node cost grows near stone (`CENTRE_WEIGHT`), which keeps the walk on corridor centrelines.
  - Straightening: the walk becomes axis-aligned legs that never come nearer the stone than the search did.
  - `_get_hall_route_path()` joins it from the player's real position, squares the first leg, folds 16px jogs into slight drifts (`HALL_ROUTE_MAX_JOG`) and still runs `_collision_safe_hall_route()`.
  - Endpoints: interaction routes end on an edge that triggers the interaction (reach and knowledge sight). Bare-point routes now reach the point itself.
- **Authored route:** `data/hall_tutorial_route.json` now only chooses corridors (`set_corridor_hint()`); it is no longer replayed point by point.
  - The shipped recording starts at the old placeholder (512,384), and a through-wall first segment like that is ignored.
  - Corridors off the recording cost `OFF_HINT_PENALTY` (3x).
  - The file is unchanged; tests verify it stays byte-identical.
  - The 60×40 `CASTLE_LAYOUT` and 32px `astar_grid` remain only for click-to-move and the Guardian's legacy queries. The trail no longer uses them.
- **Footprints:** prints stay above the fog (z 108), but only up to the first print that is neither in line of sight nor about as near in a straight line as along the trail (`HALL_ROUTE_SIGHT_RATIO`).
  - Prints under the character are hidden, and revealed prints fade in.
  - `hall_footprint_marker.gd` adds a shared additive violet glow under the authored shoe PNGs.
  - The compass names the heading of the next leg, not the goal's bearing.
- **Rehearsal Guardian:** placed by distance walked along the trail (`_hall_tutorial_guardian_mark()`). Its step aside is capped by the open floor on the roomier side, keeps a 24px wall gap, and eases at turns.
- **Fog:** `scripts/hall_fog_smooth.gdshader` (linear filtering plus smoothstep-eased bilinear weights) replaces the nearest-filtered 16px blocks. The fog logic, memory and power gating are unchanged.
- **Survival card:** `onboarding_hud.gd::_stack_control_rows()` stacks the move/inspect rows by measured line count. The English move hint no longer overprints the inspect row.
- **Props (actual main checkout only):** all nine Hall props now use `assets/props/hall_pixel/*_pixel.png`. The session worktree's older `wall_collisions.tscn` predates the user's prop placement and keeps the previous textures.
  - Rendering: 1.25 world px per texel, uniform 1.25 scale, nearest filtering, lossless import, plus a `ContactShadow` child (shared atlas `hall_contact_shadow.png`).
  - `tools/pixelize_hall_props.gd` regenerates them deterministically from the unchanged AI sources; see `PROVENANCE.md` and `manifest.json`.
  - Visual feet moved ≤0.62px. The Chemistry/Circuit stretch was removed while keeping the visible area, and M1's opaque backdrop box was removed.
  - The exhibit's first `Sprite2D` child must stay `Sprite`, because `get_visual_feet()` reads it.
- **Paused:** the 2D wall/floor redraw is paused. The user chose a Blender 3D→2D **HD** one-screen Hall prototype as the next art step (characters deferred).
- **QA:**
  - `tests/hall_visual_capture.gd` (native only; HOME under `.godot/hall-visual-`; `-- --out=<label> [--zh]`) replays the real Wake exit and captures card, route, props, fog-free areas and overview.
  - Curated comparisons are in `docs/evidence/2026-10-21-hall-visual/`.

### In-game Esc settings (2026-10-18)

- `autoload/pause_menu.gd` is the last autoload (`PauseMenu`, CanvasLayer 94, process-always). The `pause_menu` action is Esc; a controller's Start is added at runtime. It opens only during free play: the tree must be unpaused, a `player` node must exist, and the current scene's optional `can_open_pause_menu()` must agree. A previous-frame snapshot prevents the Esc that closes a Bag, Map, Note, door puzzle, minigame, dossier or room panel from also opening settings.
- Rooms veto settings for Esc-owned panels or scripted moments. `wake_room.gd` checks its book/scroll/inspect/message/puzzle/knowledge panels because it polls `ui_cancel`; `game_world.gd` checks game over, Guardian reveal/near miss, power-route scan, the Chemistry near-miss CG, knowledge dossier, Chemistry door question and the post-dossier input frame. Add a veto rather than another global Esc listener when a new scene polls Esc.
- While open, the menu owns the pause, re-pauses if a process-always timer unpauses beneath it, and swallows remaining key shortcuts so Hubs/room actions cannot act underneath. Esc/B closes; Esc backs out of a confirmation first. Resume keeps the tree paused for two frames, so the closing key cannot reach polled room input.
- Settings: Resume, Main Menu, Quit (hidden on Web/iOS), global mute, Music/Effects faders, field prompts and the shared controls list. Main Menu and Quit require confirmation with Cancel focused. Main Menu mirrors Hall's recovery path (`recover_from_interruption()` then the archive transition) after unpausing for the transition snapshot. Quit recovers and writes `save_to_disk()` synchronously before `quit_handler`.
- `GameAudio.set_muted()/toggle_muted()/is_muted()` mute Master without moving faders and persist `audio/muted` in the shared preferences file; `get_bus_volume_linear(&"Master")` still reports the fader while globally muted. Title-screen settings now has a Mute toggle beside Field Prompts/Close so the setting is always reversible.
- Language switching intentionally remains on the title screen: several room scripts do not yet rebuild every static label on `locale_changed`.
- QA: `tests/pause_menu_test.gd` requires HOME beginning with `res://.godot/pause-menu-`. Add `-- --capture [--zh]` natively for `docs/evidence/2026-10-18-pause-menu/`.

### Chemistry material observation (2026-09-07)

- **Latest naturalness pass:** `sample_material_motion.gd` supplies cached 240Hz glass trajectories, convex-hull floor contact, dissipative collisions and sleep; the shader moves seven complementary regions of the original neutral glass PNG. Ice uses the raster melt-front mask, a grounded remaining silhouette and a density-aware model mass balance, not uniform scaling/alpha disappearance. The generated `physical_geometry.gd` resource is preloaded for export; JSON is provenance, not a runtime dependency.
- Wax wobble, cloth texture replacement and regular crystal/curd rows are removed. Bubbles stay within the changing liquid depth, and mist/smoke particles cannot start older than their emission event. These are bounded illustrative models: no full heat/fluid solver, SI-scale calibration or inter-shard collision is claimed.
- Stage36 native evidence is in `docs/evidence/2026-09-07-material-naturalness/` and `tests/captures/chemistry_material_motion/`; stage35 remains historical. Use `chemistry_presentation_test.gd -- --capture --naturalness --zh` or `-- --preview --naturalness --zh` with project-local isolated HOME. Native capture explicitly draws before readback so an occluded macOS window cannot hang at a static result.
- Each sample has a bilingual physical-condition note. Heat, external pulling, moisture/oxygen, evaporation and microbial activity are stated rather than implied to appear from nothing; the bronze device is explicitly fictional. `SampleDishView.is_time_lapse()` owns the compressed-time classification instead of a duplicate controller list. These are simplified demonstrations, not quantitative laboratory predictions.
- Material sound timing uses `SampleDishView.sound_onset_seconds()`. The controller plays a pending cue only at the corresponding observation time, cancels it on selection/replay/clear, and leaves quiet melting/dissolution/souring/crystallization silent. Glass must not sound before its visible collision. Keep cancellation and actual-room audio-timing assertions in `chemistry_presentation_test.gd`.
- The actual Chemistry table now opens **Material Observation Lab / 变化观察实验台**, using the existing launcher and completion callback. `ChangeSortingMinigame` alone expands to 940x704: one large experiment, selectable samples, replay, classification and explicit sealing. Keep all eight `LEVELS`, 16 sample booleans, reward IDs and the main checkout's investigation flow.
- `SampleDishView` uses original raster specimens/vessel art and a material shader under `assets/chemistry/sample_tray/`. Observation lasts 2.6 seconds; sealing adds a 0.7-second result hold. Burning paper chars with flame/smoke/embers; ice and wax melt without invented steam/fire; fizz, boiling, fracture, dissolution, corrosion, coagulation and crystallization use distinct effects. Rust, tarnish, souring milk and crystallization explicitly say time-lapse.
- Material appearance is not an answer badge. Preserve `new_substances()` and the before/after substance sets; chemical/physical feedback belongs to a submitted classification, never merely colour, bubbles or irreversibility.
- `GameAudio` owns six new non-looping `sample_*` cues. Repeated replay replaces its previous voice; selection/close stops only the still-owned sample voice, not reused UI audio or music layers. Provenance and the `--chemistry-only` generator command are in `assets/audio/README.md`.
- Keep `_cards[id]["chemical"]` and `["physical"]` as real Buttons for the investigation flow contract. `_clear_content()` must cancel observation and null `_hero`/`_submit`; hidden or finished `_process()` must not dereference freed controls. Restore the Seal label on live verification completion. Main's newer shared-shell lifecycle is preserved; session has only a compatible `clear_feedback()` helper.
- Focused QA: `chemistry_presentation_test.gd` launches the real room and supports native `-- --capture [--zh]` or playable `-- --preview --zh`. Use HOME below the project itself, e.g. `.godot/chemistry-vfx-check/home`; verify `OS.get_user_data_dir()` stays beneath it. The renderer suite uses the same path marker. Never run reset-based tests against the player's normal HOME.
- Native room-launched EN/ZH images are in `docs/evidence/2026-09-07-chemistry-effects/after/`; renderer contact sheets, deterministic replay comparisons and frame-interval measurements are under `tests/captures/chemistry_sample_tray/`. The `before/` gallery is an old-layout baseline with already-staged raster art, not a historical baseline of the old renderer. Web export/deployment and listening QA remain separate.

### Actual-project guidance and toolbar (2026-09-07)

- **Hub layout:** Bag/Key/Note/Map retain semantic slots at `(16 + slot * 80, 14)`, with 72x106 hit targets. Persistent 14px names and separate shortcut hints share an aligned row; hidden intermediate slots show a quiet unavailable label rather than moving later tools. The 332x112 preview stays at viewport `(12,132)` and fades without positional motion. Keep the existing internal Hub panels and suppression/pause behavior.
- **Chemistry entry contract:** first arrival now uses the real key/knowledge question gate. `ChemistryDoorQuestion` presents all four choices at once; wrong answers stay locked, correct answers set `door_chemistry_question_answered`, and explicit entry starts the CG. Normal previously completed visits do not replay it. Standalone first-arrival preview resets the two Chemistry door flags.
- `chemistry_near_miss_cg.gd` animates visual actor/background/door proxies on a dedicated CanvasLayer; the world bodies are held without changing collision scale. Timed completion and skip both enter Chemistry without damage. Do not restore the old false "IT HAS YOU" title.
- Knowledge artwork is the five original text-free PNG concept plates under `assets/ui/knowledge_plates/`, with editable SVG sources and manifests. `KnowledgeArtwork` must not return to scene-prop crops.
- Route presentation uses `hall_footprint_marker.gd`: small alternating raster shoe marks, paired turn/stop prints, a 480px forward reveal and restrained alpha shimmer. Polygon arrow blobs, corner beams and scale-bounce are no longer the production renderer.
- Hub entries now rest as physical tool silhouettes on a narrow leather rail. Cell cages/name bars are removed; explicit focus/hover states and truthful preview slips remain. Normalization/provenance is in `assets/ui/tool_belt/`.
- **Current experience contract:** Hall knowledge uses a 72px approach margin around the visible footprint, checked against wall visibility; doors keep their 14px contact band and take prompt priority. The destination beacon lies within that approach zone, not against the prop.
- **Knowledge before reward:** `hall_knowledge_dossier.gd` presents all five exhibits as an illustration, observation, principle and examples. Only its filing action sets the knowledge flag. Already-filed exhibits remain inspectable. New notebook records use `content_key` so the full principle follows EN/ZH switching.
- **Bounded tutorial protection:** the safe corridor is 80px from the route polyline. After 1.1s outside, the Guardian leaves scripted presentation, moves through the real hunt and can cause capture. No automatic return teleport remains in the exposure flow. Re-entering the route restores guidance protection; forced reading remains safe.
- **Refined Hub affordance:** nine-sliced metal and parchment inlays replace the stretched generic tray. Hover/focus previews show real tool contents and purpose, without exposing unknown map geometry or inventing unread records. Source artwork is unchanged; derived surfaces have provenance under `assets/ui/hub_toolbar/`.
- The user's Godot editors run `/Users/yaleshen/shadow-castle-stem-detective`, not the session worktree. Verify the running process/project path before claiming delivery. The two checkouts have different authored geometry and other in-progress changes; never overwrite one wholesale with the other.
- Knowledge navigation uses the visible sprite's feet, not an unchanged parent origin. Route presentation omits already-walked prefixes, ends at a usable interaction edge, and validates marker paths against actual player collision. Off-centre grid connectors cannot add a wall-crossing shortcut.
- `0` controls developer mode only. The named `record_hall_route` action, bound to **Shift+0**, explicitly starts/cancels Hall recording. Normal developer mode must not bypass the knowledge stop. Recording begins after spawn resolution; finishing/cancelling away from the core restores approach guidance instead of a remote movement lock.
- The field-kit entries share a 322x92 brass/violet tray with 72x64 raster-icon controls, labels and keycaps. `ArchiveUi` owns layout/visibility/focus coordination; `HubToolbarEntry` owns visual states. Internal Hub panels, unlocks, shortcut guards and pause ownership are retained.
- Combined native evidence is under `docs/evidence/2026-09-07-main-guidance/`; `runtime*.json` identifies the actual project, source and geometry hashes. Toolbar state captures are under `docs/evidence/2026-09-07-hub-toolbar/`.
- Run reset-based tests with isolated `HOME`. The toolbar suite additionally requires matching `HUB_TOOLBAR_TEST_HOME` and a HOME path containing `/.godot/hub-toolbar-`. Do not count a rejected safety precondition as a passing test.

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

- The first Hall route is planned by `HallRoutePlanner` (see the 2026-10-21 notes above): axis-aligned legs on corridor centrelines, drawn as alternating raster shoe prints every 64px, with turning prints at each corner.
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
- `tests/standard_flow_pressure_audit.gd` measures the real planned Hall route (`_get_hall_route_path`) at current speeds. On the current Hall layout (2026-10-21) the pre-Circuit legs are 2528px/14.04s, 384px/2.13s and 287px/1.59s (17.77s total, separated by two safe rooms). Worst return reaction is 4.32s at Tier 2 with the 800px separation. The 38.93s figures in `docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md` describe the older August layout.
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
| Castle Hall and first-arrival route | `scripts/game_world.gd`, `scenes/game_world.tscn`, `scenes/wall_collisions.tscn`, `scripts/hall_route_planner.gd`, `scripts/hall_footprint_marker.gd`, `scripts/hall_fog_smooth.gdshader` |
| Hall prop pixel art | `assets/props/hall_pixel/` (`PROVENANCE.md`, `manifest.json`), `tools/pixelize_hall_props.gd` |
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
3. Follow the footprints to the knowledge core: a clear point 36-64px from the visible prop must stop queued movement and allow E/click without touching it. Read the illustrated principle/examples, close without filing and verify the stop remains; then file and continue. Reopen collected knowledge and verify the actual lesson remains readable in EN/ZH. Plain `0` must not bypass the stop.
4. Leave the footprint corridor: after the warning the Guardian must actually pursue and contact must reach recovery, without teleporting the player back. Return to the route before capture to regain guidance protection. Inspect Hub hover/focus previews, then follow the onward route through Chemistry and back; input and normal pursuit must resume.
5. Open Bag (`Tab`) and Map (`U`) in Hall; closing either must restore input and unpause. With either open, the first Esc must only close it; the next Esc opens settings, freezes the Guardian, and Esc resumes. Check mute, faders, prompts, and Cancel on both Main Menu and Quit confirmations.
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

1. **Blender Hall prototype (HD): second art pass built, user review pending.** See stages UX-20261021-39 and -40 and `docs/evidence/2026-10-21-blender-hall-prototype/` (`21-region-iteration.png` compares the two passes).
   - Pipeline:
     - `tools/blender/export_hall_region.gd` (headless Godot) exports the real collision as `wall_mask.png`, plus `outside_mask.png` and `region.json`.
     - `tools/blender/hall_prototype.py` (Blender 5.2 bpy, Cycles Metal) builds walls whose cap plus south face exactly covers the collision. It uses a 40° orthographic camera with a 1/cos Y pre-stretch, so the floor maps 1:1 onto game coordinates.
       - Geometry is per game px from a smoothed copy of the collision, which stays within 2 px of it.
       - Props (lanterns, banners, gallery machinery) must stay inside the wall outline: hung on a south face, or sunk in a gallery below its rim.
       - Floor decals carry the `floor_decal` property, so the silhouette pass skips them like the floor.
       - Keep heavy shader logic off the floor material (give it its own object), and keep merged quads tile-sized. Both slowed renders several-fold.
     - `tools/blender/capture_prototype.gd` (native Godot) overlays the render visually and captures paired shots.
     - `tools/blender/play_prototype.gd` (native Godot, `-- --hall`) is a playable preview. The normal game does not include the render.
   - Materials are CC0 Poly Haven photo textures with provenance in `prototypes/blender_hall/textures/sources.json`; there is a procedural fallback.
   - The outputs in `prototypes/blender_hall/` are local and regenerable.
   - The user chose to tune this one region until it satisfies, then extend it to the whole Hall. Next candidates for the region:
     - wall-face detail (alcoves with candles, portraits, shelves);
     - in-game lantern flicker and crystal pulse.
   - Characters stay as they are until the Hall is settled.
2. **First-time human Wake→Circuit playtest.** The deterministic audit is green, but record unfamiliar-player wrong turns, deaths, time-to-power, flashlight readability and whether 4.32s minimum return reaction feels actionable.
3. **Hall visual scale pass.** The user requested smaller player/Guardian visuals in Hall. Preserve visual feet, collision and catch geometry; update character-scale contracts and native furniture comparisons.
4. **Room spatial audit drift.** `tests/room_spatial_audit.gd` still expects a 14px contact band for the five Hall knowledge exhibits and `arrival_chemistry_core`, but those deliberately use the 72px wall-aware approach zone. The six failures predate the 2026-10-21 stage; update the expectation rather than the margin.
5. **Resolution-screen Archive entry.** The postgame Case Archive now exists (`scripts/case_archive_ui.gd`) and is reachable from the main menu once either ending flag is set. Decide whether the resolution screen should also offer a direct entry; its three actions currently occupy fixed measured regions, so a fourth needs its own layout pass.
6. **Adaptive BGM and release audio.** Add Music/SFX/UI/Voice buses, menu/explore/pursuit/powered/ending music states, settings and dialogue ducking. Keep provenance explicit as with the generated power surge.
7. **Cross-platform release preparation.** Add responsive touch controls, safe-area QA, Web/desktop/Android/iOS presets, platform SDK/signing checklist and real exported-build smoke tests.
8. **Release cleanup and portfolio handoff.** Gate remaining developer output; verify Continue/Retry/Checkpoint behavior; then select final screenshots/GIFs and preserve art provenance.

## Version publication

- `docs/DEVELOPMENT_HISTORY.md` preserves the committed milestones plus thirteen unpublished local stages, `UX-20260814-03` through `UX-20260814-15`.
- The latest stage is the shared archive atmosphere, room light rigs and the postgame Case Archive; evidence is under `docs/evidence/2026-08-14-ui-redesign/release-visual-overhaul/`, `docs/evidence/2026-08-14-hub-room-polish/`, `docs/evidence/2026-08-14-library-light-challenges/`, `docs/evidence/2026-08-15-room-spatial/` and `docs/evidence/2026-08-14-power-blackout/`.
- Do not push the current dirty worktree directly. The GitHub/Codex maintainer should review and split the thirteen local stages into auditable commits, retaining stage IDs and evidence paths.

## Git and ownership warning

The currently configured remote and Git author identity are not confirmed as the player's own. Do **not** push, rewrite remotes, or configure credentials until the repository owner supplies their own GitHub username/repository URL and authenticates locally. See the human handoff message for the recommended migration commands.
