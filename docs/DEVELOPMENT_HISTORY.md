# Development History

This page turns the repository history into a concise portfolio narrative. The milestone labels below are retrospective groupings of the dated Git commits, so the timeline can be audited from the commit log rather than treated as a vague claim of progress.

## v0.1 — Foundation: movement, maze, and atmosphere

**July 10, 2026**

The project began as a Godot prototype with player movement and a castle maze. The first visual-system iterations focused on limited visibility: a circular flashlight fog was implemented, then refined so walls blocked vision rather than simply darkening the whole map.

**What this established:** a readable top-down control scheme, a playable castle space, and a strong mystery atmosphere.

**Representative commits:** `7b84be9`, `349b4ab`, `6ecc8dd`.

## v0.2 — Investigation loop and consequence system

**July 11, 2026**

The next pass gave exploration stakes. A Castle Guardian uses A* pathfinding to chase the player; collision triggers a failure state. Dialogue pauses the chase so reading and decision-making remain fair rather than becoming a reflex test.

**What this established:** the tension/release rhythm of exploring, observing, talking, and escaping.

**Representative commits:** `530726f`, `c8698e6`.

## v0.3 — Castle expansion and detective structure

**July 12, 2026**

The prototype became a detective game rather than a maze. This version added a larger castle map and camera follow, evidence-board views, named suspects, biology evidence, a final deduction room, an accusation ending, a collapsible objective panel, and restart/menu shortcuts.

**Design decision:** evidence was written to be suggestive without being automatically conclusive. This supports the central detective skill: separating a clue from proof.

**Representative commits:** `ae74183`, `a64a450`, `fe5c2e2`, `0804d87`, `afb6f4f`, `7196553`, `be89982`, `43d6f4b`, `401a5e3`.

## v0.4 — STEM gates and cross-room reasoning

**July 13, 2026**

This pass added locked-door STEM puzzles and required players to learn a relevant clue before attempting a lock. The goal was to make the educational material part of the game loop, not a disconnected quiz screen.

**What this established:** a concrete connection between observation, knowledge, and progression.

**Representative commits:** `ca385da`, `8a45b9f`.

## v0.5 — Onboarding and information clarity

**July 14–15, 2026**

The project received an animated intro, clearer main-menu handling, a wake-room background pass, a first knowledge gate, and a notes tool shown above puzzle overlays. These changes addressed a key usability problem: players needed to understand both their immediate objective and where to revisit evidence.

**Representative commits:** `f94f95a`, `0e7b2c7`, `6d67566`, `0c96509`, `ed59f82`.

## v0.6 — Production polish: saves, room integration, and animated NPCs

**August 12, 2026**

The final polish pass focused on a more complete delivery: menu and checkpoint work, interaction cleanup, dedicated room backgrounds/props, and an NPC art-system replacement. The final NPCs use transparent 4 × 4 sprite sheets with four walking frames in each of four directions.

| Character | Gameplay role | Final placement |
| --- | --- | --- |
| Dr. Lin | Missing researcher / memory clue | Blue-tinted vision-memory echo in the Chemistry Room |
| Butler | Suspect | Chemistry Room |
| Gardener | Suspect | Greenhouse Room |
| Mechanic | Suspect | Circuit Room |
| Castle Guardian | Pursuer | Castle Hall chase system |

The reusable [`AnimatedNpc`](../scripts/animated_npc.gd) component turns each sheet into walk and idle animations, adds optional small patrol movement, and keeps all ordinary NPCs consistent. The Guardian uses the same art-sheet specification inside its own pathfinding scene.

See [Character Art Pipeline](ART_PIPELINE.md) for the documented visual iterations.

## v0.7 — Archive-system redesign: evidence chains, reversible failure, and dual endings

**August 12, 2026**

The closing sequence was rebuilt after a design review found that the old final room behaved like a linear quiz. The replacement is an Ashford analysis table: the player selects two or three raw records, forms one of five case conclusions, and seats each conclusion in a matching radial brass slot. A wrong pairing dims the connection and explains the contradiction, but does not erase progress or consume evidence.

The ordinary resolution deliberately identifies the **Butler as the executor**, not the full author of the crime. The follow-up path avoids an automatic “perfect ending” unlock. After the ordinary case closes, three unmarked Sealed Archives can be found by revisiting existing objects in the Dining Hall, Circuit Room, and Library. Players must read and manually pin all three records in Note Hub before the same table reveals a second, three-link command chain:

1. The Butler's pressure and motive to obey an emergency order.
2. The forged Mechanical Office instruction that appeared legitimate.
3. Dr. Lin's decision to deny the Mechanic funding and expose unauthorized copies.

Completing that chain exposes the **Mechanic** as the person who forged the order, weaponized the Butler's trust, and attempted to claim Dr. Lin's research. This structure distinguishes physical action from authorship, so the player has a reason to revisit evidence rather than merely collect every clue.

The alchemy screen was also revised from auto-filled ingredients into a small experiment: choose a recipe, place its three condensed materials into any order across three reaction nodes, preserve the fourth violet stabilizer node, then pull the extraction lever. Incorrect setups create explanatory violet smoke and consume nothing; only a valid arrangement reaches the existing crafting and inventory path.

**Technical decisions:** `FinalCaseBoard` is a dedicated Godot Module with a narrow Interface (`open_case`, `close_case`, and ending signals). It owns the case-board state; `final_room.gd` owns only room state and narrative handoff. Sealed-archive pinning is persisted through the existing Note Hub save payload, so the true-ending investigation survives a restart.

**Representative commit:** this milestone is recorded in the repository immediately after the archive UI foundation commit `4c33790`.

## v0.8 — Furniture scale, persistent Guardian hunt, and archive UI

**August 13–14, 2026 · Stage `UX-20260814-03` · Local review-ready**

Characters were recalibrated against real furniture while physics roots remained unchanged. The Guardian became a persistent `DORMANT / CHASE / PATROL` state machine: it pursues in Castle Hall, advances along a validated route while another room is loaded, and remains visible as a red signal on the minimap. Bag, Key, Note, Map, alchemy, final deduction, interruption, and ending screens were unified under the dark-brass/violet/parchment archive language.

**Evidence:** `docs/evidence/2026-08-13-character-scale/`, `docs/evidence/2026-08-14-guardian-hunt/`, `docs/evidence/2026-08-14-ui-redesign/`.

## v0.9 — Spatial contracts and Guardian pressure

**August 14, 2026 · Stage `UX-20260814-04` · Local review-ready**

All eight areas adopted alpha-bounded interaction footprints, a 14px contact band, 10px focus padding, physics-query safe spawns, and visual-bottom depth reversal. Every Hall entry gained a Guardian close-up followed by lethal pursuit, a live A*-path contact estimate, and restored minimap tracking. The one-time Hall guide became cardinal-only with explicit 90-degree turns. Formula sheets and reagent models entered a shared item-art catalog.

**Evidence:** `docs/evidence/2026-08-14-guardian-pressure/`, `docs/evidence/2026-08-14-item-models/`, `docs/evidence/2026-08-15-room-spatial/`.

## v0.10 — Hub typography and room-device polish

**August 14, 2026 · Stage `UX-20260814-05` · Current Codex handoff**

Note Hub replaced its oversized decorative close emblem and duplicate scrollbar with focusable, functional dark-brass controls; document text and record labels are centered. Bag Hub now uses a contained four-column category rail and non-overlapping detail stack. GPT-authored Blue Blossom, Moonleaf, and red-stain trace models complete the material family.

The final deduction lever no longer names the Butler or Mechanic before resolution. Library's pure RGB rectangles became muted jewel glass in optical brass mounts. Circuit Room gained three distinct physical switch models; `CircuitLayout` now owns their world coordinates, interaction footprints, sequence metadata, and repair-map projection, eliminating drift between the room and map.

**Evidence:** `docs/evidence/2026-08-14-hub-room-polish/`.

## v0.11 — Distributed Library light challenges

**August 14, 2026 · Stage `UX-20260814-06` · Current Codex handoff**

The Library's three RGB lenses stopped being three adjacent free interactions. Learning and assessment are physically separated: three marked empty shelves hold the visible-spectrum, reflection/absorption, and additive-light records; three distant desks hold the corresponding mini-games. A question terminal remains locked until its shelf record is explicitly filed, and it never repeats the answer.

The three assessments cover visible-spectrum wavelength order, leaf reflection versus absorption, and additive-light target mixing. Wrong answers explain what model failed without consuming progress. Each solved apparatus awards one persistent jewel filter.

The central optical array begins with three empty brass slots. A slot rejects use until its matching challenge reward exists; after all three filters are inserted, RGB light combines into a pale archive beam and unlocks the layered record. Existing saves migrate active lenses into earned rewards so no player loses progress.

**Evidence:** `docs/evidence/2026-08-14-library-light-challenges/`.

## v0.12 — Library optics laboratory

**August 14, 2026 · Stage `UX-20260814-07` · Current Codex handoff**

The three desk puzzles were rebuilt as standalone-quality mini-games in one shared arcade shell (`LibraryLightLabUI`). Each game now runs five escalating stages with its own apparatus artwork instead of ending after a single answer.

Prism Cascade sends a white beam through a glass prism into a labelled 700–410 nm spectrum strip, then asks the player to seat 3, 4, 5, 6 and finally 7 crystals on a dispersion rail. Pigment Bench lights a specimen with separated red, green and blue beams, draws only the reflected beams onward to an observer, and updates a perceived-colour swatch live across five specimens. Additive Relay blends three lamp discs with real additive blending and off/half/full intensity to render cyan, magenta, yellow, white and amber against a target swatch and a match meter.

Every game shares stage pips, a progress bar, a score, a hint that explains without solving, and a per-stage reset. Wrong answers cost nothing.

**Evidence:** `docs/evidence/2026-08-14-library-light-challenges/` (14 captures).

## v0.13 — Animated optics presentation

**August 14, 2026 · Stage `UX-20260814-08` · Current Codex handoff**

The optics laboratory received a separate presentation layer rather than more static borders. A shader now animates a low-contrast optical grid, scan beam, sparse stars and vignette behind each apparatus. Ambient archive motes, brass energy rails and slowly rotating precision reticles make the three devices feel active while keeping text and controls clear.

Feedback is tiered by importance. Routine choices receive eased button motion and colour-matched sparks; hints and incomplete submissions receive restrained pulses; incorrect models receive a brief purple-red flash and small modal-only shake; stage clears receive a gold/green seal, radial sparks and expanding ring. A full clear alone reveals a physical filter jewel with a brass frame, glass facets, highlight, three halos and a separate result plaque.

**Evidence:** `docs/evidence/2026-08-14-library-light-challenges/` (14 captures).

## v0.14 — Unified staged optical effects

**August 14, 2026 · Stage `UX-20260814-09` · Current Codex handoff**

`OpticalFxRuntime` established one timing language for visible energy across the game: charge, travel, impact, traced beam, sustained state. The Library observer became a layered science-fiction instrument with a brass housing, dual rotating scanner rings, cyan iris, six aperture blades, sensor core and sweeping scan beam. Prism crystals now fly from the tray into empty sockets before emitting to their matching spectrum bands; additive light originates in physical emitters and travels along feed lines before discs ignite.

The world RGB array follows the same rules. Each recovered filter physically drops into its slot, impacts, then sends a colour beam into a rotating archive scanner. Pale white archive light waits until the final beam arrives instead of appearing with the last click.

The shared language now also covers Circuit switch charging, item reward arrival, parchment unfurling, Final Board evidence pin/link growth, and three-feed alchemy extraction. All effects are non-blocking and verify current state in delayed callbacks so rapid reset/reselection cannot revive stale beams.

**Evidence:** `docs/evidence/2026-08-14-library-light-challenges/` (19 captures), `docs/evidence/2026-08-14-hub-room-polish/` (20 current captures), `docs/evidence/2026-08-14-ui-redesign/optical-sequence-release/` (13 captures).

## v0.15 — Four-Hub field-kit redesign

**August 14, 2026 · Stage `UX-20260814-10` · Current Codex handoff**

Bag, Key, Note and Map were rebuilt as one coherent detective field kit without becoming four copies of one panel. Shared Archive chrome supplies brass corners, a mode stamp and concise task protocol; each Hub keeps a purpose-specific structure.

Bag separates category names from count badges and expands the detail reading stack so the longest title, description and requirements fit without overlap. Key replaces the old overlapping picture-board grid with eight non-overlapping lock profiles, recovered/locked labels, progress pips and a dedicated detail chamber. Note narrows its index and widens the dossier page while replacing the sparse home page with actual record and sealed-archive progress. Map preserves its full-size map, moves it left and widens the live survey ledger.

The contract now measures rendered text rather than only configured rectangles: all eight Bag category names, longest Bag description/requirements, all Key slots and details, Note home-page progress, and Map ledger copy must fit at 1024×768.

**Evidence:** `docs/evidence/2026-08-14-ui-redesign/hub-layout-release/` (13 captures), `docs/evidence/2026-08-14-hub-room-polish/` (20 current captures).

## v0.16 — Guardian awareness rework and the tracking serum

**August 14, 2026 · Stage `UX-20260814-11` · Current Codex handoff**

The Guardian stopped being a constant omniscient chaser and became a two-phase
threat with an in-fiction explanation. While the player still carries the
tracking serum administered in the wine at the last dinner, the Guardian knows
the player's position anywhere on the floor, and every recovered room key raises
its chase speed by 12% up to a six-tier cap. Escalation is derived from the keys
the player holds rather than a separate counter, so existing saves resolve to the
correct tier without a save-version bump.

The Dining Hall now yields Mrs. Lin's counter-formulas — the Purification,
Daze and Shroud blueprints — as a single narrative beat alongside the dining
timeline evidence. Drinking the Purification Potion permanently washes the serum
out of the player's blood. From that point the Guardian loses positional tracking
and instead stakes out the doorway of the player's next objective room at a very
slow 44 px/s.

Detection afterwards is honest and readable: a 300px sight cone with a ±46°
half-angle, an 78px proximity radius for close contact, and a grid line-of-sight
sample so walls actually block vision. Sighting the player restores the full
escalated chase speed; losing sight drops the Guardian into a six-second search
sweep at 96 px/s toward the last known position before it returns to its
stakeout. The Daze Potion stuns it outright for seven seconds and the Shroud
Potion makes the player unsightable for twelve, giving the alchemy system real
tactical weight instead of pure utility.

A bilingual awareness strip under the pursuit bar reports the Guardian's current
state, escalation tier, effective chase speed and the player's active reagents,
so none of this behavior is hidden.

**Evidence:** `docs/evidence/2026-08-14-guardian-awareness/` (7 captures),
`docs/evidence/2026-08-14-guardian-hunt/` (3 captures).

## v0.17 — Four-Hub authored-art fit

**August 14, 2026 · Stage `UX-20260814-12` · Current Codex handoff**

The field-kit redesign kept its new information hierarchy, non-overlapping Key
cards, wider dossier and readable Map ledger, but the authored images were made
to fit those structures instead of remaining a second, obsolete layout beneath
them.

The Key board required the real correction. Its source and target are already
the same 3:2 aspect, so simply changing stretch modes could not align its old
narrow recesses with the new wider cards. The complete source remains visible
for the title, outer frame and four corner stones. Three atlas regions from that
same image — the two gold-framed rows and lower parchment — are enlarged beneath
the redesigned cards and detail chamber. The result preserves the requested
layout while every card visibly belongs inside the original art.

Bag's 1536×1024 workbench continues to fill its proportional 960×640 frame. Note
now declares a full-frame, content-safe parchment policy. Map artwork and fog are
locked to the same 720×540 rectangle, preserving every room, player and Guardian
coordinate. Contracts now verify artwork containment and frame equality across
all four Hubs rather than relying on screenshot judgment alone.

**Evidence:** `docs/evidence/2026-08-14-ui-redesign/hub-artwork-fit-release/`
(13 captures).

## v0.18 — Four-file Bag and powered exploration memory

**August 14, 2026 · Stage `UX-20260814-13` · Current Codex handoff**

Bag stopped exposing every backing collection as a separate player-facing tab.
Its four source-art recesses now map exactly to ALL, POTIONS, MATERIALS and
PAPERS. Physical stock — herbs, laboratory reagents, food and key fragments —
lives under Materials. Documentary stock — formula blueprints, Dr. Lin's route
map and the Circuit repair sheet — lives under Papers. Transparent hit targets
let the original metal tabs remain the visible frames.

The castle blackout is now a progression state rather than a side effect of the
Guardian chase. Before Circuit power, the Hall resets everything outside the
wall-occluded flashlight to pure black every frame; walking records hidden route
data but leaves no visible gray trail. Full Map and Guardian minimap likewise
show no architecture, only live player/Guardian signals.

Restoring the Circuit generator hydrates every recorded 32px Hall route into the
16px world-fog grid. Walked space then becomes dim gray memory while unwalked
space remains black. The full Map and minimap share the same fog texture, so no
surface can leak more knowledge than another and the reward is immediately
retroactive.

**Evidence:** `docs/evidence/2026-08-14-power-blackout/` (4 captures),
`docs/evidence/2026-08-14-ui-redesign/four-files-blackout-release/` (13 captures).

## v0.19 — Circuit restoration milestone and measured pressure

**August 14, 2026 · Stage `UX-20260814-14` · Current Codex handoff**

Restoring power became a deliberate chapter beat rather than a silent flag change.
The Master switch now sends two impact rings through the generator, briefly
squashes and energizes its machinery, shakes the camera without moving gameplay
bodies, flickers the workshop lights twice and plays a reproducible original
1.65-second relay/hum/electrical-arc one-shot.

The first Hall return replaces the redundant Guardian close-up with a safe
1.20-second route-memory scan. Recorded cells are sorted outward from the Circuit
door and revealed progressively while a cyan progress panel and restrained world
scan ring communicate the change. Completion reports `POWER RESTORED · ROUTE
MEMORY ONLINE`, exposes a temporary Map objective and makes Map immediately
available; opening it clears the objective. Guardian pressure UI and lethal
contact stay suspended through the scan and brief reward-reading window.

The pre-Circuit route was measured on the real Hall A* grid. Its three darkness
beats are 14.76s, 16.53s and 7.64s at base movement speed, separated by Chemistry
and Greenhouse safe rooms. Tier 2 reaches 179.8px/s against the player's 180px/s,
so the former 520px return separation allowed only 2.76 seconds of reaction. An
800px minimum raises the worst case to 4.32 seconds without weakening the +12%
per-key escalation.

Wake Room's bookshelf was repaired at the same testable geometry seam. Its visible
art still owns the exact focus/contact rectangle, while a separate resolver finds
a physically walkable point on that rectangle's 14px band. A six-pixel art-foot
alignment correction makes the authored shelf collision, walkable mask and opaque
edge agree.

**Evidence:** `docs/evidence/2026-08-14-power-restoration/` (4 captures),
`docs/evidence/2026-08-13-opening-flow/03-wake-bookshelf-interaction-restored.png`,
`docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md`.

### `UX-20260814-15` — Shared archive atmosphere, room light rigs and the postgame Case Archive

The painted art was strong but nothing in front of it was lit. Archive-facing
screens sat on flat black and their record panels were generic rounded
rectangles, so the intake, interruption and resolution screens read as three
unrelated overlays over three unrelated illustrations.

The fix was one shared module rather than three local ones.
`ArchiveUi.install_screen_atmosphere()` runs a single premultiplied-alpha canvas
shader that both darkens (edge falloff) and emits (lamp flicker, drifting dust,
faint grain) in one pass, and `install_dossier_chrome()` gives every record panel
brass corner brackets, rivets, a bound left spine and an inner hairline. Because
the accent is a parameter rather than a node graph, the two endings became the
same physical record filed under different seals: brass lamplight for the sealed
review, arcane violet for the true record.

The same idea was applied to the world through `OpticalFxRuntime.install_lamp()`
and `install_arc_emitter()`, using runtime-generated textures so no new art
entered the pipeline. Circuit Room now casts light from the five wall lamps,
bench lantern and generator chamber its plate already paints and arcs from its
cracked bus until power is restored; the Library casts all ten of its fixtures
and gives each of the three light challenges a beacon in the wavelength it
teaches; the Final Room casts its violet sconces, sealed door sigil, vault core
and brass orrery.

One hub was deliberately excluded. The survey Map renders unexplored hall
geometry in near-black, so adding light behind it lifted the walls into a
readable building outline and broke pre-power blackout secrecy. Investigating
that also exposed a pre-existing false positive: the blackout harness
photographed the map two frames after opening it, mid fade-in, so the translucent
field let the hall art through in the release evidence. The harness now waits for
the hub to settle and measures mean field brightness, so the secrecy rule is
checked by the gate instead of by eye.

Finally, finishing either ending now unlocks a **Case Archive** on the main menu
with Evidence, People, Timeline, Science and Verdict sections. Every line is
derived from real playthrough state, and evidence rows reuse the accusation
table's own names and link each record to the conclusion it supports, so the
archive and the board cannot drift into two vocabularies. Unlock is read from the
existing `normal_ending` / `perfect_ending` flags, so no parallel unlock field and
no save-schema change were needed.

**Evidence:** `docs/evidence/2026-08-14-ui-redesign/release-visual-overhaul/`
(15 captures), `docs/evidence/2026-08-14-hub-room-polish/`,
`docs/evidence/2026-08-14-library-light-challenges/`,
`docs/evidence/2026-08-15-room-spatial/`,
`docs/evidence/2026-08-14-power-blackout/`.

These thirteen local stages intentionally remain uncommitted/unpublished until the repository owner's Codex/GitHub maintainer reviews the existing dirty worktree and splits it into auditable commits.

## v0.20 — Three verbs at the junction, and copy that stops fighting the plate

**August 15, 2026**

Circuit Room's three plates stopped being switches to press and became three
**Junction Benches**, deliberately built as three different verbs rather than
one puzzle wearing three coats. Bench I is **build**: seat parts until a series
loop conducts, then discover from stage 4 that a closed loop can still leave the
lamp dark, because a conductor laid across it carries the current past — the same
fault that darkened Ashford. Bench II is **track**: no parts rack at all, just a
draggable rheostat wiper, a live circuit and an analogue meter, cleared by
*holding* the needle inside the printed safe band while the filament heats and
the load drifts under the player's hand. Bench III is **diagnose**: nothing to
build or tune, a dead bus, and a probe. Open faults read full supply upstream and
zero downstream, so two chosen probes box the fault in; from stage 4 the fault
still conducts, so nothing reads zero and the culprit has to be named by
comparing drops between neighbours. Every reading in all three benches is solved
from the series chain, and a wrong accusation is answered with the measurement
that contradicts it rather than with "no". The benches are drawn as hardware —
hinged blade switches, glass fuses with visible filaments, banded resistors,
ceramic windings, brass test-point studs — because a bench that renders as a form
teaches a form.

The alchemy workbench then got the inverse treatment: its painted plate was
already good, and the text layer was the thing fighting it. Captions that had
been floating over reaction smoke and shelf clutter were given brass-edged
specimen plaques, and the rack rows were found to be drawing reagent and formula
names *underneath* their own icons — a defect that had been quietly rendering
洞察药剂配方 on screen as the meaningless 寒药剂配方. The seven-space text prefix
that was standing in for layout could neither scale with the icon nor survive
word wrap; the clearance now lives in the row's stylebox, where overlap is not
expressible, and the contract test asserts it per row.

**Evidence:** `docs/evidence/2026-08-14-ui-redesign/release-three-benches/`,
`docs/evidence/2026-08-14-ui-redesign/before/05-alchemy-ready.png`.

## v0.21 — The game finds its voice

**August 15, 2026**

Until this point the entire project contained exactly one sound effect. It now
has a mixer (`Master / Music / SFX / UI`), an original score, and feedback on
every action that carries weight — all of it generated deterministically by
`tools/generate_audio_set.mjs` from oscillators and seeded noise, with no
samples and no third-party audio anywhere.

The score is built on one idea worth stating plainly: it is three eight-second
layers of the *same* D-minor piece — the archive at rest, something is aware of
you, the Guardian has you — started on the same frame and never stopped.
Escalation is nothing but a change of gain. That is what lets the music tighten
as the Guardian closes and relax when the hunt clears without a restart, a seam,
or a tempo slip, and it is why the contract test asserts that all three layers
are still *playing* and still share a playback position after an intensity
change. A later "optimisation" that stopped a silent layer to save CPU would
desynchronise the whole score, and the suite now fails loudly if anyone tries.

Wiring was done at chokepoints rather than screen by screen: every archive
button already passes through `ArchiveUi.apply_button`, so that is where a press
became audible (confirming and retreating deliberately sound different), and
`GameAudio` subscribes to `GameState.item_acquired` rather than making GameState
learn any audio vocabulary. Settings gained separate Music and Effects faders —
separate because muting everything to silence one of them is a real loss — and a
new `ArchiveUi.apply_slider()` with a generated brass grabber so the faders speak
the same brass-on-walnut language as the rest of the case file.

Two Godot traps were worth the scar tissue. `AudioStreamWAV.loop_end` is a frame
index rather than a sentinel, so `loop_begin = 0, loop_end = 0` defines a
zero-length loop and every music layer stopped on the frame it started. And
`ConfigFile.get_value(section, key, null)` still raises when the key is absent,
which is the same trap as `get_meta(key, null)`.

The same stage fixed a pursuit defect: the contact estimate used to freeze when a
hub paused the world and ghost through the hub's backdrop, still displaying a
time that had stopped being true. It now withdraws on the pause notification
itself, because the frame that would have retracted it never arrives.

**Evidence:** `docs/evidence/2026-08-15-audio/`.

## v0.22 — Hardware, not pictures of hardware

**August 15, 2026**

Circuit Room's three switch plates had always been flat vector art: a beveled
block, four corner squares and a coloured bar, sitting in a room otherwise made
of painted stone, tarnished brass and real light. They read as placeholders, and
they were. They are now drawn in code as the hardware they represent — a
cast-iron backplate on four brass bolts, a brass bezel over a slate recess, two
porcelain insulator posts, and a hinged blade that swings down into its contact
jaw. Drawing rather than blitting is what earns the important part: throwing a
switch now *moves* something. Open and closed used to be two tints of the same
image.

One detail is worth keeping. The blade's open angle is not a constant — it is
derived from how much headroom the plate actually has, which is why it resolves
to −21.6° on the 64×48 plates and −29.2° on the taller master plate. A
hard-coded angle looked correct on the plate it was tuned against and swung
straight out through the bezel on the others.

The same pass moved the Guardian's start corner off the map border. It had been
sitting in the dead strip behind the painted hall, and the reason it survived
review is instructive: the hall's real walls are collision polygons rather than
solid grid cells, so the walkability check happily reported the outermost border
as open floor and the "nearest walkable cell" resolver had nothing to push
against. The corner is now chosen by scanning for a cell that is free on every
collision layer and inset from the border, and the inset is asserted.

**Evidence:** `docs/evidence/2026-08-15-switch-hardware/`.

## Reflection

The main lesson from this project is that a feature is only useful when its information is legible to the player. The major revisions repeatedly made hidden game state visible: fog became wall-aware, dialogue paused danger, locks required learned clues, objectives and notes stayed accessible, and character art was revised from an unsuitable realistic concept to small readable pixel sprites that match the player and rooms. The final redesign added a related lesson: a detective game should let the player revise a theory without punishing experimentation, while still making the difference between an executor and the author of a crime meaningful.
