# Agent stage report

> **Purpose:** Shared mailbox from the implementation agent to the GitHub/Codex maintainer. This report contains no credentials and is not authorization to publish automatically.

## Stage

- **Stage ID:** `UX-20260815-26`
- **Stage name:** Switches become hardware, and the Guardian stops standing behind the room
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** Circuit Room's three plates were flat vector rectangles — a beveled block, four squares and a coloured bar — sitting in a room of painted stone, tarnished brass and real lighting. They now draw as the hardware they are meant to be: a cast-iron backplate on four brass bolts, a brass bezel over a slate recess, two porcelain insulator posts, and a hinged blade that visibly swings down into its contact jaw when the charge lands. Open and closed are no longer two tints of the same picture; the blade travels. Separately, the Guardian's start corner was pinned against the map border, which put it in the dead strip behind the painted hall; it now stands inside the room's bottom-right.

## What changed

- New `scripts/circuit_switch_view.gd`: the whole plate is drawn, so the blade can move. Two sprites could not have shown the throw.
- The open angle is derived from the plate's own headroom rather than hard-coded, so a blade can never swing out through the bezel on a plate shorter than the one it was tuned against (it resolves to −21.6° on the 64×48 plates and −29.2° on the 72×56 master).
- The stand-in `ActiveGlow` octagon, `MountBorder` outline and floating sequence Label are gone. The plate draws its own bezel, live recess light, contact arc and a stamped brass number tag.
- `ENEMY_START_POSITION` moved from `(1832, 1208)` to `(1744, 1072)`, chosen by scanning the hall for a cell that is free on every collision layer, grid-walkable, and inset ≥160px from the border.
- The now-dead `texture` entry was removed from `CircuitLayout.SWITCH_SPECS`.

## Verification

- The reason the old corner passed review is worth recording: the hall's real walls are collision polygons in `wall_collisions.tscn`, not solid grid cells, so `is_player_position_walkable()` cheerfully reports the outermost border as walkable and `_nearest_guardian_walkable_position()` had nothing to push against. `guardian_hunt_flow_test` now asserts the inset directly.
- `hub_room_polish_contract_test` no longer asserts that a node named `MountBorder` exists — a test of implementation. It now asserts the intent: the plate is throwable, its blade visibly travels between states, and it lifts without leaving its own bezel.
- 18/18 logic suites PASS, 13/13 visual harnesses PASS, parse 0 errors, `git diff --check` clean, QA save absent.
- Evidence: `docs/evidence/2026-08-15-switch-hardware/01-knife-switch-open-and-seated.png`, shown at true in-game size and at 3×.

## Risks / follow-up

- `assets/props/CircuitRoom/switch_auxiliary.svg`, `switch_regulator.svg` and `switch_master.svg` are now unreferenced. They were left in place rather than deleted; the maintainer should decide whether to drop them.
- The plate is tuned for the three authored sizes. It scales, but a plate much shorter than 48px would leave the blade very little travel and would be better served by a vertical hinge.
- Still open: one first-time human playtest Wake→Circuit; export presets and touch controls.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-25`
- **Stage name:** The game has a voice — bus architecture, adaptive score, and a countdown that stops lying
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** Before this stage the entire game contained exactly one sound. It now has a mixer, an original score that follows the Guardian, and feedback on every action that mattered. The music is three eight-second layers of the same D-minor piece — archive at rest, something is aware of you, the Guardian has you — started on the same frame and never stopped, so the score escalates and relaxes by gain alone, with no restart and no seam. Music and effects have separate faders in Settings, styled in the same brass-on-walnut as the rest of the archive. Separately, the pursuit countdown no longer ghosts through an open hub: it withdraws the moment the world pauses instead of freezing on a time that has stopped being true.

## What changed

- `tools/generate_audio_set.mjs`: 13 deterministic, original assets — three bar-aligned music layers and ten one-shots — synthesized from oscillators and seeded noise. No samples, no third-party audio. Music partials are snapped to integer multiples of 1/8 Hz so every oscillator completes whole cycles per loop and the loop point is sample-exact.
- `default_bus_layout.tres`: Master / Music / SFX / UI, each child routed through Master.
- `autoload/game_audio.gd` (`GameAudio`): a deep module whose whole interface is `play()`, `set_music_intensity()`, `duck_music()` and the two volume accessors. Voice pool with stealing, per-sound pitch spread, sidechain-style ducking, and volumes persisted into the existing preferences file rather than a second settings file.
- Wiring at chokepoints rather than per screen: `ArchiveUi.apply_button` sounds every archive button in the game (confirm vs back by role), `GameAudio` subscribes to `GameState.item_acquired`, and the Hall drives intensity from Guardian state each frame.
- `ArchiveUi.apply_slider()` + a generated brass grabber, so the new faders speak the archive's visual language instead of arriving as engine defaults.
- `game_world._notification()`: the contact estimate withdraws on `NOTIFICATION_PAUSED` and returns on unpause.

## Verification

- New `audio_contract_test` (18th suite). Its central assertion is the one that is easy to break later: all three layers must be *playing* and share a playback position, and must still be playing after an intensity change. A future "optimisation" that stops a silent layer would desynchronise the score, and this fails loudly if anyone tries. It also covers bus routing, catalogue integrity, crossfade, ducking recovery, volume round-trip, and that both Settings faders actually move their bus.
- The pause fix was written test-first: `guardian_hunt_flow_test` asserted the withdrawal and failed before the change.
- 18/18 logic suites PASS, 13/13 visual harnesses PASS, parse 0 errors, `git diff --check` clean, QA save absent.
- Evidence: `docs/evidence/2026-08-15-audio/01-settings-volume-faders.png`.

## Risks / follow-up

- Two real Godot traps were hit and are worth knowing before editing this code. `AudioStreamWAV.loop_end` is a frame index, not a sentinel: `loop_begin = 0, loop_end = 0` is a zero-length loop, and every music layer stopped on the frame it started. And `ConfigFile.get_value(section, key, null)` still raises when the key is absent, so presence must be checked first.
- Mix levels are a first pass set by ear against the generated peaks. They are the sort of thing only a human playtest can settle.
- Still open: one first-time human playtest Wake→Circuit; export presets and touch controls.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-24`
- **Stage name:** Alchemy workbench legibility — copy given surfaces, names given room
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** The alchemy workbench's painted plate was never the problem; the text layer was fighting it. Operational copy that had been floating over reaction smoke, a shelf edge and a test-tube rack now sits on its own brass-edged specimen plaques, the way a museum pins a label under an exhibit. The rack rows read correctly for the first time: reagent and formula names were being drawn underneath their own icons, which had silently renamed the second formula on screen from 洞察药剂配方 to the meaningless 寒药剂配方. The parchment readout dropped a header that only named the tray the player was already looking at, so its three live lines finally have room.

## What changed

- `ArchiveUi`-consistent caption plaques (`_install_caption_plaques`, `_new_caption_plaque`) behind the expected-product heading and the product name/description, with the copy lifted above them.
- `_reserve_icon_gutter()` replaces a hard-coded seven-space text prefix. Padding spaces could neither scale with the icon nor survive word wrap, which is exactly how names ended up hidden; the clearance is now reserved in the row's stylebox, so overlap is not expressible.
- Rack rows switched to `AUTOWRAP_OFF` + `clip_text`, so a long name truncates at the row's edge instead of wrapping back under the icon.
- The redundant `反应阵列` header is retired and the parchment's three readout lines redistributed.

## Verification

- New `_check_alchemy_row_legibility()` block in `ui_design_contract_test` asserts, per row, that the label starts past the icon's right edge, that clearance is reserved rather than typed as spaces, and that the full name fits. Falsified before landing: forcing the gutter back to a constant produces 5 failures.
- 17/17 logic suites PASS, 13/13 visual harnesses PASS, parse 0 errors, `git diff --check` clean, QA save absent.
- `05-alchemy-ready.png` now shows all five rack rows with complete names.

## Risks / follow-up

- The product caption plaque is sized for a name plus a description line; recipes whose description is empty leave a little slack under the name. Cosmetic only.
- Still open from earlier stages: the Hall countdown panel ghosts faintly through the Map hub backdrop when the map is opened mid-pursuit (the tree is paused, so the Hall's `_process` cannot hide it); one first-time human playtest Wake→Circuit; adaptive BGM/audio buses; export presets and touch controls.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-23`
- **Stage name:** Junction Bench III — fault isolation, the third verb
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** The master plate opens a bench where nothing can be built and nothing can be tuned. The bus is already dead. The player carries a probe, reads test points, and names the faulty segment from the evidence — the same skill the case runs on, applied to hardware. An open fault puts full supply on every point upstream and zero on every point downstream, so two well-chosen probes box the fault in; the board dims the segments the readings have already ruled out, keeping the deduction visible instead of asking the player to hold it. From stage 4 the fault is a degraded segment that still conducts: nothing reads zero, and the culprit has to be found by comparing drops between neighbours. A wrong call is answered with the specific reading that contradicts it, never with "no".

## What changed

- `DIAGNOSTIC_STAGES` × 6: open faults teaching full/zero and then halving, then high-resistance faults teaching drop comparison, ending on the Ashford bus where one segment "was helped along".
- `_voltage_at()` derives every reading from the series chain — no current at all under an open, and a real I = V/Rₑ drop profile under a degraded segment.
- `_segment_excluded()` turns the readings into visible eliminations, and `_wrong_accusation_reason()` cites the contradicting measurement.
- Rendering: brass test-point studs, per-point voltage tags, a probe with lead and body that plants on the measured point, dimmed excluded segments, and a parted conductor drawn on the segment once it is correctly named.

## Verification

- 17/17 logic suites PASS, including the new `circuit_bench_diagnostic_test`. It asserts the verb (no rheostat, probes exist, a verdict is asked for) and the physics: full supply at the last point before a break, zero immediately after, no zero anywhere on a high-resistance fault, the largest drop always on the guilty segment, a wrong call explained rather than merely rejected, and — for every open stage — that binary search within ceil(log2(segments)) probes really does isolate the fault.
- 13/13 visual harnesses PASS for 137 captures; `18-diagnostic-narrowed.png` shows two probes and three segments already eliminated.
- Parse 0 errors, `git diff --check` clean, QA save absent.

## Risks / follow-up

- All three Circuit plates are now gated behind their benches. `power_restoration_milestone_test` and `power_restoration_visual_capture` pre-clear all three bench flags in setup, which is correct but is a precondition anyone editing those suites must know about.
- The alchemy workbench redesign remains outstanding, and it still has the "reads as a form, not as apparatus" problem these benches were built to avoid.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-22`
- **Stage name:** Bench II rebuilt as continuous regulation — a different verb, not the same puzzle with numbers
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** Bench I and Bench II were the same game: choose from a rack, fit it into a slot, press test. Bench II is now a genuinely different interaction. There is no rack. The series resistance is a **rheostat** — a wire-wound coil with a wiper the player drags — and the circuit is always live, so the meter answers continuously as the hand moves. Winding to the left of the wiper glows because it is the part actually in circuit. The stage is satisfied by **holding** the needle inside the green band, not by submitting an answer: a value crossed in passing does nothing, and a hold gauge fills only while the value is kept. From stage 4 the filament heats and the load drifts on its own, so the task becomes tracking a moving target by hand rather than setting a number once.

## What changed

- `REGULATOR_STAGES` re-authored around `r_max`, `hold`, `drift` and `drift_span` instead of a parts rack.
- New `RheostatView` with real drag input, a ceramic former, visible windings and a knurled knob; the in-circuit portion of the coil is tinted live.
- `_process()` drives the whole bench: drift advances the load, holding accumulates, overshoot accumulates against a 0.55 s grace before the filament fails.
- `_solve_regulator()` now aims at the **centre** of the band rather than its first edge, so the test hook is not sitting on a boundary a drifting load would immediately push it off.
- The one-shot ENERGISE control is hidden on this bench, because a bench that is always live has nothing to energise.
- **Bug fix.** `_refresh_rail()` used `queue_free()` alone, so a rebuilt node was auto-renamed while the old one lingered until end of frame, and every lookup by name silently missed. Children are now detached before being freed.
- Generated labels take the locale font, fixing missing CJK glyphs in the bench copy.

## Verification

- 16/16 logic suites PASS. `circuit_bench_regulator_test` was rewritten for the new model and now asserts the verb as well as the physics: a rheostat exists, **no parts rack exists**, the reading is the divider to within a millivolt, moving the wiper right always lowers the lamp voltage, at least two stages drift the load, crossing the band does not clear a stage, and tracking-and-holding does.
- 13/13 visual harnesses PASS for 131 captures; `13-regulator-holding-in-band.png` and `15-regulator-drifting-load.png` document the new interaction.
- Parse 0 errors, `git diff --check` clean, QA save absent.

## Risks / follow-up

- Bench III must be a third distinct verb. Construction (I) and continuous tracking (II) are taken; the strongest remaining candidate is **diagnosis**: a dead bus, a movable probe, and a fault the player has to locate by measuring rather than by rebuilding.
- The alchemy workbench redesign remains outstanding.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-21`
- **Stage name:** Junction Bench II — Ohm's law, voltage division and a filament that really fails
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** The regulator plate now opens a six-stage bench built on V = V_src · R_lamp / (R_lamp + R_series). The supply voltage and the lamp's resistance are printed on the bench; the player fits resistors from a rack and watches an analogue panel meter — real dial, tick marks, a printed green safe band and a red danger zone — swing toward the resulting lamp voltage. Land in the band and the lamp runs steady. Fall short and the filament stays dull. Overshoot and the filament visibly burns out: white flash, expanding rings, bench shake, and a bulb left with a parted filament behind sooted glass. That last outcome is the point — "too little resistance is not brighter, it is destroyed" is a lesson a warning label cannot deliver.

## What changed

- `REGULATOR_STAGES` × 6: one slot → larger resistance leaves less voltage → the burnout trap → two slots that add before they divide → a stage with several valid answers → the Ashford tie-in, a regulator set for a lamp never fitted.
- Nothing is a lookup table. `_lamp_voltage()` evaluates the divider, and `get_stage_solution()` brute-forces the stage's own rack, so a stage that cannot be solved from its parts is a test failure rather than a shipped dead end.
- Two new renderers: `MeterView` (dial, safe band, danger zone, and a needle with mass that swings rather than snaps) and a `LampView.State` of DARK / DIM / LIT / BURNT.
- Bench selection runs through `BENCH_FOR_CHALLENGE`, so the shared shell now hosts two apparatuses with no duplication.

## Verification

- 16/16 logic suites PASS, including the new `circuit_bench_regulator_test`, which checks the physics rather than the progression: the reading matches the divider to within a millivolt at every stage, more series resistance always leaves the lamp less voltage, every stage is solvable from its own rack, under-volt does not advance, and over-volt burns out and restarts the stage.
- 13/13 visual harnesses PASS for 130 captures; `11-regulator-under-volt.png`, `12-regulator-burnout.png` and `13-regulator-in-band.png` document the three outcomes.
- Parse 0 errors, `git diff --check` clean, QA save absent.

## Risks / follow-up

- Bench III (three-phase load balance) is designed but unbuilt; the master plate still throws without one.
- The alchemy workbench redesign remains outstanding.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-20`
- **Stage name:** Junction Bench I rendered as hardware, with visible charge
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **User-visible outcome:** The bench was a labelled wireframe — flat rectangles, a grey circle for a lamp, and no way to tell a switch from a fuse without reading. Every element is now drawn as the object it is. The source is a cell stack with plates and polarity. A blade switch is visibly hinged, and open lifts the blade off its post leaving a dashed air gap. A fuse is a glass cartridge with metal end caps; blown, its filament has parted and the glass behind it is sooted. A resistor has a ceramic body with four tolerance bands. A ceramic plug has ribs and no conductor through it. The load is a real bulb with an envelope, a coiled filament and a screw base. Empty sockets are recesses with exposed contact clips. Energising is no longer a colour change: charge carriers travel the conductive path, the filament whites out, and the bulb's halo washes the board.

## What changed

- Four drawn renderers in `circuit_lab_ui.gd`: `PartView`, `SourceView`, `LampView` and `CurrentFlow`. All use `_draw()` with gradients, highlights and shadow edges, so materials read as copper, brass, glass and ceramic without adding a single art asset.
- Parts are hit-tested by a transparent button sitting over the drawn object, so the player clicks the hardware rather than a labelled box.
- The rack shows the same object the board will hold, at a capped symbol width so a short tray cannot stretch a copper bar out of recognition.
- `CurrentFlow` only exists while the circuit is genuinely live, so "is it on?" is answered by motion rather than by a remembered colour.

## Verification

- 15/15 logic suites PASS; 13/13 visual harnesses PASS for 125 captures; parse 0 errors; `git diff --check` clean; QA save absent.
- Native evidence: `docs/evidence/2026-08-15-circuit-benches/` — `04-bench-live-run.png` shows carriers on the rail and the lit bulb; `08-bench-final-stage.png` shows the blown fuse, the two parallel bypasses and the full rack.

## Risks / follow-up

- Benches II and III are still designed but unbuilt; their plates throw without a bench.
- The alchemy workbench redesign is still outstanding and has the same "reads as a form, not as apparatus" problem this stage just fixed here.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-19`
- **Stage name:** Junction Bench I — continuity, and the short that darkened Ashford
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **Previous unpublished stages:** `UX-20260814-13` through `UX-20260815-18` are still unpublished and should be committed first, in that order.
- **User-visible outcome:** A located junction plate is no longer an operable one. The auxiliary plate now opens a six-stage bench that teaches one law by making the player operate it: a series run conducts only if every link conducts, and a conductor placed across the lamp carries the current past it. The second half is this case's own crime — stage 4 onward the player can close a perfectly complete loop and watch the lamp stay dark, with the current traced visibly through the bypass. Only after clearing all six stages does the plate throw in numbered order.

## What changed

- **New module.** `scripts/circuit_lab_ui.gd` (`CircuitLabUI`) is the shared bench shell — frame, atmosphere, dossier chrome, stage pips, lesson line, action line, part rack, per-stage reset and clear burst — plus Bench I's apparatus. An apparatus describes its stages as data and draws its own hardware; nothing else is duplicated.
- **Curriculum, six stages:** continuity → a resistor is still a conductor → a blown fuse is now just a gap → a conductor across the lamp steals the current → every bypass must stay open → the full bus, where a sound part in the wrong place reproduces the blackout.
- Link notation supports fixed hardware, empty sockets and pre-filled sockets, so "replace the blown fuse" is expressible without a special case.
- Bench I is drawn as hardware: a live rail, physical sockets, and parallel bypasses that tap the same two points across the lamp. Outcomes play on that hardware — an open run flashes and shakes, a short traces the detour in amber, a live run surges cyan into the lamp.
- `Enemy`-style gating: `BENCH_FOR_SWITCH` maps a plate to its bench flag. Plates without a bench stay operable, so the room is never blocked by unbuilt content.
- **Bug fix.** `ArchiveUi.apply_button()` deferred `_center_button_pivot` with a node argument; any screen that rebuilds controls emitted a stream of argument-conversion errors as freed buttons hit the deferred call. It now binds the button's own `resized` signal.

## Verification

- 15/15 logic suites PASS, including the new `circuit_bench_continuity_test`. It plays all six stages and asserts, at every stage that can express them, that an open link is rejected, that a wire across the lamp is rejected, and that a **resistor** across the lamp is rejected too — that last one is the misconception the bench exists to correct.
- 13/13 visual harnesses PASS for 125 captures, including the new `circuit_bench_visual_capture` (9 shots covering the empty bench, an open run, a live run, and the short both traced and explained).
- Parse 0 errors, `git diff --check` clean, QA save absent.
- Native evidence: `docs/evidence/2026-08-15-circuit-benches/`.

## Risks / follow-up

- Benches II (Ohm's law / voltage division) and III (three-phase load balance) are designed but not built; their plates currently throw without a bench.
- The alchemy workbench redesign is still outstanding.
- Two release-gate suites now pre-clear bench flags in setup, which is correct but means the bench is a real precondition anyone editing those suites must know about.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260815-18`
- **Stage name:** Concealed Circuit junction plates and the two ways to find them
- **Completed at:** `2026-08-15`
- **Status:** `complete`
- **Previous unpublished stages:** `UX-20260814-13` through `UX-20260814-17` are still unpublished and should be committed first, in that order.
- **User-visible outcome:** The Circuit workshop no longer hands the player three obvious plates to press. The junction plates are set flush with their housings and the room offers nothing at all: no plate, no prompt, no focus box and no contact band, so the puzzle cannot be brute-forced by walking the wall pressing interact. Inspecting any housing now says a plate is flush with it and that the repair blueprint would mark it. Two things reveal them — opening the repair blueprint **while standing in the Circuit Room**, or drinking a Vision potion, which sees through the housings. Either way the three plates charge, ring and settle into place in blueprint order, and the position is filed as a Note record so it is never lost.

## What changed

- **New seam.** `RoomInteractionRuntime` skips items marked `concealed`, so concealment removes the prompt, the focus box and the contact band together rather than only hiding a sprite.
- **Circuit Room** owns `circuit_switches_surveyed`. `_evaluate_switch_survey()` runs on `GameState.state_changed` and per frame (Vision expires on a timer, not a state change), and `_survey_switches()` plays a staggered charge/ring/settle reveal tinted cyan for the blueprint path and violet for the Vision path.
- **Map hub** sets `circuit_repair_map_studied` only when the blueprint is opened with `current_room_id == "circuit_room"`, so the drawing has to be held against the housings in front of you.
- Housing inspections append a concealment hint while unsurveyed, so the room states its own next step.

## Verification

- 14/14 logic suites PASS, including the new `circuit_switch_survey_test` (19 assertions: concealed by default, no interaction offered at a concealed band, blueprint reveals on site, Vision reveals without the blueprint, and the reveal survives Vision expiring).
- 12/12 visual harnesses PASS for 116 captures. `08a-circuit-plates-concealed.png` is new and documents the default state; `09-circuit-styled-switches.png` now documents the surveyed state.
- Parse 0 errors, `git diff --check` clean, QA save absent.

## Risks / follow-up

- The reveal is permanent once earned. That is deliberate — re-hiding a located plate would be hostile — but it does mean the Vision potion has no further use here after the first reveal.
- Still open, and each needs its own stage: a mini-game per switch, and the alchemy workbench redesign.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260814-17`
- **Stage name:** Hall scale, Guardian corner start and a contact estimate that actually runs down
- **Completed at:** `2026-08-14`
- **Status:** `complete`
- **Previous unpublished stages:** `UX-20260814-13` through `UX-20260814-16` are still unpublished and should be committed first, in that order.
- **User-visible outcome:** Castle Hall now reads as the large space it is. The detective's Hall-only visual scale drops from 2.0 to 1.45 (65.8px) and the Guardian from 1.0 to 0.80 (80px), so both are small against a 1920×1280 floor while the Guardian stays about 22% taller and visibly heavier. The Guardian now starts in the far bottom-right corner, resolved to the nearest walkable cell, so the first crossing is a long diagonal. The pursuit readout was reported as "only refreshing, never moving": it sampled a path estimate on an interval and snapped to each sample, so it never behaved like a clock. It now runs down every frame and re-measures on the interval, reporting danger immediately while rate-limiting relief, so gaining ground reads as the clock slowing rather than resetting.

## What changed

- `ROOM_VISUAL_SCALE_PROFILES["floor_1_hub"]` is 1.45; every other room keeps 2.0. Only the visual node changed — CharacterBody2D, collision shape, speed, A*, catch distance and line-of-sight are untouched.
- `Enemy.HALL_VISUAL_SCALE` / `HALL_VISUAL_FOOT_ANCHOR` are now named constants and the authoritative source; `scenes/enemy.tscn` matches them. The foot anchor was recomputed from the scale so the boots stay bottom-aligned with the body origin.
- `ENEMY_START_POSITION` / `GameState.GUARDIAN_HALL_START_POSITION` moved to the bottom-right corner, and `_guardian_hall_spawn_position()` resolves the authored corner through `_nearest_guardian_walkable_position()` before falling back to the farthest patrol node.
- `_update_guardian_countdown()` decrements every frame and clamps recovery to `GUARDIAN_ETA_RELIEF_RATE`.
- `guardian_hunt_visual_capture` now waits for the Map hub to settle before capturing, for the same reason the blackout harness does.

## Verification

- 13/13 logic suites PASS; 12/12 visual harnesses PASS for 115 captures; parse 0 errors; `git diff --check` clean; QA save absent.
- **New contracts:** the Guardian resumes physics and actually closes ground after the reveal, and the contact estimate measurably runs down. The first two assertions passed on the old build; the countdown assertion failed on it (13.45 → 13.45), which is exactly the reported symptom.
- Native evidence: `docs/evidence/2026-08-13-character-scale/before/02-castle-hall-guardian.png`, `docs/evidence/2026-08-14-guardian-hunt/`.

## Risks / follow-up

- **Known cosmetic defect, not fixed:** opening the Map while pursued lets the Hall's countdown panel ghost faintly through the hub's 94%-opaque backdrop. It needs the Hall to hide that panel when a hub opens, which the paused tree currently prevents.
- Hall fairness numbers in `standard_flow_pressure_audit` were re-run and still pass, but the corner start lengthens the first approach; the measured reaction budget should be re-read by a human before release.
- Not built this stage, and each needs its own: hiding the Circuit switches until the repair blueprint or a Vision-class potion reveals them; three Circuit mini-games; the alchemy workbench redesign.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260814-16`
- **Stage name:** Circuit switch reachability repair and the rebuilt Note hub
- **Completed at:** `2026-08-14`
- **Status:** `complete`
- **Previous unpublished stages:** `UX-20260814-13`, `UX-20260814-14` and `UX-20260814-15` are still unpublished and should be committed first, in that order.
- **User-visible outcome:** Circuit Room was uncompletable. All three power switches are painted onto the faces of solid props, and contact was measured against the painted plate, so every point that satisfied it was inside the workbench, generator or cabinet collision. Nothing could be pressed and the blackout could never be repaired. Rooms can now declare a walkable contact band separate from the visible plate, so each switch is operated from the floor in front of its housing while focus and prompt still frame the plate. The Note hub was rebuilt: the two floating star ornaments and the free-floating divider emblem are gone, the header is one band (title and subtitle left, mode stamp and close right, a single rule under both), the index column and the painted dossier page now share exact top and bottom edges, and the index scrollbar disappears when the index fits instead of showing a full-height grabber over three records.

## What changed

- **New seam.** `RoomInteractionRuntime._get_item_contact_rect()` lets a room declare `contact_rect` for a device that cannot be stood on. Focus rect, prompt anchor and highlight keep using `interaction_rect`, so the visible footprint rule is unchanged.
- **Single source of truth.** `CircuitLayout.SWITCH_SPECS` gained a `contact` band per switch, measured from the mounting prop's collision footprint, plus `get_contact_rect()`. The switches are also listed first in `INTERACT_ITEMS`, because the runtime offers the first touching entry.
- **Painted-page layout.** The Note hub measures the scroll artwork's solidly painted region (alpha ≥ 0.55, subsampled and cached) and derives the node rect from the page frame, so asymmetric transparent padding can no longer push the dossier out of line with the index.
- **Bug fix.** `OpticalFxRuntime._breathe_lamp()` called `get_meta("lamp_breath", null)`, which errors when the key is absent; every installed lamp logged an error on creation. Guarded with `has_meta()`.

## Verification

- **Headless release gate:** 13/13 logic suites PASS, including the new `circuit_switch_reach_test`.
- **Native release gate:** 12/12 visual harnesses PASS for 115 captures.
- **New contract:** every Circuit interaction is operable from a position the player can occupy; standing at a switch band selects the switch rather than its housing; and standing at the centre of a prop's front edge still selects the prop. The contract fails on the pre-fix build with six assertions.
- `room_spatial_audit` now measures the 14px band against the contact surface the runtime actually uses.
- Godot parse/import 0 errors, `git diff --check` clean, QA save absent.
- Native evidence: `docs/evidence/2026-08-14-ui-redesign/release-note-circuit/`.

## Risks / follow-up

- Contact bands are authored against the current prop footprints. If Circuit props are moved or resized, re-derive the three bands and re-run `circuit_switch_reach_test`.
- The other rooms were not audited for the same class of defect. Any interaction painted onto a solid prop elsewhere would have the same failure mode and no test covers it yet.
- One first-time human playtest is still the outstanding release blocker.

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260814-15`
- **Stage name:** Shared archive atmosphere, room light rigs and the postgame Case Archive
- **Completed at:** `2026-08-14`
- **Status:** `complete`
- **Previous unpublished stages:** `UX-20260814-13` and `UX-20260814-14` are still unpublished and should be committed first, in that order.
- **User-visible outcome:** Every archive-facing screen is now lit by one shared atmosphere pass instead of sitting on flat black — the intake, interruption and resolution screens gained a vignette, a flickering lamp, drifting dust and a very slow backdrop breath, and their record panels became physical dossiers with brass corner brackets, rivets and a bound spine. The two endings now file the same record under different accents: brass lamplight for the sealed review, arcane violet for the true record. Bag, Key and the Note dossier share that light; the Bag header no longer stacks three caption lines on one baseline and its quantity line no longer straddles the painted plaque edge. Circuit Room casts light from its five wall lamps, bench lantern and generator chamber and arcs from its cracked bus, and the arcing calms once power is restored. The Library casts light from all ten painted fixtures and gives each of the three light challenges a beacon in the wavelength it teaches. The Final Room casts its violet sconces, door sigil, vault core and brass orrery, and the accusation table now has a slow violet core. Finishing either ending unlocks a new **Case Archive** on the main menu: five sections (Evidence / People / Timeline / Science / Verdict) built entirely from the real playthrough state.

## What changed

- **New shared module.** `ArchiveUi` gained `install_screen_atmosphere()`, `install_dossier_chrome()`, `retint_dossier_chrome()` and `drift_backdrop()`, backed by a new premultiplied-alpha canvas shader `assets/ui/screen_atmosphere.gdshader` that performs vignette, lamp flicker, dust and grain in a single pass.
- **New world module.** `OpticalFxRuntime` gained `install_lamp()`, `set_lamp_energy()`, `install_arc_emitter()`, `set_arc_interval()` and generated radial-glow/additive resources, so rooms cast the light their art already paints without adding any new image asset.
- **New screen.** `scripts/case_archive_ui.gd` (`CaseArchiveUi`) is a self-contained CanvasLayer with a three-call interface: `is_unlocked()`, `open_archive()`, `close_archive()`. Unlock is derived from the existing `normal_ending` / `perfect_ending` story flags, so no parallel unlock field and no `SAVE_VERSION` change were needed and older ending saves are recognised automatically.
- **Real data, not a second narrative.** Evidence rows reuse the accusation table's own `SOURCE_SPECS` names and derive each detail line from `CONCLUSION_SPECS`, so the archive and the board cannot drift into two vocabularies. People, Timeline, Science and Verdict read `story_flags`, `visited_rooms`, `completed_rooms`, `learned_fire_oxygen_rule` and `learned_circuit_rule`.
- **Deliberate exclusion.** The survey Map hub is the one hub that does **not** receive the shared atmosphere. Its field renders unexplored hall geometry in near-black, so any light behind it lifts the walls into a readable building outline and breaks pre-power blackout secrecy. That exclusion is now an assertion, not a comment.
- **Release-gate repair.** `power_blackout_visual_capture` photographed the survey map two frames after `open_map()`, i.e. mid fade-in, so the translucent field let the hall art through and produced a false blackout leak in the evidence. The harness now waits for the hub to settle and measures mean field brightness, so blackout secrecy is checked by the gate instead of by eye.

## Verification

- **Headless release gate:** 12/12 logic suites PASS.
- **Native release gate:** 12/12 visual harnesses PASS for 115 generated 1024×768 captures (113 previously, plus two Case Archive captures).
- **New contracts:** intake/interruption/resolution each carry the shared atmosphere and dossier chrome; each ending files the record under its own accent; Bag/Key/Note carry the atmosphere while the survey map provably does not; the Case Archive is sealed before any ending, unlocks on the ordinary ending, lists records under all five sections, names evidence with the board's vocabulary, and stamps each ending differently.
- **Godot parser/importer:** headless editor parse/import PASS, 0 errors.
- `git diff --check` clean. QA save absent before and after.
- Native evidence: `docs/evidence/2026-08-14-ui-redesign/release-visual-overhaul/` (15 captures incl. `11-case-archive-evidence.png`, `12-case-archive-verdict.png`), `docs/evidence/2026-08-14-hub-room-polish/`, `docs/evidence/2026-08-14-library-light-challenges/`, `docs/evidence/2026-08-15-room-spatial/`, `docs/evidence/2026-08-14-power-blackout/`.

## Risks / follow-up

- The Case Archive is reachable from the main menu only. A direct entry from the ending screen was deliberately not added, because the resolution panel's three actions are already laid out to fixed measured regions; adding a fourth action is its own layout stage.
- Room light rigs are positioned against the authored 1448×1086 background plates. If any room background is repainted, the fixture coordinate tables in `circuit_room.gd`, `library_room.gd` and `final_room.gd` must be re-derived.
- The atmosphere shader animates from `TIME`, so captures of these screens are intentionally not pixel-stable between runs; the gate asserts structure and brightness, never pixel equality.
- One first-time human playtest is still the outstanding release blocker, unchanged from `UX-20260814-14`.
- GitHub publication remains reserved for the authenticated Codex/GitHub maintainer.

## GitHub documentation proposal

- Add: "Archive-facing screens now share one lit-room atmosphere and a physical dossier chrome, rooms cast the light their art paints, and finishing either ending unlocks a five-section Case Archive built from the real playthrough."
- Suggested commit title: `feat: share one archive atmosphere and add the postgame Case Archive`

## Copy this exact brief to Codex

```text
CODEX_SYNC_BRIEF
Stage: UX-20260814-15 Shared archive atmosphere, room light rigs and the postgame Case Archive
Status: complete
Outcome: One shared atmosphere pass (vignette, lamp flicker, dust, grain) and a physical dossier chrome now unify the intake, interruption and resolution screens plus Bag, Key and the Note dossier; the two endings file the same record under brass or arcane-violet accents. Circuit, Library and Final Room cast light from the fixtures their art already paints, Circuit's cracked bus arcs until power is restored, each Library light challenge carries a beacon in the wavelength it teaches, and the accusation table gained a slow violet core. Finishing either ending unlocks a Case Archive on the main menu with Evidence/People/Timeline/Science/Verdict sections derived entirely from real GameState.
Changed: autoload/archive_ui.gd, assets/ui/screen_atmosphere.gdshader, scripts/optical_fx_runtime.gd, scripts/case_archive_ui.gd (new), scripts/start_ui.gd, scripts/death_ui.gd, scripts/game_over_ui.gd, scripts/main_menu.gd, scripts/inventory_hud.gd, scripts/key_hud.gd, scripts/clue_journal.gd, scripts/map_hud.gd, scripts/circuit_room.gd, scripts/library_room.gd, scripts/final_room.gd, scripts/final_case_board.gd, tests/ui_design_contract_test.gd, tests/ui_visual_gallery.gd, tests/power_blackout_visual_capture.gd, release docs.
Verified: 12/12 headless suites PASS; 12/12 native harnesses PASS for 115 captures; new atmosphere/chrome/ending-accent/Case-Archive contracts PASS; survey map provably carries no light layer and its blackout field brightness is now measured by the gate; Godot parse/import clean; git diff --check clean; QA save absent.
Evidence: docs/evidence/2026-08-14-ui-redesign/release-visual-overhaul/ (15 captures), docs/evidence/2026-08-14-hub-room-polish/, docs/evidence/2026-08-14-library-light-challenges/, docs/evidence/2026-08-15-room-spatial/, docs/evidence/2026-08-14-power-blackout/
Risks: Case Archive is main-menu only; room light rigs are tied to the current 1448x1086 background plates; human first-time playtest still outstanding.
GitHub proposal: publish as separate commit `feat: share one archive atmosphere and add the postgame Case Archive` after UX-20260814-14.
Requested Codex action: review and publish this versioned stage
```

---

# Previous stage (still unpublished)

## Stage

- **Stage ID:** `UX-20260814-14`
- **Stage name:** Power-restoration milestone, measured Hall fairness and Wake bookshelf repair
- **Completed at:** `2026-08-14`
- **Status:** `complete`
- **Previous unpublished stage:** `UX-20260814-13` introduced the four-file Bag and power-gated exploration memory and should be committed first.
- **User-visible outcome:** Completing the Circuit switch sequence now lands as a chapter milestone: the generator takes a physical impact, workshop light flickers twice and an original electric surge plays. On the first Hall return, a cyan scan restores recorded gray routes progressively, then displays `POWER RESTORED · ROUTE MEMORY ONLINE` and directs the player to open Map immediately. The standard pre-Circuit route was measured and the minimum Hall-return separation raised from 520px to 800px, preserving +12% Guardian escalation while guaranteeing at least 4.32s reaction at Tier 2. Wake Room's bookshelf is interactable again from a real walkable point while its focus boundary still matches the visible shelf exactly.

## What changed

- `scripts/circuit_room.gd`: successful Master activation queues a one-time Hall restoration sequence and Map objective, unlocks Map, and plays `_play_power_restoration_impact()`: two generator rings, eased generator squash/settle, restrained camera impact, two-step full-screen cyan flicker and `PowerSurgeAudio` at -7dB.
- `assets/audio/sfx/power_restore_surge.wav`: new 1.65s original stereo electrical one-shot. `tools/generate_power_restore_sfx.mjs` deterministically synthesizes its relay impact, rising hum, electrical arcs and arcane resonance; `assets/audio/README.md` records provenance and format.
- `scripts/game_world.gd`: first powered return runs `_begin_power_restoration_return_sequence()` instead of stacking the normal Guardian close-up. Recorded Hall cells are sorted by distance from the Circuit doorway and progressively fed into the 16px world fog across 1.20s. A centered progress panel transitions to the exact completion status, then exposes a temporary `ROUTE MEMORY ONLINE` objective. The Guardian is held/non-lethal during scanning and the 1.15s reward-reading window; Map becomes usable as soon as scanning completes.
- `scripts/map_hud.gd`: first powered Map open sets `power_map_reviewed` and calls back into the active Hall to dismiss the temporary objective. Map CanvasLayer visibility now respects its own unlock even if an old save lacks the toolkit flag.
- `scripts/wake_room.gd`, `scenes/wake_room.tscn`: interaction highlight/contact remains the exact visible art rectangle, while `_get_visual_interaction_approach()` separately samples walkable points along its 14px contact band. The shelf visual moved 6px to align its opaque floor edge with authored collision/mask geometry.
- `tests/power_restoration_milestone_test.gd`: verifies one-shot flags, audio playback, named impact/flicker nodes, progressive scan, exact completion prompt, Map objective and objective completion.
- `tests/standard_flow_pressure_audit.gd`: measures the real A* critical path and escalation budget. Wake→Chemistry 14.76s, Chemistry→Greenhouse 16.53s, Greenhouse→Circuit 7.64s; 38.93s total across three safe-room-separated pressure beats. 800px separation yields 4.78/4.78/4.32s reaction.
- `tests/wake_room_debug_path_test.gd`, `tests/room_spatial_audit.gd`: jointly prove the shelf is selectable from its computed walkable point and that bed/desk/shelf/door contact footprints still match visible art.
- `tests/power_restoration_visual_capture.gd`, `tests/wake_room_debug_path_visual_capture.gd`: native evidence for impact, scanning, online status, powered Map reward and restored bookshelf focus.

## Design decisions

- **Power restoration replaces, not stacks with, the return close-up.** The player receives one safe, readable beat rather than overlapping scan, Guardian cinematic, ETA and awareness UI.
- **Original procedural SFX, no unclear license.** The sound is generated from equations/noise with a fixed seed and has a reproducible source script.
- **Fairness came from measurement, not slowing the Guardian.** Tier 2 already nearly matches player speed. An 800px safe spawn keeps escalation meaningful while providing a usable reaction window.
- **Interaction geometry has two responsibilities.** Visible art owns highlight/contact; a separate resolver owns navigation endpoints. Expanding invisible hitboxes would make focus misleading.

## Evidence and verification

- **Headless release gate:** 12/12 suites PASS, adding the power-restoration milestone and standard-flow pressure audit to all prior contracts.
- **Native release gate:** 12/12 visual harnesses PASS for 113 generated 1024×768 captures with no runtime error markers.
- Manual review confirmed generator impact is readable without obscuring actors; scan/progress/online states do not overlap Guardian pressure HUD; Map opens visibly and displays recovered gray routes; Wake shelf focus and prompt match the object with no debug path visible.
- Native evidence: `docs/evidence/2026-08-14-power-restoration/` (4 captures), `docs/evidence/2026-08-13-opening-flow/03-wake-bookshelf-interaction-restored.png`, and `docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md`.
- **Godot parser/importer:** headless editor parse/import PASS.
- **Save integrity:** one-time sequence/objective completion is persisted through story flags and needs no schema migration.
- `git diff --check` clean.

## Risks / follow-up

- The automated route audit validates geometry and timing but does not replace one first-time human playtest. A release candidate still needs an unfamiliar player to complete Wake→Circuit while deaths, wrong turns and time-to-power are recorded.
- The new one-shot is an event sound, not the requested full background-music system; adaptive BGM remains a later release stage.
- GitHub publication remains reserved for the authenticated Codex/GitHub maintainer. This stage should be committed after `UX-20260814-13`.

## GitHub documentation proposal

- Add: “Circuit restoration now lands with original audiovisual impact, a progressive Hall route scan and an immediate Map objective; measured return spacing preserves at least 4.32s reaction at pre-Circuit Tier 2.”
- Suggested commit title: `feat: stage the Circuit power restoration milestone`

## Copy this exact brief to Codex

```text
CODEX_SYNC_BRIEF
Stage: UX-20260814-14 Power-restoration milestone, measured Hall fairness and Wake bookshelf repair
Status: complete
Outcome: Master-switch completion plays a generated 1.65s electrical surge, generator impact, flicker and camera response. First Hall return progressively restores routes over 1.20s, displays POWER RESTORED · ROUTE MEMORY ONLINE and makes Map immediately available; opening it completes the objective. Standard A* audit measures three pre-Circuit darkness beats (38.93s total) and 800px return separation guarantees 4.32s worst-case reaction at Tier 2. Wake bookshelf is selectable again without enlarging its visible focus boundary.
Changed: scripts/circuit_room.gd, scripts/game_world.gd, scripts/map_hud.gd, scripts/wake_room.gd, scenes/wake_room.tscn, assets/audio/sfx/power_restore_surge.wav, assets/audio/README.md, tools/generate_power_restore_sfx.mjs, tests/power_restoration_milestone_test.gd, tests/power_restoration_visual_capture.gd, tests/standard_flow_pressure_audit.gd, tests/wake_room_debug_path_test.gd, tests/wake_room_debug_path_visual_capture.gd, docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md, release docs.
Verified: 12/12 headless suites PASS; 12/12 native harnesses PASS for 113 captures; generated WAV decodes as 1.65s; exact milestone, route progression, Map objective, reaction-budget and Wake geometry contracts PASS; Godot parse/import and diagnostics clean; git diff --check clean; QA save absent.
Evidence: docs/evidence/2026-08-14-power-restoration/ (4 captures), docs/evidence/2026-08-13-opening-flow/03-wake-bookshelf-interaction-restored.png, docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md
Risks: human first-time playtest remains required; adaptive BGM is not part of this event-SFX stage.
GitHub proposal: publish as separate commit `feat: stage the Circuit power restoration milestone` after UX-20260814-13.
Requested Codex action: review and publish this versioned stage
```
