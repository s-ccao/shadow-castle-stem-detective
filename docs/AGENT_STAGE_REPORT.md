# Agent stage report

> **Purpose:** Shared mailbox from the implementation agent to the GitHub/Codex maintainer. This report contains no credentials and is not authorization to publish automatically.

## Stage: UX-20261021-73 (phase 3: mechanic loops, HD captures in both languages, a demo case, platform groundwork)

- **Date:** 2026-10-27
- **Status:** phase 3 of the approved website plan. Four commits and the docs commits on branch `agents/site-game-hall`, on top of stage 72, not pushed. **In production** since 2026-10-27 after the user's approval ("可以上线"); see Production below. Concept key art waits for the user's original image files.
- **User input this stage:** replies in Chinese. The user could not open the preview or the linked files, so the site now runs locally (`tools/serve_site.py`) in VS Code's built-in browser, and the key-art prompts sit in `~/Desktop/shadow-castle-key-art/` as one ready-to-paste file per game with the style reference and Chinese instructions. Chosen HD captures: sheet numbers 3, 5, 8, 9 and 12. Keep the magnifier cursor. The user will generate the key art. Start phase 3.

### What changed (`web/landing`, `web/README.md`, `tools/site_build.py`, `tools/check_site.py`, `.github/workflows/site.yml`; no Godot file)

- **C7 `5f5872a` mechanic vignettes:** `js/vignettes/stage.js` runs short canvas loops of each upcoming game's core verb. It uses the one shared animation loop, caps device pixels by a pixel budget, pauses off screen and in hidden tabs, and draws a single still frame under reduced motion; every scene is a pure function of loop progress. The six scenes (4.1–5.7 KB each, loaded on demand):
  - Evidence Rush: cards land, threads link evidence to statements, a "≠" seal marks the contradiction, the board lights.
  - Prism Lab: two mirrors turn into line, a prism's spectrum wakes a lock.
  - Echo Corridor: a pulse reveals the maze and the guard turns towards it.
  - Time Echo: record, rewind, and a violet echo holds the plate.
  - Alchemy Shift: two liquids turn elixir green, the order ticks off and the combo bursts.
  - Rune Defense: runes are set, shadows march, a chain of bursts holds the gate.

  They play on card hover (or the touch Preview button), on the library stage, and in a lens in each case page's hero. Catalogue field `media.vignette`, checked by `check_site.py`. Also fixes card previews that kept playing after the pointer left for empty space.
- **C8 `e38ea00` HD captures:** the five frames the user picked (Final Archive, Library, Chemistry Room, Circuit Room, Dining Hall), English and Chinese, as WebP at 1024 and 640 wide under `assets/games/shadow-castle/` (35–109 KB each, 1.39 MB in all).
  - They replace the old stills in the hub's featured block, the card preview and the library, take over the Circuit Room figure, and fill a new "Walk the castle" gallery on the Shadow Castle page.
  - Stills accept `{en, zh}` sources; `data-zh-src`/`data-zh-srcset` swap before the dictionary loads, so a Chinese visit fetches only Chinese captures.
  - Story pages can now use build regions. Room names follow `autoload/case_locale.gd`; provenance is in `src/art/manifest.json`.
- **C9 `bb2655a` demo deduction board:** "The Observatory Lens" (`data/demo-case.json`), an original case with a Clockmaker, a Cook and an Archivist and none of the main game's characters.
  - Input: drag with a mouse, pick-then-place on touch, Enter/Space/Escape on the keyboard.
  - HUD: a 60-second clock that starts on the first move and pauses in hidden tabs, plus link and contradiction counts; a live region reports each result.
  - Solving lights the board and offers Shadow Castle and the Evidence Rush case file; time-out gives a hint and a retry. It is labelled a demo throughout.
  - The module (15.0 KB), its CSS and data load only as the section nears the viewport.
- **C10 `7bff43e` platform groundwork:**
  - A `/games` status filter, kept in `?status=` and hidden without JavaScript.
  - Generated `sitemap.xml` and `robots.txt`, and schema.org VideoGame data for playable games only.
  - `data/games.schema.json`, including the reserved embed, scores and leaderboard fields. Both catalogues validate against it, and a play link on an unreleased game is rejected.
  - `check_site.py` now checks the sitemap and the structured data, and `.github/workflows/site.yml` runs it on pushes that touch the site.
  - `web/README.md` documents per-language screenshots, vignettes, the demo, and the planned `/play/<slug>`, score messages and Investigator-ID leaderboards.
- **Docs commit:** this report, the website note in `docs/AGENT_HANDOFF.md`, `web/landing/DESIGN.md`, `.hallmark/log.json`, evidence images.

### Verification

- **`python3 tools/check_site.py`:** 11 pages, 268 translation keys, 0 errors, 0 warnings.
- **Godot:** the headless editor parse (isolated HOME) exits 0 with no errors. `git diff --check` is clean.
- **`tools/check_static.py` and `tools/check_translations.py`** exit 1 with the same pre-existing findings as stage 72 (`**` in `tools/generate_minigame_answers.gd`; one Chemistry key's line breaks). This branch changes no game file.
- **Browser matrix:** 11 pages × 320–1440 px × English/Chinese, 132 runs. The only findings are the intended 404 status of a missing page. Reduced motion: 20 runs, clean.
- **Behaviour:**
  - Vignettes draw on hover, Preview, the library stage and the lens; they stop when the pointer leaves and hold one still frame under reduced motion.
  - Captures follow the language, including in the open library; a Chinese visit requests no English capture.
  - The demo passes these paths: a consistent link, an unrelated link, drag to solve, keyboard only, the 10-second warning, time-out, reset, and tap-tap on a phone in Chinese.
  - The archive filter works, including deep links.
- **Frame time:** p95 16.7–16.8 ms on the hub, a card vignette, the library stage and a case lens, also at 4× CPU slowdown.
- **Weight:**
  - Vignettes: the 6.3 KB runner plus one 4.1–5.7 KB scene per game shown.
  - Demo: 15.0 KB JavaScript, 8.3 KB CSS and 3.3 KB data, all lazy.
  - Archive filter: 1.5 KB.
  - JavaScript loaded on every page grew by 1.5 KB (`main.js`, `i18n.js`); the lazy card and library modules grew by 0.9 and 1.4 KB.
- **Preview:** `shadow-castle-detective-site-roanqqp2g-cyc4.vercel.app` (Vercel login required). `vercel curl` confirms the sitemap, the vignette runner, the demo data, a Chinese capture and a case page.
- **Evidence:** `docs/evidence/2026-10-27-site-stage73/` (card vignette, library stage, case lens, solved demo, phone demo, featured block, gallery, archive filter, the six vignette stills).

### Production

- **Deployed:** `npx vercel deploy --prod` from `web/landing` at `6609f95` → `shadow-castle-detective-site-8pbu2ake0-cyc4.vercel.app`, now behind `shadowcastledetective.com`.
- **Verified live:**
  - 18 key files (pages, sitemap, robots, catalogue, dictionary, demo data, scripts, styles, a Chinese capture, the hero painting) are byte-identical to the branch.
  - `/assets/*` carries the one-year immutable cache, and a missing page answers 404 with the case-file page.
  - `/api/community` answers JSON, and the community page renders the live discussion.
  - In headless Chrome the hub, the Chinese Shadow Castle page and the community page load with no console error, and `/#science-title` forwards to `/games/shadow-castle#science-title`.
- **Rollback target:** the previous production deployment `shadow-castle-detective-site-8l8dy9d7f-cyc4.vercel.app` (`dpl_DstPBHSyuHK52pUfZdYE8znDsJnV`, 2026-09-16): `cd web/landing && npx vercel rollback shadow-castle-detective-site-8l8dy9d7f-cyc4.vercel.app`.
- **Branch caution:** production now serves the unpushed branch `agents/site-game-hall`. Until it is merged, a website deploy from `main` would bring back the old single-game page.

### Risks / follow-up

- Concept key art is outstanding: the user generated six images but shared only a 793 × 768 screenshot of them, too small to ship; the originals are needed. Until then the six games show their mechanic loops and emblems.
- Draft copy still awaits the user's review (hub title and lead, taglines, the English premises, the demo case); the user can now see it locally.
- Captures 3 (Chemistry Room) and 5 (Circuit Room) keep the in-game "Press E…" prompts, as chosen.
- Screenshots ship as WebP only. Every browser that renders the site's CSS baseline (`color-mix`, `:has`, `<dialog>`) decodes WebP, so the planned JPEG fallback was dropped.
- CSS remains over the plan's 30 KB (stage 72); the demo's CSS is lazy.
- The preview needs a Vercel login, and this machine's network filter blocks the live and preview hosts.

### Proposed next stage

- C8b: concept key art once generated. Make a contact sheet for the user's choice, then 16:9, 16:10 and 1200 × 630 crops, a visible "Concept art" label and provenance.
- After the user reviews the preview: `npx vercel --prod` from `web/landing`, verify the live files and record the previous production deployment for rollback.

## Stage: UX-20261021-72 (the website becomes a case archive: hub, seven case files, library and effects)

- **Date:** 2026-10-27
- **Status:** phase 2 of the approved website plan. Seven commits on branch `agents/site-game-hall`, not pushed. A Vercel **preview** is deployed; production (shadowcastledetective.com) is unchanged until the user approves it.
- **Request:** "把 Shadow Castle 从单款游戏展示页升级为具有高品质动画效果和多游戏入口的游戏平台", with stellarascensiongame.com as the reference. In English: turn the single-game page into a games platform with high-quality motion and an entrance for several games; borrow the reference's interaction mechanics (game library, animated hero, scroll storytelling, game cards, previews, HUD) without copying its code, art, video, copy or brand; keep the game, Research, Community, the development record and every link; English and Chinese; desktop and mobile; reduced motion; a data-driven catalogue in which the six unfinished games are Coming soon with no play link; one commit per stage; a preview before production.
- **Reference study:** the reference's public HTML, CSS and JavaScript were read only to name its mechanics (notes kept in the session, not in the repository). No code, asset, copy or palette was reused.

### What changed (`web/landing`, `web/README.md`, `tools/site_*.py`, `tools/check_site.py`; no Godot file)

- **C1 `c8bef94` shared shell:** new tokens (moonlight, bronze, night sky, glass, one accent per game, IBM Plex Mono, CJK fallbacks, the missing `--color-ink-3`); `css/site.css` with the N10 navigation, Ft5 footer, buttons in all eight states and status stamps; `js/loop.js` (one shared animation loop), `prefs.js` (system reduced motion or the site's Animations switch), `i18n.js` (English in the HTML, Chinese from `i18n/zh.json`), `nav.js`. The community page moved onto the shared shell. `tools/site_build.py` (generator), `tools/check_site.py` (checks), `tools/serve_site.py` (local server routed like Vercel), `DESIGN.md`, `.vercelignore`.
- **C2 `ba7e8c6` structure:** the hub at `/`; the previous home page word for word at `/games/shadow-castle`, its old anchors forwarded there; the catalogue `src/games.json` (Shadow Castle plus the user's six games, both languages; planning notes stripped from the published `data/games.json`); seven generated case pages, the `/games` archive, a case-file 404, original line emblems, case cards.
- **C3 `92c21c2` the hub's castle:** a layered vector night scene drawn in code, one window per game (Shadow Castle's lamp lit, six dim candles, a label on hover), a pointer lantern that reveals chalk clues, fog from a generated texture, light rain, rare soft lightning, parallax; portrait screens put the castle above the copy. The Shadow Castle page gets rain, fog and moonlight over its painting.
- **C4 `6fb225d` scroll storytelling:** rises, a brass heading glint, photographs that develop like prints, the true figures counting up, a reading thread, and a thread that lights each development milestone.
- **C5 `58770ce` pointer layer:** a brass magnifier cursor that frames what it can open, magnetic primary buttons, ember sparks, tilting cards. The native cursor returns for text entry, touch, forced colours, reduced motion and on any error.
- **C6 `f12527e` the case-file library:** a modal dialog over every page from the navigation (with a count), a dock, the castle windows and `#cases` deep links; the stage glides between accents and inks each name in; keyboard, touch and Back all work; nothing auto-advances; card previews on hover or a Preview button on touch.
- **Docs commit:** `web/README.md` → "The website", the website note in `docs/AGENT_HANDOFF.md`, this report, `.hallmark/log.json`, the key-art brief, prompts and manifest in `web/landing/src/art/` (not deployed), evidence images, and `.vercelignore` repeating `.env*` (it replaces the CLI's `.gitignore` fallback).
- **Copy:** new hub and archive copy is a draft for the user's review. The six games' texts are the user's Chinese, translated to English; development difficulty and planning notes are not published. Chinese uses the game's own terms (林女士, 守卫, 眩晕, 隐身, 净化).

### Verification

- **`python3 tools/check_site.py`:** 11 pages, 229 translation keys, 0 errors, 0 warnings; `site_build.py --check` reports nothing stale.
- **Godot:** the headless editor parse (isolated HOME `.godot/site-check/home`) exits 0 with no errors, before and after the stage. `git diff --check` is clean for the branch.
- **`tools/check_static.py` and `tools/check_translations.py`** exit 1 with output byte-identical to `main` (`d17d359`): pre-existing and outside this stage (Markdown `**` in `tools/generate_minigame_answers.gd`; one Chemistry-key translation whose line breaks differ).
- **Browser:** headless Chrome at 320, 375, 414, 768, 1024 and 1440 px in English and Chinese (a session-only playwright-core harness against `tools/serve_site.py`). Hub, archive, every case page, community and 404: no horizontal overflow, no wrapped buttons or links, no broken images, no console errors or failed requests. Reduced motion (system emulation and the site switch) is clean.
- **Behaviour:** `/#science-title` forwards to `/games/shadow-castle#science-title`; the library opens from the keyboard onto its case, Up/Down/Home/End browse, Esc returns focus to the opener, a castle window opens its own case, Back closes, a `#cases` link on a case page opens that case, the first tap on touch selects, and the phone sheet scrolls with every row at full height. A scroll-through leaves nothing hidden, every photograph developed, the counters on 8 / 5 / 22, and all milestone seals lit.
- **Frame time** (headless Chrome, every effect on, 2.5 s): 1440 × 900 median 16.7 ms, p95 16.8 ms; 375 × 812 median 16.7 ms with one 117 ms spike at start.
- **Weight:** shared JS on every page 16.7 KB (plan ≤ 45 KB); the hub with its lazy modules about 47 KB raw, 15 KB gzip; new CSS about 73 KB raw, 18 KB gzip, over the planned 30 KB raw.
- **Preview:** `shadow-castle-detective-site-j878xidnp-cyc4.vercel.app` (Vercel login required). This machine's network filter blocks the live and preview hosts, so the community feed was not checked there.
- **HD screenshots for phase 3:** the repository's own native capture scripts (`tools/blender/capture_*.gd`) ran in English and Chinese, every run exit 0 with no script error, every room's checks passing (Wake Room PASS; Chemistry 102; Circuit Room 111; Library 141; Final Room 114; Greenhouse 114; Dining Hall 129). The captures are staged outside the repository for the user's choice.
- **Evidence:** `docs/evidence/2026-10-27-site-stage72/` (hub in English and Chinese, a window label under the lantern, the upcoming cards, the library on desktop and phone, a case page, the Shadow Castle page, the archive in Chinese).

### Risks / follow-up

- The preview needs a Vercel login, and this machine cannot open either host; review on another network or device.
- The hub replaces the old home page. Canonical and Open Graph tags are updated; Chinese is client-side, so crawlers index English; old anchors other than `#top` and `#case-brief` are forwarded by a script.
- New CSS exceeds the planned budget (73 KB raw, 18 KB gzip).
- Draft copy awaits review: the hub's title and lead, the six taglines, the English translations of the six premises.
- The custom cursor replaces the system cursor on mouse devices (with the exits above); it can be dropped on its own if unwanted.
- Phase 3 needs the user's key art (prompts in `web/landing/src/art/prompts.md`) and a choice of HD screenshots.

### Proposed next stage (UX-20261021-73, phase 3)

- C7: six mechanic animations (Canvas) for the cards, the library stage and the case pages.
- C8: key art once generated, the chosen HD screenshots in both languages, provenance records.
- C9: the deduction-board demo with its HUD on the hub.
- C10: an archive filter, `sitemap.xml`, structured data, `games.schema.json`, the reserved score and leaderboard notes, and an optional site CI job.

## Stage: UX-20261021-71 (the detective stops at the Library's door, and the Chemistry near-miss CG in HD)

- **Date:** 2026-10-26
- **Status:** deployed to play.shadowcastledetective.com, together with stage 70, at the user's request ("部署到网站，并提交推送到 GitHub"). Committed and pushed with this report.
- **Request:** "现在你来帮我把一些我游戏的bug修复一下，1比如说libary的玩家问什么可以走到大门的上面，而且final_room的lin的身材比例和顽疾完全不一样，而且，新手教程里面的玩家在进入chemsity_rooom的时候显示的动画，玩家差一点被抓住，用的是老的地图". In English: fix some bugs. Why can the player walk onto the Library's main door? Lin in the Final Room is proportioned quite unlike the player. And the tutorial's "almost caught" scene on entering Chemistry still uses the old map.
- **Context:** the user plays the website, which runs stage 69. Stage 70 answered the first two reports but was never deployed.

### What changed

- **Standing on the Library's door** (`scenes/floor_1/library_room.tscn`, `scripts/library_room.gd`):
  - **Cause:** stage 70's `GateThreshold` started at y 1020, where the door's leaves meet its steps. The walls on each side stop the feet at y 940, but the doorway between them stayed open down to 1020. The door is drawn there (its gable from y 921, its leaves to about 1015), and no depth hides anyone at the doorway, so the detective was drawn standing on the door. Stage 70's own `09-doorway` capture shows it.
  - **Fix:** the threshold now closes the doorway from the jambs' line, its top following the door's gable, (650, 940) → (716, 921) → (782, 940). The band from y 1020 down stays.
  - `EXIT_RECT` now starts at y 921 instead of 962, so the exit's 14 px contact band still reaches the detective there. The arrival spawn moves from y 930 to 910, clear of the gable.
  - **Now:** walking straight down at the door stops the feet at y 921.3, and on the gable's west slope at 932.8. The "return to the Castle Hall" prompt shows, and the door is drawn whole below him.
- **The Circuit Room's gate had the same opening** (`scenes/floor_1/circuit_room.tscn`, `scripts/circuit_room.gd`): its passage was open down to stage 70's threshold at y 1056, through the gate.
  - The threshold now closes it at the gate's top, y 936. The detective can step into the alcove between the jambs (the user chose this over stopping at the jambs' line, y 918), but not onto the gate.
  - `EXIT_RECT` starts there instead of 972. The spawn is y 910, just north of the alcove: the room's spawn check wants three open directions, which the alcove does not give.
  - Walking down stops the feet at y 936, with the prompt showing.
- **`tests/room_bounds_test.gd`** gains `DOORWAYS`. In the Library, the Dining Hall and the Circuit Room:
  - the deepest the feet reach between the jambs must not pass the line where the door begins;
  - some spot the detective can reach must lie within the exit's 14 px band.
  - **Red and green:** on stage 70's scenes the feet reach y 1016 in the Library (door at 940) and 1048 in the Circuit Room (gate at 936). With the fix they reach 936 and 928 on the 8 px lattice, and both exits are in reach, in both looks. The Dining Hall's door was already closed (968, door at 971).
- **Tools:** `capture_library.gd`'s arrival (724, 910) and doorway (724, 918) follow the new geometry. Its doorway shot used to stand the detective on the door at (724, 990). `room_circuit.py`'s comment names the new spawn.
- **Mrs. Lin: no change in this stage.** The website still draws stage 69's body: 155 × 88.5 px, with a head about as wide as the detective's chest. Stage 70 laid her at the cast's drawn height, 100 × 57.5 px beside a detective about 90 px tall, as long lying as he is tall. Measured at game scale, her head now matches his (`04-mrs-lin-scale-stage69-vs-70.jpg`). The website shows this once stage 70 is deployed.
- **The Chemistry near-miss CG in HD** (`scripts/chemistry_near_miss_cg.gd`):
  - **Cause:** the CG builds its zoomed shot from copies of the Hall's `BackgroundVisual` and `WallsVisual`, the painted floor and walls, and closes the doorway with a leaf cut from the painted walls. The HD Hall is a separate render laid over those, so the CG showed the old map, with the HD figures in it.
  - **Fix:** when the HD look is staged, the CG also copies the HD render, drawn above the painted art, and the HD Chemistry door, held at its open frame.
  - As the detective slips through, the door swings shut back through its 10 frames (`_swing_shut`) instead of the painted leaf sliding across.
  - The painted look keeps its doorway matte and sliding leaf. The HD figures in the CG are now drawn smooth, as in the game; they were nearest-filtered.
  - `tests/chemistry_entry_sequence_test.gd` gains 4 checks under `-- --hd` (25 in HD, 21 painted): the CG draws the HD render over the painted one, the HD door stands open and swings to frame 0, and no painted leaf is cut into the shot.
  - The HD render is opaque. The pale stone edge at the bottom of the shot is the render's own, as in the game.

### Verification

- **Godot:** the headless editor parse (isolated HOME) reports 0 errors. `git diff --check` is clean.
- **gdlint:** no new issues in the edited scripts and tests (`library_room.gd` and `circuit_room.gd` keep their 24 and 27 earlier ones). `tests/room_bounds_test.gd` is clean.
- **Full headless suites,** each under its own HOME, matching stage 70:
  - painted: 58 of 59 pass. `room_spatial_audit` fails only its 6 known Hall cases.
  - with HD on: 56 of 59 pass. The 3 failures are the known ones: `character_scale_profiles_test` (its 5 painted-size checks), `hd_look_test`'s 2 dormant-mode checks, and `room_spatial_audit`'s Hall cases.
  - No script or parse error in any log.
  - `chemistry_presentation_test`, `pause_menu_test` and `knowledge_plate_art_test` refuse a generic HOME; under their own (`.godot/chemistry-*`, `.godot/pause-menu-*`, `.godot/knowledge-art-*` with `KNOWLEDGE_ART_EVIDENCE`) they pass in both looks.
- **In game, HD, 1024 × 768** (`docs/evidence/2026-10-26-stage71-doors-cg/`):
  - `00-door-collision-overlay-before.jpg`: each room's south door with its collision and exit box, before the fix.
  - `01-doorways-and-mrs-lin.jpg`: after walking down into each doorway, the detective stands above the Library's door (centre and west slope) and in the Circuit Room's alcove, above its gate, with the prompt. Beside him, Mrs. Lin is as long as he is tall.
  - `02-near-miss-cg-hd.jpg` and `03-near-miss-door-open-shut.jpg`: the CG's approach, lunge and slam in HD, with the HD door open and then shut. The painted look is unchanged.
- **Web build** (exported under an isolated HOME whose export templates link to the installed ones):
  - `index.pck` is 92,360,712 B, under Vercel's 100 MB limit, 960 B more than stage 70's.
  - Loaded on its own (`--main-pack`, no project folder), the pack holds this stage: the CG's `HD_DOOR`, the Library's `EXIT_RECT` (622, 921, 204, 165) and gabled threshold, and the Circuit Room's `EXIT_RECT` (640, 936, 168, 150) and threshold at 936. Scripts ship as compressed tokens, so a text search of the pack finds none of them.
  - From a local server, in headless Chrome: the title in 2.3 s; New Case into the HD Wake Room; 60 fps on the title and in the room; no console errors.
- **Deployment:** `shadow-castle-detective-play-4ewaak7hn-cyc4.vercel.app` → https://play.shadowcastledetective.com.
  - The ETags of `index.html`, `index.js`, `index.wasm`, `index.pck` and the service worker equal the local MD5s, and the sizes match.
  - The service worker's cache is `1793083394|3599348`, so a browser holding the old build is offered the update.
- **Rollback target:** `shadow-castle-detective-play-ixcl1bnrm-cyc4.vercel.app` (stage 69).

### Risks / follow-up

- **The CG frame** shows the HD render and the Chemistry door, but no Hall exhibits, as before. The Greenhouse exhibit's top 31 px would fall at the frame's bottom edge.
- **Web frame rate:** measured in the Wake Room only, as in stage 70.

## Stage: UX-20261021-70 (no walking out of the Library, and Mrs. Lin at the cast's size)

- **Date:** 2026-10-26
- **Status:** implemented and checked locally; deployed, committed and pushed with stage 71.
- **Request:** "还有一些小bug,比如说libary 的玩家可以走到大门的外面，或者什么的，而且final_room里面的lin的身材太大了，和玩家以及其他人的完全不一样，需要修改". In English: there are some small bugs, for example the player can walk out past the Library's main door; and Lin in the Final Room is far too big, quite unlike the player and everyone else.
- **Interrupted once:** the machine restarted during the Final Room render, which also cleared the scratch files under `/tmp`. Everything was re-run after the restart.

### What changed

- **The Library's way out** (`scenes/floor_1/library_room.tscn`):
  - **Cause:** the room's two south walls only flank the doorway. Below them nothing closed the floor, so the detective could walk down the gate's steps, off the bottom of the room, and along the outside of the south wall.
  - **Measured from the arrival spot on a 4 px lattice:** 105,865 reachable spots, 37,775 of them south of y 1020, outside the room.
  - **Fix:** a new `RoomCollisions/GateThreshold` closes the whole width from y 1020 down, where the gate's door leaves meet its steps.
  - **Now:** the reachable floor ends at the threshold (y 1016) and none of it lies outside the room. The exit box is still reached from 308 spots. Holding down, down-left or down-right in the doorway stops the detective at y 1020 with the "return to the Castle Hall" prompt showing.
- **The Circuit Room had the same opening** (`scenes/floor_1/circuit_room.tscn`), found by the new test below. Its `GateThreshold` starts at y 1056, the foot of the lightning door, inside its exit box.
- **New `tests/room_bounds_test.gd`:**
  - It flood-fills, in the Hall and all seven rooms, the floor the detective's body can reach from where it arrives, on an 8 px lattice smaller than the 14 × 8 px body. It fails on any spot outside the room, meaning the follow camera's limits, or one screen for the Wake Room.
  - It has 16 checks and takes about 5 s.
  - **Red and green:** on the old scenes it fails the Library (1,254 of 12,215 spots outside) and the Circuit Room (1,247 of 10,782). With the fix, both looks pass 16 of 16.
- **Mrs. Lin's size** (`tools/blender/room_final.py`):
  - **Cause:** she was laid at real length, 140 cm, the cast's standing height. The camera shortens a standing figure to 140 × sin 40° = 90 px, but a body lying across the view shows its whole length. So she was drawn 155 × 88.5 px beside a 90 px detective (the cast stand 91–92 px), with a head as wide as his chest.
  - **Fix:** she is laid at the cast's drawn height, her model scaled by sin 40° (0.643), so lying she is as long as the detective is tall. Her pose and her floor centre (346, 611) are unchanged. The torn violet cuff in her hand shrinks with her.
  - **Footprint:** her HD footprint shrinks to her own extent, 299–393 × 588–624, from 272–420 × 576–630.
  - **Re-render:** the room was rendered again (88 s at 128 samples), so the shadow she throws on the flagstones matches her. She is now drawn 100 × 57.5 px.
  - **Published:** `publish_hd.py` changed only the Final Room's 8 files: the room render, the five prop images (re-rendered with the room) and its two JSON files. The depth map, the other rooms, the figures, the portraits and the maps are byte-identical.
  - `tools/blender/capture_final.gd`: her stand point moves from (346, 645) to (346, 639), because her box now ends at y 622 instead of 627.5 and the room offers an item within 14 px of its box.
- **Two Chinese labels** (`scripts/case_script_zh.gd`):
  - "Mrs. Lin's body" and "Mrs. Lin's notebook" had no entry, so the Chinese prompt read "按 E 查看Mrs. Lin's body". They are now "林女士的遗体" and "林女士的笔记本", the name the Final Room's Chinese text uses for her.
  - Checking every room's interaction labels against the table found no other gap the player sees. The Circuit Room's switch specs carry labels nothing shows, and the Mechanic's prompt has its own translation.

### Verification

- **Full headless suites,** each under its own HOME:
  - painted: 58 of 59 pass. `room_spatial_audit` fails only its 6 known Hall cases.
  - with HD on: 56 of 59 pass, with the same three as stage 69 failing: `character_scale_profiles_test` (its 5 painted-size checks), `hd_look_test`'s two dormant-mode checks, and `room_spatial_audit`'s Hall cases.
  - `room_bounds_test`, `library_knowledge_access_test`, `interaction_stops_walk_test` and `hall_route_authoring_test` pass in both looks.
- **Captures, EN and ZH:** all ten pass, 1,056 checks per language and 2,112 in all, every run with its summary line and no script error.
  - The Final Room's 114 include Mrs. Lin: her footprint blocks the floor where she lies, and standing at (346, 639) offers her, in both looks.
  - The Library's 141 include the doorway shot: the detective at the door, with the way-out prompt.
- **In game,** at 1024 × 768 (shots not committed):
  - beside the detective, the re-rendered Mrs. Lin is as long as he is tall, and her shadow fits her;
  - the Chinese prompt reads "按 E 查看林女士的遗体".
- **Godot and lint:** the headless editor parse (and import) reports 0 errors. gdlint is clean on `tests/room_bounds_test.gd` and `tools/blender/capture_final.gd`, pyflakes on `room_final.py`, and `git diff --check` is clean.
- **Web build** (exported locally, not deployed):
  - `index.pck` is 92,359,752 B, under Vercel's 100 MB limit.
  - Against the live stage 69 pack it holds the same 1,030 files, none from `prototypes/`. Only 11 differ: the Library and Circuit Room scenes, the Final Room's six textures and two JSON files, and `case_script_zh`.
  - Booted in headless Chrome from a local server, it reaches the title in 6.5 s. The HD Wake Room runs at 60 fps standing and walking, with no console errors.

### Risks / follow-up

- **The painted body** is still 123 × 82 px. It only shows when the HD look is off; the game and the website always draw HD.
- **`character_scale_profiles_test`** still fails with HD on, by design. It asserts the painted body's 140 × 70 px collision, and the HD footprint is now 94 × 36.
- **The Library's `EXIT_POSITION` (724, 1030)** now lies inside the threshold. The room only uses it to build an exit box when none is given, and it gives `EXIT_RECT`.
- **Next:** deploy and commit.

## Stage: UX-20261021-69 (stage 68's two known HD issues fixed)

- **Date:** 2026-10-26
- **Status:** deployed to play.shadowcastledetective.com at the user's request ("重新部署网站，并提交推送"). Committed and pushed with this report.
- **Request:** "修复这两个已知问题" (fix the two known issues), after stage 68's commit and push.

### What changed

- **The Hall could freeze with the HD look** (`scripts/hd/hd_depth.gd`):
  - **Cause:** the depth pass kept every sprite it had ever tracked as a key of `entries`. That included the footprints, which are freed and laid again with every new trail. GDScript walks a Dictionary by looking up the key it is on, so when a new sprite took a freed one's memory, the lookup could land on the old key and the loop went round for ever. The game stopped drawing, at full CPU.
  - **Found with temporary tracing:** the frame stuck in `HDLook._process`, then in `hd_hall.advance`, then in `depth.advance`'s loop over `entries`. One pass over 288 entries made more than 20,000 visits.
  - **Seen in:** `hall_route_authoring_test` with HD on, in about half of the runs. Normal play lays the trail again too: after leaving it, and at each step of the arrival.
  - **Fix:** `entries` is keyed by the sprite's instance id, which is never reused, and each entry holds its sprite. `advance` walks a copy of the keys and drops entries whose sprite was freed; `restore` walks the values.
- **The same hazard in the figures** (`scripts/hd/hd_characters.gd`): `swaps` was keyed by the game's sprites and walked every physics tick, and a Guardian can be freed and another staged. It is keyed by instance id now, with the sprite in each entry. `figure_of`, `gait_of`, `cycles_of` and `staged` are unchanged for their callers.
- **The lens-scroll's box** (`scripts/library_room.gd`): `recipe_vision_scroll`'s `interaction_rect` is 66 px tall instead of 76, so it ends at the atlas case's front (y 508) rather than on the floor in front of the violet reflection cabinet.
  - Before, it ran to y 518. In HD the cabinet's box starts at y 517, lifted 1 px by the flame of the candle on its top, so the two boxes shared a 25.5 × 1 px strip. Painted, they were 0.33 px apart.
  - The scroll is listed first, so on the floor north of the cabinet it took the cabinet's prompt.
  - Now the gap is 9 px in HD and 10.3 px painted. The scroll is still offered from the rug and the atlas case's front.
- **`tests/interaction_stops_walk_test.gd`:** before its walk it waits, up to 8 s, for the room to let the detective walk.
  - The HD Library holds the detective during its establishing shot on its first load, so the walk never started ("was walking: false"). The rule under test was not broken.
- **`tests/hd_look_test.gd`:** two new checks, 37 in all. 64 footprint sprites are tracked and freed, and a stand-in Guardian is staged and freed. Neither the depth pass nor the figures may keep an entry for a freed sprite.

### The website

- **Deployment:** `shadow-castle-detective-play-ixcl1bnrm-cyc4.vercel.app` → https://play.shadowcastledetective.com.
  - `index.pck` is 92,337,272 B, SHA-256 `9dd06d0c…`, identical live and local.
  - The ETags of `index.html`, `index.js`, `index.wasm`, `index.pck` and the service worker equal the local MD5s.
  - The service-worker cache is `1793002165|5145394` (was `1792996368|4961264`), so a browser holding stage 68's build shows "A new game update is ready".
- **Rollback target:** `shadow-castle-detective-play-j3y5kdxda-cyc4.vercel.app` (stage 68).
- **Before deploying:**
  - The new pack's directory differs from the live one only in `scripts/hd/hd_characters.gdc`, `scripts/hd/hd_depth.gdc` and `scripts/library_room.gdc`: same 1,030 files, none from `prototypes/`.
  - The pack check matches stage 68's: 28 scenes load, all 147 HD images are present, and the only missing literal path is the known `scripts/wall_collision_data.gd` fallback.
  - The build was booted in headless Chrome on the Apple M3 GPU (ANGLE Metal) from a local server: no console errors and 5.9 s to the title. In the HD Wake Room it ran at 60 fps, both standing and walking (median and 95th percentile 16.7 ms, worst 16.8 ms), with a 123 MB JS heap. That is the web frame rate stage 68 could not measure, for the Wake Room.

### Verification

- **The hang:** `hall_route_authoring_test -- --hd` passed 20 of 20 runs, each in 8–10 s with 60 checks. Before the fix, today's runs hung in the first or second run of each batch and were killed at 90 s.
- **Red and green:** with stage 68's `hd_depth.gd` and `hd_characters.gd`, the new `hd_look_test` check hangs (killed at 120 s after 13 checks). With the fix, `hd_look_test` passes 37 of 37.
- **The Library:**

  | Test | Painted | HD |
  | --- | --- | --- |
  | `library_knowledge_access_test` | 65 of 65 (`lower_storage` 122 spots, was 115) | 65 of 65 (106 spots, was 99 and failed) |
  | `interaction_stops_walk_test` | 16 of 16 | 16 of 16 |
- **In game,** with HD at 1024 × 768 (shots not committed):
  - beside the atlas case, the lens-scroll is offered;
  - at (334.5, 537), north of the cabinet, the violet reflection cabinet is offered; the scroll was, before.
- **Full headless suites** (each under its own HOME):
  - painted: 57 of 58 pass. `room_spatial_audit` fails only its 6 known Hall cases.
  - with HD on: 55 of 58 pass, up from 52. `hall_route_authoring_test`, `library_knowledge_access_test` and `interaction_stops_walk_test` now pass. The three that still fail assert the painted game or are known:
    - `character_scale_profiles_test`: its 5 checks of the painted figure sizes, as in stage 68;
    - `hd_look_test`'s two dormant-mode checks, which only hold without `--hd`;
    - `room_spatial_audit`'s 6 Hall cases.
- **Captures, EN and ZH:** all ten pass, 1,056 checks per language and 2,112 in all, as in stage 68.
  - Four runs were cut short with no failure: their windows were closed from outside, so they ended with code 0 and no summary line. They were Chemistry EN, Library EN and both Dining Hall runs, and their re-runs passed in full (102, 141, 129 and 129).
- **Godot and lint:**
  - the headless editor parse reports 0 script errors;
  - gdlint is clean on `hd_depth.gd`, `hd_characters.gd` and both tests. `library_room.gd` has its 24 earlier problems and no new one;
  - `git diff --check` is clean.

### Risks / follow-up

- **Bugs the user reported next, not fixed in this stage:**
  - the player can walk out past the Library's main door;
  - Dr. Lin is far too big in the Final Room, beside the detective and the cast.
- **The approach-area test is sensitive to small shifts:** it samples a 10 px grid anchored to the shelf's box, so a 1 px shift in a box moves a whole row (14 spots). HD now has 106 spots against a threshold of 100.
- **The Library's other object-keyed records:** `hd_library.gd`'s `stand_parts` and `marker_positions` still use objects as keys. Neither is ever iterated, and their nodes live as long as the room.
- **Web frame rate:** measured only in the Wake Room. The Hall and the larger rooms are not measured yet.
- **Next:** the two reported bugs.

## Stage: UX-20261021-68 (the HD look in the game, on the website)

- **Date:** 2026-10-25
- **Status:** deployed to play.shadowcastledetective.com at the user's request. The user approved commit and push: committed as `726a934` and pushed to `origin/main`.
- **Requests:**
  - "开始" (start): move every HD room, figure, portrait and map into the game, then sync the website (the user's plan from stage 66's review);
  - "现在只需要你同步到网站上并且把原来的贴图的哪一套给删掉" (only sync it to the website, and delete the old set of art);
  - "不一定要remove old 版本，我现在需要游玩网页版的是最新的版本" (the old version need not be removed: the website must play the latest version).

### What changed

- **Publishing** (`tools/blender/publish_hd.py`, new): copies what the game draws from the gitignored `prototypes/` into `assets/hd/` (hall, rooms, characters, portraits, maps; 139 files, 18.9 MB on disk, about 17 MB in the pack).
  - Colour images go out as WebP and are imported lossy (0.85), as the painted backgrounds are, about a fifteenth of the PNG size. Depth maps stay lossless PNG, without alpha-border fixing, since they carry numbers.
  - Sheets, portraits and maps are imported with mipmaps.
  - The 36-frame idle sheets are laid out in bands of 18 columns, so no texture is wider than 4096 px.
  - Portraits go out at 224 px. The Circuit repair map is composited offline.
  - JSON image names are rewritten to the published files, and files no longer published are pruned.
  - Checked: every prop's and door's alpha is identical to the render's, and every frame of every sheet lands where the game asks for it.
- **The HD look is the game's own** (`scripts/hd/`): the preview's modules, moved with `git mv` from `tools/blender/prototype_*.gd`:
  - `hd_room`, `hd_props`, `hd_depth`, `hd_glows`, `hd_doors`, `hd_characters`, `hd_maps`, `hd_portraits`, `hd_library`;
  - new: `hd_data.gd` (paths, and textures through Godot's importer, so it works on the web), `hd_hall.gd` (the Hall's staging, taken out of `play_prototype.gd`) and `hd_look.gd`.
  - `hd_look.gd` is the `HDLook` autoload. It stages the Hall and every room as they load, makes the portraits and the Map Hub's maps HD from the start, and lets go of a look once its scene leaves the tree.
  - A `--script` run (tests, captures, audits) keeps the painted game unless it passes `--hd` or calls `enable()`.
  - The cast's sheets load when an NPC first shows. The detective's and the Guardian's stay loaded for the session.
- **Faster prop boxes:** `RoomSpatialRuntime.opaque_rect_of` trims the native used rect to the 0.05 alpha threshold, with one cache for the session, and `RoomInteractionRuntime` uses it.
  - On 111 textures (88.6 Mpx) its result is identical to the old pixel-by-pixel scan, and it takes 0.3 s instead of 6.4 s.
  - Staging an area now takes 55–310 ms; the Library took 0.2 s more before.
- **Tools:**
  - `play_prototype.gd` now only turns `HDLook` on and jumps to a room.
  - The captures and audits read `assets/hd/` and still write their shots under `prototypes/`.
  - The NPC facing checks and the Hall capture's stride check count frames per facing, for the banded idles.
- **New test** `tests/hd_look_test.gd` (35 checks): dormant under `--script`; enabled, the portraits, maps, Hall and all seven rooms stage, and each look lets go of its scene.
- **The old art in the web pack:** the pack grew to 115.5 MB, and Vercel refuses a file over 100 MB.
  - `export_presets.cfg` now excludes 42 old images that no shipped script, scene or data names: the UUID-named and duplicate player sheets, old Hall wall and map versions, and old UI frames and buttons. That is 23.1 MB.
  - The files stay in the repository.
  - The painted art the game still loads under the HD look (scenes, prop boxes, the fallback) still ships.
- `project.godot`: the `HDLook` autoload.

### The website

- **Deployment:** `shadow-castle-detective-play-j3y5kdxda-cyc4.vercel.app` → https://play.shadowcastledetective.com.
  - `index.pck` is 92,336,552 B (was 98,455,556), SHA-256 `39b6a826…`, identical live and local.
  - The ETags of `index.html`, `index.js`, `index.wasm` and `index.pck` equal the local MD5s.
  - The service-worker cache is `1792996368|4961264` (was `1792958880|6394217`), so a browser holding the old build shows "A new game update is ready".
- **Rollback target:** `shadow-castle-detective-play-znzqamw4e-cyc4.vercel.app` (stage 65's build).
- **In a browser:**
  - the local build boots to the title, and a new case opens the HD Wake Room with no console errors;
  - the live site loads the new build (125.7 MB first load) and shows the HD Hall.

### Verification

- **Captures, EN and ZH**, on the published `assets/hd/` data: all ten pass with no script errors, 1,056 checks per language and 2,112 in all.

  | Capture | Checks |
  | --- | --- |
  | Wake | 65 |
  | Chemistry | 102 |
  | Greenhouse | 114 |
  | Circuit | 111 |
  | Final | 114 |
  | Maps | 24 |
  | Portraits | 80 |
  | Hall | 176 |
  | Library | 141 |
  | Dining | 129 |
- `tests/hd_look_test.gd`: 35 of 35.
- **Headless suites:**
  - painted: 55 of 56 pass; `room_spatial_audit` fails only its six known Hall cases;
  - with the HD look on (`-- --hd`): 52 pass. The rest are listed under Risks.
- **The exported pack**, loaded on its own (`--main-pack`):
  - all 28 scenes load;
  - every literal `res://` path the shipped code names is present, but for `scripts/wall_collision_data.gd`, a fallback removed in `4bb4254` that `game_world.gd` only warns about;
  - all 147 HD images its JSON names are present.
- **Godot and lint:**
  - the headless editor parse exits 0 with 0 script errors;
  - gdlint is clean on `scripts/hd/`, the captures and audits, `play_prototype.gd` and `tests/hd_look_test.gd`. `room_interaction_runtime.gd` keeps one over-long line from before, and this stage removes its other lint error;
  - pyflakes is clean on `publish_hd.py`;
  - `git diff --check` is clean.

### Risks / follow-up

- **An intermittent hang with the HD look on:** `hall_route_authoring_test` stops in 2 of 6 runs, in a developer-mode route-recording step after a cancelled recording. It never stops in painted runs. Bisected to the depth pass; not yet fixed. Normal play has not shown it. *Fixed in stage 69: it was the depth pass's Dictionary of freed footprint sprites, and normal play could hit it too.*
- **The HD Library's boxes:** with HD on, `library_knowledge_access_test` finds that `recipe_vision_scroll`'s box covers part of `lower_storage`'s approach area, and `interaction_stops_walk_test` fails in the Library. Both items are still offered (stage 66's audit), but the boxes need adjusting. *Fixed in stage 69; the walk test's Library failure was the establishing shot holding the detective.*
- **Tests that assert the painted look** fail with HD on, as expected: `character_scale_profiles_test` (the Hall's figures are drawn smaller in HD) and `hd_look_test`'s own dormant checks.
- **Web frame rate not measured:** the integrated browser's tab was hidden, so it throttled.
- **Committed:** `726a934` holds what is live, so `main` and the website match.
- **Next:** fix the depth-pass hang and the Library's boxes; measure the web frame rate on a visible tab; commit.

## Stage: UX-20261021-67 (the Dining Hall furnished)

- **Date:** 2026-10-25
- **Status:** approved by the user ("满意"; the heraldic trophy kept rather than a Tripo suit of armour), then committed and pushed at their request. Preview only: the game and the website are unchanged. Their choice for next: move every HD room, figure, portrait and map into the game and sync the website.
- **Request:** at stage 66's review the user chose to fill the Dining Hall, which at a real size is emptier than its painting, with some furniture ("加一些家具填满大厅（长凳、盔甲、边桌等）"), before the move into the game.

### What changed (`tools/blender/room_dining_hall.py`)

Every new piece is real-size against the 1.4 m detective, stands on floor the furniture left open, and keeps clear of every prompt's floor, the arrival, the way out and the boot prints:

- **A window seat under each window:** an oak bench 1 m long with turned legs, a stretcher and a velvet cushion, its seat 46 cm up, in front of the stone sill.
- **The hearth:** two of the hall's own chairs drawn up to the fire and turned in toward it, a low Gothic table between them (CC0 `gothic_coffee_table`, at 60 × 60 cm) with a pewter jug and a brass goblet on its tray.
- **A heraldic trophy** between the wall door and the clock: the worn kite shield (CC0 `kite_shield`) on an oak post on a stone plinth, two swords (CC0 `antique_estoc`) crossed behind it. This is the user's "盔甲" (armour): no CC0 suit of armour exists on Poly Haven.
- **An iron-bound chest** (CC0 `treasure_chest`, already in the manifest) in the south-west corner, its lock toward the room.
- **Two wine casks** (CC0 `wine_barrel_01`, already in the manifest) against the south wall in the east.
- **Two iron floor candelabra**, 1.6 m to the flames, either side of the way in from the main door, three candles each, with a pool of candlelight on the flagstones round each.
- **Footprints** for all of them in `"collision"`, as `RoomCollisions/HD*` polygons the preview adds while staged and frees on restore: `HDWindowBench0`/`1`, `HDFireside`, `HDTrophy`, `HDChest`, `HDCasks`, `HDCandelabrum0`/`1`.
- **`cc0_models.json`:** three models added with their authors, pages and SHA-256 (`gothic_coffee_table`, `kite_shield`, `antique_estoc`); `fetch_models.py` verifies every file.

### Capture (`tools/blender/capture_dining_hall.gd`, 129 checks, was 114)

- New `_furnishing_checks()`: in the HD look the player cannot stand inside any of the eight furnishings; in the painted room each spot is open floor again (but the trophy's, which the painted clock's collision covers).

### Exact files

- **Changed:** `tools/blender/room_dining_hall.py`, `tools/blender/capture_dining_hall.gd`, `tools/blender/cc0_models.json`; `docs/AGENT_STAGE_REPORT.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- **New:** `docs/evidence/2026-10-25-dining-furnishings/` (the painting beside the furnished hall, the hearth and trophy, the window seats, the south side, an in-game shot at the hearth).
- **Local only (gitignored):** the Dining Hall's render, captures and audits; the three new models under `prototypes/blender_rooms/models/`.

### Verification

- **Light** (`measure_room.py`, against the painting): luminance 1.09, warmth 1.11, floor spread 0.85, within the standard (stage 66: 1.08, 1.00, 0.72; the candelabra add warm light).
- **Captures, EN and ZH:** Dining Hall 129, Hall 176 and maps 24, all passing.
- **Audits:** every Dining Hall interaction is offered from reachable floor (table 852 cells, clock 333, sideboard 522, fireplace 157, wall door 83, dresser 1188, exit 7 as before); coverage: no painted art left (41 staged).
- **Godot and lint:** headless editor parse with 0 script errors; `capture_dining_hall.gd` parses alone and gdlint is clean; pyflakes is clean on `room_dining_hall.py`; `git diff --check` is clean.

### Risks / follow-up

- **The painting has none of these pieces.** They are the hall's own kind of furniture (its chairs, its oak, its candles) and CC0 period pieces, chosen to fill the open floor without crowding the routes.
- **Not a full suit of armour:** a heraldic trophy stands in for it; a suit would need a Tripo model.
- **Next:** the move of every HD room, figure, portrait and map into the game, and the deploy (the user's plan).

## Stage: UX-20261021-66 (the Library and the Dining Hall to the room standard)

- **Date:** 2026-10-25
- **Status:** approved by the user ("满意"), then committed and pushed at their request, with the Library's and the Dining Hall's own work (stages 57, 59 and 60). Preview only: the game and the website are unchanged.
- **Their choices for next:** fill the Dining Hall with some furniture (benches, armour, side tables), since at a real size it is emptier than the painting; then move every HD room, figure, portrait and map into the game and sync the website.
- **Request:** "现在开始" (start now), on the plan the user chose at stage 65's review: bring the Library and the Dining Hall to the room standard first, then move every HD room, figure, portrait and map into the game and sync the website.
- **Taken over with the user's leave (stage 65's review):** the Library session's stages 57 and 59 and the Dining Hall session's stage 60, never committed. Their files stay as they left them apart from the fixes below, and go into this stage's commit with it.

### What changed

- **The Library** (`tools/blender/room_library.py`):
  - **Wood:** the approved worn, waxed oak (`oak()` returns `room_chemistry.aged_oak()`), and its dark cases and gate each a part and shade of `wood_table` / `wood_table_worn` with worn rims (`room_chemistry.laid`), in place of `wake.oak()`, flat and grainless at 2x.
  - **Light:** `grade()` sets the exposure (−0.2, and +0.08 awakened) and a 6350 K white balance (`LIBRARY_EXPOSURE`, `LIBRARY_WHITE_BALANCE`, each overridable from the environment).
  - Both states re-rendered (203 s normal, 121 s awakened).
- **The Dining Hall** (`tools/blender/room_dining_hall.py`), its furniture at a real size against the 1.4 m detective:
  - **The banquet table** is 3.2 × 1.15 m and 76 cm high, on the painted table's middle (was 5.1 × 2.8 m and 53 cm).
    - `on_table()` lays the places, candles, wine, platter and spills out on the painted table and draws them in onto the real one, each plate clear of the table's frame. A plan check of every piece found none touching after three were nudged (a glass, the platter, the sauceboat).
    - Plates are 28 cm and glasses a real size; the two side plates are dropped, with no room left between the places.
    - Its eight chairs stand round it as the painting sets them, and the rug is sized to them as the painting's is (5.3 × 3.1 m, was 6.9 × 4.7 m).
  - **The clock** is 52 cm × 2.1 m, modelled at the painting's 86 cm × 3.6 m and scaled about its foot, its east side by the east wall.
  - **The sideboard** is 2.2 m × 60 cm and 87 cm high, back to the east wall (was 4.1 × 1.56 m, standing off it).
    - It has one cupboard door in its south end, and three drawers along its west side, the middle one pulled out with the silver.
    - `on_sideboard()` draws its load in, and the shelf's stands down the shelf's middle.
    - The pan is dropped for lack of room, and its entry removed from `cc0_models.json`.
    - The torn cloth lies 48 px on the top: laid 80 px on, it overhung the narrower top's west edge.
  - **The serving table** is 55 cm deep and 81 cm high (was 1.25 m deep), its load rearranged to fit.
  - **Footprints** (`footprints()`, in `"collision"`):
    - the table with its chairs, inside the painted footprint but for its north edge;
    - the clock;
    - the sideboard, plus `HDOpenDrawer` for its pulled-out drawer;
    - `RoomCollisions/RightWall`, its north-east notch drawn back to the serving table's depth.

    The table's end chairs are now in its prop, as its south ones were, so its prompt box (x 435–946) reaches the floor beyond them. Every HD front is within the walk-up rule's 7.5 px of its footprint.
  - **Floor:** the flagstones are a shade darker (value 1.7, was 2.45), with lighter joints (0.03–0.06, was 0.008–0.028) and narrower gaps (0.9, was 1.2).
  - **Hearth:**
    - the ember bed fills the firebox: coals 2–3 cm, each at its own heat between dark seams, deep red to orange, dying to ash at the bed's edge;
    - the logs are charred, glowing underneath and in a few thin cracks;
    - the flames are low orange licks, emission only, never white;
    - a warm light inside the firebox lights its back and sides, now smoked stone;
    - the fire's spill on the hearth rug is softened (36 W, was 48).

    Shader Object space is metres, so stage 60's coal and crack cells (7 mm and 1 cm) were below a pixel and averaged to a flat tan glow.
  - **Grade:** a 7400 K white balance (`DINING_EXPOSURE`, `DINING_WHITE_BALANCE`, `DINING_FLOOR_VALUE`, each overridable from the environment).
  - **Boot prints:** the trail from the table starts at the rug's edge, and the wall door's trail reaches toward the clock where it now stands.
- **Capture** (`tools/blender/capture_dining_hall.gd`, still 114 checks):
  - the table's stand is the floor behind its south chairs, (628, 690);
  - the sideboard takes an `hd_stand` beside its open drawer, (1296, 812), in the HD look, since no one spot reaches both the painted sideboard and the real one; a prop with its own HD stand is shot in each look from where it is used there;
  - the check north of the table names the chairs' backs that hide the player there.
- **New tool** `tools/blender/measure_room.py <room> <painting> [render]`: the room standard's three measures (Pillow and numpy).

### Measured (ratio to the painting; the standard asks about 1 ± 0.15 for light, a floor spread near the painting's or lower)

| Room | Luminance | Warmth | Floor spread |
|---|---|---|---|
| Library, before → after | 1.42 → **1.06** | 1.33 → **0.98** | 1.33 → **1.07** |
| Dining Hall, before → after | 1.09 → **1.08** | 0.84 → **1.00** | 1.22 → **0.72** |

### Exact files

- **Changed by this stage:**
  - `tools/blender/room_library.py`, `tools/blender/room_dining_hall.py`, `tools/blender/capture_dining_hall.gd`;
  - `tools/blender/cc0_models.json` (the pan removed);
  - `docs/AGENT_STAGE_REPORT.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- **New:**
  - `tools/blender/measure_room.py`;
  - `docs/evidence/2026-10-25-room-standard/`: painting, before and after for both rooms, the Library's wood, the Dining Hall's table, hearth and east side, two in-game HD shots, and `measurements.json`.
- **Committed with it, from the Library and Dining Hall sessions:**
  - new scripts: `tools/blender/prototype_library.gd`, `capture_library.gd` and `capture_dining_hall.gd` (each with its `.uid`), and `room_library.py` and `room_dining_hall.py`;
  - their hunks in `prototype_room.gd` (the `EXTRAS` living layer), `prototype_props.gd` and `room_prototype.py` (`"overhead"`), `export_room_layout.gd` (both rooms), `play_prototype.gd` (`--library`, `--library-ready`, `--dining`) and `cc0_models.json`;
  - their reports (stages 57, 59 and 60) and handoff notes;
  - `docs/evidence/2026-10-23-blender-library/` and `docs/evidence/2026-10-24-blender-dining-hall/`.
- **Local only (gitignored):** the two rooms' renders, captures and audits under `prototypes/blender_rooms/`.

### Verification

- **Captures, EN and ZH**, all passing:
  - Library 141 and Dining Hall 114;
  - every other area's: Wake 65, Chemistry 102, Greenhouse 114, Circuit 111, Final 114, maps 24, portraits 80 and Hall 176.
- **Audits:**
  - interactions: every Dining Hall item is offered from reachable floor (table 862 cells, clock 336, sideboard 522, fireplace 157, wall door 83, dresser 1188, exit 7 in the doorway's jamb as before), and every Library item is offered (the fewest, 72 cells);
  - coverage: no painted art is left in either room.
- **Measures:** as above (`measure_room.py`).
- **Godot and lint:**
  - the headless editor parse has 0 script errors;
  - gdlint is clean on `capture_dining_hall.gd`, `capture_library.gd` and `prototype_library.gd`;
  - pyflakes is clean on `room_library.py`, `room_dining_hall.py` and `measure_room.py`;
  - `git diff --check` is clean.

### Risks / follow-up

- **The Dining Hall is emptier:** at a real size its furniture leaves far more open floor in the 14 m hall than the painting's oversized pieces did. Everything the painting has is there and nothing was added; filling the hall (benches, a second table, armour) would be a new design choice.
- **The hearth** is an ember bed with low flames, nearer the painting than stage 60's tongues, but a still image of fire.
- **The user has not reviewed** the Library's stage 59, the Dining Hall's stage 60 or the Circuit Room's stage 55-circuit on their own.
- **Next:** furniture to fill the Dining Hall (the user's choice at this review), then the move of every HD room, figure, portrait and map into the game, and the deploy.

## Stage: UX-20261021-65 (web deploy; every room and map built in Blender)

- **Date:** 2026-10-25
- **Status:** approved by the user ("满意"), then committed and pushed at their request, with this stage's hunks and the Circuit Room's only (the Library's and the Dining Hall's work stays uncommitted for review). The website serves stage 63's game fixes (deployed at the user's request); everything else here is preview only. Their choice for next: bring the Library and the Dining Hall to the room standard first, then move everything into the game and sync the website.
- **Requests:**
  - "所有的更新都同步上传到网站了吗，检查是否所有的room都完成了重建" (are all updates on the website, and is every room rebuilt?);
  - at the review form: deploy the game's fixes now; take over the Library, the Dining Hall and the Circuit Room; and the note "优先修改其他的room，全部的小地图完成后再进行下一步" (the other rooms first; the next step once every map is done);
  - "检测是否所有的room和小地图都是用blender搭建的" (check that every room and map is built in Blender);
  - "如果是用blender搭建的话就直接同步到网页上，如果还有room没有用blender搭建，优先搭建那个room" (if they are, sync them to the website; build any that are not first).
- **Taken over with the user's leave:** the Circuit Room session's work (worktree `circuit-room-blender`, stages 54-circuit and 55-circuit, never committed) is merged into this checkout. The Library and Dining Hall sessions' work stays as they left it; their standard fixes are not made yet.

### The website

- **What was live:** play.shadowcastledetective.com served the 2026-10-21 export (stage 38): the four files' ETags equalled the local export's MD5s. Neither Vercel project is connected to Git, so stages 39–64 never reached it; two of them changed the game itself (stage 62: the Final Room's way back; stage 63: the Wake door click, the Greenhouse beds and plot, the gardener's spot).
- **The export would have shipped the preview:** `export_presets.cfg` excluded `tests/`, `tools/` and `docs/` but not `prototypes/`, whose rooms and characters (about 755 MB) Godot imports. The Web preset now excludes `prototypes/*` too.
- **The new build:** 846 files, as before. Its directory differs from the live one only in the four game scripts (`chemistry_room`, `final_room`, `greenhouse_room`, `wake_room`) and two caches whose entries are the same, reordered. 55 of 56 headless suites pass; `room_spatial_audit` fails only its six known Hall cases.
- **Browser test** (local server, then live): boots to the title; a new case reaches the Wake Room, and a click on the door from across the room walks the detective to it and opens its question (stage 63's fix), with no console errors.
- **Deployed:** `shadow-castle-detective-play-znzqamw4e-cyc4.vercel.app` → https://play.shadowcastledetective.com. Live sizes and MIME types are right, every ETag equals the local MD5, the live `index.pck` has the local SHA-256 (`71a2a45b…`), and the service worker's cache is `1792958880|6394217` (was `1792622131|5145128`). A browser holding the old build shows "A new game update is ready"; "Restart now" loads the new one and drops the old cache. Rollback target: `shadow-castle-detective-play-ick3tv2wl-cyc4.vercel.app`.

### What is built in Blender, measured

- **New tool** `tools/blender/audit_blender_coverage.gd -- --room=<room>|hall`: opens the area, notes every textured thing it draws in the world (the HUD aside), stages the HD look as the preview does, and sorts what shows: drawn by the HD look, the game's own art covered by the render, or the game's own still showing, as art (from the project), generated (made in code) or self-drawn. It writes `audit/coverage.json` and a shot with what is left boxed (the Hall's whole map in one view).
- **Found:** every room's own art is under its render, but for Mrs. Lin's body in the Final Room (`assets/props/FinalRoom/mrs_lin_fallen.png`, drawn over the HD floor). The Hall's only art left is the tutorial's footprints (guidance), and the rest is generated light. Not covered by the tool, and found by reading `map_hud.gd`: the Map Hub and the Guardian's minimap draw `assets/backgrounds/hall_map_hub.png`, the painted Hall map, and the Circuit repair map draws the painted workshop. The Circuit Room was rebuilt only in its worktree.
- **After this stage:** no room's own art is left in any of the eight areas (Hall 0, Wake 0, Chemistry 0, Greenhouse 0, Library 0, Dining Hall 0, Circuit 0, Final 0), and the three maps are Blender renders.

### What changed

- **The Circuit Room is in this checkout's preview** (`play_prototype.gd -- --circuit`):
  - its `room_circuit.py`, `capture_circuit_room.gd`, render data, four CC0 textures (SHA-256 checked) and evidence are copied over;
  - its changes to the shared scripts are merged three-way on its base, `ddcbc66`: the light rig lifted onto the HD fixtures (`prototype_room.gd`), a south wall with doorways and `"meta"` from `build()` (`room_prototype.py`), and furniture and script constants in the layout export (`export_room_layout.gd`, behind `"furniture": true` so no other room's export changes);
  - re-rendered with the merged pipeline: the same 1044 objects, 15 glows and 8 fixtures, the image within render noise of the worktree's (0.1 % of pixels), and its JSON identical; re-exported, its collision mask is identical.
- **Mrs. Lin, the Tripo Dr. Lin where she fell** (`room_final.py` `fallen_lin()`, the prop `MrsLinBody`):
  - the cast's model, imported into the room without touching the room's own meshes, posed from her rest pose and laid face down on the flagstones where the body lies (the model's eyes are painted open, so her face is turned to the floor): her lower arm reaches toward the notebook, her upper hand rests by her hip on the torn violet cuff, her knees are drawn up;
  - 1.4 m tall like the cast against the detective, lit by the room and by a soft warm light linked to her alone, so her dark coat reads and the room's light is unchanged;
  - her HD footprint ends where she meets the floor at the south, so the room offers her to a player who comes up from the room (from 292 floor cells; the painted body from 55).
- **The Map Hub's maps in Blender** (`tools/blender/prototype_map.gd`, staged with the figures in every look):
  - `hall_prototype.py --map <png>` renders the whole Blender Hall from straight above, props on their stands and doors shut, at the map's 1448 × 1086 with pixels drawn taller than wide, so `map_hud.gd`'s projection lands on it unchanged (20 s to render);
  - the painted map no longer matches the Hall: its walls cross the current collision, while the Blender map's walls stand on it;
  - the repair map's board is the Circuit Room's HD render with its props laid back in, at the painted background's size, so the switch markers land as before;
  - MapHud is an autoload, so the HD look sets its panel's, minimap's and repair board's textures itself (smooth, with mipmaps) and gives the game's own back.
- **The Final Room capture** (`capture_final.gd`) stages Mrs. Lin as an HD prop and checks her box, prompt and footprint: 114 checks (was 111).
- **New capture** `tools/blender/capture_maps.gd` (24 checks): each map in each look, the screen change in each (21.3 and 22.7 of 255), a repair map built while HD shows, and the restore.

### Exact files

- **New:** `tools/blender/audit_blender_coverage.gd`, `tools/blender/prototype_map.gd`, `tools/blender/capture_maps.gd` (each with its `.uid`); from the Circuit worktree `tools/blender/room_circuit.py`, `tools/blender/capture_circuit_room.gd` and `.uid`, `docs/evidence/2026-10-24-blender-circuit-room/`; `docs/evidence/2026-10-25-blender-coverage/`.
- **Changed:** `export_presets.cfg`; `tools/blender/room_final.py`, `hall_prototype.py`, `prototype_characters.gd`, `capture_final.gd`, `audit_interactions.gd`, `play_prototype.gd`; merged with the Circuit worktree: `prototype_room.gd`, `room_prototype.py`, `export_room_layout.gd`, `cc0_textures.json`; this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- **Local only (gitignored):** `prototypes/blender_rooms/circuit_room/`, the four textures in `prototypes/blender_hall/textures/`, `prototypes/blender_hall/map.png`, the Final Room's re-render, the audits and captures.

### Verification

- **Captures, EN and ZH:** Wake 65, Chemistry 102, Greenhouse 114, Final 114, Hall 176, portraits 80, Circuit 111, maps 24, Library 141, Dining Hall 114, all passing.
- **Audits:** coverage as above; interactions in the Circuit Room (every item offered; its three switches stay concealed until surveyed, as in the painted look) and the Final Room (Mrs. Lin from 292 cells).
- **Godot:** the headless editor parse has 0 errors and every changed tool script parses on its own (`--check-only`); gdlint is clean on them; pyflakes is clean on `room_final.py`, `hall_prototype.py`, `room_prototype.py` and `room_circuit.py`; `git diff --check` is clean.
- **Web:** as above (deploy, hashes, browser).

### Risks / follow-up

- **The website still shows the painted game:** every HD room, figure, portrait and map is in the preview. Syncing them is the move into the game: copy the renders into `assets/`, make the HD look the game's own, and keep the web download in bounds (it is 131.6 MB now; the HD rooms' PNGs are large and need lossy compression).
- **The Library and the Dining Hall** do not yet meet the room standard (stage 61's audit: the Library's flat wood and light 39.7 against its painting's 27.9; the Dining Hall's 5.1 m table, dark floor joints and weak hearth). The user has not reviewed the Circuit Room's stage 55-circuit, the Library's stage 59 or the Dining Hall's stage 60.
- **Mrs. Lin** follows the cast's chibi Tripo model rather than the painted figure's proportions, and lies face down because the model cannot close its eyes.
- **The Hall map** is a straight top-down render; the Map Hub's ink and fog still draw over it as before.
- **Next:** the Library and the Dining Hall brought to the room standard (the user's choice), then the move of every HD room, figure, portrait and map into the game, and the deploy.

## Stage: UX-20261021-64 (dialogue portraits from the Tripo models)

- **Date:** 2026-10-25
- **Status:** approved by the user ("满意"), then committed and pushed at their request, with this stage's hunks only. Preview only: the game's own portraits, scenes and saves are unchanged. Their choice for next: moving the HD rooms, characters and portraits into the game.
- **Request:** the user's choice at stage 63's review, "用新模型渲染 NPC 头像" (render the NPC portraits from the new models), then "可以，继续" (go on).
- **Parallel work:** the Library (57, 59) and Dining Hall (60) sessions' work is still uncommitted in this checkout; this stage does not touch it.

### What the game shows now

- Each speaker's portrait sits at the left of the dialogue box: a 112 px square over the frame's own colour, with the speaker's name across its foot.
  - Four scenes do this, each with its own copy of `NPC_DIALOGUE_PORTRAITS` and `_set_avatar`: the Wake Room, the Chemistry Room, the Greenhouse and the Hall.
  - The pixel portraits are head-and-shoulders busts on a transparent ground (`assets/characters/portraits_pixel_v2/`, 1254 px), loaded by path whenever the speaker changes, and drawn with nearest filtering.
- **Speakers the player meets:** Mrs. Lin's letter (Wake, the `dr_lin` portrait), the butler (Chemistry) and the gardener (Greenhouse). The Hall's butler, gardener and mechanic dialogues exist, but the Hall spawns no NPCs. No dialogue names the Castle Guardian. The detective keeps his coloured square, by design ("玩家保留色块").

### What changed

- **Five HD portraits** (`tools/blender/portrait_prototype.py`): the butler, the gardener, the mechanic, Dr. Lin and the Castle Guardian, rendered from their Tripo models into `prototypes/blender_chars/portraits/<portrait>.png` (1024 px, RGBA, transparent ground). `portraits.json` maps each game portrait to its HD file and records the framing.
  - **Pose:** the gait sheets' standing idle, the body turned 14–18° toward the viewer's right (toward the dialogue text) and the head turned most of the way back to the camera, with a slight tilt for each one's manner.
  - **Light:** the gait sheets' rig (warm key from the upper left, cool fill, violet rim), a little stronger for a close bust, plus a violet kicker so a dark coat stands off the frame's dark ground. The Guardian's visor and core glow as in his sheets.
  - **Lens and framing:** 85 mm, 5° above eye level. Each bust is framed on its own head (crown 5 % below the top, chin 57 % down), so the name label covers only the chest. Dr. Lin's wide hair is framed a little looser (53 %); the Guardian's helm sits high on his armour, so his framing takes in his shoulders and the glowing core (36 %), as his pixel portrait does.
  - **Time:** 49 s for all five at 128 samples.
- **In the preview** (`tools/blender/prototype_portraits.gd`, staged with the characters by `prototype_characters.gd`):
  - While the HD look is staged, each HD portrait (scaled to 224 px, twice the box, with mipmaps) takes over its game portrait's resource path (`Resource.take_over_path`). Each scene's own `load()` then returns the HD portrait the next time the speaker changes, and the box draws it with `LINEAR_WITH_MIPMAPS`.
  - A box already showing a pixel portrait swaps at once. Restoring gives each path back to the game's own portrait, and the box its own filter.
  - The registry is static, since the resource cache is global and the Hall and each room stage their looks separately.
- **New capture** (`tools/blender/capture_portraits.gd`, 80 checks): opens each speaker's dialogue the game's own way in both looks, in the Wake Room, Chemistry, the Greenhouse and the Hall (butler, gardener, mechanic, and the Guardian by name). It checks the pixel portrait, the swap to HD, the screen change inside the box, a fresh `load()` in HD, and the restore.

### Exact files

- **New:**
  - `tools/blender/portrait_prototype.py`: the renderer;
  - `tools/blender/prototype_portraits.gd` and its `.uid`: the preview's portrait layer;
  - `tools/blender/capture_portraits.gd` and its `.uid`: 80 checks;
  - `docs/evidence/2026-10-25-npc-portraits/`.
- **Changed:** `tools/blender/prototype_characters.gd`: attaches the portraits and stages them in `apply()`/`restore()`.
- **Local only (gitignored):** `prototypes/blender_chars/portraits/` (the five PNGs, `portraits.json`, the captures); a provenance note in `prototypes/blender_chars/source/sources.json`.
- **Evidence:** `docs/evidence/2026-10-25-npc-portraits/`:
  - `01-portraits.png`: the five pixel portraits above their HD ones;
  - `02-dialogue-boxes.png`: the dialogue box in game at 1024×768, at 2x, pixel and HD, for Mrs. Lin's letter, the butler, the gardener, the mechanic and the Guardian;
  - `03-chemistry-butler.png`, `04-greenhouse-gardener.png`, `05-wake-dr_lin.png`: the whole moment, painted and HD;
  - `06-chinese.png`: HD with the Chinese interface.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Asset QA** (`create-game-assets` `asset_report.py`): all five are 1024×1024 RGBA with a transparent ground. Their crowns sit 44–50 px below the top edge with nothing clipped, and each bust is cut by the frame's foot as intended.
- **Capture** `capture_portraits.gd`: 80/80 in EN and in ZH. The screen inside the box changes by 24–33 (of 255) between the pixel and HD portraits.
- **No regressions,** EN and ZH: `capture_room.gd` 65, `capture_chemistry.gd` 102, `capture_greenhouse.gd` 114, `capture_final.gd` 111, `capture_prototype.gd` 176 (Hall), `capture_library.gd` 141 and `capture_dining_hall.gd` 114. The Library's and Dining Hall's capture folders were restored afterwards.
- **Godot:** the headless editor parse has 0 errors; gdlint is clean on the new and changed scripts; pyflakes and `git diff --check` are clean.

### Risks / follow-up

- **Preview only.** Moving the portraits into the game means copying the five PNGs into `assets/characters/`, pointing the four `NPC_DIALOGUE_PORTRAITS` maps at them, and drawing the boxes with linear filtering and mipmaps.
- **Likenesses follow the Tripo models,** which the user approved at stage 63, rather than the pixel portraits. The gardener's skin reads lighter than her pixel portrait's, and every model has chibi proportions, so the busts show less shoulder.
- **The Guardian's and the mechanic's portraits** show only in the Hall's dialogues, which the game does not reach yet (no Hall NPCs, no Guardian dialogue). The Circuit Room's mechanic dialogue has no portrait box.
- **Found, not fixed (pre-existing):** in Chinese the Greenhouse still names the gardener "Gardener" in its dialogue header and portrait label, while Chemistry names the butler 管家.
- **Next:** the move of the HD rooms, characters and portraits into the game (the user's choice).

## Stage: UX-20261021-63 (interactions against the HD rooms; the cast in Tripo)

- **Date:** 2026-10-25
- **Status:** approved by the user ("满意"), then committed and pushed at their request, with this stage's hunks only. Their choice for next: the NPC portraits, rendered from the new models.
- **Requests:**
  - "现在复查每个交互地点是否准确的对应了修改的后的物品大小和位置" (now recheck that every interaction spot matches the rebuilt items' size and position);
  - during the stage: "还有npc的建模，也需要用tripo做出来" (and the NPC models, made in Tripo too).
- **Parallel work:** the Library (57, 59) and Dining Hall (60) sessions' work is still uncommitted in this checkout, and Circuit is in its worktree. This stage only reads their rooms; their hunks in the shared files are untouched.

### How the audit works

- **New tool:** `tools/blender/audit_interactions.gd` (`-- --room=<room>|hall`), for each look (HD and painted):
  - walks the floor reachable from the room's arrival (6 px cells, the room's own walkability);
  - for every interaction, records its box, its contact box, its mouse hotspot (the Wake Room's), and every cell where the room's own "near" test offers it;
  - stands the player in front of each and shoots it;
  - writes `prototypes/blender_rooms/<room>/audit/interactions.json` (or `prototypes/blender_hall/audit/`).
- **Coverage:** all 7 areas (Wake, Chemistry, Greenhouse, Library, Dining, Final and the Hall): 79 interactions, plus the Greenhouse's 10 herb plots and the Hall's corridor fragments.

### What it found, and what changed

- **Already right (no change):**
  - **Final Room:** every box follows its HD prop; the exit box is the great door.
  - **Dining Hall:** every box follows its HD prop. The exit is offered from only 7 cells in both looks, which is the room's design.
  - **Library:** the 20 cases follow their HD props. The fixed boxes (the two scrolls, the research desk, the three lens slots, the chained cabinet, the drawer bank) sit on the HD art as on the painted art, because the Library session built the HD room on them.
  - **Hall:** the 8 doors' boxes are centred on the HD doorways, and the 9 props follow their HD stands. The corridor fragments and service points are invisible proximity points, the same in both looks.
- **Chemistry, the red stain (HD only):**
  - The stain's box was the painted pool's fixed `RED_STAIN_RECT` (900, 500, 265 × 350). The HD stain is a pool about a third of that size, thrown south-west (x 885–1057, y 567–716, its last drops to x 1068 and y 560–726), so the box spilled over the east counter and empty floor down to y 850.
  - Now `room_chemistry.build()` returns the HD pool's box, `"interactions": {"red_stain": [884, 560, 184, 166]}`. `room_prototype.py` writes it into `render.json`, and the preview sets it as the room's `red_stain_interaction_rect` while staged.
  - **Game hook:** `scenes/floor_1/chemistry_room.gd` keeps the box in `var red_stain_interaction_rect := RED_STAIN_RECT`, read by `get_interaction_rect`. The painted game is unchanged.
- **Greenhouse, the long beds (both looks):**
  - The beds' boxes, (105, 305, 125 × 655) and (794, 305, 125 × 655), stopped 19 px short of the aisle, beyond the 14 px contact band. The beds' minigames were offered from 33 and 32 cells, all at their north ends.
  - The boxes are now each whole bed inside its stone kerb, which is also its collision outline and where the HD room builds it: (90, 318, 167 × 822) and (762, 318, 150 × 820). They are offered from 666 and 426 cells, all along the aisle, in both looks.
- **Greenhouse, the planter's north herb plot (both looks):**
  - `planter_north` at (515, 520) was the planter's middle; the nearest floor was 113 px away, so it could never be picked (reach 78).
  - It is now (515, 455), in the soil inside the north rim, picked from the floor behind the planter (94 cells, 49 px at the nearest).
- **Greenhouse, the gardener (both looks):** her mark (780, 1000) was inside the moonleaf bed's collision, which the painting draws 30 px narrower. In HD her feet stood in the soil. `GARDENER_POSITION` is now (740, 1000), on the aisle floor beside the bed.
- **Wake Room, the door's mouse click (both looks; a game bug):**
  - The door's hotspot was a fixed 100 × 160 box round `door_position` (832, 450), which barely touched the door.
  - A click from across the room walked to a point 105 px short of the door (`DOOR_INTERACT_RADIUS` × 0.7, pushed out from `door_position`). On arrival the room said "I couldn't get close enough" every time.
  - Now `_sync_door_interaction()` makes the door's box (its visible art), its hotspot and its walk-up point (on the box's contact band, the way a prop's is found) agree. A click walks there and arrival uses `CLICK_ARRIVAL_MARGIN`, as for the props. `begin_mouse_interaction`, `calculate_interaction_approach_point` and `DOOR_INTERACT_RADIUS` are removed (nothing else used them).
  - The preview calls `_sync_door_interaction()` when it stages and restores, instead of setting the door's box itself.
- **Wake Room, the props' click areas (HD only):** the bed's, desk's and bookshelf's click shapes were drawn round the painted props, so in HD the bed's pillow and the bookshelf's top took no click. While staged, the preview turns those shapes off and gives each prop a box over its HD art. Restoring puts the painted shapes back.

### The cast in Tripo

- **Models:** the butler, the gardener, the mechanic and Dr. Lin, made the detective's way in Tripo Studio, on the user's account:
  - a 1:1 concept image pair (Nano Banana) from the pixel sprite's front frame, with a T-pose prompt;
  - HD Model H3.1 (4K PBR, 40k triangles, private);
  - Auto Rig (Humanoid, Mixamo);
  - the preset clips walk, run, idle, look_around and standing_relax;
  - a GLB export, 2k textures, in place.
  - **Cost:** 380 credits (4 concept pairs at 20, 4 models at 55, 4 rigs at 20; retargets and exports are free). Balance 3885 → 3505.
  - **Provenance:** `prototypes/blender_chars/source/sources.json` (task ids, prompts, chosen concepts) and `npc_prompts.json`. Concepts in `concepts/`, references in `refs/`.
- **Sheets:** `character_prototype.py --character butler|gardener|mechanic|dr_lin` renders each into idle, walk and run sheets in 8 facings, 128 px cells and a 100 px figure, as the detective's. Each takes about 4 minutes.
  - `character_motion.STYLES` gives each their own manner: the butler upright and still, with a calmer walk; the gardener and the mechanic at ease; Dr. Lin with her hands clear of her long coat.
- **In the preview** (`prototype_characters.gd`):
  - Every `AnimatedNpc` the game names (Butler, Gardener, Mechanic, Dr. Lin Memory Echo) is drawn by its Tripo figure, a child of its own sprite.
  - The game keeps the NPC's sprite, frames, turning to meet the player and notice pulse. The figure is drawn as tall as the pixel figure and on the same feet, plays its idle loop, and faces as the game turns the NPC (its 8 or 4 facings map to the sheet's rows).
  - `prototype_depth.gd` hides the cast behind walls in front of them and gives each a contact shadow, except Dr. Lin's memory echo, which is a vision, not a body.
  - In HD: the butler and Dr. Lin's echo in Chemistry, and the gardener in the Greenhouse. The mechanic is ready for the Circuit Room's HD room, which is in its own worktree. Mrs. Lin's body in the Final Room is that room's own prop and is unchanged.

### Exact files

- **New:** `tools/blender/audit_interactions.gd` and its `.uid`; `docs/evidence/2026-10-25-interactions-and-cast/`.
- **The game itself:**
  - `scripts/wake_room.gd`: `_sync_door_interaction()`, `door_approach_position`, the door's click walk and arrival; the unused radius helpers removed.
  - `scripts/greenhouse_room.gd`: the beds' boxes, `planter_north`, `GARDENER_POSITION`.
  - `scenes/floor_1/chemistry_room.gd`: `red_stain_interaction_rect`.
- **The prototype:**
  - `tools/blender/prototype_room.gd`: `"interactions"` swap (`_read_interactions`, `_swap_interactions`), the Wake props' HD click boxes (`_swap_hotspots`), `_sync_door_interaction()` in `_resync()`, the cast in `summary()`.
  - `tools/blender/prototype_characters.gd`: the cast (`NPCS`, `NPC_FIGURE_PX`, `NPC_FACINGS`, `_swap_npc`, `_row`, `cast`).
  - `tools/blender/prototype_depth.gd`: the cast's depth and shadows.
  - `tools/blender/room_chemistry.py`, `tools/blender/room_prototype.py`: the `"interactions"` contract.
  - `tools/blender/character_prototype.py`, `tools/blender/character_motion.py`: the four characters.
  - `tools/blender/capture_chemistry.gd` (102 checks, was 86): the HD stain's box; the butler and the echo in HD.
  - `tools/blender/capture_greenhouse.gd` (114 checks, was 97): the beds along the aisle and the north plot, in both looks; the gardener in HD, on the aisle.
- **Local only (gitignored):** the GLBs and sheets in `prototypes/blender_chars/`; the audits in `prototypes/blender_rooms/*/audit/` and `prototypes/blender_hall/audit/`.
- **Evidence:** `docs/evidence/2026-10-25-interactions-and-cast/`:
  - `01-red-stain.png`, `02-herb-beds.png`, `03-planter-north.png`, `04-wake-click-areas.png`: before and after, at 2x on the HD render. The box is gold, the floor it is offered from green, the click area magenta.
  - `05-gardener-mark.png`: her old and new marks over the bed's collision, and her in game in both looks.
  - `06-cast-tripo.png`: each of the cast as the game's pixel sprite, the concept and the Tripo model.
  - `07-cast-gait-sheets.png`: frames of each one's idle, walk and run sheets.
  - `08-cast-chemistry.png`: the butler and Dr. Lin's echo in the Chemistry Room, painted and HD.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Audit after the fixes:** the stain is offered from the floor round the HD pool (1254 cells); the beds from 666 and 426 cells; `planter_north` from 94; every Wake click area is its HD prop's box (the door 851, 248, 104 × 267.5).
- **Wake mouse probe** (real left clicks pushed into the viewport, fresh room each time, `/tmp` script): 22/22 clicks walk to the thing and open it. That covers the door's top, middle and right edge from three starts in HD (all three points lie outside the old hotspot), the bed's head and the bookshelf's top in HD, and each in the painted look.
- **Captures**, EN and ZH:
  - `capture_chemistry.gd` 102/102 and `capture_greenhouse.gd` 114/114 (new checks);
  - unchanged and passing: `capture_room.gd` 65/65 (Wake), `capture_final.gd` 111/111, `capture_prototype.gd` 176/176 (Hall), `capture_library.gd` 141/141 and `capture_dining_hall.gd` 114/114. The Library's and Dining Hall's capture folders were restored afterwards.
- **Game tests (headless):**
  - pass: `greenhouse_herb_plots_test`, `potion_economy_test`, `wake_interaction_priority_test`, `tutorial_chain_test`, `chemistry_deduction_test`;
  - `room_spatial_audit` fails only its six known Hall cases (next priority 4).
- **The cast:** each figure stands on its NPC's feet (0.00 px off) at the pixel figure's height (butler 92.4, Dr. Lin 92.2, gardener 91.2 px), facing as the game turns it; 0 render warnings.
- **Godot:**
  - the headless editor parse has 0 errors;
  - gdlint is clean on the prototype's scripts and the captures;
  - the three game scripts keep their earlier gdlint findings and add none;
  - pyflakes and `git diff --check` are clean.
- **Blender 5.2.2:** Chemistry re-rendered (116 s, 1843 objects, 28 glows) with its `"interactions"`.

### Risks / follow-up

- **Game changes for players:**
  - the Wake door now answers a click from anywhere;
  - the Greenhouse beds' minigames are offered along their whole length;
  - `planter_north` can now be picked (two blue blossom more per sweep, as designed);
  - the gardener stands 40 px further west.
  - Saves, story flags and the other plots are unchanged.
- **The beds' boxes are larger** in the painted look too: the focus brackets now frame the whole bed rather than its soil.
- **Library boxes:** they were found right; none of the Library session's work was changed.
- **The cast stand still in this game,** so only their idle shows. Their walk and run sheets are ready for a scene that moves them.
- **The mechanic** shows in HD once the Circuit Room's HD room joins the preview. **Mrs. Lin's body** (Final Room) is the room's own prop; a Tripo body would replace that prop.
- **Committing:** the shared files hold other sessions' uncommitted hunks. Build this stage's commit from `HEAD` plus its own hunks, as for stages 61 and 62.
- **Next:** the NPC portraits rendered from the new models (the user's choice), then the move into the game.

## Stage: UX-20261021-62 (Final Room)

- **Date:** 2026-10-24
- **Status:** approved by the user ("满意") after two revisions at their review, then committed and pushed with the game's exit fix and the Dining Hall session's generic exporter code (`rect_shapes`, `_rect_walls`, `rects`), at the user's request. The prototype ships nothing. The one change to the game itself is the Final Room's exit (`scripts/final_room.gd`, see "Review and revision"); its art, collision and saves are unchanged.
- **Request:** at stage 61's review the user approved both rooms and chose the Final Room next, continuing "可以继续修改其他的房间" (go on with the other rooms) to the room standard.
- **Parallel work:** the Library (stages 57 and 59) and the Dining Hall (stage 60) sessions have uncommitted work in this checkout; Circuit is being built in the worktree `circuit-room-blender`.

### Review and revision

- **First review:** "需要修改" (needs changes), with "为什么我的人物可以走到大门的上面？？" (why can my character walk onto the top of the great door?). They chose to commit stage 62 with the Dining Hall's generic exporter code, and Tripo characters next.
  - **Why it happened:** the game's south walls stop the player's feet along the painted door's top edge, y 797 at its west end to 776 at its east, and 726–751 by the piers and bays. The great door stands south of that line, between the camera and the player. The HD gate rose above the line (its crest top at screen y 710) and was out of the depth map, so the player was drawn over it, standing on its arch.
  - **The first fix (superseded):** a lower gate set further back, below the line the feet reach. The user rejected it.
- **Second review:** "不能有空气墙，玩家应该可以走到门的后面，然后可以从门看到玩家的身影，就和hall一样" (there must be no invisible walls; the player should be able to walk behind the door, and you should see the player's silhouette through the door, as in the Hall).
  - **The cause was an invisible wall.** In HD the floor runs on past that line to the gate, so the painted walls that stop the player there are a wall across open floor.
- **The HD room, revised:**
  - **The gate is the first build's again** (`room_final.south_gate`): 2.0 m leaves under the round arch and its sunburst crest, columns and tall piers. It is now in the depth map.
  - **The floor runs up to the gate's base** (`GATE_BACK`, the north faces of its piers, bays, columns, jambs and leaves). The flagstones are laid up to it (856 stones instead of 822), and the dark under them runs on to it.
  - **The south walls end where the floor really does.** `footprints()` swaps the painted `RoomCollisions/BottomLeftWall` and `BottomRightWall` for walls that follow the floor's edge and the gate's base, while the HD room is staged. The painted ones come back on restore.
  - **What the player sees:** walking south from the arrival, he reaches the gate. All along it he walks up to its base, behind it, where it stands between him and the camera, and shows through it as the Hall's violet silhouette (the depth pass's `PLAYER_GHOST`). The leaves themselves still block him.
- **The game's exit, fixed** (`scripts/final_room.gd`, the bug stage 62 found):
  - `EXIT_RECT` is now the great door itself, `Rect2(622, 788, 206, 204)`, instead of the landing beyond the walls (624, 958, 200, 128).
  - Walking up to the door offers "Press E to return to the Castle Hall": in the painted look at the door's top edge, and in HD behind it, at its base. The probe's nearest reachable gap fell from 166 px to 0.
  - The walls, the spawn, the transition and the saves are unchanged.

### What changed

- **The Final Room, rebuilt in Blender from its painting** (`assets/backgrounds/final_room_arcane.png` and `assets/props/FinalRoom/`), on the room's real collision, in the Chemistry Room's dark slate, laid flagstones, old oak and brass:
  - **North:** the vault door between two tall glazed cabinets and two brass wall lanterns. Either side are a violet lancet between colonnettes and a violet crystal lantern under a brass rosette; in each corner, an arched alcove of scroll racks over a chest of drawers.
  - **West:** scroll presses and drawers along the wall, a glass vitrine and a long table of papers before them, a cabinet lit violet from inside, and a great packing crate turned askew in the south-west corner.
  - **Middle:** the Ashford analysis table, a round table 3.2 m across and 81 cm high. Its eight slate evidence panels are linked by brass to an inner hoop, and a circle of brass inlay rings it on the floor.
  - **East:** the Knowledge Engine, a brass armillary with its glass orb and planets on a drum, on an octagonal stepped dais, with its console glowing. Beside it stand scroll presses, two vitrines, a writing table and a chest of drawers.
  - **South:** the floor ends at a coping over the dark, as the painting's does. The way back to the Hall is the painting's great door, with a violet core in a brass ring between its leaves and the four rooms' emblems round it, between columns and violet lamps on tall piers. The floor runs up to its base, so the player walks behind it and shows through it, as in the Hall.
  - **Floor:** 822 flagstones laid one by one, with brass lines let into them and five iron grates glowing violet from below. Mrs. Lin lies where the game draws her (her figure stays the game's own until the characters' pass), with her notebook by her hand.
- **Four HD props stand in for the room's own nodes:** the vault door, the analysis table, the Knowledge Engine and the notebook. Their highlight boxes, prompts and walk-up points follow them, through the room's own `_sync_authored_interaction_positions()`.
- **Real footprints:**
  - The table's and the engine's capsules become the HD props' outlines.
  - The west vitrine and table of papers, the crate and the east writing table, which the painting lets the player walk through, get footprints of their own while the HD room is staged.
  - Behind the HD table, where the painted table stood, the floor is open. A player there is hidden behind the table and is still offered it.
  - The south walls end at the floor's edge and the gate's base (the revision), so the floor before the great door is open up to it.
- **Light:**
  - The room is lit by its own lamps: two amber wall lanterns, the violet crystal lanterns, the lancets and the grates, the engine's orb and console, and a warm fill.
  - Mean luminance is 25.7 and warmth (R − B) +7.4, against the painting's 25.9 and +6.6.
  - The open floor is a little brighter than the painting's (centre 40 against 34), and the table a little darker (26 against 33).

### Pipeline (backward compatible)

- **`export_room_layout.gd`:**
  - a `final_room` entry;
  - `"capsule_shapes": true` exports `CapsuleShape2D` furniture collisions as 32-point wall polygons, through the shape's whole transform (the Final Room's hang under scaled sprites).
  - The entry also uses the Dining Hall session's `"rect_shapes"` and `"rects"` exporter code.
- **`room_prototype.py`:** a room's `Shell` `"south"` wall is optional. The Final Room ends its floor its own way.
- **`prototype_room.gd`:** the footprint swap is generalised and takes world px points from `build()`'s `"collision"`:
  - a `CollisionPolygon2D` is re-projected when the room is staged;
  - a `RectangleShape2D` stays a rectangle;
  - any other shape (a capsule) becomes the HD prop's outline, as a `ConvexPolygonShape2D`;
  - a path the scene lacks adds a `CollisionPolygon2D` under the body it names, which is freed on restore;
  - the body's transform is forced after the swap. The Final Room's collision hangs under the props' sprites, which the HD props rescale, so for a frame the physics server saw the shapes at the other look's scale and the player could be pushed to NaN.
  - `_resync()` also calls a room's `_sync_authored_interaction_positions()`, and `final_room` is added to `ROOMS`.
- **`play_prototype.gd`:** `-- --final` opens the Final Room.

### Exact files

- **New:**
  - `tools/blender/room_final.py`: the room, its four props and its footprints;
  - `tools/blender/capture_final.gd` and its `.uid`: 111 checks.
- **Changed:**
  - `tools/blender/export_room_layout.gd`: the `final_room` entry and `_capsule_walls()`;
  - `tools/blender/prototype_room.gd`: the footprint swap, `_resync()` and `ROOMS`;
  - `tools/blender/room_prototype.py`: the optional `"south"`;
  - `tools/blender/play_prototype.gd`: `--final`.
- **Evidence:** new `docs/evidence/2026-10-24-blender-final-room/`:
  - `01`–`09`: the painted room and the HD room in game, at the same spots. They cover the arrival, the vault door, in front of the table, the engine's console, the notebook, beside Mrs. Lin (Chinese UI), behind the table, the west tables and crate, and the east side.
  - `10-room-overview.png`: the whole room, painted and HD, each with its light.
  - `11-render-on-collision.png`: the render over its collision, with the HD footprints.
  - `12-hd-props.png`: the four props, painted and HD, at 2x.
  - `13-at-the-door.png` (revision): at the great door, the way back offered in both looks; in HD the player is behind the door, seen through it.
  - `14-no-invisible-wall.png` (revision): the floor before the door at 2x, over the painted south walls (ending at the door's top, across open floor) and over the HD room's own (ending at the gate's base).
- **The game itself (revision):** `scripts/final_room.gd`: `EXIT_RECT`.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Blender 5.2.2, 128 samples:** the room renders in 95 s, with 1739 objects, 856 flagstones, 18 glows and 4 props.
- **Captures:** `capture_final.gd` passes 111/111 in EN and in ZH (91 before the revisions). It checks:
  - every prop staged in HD, every glow's halo, and the depth map;
  - each prop offered from its walk-up spot, in both looks, with its box following the HD art;
  - the 10 footprints swapped in, the south walls among them;
  - the HD table, west vitrine and great door block; the floor behind the table and before the door is open; the painted walls close that floor again on restore;
  - the table and the engine draw in front of a player behind them and behind one in front;
  - no invisible wall: walking south from the arrival, the player reaches the great door;
  - at nine spots along the door, walked as far south as the walls allow, the player stands at its base, behind it (45 rows of his figure behind it);
  - behind the door he shows through it as the Hall's silhouette (ghost 0.45; about 3800 px of his figure seen, measured against a shot without him);
  - at the door the way back to the Castle Hall is offered, in both looks;
  - the HD detective at the room's size, walking and running at the game's speed;
  - everything, footprints included, put back on restore.
- **The game's exit:**
  - The reachability probe on the game's own collision now finds the exit's 14 px band reached, at a 0 px gap; it was 166 px.
  - `tests/room_transition_flow_test.gd` and `tests/interaction_stops_walk_test.gd` pass.
  - `tests/room_spatial_audit.gd` passes the Final Room's exit contact band (`final/exit`) and fails only its six known Hall cases (next priority 4).
- **No regressions:**
  - `capture_chemistry.gd` passes 86/86 and `capture_greenhouse.gd` 97/97 on the generalised swap;
  - the stage 61 rectangle swap test on the Dining Hall's table still passes headless.
- **Godot:**
  - the headless editor parse has 0 errors;
  - gdlint is clean on the prototype's scripts; `scripts/final_room.gd` keeps its 57 earlier findings and adds none;
  - pyflakes and `git diff --check` are clean.
- **Playable preview:** `play_prototype.gd -- --final` stages the room with 18 glows, 4 HD props, depth and 2 HD character sheets, and no script errors.

### Risks / follow-up

- **Preview only, but for the exit:** the game's own Final Room keeps its painted art and collision. Moving the HD room into the game means moving its footprints with it, its south walls included.
- **The game's exit (found in stage 62, fixed in the revision):** the Final Room's way back to the Hall could not be reached.
  - `RoomCollisions/BottomLeftWall` and `BottomRightWall` overlap at x 604–614 and close the whole gate bay. The deepest the player can walk is y 876, and the nearest they came to the old `EXIT_RECT` (624, 958, 200, 128) was 166 px, against a 14 px band, so "Press E to return to the Castle Hall" was never offered.
  - The walls are unchanged since the release build `505f008`, whose 80 px radius round `EXIT_POSITION` was out of reach too.
  - `room_spatial_audit` did not catch it, because it places the actor directly.
  - The safe spawn still moves the arrival from (724, 930) to (724, 770); `PLAYER_SPAWN_POSITION` is unchanged.
- **The painted look keeps its walls:** in the painted room the player still stops at the door's top as painted and is drawn over its hood. The HD room fixes this with its own walls, and replaces the painting when it moves into the game. Moving the painted walls now would change the shipping collision and the arrival.
- **Behind the door:** in HD the player can stand behind the gate's piers and columns too, all along its base. He is drawn as the violet silhouette there, as behind the Hall's walls, so he is never lost.
- **New blocking furniture:** in HD the west vitrine and table, the crate and the east table block the player, where the painting let them walk through.
- **Mrs. Lin** is still the game's pixel figure, until the Tripo characters' pass.
- **Committing:** the shared pipeline files hold the Library's and the Dining Hall's uncommitted hunks. Committing this stage alone means building its blobs from `HEAD` plus its own hunks, together with the Dining Hall's generic `rect_shapes`, `_rect_walls` and `rects` exporter code, which the `final_room` entry relies on. The user chose that.
- **Next:** the Tripo characters (the user's choice), the remaining rooms (Circuit is in its own worktree), the NPCs' portraits, and the move into the game.

## Stage: UX-20261021-61 (room audit, Chemistry brightening, Greenhouse bench)

- **Date:** 2026-10-24
- **Status:** approved by the user (both rooms "满意"), then committed and pushed together with the whole Greenhouse room (stages 54 and 56), at the user's request. Nothing ships: the game, its scenes, its saves and the Web build are unchanged.
- **Request:** after approving stage 58 ("很好"; committed and pushed as `aadec6c`), the user asked: "可以继续修改其他的房间，而且可以按照你的这个标准检查其他chat修改的房间，看一下是否符合你的标准" (go on with the other rooms, and check the rooms the other chats changed against your standard).
- **The user's choices at the audit:**
  - record the findings in the handoff, so the active sessions fix their own rooms;
  - fix the idle Greenhouse here (its session has been idle since 01:37);
  - brighten the Chemistry Room;
  - build the Final Room next.
- **Parallel work:** the Library (stages 57 and 59) and the Dining Hall (stage 60) sessions are working in this checkout.

### What changed

- **The other rooms, audited against the stage 58 standard.** Sizes were measured in the code, light on the renders at the painting's size, and wood at 2x. The standard and the findings are in `docs/AGENT_HANDOFF.md` ("Room standard" and "Audit").
  - **Greenhouse:** the bench is 1.85 m deep and its book 64 × 53 cm; its wood is graded to about a 4 % albedo, so it reads dark and flat. Fixed here.
  - **Library**, for its session: `wake.oak()` wood, and the render is brighter than its painting (mean luminance 39.7 against 27.9).
  - **Dining Hall**, for its session:
    - the banquet table is 5.1 × 2.8 m and 53 cm high;
    - its floor joints are too dark (luminance standard deviation 14.5–19 against 9–11);
    - its hearth burns weaker than the painted fire.
    - The handoff's "Real size vs the painting (stage 60, open)" note now records that stage 58 is approved, so the real-size rule stands.
  - **Chemistry** (this session's): a third darker and cooler than its painting. Brightened here.
- **The Chemistry Room is as bright as its painting.**
  - `grade()` sets exposure 0.9, and white balance at 7100 K (warmer). The lights are unchanged.
  - The room with its props: mean luminance 42.7 and warmth (R − B) +7.7, against the painting's 43.8 and +7.8. Stage 58 was 31.8 and +2.9.
- **The Greenhouse's potting bench is a real bench.**
  - **Size:** 2.5 × 1.0 m and 78 cm high. Stage 56 was 1.85 m deep and 65 cm high.
    - Its front stays where the painting's is, so the walk-up spot and the stool's footprint are unchanged.
    - The preview swaps its footprint into `RoomCollisions/table`. The floor behind it, inside the painted bench's footprint, is open: a player there is hidden to the shins and can gather from the seedling trays.
  - **Its clutter, re-laid on the shallower top:**
    - a back row: seed jars, a potted plant, the basket of blossom, the lantern, a bowl of bulbs, the fern in its pot and the seedlings;
    - the work in front: the seedling tray, cut herbs, twigs and dried flowers, the open handbook, a fallen pot, the trowel, the drying rack, the mortar and the repair map.
    - The tray and the rack lie under the game's glow markers for them, which are drawn on screen at (440, 965) and (590, 965).
    - The handbook is a real one, open: 46 × 31 cm.
    - The watering can moved to the slatted shelf, which now has three 17 cm slats centred between its rails.
  - **Weathered oak:**
    - rough-sawn `wood_table` boards, greyed to about a weathered oak's albedo (sRGB about 114, 87, 71) and matte, because a potting bench is unfinished wood;
    - each board has its own shade, worn rims and grime in its corners.
    - Stage 56 graded `wood_table_worn` to about a 4 % albedo, which lost the grain.
  - **The lantern** stands 7 px further forward and burns at 18 W instead of 6, so its pool reaches across the top, as the painting's does.
  - **Light, measured in game:** the bench top's median luminance is 45 and its warmth +29, against the painting's 50 and +27. Stage 56 was 24 and +20.
- **Pipeline (backward compatible):**
  - `prototype_room.gd`'s footprint swap also takes a `CollisionShape2D` with a `RectangleShape2D`, given as its four world px corners.
    - A centred copy of the shape is swapped in; the scene's own shape and position come back on restore.
    - Tested headless on the Dining Hall's table. This was the gap that session's note named.
  - `room_greenhouse.laid_photo` takes optional `coat`, `coat_roughness`, `roughness` and `bevel`. Their defaults leave every existing material as it was, the Dining Hall's included.

### Exact files

- **Changed:**
  - `tools/blender/room_chemistry.py`: `grade()`.
  - `tools/blender/prototype_room.gd`: rectangle footprints.
  - `tools/blender/room_greenhouse.py` (the Greenhouse session's, untracked):
    - `BENCH`, `BENCH_TOP` and the shelf;
    - `bench_wood`, the clutter and the lantern;
    - `laid_photo`'s options;
    - the paving's culling under the bench;
    - the footprint in `build()`.
  - `tools/blender/capture_greenhouse.gd` (untracked): footprint checks and the `11-behind-bench` shot.
- **Evidence:**
  - `docs/evidence/2026-10-23-blender-chemistry/`:
    - `01`–`12` regenerated from the brighter captures;
    - new `14-brighter-room.png`: stage 58, stage 61 and the painting, each with its light.
    - `13` stays as stage 58's record.
  - New `docs/evidence/2026-10-24-greenhouse-bench/`:
    - `01-workbench.png`: painted, stage 56 and stage 61 in game, each with the bench top's light;
    - `02-bench-2x.png`, `03-behind-bench.png` and `04-render-on-collision.png`.
  - The audit's sheets are kept outside the repo, in the session's `files/audit-2026-10-24/`.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Blender 5.2.2, 128 samples:**
  - the Chemistry Room renders in 115 s (28 glows, 2 props);
  - the Greenhouse in 113 s (64 glows, 5 props).
- **Captures:** `capture_chemistry.gd` passes 86/86, and `capture_greenhouse.gd` 97/97 (89 before), each in EN and in ZH.
  - The new Greenhouse checks:
    - the HD bench's footprint is swapped in;
    - the freed floor behind it is open, and the bench itself still blocks;
    - behind it, the bench draws in front of the player and the seedling trays are offered;
    - the painted footprint comes back on restore.
- **No regressions:** the Dining Hall's `laid_photo` calls are unchanged (positional arguments and keywords only from the original set), and pyflakes is clean on `room_dining_hall.py`.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean.
- **Playable preview:** `play_prototype.gd -- --greenhouse` stages the room with 64 glows, 5 HD props, depth and 2 HD character sheets, and no script errors.

### Risks / follow-up

- **Preview only:** the game's own Greenhouse, its painted bench and its collision are unchanged. Moving the HD room into the game means moving the bench's collision with it.
- **A new way to reach the herbs:** in HD the seedling trays and the drying rack can also be gathered from behind the bench. The painted bench kept the player to its sides.
- **Committing:** at the user's choice, this stage is committed with the whole Greenhouse room, which had never been committed:
  - `room_greenhouse.py` and `capture_greenhouse.gd`;
  - its evidence (`docs/evidence/2026-10-23-blender-greenhouse/`), its stage 54 and 56 entries, and its handoff lessons and status lines;
  - the `seaside_rock` texture its gate and pavers use.
  - The Library's and the Dining Hall's work in this checkout stays uncommitted for their sessions, including their entries and lessons in these docs and the Dining Hall's `"overhead"` pipeline.
- **The Greenhouse's overall light:** 11 % darker than its painting in game (39.7 against 44.7), within the standard's 15 %.
- **The other rooms:** the Library and Dining Hall sessions may not act on the audit; their notes are in the handoff.
- **Next:** the Final Room (the user's choice), then the Tripo NPCs.

## Stage: UX-20261021-60 (Dining Hall)

- **Date:** 2026-10-24
- **Status:** built and verified, awaiting the user's review. Nothing ships: the game, its scenes, its saves and the Web build are unchanged.
- **Request:** the user approved stage 56: "很好，按照你目前的优化方向的这个效果优化下一个房间" (very good; optimise the next room the same way, to the same effect).
- **Which room:** in the handoff's order the next room is Circuit, but a parallel session is already building it in its own worktree (`circuit-room-blender`). This stage therefore took the next unclaimed room, the **Dining Hall**.
- **Approach:** stage 56's direction throughout:
  - every piece follows the painted room's own design (`assets/backgrounds/dining_hall_banquet.png` and `assets/props/DiningHall/`);
  - the Hall supplies the moonlight, the wall tops and the materials;
  - stone and boards are laid piece by piece from CC0 photos;
  - real tableware is CC0 Poly Haven models.

### What it is

- **North wall:**
  - two gothic windows (a mullion, two lights and an oculus under a hood moulding) on the night sky, with moonlight falling through them;
  - four red velvet curtains on brass rods with gold tiebacks;
  - a portrait each side in a gilt frame (the Hall's portraits' glowing eyes are switched off here);
  - three-candle brass sconces.
- **Fireplace (`Worldsort/Fireplace`):**
  - a hearth slab; dressed piers; a segmental arch of nine voussoirs with a proud keystone;
  - a mantel carrying three candlesticks and the CC0 mantel clock;
  - a hood tapering in dressed courses to a cornice, with a red shield bearing a sword;
  - in the firebox, a low fire as the painting has it: charred logs whose cracks glow, on an iron grate over embers, with dim orange tongues. Fire irons and a log stack stand beside it.
- **North-east corner:**
  - the barred wall door (`Worldsort/WallDoor`): big dressed blocks round a deep-set five-board door with strap hinges, a lock plate and a latch ring, on a step, with a small rug before it;
  - the serving cabinet: a drawer and turned feet, carrying a candle, a glass carafe, plates and a bowl.
- **Banquet table (`Worldsort/DiningTable`):**
  - six boards inside a moulded frame with cut corners, on an apron and six legs;
  - laid for eight with pewter plates and silver cutlery, and gilt candlesticks burning down its middle;
  - wine glasses with silver rims, one fallen; the decanter on its side and its wine spilt; the eighth place's napkin dropped and its spoon lost; a platter of CC0 fruit; a sauceboat.
  - The three south chairs belong to the table's prop, so its prompt box reaches the floor in front of them, as the painted table's does.
- **Chairs:** eight at the painting's scale: velvet seats, a moulded back frame round a velvet panel, a carved crest and turned finials. The end chairs are pushed back and turned.
- **Rugs:**
  - the banquet rug: a dark madder field, border bands, gold lines, a quarter-ring scroll in each corner and a medallion;
  - small rugs before the hearth, the wall door and the dresser;
  - a runner out of the main door.
- **Chandelier (`ChandelierSprite`):** a bronze wheel on eight iron spokes with collars round a hub, eight candles in drip pans, four chains to a crown ring and the long chain up. It hangs above everyone, as the game draws it.
- **Grandfather clock (`Worldsort/GrandfatherClock`):**
  - a plinth and a panelled base;
  - a trunk whose open door shows the gilt pendulum and two weights hanging still;
  - a hood on brass columns round the dial, stopped at midnight with its minute hand bent;
  - a broken pediment with swan necks and scrolls, and an urn finial.
- **Sideboard (`Worldsort/Sideboard`):**
  - the long sideboard down the east wall, with a raised back shelf;
  - brass bowls, the CC0 brass goblets, pot, pan and vase, a wine bottle and a candle;
  - cupboard doors at its south end;
  - its middle drawer pulled out, with silver cutlery and coins in it;
  - a torn red woollen strip, dropped askew with Blender's cloth solver, hanging over its south end.
- **Dresser (`Worldsort/Cabinet`):**
  - turned 31° toward the room by the west wall;
  - a cupboard base with two panelled doors, under a counter with a pewter basin and a folded cloth;
  - three shelves of plates stood on edge and stacked, cups and a brass goblet, under a carved crest;
  - its jug table with two pewter jugs beside it.
- **South wall and main door (`Worldsort/MainDoor`):**
  - the painting's south wall seen over its top: a low wall under the Hall's cap; a parapet of dark coursed stone round the door, with a dark recess each side; two torch blocks proud of it, a torch burning in an iron bracket on each; pilasters at the door's sides, all under pale caps; steps either side of the threshold.
  - The door has two leaves of boards under a studded rim rising to a shallow Tudor point, strap hinges with scrolled ends, ring pulls and a studded meeting stile. A stone threshold and the red runner lead out, with the Hall's lamplight on the boards beyond.
- **Floor:**
  - 916 flagstones in rough east-west courses, 28–66 px wide and 22–34 px deep, about a quarter split into two smaller stones;
  - each stone a slab with a worn chamfered rim, showing its own part of the CC0 `seaside_rock` photo in its own warm grey (`room_greenhouse.laid_photo` and `_paver`), with dark grout and dust in the joints;
  - muddy boot prints in the painting's two trails (from the wall door toward the clock, and from the table to the main door), and grit kicked to the walls.
- **Light and tone:** the Hall's moonlight and exposure, as the other rooms have them.
  - Measured region by region against the painting (mean luminance, painting / render): whole room 28.9 / 31.3, open floor 47.5 / 45.8, back wall 18.2 / 19.0, rug 20.2 / 18.9, curtains 15.8 / 16.8, table top 38.9 / 40.2, hearth stone 27.7 / 26.4, fire 22.7 / 18.3, windows 16.8 / 17.6, sideboard 24.2 / 24.0.
  - Further off: the dresser is darker (26.0 / 20.3), and the main door brighter under the Hall's lamp (18.5 / 24.4).

### Pipeline additions (shared files, surgical)

- **`tools/blender/export_room_layout.gd`:** the Dining Hall entry, plus two options.
  - `"rect_shapes": true` exports a room's `RectangleShape2D` furniture collisions as wall polygons named after their prop.
  - `"rects"` exports Rect2 constants (the exit's) as `extras["<name>_rect"]`.
  - The Greenhouse export is byte-identical.
- **`tools/blender/room_prototype.py` and `tools/blender/prototype_props.gd`:** `build()` may return `"overhead"`, props hung above every figure (the chandelier). They are rendered alone like any prop and marked `"overhead": true`. The preview never gives them to the depth pass, so they draw above every figure, as the game draws them.
- **`tools/blender/prototype_room.gd`:** the Dining Hall is in `ROOMS`.
- **`tools/blender/play_prototype.gd`:** `-- --dining` opens the Dining Hall at its door.
- **`tools/blender/cc0_models.json`:** five CC0 Poly Haven models:
  - `brass_pot_02` and `brass_pan_01` (Rico Cilliers);
  - `wine_bottles_01` (Jurita Burger and Rico Cilliers);
  - `food_apple_01` (Oliver Harries);
  - `food_pears_asian_01` (Amal Kumar).
  - The room also places the existing `brass_goblets`, `brass_vase_03` and `mantel_clock_01`.

### Exact files

- **New:**
  - `tools/blender/room_dining_hall.py`: the room build, reusing `room_greenhouse` and `room_wake` as libraries.
  - `tools/blender/capture_dining_hall.gd`: the native capture and its checks.
- **Changed:** `tools/blender/export_room_layout.gd`, `tools/blender/room_prototype.py`, `tools/blender/prototype_props.gd`, `tools/blender/prototype_room.gd`, `tools/blender/play_prototype.gd`, `tools/blender/cc0_models.json`.
- **Evidence:** `docs/evidence/2026-10-24-blender-dining-hall/`:
  - `01`–`09`: painted and HD at the native 1024×768, at the door (ZH), the table, the hearth, the wall door (ZH), the clock, the sideboard, the dresser, behind the table and on the open floor;
  - `10-room-overview.png`: the whole room, painted and HD;
  - `11-hd-props.png`: each prop rendered alone;
  - `12-render-on-collision.png`: the HD room with the game's walls and footprints outlined.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`. The status page also gains the Greenhouse line that stages 54 and 56 left out.
- **Generated, not committed:** `prototypes/blender_rooms/dining_hall_room/` (layout, renders, depth, props and captures).

### Verification

- **Blender 5.2.2, 128 samples, 2896×2172:** 95 s (room pass 65 s), 942 objects, 31 glows, 8 props.
- **Capture:** `capture_dining_hall.gd` passes 114/114 in EN and in ZH:
  - all 8 props are staged; the 7 the room render draws are undrawn as sprites, and the chandelier hangs in HD above every figure with no depth pass;
  - the 6 highlight boxes follow their HD props, and the painted ones come back on restore;
  - every prompt is offered beside its prop in both looks, and the way back to the Hall in the doorway in both looks;
  - north of the table its top hides the player's legs (13 rows); nothing hides the player in front of its south chairs or on open floor;
  - at the main door its arch ghosts only the feet (7 of 45 rows);
  - the HD detective stands at the room's size and walks.
- **Playable preview:** `play_prototype.gd -- --dining` stages `dining_hall_room: 31 glows, 8 HD props, depth true, 2 HD character sheets`.
- **Other checks:**
  - gdlint is clean on every changed `.gd` file, and pyflakes on the Python;
  - the headless editor parse has 0 errors;
  - `git diff --check` is clean, including the new files;
  - `fetch_models.py --verify` verifies 229 files.

### Risks / follow-up

- **Preview only**, as before. The Dining Hall has no NPC.
- **Pre-existing exit reach (both looks, not changed here):** the main door's own footprint (from y 955.85) stops a player 14.2 px from `EXIT_RECT` (top y 970) in the middle of the doorway, just past the 14 px contact band. The way back to the Hall is therefore offered only near the doorway's jambs.
  - The capture stands at the west jamb.
  - A one-line game fix would be `EXIT_RECT` from y 968, or the footprint a few px shorter; it needs the user's approval because it changes gameplay.
- **The door rule:** each Hall door must look like its room's door seen from inside. The Hall's Dining door is still the stage-47 design, so when the HD art moves into the game, one follows the other.
- **Real size (open):** stage 58 recorded a rule to build furniture at real size against the 1.4 m detective, after the user found the Chemistry table too big (4.8 × 4.4 m). That rule postdates stage 56's direction and is not yet reviewed.
  - This stage keeps the painting's proportions, as stage 56 did: the banquet table is 5.1 × 2.8 m for eight places, the clock 3.8 m tall.
  - If the user finds them too big, shrink them and the chairs as stage 58 did. The preview's footprint swap would then need to handle the Dining Hall's `RectangleShape2D` collisions (it only swaps `CollisionPolygon2D` today).
- **Shared files:** the six changed pipeline files and the model manifest are shared with the parallel sessions; only the Dining Hall entries and the `overhead`, `rect_shapes` and `rects` options are this stage's.
  - The Circuit session's worktree will need a small merge in `ROOMS` and `play_prototype.gd`.
  - Stage 60 follows 58 and 59 from the other sessions. Renumber by commit order if needed.
- **Next (proposed):** the user's review of the Dining Hall; then the Final Room, after Circuit.

### GitHub documentation proposal

- Note stage 60 in `docs/PROJECT_STATUS.md` (done locally): the Dining Hall rebuilt from its painting, with its chandelier hung above everyone.
- Also add the Greenhouse line (stages 54 and 56), done locally.

---

## Stage: UX-20261021-59 (Library floor and gate)

- **Date:** 2026-10-24
- **Status:** built and verified, awaiting the user's review. Nothing ships: the game, its scenes, its saves and the Web build are unchanged.
- **Request:** the user's review of stage 57: "很好，就是地板和大门还需要优化" (very good, only the floor and the gate still need work).
- **What was wrong in stage 57:**
  - **Floor:** one large-tile photo printed across the whole room, so it read as a grey sheet with no flags. The rugs were plain fields with a faint lozenge, the stair foot was bare, and the floor ran under a flat slab band 26 px high across the whole south of the screen.
  - **Gate:** the Hall's Library portal shrunk into a narrow gap in that slab, its leaves standing open on a lit fanlight, between two crystal pillars.
- **What changed:** both are now built from the painted room's own design (`assets/backgrounds/library_archive.png`), as stage 56 did for the Greenhouse.
- **Parallel work:** stage 58 (the Chemistry restyle) was written by another session in the meantime. Renumber by commit order if needed.

### What changed

- **Floor (`flagstones()`):**
  - 846 dark flags laid in courses as the painting lays them. Rows run 18–32 px deep, stones are 24–62 px wide with their joints staggered, and about a fifth of the large flags run two courses deep.
  - Each flag is a slab with a narrow chamfer and an occasional chipped corner, tipped a hair so no two catch the light alike. Each shows its own part of the CC0 `seaside_rock` photo in its own shade, between a slate grey and a warm grey, and is mottled; 54 carry a crack.
  - Thin dark grit shows in the joints (`floor_bed()`). The flags go round the optical array's plate, the medallion and the cobbles, and stop short of the cases, the dais and the stair.
  - Its tone in the open aisles is within a few levels of the painting's, with similar contrast (for example 48/36/36 against the painting's 49/41/36 in the west aisle).
- **Cobbles (`cobbles()`):** the painting's patch of worn cobbles at the foot of the dais stair. 75 irregular stones are packed in a Voronoi pattern, each a low dome in brown and grey from the CC0 `rock_surface` photo; the spectrum window's rainbow now falls on them.
- **Rugs (`rug_material`):** the painting's ornament on every rug.
  - Each has a dark border band strung with gold dots between gold lines, and a guard of small dots.
  - Runners carry gold rosettes down the middle, with sprigs and small flowers between them.
  - Carpets carry a centre rosette in a double lozenge, corner rosettes and a lattice of small flowers.
  - The gold is quieter than stage 57's.
- **South front (`south_front()`):** the floor now ends where the room ends. A coping of pale dressed stone runs along the collision's south edge, and below it the dark ashlar wall drops two courses and fades into the dark (`laid_stone(..., fade=...)`). The flat slab band and its lit lip are gone.
- **Gatehouse (`gate()`):** the painting's gate at the corridor's end, standing forward of the south front, replacing the Hall portal and the crystal pillars.
  - Two stout piers with pale caps, and lower outer piers. A Library banner (deep blue edged in gold, a gold cross in a ring, a pointed foot) hangs on a brass rod between each pair.
  - A sconce of two candles either side of the door, lighting the stone warmly.
  - Slim pilasters carry a gabled hood of dark stone with a pale lip, with the Library's open book in brass under its peak.
  - Under it, a pair of oak doors in a Tudor-pointed arch. They are framed and panelled, each with a brass ring above and a brass star below, studded rails and two pulls at the meeting stiles.
  - A threshold and three widening steps go down toward the camera into the dark.
  - It stays out of the depth pass, so a player at the door shows in front of it, as the painted one does.
- **Awakened state:** the gate's banners glint gold with the archive's other brass; the glyph lines and the medallion lie on the new floor.
- **Code:** `room_library.py` alone.
  - New: `laid_stone`, `flagstone_material`, `joint_material`, `void_material`, `pale_stone`, `dressed_stone`, `ashlar_stone`, `gate_oak`, `banner_material`, `floor_bed`, `south_front`, `free_spans`, `lay_courses`, `flagstone`, `flagstones`, `clip_half`, `cobbles`, `tudor_arch`, `ashlar`, `gate`.
  - Removed: `south_wall`, `south_pillars` and `portal`.
  - Its lines are folded to 120 characters like its sibling modules, a layout-only change checked by comparing ASTs.

### Exact files

- **Changed:** `tools/blender/room_library.py`.
- **Evidence:** `docs/evidence/2026-10-23-blender-library/`.
  - `01`–`14` are re-shot.
  - The new `15-restyle-floor-and-gate.png` shows the painted room, stage 57 and this pass side by side at the gate, along the floor's south edge and on the cobbles under the rainbow.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- **No new third-party assets:** `seaside_rock` and `rock_surface` are CC0 Poly Haven textures already in `cc0_textures.json` (added by the Greenhouse and Chemistry sessions).

### Verification

- **Blender 5.2.2, 128 samples, 2896×2172:**
  - dormant: 357 s (room pass 247 s, under load from other sessions), 4546 objects, 49 glows, 20 props;
  - awakened: 143 s, 4552 objects, 57 glows.
- **Capture:** `capture_library.gd` passes 141/141 in EN and in ZH, re-run on the new render: props, highlight boxes, reach, markers, plate, depth, light, establishing shot and awakening.
- **Depth:** the doorway column hides nothing from y 920 to 1030, and three towers still hide a player behind them (45, 12 and 26 rows).
- **Other checks:** `tests/library_knowledge_access_test.gd` passes. pyflakes is clean; the headless editor parse has 0 errors; `git diff --check` is clean.

### Risks / follow-up

- **Preview only**, as before.
- **The gate is not a Hall door:** the handoff's door rule asks that each Hall door look like its room's door seen from inside. The Hall's Library portal is still the stage-47 design, so when the HD art moves into the game, either the Hall's Library door follows this gatehouse or the reverse.
- **Next (proposed):** the user's review of the floor and the gate.

### GitHub documentation proposal

- Note stage 59 in `docs/PROJECT_STATUS.md` (done locally): the Library's floor laid flag by flag and its painted gatehouse.

---

## Stage: UX-20261021-58 (Chemistry restyle)

- **Date:** 2026-10-24
- **Status:** approved by the user ("很好"), committed and pushed as `aadec6c`. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user's review of stage 55 (committed and pushed as `9bb97b8`): "中间的桌子做的太大了，而且每个桌子的质感都不好，地板也是，没有让人惊艳的感觉，需要优化" (the middle table is too big, every table's material is poor, the floor too; nothing stunning; optimise it).
- **Parallel work:** the Greenhouse (stages 54 and 56) and the Library (stage 57) are being built in this checkout by other sessions.

### What changed

- **The table is a real table, and the floor around it is free.**
  - Stage 55 filled the painted table's whole footprint, 481 × 336 px (4.8 × 4.4 m, about three times the detective's height each way).
  - The HD table is now 390 × 165 px (3.9 × 2.2 m), centred where it was.
  - The preview swaps its footprint into the room's collision while the HD room is staged, and gives the painted one back on restore. The player walks round the smaller table, and its prompt and focus box follow it.
- **The table follows the painting's own design** (the lesson the Greenhouse's stage 56 recorded):
  - heavy worn oak on turned legs with bun feet, an H-stretcher and a pot-board holding books, a copper pan and a crate of bottles;
  - a drawer front with brass ring pulls and violet enamel lozenges between the drawers;
  - a top of boards between breadboard ends, with a raised rim and brass corner caps.
  - **On it, as painted:**
    - the great glass still in the middle: a globe in a brass ring over a spirit burner, five glass arms running down into small receivers;
    - an oil press, a tall amber flask, a dark flask on a stand, a three-candle brass candleholder and a spired globe along the back;
    - yellow-green bottles, a rack of violet vials, iron tongs and strewn glass beads;
    - at the south-east corner, the red spill running over the edge in drips to the floor.
  - **The blue coat:** someone's coat with a buckled leather strap, dropped over the front edge with the cloth solver.
  - **A great rug** stands under the table: burgundy field, crimson and indigo medallion, indigo border of running diamonds between gold guards, fringed ends, worn where feet cross it.
- **Wood that reads as old oak** (every table, counter, bench, cabinet, rack and door):
  - a new CC0 worn-tabletop photo (`wood_table`, Dimitrios Savva), graded warm and dark;
  - each piece takes its own part and shade of the photo, so no two boards read as one printed sheet;
  - edges are worn paler, grime sits in the corners, and a waxed coat catches the candles.
- **Flagstones laid one by one, as the painting draws them:**
  - 829 square-cut stones in east-west rows of mixed lengths, so their joints stagger;
  - each stone a chamfered slab, turned and tipped a little, with its own part and shade of a CC0 rock photo (`rock_surface`, Amal Kumar) graded lavender-grey, and its rim worn paler;
  - dark mortar in the sunken joints; 36 stones cracked.
  - This replaces one tiled photo across the whole floor.
- **Light:** the fire, the sconces, the candles and the lanterns carry the room; the moon only fills what they leave dark. Mean luminance is 30.4, against 31.2 before; the brightest 1 % is brighter (p99 108 vs 94).
- **The stain:** brighter red, with longer, wider streaks thrown south-west that break into drops at their ends; it lies over the rug where they meet.

### Pipeline (shared, backward compatible)

- **Inside-out meshes:** `room_prototype.mesh_from` now turns every closed mesh island right way out by its signed volume, after Blender's `recalc_face_normals`.
  - That call left closed boxes inside out depending on where they stood. For example, the same box at y 352–688 came out right, but at y 445–610 came out inverted.
  - A cloth collider facing inward pulls the cloth through it, which is why the coat fell through the table.
  - The Wake Room re-renders identically with the fix: mean difference 0.01 per channel, depth map 100 % identical.
- **Footprint swap:** a room's `build()` may return `"collision"` (`{polygon node path: world px points}`). `room_prototype.py` writes it to `render.json`, and `prototype_room.gd` swaps those polygons in on `apply()` and back on `restore()`.
- `cc0_textures.json`: `wood_table` and `rock_surface`.

### Exact files

- **Changed:**
  - `tools/blender/room_chemistry.py`: the `laid` photo material, aged oak, flagstone and grout; the laid floor; the real-size table and its apparatus; the rug; lights; the footprint.
  - `tools/blender/room_prototype.py`: `_turn_islands_outward`, `collision` in `render.json`.
  - `tools/blender/prototype_room.gd`: the footprint swap.
  - `tools/blender/capture_chemistry.gd`: footprint checks; each look's own walk-up spots and shots.
  - `tools/blender/cc0_textures.json`: two textures.
- **Evidence:** `docs/evidence/2026-10-23-blender-chemistry/`, regenerated:
  - `01`–`09`: painted vs HD pairs;
  - `10`–`12`: the overview, the render over its collision (the HD table's own footprint) and the props;
  - new `13-restyle-table-floor.png`: before, after and the painted room.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Blender 5.2.2 (Cycles Metal):** the final render takes 125 s at 128 samples (the room pass 93 s). It builds 1843 objects with 28 glows; the coat simulates in about 9 s.
- **Capture:** `capture_chemistry.gd` passes 86/86 in EN and in ZH.
  - New: the HD room swaps the table's footprint in; the freed floor beside it is open; the table itself still blocks; the painted footprint comes back on restore.
  - Each interaction is offered from each look's own walk-up spot.
  - North of the table, it covers the player to the shoulders.
- **No regressions:** `capture_room.gd` (Wake Room) passes 65/65; its capture folder was restored afterwards. A Wake Room re-render matches its committed render.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean.
- **Playable preview:** `play_prototype.gd -- --chemistry` stages the room with 28 glows, 2 HD props, depth and 2 HD character sheets, and no script errors.

### Risks / follow-up

- **Preview only:** the game's own Chemistry Room, its painted table and its collision are unchanged. Moving the HD room into the game means moving the table's collision with it.
- **NPCs:** the butler and Dr. Lin's echo are still the pixel NPCs.
- **Next:** the user's review, then the butler and Dr. Lin's echo in Tripo (the user's choice), then the Dining Hall.

## Stage: UX-20261021-55-circuit (Circuit bench, floor and gate)

- **Date:** 2026-10-24
- **Status:** built and verified, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user's verdict on stage 54-circuit: "感觉桌子和地板需要修复，而且下方需要加一个符合房间特色的大门" (the bench and the floor need fixing, and a big gate in the room's own character should be added at the bottom).
- **Where:** the same branch and worktree as stage 54-circuit (`agents/circuit-room-blender`, base `ddcbc66`), still uncommitted.
- **Numbering:** provisional, like stage 54-circuit. The main checkout has since used 54 (Greenhouse), 55 (Chemistry, committed as `9bb97b8`), 56 (Greenhouse door, bench and floor) and 57 (Library). Give both circuit stages the next free numbers on merge.

### What was wrong (stage 54-circuit)

- **Bench:**
  - The top was one even, dark board.
  - The pale pegboard fought the room.
  - The glove read as a hand and the pliers as two crossed lines.
  - The rag read as a folded paper.
  - The console was a plain dark box.
- **Floor:** big, even slate squares read as a modern tiled floor, flat in tone, not as the castle's flagstones.
- **Exit:** the runner ran out between the pillars into the dark, with no door at the room's bottom edge.

### What changed (`tools/blender/room_circuit.py`)

- **Workbench** (`workbench()` rebuilt; new helpers `shift_uvs`, `wedge`, `lying`, `glove`, `pliers`):
  - **Top:** seven oak planks in three tones, their UVs shifted so no two match, with oil stains. It has a riveted steel nosing along the front, iron corner brackets, a vise, and drawers with brass pulls.
  - **Shadow board:** dark green, with cream painted outlines. The cutters' outline is empty, the one missing tool.
  - **Instrument console:** walnut-toned oak.
    - A sloped desk with toggles and pilot lamps, and a riser with two dials.
    - Plate 3's flush cover sits where `CircuitLayout` draws the master plate.
  - **Lying on top:**
    - a glove cut to a hand's outline, with a violet cuff;
    - real pliers, wire coils, a soldering iron and a screw tin;
    - the lantern;
    - a rag dropped over the front edge with cloth simulation.
- **Floor** (`flagstones()`):
  - Castle flagstones of mixed sizes laid in courses (CC0 `rock_tile_floor`), graded, with patches of tone.
  - The grates, mains, chalk and oil stay. The runner now ends just behind the gate.
- **Gate** (`exit_gate()`):
  - **Portal:** the Hall's stone portal (`build_portal`) at 2.8 times its size, 14 Hall px each side of the doorway.
    - It stands across the passage at x 698.5, its foot at plan y 1090, just past the room's south edge.
    - Crest, plaque and lit passage are left off.
  - **Shut:** two leaves of riveted steel plate under a brass seal with the Circuit bolt on enamel, and a brass lock bar.
  - **Electrical:**
    - porcelain insulators on iron brackets on both jambs carry a copper bus over the arch on porcelain stand-offs;
    - a blue indicator lamp sits in a brass cup on each jamb.
  - **Light:** the blue fanlight is dimmed to matte at this size. A warm key from the floor in front and a blue fill light it.
  - **Facing:** it faces the camera, as the Hall draws a door reached from the north. A player walking out is seen behind it as the depth pass's ghost, as at the Wake gate.
  - **Clearance:** its top stands at screen y 939, below the arrival spawn (724, 930), so neither a player coming in nor the shadow at their feet is hidden.
    - The first cut stood at y 1076, and its top covered the spawn's feet by 6 rows.
- **Capture** (`tools/blender/capture_circuit_room.gd`):
  - shot `01-room` now stands the player on the game's own `PLAYER_SPAWN_POSITION`;
  - a new check: nothing hides a player at the spawn or the shadow under their feet (111 checks).
- **Textures:** `rock_tile_floor` (Charlotte Baglioni) added to `tools/blender/cc0_textures.json`. `monastery_stone_floor` was tried and dropped.

### Exact files

- Changed:
  - `tools/blender/room_circuit.py` and `tools/blender/capture_circuit_room.gd` (both new in stage 54-circuit, still untracked)
  - `tools/blender/cc0_textures.json`
  - `docs/AGENT_HANDOFF.md`
  - `docs/PROJECT_STATUS.md`
  - this report
- Evidence, regenerated in `docs/evidence/2026-10-24-blender-circuit-room/`:
  - `01`–`11` recaptured;
  - `12-render.png` re-rendered;
  - new: `13-bench-floor-gate-before-after.png`. Its left column is stage 54-circuit's render with its bench prop; its right column is this stage's.
- Local only: `prototypes/blender_rooms/circuit_room/` re-rendered and recaptured.

### Verification

- **Blender:** the final render (128 samples, 2896×2172) takes 142 s in all, with 1044 objects, 15 glows and 8 fixtures.
  - The three HD props stand on their collision rectangles within 4.1 px (Workbench 382 × 301 at (446, 439.5)).
- **Depth,** measured over every feet position the player's 14 × 8 body can reach from the spawn on the collision mask (569,879). The map hides the player only:
  - north of the exit pillars (13,350);
  - in the low south wall's band, y 943–967 (17,359);
  - walking out down the passage behind the gate, feet y 939–1085 (15,589);
  - in a strip under the south wall, outside the room, reached only from the foot of the exit passage (19,488; see risks).
- **Room capture:** `capture_circuit_room.gd` passes 111/111 in EN and in ZH.
- **No regression:** `capture_room.gd` (Wake Room) passes 65/65.
- **Tools:**
  - gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean on `tools/blender/*.py`;
  - the headless editor parse (isolated HOME) has 0 errors;
  - `git diff --check` is clean;
  - `fetch_textures.py` verifies all 51 maps.

### Risks / follow-up

- **Preview only:** the HD room shows only in the prototype preview. The Mechanic is still the pixel sprite.
- **Gate:** the gate is drawn shut. A player stepping into the exit rect is seen behind it as a ghost before pressing E, the Wake gate's convention.
  - Doors that swing (`prototype_doors.gd`) are a Hall-only feature for now.
- **Pre-existing collision gap:** the room's `BottomLeftWall` and `BottomRightWall` polygons stop 18–28 px short of the room's bottom edge, and `room_size` limits only the spawn and the camera.
  - A player who walks on past the exit prompt can follow that strip under the south wall, in the painted game too.
  - The HD depth map ghosts them there. Not changed here.
- **Merge:** besides stage 54-circuit's shared files, `cc0_textures.json` now also conflicts with the main checkout's additions; keep both sides' assets.
- **Next (proposed):** the user's verdict on the bench, floor and gate. Then the Mechanic in Tripo, or the next room.

### GitHub documentation proposal

- README / project page: none until the user accepts the style. Then show the Circuit Room beside the Wake Room under "Blender HD rooms (preview)", with `01-overview.png`.

---

## Stage: UX-20261021-54-circuit

- **Date:** 2026-10-24
- **Status:** built and verified, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** "你现在重新搭建electric_room，用blender搭建，风格向大厅看齐。保持审美优化" (rebuild the electric room in Blender, in the Hall's style, keeping the aesthetics refined). "electric_room" is the Circuit Room (`scenes/floor_1/circuit_room.tscn`, 电路室).
- **User's choices:**
  - work in a new, separate worktree, because a parallel session was building the Greenhouse in the main checkout;
  - the room only: the Mechanic stays the pixel sprite until his Tripo model.
- **Where:** branch `agents/circuit-room-blender` at `/Users/yaleshen/shadow-castle-stem-detective.worktrees/circuit-room-blender`, cut from `main` at `ddcbc66` (stage 53). Uncommitted, as the handoff requires.
- **Numbering:** this stage was numbered provisionally. The Greenhouse session may also have taken 54; renumber on merge.

### What changed

- **The room** (`tools/blender/room_circuit.py`), rebuilt on the room's real collision (1448 × 1086, rendered at 2 px per px) with the Hall's floor, wall stone, wall tops, banners and moonlight:
  - **Switchboard** along the back wall, standing exactly on the collision's slanted front:
    - five framed slate sections: feeder knife switches under gauges, the regulator with a rheostat, resistor coils, a fuse bank with one fuse blown black, and the burnt bus;
    - the burnt bus sits in sooted, cracked slate, its west bar snapped and bent, with a blue arc jumping the gap at the game's `BROKEN_BUS_POSITION`;
    - louvred steel doors below, a slate counter with brown-glazed insulators, bus bars on stand-offs along the top, and two brass picture lights.
  - **Maintenance door:** iron and riveted, left ajar in an arched opening, with the Circuit emblem (the Hall's bolt) above it.
    - Dusty boot prints run from it to the burnt section; porcelain shards lie under the shattered stand-off.
  - **Equipment cabinet** (`Worldsort/Cabinet`): riveted dark-enamelled iron, a padlocked locker door with bright scratches round the keyhole, and the flush junction cover where plate 1 is drawn.
    - The loose access panel sits askew with one screw gone.
    - On top: a coil of violet-wrapped cable, a toolbox and an oil can.
  - **Workbench** (`Worldsort/Workbench`): worn oak with drawers.
    - The shadow board has one painted outline left empty.
    - The diagnostic console holds plate 3's flush cover, a galvanometer and binding posts.
    - The open journal carries a sketched circuit and an oil smudge. One glove has a violet cuff. Also: pliers, wire, a soldering iron and the oil lantern.
  - **Dynamo** (`Worldsort/Generator`) on a stone foundation with a tread-plate bedplate and a brass rail:
    - flywheel, two field coils under an iron yoke, the armature, the commutator and its brushes;
    - the regulator housing with plate 2's flush cover;
    - a glass arc chamber with a violet core;
    - the Prism Dust tray.
  - **Light:** five caged bulb lamps, each with a warm floor pool; moonlit lancet windows in both side walls, with beams across the floor; the arc, the chamber and the bench lantern.
  - **Floor:** violet-lit grates, copper mains with flanged collars, the circuit chalked on the flagstones, oil and soot, and the runner out.
  - **Exit:** two stone pillars on the collision's own line, each with a capstone, a Hall lantern and the castle banner, and the Hall passage's cold light beyond.
- **The pipeline** (shared, backward compatible; the Wake Room re-renders the same):
  - `export_room_layout.gd` exports a `RoomInteractionRuntime` room:
    - its props by node path, their `FurnitureCollision` rectangles (solid in the mask), its `INTERACT_ITEMS`;
    - named script constants (the light fixtures, the exit).
  - `room_prototype.py`:
    - a south wall may have a doorway (`openings`);
    - prop roots follow the layout's node paths;
    - `build()` may add `render.json` metadata.
  - `prototype_room.gd`:
    - stages the Circuit Room;
    - moves the room's own light rig (`ambience_layer`: 5 wall lamps, the bench lantern, the chamber glow and both arc emitters) onto the HD fixtures listed in `render.json` `fixtures`, and puts it back on restore.
    - The game's brown-out and power-restored lamp states and arcing therefore play on the HD room.
  - `prototype_depth.gd`, `prototype_characters.gd`: find a player kept under `Worldsort/`.
  - `capture_circuit_room.gd`: new native capture (109 checks).
- **Textures:** 3 more CC0 Poly Haven sets in `tools/blender/cc0_textures.json` with authors and checksums: `green_metal_rust` and `metal_plate_02` (Rob Tuytel), `slate_floor` (Dimitrios Savva).

### Aesthetic passes (the final is the left column of `13-bench-floor-gate-before-after.png`; the folder's other images now show stage 55-circuit)

1. **First pass:** too cold and even, with the room lit grey by the moonlight. The lamps were spots without pools, and the arc chamber's core clipped to white. The exit piers were 186 px deep tiled boxes, the floor pipes read as thin rails, and oil stains read as holes.
2. **Final pass:**
   - the exposure comes down (the moonlight stays the Hall's), and the lamps are brighter with floor pools;
   - the core is violet;
   - the piers became lit pillars on the wall line, with banners where they show;
   - the mains are thicker, with collars;
   - the oil is a soft gloss, and the cabinet iron, pegboard and chalk are quieter.

### Exact files

- New:
  - `tools/blender/room_circuit.py`
  - `tools/blender/capture_circuit_room.gd` (+ `.uid`)
  - `docs/evidence/2026-10-24-blender-circuit-room/` (`01`–`10` painted vs HD at 1024×768, `11-hd-detective.png`, `12-render.png`)
- Changed:
  - `tools/blender/export_room_layout.gd`
  - `tools/blender/room_prototype.py`
  - `tools/blender/prototype_room.gd`
  - `tools/blender/prototype_depth.gd`
  - `tools/blender/prototype_characters.gd`
  - `tools/blender/play_prototype.gd` (doc line)
  - `tools/blender/cc0_textures.json`
  - `docs/AGENT_HANDOFF.md`
  - `docs/PROJECT_STATUS.md`
  - this report
- Local only (gitignored, regenerable): `prototypes/blender_rooms/circuit_room/` (layout, render, depth, props, captures).

### Verification

- **Blender:** the final render (128 samples, 2896×2172) takes 131 s in all, with 917 objects and 11 glows.
  - The three HD props stand on their collision rectangles within 4.1 px (the walk-up rule allows 7.5).
  - The depth map hides reachable floor only where it should: north of the exit pillars (11,771 px) and in the low south wall's band (9,981 px). The one exception is a 20 px sliver at the switchboard's east end, out of 542,423 reachable px.
- **Room capture:** `capture_circuit_room.gd` passes 109/109 in EN and in ZH. It checks:
  - props staged on their collision;
  - focus boxes and feet follow the HD props and go back;
  - each prop, plate, the Mechanic and the exit offered where the game puts them, in both looks;
  - plates drawn on their HD housings;
  - all 9 light-rig nodes on their HD fixtures, through the power restoring and back;
  - pillar occlusion and open floor;
  - the HD detective's size, idle and run.
- **No regression:** `capture_room.gd` (Wake Room) still passes 65/65. Rebuilding the Wake Room through the changed `room_prototype.py` gives the same prop roots, with rects within 1 px (sampling).
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean on `tools/blender/*.py`. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.

### Risks / follow-up

- **Preview only:** the HD room shows only in the prototype preview.
- **Mechanic:** still the pixel sprite, which stands out in the HD room until his Tripo model.
- **Merge:** shared pipeline files (`export_room_layout.gd` `ROOMS`, `prototype_room.gd` `ROOMS`, `room_prototype.py`, `cc0_textures.json`) and these docs will conflict with the Greenhouse session's edits in the main checkout. The changes are additive; keep both rooms' entries.
- **Next (proposed):** the user's verdict on this style. Then the Mechanic in Tripo (his HD portrait follows from the model), or the next room in the planned order.

### GitHub documentation proposal

- README / project page: none until the user accepts the style. Then add the Circuit Room to the "Blender HD rooms (preview)" mention beside the Wake Room, with `01-overview.png` as the image.

---

## Stage: UX-20261021-57 (Library)

- **Date:** 2026-10-24
- **Status:** built and verified, awaiting the user's review. Nothing ships: the game, its scenes, its saves and the Web build are unchanged.
- **Request:** "你现在负责libary 优化，用blender重新搭建，风格向大厅看齐，保持风格，让玩家游玩起来感觉惊讶" (rebuild the Library in Blender in the Hall's style, keep that style, and make playing it surprising).
  - The user chose this checkout, a preview-only room like the Wake Room, and all five surprises offered: the archive awakening when the RGB puzzle is solved, moonlight shafts with dust and a prism rainbow, a two-storey gallery, light-test lamps that follow progress, and an establishing shot on first entry.
- **Parallel work:** the Greenhouse (54, 56) and Chemistry (55) sessions edit the same shared files; this stage only adds to them. Renumber by commit order if needed.

### What the room is now

- **Built like the Hall:** the Hall's moonlight and wall tops, flagstones and slate from the same CC0 photo sets, worn warm oak and leather books. The gate is the Hall's own Library portal (`hall.build_portal`: book emblem, warm fanlight), seen from inside.
- **On the game's own collision** (1448×1086; the camera still follows the player). All 28 interactions are the game's own, and the 20 cases and desks stand on their own collision rects. Their `Worldsort/` nodes keep legacy names; `room_library.py` maps each to what it now is.
- **North, the reading bay:** a dais up a stair with balustrades, two violet reading chairs, a long-case clock, candle stands, and a spiral stair to the gallery.
  - Behind it, the **spectrum window**: seven bands of coloured glass under a rose. Its light falls as a rainbow down the steps and across the floor.
  - Either side stand **two pairs of great lancet windows** in stained glass, blue-violet in the west and green in the east. Their moonlight lands on the cases before them.
- **Two storeys:** gallery wings 112 px up on either side of the bay. Their bookcases (the reading case and the jar case) stand on the deck.
- **The archive:**
  - bookcases dressed with books, scrolls, boxes, candles and lanterns;
  - five archive towers with brass emblems (ring, compass, hourglass, wheel, crossed ring, clasp);
  - the apothecary cabinet, the archive drawers and the chained case;
  - the violet reflection cabinet and the additive archive.
- **The three light tests,** each a desk with its own lamp:
  - red at the research desk, with its spectroscope;
  - green at the Reflection Matrix in the east;
  - blue at the Additive Relay in the west, by the globe.
- **The floor:**
  - a violet carpet under the research desk, navy runners down the aisles and wine rugs under the desks;
  - the optical array, a flush brass plate whose lens beds lie under the game's three filters;
  - before the gate, the RGB medallion of three overlapping circles.
- **South:** the low wall, with the gate between two violet crystal lamps.
- **Awakened** (`LIBRARY_STATE=awakened` writes `render-awakened.png`):
  - pale light from the optical array;
  - the medallion's circles adding red, green and blue up to white;
  - the cases' brass emblems burning gold, and glyph lines running from the array to the three light tests;
  - the hidden archive text glowing on the floor and round the spectrum window.

### The living light (preview layer, `prototype_library.gd`)

- **Moonlight shafts:** 12 additive shafts (4 lancets, 7 spectrum bands and the rose) run from each window to where Blender cast its light through the built room. They breathe slowly, and 123 motes of dust drift down them.
- **Light-test lamps:** each desk's lamp is dim while its test is dormant, brighter once its knowledge is filed, and steady once its filter is earned. It flares as it rises.
- **The awakening:** seating the third filter sets `library_rgb_puzzle_solved` through the game's own flow.
  - The game's ignition and reward card play first.
  - Then the awakened archive spreads from the optical array across the room behind a bright rim (2.8 s). Meanwhile the camera draws back to the whole archive, holds, and returns to the detective (5.7 s in all).
  - The awakened render's 56 glows light as the rim reaches them.
  - A save already solved shows the archive awake at once, without the shot.
- **The establishing shot:** the first time the Library loads in a run, the camera opens on the whole archive (zoom 0.71).
  - The title reads "THE ARCHIVE OF LIGHT" / "光之档案馆", with "ASHFORD CASTLE · LIBRARY" / "阿什福德城堡 · 图书馆" beneath. It is set in the archive UI's pixel face, gold and parchment over a brass and violet rule, on the dark south wall.
  - After 1.1 s the camera glides down to the detective (2.2 s).
- **Shots and input:** while a shot plays, the detective stands still and the room's prompts wait. Any key or click skips it. The prompts return only once every key is up, so the key that skipped the shot does not also act in the room.
- **Markers and plate:**
  - The knowledge-shelf and light-test markers are seated on the HD cases.
  - Over the HD plate, the game's flat optical plinth, inlays, frames and scanner housing are hidden. Its filters, beams, rings, glyphs, caption and light stay the game's own.
  - Restoring puts all of it back.

### Pipeline additions (shared, backward compatible)

- `prototype_room.gd`:
  - The Library joins `ROOMS`.
  - A new `EXTRAS` table gives a room its own living layer (`attach(room, look)`, `apply`, `restore`, `advance`, `summary`). It is loaded at runtime with `load()`, so one room's layer cannot stop another from staging. Its summary joins the room's.
- `play_prototype.gd`:
  - `-- --library` opens the Library at its door.
  - `-- --library-ready` opens it with its three light tests passed, so seating the filters at the optical array awakens it.
- `export_room_layout.gd`: the `library_room` entry (its 20 `Worldsort/` props and `INTERACT_ITEMS`).

### Exact files

- **New:**
  - `tools/blender/room_library.py`: the room in both states, and `render-library.json`.
  - `tools/blender/prototype_library.gd` (+ `.uid`): the living light and the shots.
  - `tools/blender/capture_library.gd` (+ `.uid`): 141 checks and the captures.
  - Evidence: `docs/evidence/2026-10-23-blender-library/`:
    - `01`–`07`: painted vs HD pairs at native 1024×768 (arrival, optical array, spectrum window, west aisle in ZH, east aisle, behind a tower, the gate in ZH);
    - `08-establishing-shot.png` (EN and ZH), `09-glide-and-lamp.png`, `10-awakening.png` (four frames);
    - `11-awakened-array.png` and `12-awakened-window.png`: painted vs awakened HD;
    - `13-dormant-and-awakened.png` and `14-render-on-collision.png`.
- **Changed (additions only):** `tools/blender/prototype_room.gd`, `tools/blender/play_prototype.gd` and `tools/blender/export_room_layout.gd`.
- **Depends on the Greenhouse and Chemistry sessions' uncommitted work:**
  - `roots` and `in_room` in `room_prototype.py`;
  - the `"props"` and `"items"` export in `export_room_layout.gd`;
  - the `Worldsort/player` lookups in `prototype_depth.gd` and `prototype_characters.gd`;
  - their `ROOMS` entries and flags in `prototype_room.gd` and `play_prototype.gd`, beside which this stage's lines sit.
  - Commit this stage with or after stages 54–56.
- **Docs:** this report, `docs/AGENT_HANDOFF.md` and `docs/PROJECT_STATUS.md`.
- **Generated, gitignored:** `prototypes/blender_rooms/library_room/` (layout, collision, both renders, depth, props, glows, `render-library.json`, captures).
- **No new third-party assets:** the textures are the Hall's and the Wake Room's CC0 Poly Haven set, already in `cc0_textures.json`. The title uses the project's own Fusion Pixel font (OFL).

### Verification

- **Blender 5.2.2 (Cycles Metal), 128 samples, 2896×2172:**
  - dormant: 155 s (room pass 86 s), 4448 objects, 48 glows, 20 props;
  - awakened: 94 s, 4454 objects, 56 glows.
- **Capture:** `capture_library.gd` passes 141/141 in EN and in ZH.
  - **Props:** all 20 cases and desks are staged on their own nodes. Every highlight box follows its HD art and returns to the painted one.
  - **Reach:** each knowledge shelf is chosen from at least 100 open spots (119–372). Each shelf and light test is chosen from at least 80% as many spots in HD as in the painted room: the writing desk from 116 against 132, every other from as many or more. The six markers sit on the HD cases and go back.
  - **Plate:** the HD plate shows under the game's filters, and the game's plate comes back.
  - **Depth:** three towers hide a player behind them (12–45 rows). The arrival, the gate and the open floor hide no one, and the gate still offers the way out.
  - **Light:** 12 shafts and 123 motes show in HD only, and the dust drifts. The three lamps read dormant, primed (each flaring) and solved.
  - **Establishing shot:**
    - it opens on the whole archive, holds the detective and the prompts, and ends on the room's camera;
    - a key skips it without also taking the gate;
    - it plays once by itself.
  - **Awakening:**
    - two filters leave the archive dormant, and the third solves the puzzle in the game's own flow;
    - the archive waits for the reward card, then spreads as the camera draws back;
    - the camera returns with the detective free to walk;
    - staged again, the solved archive shows awake at once.
- **No regressions:**
  - `capture_room.gd` 65/65, `capture_chemistry.gd` 80/80 and `capture_greenhouse.gd` 89/89 (EN). They re-shot those rooms' gitignored capture folders.
  - `tests/library_knowledge_access_test.gd` passes.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean, and the new files have no trailing whitespace.
- **Playable preview:** `play_prototype.gd -- --library-ready` stages "48 glows, 20 HD props, depth true, 2 HD character sheets; 12 shafts, 123 motes, 3 lamps, awakened render true". It shows no script errors, and its exit-time leak count equals the Chemistry preview's.

### Risks / follow-up

- **Preview only:** the game's own Library is unchanged. The establishing shot plays once per run (a static flag); in the game it needs a saved story flag.
- **The reward card:** the awakening waits for the card by reading `ItemRewardHud`'s `_panel` and `_queue`. If those change, it falls back to a 5 s cap.
- **Legacy node names:** the 20 `Worldsort/` names no longer match what the pieces are (`TopLeftCabinetB` is a gallery bookcase); `room_library.py` maps them.
- **Side walls are edge-on at 40°:** decoration on them hardly shows, so they carry lamps and low cabinets only.
- **Next (proposed):** the user's review of the Library (the look, the shots' timing, the title's wording). Then the next room in order: the Circuit Room (mechanic), the Dining Hall, the Final Room.

### GitHub documentation proposal

- Add stage 57 to `docs/PROJECT_STATUS.md` (done locally): the HD Library, preview only, with its living light, awakening and establishing shot, linking `docs/evidence/2026-10-23-blender-library/`.

---

## Stage: UX-20261021-56 (Greenhouse door, bench and floor)

- **Date:** 2026-10-24
- **Status:** approved by the user ("很好，按照你目前的优化方向的这个效果优化下一个房间", in stage 60's request); committed and pushed with stage 61, at the user's request. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user's verdict on stage 54: "门和桌子和地板需要修改" (the door, the table and the floor need changing). The stage-54 versions did not follow the painted room:
  - **Door:** the Hall's portal scaled 3.25×, a dark dungeon door between lantern piers.
  - **Bench:** a plain oak slab on a box.
  - **Floor:** a square tile photo, purple-grey and uniform; it also had a vent grate, puddles and petal confetti.
- **What changed:** all three are now built from the painted room's own design (`greenhouse_arch_door.png`, `greenhouse_workbench.png` and `greenhouse_room_bg.png`), in the Hall's materials and light.

### What changed

- **Door (`gate()`):**
  - A deep round arch of eleven dressed voussoirs and a proud keystone, on two square plinths cut with a diamond point.
  - In the arch, an oak frame with a centre post and a door each side. Each door is planked below its mid rail and glazed above it in small panes of dark green glass, with riveted strap hinges and a ring pull, on a stone threshold.
  - A bronze shield on the keystone carries the Greenhouse leaf, faintly lit like the Hall door emblem. Ivy climbs the east side, and the south wall now stops at the plinths.
  - An iron lantern on a stone post stands on the wall either side, with pink blossom along the wall's top (`gate_dressing()`), as the painting has them.
  - **Depth:** at the gate's prompt the arch now ghosts the player's legs (22 of 45 rows), as the painted shield covers them. In stage 54 the taller portal ghosted the whole figure.
- **Bench (`workbench()`):**
  - Six worn boards run across the top, each a separate piece of the photo with paler worn edges. The corners are bound in riveted iron.
  - It stands on square legs, with aprons and a slatted shelf below.
  - On it, placed as in the painting:
    - a fern in a big pot, the lantern, seedlings in small pots, seed jars, a small potted plant, the watering can;
    - a basket of picked blossom and a bowl;
    - the seedling tray, the open handbook, a stone mortar of crushed violet petals;
    - moonleaf laid on a drying rack (leaves with ribs and veins), cut herbs, twigs, dried flowers;
    - the trowel, the repair map, a pot on its side, spilt earth.
  - On the shelf: stacked pots, a basket and a bucket. The tray and drying rack stay where the game marks its two herb plots.
- **Floor (`paving()`):**
  - 353 slate pavers in north-south columns of mixed widths (36–48 px) and lengths, joints staggered, as the painting lays them.
  - Each paver is a slab with a two-step chamfered rim that catches the light, shaded and textured individually from the new CC0 `seaside_rock`. 36 are cracked.
  - Dark earth fills the joints, greening with moss toward the beds (`joints_material()`).
  - Its tone matches the painting's to within about 0.03 per channel, slightly bluer under the moonlight.
  - The floor dressing is calmer: vines creeping out of the beds, a few fallen leaves along the kerbs, petals by the beds and the gate, the spade and the bucket. The vent grate, puddles and petal confetti are gone.
- **Planter:** each lantern post now stands on a square plinth, as in the painting. The collision's bump south of the ring is that plinth, so the planter's prompt still reaches a player stopped there.

### Exact files

- **Changed:**
  - `tools/blender/room_greenhouse.py`: gate constants, `laid_photo`, `joints_material`, `Models.group`, the bench (`workbench`, `bench_wood`, `clutter`, `blades`, `shelf_things`, `wood_boxes`, `turned_box`, `turned_quad`), the gate (`gate`, `diamond`, `voussoir`, `doors`, `gate_glass`, `shield`, `gate_ivy`), the floor (`paving`, `_paver`, `floor_dressing`, `gate_dressing`), the post plinths, and `seed_jars(scale)`.
  - `tools/blender/capture_greenhouse.gd`: the gate check now asks for legs ghosted, never the whole figure.
  - `tools/blender/cc0_textures.json`: CC0 `seaside_rock` (Dimitrios Savva), its three maps with SHA-256.
- **Evidence:** `docs/evidence/2026-10-23-blender-greenhouse/`. `01`–`10` are re-shot. The new `11-restyle-door-bench-floor.png` shows the painted room, stage 54 and this pass side by side for the gate and for the bench on its floor.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`.

### Verification

- **Blender 5.2.2:** the final render takes 110 s at 128 samples (1395 objects, 64 glows).
- **Capture:** `capture_greenhouse.gd` passes 89/89 in EN and in ZH:
  - all 5 props are staged, and every highlight box follows its HD prop;
  - every prompt is offered where the player stands beside it;
  - the planter's rim hides the player's legs north of it, and the arch ghosts the legs at the gate's prompt.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean, including the new files. `fetch_textures.py` verifies all 45 texture maps.

### Risks / follow-up

- **Preview only**, as before. The gardener is still the pixel NPC.
- **Shared manifest:** `cc0_textures.json` is shared with the parallel Chemistry and Library sessions. Only the `seaside_rock` entry is this stage's.
- **Next (proposed):** the user's review of the door, bench and floor.

## Stage: UX-20261021-55 (Chemistry)

- **Date:** 2026-10-24
- **Status:** reviewed, then committed and pushed as `9bb97b8` as the baseline, with the shared pipeline changes it needs. The user asked for a restyle (stage 58): the middle table is too big, and the tables' and the floor's materials are not good enough to impress. After it, the butler and Dr. Lin's echo in Tripo. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** "可以现在继续跟改各个房间，重新使用blender建模，以及各个npc" (go on rebuilding each room in Blender, and each NPC). The user chose the Chemistry Room after the Wake Room.
- **Parallel work:** the Greenhouse (stages 54 and 56) and the Library (stage 57) are being built in this checkout by other sessions. Renumber by commit order if needed.

### What the room is now

- **Built like the Hall and the restyled Wake Room:**
  - the Hall's moonlight and exposure (0.35), and the Hall's mossy slate wall tops outlined in lit stone;
  - flagstones and slate walls from the same CC0 photo sets;
  - worn warm oak, leather books and a cloth dropped with the cloth solver.
- **On the game's own collision:** 1305×1206, the camera still follows the player through it. Every interaction (doorway, cabinet, table, red stain, butler) is still the game's own rect.
- **North:**
  - The way back to the Hall is the Hall's Chemistry portal seen from inside: quoins, eleven voussoirs, the flask emblem on an enamel plaque on the keystone, and green fan glass over oak double doors at the back of the deep alcove.
  - The arch is a half ellipse, so the doors stand taller than the detective under the 180 px wall.
  - Two stone pilasters carry iron candle bowls.
  - **The potion cabinet** (`Worldsort/ChemistryPotionCabinet`): an oak dresser with cupboards, a counter and a hutch crowded with stock.
  - **An open rack** to the east with CC0 brass goblets, vases, a lantern, a mantel clock, books and a candle, and crates and a lantern before it.
- **West:**
  - an apothecary counter that follows the slanted wall, with jars, a balance, a mortar, a tube rack, a herb basket, books and candles, and a shelf of stock on brackets over it;
  - a stone pedestal with a great violet flask;
  - the round candle table with a CC0 three-branch candleholder;
  - a barrel, a bucket and a sea chest;
  - a raised herb bed of CC0 plants; a purple runner.
- **Middle: the alchemy table** (`Worldsort/ChemistryLabTable`), a working bench:
  - a plank top with breadboard ends, ringed with water marks and scorched by the burner;
  - a two-tier reagent shelf down its north side;
  - the great flask boiling green over a burner on a slate slab, with a glass condenser dripping into a receiver;
  - the open book on a blotter with ink and quill;
  - a CC0 candelabra, specimen jars, flasks, a balance, books and notes;
  - a knocked-over bottle in a purple spill with broken glass, and a velvet cloth slipping off the front edge.
- **The floor tells what happened:**
  - the red stain, flung south-west with a dried rim, streaks breaking into drops, and satellite drops round it;
  - red crystal shards, a red bottle, glass and dropped notes round it;
  - a trail of green bottles, a tipped purple flask in its own spill, and scattered notes between the table and the herb bed.
- **East:** a long work bench with a stepped reagent rack, a copper alembic over a brazier dripping into green distillates, a retort over a burner, a tube rack, books, a lantern and a balance, with a shelf of stock over it.
- **South:**
  - a brick hearth (CC0 `castle_brick_02_red`) against the south wall where the painting has its arch: embers under an iron cauldron of glowing green brew;
  - crates, barrels and jars stored at either side.
- **Stock in apothecary colours:** shelf glass is mostly amber, brown, bottle green, oxblood, cobalt and violet, with few bright potions. Stored liquids barely glow; only the brewing ones and the experiments do.
- **CC0 models:** 13 Poly Haven models at real size (crates, barrels, chest, bucket, basket, brass candleholders and goblets, vases, clock, lanterns, bowl), plus the Greenhouse's plant models.

### Pipeline additions (shared, backward compatible)

- `room_prototype.py`:
  - `ModelSet` loads a CC0 model once and places linked copies at real size: `place` for one object, `group` for an asset's objects as modelled. `grade` darkens a photo-scanned model's colours toward the palette.
  - A back-wall opening may give its reveal's own `depth`.
- `cc0_textures.json`: `castle_brick_02_red` (Rob Tuytel, CC0). Fetch it with `fetch_textures.py`.
- `export_room_layout.gd`: the `chemistry_room` entry.
- Preview:
  - `prototype_room.gd` registers the Chemistry Room.
  - `play_prototype.gd -- --chemistry` opens it directly.
  - `capture_chemistry.gd` shoots and checks it.

### Exact files

- **New (this stage):**
  - `tools/blender/room_chemistry.py`, `tools/blender/capture_chemistry.gd` (+ `.uid`).
  - Evidence: `docs/evidence/2026-10-23-blender-chemistry/`:
    - `01`–`09`: painted vs HD pairs at native 1024×768;
    - `10-room-overview.png`, `11-render-on-collision.png`, `12-hd-props.png`.
- **Changed (this stage):**
  - `tools/blender/room_prototype.py`: `ModelSet`, `MODELS_DIR`, opening `depth`.
  - `tools/blender/export_room_layout.gd`: the `chemistry_room` entry.
  - `tools/blender/cc0_textures.json`: the brick.
  - `tools/blender/cc0_models.json`: 13 models, in the Greenhouse session's new manifest.
  - `tools/blender/prototype_room.gd`, `tools/blender/play_prototype.gd`.
- **Shared pipeline from the parallel Greenhouse session**, committed with this stage at the user's request, without the Greenhouse room itself:
  - `cc0_models.json` and `fetch_models.py`;
  - `roots` and `in_room` in `room_prototype.py` and `prototype_props.gd`;
  - the export's `props`, `items`, `plots` and `shape`, and its `Worldsort/player` fallback (`export_room_layout.gd`);
  - the `Worldsort/` player lookups in `prototype_depth.gd` and `prototype_characters.gd`;
  - `_sync_interaction_footprints()` in `prototype_room.gd`, and `--greenhouse` in `play_prototype.gd`.
  - The Greenhouse's and the Library's rooms, captures, evidence and report entries stay with their sessions.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`.

### Verification

- **Blender 5.2.2 (Cycles Metal):** the final render takes 135 s at 128 samples (2610×2412; the room pass 98 s). It builds 1882 objects with 31 glows; the table cloth simulates in about 10 s.
  - Under load from other sessions a render took up to 378 s.
- **Capture:** `capture_chemistry.gd` passes 80/80 in EN and in ZH.
  - Both props are staged on their own `Worldsort/` nodes, and each highlight box follows its HD art and returns to the painted one.
  - The doorway, cabinet, table, red stain and butler are each offered beside them in both looks.
  - The table draws in front of a player north of it (z 20) and behind one south of it (z −20).
  - The cauldron hides the legs of a player behind it (17 rows); the doorway and the open floor hide nothing.
  - The HD detective stands 90.4 px tall like the pixel one, and runs.
- **No regressions:** `capture_room.gd` (Wake Room) passes 65/65; its capture folder was restored afterwards.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean, and the new files have no trailing whitespace.
- **Playable preview:** `play_prototype.gd -- --chemistry` stages the room with 31 glows, 2 HD props, depth and 2 HD character sheets, and no script errors.

### Risks / follow-up

- **Preview only:** the game's own Chemistry Room is unchanged.
- **NPCs:** the butler and Dr. Lin's memory echo are still the pixel NPCs. Tripo models need the owner's Tripo Studio account, as for the detective and the Guardian.
- **Duplicate model loaders:** the Greenhouse has its own `Models` loader. Merge it with `ModelSet` once neither session is editing.
- **Next:** the restyle the user asked for (a table of real size, richer wood and flagstones, a room that impresses), then the butler and Dr. Lin's echo in Tripo, then the Dining Hall.

## Stage: UX-20261021-54 (Greenhouse)

- **Date:** 2026-10-23
- **Status:** reviewed: the user asked for its door, bench and floor to be changed ("门和桌子和地板需要修改"), which stage 56 did; committed and pushed with stage 61, at the user's request. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** "你现在负责优化green_house，用blender重新搭建，符合我游戏的风格，搭建风格向大厅看齐" (rebuild the Greenhouse in Blender, in the game's style, built the way the Hall is built).
- **Parallel work:** other sessions are rebuilding Chemistry (`room_chemistry.py`) and Library (`room_library.py`) in this checkout at the same time. If one of them also reports as stage 54, renumber by commit order. Their edits to shared files are listed under "Exact files".

### What the room is now

- **Built like the Hall:** the Hall's moonlight (`moon_sky`), the Hall's own wall tops (dark mossy slate with broken cracks, outlined in lit stone), flagstones and slate walls from the same CC0 photo sets, iron lanterns of the Hall's design, and the Hall's Greenhouse portal (`hall.build_portal`, leaf emblem) as the gate, seen from inside. The render's mean luminance is 38.0, the restyled Wake Room's 37.9.
- **Two screens tall (1024×1536), on the game's own collision:** the camera still follows the player through it.
  - **North:** a pointed gothic window (two lancets, an oculus with a quatrefoil, a hood moulding) over a two-step plinth, with moonlight thrown through it; a lancet either side; lanterns on stone pedestals in the collision's pockets; hanging baskets; a copper pipe to the beds.
  - **West bed:** blue blossom, the ironvine trellis, nettles and ferns, and the three brass valves for light, water and air that its text describes.
  - **East bed:** moonleaf (calathea's silver bands turned toward moonlight), glowing silver pods, and the mineral patch of grit and pale crystals.
  - **Middle:** the great stone planter, a moulded ring with a faint green groove and a lantern on each of its three posts. A violet flower glows at its heart; blue blossom grows to the north, dewcap in the shaded west and emberroot in the east, matching its three herb plots.
  - **Bench:** the gardener's potting bench in worn oak, with seedling trays, a drying rack hung with moonleaf, the open handbook, the repair map, seed jars, a watering can, a trowel, a lantern, a bucket, a basket and his stool.
  - **South:** two clusters of terracotta pots (blue blossom, the emberroot pot, a fern; a leafy plant ringed with calathea), a drain grate, puddles, fallen leaves and petals; the gate between two lantern piers, with steps down to the Hall.
- **Plants and tools:** 34 CC0 Poly Haven models at their real size (one game px across is a centimetre). Flower colours are graded into the palette (blue blossom from periwinkle, blue-white heliophila); dewcap, emberroot, the magic flower, pods, ivy and ironvine are modelled.
- **Depth:** the walls, both bed kerbs, the planter and the gate stand in the depth map.
  - North of the planter its rim hides the player's legs. At the gate's prompt the taller portal shows the player as a ghost, as the Hall's portals do; an earlier pass hid them completely.
  - The aisles and the floor in front of the planter hide nothing.

### Pipeline additions (shared, backward compatible)

- **Props outside `Props/`:** `export_room_layout.gd` reads a room's prop nodes from its spec (`"props"`), exports its `INTERACT_ITEMS` and `HERB_PLOTS` (`"items"`, `"plots"`), each polygon's own name (`"shape"`) and finds a y-sorted player. The Wake Room's export is unchanged apart from the new `shape` field (checked).
- **`roots` and `in_room`:** a room's `build()` may return `"roots"` (the node each prop render stands in for, here `Worldsort/<prop>`) and `"in_room"` (props the room render and depth map keep, because the player walks round or behind them).
  - `prototype_props.gd` stages those sprites undrawn (`self_modulate` alpha 0, restored on `restore()`), so the game's prompt box still follows the HD prop.
- **Preview:** `prototype_room.gd` registers the Greenhouse and re-reads its footprints through `_sync_interaction_footprints()`. `prototype_depth.gd` and `prototype_characters.gd` find a player under `Worldsort/`. `play_prototype.gd -- --greenhouse` opens the room directly.
- **CC0 models:** `tools/blender/cc0_models.json` (authors, pages, SHA-256 per file) and `tools/blender/fetch_models.py`. The binaries go to the gitignored `prototypes/blender_rooms/models/` (≈58 MB for the Greenhouse's 21 models). The Chemistry session has since added its 13 models to the same manifest.

### Exact files

- **New (this stage):**
  - `tools/blender/room_greenhouse.py`, `tools/blender/capture_greenhouse.gd` (+ `.uid`), `tools/blender/fetch_models.py`, `tools/blender/cc0_models.json`.
  - Evidence: `docs/evidence/2026-10-23-blender-greenhouse/`, with `01`–`08` painted vs HD pairs (native 1024×768), `09-room-overview.png` and `10-hd-props.png`.
- **Changed (this stage):**
  - `tools/blender/export_room_layout.gd`: the greenhouse entry, `props`/`items`/`plots`, `shape`, the `Worldsort/player` fallback.
  - `tools/blender/room_prototype.py`: `roots` and `in_room` in the docstring, `render_props`, `render_depth` and `main`.
  - `tools/blender/prototype_props.gd`, `prototype_room.gd`, `prototype_depth.gd`, `prototype_characters.gd`, `play_prototype.gd`.
- **Shared files also changed by the parallel Chemistry session (not this stage):** `room_prototype.py` (`ModelSet`, opening `depth`), `export_room_layout.gd` (its `chemistry_room` entry), `cc0_models.json` (13 models), `cc0_textures.json`.
- **Docs:** this report, `docs/AGENT_HANDOFF.md`.

### Verification

- **Blender 5.2.2 (Cycles Metal):** the final render takes 181 s at 128 samples (2048×3072; the room pass 112 s) and builds 1232 objects with 66 glows.
- **Capture:** `capture_greenhouse.gd` passes 89/89 in EN and in ZH:
  - all 5 props are staged on their own `Worldsort/` nodes, and each highlight box follows its HD art and returns to the painted one;
  - each prop's prompt is offered beside it in both looks, as are the gardener's and a herb plot's;
  - the depth checks pass, and the HD detective stands 90.4 px tall like the pixel one, idles and runs.
- **No regressions:** `capture_room.gd` (Wake Room) passes 65/65 and `capture_prototype.gd` (Hall) passes. Their capture folders were restored afterwards.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean, including the new files.
- **Playable preview:** `play_prototype.gd -- --greenhouse` stages the room with 66 glows, 5 HD props, depth and 2 HD character sheets, and no script errors.

### Risks / follow-up

- **Preview only:** the game's own Greenhouse is unchanged.
- **The gardener** is still the pixel NPC. A Tripo model needs the owner's Tripo Studio account, as for the detective and the Guardian.
- **Duplicate model loader:** `room_greenhouse.py` has its own `Models` loader (`materials`, `tilt`, `anchor`). The parallel Chemistry session added a simpler `ModelSet` to `room_prototype.py`. Merge them once neither session is editing.
- **Glow placement:** the herb-plot markers are the game's own green squares. They sit on the HD planting, but the room's own pods and dewcap now glow too.
- **Next (proposed):** the user's review of this room, then the gardener in Tripo.

## Stage: UX-20261021-53

- **Date:** 2026-10-23
- **Status:** approved by the user, committed and pushed as `ddcbc66`. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user's verdict on stage 52 (committed and pushed as `d283383`): "现在的感觉太假了，和墙壁和大厅的风格不匹配，特别是床和书架" (it feels fake and does not match the walls or the Hall, especially the bed and the bookshelf).

### What made it fake, and what changed

- **The bedding was a stiff height field:** a flat velvet slab with painted-on ripples, ball pillows and a white band.
  - It is now dropped onto the bed with Blender's cloth solver (`room_prototype.simulate_cloth`), so it hangs as cloth does.
  - The coverlet is plum silk damask (CC0 `floral_jacquard`) with a turned-down sheet.
  - Soft creases are raised only where the cloth lies face up.
  - A cream throw with a woven gold border is thrown across the foot and hangs over the east side, resting on the coverlet.
  - The pillows are sewn, puffed shapes with pinched corners.
- **The bed was a plain box:** it is now a four-poster in the painting's shape.
  - Square blocks where the rails join, turned posts with brass finials.
  - Arched head and foot boards of rails, stiles and raised panels.
- **The bookcase had flat bright books in a dark box.**
  - Every book now has two boards and a rounded spine in one aged-leather piece (CC0 `fabric_leather_02`), each in its own muted binding colour.
  - The books have a cream page block, gilt bands and labels.
  - The shelves have flat stacks, a tied scroll and a leaning book resting on its neighbour.
  - The case has plinth and crown mouldings, shelf lips, and two drawers with escutcheons and ring pulls.
- **Wood:** the dark red-brown wood read as plastic. The furniture is now worn, waxed oak (CC0 `wood_table_worn`), warm like the painting's. Crates and the trunk are rough boards (CC0 `wood_cabinet_worn_long`).
- **Out of keeping with the walls and the Hall:**
  - **Light:** the overhead fill read as a studio light. The room is now lit as the Hall is: the Hall's own moonlight (colour, strength and softness), with the room's candles and its window.
  - **Wall tops:** the Hall's own materials, dark slate with moss and broken cracks, outlined in lit stone.
- **Smaller fixes:**
  - The runner shows a carpet's pile.
  - Flames are tapered teardrops that cast no shadow.
  - Every turned piece is round in 3D.
  - The trunk's cloth is simulated too.
  - Photo textures keep their proportions on non-square images.

### Exact files

- Changed:
  - `tools/blender/room_prototype.py`: `simulate_cloth`, `Kit.blocks`, per-face materials on `Kit.sheet`, texture aspect, flames.
  - `tools/blender/room_wake.py`: bed, bookcase, books, woods, cloth, light, wall tops.
  - `tools/blender/cc0_textures.json`: 4 more CC0 Poly Haven sets, `floral_jacquard`, `fabric_leather_02`, `wood_cabinet_worn_long` and `dirty_carpet`, with authors and checksums.
- Evidence: `docs/evidence/2026-10-23-blender-wake-room/`.
  - `01`–`10` are re-captured.
  - New `11-restyle-bed-bookshelf.png` shows stage 52, stage 53 and the painted room side by side.
- Docs: this report, `docs/AGENT_HANDOFF.md`.

### Verification

- **Blender:** the final render (128 samples, 2048×1536) takes 81 s in all. The three cloth simulations take about 29 s of that and come out the same each run.
  - The throw lies on the coverlet: a probe found the coverlet showing through it in 0 of 342 grid cells, where an earlier drop let it through everywhere.
- **Room capture:** `capture_room.gd` passes 65/65 in EN and in ZH. Every prop's walk-up point is still on the game's 13.5 px band.
- **Godot:** gdlint and pyflakes are clean; the headless editor parse has 0 errors; `git diff --check` is clean.

### Risks / follow-up

- **Same limits as stage 52:** preview only, and the east gate stays true to perspective (the user's choice).
- **Next (user's choice):** the Chemistry Room, with the butler and Dr. Lin's memory echo made in Tripo, once the user accepts this style.

### GitHub documentation proposal

- None beyond stage 52's: this stage restyles the same prototype.

---

## Stage: UX-20261021-52

- **Date:** 2026-10-23
- **Status:** reviewed. The user approved committing it but asked for a restyle: "现在的感觉太假了，和墙壁和大厅的风格不匹配，特别是床和书架" (it feels fake, out of keeping with the walls and the Hall, especially the bed and the bookshelf). Stage 53 restyles the room. The east gate stays true to perspective (the user's choice), and the Chemistry Room follows. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** "可以现在继续跟改各个房间，重新使用blender建模，以及各个npc" — rebuild every room and every NPC the Hall's way, before moving the HD art into the game. Stage 51 was committed and pushed as `75c4115`.
- **User's choices:**
  - one room per stage, the Wake Room first;
  - all of it in the preview first, moved into the game together at the end;
  - NPC portraits rendered from their new 3D models;
  - about 1000 Tripo credits for the four NPCs (butler, gardener, mechanic, Dr. Lin).

### What changed

- **A room pipeline**, shared by every room to come:
  - `tools/blender/export_room_layout.gd` (headless Godot) exports a room's real collision, props, spawns and interaction points to `prototypes/blender_rooms/<room>/layout.json` and `collision.png`.
  - `tools/blender/room_prototype.py` (Blender) renders a room from those, using the Hall's projection and materials:
    - **Walls:** a vertical back wall with openings, and side walls that lean out like the painted room's.
    - **Room image:** the room alone, at 2 px per game px.
    - **Props:** each interactive prop rendered alone and cut where the room stands in front of it (holdouts).
    - **Depth:** a map of each wall and fixed piece's ground y.
    - **Glows:** the candles' and crystals' halos.
  - A room's furniture and lights live in `tools/blender/room_<name>.py`.
- **The Wake Room** (`tools/blender/room_wake.py`, 472 objects), everything standing on the floor its collision blocks:
  - **Window:** an arched leaded window with a rose head. Moonlight falls through it in a pool on the floor, carrying the mullion's shadow.
  - **Bed:** a four-poster with folded velvet, a draped throw and the brass key's bow showing under the pillow.
  - **Bookshelf:** books, potions, an hourglass, a skull and a globe.
  - **Desk:** Mrs. Lin's three candles under glass jars of three sizes (her drill), the scroll the desk clue reads, an open book, ink and quill.
  - **Window seat:** the candle note folded on it, between two candles.
  - **Furniture along the walls:** a nightstand, two wall sconces, a side table with an oil lamp, a travelling trunk, the alchemy bench and the crates with an armillary sphere.
  - **Floor:** a brass compass rose let into the floor, and a purple runner.
  - **The Wake gate:** the Hall's own Wake portal (moon emblem, violet seal), mapped onto the east wall between two violet crystal lamps.
- **Preview:** `tools/blender/prototype_room.gd` stages a room's HD look, and `play_prototype.gd` uses it whenever the Wake Room loads.
  - It re-reads the room's highlight boxes and walk-up points from the HD props, and from the painted ones on restore.
  - Figures keep their room size (the depth pass gained `figure_scale` and `shadow_size`).
- **Textures:** four more CC0 Poly Haven sets, with authors and checksums, in `tools/blender/cc0_textures.json`: `dark_wood`, `wood_table_worn`, `velour_velvet` and `cotton_jersey`.

### Design decisions

- **Gameplay stays the game's own.** Collision, prompts, the first lead and saves are untouched.
- **Walk-up rule for HD props:** the game walks the player to a 13.5 px band round a prop's art, and that band must clear the prop's collision by 14 px. So each HD prop's visible front must reach within 7.5 px of its collision edge. The room capture caught the desk and bookshelf short of it (9–12 px); both now stand on their collision edge.
- **Side-wall doors are true to perspective.** Seen from this camera, a door in the east wall is foreshortened. The painting draws its vault door facing the player instead. The HD gate is about 100 px wide on screen; the painted door is 112. Asked, the user kept the true perspective.
- **Helpers added to the renderer:**
  - Hall pieces keep their exact shape on a leaning wall: the shear is split between two empties.
  - Photo textures are box-projected, so wood keeps its grain on every face.
  - Cloth (the blanket, the throw, the trunk's cloth) is a wrinkled height field.

### Exact files

- New: `tools/blender/room_prototype.py`, `tools/blender/room_wake.py`, `tools/blender/export_room_layout.gd`, `tools/blender/prototype_room.gd`, `tools/blender/capture_room.gd` (each `.gd` with its `.uid`).
- Changed:
  - `tools/blender/play_prototype.gd` (stages rooms);
  - `tools/blender/prototype_depth.gd` (`figure_scale`, `shadow_size`; the Hall keeps its defaults);
  - `tools/blender/cc0_textures.json` (4 assets).
- From the code-review feedback after stage 51, also in the working tree: `tests/hall_route_authoring_test.gd` (new check `_check_recording_never_strands_the_knowledge_stop`) and the new `tests/change_sorting_seal_test.gd` with its `.uid`.
- Evidence: `docs/evidence/2026-10-23-blender-wake-room/`:
  - `01`–`07`: current against HD, in game;
  - `08`: the render over the collision;
  - `09`: the four props, painted against HD;
  - `10`: the HD detective standing and running.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only (gitignored, regenerable): `prototypes/blender_rooms/wake_room/` and the new textures.

### Evidence and verification

- **Blender:** the final render (128 samples, 2048×1536) takes 47 s on the M3, about 60 s with the props, depth and glows. The first run compiles Cycles kernels once, about 4 minutes, for the wax's subsurface scattering.
- **Room capture:** `capture_room.gd` passes all 65 checks in EN and in ZH:
  - all 4 props staged, 18 glows, depth, both character sheets;
  - each highlight box follows its HD prop and goes back on restore;
  - each prop's walk-up point sits on the 13.5 px band and offers that prop;
  - the door is offered at its standing point, and the candle note is in reach, in both looks;
  - the alchemy bench hides the player's legs, and open floor never does;
  - the HD detective is 90.4 px tall, idles and runs.
- **Hall regression:** `capture_prototype.gd` passes 176/176 after the shared depth change.
- **Feedback tests:** `hall_route_authoring_test.gd` and `change_sorting_seal_test.gd` both pass.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.

### Risks / follow-up

- **The room reads as fake to the user,** especially the bed and the bookshelf, and does not match the walls or the Hall: stage 53 restyles it before the next room.
- **Preview only:** the HD room shows only in `play_prototype.gd` and the captures.
- **Prompt boxes change shape with the art:** the bed's box is taller and the gate's smaller. Prompts and walk-ups are verified, but a player may notice the change.
- **Next (user's choice):** after the restyle, the Chemistry Room, with the butler and Dr. Lin's memory echo made in Tripo.
- **GitHub:** committed and pushed as `d283383` with the user's approval.

### GitHub documentation proposal

- Add stage 52 to `docs/PROJECT_STATUS.md`: the room pipeline and the HD Wake Room, preview only, linking `docs/evidence/2026-10-23-blender-wake-room/`.

---

## Stage: UX-20261021-51

- **Date:** 2026-10-23
- **Status:** approved by the user ("很好"), who also approved committing it and chose the next step: move the HD Hall into the game. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 50 (committed and pushed as `404aaf9`), the user found what was enlarged too big ("现在的太大了，就正常一点就可以了"). Asked which part, they chose the hands, which stage 50 had drawn 1.4× (detective) and 1.3× (Guardian).

### What changed

- **Hand size:** both characters' hands are back to the models' own size (`"hand": 1.0` in `character_motion.py`). They stay visible because the arms are still held out from the coat. The arm swing, run, idle, strides and gait logic are unchanged.
- **Re-rendered:** all six gait sheets and the 3× previews. The sheet layouts and strides are identical (detective walk 54.5 px and run 111.3 px; Guardian 89.3 px and 128.2 px), so the preview needed no change.

### Exact files

- Changed: `tools/blender/character_motion.py` (hand scale 1.0 and its docstring).
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`: rebuilt `32-hd-characters.png`, `33-character-walks.png`, `34-characters-standing-zh.png`, `35-characters-close.png` and `36-tripo-characters.png`, plus the comparisons where the HD detective appears.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: the re-rendered sheets and previews in `prototypes/blender_chars/`.

### Verification

- **Blender:** all six sheets render with every frame of every facing inside its cell.
- **Native captures:** `capture_prototype.gd` passes all 176 checks in EN and ZH, including idle, walk, run, the planted-feet stride (55.3 px a cycle against 55.4 px) and restoring.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched with the new frames.

### Limits / next stage

- Same as stage 50: preview only, and the detective always runs because the game moves him at 180 px/s.
- **Next (user's choice):** move the HD Hall, props, doors, depth shader, 50 px Hall figures and these characters into the game itself, with each Hall door matching its room's own door.
- **GitHub:** committed and pushed with the user's approval (the hash is recorded in the next stage).

---

## Stage: UX-20261021-50

- **Date:** 2026-10-23
- **Status:** reviewed by the user, who approved committing it. Their verdict: tweak, because what was enlarged is now too big and should be closer to normal ("现在的太大了，就正常一点就可以了"). Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** after stage 49 (committed and pushed as `c88924e`), the user asked for a running animation ("需要奔跑动画"). Reviewing that work they added three complaints:
  - the hands can't be seen at all ("手根本看不到");
  - running needs a pose of its own ("跑步也需要单独的姿势");
  - the figures are too stiff and should be livelier ("人物现在太死板了，需要生动一点").

### What changed

- **More Tripo clips:** I retargeted more of Tripo Studio's preset animations onto both existing rigs: run, idle, look_around and standing_relax, plus swagger and flee_01 for the detective. Retargets cost no credits; the balance stayed at 3885.
  - Each character's export is now one GLB with every clip: `detective_anims.glb` (7 clips) and `guardian_anims.glb` (5 clips), in place, with skeleton.
  - `sources.json` records the export task ids and clips.
- **Why the hands vanished:** the clips are motion capture of an adult, retargeted onto chibi bodies. The arms hang straight, so the small hands sit at the hips, inside the coat's outline (or the tabard's), and disappear at 50 px.
- **New `tools/blender/character_motion.py`** keeps each clip's legs and hips and rebuilds the rest of every frame so it reads at 50 px:
  - **Arms** are held 12–26° out from the body so the hands clear the coat. They swing against the legs, a beat (7% of the cycle) behind them, and the elbows bend as they come forward. A run pumps them at 80–84° with fists, the Guardian's gauntlets curled tighter.
  - **Hands** are drawn 1.4× (detective) and 1.3× (Guardian) larger, the way chibi art draws them.
  - **Chest and head:** the chest twists against the arms, the head turns back against it, nods with each step and looks where the figure goes.
  - **Run lean:** the motion-capture run hunches 30° forward; it is brought to 13–14°.
  - **Stride:** made 1.45× longer for the detective's run, and 1.3× (walk) and 1.15× (run) for the Guardian, so the legs don't strobe at the game's speeds. The body is lowered so the lower shoe still meets the floor; a run keeps half its time in the air.
  - **Idle:** a 6-second loop that breathes twice, sways and looks left, then right.
- **`tools/blender/character_prototype.py` now renders three gaits per character, each in the game's 8 directions:**
  - **idle:** 36 frames at 6 fps;
  - **walk:** one cycle in 8 frames;
  - **run:** one cycle in 8 frames.
  - Both cycles start on the right foot's footfall, found from the feet, so a figure can switch between them mid-stride.
  - The JSON gives each sheet, the idle's fps, and each cycle's stride, i.e. the ground it covers. That is measured from a planted foot's steady backward slide: detective walk 54.5 px and run 111.3 px; Guardian walk 89.3 px and run 128.2 px, on the 100 px sheet figure.
  - Shoes are found from the skin weights. The importer's NLA tracks are muted, and each pose starts from rest so a clip sets only what it keys.
- **`tools/blender/prototype_characters.gd` draws each figure itself.** The game only knows a walk and a frozen standing frame, so its sprite is left to run the game's logic undrawn, on the HD walk frames. A child `Sprite2D` draws the figure, sharing the sprite's place, scale, visibility, modulate and the depth pass's material (`use_parent_material`). Every physics tick (`track()`, called from the preview's `_physics_process`) it:
  - reads the game's facing and whether the game walks the figure;
  - plays the idle loop while standing;
  - while moving, walks or runs by the body's true pace per tick: it runs above 120 px/s and walks again below 100 px/s, a change of gait waiting until the pace has stayed past the threshold for 0.15 s;
  - advances each cycle by the ground the body covered, so planted feet stay put at any speed.
- **What this means in play:**
  - The detective (180 px/s) runs at about 3.3 strides a second.
  - The Guardian creeps, patrols and searches at a walk (38–96 px/s), and chases at a run (145 px/s and up), its cloak streaming.
  - A paused game holds the figures. Measuring per physics tick made every capture run give identical results.

### Exact files

- New: `tools/blender/character_motion.py`.
- Changed: `tools/blender/character_prototype.py`, `tools/blender/prototype_characters.gd`, `tools/blender/capture_prototype.gd` (new checks, shots 35–36, `_clear_way` with a reach), `tools/blender/play_prototype.gd` (`_physics_process`).
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - `32-hd-characters.png` now shows the standing (first idle) frame in every facing.
  - `33-character-walks.png` now shows the gaits: the idle loop, the walk and the run, side and front.
  - `35-characters-close.png` adds the HD detective running and the HD Guardian charging, in game.
  - `36-tripo-characters.png` now shows standing and running.
  - The comparisons where the HD detective appears were rebuilt.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_chars/` (three sheets and JSON per character, plus a 3× `<character>_preview.png` from `--preview --zoom 3`) and `prototypes/blender_chars/source/` (both GLBs per character, `sources.json`).

### Verification

- **Blender:** all six sheets render with every frame of every facing inside its cell.
- **Native captures:** `capture_prototype.gd` passes all 176 checks in EN and ZH, four runs in a row with identical results. The new checks:
  - each figure is drawn by its HD child on the game sprite's place and depth material, with the game's sprite undrawn;
  - "Standing plays the idle loop" (detective frame 255 → 261, Guardian 111 → 117 in a second);
  - "The Guardian walks at patrol pace (70 px/s)" (all 30 ticks walk);
  - "The Guardian runs at chase pace (170 px/s)" (walk ×13, then run ×23);
  - "A stopped Guardian goes back to its idle loop";
  - "Moving at the game's speed plays the HD run" (every moving sample, 8 different frames);
  - "The run keeps each planted foot on its spot": 2.62 cycles over 145 px, 55.3 px a cycle against the 55.4 px rendered stride;
  - "Stopping holds the game's standing frame and shows the idle loop";
  - restoring removes the HD figures.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched with the new figures.

### Limits / next stage

- **Preview only, Hall only:** the game's sprites are unchanged.
- **Always running:** the detective has no slower gait in play, because the game moves him only at 180 px/s (252 with the Swiftness Potion). His walk appears only for slower scripted moves.
- **Fixed lighting:** the figures are lit by a fixed rig, not by the Hall's lanterns.
- **Unused clips:** swagger, flee_01, look_around and standing_relax are exported but not rendered. They are candidates for idle variety or a Guardian alert pose.
- **Next (user's choice):** bring the enlarged parts back toward normal size. Then move the HD Hall, props, doors, depth shader, 50 px Hall figures and these characters into the game itself, with each Hall door matching its room's own door.
- **GitHub:** committed and pushed with the user's approval (the hash is recorded in the next stage).

---

## Stage: UX-20261021-49

- **Date:** 2026-10-22
- **Status:** reviewed by the user, who approved committing it. Their verdict: tweak, adding a running animation ("需要奔跑动画"). Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 48 (committed and pushed as `4db9b59`), the user found the primitive-built figures look like wooden puppets ("有点像木偶人"), off the game's style. They asked for characters generated with Tripo in the game's style and background, and approved uploading the pixel sprites as references.

### What changed

- **Two Tripo characters**, made in Tripo Studio on the project owner's account (they logged in themselves; I never touched credentials), in the integrated browser:
  1. **References:** the game's own pixel sprites. Each front frame was enlarged with nearest neighbour onto white.
  2. **Concept:** Generate Image (Nano Banana, 1:1, 2 images) with a prompt that keeps each design and asks for a stylized 3D T-pose. I chose one image of each pair.
  3. **Model:** Generate Model from the chosen image: HD Model, H3.1 Best Quality, 4K PBR texture, about 38k triangles, private.
  4. **Rig:** Auto Rig, humanoid, Mixamo skeleton (65 bones).
  5. **Walk:** the preset "walk", retargeted onto the rig.
  6. **Export:** GLB with 2k textures, skeleton and walk, in place.
  - The detective keeps his design: messy chestnut hair, big grey-blue eyes, an open brown trench coat over a waistcoat, a gold buckle, rolled cuffs, dark trousers and brown shoes.
  - The Guardian is dark steel with bronze trim, a flat-topped great helm with a glowing violet visor slit, a violet core in the breastplate, pauldrons, gauntlets, a tattered tabard and a tattered cloak.
- **Provenance:** recorded in `prototypes/blender_chars/source/sources.json` (local only, like every prototype output). It lists the two prompts, the chosen images and the task ids for concept, model and export, so the models can be found again in the account. The GLBs, concepts and references sit beside it.
- **`tools/blender/character_prototype.py` now renders the Tripo GLBs.** The stage-48 primitive models are gone; the camera, lights, sheet layout and JSON are unchanged, so the preview module needed no change.
  - Import: it imports the GLB and removes a stray untextured icosphere that Tripo's export carries around the origin.
  - Walk: it finds the walk's period from the feet. Each clip holds two identical 28-frame cycles, 1.17 s each at 24 fps. The cycle starts on the frame where the right foot passes the left.
  - **Standing pose (frame 0):** the cycle's mean pose (bone rotations averaged over the cycle), with legs under the body and arms hanging, set down on the walk's floor.
  - **Walk frames 1–7:** the rest of the cycle, evenly spaced (sub-frame sampling).
  - **Centring:** each figure is centred on where its feet stand on average. The Guardian's in-place walk sits about 0.07 units forward of the origin and would otherwise swing sideways as it turns.
  - **Glow:** the Guardian's visor and core glow. Tripo's GLB has no emission, so violet texels (blue well above green, 0.6% of the texture and none of the steel, bronze or cloth) drive emission at strength 4.
- **In the preview,** both figures walk, turn and stand on the game's own logic, at the stage-48 sizes and footing: the detective 49.7 px tall like the pixel one, the Guardian on its pixel sheet's layout.

### Exact files

- Changed: `tools/blender/character_prototype.py` (primitive modelling replaced by the GLB renderer).
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - rebuilt sheets `32-hd-characters.png`, `33-character-walks.png`, `34-characters-standing-zh.png` and `35-characters-close.png`;
  - rebuilt comparisons 01–04, 11, 12, 14, 17, 20, `26-hall-doors.png`, `28-hd-props.png` and `31-door-behaviour.png`, where the HD detective appears;
  - new `36-tripo-characters.png`: for each character, the pixel sprite, the Tripo concept made from it, and the rigged model standing and walking.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_chars/` (sheets, JSON, 3× turnarounds) and `prototypes/blender_chars/source/` (GLBs, concepts, references, `sources.json`).

### Verification

- **Blender:** both sheets render with every frame of every direction inside its cell. Standing figures: detective rows 14–116 of 128 (feet row 114); Guardian rows 34–137 of 156 (feet row 134; the pixel Guardian spans 34–133). The toes reach 2–3 px past the feet row because they point toward the camera.
- **Native captures:** `capture_prototype.gd` passes all 167 checks in EN and ZH, including the stage-48 character checks: both sheets load and play, all 8 walks have 8 frames, the detective is 49.7 vs 49.7 px on the body origin (0.00 px off), standing holds frame 0, walking cycles every frame, and restoring returns the pixel figures.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `region [0, 0, 1920, 1280], 347 glows, 9 HD props, 7 doors, depth true (9 props), 2 HD character sheets (2 figures)`.
- **Tripo credits:** the Studio balance fell from 4395 to 3885 (510) between the first generation and the last export. The buttons showed 190: concepts 2 × 20, models 2 × 55, rigs 2 × 20; the walk retargets and exports were free. The billing page lists payments only, so the difference is unconfirmed; the HD models probably cost more than their button showed.

### Limits / next stage

- **Preview only, Hall only:** the game's sprites are unchanged.
- **Local models:** the GLBs live only in the gitignored `prototypes/` folder and in the Tripo account; they are AI-generated prototype assets, not yet shipping assets.
- **Lighting:** the figures use the stage-48 light rig, not the Hall's lanterns, and the detective's hair reads a little more orange than the sprite's.
- **One walk:** both characters share Tripo's preset walk, so the Guardian has no heavier gait or separate chase run.
- **Next (user's choice):** a running animation for the characters. Then move the HD Hall, props, doors, depth shader, 50 px Hall figures and these characters into the game itself, with each Hall door matching its room's own door.
- **GitHub:** committed and pushed with the user's approval (the hash is recorded in the next stage).

---

## Stage: UX-20261021-48

- **Date:** 2026-10-22
- **Status:** reviewed by the user, who approved committing it. Their verdict: restyle. The figures feel like wooden puppets ("有点像木偶人") and don't match the game's style, so they asked for characters generated with Tripo in the game's style. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 47 (committed and pushed as `3d75ff1`), the user chose HD characters made in Blender next, so the figures match the HD Hall. They had asked for the characters too ("人物也是") when the Hall moved to Blender.

### What changed

- **Two 3D characters**, built in Blender by the new `tools/blender/character_prototype.py` from smooth primitives: lathed bodies, ellipsoids, tapered limbs, and hair locks that follow the head's surface. Each is rigged with plain pivots at hips, knees and shoulders.
  - **The detective**, after the pixel sprite:
    - messy brown hair with a heavy fringe, big slate eyes under serious brows, and a light blush;
    - a long brown trench coat worn open over a vest, a white shirt and a gold-buckled belt, with lapels, pockets, a back belt and light rolled cuffs;
    - charcoal trousers and brown shoes.
    - The proportions are chibi like the sprite's (the head is about a third of the figure). Facing down, its width at every height measured is within 4% of the figure's height of the sprite's. The side view is slimmer, because the sprite's side frame swings a hand clear of the body.
  - **The Castle Guardian**, a knight in slate steel with bronze trim:
    - a flat-topped great helm with a bronze ridge and a visor slit whose eyes glow violet;
    - two-lame pauldrons, and a bronze V down the breastplate to a glowing violet core;
    - plated arms and dark gauntlets;
    - a tattered brown front cloth in two halves that swing with the legs, and a long tattered cloak.
- **Walks:** each character has an 8-frame cycle in each of the game's 8 directions.
  - The hips swing ±24° (the Guardian's ±20°), the trailing knee bends to lift the foot, and the arms swing against the legs.
  - The body drops so the lowest foot stays on the floor.
  - Frame 0 is the standing pose, because the game shows idle by stopping a walk on frame 0.
- **Rendering:** an orthographic camera 72° from straight down, the near-front view the pixel sprites use, so faces read.
  - Unlike the Hall, characters are not stretched to the floor plan: a figure stands on one point.
  - A warm key from the upper left, a cool fill and a violet rim from behind; transparent background; AgX like the Hall.
  - The detective's sheet is 8 × 8 cells of 128 px with a 100 px figure, twice the 50 px the preview shows, so it shrinks smoothly with mipmaps.
  - The Guardian's sheet is laid out like its pixel sheet (128 × 156 cells, boots on row 134, a 100 px figure). The game's own scale and foot anchor therefore still fit it, and so does the preview's depth pass, which rescales that sprite.
  - `<character>.json` gives the rows by animation name, the cell, the feet, the height and the angle.
- **In the preview** (`tools/blender/prototype_characters.gd`), the player's and the Guardian's sprites get the HD frames.
  - The game's own walk, facing, idle and distance-driven stride timing play them.
  - The detective stands exactly as tall as the pixel one (49.7 px in the preview) on the same feet; the Guardian keeps its scale and anchor.
  - A Guardian that appears later is picked up. `restore()` gives back the pixel frames and placement.
- **Captures:**
  - new shot 34 shows both figures standing face to face, fog lifted, in both looks. The Hall tutorial, which walks the Guardian along its route every frame, is held only for that still.
  - new shot 35 shows the HD detective mid-stride.
- **How it got there:**
  - At the Hall's own 40° the camera looked down on the head and faces did not read.
  - 72° matched the sprite better than 65°.
  - The first hair was a smooth bowl, then spikes. The final hair is a darker cap under lighter locks whose tips lift off to break the outline, clear of the face and ear in profile.

### Exact files

- New: `tools/blender/character_prototype.py`, `tools/blender/prototype_characters.gd` (and its `.uid`).
- Changed: `tools/blender/capture_prototype.gd`, `tools/blender/play_prototype.gd`.
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - rebuilt comparisons 01–04, 11, 12, 14, 17, 20, `26-hall-doors.png`, `28-hd-props.png` and `31-door-behaviour.png`, because the HD detective now appears in every HD shot;
  - new `32-hd-characters.png`: both characters in every facing, pixel sprite above HD;
  - new `33-character-walks.png`: the side and front walk cycles, frames 0–7;
  - new `34-characters-standing-zh.png`: the pair in game, current and HD;
  - new `35-characters-close.png`: close crops of the pixel pair, the HD pair and the HD detective walking.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_chars/` (two sheets and their JSON).

### Verification

- **Blender:** 64 frames a sheet at 64 samples, about 1 s a frame. The framing check found every frame of both sheets inside its cell. Measured standing figures: detective rows 14–115 of 128; Guardian rows 34–135 of 156, against the pixel Guardian's 34–133.
- **Native captures:** `capture_prototype.gd` passes all 167 checks in EN and ZH (148 before). The 19 new ones include:
  - "Both HD character sheets load (2 of 2)";
  - "The detective plays the HD sheet" and "The Guardian plays the HD sheet";
  - "Every one of the game's 8 walks has 8 HD frames", for each character;
  - "The HD detective stands as tall as the pixel one (49.7 vs 49.7 px)";
  - "The HD detective's feet are on the body's origin (0.00 px off)";
  - "The standing Guardian keeps its facing on its standing frame";
  - "Restoring gives both figures their pixel frames and place back";
  - "Walking plays the HD walk frames": all 8 frames cycle as the game walks the player;
  - "Stopping shows the HD standing frame".
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `region [0, 0, 1920, 1280], 347 glows, 9 HD props, 7 doors, depth true (9 props), 2 HD character sheets (2 figures)`.

### Limits / next stage

- **Preview only, Hall only:** the game's sprites are unchanged, and other rooms keep the pixel figures.
- **Fixed lighting:** the figures are lit by a fixed rig, not by the Hall's lanterns, so they don't pick up local light colour.
- **Rigid cloth:** the coat and cloak don't sway; the Guardian's front cloth swings with the legs.
- **Nearest filtering elsewhere:** the potion afterimage and the near-miss CG copy whatever frames the sprites carry, so in the preview they show HD frames with their own nearest filtering.
- **Next (user's choice):** regenerate both characters with Tripo (AI 3D generation) in the game's style, and render them through this stage's sheet layout, camera and preview swap, which stay. Then move the HD Hall, props, doors, depth shader, 50 px Hall figures and the characters into the game itself, with each Hall door matching its room's own door.
- **GitHub:** committed and pushed with the user's approval (the hash is recorded in the next stage).

---

## Stage: UX-20261021-47

- **Date:** 2026-10-22
- **Status:** approved by the user, who chose HD characters next and approved committing this stage. Nothing ships: the game, its scenes and the Web build are unchanged.
- **The user's rule for the doors, for when they move into the game:** each Hall door must look the same as that room's door seen from inside, so the player never sees two different doors. They need not copy today's textures; redesign them freely, but give each one character that fits the game and its room.
- **Request:** on stage 46 (committed and pushed as `db3791a`), the user said three things:
  - the doors look plain;
  - the Wake Room door is missing: it is only a stair, so the space reads as nothing but the Hall;
  - doors should open by themselves as the player goes in.
- **What they chose:**
  - larger stone portals with room emblems;
  - an arched double door at the head of the Wake stair;
  - walking up to an unlocked door leaves it slightly open and E opens it fully, while at a locked door E makes it shake slightly and then the requirement pops up.

### What changed

- **Stone portals.** Every door is a 3D portal, 40 px wide and about 61 px tall, so its crest rises above the 40 px walls. It has:
  - quoin jambs and a voussoir arch with a violet gem in its keystone;
  - spandrels, a cornice, and a crest bearing the room's emblem on a dark enamel plaque: flask (Chemistry), lightning (Circuit), clock (Dining), star (Final), leaf (Greenhouse), open book (Library), crescent moon (Wake);
  - a fanlight: an iron sunburst over stained glass in the room's colour.
  - The lanterns beside each door move out to clear the wider portal. Ivy, wall-top candles and floor clutter keep off it.
- **Real doorways.** A 24 × 14 px recess is cut into the wall behind each face door. Through an open door the player sees a passage lit in the room's colour.
- **Leaves that open.** Each door has two oak leaves with planks, iron straps, studs, ring handles and a kick plate, hung on hinges.
  - They are rendered apart as a 10-frame opening sequence from 0° to 72°. They stop at 72° so open leaves still show along the doorway instead of turning edge-on.
  - The walls and the portal are holdouts in those renders, so stone in front correctly cuts the leaves.
  - Each door gets one sprite sheet, listed in `render-doors.json`.
- **The Wake Room door.**
  - The stair is now a straight-topped stairwell (x 235–259), cut where the floor's edge is straightest and into wall only.
  - The same portal and double door stand at its head, facing down the stair, and the leaves open toward the camera.
  - A player on the landing behind the door shows as a ghost behind the stone, with the door in front.
- **The doors in the preview** (`prototype_doors.gd`):
  - At an unlocked door's prompt, the door swings ajar (23°); walking away shuts it.
  - E there swings it fully open, holds a beat, then the game's own handler runs and the player enters.
  - E at a locked door rattles it three times (about 0.36 s), then the game's handler shows what it needs: the key message or the knowledge question.
  - Light from the room spills out as a door opens.
  - "Unlocked" is the game's own rule: `door_<room>_unlocked`, plus `circuit_door_open` for the Circuit door. The Wake door is always open.
  - The preview holds E back from the game only while a door's prompt shows or a door is moving. It gives E back before the game's message appears, and while the game is paused.
- **Depth:** each portal's stone is in the depth map, so a figure behind a portal is hidden behind it. The doorway and fanlight stay open.
- **Captures:**
  - door shots 05–10 now place the player beside each door so it stays in view;
  - new shots 30–33 cover the door behaviours;
  - the capture now keeps the depth shader on the figures' current feet, as the preview does.

### Exact files

- New: `tools/blender/prototype_doors.gd` (and its `.uid`).
- Changed: `tools/blender/hall_prototype.py`, `tools/blender/capture_prototype.gd`, `tools/blender/play_prototype.gd`.
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - rebuilt comparisons 01–04, 11, 12, 14, 17, 20, `26-hall-doors.png`, `28-hd-props.png`, `29-hd-prop-models.png` and `silhouette-diff.png`;
  - new `30-hd-doors.png`: all seven doors shut, ajar and open;
  - new `31-door-behaviour.png`: the locked door's rattle and message, a door ajar, a door open, and the Wake gate (ZH).
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/` (now also `render-doors.json` and 7 door sheets).

### Verification

- **Layout loop:** every face door's face is flush across the portal's width, and every doorway recess is cut.
- **Blender:** final render at 128 samples: 136 s for the Hall, then the props and 7 × 10 door frames at about 1 s each. Footprint is unchanged: IoU 1.0; against the collision beyond 3 game px, 20 extra and 0 missing px. The recesses and the stairwell count as deliberate cuts.
- **Native captures:** `capture_prototype.gd` passes all 148 checks in EN and ZH. The new ones are:
  - "Every Hall door plays in HD (7 of 7)";
  - "A locked door stays shut as the player walks up";
  - "E at a locked door rattles it, then the game takes E";
  - "The game then says what the locked door needs";
  - "An open door stands ajar for the player at it";
  - "E at an open door swings it wide before the game goes through";
  - "The door shuts behind a player who walks away";
  - "The Wake gate stands ajar in front of a player behind it".
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `region [0, 0, 1920, 1280], 347 glows, 9 HD props, 7 doors, depth true (9 props)`.

### Limits / next stage

- **Preview only:** the game's doors and scenes are unchanged.
- **Mouse clicks skip the animation:** clicking a door to walk to it goes through the game's own path.
- **Untranslated message:** in the ZH run, the locked door's message ("The key fits, but the knowledge lock is still sealed.") is English. The game never localized that text; this stage did not change it.
- **Next (user's choice):** HD characters made in Blender, matching the HD Hall. After that, move the HD Hall, its props and doors, the depth shader and the 50 px Hall figures into the game itself, with each door matching its room's own door.
- **GitHub:** committed and pushed with the user's approval (the hash is recorded in the next stage).

---

## Stage: UX-20261021-46

- **Date:** 2026-10-22
- **Status:** reviewed by the user, who approved committing it. Their notes for the next stage: the doors look too plain; the Wake Room door is missing (only a stair, so the space reads as nothing but the Hall); and doors should open by themselves as the player goes in. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 45 (committed and pushed as `1cd575d`), the user asked for the other eight props in HD. They allowed moving or remaking them "让他们完美的融入现在的环境" (so they blend perfectly into the current environment).

### What changed

- **New stands.** At their pixel places, most props no longer fit the HD Hall:
  - the Dining clock stood in the black east void;
  - the Tower machine stood inside a pit;
  - the Workshop machine covered several wall blocks of a bay;
  - the Circuit exhibit stood in an alcove behind a wall;
  - Library and Greenhouse floated on open floor beside wall corners.
- **Each prop now backs onto a straight stretch of a wall's camera-facing face**, chosen by three rules:
  - it has at least a wall's height of open floor in front (40 px, plus its depth, plus 6 px); otherwise the next wall's top hides its foot, the "standing on a wall's top edge" look reported before;
  - the player can walk up to it on floor no door's prompt claims;
  - it keeps 48 px from door arches, and clear of the stair and the spawn.
  - `HD_PROP_STANDS` lists the stands. `prop_stands()` re-measures each one on the layout and prints its face rows, feet and open floor. All 9 are OK; the engine has exactly the minimum, 52 px.
- **How far each prop moves** (x, y in game px):

  | Prop | Move | Note |
  | --- | --- | --- |
  | Chemistry | +8, +13 | the tutorial target, barely moved |
  | Rack | +1, +11 | |
  | Engine | 0, +8 | |
  | Library | +7, −43 | |
  | Greenhouse | −39, −33 | |
  | Workshop | +101, +38 | |
  | Tower | +116, −102 | |
  | Dining | −139, −160 | |
  | Circuit | +122, −271 | |

- **Nine HD models**, each at its pixel sprite's size at the preview's figure scale (1.1/1.45). Each keeps its sprite's identity and shows its exhibit's science:
  - **Chemistry:** a riveted bronze reaction vessel on a stone plinth. The reaction churns orange behind a bolted porthole; it has a flue, a gauge, a sight glass and a copper pipe.
  - **Library:** a walnut console. Its frosted panel shows red, green and blue lamplight adding up to yellow, cyan, magenta and, where all three meet, white.
  - **Greenhouse:** plants under a brass-framed glass case around a glowing green core, a sun lamp above, and oxygen bubbles rising in a water tube.
  - **Dining:** a walnut longcase clock at eight minutes to midnight, with a candle clock and an hourglass: time read three independent ways.
  - **Circuit:** the stage-44 cabinet, now at the figures' scale and the stand's depth.
  - **Storage rack:** oak shelving with crates, jars, bottles, books, rolled plans and a chest; a small violet vial glows among them.
  - **Tower machine:** a furnace cabinet, brass and copper drums turned by meshing gears, and a violet crystal in a glass cage.
  - **Engine machine:** a firebox, a banded boiler with chimney, a piston and crosshead, a heavy flywheel, and a brass winding key on its gearbox.
  - **Workshop machine** (remodelled 70 px wide to fit its bay): a workbench with a vise, pegboard tools and a gooseneck lamp, beside a belt-driven drill press.
- **Rendered into the room.**
  - In the Hall render the props are invisible to the camera, but they still cast shadows and bounce light. So their shadows and their own lights are baked into the floor and walls around them.
  - Each prop is then rendered alone over transparency in the same scene. The render is cropped to the px the game counts as shown (alpha above 0.05, its own threshold).
  - Each prop carries its own lights (reaction, lamps, furnace, crystal, candle) and a soft key light from the front; wide props get one from each side.
  - No alcoves are cut for the staged props, so the old notches (e.g. behind the engine) are gone.
- **The Hall's dressing makes room for the props.**
  - Lanterns move beside a prop instead of hanging behind it.
  - Banners, wall decor, cobwebs, ivy and wall-top candles stay off its face.
  - Floor cracks, notes, spills, chalk and grates stay off its foot.
- **Staged in the preview.** `prototype_props.gd` now does the following for each prop:
  - moves the prop's node by its listed offset;
  - shows the cropped render in place of its sprite;
  - hides the pixel contact shadow;
  - has the game re-read its knowledge exhibits.
  - The game's feet, prompt, focus box and occlusion then follow the prop the player sees. `restore()` puts every node back exactly.
- **Captures:** shots 21–29, one per prop. Each is taken from a walk-up spot where the player is in full view, the prop's own prompt shows and no door's does.

### Exact files

- Changed: `tools/blender/hall_prototype.py`, `tools/blender/prototype_props.gd` (rewritten), `tools/blender/capture_prototype.gd`, and `tools/blender/play_prototype.gd` (doc comment only).
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - rebuilt comparisons 01–04, 11, 12, 14, 17, 20, `26-hall-doors.png` and `silhouette-diff.png`;
  - new `28-hd-props.png`: every prop in game, from where its prompt shows (ZH);
  - new `29-hd-prop-models.png`: each game pixel sprite above its HD model.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/` (the Hall render, 9 prop renders and `render-props.json`).

### Verification

- **Stands:** all 9 are OK, both in the builder and in the no-Blender layout harness.
- **Blender:** final render at 128 samples, 184 s for the Hall plus about 2 s per prop. Each prop's shown rect is within 1 px of its stand, and its feet within 0.5 px. Footprint is unchanged: IoU 1.0; against the collision beyond 3 game px, 20 extra and 0 missing px.
- **Native captures:** `capture_prototype.gd` passes all 132 checks in EN and ZH. They include:
  - "Every listed prop is staged in HD (9 of 9)";
  - "Every listed prop takes the depth shader";
  - for each prop, a walk-up spot in full view where its own prompt shows and no door's does.
  - In the shots, the game's focus box frames each HD knowledge exhibit and the rack, and the Dining prompt reads 按 E · 了解餐厅知识.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `region [0, 0, 1920, 1280], 346 glows, 9 HD props, depth true (9 props)`.

### Limits / next stage

- **The moves exist only in the preview.** The game's scene still has the props at their pixel places, with their pixel sprites.
- **No machine prompt at the start.** The three machines show no prompt until their stations unlock later in the story. The capture checks that their prompts reach the player, not the story gate.
- **The Circuit exhibit sits beside its door.** The door's prompt covers the floor in front of the exhibit and to its left, so the player reads it from a step further south, still well inside its 72 px reach.
- **Slower Hall render:** 184 s, up from 148 s.
- **Next (user's notes):** richer doors that open by themselves as the player goes in, and a visible Wake Room door; after that, move the HD Hall, its props on their stands, the depth shader and the 50 px Hall figures into the game itself.
- **GitHub:** committed and pushed as `db3791a` with the user's approval.

---

## Stage: UX-20261021-45

- **Date:** 2026-10-21
- **Status:** approved by the user; committed and pushed as `1cd575d`. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 44 (committed and pushed as `0c0c00d`), the user chose "extend to the whole Hall".

### What changed

- **The whole Hall in one render.**
  - `export_hall_region.gd` exports the full map (`--region=0,0,1920,1280`). It also exports every prop the game sorts against the player (`HALL_OCCLUSION_NODE_PATHS`: rack, 3 key machines, 5 exhibits), and each door's real prompt rect from `get_interaction_rect`.
  - `hall_prototype.py` builds every door, alcove, lantern and decor count from that data instead of the old region's hand-placed values. Decor counts scale with area.
- **Each door on the side the player uses it from.**
  - A door shows on the camera-facing south face whenever the player can stand south of it, inside the game's prompt area (the prompt rect grown by the game's 14 px margin and the 14×8 body). That gives six face doors.
  - Only the Wake Room door, with no standing room south of it, keeps the stair down from the north.
  - Greenhouse, Library and Circuit have reachable floor on both sides of their walls (1,784 / 2,501 / 3,400 standing px north). The old art paints all three arches on the south face, and the game puts the player back south of them, so they face south too. My earlier plan had stairs for Greenhouse and Library; that was wrong and is not built.
- **Doors that sit flush.**
  - Smoothing left some door faces a few px ragged; Final's measured edge was a 4 px bump below the real face. The face is now cut back to one straight line across each door.
  - A lantern hangs beside every door: the search follows the face, so doors near corners are lit too (Circuit and Dining were unlit).
  - The keystone is a pale stone wedge with a small violet gem, not a white block.
- **Gallery works across the Hall.** The gaps between corridors join into pits of up to 222,565 px, where the old rule placed 2 pipes and 4 gears per pit.
  - Pipe runs are at most 170 px, end in iron valve housings on the pit floor, and alternate direction. Before, single pipes ran across the whole Hall like ruled lines.
  - Counts scale with pit area, and gear trains of two or three mesh at their rims. Gears no longer overlap: 143 gears, 0 overlapping pairs; the old rule gave 169 overlapping pairs.
- **Depth for every prop.** The preview and the captures put the occlusion shader on all 9 props and their contact shadows (`Depth.add_props`), not only the HD exhibit.
- **Captures:** door shots 05–10 from the floor in front of each arch; art shots 13–17 across the north, east and centre; the overview zoom fits the whole Hall on one screen.

### Exact files

- Changed: `tools/blender/hall_prototype.py`, `tools/blender/export_hall_region.gd`, `tools/blender/prototype_depth.gd`, `tools/blender/capture_prototype.gd`, `tools/blender/play_prototype.gd`.
- Evidence in `docs/evidence/2026-10-21-blender-hall-prototype/`:
  - rebuilt comparisons 01–04, 11, 12, 20 and `silhouette-diff.png`;
  - new `14-art-north.png`, `17-art-heart.png`, `26-hall-doors.png` (every door, in game), and `27-doors-and-gallery-works.png` (first whole-Hall pass vs final).
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/`, now holding the whole Hall's masks, `region.json` and render (3840×2560).

### Verification

- **Layout loop:** a no-Blender harness runs the builder's `Layout` in 5 s. It checks each door's side against the game's prompt rects, which match `game_world.gd` exactly, and checks that every door face is flush. It fails on the previous code (Wake given a face door; 23 ragged columns at Final).
- **Gear check:** 0 overlapping gear pairs; it fails on the previous rule.
- **Blender:** final render at 128 samples, 148 s, 4.1 GB peak. Footprint: IoU 1.0; against the collision beyond 3 game px, 20 extra and 0 missing px. Missing px beside a deliberate cut (alcoves, door faces, the stair) no longer count; before that change it was 62 px, all beside cuts.
- **Native captures:** `capture_prototype.gd` passes all 87 checks in EN and ZH, including "Every listed prop takes the depth shader" and a walkable spot for all 10 player shots. No shader errors.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`; pyflakes is clean. The headless editor parse (isolated HOME) has 0 script errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `region [0, 0, 1920, 1280], 330 glows, 1 HD props, depth true (9 props)`.

### Limits / next stage

- **Only the Circuit exhibit is HD.** The other 8 props are still the pixel sprites, now with depth.
- **The game still shows 66 px figures;** 50 px exists only in the preview.
- **The export can warn at exit:** in 1 of 3 runs it printed "3 resources still in use at exit". The export itself is complete every time.
- **Next, if approved:** HD models for the remaining exhibits, machines and rack; then move the HD Hall, the depth shader and the 50 px Hall figure into the game itself.
- **GitHub:** committed and pushed as `1cd575d` with the user's approval.

---

## Stage: UX-20261021-44

- **Date:** 2026-10-21
- **Status:** taller walls and smaller Hall figures in the prototype, awaiting the user's review. Nothing ships.
- **Request:** on stage 43 (committed and pushed as `59af5ea`), the user chose "adjust": "墙太矮了，也可能是因为人物现在的贴图太高了，导致看上去还是有点不好" (the walls are too low, or the figure too tall, so it still looks off).
- **Cause:** 24 px walls beside a 66 px figure stood about a third of its height, which reads as a parapet, not a castle wall.

### What changed

- **Walls 40 px tall** (`FACE_PX`). The face decor is resized for 40 px faces: banners, tapestry, niche, rift and ivy. The feet stay in view on 74% of the opening route; that was measured for 32/36/40/44 px as 83/78/74/71%.
- **Figures at 50 px instead of 66 in the preview** (`prototype_depth.gd`, `FIGURE_SCALE` = 1.1/1.45).
  - Only the player's `VisualRoot` and the Guardian's `GuardianCore` change, with their offsets scaled, so the feet stay put.
  - Collision and navigation are untouched, and the preview holds its scale if the game resets it.
  - The handoff already listed smaller Hall figures as an earlier user request. The game itself still uses 1.45.
- **Ghosts instead of silhouettes.** Whatever a wall hides now shows through:
  - the player in its own colours, tinted violet, at 45% opacity;
  - the Guardian tinted red, at 45%;
  - footprints at 35%, so the route stays readable behind taller walls.
  - Contact shadows and HD props are still fully hidden.

### Verification

- **Blender:** final render at 128 samples, 39 s. The footprint check is unchanged: IoU 1.0, and against the collision beyond 3 game px, 16 extra and 11 missing px.
- **Native captures:** `capture_prototype.gd` passes all 36 checks in EN and ZH, with no shader errors.
- **Godot:** gdlint is clean. The headless editor parse has 0 script errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `78 glows, 1 HD props, depth true`.
- **Evidence:** the comparisons were rebuilt. New: `25-taller-walls.png` (stage 43 vs this pass, behind a wall).

### Limits / next stage

- **Occlusion trade-off:** at 40 px, a figure hugging a wall's north side shows only its head above the wall; the rest is a ghost.
- **The Circuit cabinet:** the wall in front of its alcove now hides its lower half.
- **Next:** if the user approves, put the figure scale into the game's Hall profile (`scripts/player.gd`, Guardian scene) together with the HD Hall, and extend the pipeline to the whole Hall.
- **GitHub:** committed and pushed as `0c0c00d` with the user's approval.

---

## Stage: UX-20261021-43

- **Date:** 2026-10-21
- **Status:** walls with real depth built in the prototype region, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 42 the user chose to extend the prototype to the whole Hall (stage 42 is committed and pushed as `3d8143c`). Before that, they raised three problems:
  - "大厅的钟感觉很怪异，有点感觉穿模了，横在那里的感觉很不好": the Hall's "clock" looked strange and seemed to clip.
  - "大厅下面的墙感觉玩家走不过去": the walls below felt impassable.
  - "现在的效果玩家走到墙壁旁边就和踩着墙壁的上沿一样，不知道是否是因为人物模型现在是贴图的问题": next to a wall, the player looks like they are standing on its top edge; is it because the character is a flat sprite?

### Diagnosis

- **Measurement:** at all 1,926 reachable spots where the player's feet touch a wall to their south, the drawn wall top began 1 px below the feet.
- **Cause:** the prototype drew every wall's cap plus south face exactly over its collision. So a wall's top edge sat exactly where the player stops on its north side, and nothing was ever drawn in front of the player. The current hand-painted art has the same property (`04-behind-wall.png`, left). The character being a sprite only adds to it: there was no shadow and no occlusion.
- **The "clock":** most likely the brass compass rose at the arrival, a ringed, ticked disc lying flat. The 3D candles, rubble and cogs around the floor could be walked through.
- **The walls below:** the Wake gate's door was drawn on its south face, facing a strip of floor no player can reach, while the player arrives on its north side. Other walled-off strips along the bottom were also drawn as floor.

### What changed

- **Walls stand on the collision** (`tools/blender/hall_prototype.py`, `Layout`). Every wall px is now the base of a block 24 px tall on screen, and its top rises above the base the way a real wall's does.
  - 24 px keeps the player's feet in view on 94% of the opening route (measured).
  - A player hugging a wall's north side keeps head and shoulders of their 66 px.
  - Movement, doors and the Guardian are unchanged.
- **Depth map and occlusion:**
  - `render-depth.png`: for each screen px, the ground y of the wall seen there. It is computed from the same heightfield, and the nearer surface has the larger ground y.
  - The new `tools/blender/prototype_depth.gd` puts a shader on the player, the Guardian, the footprints and the HD props that hides whatever a wall in front covers.
  - Characters keep a faint violet (player) or red (Guardian) silhouette there, so they are never lost.
  - Both characters get a soft contact shadow, which walls hide too.
- **No floor beyond reach:** floor no player body can reach, and that no reachable floor touches, is now castle mass. That is 78,291 px over the map, including the strips along the bottom.
- **The Wake Room door from the player's side:** a stair drops south through the gate wall from where the player stands. It is lit violet from below and runs under the mass beyond, with candles on the wall tops at its mouth. The door on the south face is gone.
- **The Circuit exhibit** stands in a floor-level alcove cut into the wall mass it sits in, instead of floating over the wall top.
- **Removed:** the compass rose, the ritual candles, the rubble and the loose cogs. Everything left on walkable floor is flat (notes, chalk, spills, cracks, grates, the rug).
- **Smaller decor:** face decor is sized for 24 px faces: banners, tapestry, niche, rift and ivy.
- **Wall tops:** lighter, so masses read as stone rather than holes.

### Findings

- **Footprint check:** the walls rendered from straight above, unstretched, have IoU 1.0 with the heightfield. Against the collision, beyond 3 game px, only 16 px are extra and 11 px missing, at corners.
- **In play** (`04-behind-wall.png`, `24-walls-with-depth.png`): with feet against a wall's north side, the wall hides the legs and the player reads as behind it, not on top of it.

### Exact files

- Changed: `tools/blender/hall_prototype.py`, `tools/blender/play_prototype.gd`, `tools/blender/capture_prototype.gd` (new shot `04-behind-wall`, depth on/off per pair), `tools/blender/prototype_props.gd` (`standing()`).
- New: `tools/blender/prototype_depth.gd` (+UID).
- Evidence: rebuilt comparisons, plus new `04-behind-wall.png` and `24-walls-with-depth.png` (stage 42 vs this pass), in `docs/evidence/2026-10-21-blender-hall-prototype/`.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/`, now also holding `render-depth.png`.

### Verification

- **Blender:** final render at 2048×1024, 128 samples, 31 s, with the footprint check as above. `py_compile` and pyflakes are clean.
- **Native captures:** `capture_prototype.gd` passes all 36 checks in EN and ZH, including "The depth map loads" and the new shot. No shader errors.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`. The headless editor parse (isolated HOME) has 0 script errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `79 glows, 1 HD props, depth true`.

### Limits / next stage

- **Still open:** the Wake stair is 17 px wide (the gate wall's north edge steps east of it). Wall-mounted decor is not in the depth map, which is harmless because the player's body always stops 8 px south of a face.
- **Next:** once the user approves the depth model, extend the pipeline to the whole Hall, including the other exhibits, machines and doors. Doors on walls that the player reaches from the north will need stairs or openings like the Wake gate's.
- **GitHub:** committed and pushed as `59af5ea` with the user's approval. No Web deployment.

---

## Stage: UX-20261021-42

- **Date:** 2026-10-21
- **Status:** denser dressing and the first HD interactive prop built in the prototype region, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** on stage 41 the user chose "满意，下一步把左边的电路展台也换成高清模型" (replace the Circuit exhibit on the left with an HD model) and noted "装饰太少了" (still too little decoration). Stage 41 was committed and pushed as `2bef8ca` with their approval.

### What changed

- **HD Circuit exhibit** (`build_circuit_exhibit`). The Circuit Room knowledge exhibit is modelled as a walnut electrical cabinet:
  - two brass-bezelled meters on one closed circuit (its text describes "the two gauges measure a closed electrical circuit"), joined by copper leads;
  - a knife switch, a copper coil, binding posts, a crest with a lit filament bulb, and cupboard doors.
  - **Integration without touching gameplay.** The game reads the exhibit's feet, focus point, occlusion and highlight from its `Sprite` node's opaque bounds.
    - The model is built to touch all four sides of the sprite's rect (62.5, 912.5, 37.5×92.5) and rendered alone over transparency into exactly that rect, as `render-prop-CircuitRoomKnowledge.png`, listed in `render-props.json`.
    - The new `tools/blender/prototype_props.gd` swaps only that sprite's texture and scale in the preview and captures, and keeps the contact shadow in place.
    - Headless check: feet (81.25, 1005) and rect are identical before and after the swap, and `restore()` returns the pixel prop exactly.
- **Denser dressing.** Wall slots are now about 30 px apart (they were about 46), and six new wall kinds join the mix: iron candle sconces, blueprints, a torn treasure map, an oval mirror with a pale figure in it, a star-chart tapestry, and violet light leaking from wall cracks.
  - **Floor** (flat, walk-over, tagged `floor_decal`):
    - 29 dropped notes in clusters;
    - 2 chalk diagrams (a triangle in a circle, arrows, working);
    - 3 glowing reagent spills, violet and green;
    - 12 cracked flagstones, some leaking violet light;
    - 8 loose cogs and 10 rubble heaps at the walls' feet;
    - 4 groups of ritual candles around the compass rose.
  - **Wall tops:** moss patches and a broken crack network on the dark slate, 10 candle groups burning near their south edges (inside the outline), and 6 ivy curtains hanging down the faces.
  - There are 91 animated glows now (64 before the floor dressing). The bulb flickers like a filament.
- **Fixes along the way:**
  - The floor and cap ambient occlusion only considers the hall's own stone. Without that, decals and props darkened the floor in squares.
  - The capture tool logs the spot each player shot uses.

### Findings

- **Gameplay still unchanged:**
  - IoU against the smoothed outline is 0.99993.
  - Against the collision, 0 px are missing beyond 3 game px, and the same 16 px are extra at the two pocket-adjacent spots.
  - Every new wall and top item is inside the outline. Every floor item is flat or a few px tall, and the silhouette pass skips it like the floor.
- **In play** (`23-denser-dressing.png`):
  - The arrival now has the lit cabinet, a candle ring around the compass and notes underfoot.
  - Every corridor has something to look at, and the violet spills and leaks hint at more down the side passages.
- **Render cost:** 34 s at 128 samples. A probe showed the Metal kernel optimisation level makes no difference at 128 samples.

### Exact files

- Changed: `tools/blender/hall_prototype.py`, `tools/blender/play_prototype.gd`, `tools/blender/capture_prototype.gd`, `tools/blender/prototype_glows.gd`.
- New: `tools/blender/prototype_props.gd` (+UID).
- Evidence: `docs/evidence/2026-10-21-blender-hall-prototype/`.
  - The six comparisons were rebuilt from fresh EN/ZH captures.
  - New: `23-denser-dressing.png` (stage 41 vs this pass).
  - Updated: `silhouette-diff.png`.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/`, containing `render.png`, `render-glows.json`, `render-props.json`, `render-prop-CircuitRoomKnowledge.png`, the silhouettes, `hall_prototype.blend` and the captures.

### Verification

- **Blender:** final render at 2048×1024, 128 samples, with the silhouette check as above. `py_compile` and pyflakes are clean.
- **Native captures:** `capture_prototype.gd` passes all 30 checks in EN and ZH, including "The HD props load", and the shots were inspected.
- **Exhibit swap:** a headless check confirms the swap leaves the exhibit's feet and rect identical.
- **Godot:** gdlint is clean on all `tools/blender/*.gd`. The headless editor parse (isolated HOME) has 0 script errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `BLENDER_PROTOTYPE_OVERLAY region [0, 768, 1024, 512], 91 glows, 1 HD props`.

### Limits / next stage

- **Remaining pixel elements:** the player, the Guardian and the footprints are still pixel art on the HD render.
- **Next:**
  - Extend the pipeline to the whole Hall, including the other four knowledge exhibits, the storage rack, the three Final Key machines and the seven doors.
  - Then decide on characters.
- **GitHub:** committed and pushed as `3d8143c` with the user's approval. No Web deployment.

---

## Stage: UX-20261021-41

- **Date:** 2026-10-21
- **Status:** wall dressing and living light added to the prototype region, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user approved stage 40 ("满意，继续加墙面细节和灯光闪烁"). They added: "原来的可以全部修改掉，增加你觉得符合我游戏的细节" (anything original may be replaced; add the details that fit the game). Stage 40 was committed and pushed as `2a853a2` with their approval.

### What changed

- **Wall dressing** (`tools/blender/hall_prototype.py`, `dress_faces`). The free stretches of every full-height south face are filled around the lanterns, banners and the Wake gate.
  - Wide gaps take story pieces, narrow gaps small ones, and each kind is capped so nothing repeats.
  - This pass placed:
    - 6 candle alcoves: an arched recess with three lit candles and its own small light;
    - 3 portraits: a darkened oil sitter in a gilt frame, cracked varnish, eyes that glint;
    - 1 bookshelf: cloth-bound books in a muted palette, a couple leaning, and glowing potion flasks in glass;
    - 1 chalkboard: lines of equations and a ringed diagram, half rubbed out;
    - 2 clocks stopped at eight minutes to midnight;
    - 3 brass pressure gauges on risers, needles in the red;
    - 1 detective's case board: notes and photographs pinned to cork, tied with red string;
    - 9 cobwebs in upper corners.
  - The case board, shelf, lantern and banner share the long wall beside the opening route.
- **Screen proportions:** things hung on a face are scaled ×1/sin 40° in height, so clocks and dials read round, as the gate arch does, and lanterns are taller than wide.
- **Living light:** the Blender script writes `render-glows.json` beside the render, with 48 glows: lanterns, candles, potions, crystals, grates, the compass runes and the portraits' eyes.
  - The new `tools/blender/prototype_glows.gd` adds an additive halo for each glow under the overlay.
  - In the playable preview the halos move on smooth noise: lanterns and candles flicker; crystals, grates, runes and eyes pulse slowly.
  - Captures show the halos at rest.
  - The Hall's fog (z 100) still covers them, so unexplored rooms stay dark.

### Findings

- **Gameplay still unchanged:**
  - IoU against the smoothed outline is 0.99993.
  - Against the collision, 0 px are missing beyond 3 game px, and the same 16 px are extra at the two pocket-adjacent spots.
  - All dressing sits inside the wall outline. The gauge risers stand on the floor at the wall's foot, within 3 px.
- **In play** (`12-art-centre`, `22-wall-dressing.png`): the walls now give each corridor its own reason to look, and the warm halos make the lamplight feel alive.
- **Still open:**
  - The Circuit knowledge exhibit is still a pixel sprite on the HD render. Replacing it needs care, because it is interactive.
  - The wall tops are uniform dark slate.

### Exact files

- Changed: `tools/blender/hall_prototype.py`, `tools/blender/play_prototype.gd`, `tools/blender/capture_prototype.gd`.
- New: `tools/blender/prototype_glows.gd` (+UID).
- Evidence: `docs/evidence/2026-10-21-blender-hall-prototype/`.
  - The six comparisons were rebuilt from fresh EN/ZH native captures.
  - New: `22-wall-dressing.png` (stage 40 vs this pass).
  - Updated: `silhouette-diff.png`.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only: `prototypes/blender_hall/`, containing `render.png`, `render-glows.json`, the silhouettes, `hall_prototype.blend` and the captures.

### Verification

- **Blender:** final render at 2048×1024, 128 samples, 67 s, with the silhouette check as above. `py_compile` and pyflakes are clean.
- **Native captures:** `capture_prototype.gd` passes all 29 checks in EN and ZH, and the shots were inspected.
- **Godot:** gdlint is clean on all three GDScript tools. The headless editor parse (isolated HOME) has 0 script errors. `git diff --check` is clean.
- **Preview:** relaunched. Its log reads `BLENDER_PROTOTYPE_OVERLAY region [0, 768, 1024, 512], 48 glows`.

### Limits / next stage

- **Proposed next:**
  - An HD model of the Circuit exhibit that still reads as interactive.
  - Moss and wear on the wall tops.
  - Then extending the pipeline to the whole Hall, including the seven doors.
- **GitHub:** committed and pushed as `2bef8ca` with the user's approval. No Web deployment.

---

## Stage: UX-20261021-40

- **Date:** 2026-10-21
- **Status:** second art pass on the same prototype region complete, awaiting the user's review. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** the user's verdict on stage 39 was "这现在只是做了一小部分吗，感觉还是一半，太简陋了，不够让人有探索欲望和神秘感" (only a small part, half-finished, too crude, no pull to explore, no mystery). They chose to tune this region until it satisfies before extending it.
- **Scope:** the region is the lower-left fifth of the Hall (x 0–1024, y 768–1280 of 1920×1280), around the Wake gate and the opening route.

### What changed (all in `tools/blender/hall_prototype.py`)

- **Clean walls instead of 4 px stairs.** The collision is a 4 px raster traced from the old art, so every diagonal was a staircase.
  - Geometry is now built per game px from a smoothed copy (Gaussian σ 2.5 px, threshold ½, never thinner than the collision eroded by 1 px). Straight edges stay exact and stairs become slopes.
  - No edge moves more than 2 px from the collision.
  - Faces are merged into quads within 32 px tiles: 19.7k faces.
- **Dark wall tops, lit outlines.** Wall tops are dark slate, and a lit capstone lip runs along every edge: 8 px on the camera-facing south edge, 3 px elsewhere. Each wall mass keeps a crisp outline, and the corridors become the lit space to explore.
- **Real machinery in the galleries.** The striped brass shader, which read as staircases, is gone. Galleries now have a dark plate floor with 3D brass works:
  - 22 flanged pipe runs;
  - 35 toothed brass and copper gears with spoke windows;
  - 11 violet crystal clusters, each lit from above.
  - Everything stays below the rim, so it sits inside the wall outline.
- **Lanterns.** There are 8 iron lanterns (arm, roof, posts, glass with a flame inside), each on a real full-height south face.
  - They line the opening route, and some light side corridors and the Circuit exhibit, so warm light invites a look.
  - Each one has a soft warm pool on the floor below.
- **Decor that tells the place:**
  - 3 swallowtail banners (violet and teal) with the castle's gear-and-eye sigil.
  - A brass compass rose with a ring of faintly lit runes, set in polished stone at the arrival: (180, 948), r 46.
  - A worn runner rug along the route's first east leg, which the violet footprints now follow.
  - Two iron floor grates with violet light rising through them. A script places them in quiet spots well off the route, at (514, 1114) and (582, 786), as a reason to wander.
- **Tried and dropped:** floor puddles. At game scale they read as dirt smears, not water.
- **Render cost:** 128 samples take about 41 s on the M3 (about 19 s of that is fixed per run). Two fixes:
  - The compass shader had been on the floor material, so every floor pixel evaluated about 120 nodes. The compass is now its own disc object.
  - Decorative glows are excluded from light sampling, because the point lights carry the light.

### Findings

- **Gameplay still unchanged.** Against the smoothed outline the render's silhouette has IoU 1.0. Against the raw collision:
  - 0 px are missing beyond 3 game px.
  - 16 render px are extra beyond 3 game px, at two pocket-adjacent spots 1–2 game px across.
  - All other differences are the 2 px smoothing and the 308 filled pocket cells (5,700 px), as before.
- **In play** (native captures with real fog and the HUD):
  - The arrival opens on the compass, a lantern pool and the rug that the footprints follow.
  - Gears and violet crystals glint in the galleries.
  - Banners and grates draw the eye down side corridors.
- **Still open:**
  - The pixel-art player and the Circuit exhibit sit on an HD background.
  - The south wall faces are still mostly plain stone.
  - The lights are static in the render. In play they could flicker.

### Exact files

- Changed: `tools/blender/hall_prototype.py`.
- Evidence: `docs/evidence/2026-10-21-blender-hall-prototype/`.
  - The six side-by-side comparisons were rebuilt from fresh native captures.
  - New: `21-region-iteration.png`, comparing the first prototype with this pass.
  - Updated: `silhouette-diff.png`. Red marks extra px beyond 3 game px and blue marks missing px beyond 3 game px; the dim colours are within tolerance.
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.
- Local only (gitignored, regenerable): `prototypes/blender_hall/`, containing `render.png`, `silhouette*.png`, `hall_prototype.blend` and the EN/ZH captures.

### Verification

- **Blender:** final render at 2048×1024, 128 samples, 42 s, with the silhouette check as above. `py_compile` and pyflakes are clean.
- **Native captures:** `capture_prototype.gd` passes all 29 checks in EN and ZH. All shots are 1024×768 and were inspected.
- **Godot:** the headless editor parse has 0 script errors (isolated HOME). `git diff --check` is clean.
- **Preview:** the playable preview was relaunched on the new render: `play_prototype.gd -- --hall`.

### Limits / next stage

- **Proposed next stage:** after the user's review, add the remaining wall-face detail: alcoves with candles, portraits, shelves. In-game lantern flicker and crystal pulse could follow.
- **Later:** extend the pipeline to the whole Hall, including treatments for the seven doors (most face directions the camera cannot see). Characters stay deferred.
- **GitHub:** committed and pushed as `2a853a2` with the user's approval. No Web deployment.

---

## Stage: UX-20261021-39

- **Date:** 2026-10-21
- **Status:** prototype complete, direction decision pending. Nothing ships: the game, its scenes and the Web build are unchanged.
- **Request:** after stage 38 shipped, "现在进行下一步的搭建": build the Blender 3D→2D Hall prototype the user chose (HD style, one screen, characters deferred), to judge whether it beats the current hand-painted AI art.
- **Follow-up:** the user chose "improve 3D". They had found no 3D in the game; until then it had only appeared inside the capture tool. Two responses:
  - a playable preview launcher, `tools/blender/play_prototype.gd`;
  - a quality pass with CC0 photo materials and visible wall lanterns.

### What was built

- **`tools/blender/export_hall_region.gd`** (Godot, headless) exports the Hall layout:
  - `wall_mask.png`: the real wall collision of the whole map, sampled on the collision's own 4 px grid with physics point queries.
  - `outside_mask.png`: floor outside the castle, from the floor art's alpha.
  - `region.json`: the prototype region (x 0–1024, y 768–1280, around the Wake spawn), spawn, doors, exhibits and the opening route.
- **`tools/blender/hall_prototype.py`** (Blender 5.2 `bpy`, Cycles on the M3 Metal GPU) builds and renders the Hall in 3D:
  - **Camera:** orthographic, tilted 40° from vertical. The scene's Y axis is pre-stretched by 1/cos 40°, so the floor lands 1:1 on game coordinates and heights show as z·sin 40°.
  - **Walls:** each wall column run gets a top cap plus a camera-facing south face. Its height is chosen so the two cover exactly the run's collision cells. Runs sharing a south edge share one face height, so caps don't step.
  - **Galleries:** large wall masses get a stone rim around a sunken machinery gallery, echoing the current art's pale outlines around dark machinery.
  - **Wake gate:** a taller gatehouse face carrying an arched oak door, with pale stone frame, brass straps, violet keystone and twin lanterns. It is shaped in screen proportions so the arch reads round after the tilt.
  - **Materials:** CC0 photo texture sets from Poly Haven at 1k, with per-face planar UVs so the normal maps shade correctly. Each is graded toward the castle's violet-grey and brass palette:
    - `large_floor_tiles_02` for the floor;
    - `castle_wall_slates` for the wall faces, with brass bands;
    - `large_grey_tiles` for the capstones;
    - `metal_plate` under the brass pipes and violet crystals of the galleries;
    - `rough_pine_door` for the gate door.
    - The first four are by Rob Tuytel, the door by Dimitrios Savva. Licence, source URLs and SHA-256 are in `prototypes/blender_hall/textures/sources.json`.
    - Without the textures folder the script falls back to its original procedural materials.
  - **Lighting:** moonlight, violet ambient, and iron-bracketed wall lanterns.
    - The lanterns hang on the nearest full-height south face, so the light has a visible source and never looks like an obstacle on the floor.
    - Dim floor fills, violet glows and the gate lights complete it.
  - **Output:** a 2048×1024 render (2 px per game px), 128 samples, about 35 s.
- **`tools/blender/capture_prototype.gd`** (native Godot) replays the real Wake Room exit. It then captures the same gameplay moments with the current art and with the render laid over it (a visual-only Sprite2D at z −40; collision, fog, route and nodes untouched).
- **`tools/blender/play_prototype.gd`** (native Godot) runs the real game and lays the render over the Hall region whenever the Hall loads.
  - `-- --hall` jumps straight to the Hall arrival.
  - Usage: `HOME="$PWD/.godot/blender-proto-play/home" godot --path . --script res://tools/blender/play_prototype.gd -- --hall`.
  - This is the only way to see the prototype in play: the normal game and the Web build do not include it.

### Findings

- **Gameplay unchanged by construction.** The rendered wall outline matches the collision: IoU 0.9938 and **0 missing px** at 2048×1024. All 5,972 extra px are accounted for:
  - 5,760 are 308 enclosed floor cells inside wall masses. No body fits or reaches them, and drawn as floor they became black crevices, so they are drawn as wall.
  - 212 are one-cell lips and the lanterns' few-pixel overhang on their faces.
  - With a matching outline, the player can never stand behind a wall, so no occluder layer is needed.
- **Better than the current art:** one consistent projection, with real wall height, lit south faces, cast shadows, brass detail and a gate that reads as a door. With the CC0 materials it reads as a real stone castle, and the violet footprints stand out more clearly on the darker stone.
- **Worse than the current art:**
  - It is darker and cooler than the warm current art. The procedural first pass was also plainer; the CC0 pass largely closes that gap.
  - The collision's 4 px stair-steps show as jaggies on diagonal edges.
  - The pixel-art player and exhibit now sit on an HD background.

### Exact files

- New tools: `tools/blender/export_hall_region.gd` (+UID), `tools/blender/hall_prototype.py`, `tools/blender/capture_prototype.gd` (+UID), `tools/blender/play_prototype.gd` (+UID).
- Texture provenance: `tools/blender/cc0_textures.json` (assets, authors, licence, URLs, SHA-256) and `tools/blender/fetch_textures.py`, which downloads and verifies the maps. The binaries are not committed.
- `.gitignore` now ignores `/prototypes/`, the regenerable outputs.
- Evidence: `docs/evidence/2026-10-21-blender-hall-prototype/`, containing 6 side-by-side comparisons at native 1024×768 (arrival with real fog, first corridor, Wake gate, two fog-lifted views, region overview) and `silhouette-diff.png`.
- Local only, regenerable and gdignored: `prototypes/blender_hall/`, containing the masks, `region.json`, `render.png`, `hall_prototype.blend` (open it in Blender to inspect the 3D scene), the raw EN/ZH captures, and `textures/` (15 CC0 maps, 8.2 MB, with `sources.json`).
- Docs: this report, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`.

### Verification

- **Silhouette check:** rendered by Blender's Workbench engine with anti-aliasing off, compared pixel by pixel with the collision. Result as above. The textured final render takes about 38 s (2048×1024, 128 samples, M3 Metal).
- **Preview:** the playable preview was launched and its log confirms the overlay is added to the Hall.
- **Native captures:** `capture_prototype` passes in EN and ZH; all shots are 1024×768 and were inspected.
- **Static checks:** Godot headless editor parse has 0 script errors. `tools/check_static.py` reports only the 15 pre-existing issues. gdlint is clean on both new GDScript tools, `hall_prototype.py` compiles, and `git diff --check` is clean.

### Limits / next stage

- **Scope:** one region only, and the render is not integrated into the game.
- **Quality:** a richer pass would use CC0 PBR texture sets with provenance, decorative 3D props (pipes, braziers, rubble), and chamfered diagonals where the collision allows.
- **Style:** the characters and pixel props would need the same treatment for one style.
- **Proposed next stage:** the user decides between three options: raise the 3D quality and extend it to the whole Hall; a hybrid that uses the 3D pass for depth and lighting under the painted texture; or stay 2D.
- **GitHub:** the user approved committing `tools/blender/`, `docs/evidence/2026-10-21-blender-hall-prototype/`, `.gitignore` and these doc updates. `prototypes/` stays local. No Web deployment.
- **User verdict on this pass:** still too plain and half-finished, without enough pull to explore or sense of mystery. The user wants this region tuned before anything is extended (see the next stage).

---

## Stage: UX-20261021-38

- **Date:** 2026-10-21
- **Status:** complete
- **Request:** After the Wake Room, the tutorial route is "completely wrong" and passes through walls; many Hall textures (map art and item art) look like odd stickers. The user chose six fixes: smooth fog, redraw the Hall walls, remake the Hall props, readable footprints and arrival framing, fix the overlapping card text, align navigation. They asked mid-stage about rebuilding maps and characters in Blender, then chose an **HD Blender one-screen Hall prototype** as the next step. Characters are deferred, and the 2D wall/floor redraw is paused (superseded).
- **Delivery:** actual main project, plus code mirrored to the session worktree. Committed and pushed to `origin/main` as `8084ff2` ("Lead the Hall trail down corridor centres and redraw its props"). After the user's local playtest (the full Wake → Hall → Chemistry opening at full health, no script errors), it was **deployed to production on 2026-10-21**.
  - Deployment: `shadow-castle-detective-play-ick3tv2wl-cyc4.vercel.app` → https://play.shadowcastledetective.com.
  - Verification: the live `index.pck` (98,455,444 bytes) has the same SHA-256 as the local export (`371311bd…`); the service-worker cache version is `1792622131|5145128`; the browser boot shows the title screen with no console errors or failed requests.
  - Rollback target: the previous production deployment `shadow-castle-detective-play-eo9jos5ib-cyc4.vercel.app`.

### Diagnosis

- **Route start:** the shipped authored route (`data/hall_tutorial_route.json`) begins at the old scene placeholder (512,384), not at the Wake spawn (224,984). Its first segment is a teleport through the stone.
- **Old connectors:** the route was copied point by point. The connectors to it used the coarse 32px grid, and collision repair then added zigzags. Stage 1 measured 1867px against a 1557px shortest path.
- **Why it looked like wall-walking:** the route centreline touched 0 of 936 wall samples. The visible problem was presentation:
  - the first prints were hidden under the arrival dialogue;
  - later prints were drawn above the fog past corners, so the trail glowed through walls;
  - the rehearsal Guardian was placed a fixed 190px beside the trail, which is inside the stone in most corridors.
- **`opening_blockers_test`:** returned a 0-point route because the Chemistry door's grid cell is solid. This failure predates stage 37.
- **Props:** 548–1774px AI images were shown at 0.07–0.14 scale without mipmaps, so they aliased. Two exhibits were stretched (Chemistry core 54% too tall, Circuit 16%), and M1 carried an opaque backdrop box.

### Player-facing changes

- **Route:** new `HallRoutePlanner` plans on the Guardian's existing 16px collision lattice.
  - The trail starts where the player stands and keeps to corridor centrelines in long straight legs, never nearer the stone than the search was.
  - Corners sit where there is more room, and sub-node 16px jogs become slight drifts.
  - The authored recording now only selects corridors; its wobble and through-wall start are not replayed. The file itself is unchanged.
  - Stage 1 is 1800px in 15 legs, down from 1867px with 38 points.
- **Footprints:**
  - Raster shoe prints now sit in a small additive violet glow, matching the "glowing footprints" copy.
  - They show only up to the first print that is out of sight and far nearer in a straight line than along the trail, so no print glows through a wall the trail goes round.
  - Prints under the character are hidden, and new prints fade in.
  - The compass names the heading of the next leg rather than the goal's bearing (the old card said NORTH-EAST while the trail went south).
- **Rehearsal Guardian:** follows by distance walked, not waypoint index. Its step aside is limited to the open floor on the roomier side with a 24px wall gap, and eases at turns.
- **Fog:** a smoothing shader replaces 32px black blocks with soft rounded falloff. Flashlight, memory and power gating are unchanged.
- **Survival card:** rows are stacked by measured line count; the English "RUN —or click a clear route" no longer overprints "USE a marked door or exhibit".
- **Props:** all nine Hall props are deterministic pixel art at 1.25 world px per texel, matching the walls.
  - Uniform scale, nearest filtering, lossless import and contact shadows.
  - Visual feet moved ≤0.62px. The stretch is removed while keeping visible area, and M1's backdrop is gone.

### Exact files

- **New code:** `scripts/hall_route_planner.gd`, `scripts/hall_fog_smooth.gdshader` (+UIDs), `tests/hall_visual_capture.gd` (+UID), `tools/pixelize_hall_props.gd` (+UID).
- **Changed code:**
  - `scripts/game_world.gd`: route builder, goal candidates, start squaring, jog folding, footprint visibility/fade, guardian mark, compass, fog material, lint-ordered constants.
  - `scripts/hall_footprint_marker.gd` (violet glow).
  - `scripts/hall_route_store.gd` (contract comment).
  - `scripts/onboarding_hud.gd` (measured rows).
- **Changed tests:** `tests/hall_route_authoring_test.gd` (corridor-hint contract, wall-safe Guardian aside), `tests/footprint_presentation_test.gd` (no print through walls or on the character, compass heading), `tests/tutorial_onboarding_test.gd` (Hall card rows, EN/ZH).
- **Scene and assets:**
  - `scenes/wall_collisions.tscn`: nine prop sprites (texture/scale/position/filter), `ContactShadow` children, new texture ext_resources only.
  - New `assets/props/hall_pixel/`: 9 prop PNGs, the shadow atlas, imports, `manifest.json`, `PROVENANCE.md`.
- **Docs:** `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- **Evidence:** `docs/evidence/2026-10-21-hall-visual/`, which contains `compare/` (before/after card EN/ZH, route start, route 1/3) and `props/` (contact sheet, in-game before/after, M1 backdrop mask).
- **Raw native captures** (34 before, 34 after EN/ZH, WIP and prop runs) were moved out of the repo to the session files to keep 49 MB of frames out of the checkout. `tests/hall_visual_capture.gd` regenerates them.

### Verification

- **Parsing:** Godot 4.7 headless editor parsing passes in both roots. `git diff --check` passes in both.
- **Full main sweep:** 54/54 `tests/*_test.gd` suites passed with fresh guarded HOMEs and no script/parse errors. This includes `opening_blockers_test`, which now passes; it was the single stage-37 failure. After the final bare-point endpoint fix the sweep was 53/54 at a load average of ~20. The only failure was `fog_performance_test`'s absolute 3ms budget (4.92ms), and it passes at 1.85ms when rerun after the load fell.
- **Route suites (main and session worktree):** opening blockers, authoring, footprints, staged guidance, guided crossing, onboarding and tutorial chase all pass.
- **Authoring test:** a hand-walked recording with ±5px wobble that starts with a through-wall teleport is followed by corridor (the route passes within 64px of the authored detour) while using fewer than half its points. Every leg is wall-clear and axis-aligned within one jog, and clearing the recording returns the plain corridor.
- **Footprint check:** walking the whole opening route in 96px stops shows 0 visible prints through walls and 0 prints on the character.
- **Guardian aside:** in 41 samples along the route, the Guardian's step aside is never in stone.
- **Pressure audit** on the planned trail: 2528px/14.04s, 384px/2.13s and 287px/1.59s, 17.77s total, minimum reaction 4.32s, PASS. On the same layout the previous builder measured 2725/320/286px.
- **Fog cost:** the CPU fog update is unchanged. An interleaved same-process A/B measures 1.97/1.97ms and 1.82/1.83ms with and without the smoothing material. Budget overruns came only from machine load: at a load average of ~90 the session worktree, which did not yet have the shader, also measured 3.26–3.30ms.
- **Props:** the feet probe passes for all 9 props, imports are lossless without mipmaps, and two runs of the generator produce byte-identical output.
- **Native evidence:** `hall_visual_capture` passes in EN and ZH (the real Wake exit, card, route, nine props, four fog-free areas, overview), and the images were inspected at 1024×768.
- **gdlint:** the CI scope total is 1301, against 1302 before this stage. The new planner and the edited tests add no issues.

### Limits / next stage

- **Wall/floor art:** unchanged; the 2D redraw is paused. The remaining "sticker" feel of the walls (mixed projection, the wall-top drawn under the player, AI lighting) is the target of the Blender HD prototype.
- **`tests/room_spatial_audit.gd`:** still reports the pre-existing 6 contact-band failures for knowledge exhibits, which now deliberately use the 72px approach zone. The expectation needs updating separately.
- **Old grid:** the 32px `CASTLE_LAYOUT` grid is still stale for click-to-move and legacy Guardian queries. The trail no longer uses it.
- **Worktree:** prop textures were not mirrored into the session worktree, whose scene predates the user's prop placement edits in main.
- **Proposed next stage:** a Blender 5.2.2 (bpy) one-screen HD Hall prototype from the existing collision layout, with an orthographic oblique camera, floor/wall-base/wall-top occluder layers, and a side-by-side comparison at 1024×768.
- **Exact GitHub documentation update proposed:** after reviewing the files above, synchronize `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, `docs/AGENT_STAGE_REPORT.md` (stage 38), `assets/props/hall_pixel/PROVENANCE.md`, `assets/props/hall_pixel/manifest.json` and `docs/evidence/2026-10-21-hall-visual/`. Publish the Web build only after the user confirms.

---

## Stage: UX-20261018-37

- **Date:** 2026-10-18
- **Status:** complete
- **Request:** During play, Esc should open a settings screen for adjusting the game at any time, such as mute, return to the main menu, and quit.
- **Delivery:** Actual main project and compatible session worktree. Existing room flows, Hub pause ownership, saves and authored Hall geometry are preserved. Local only; no commit, push or Web deployment.

### Player-facing changes

- **Esc settings dossier:** in free play, Esc (or controller Start) pauses the case and opens a centered brass/parchment dossier: Resume, Main Menu, Quit; Mute, Music and Effects faders; Field Prompts; and the controls list. Kicker and autosave lines show the current room and the real Continue room. EN/ZH copy is code-native.
- **Esc ownership:** an Esc that closes an open Bag, Map, Note, door puzzle, minigame, dossier, Chemistry question or Wake Room panel never also opens settings; the next Esc does. Scripted Hall moments (Guardian reveal/near miss, power scan, Chemistry CG, game over) veto settings. Main menu and cutscenes never show it.
- **Safe pause:** opening freezes the room, detective and Guardian; Hub/room shortcuts cannot act underneath. Esc resumes and backs out of confirmations first. Play resumes after the closing key's frame so polled room input cannot reuse it.
- **Leaving safely:** Main Menu and Quit require confirmation with Cancel focused. Both use the existing recovery semantics (never saving a dead player or active chase), state where Continue resumes, and save. Quit writes synchronously and is hidden on Web/iOS, where an app cannot close itself.
- **Persistent mute:** mute silences Master without moving faders and persists. Title-screen settings gained a matching Mute toggle so it can always be undone. Its Chinese field-prompt label is corrected to "引导提示"; the controls line now says Esc also opens settings.
- Language remains a title-screen setting: several room scripts do not yet rebuild every static label after a live language change.

### Exact files

- New `autoload/pause_menu.gd` and UID; `project.godot` (autoload registered last and `pause_menu` Esc action).
- `autoload/game_audio.gd` (`set_muted/toggle_muted/is_muted`, persistent `audio/muted`), `autoload/case_locale.gd` (pause/mute strings, field-prompt translation, controls line), `scripts/main_menu.gd` (Mute toggle and button row).
- Veto hooks: `scripts/wake_room.gd` and `scripts/game_world.gd` (`can_open_pause_menu()`).
- New `tests/pause_menu_test.gd` and UID (native `-- --capture [--zh]`, playable `-- --preview [--zh]`).
- `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- Evidence: `docs/evidence/2026-10-18-pause-menu/` (14 native PNGs, validation logs, `.gdignore`).

### Verification

- Godot 4.7 headless editor parsing passes in both roots; `git diff --check` passes in both.
- `pause_menu_test` passes **140 checks** headless EN and ZH and **155 checks** in native EN/ZH capture runs in actual main, and **141 checks** headless EN/ZH in the session worktree. It drives real Chemistry, Wake Room, Hall and title-screen scenes: Bag/book closing priority, Hall vetoes, Guardian/player freeze, swallowed Tab/U/M shortcuts, keyboard focus, mute persistence and fader preservation, Music/Effects/prompt toggles, confirmation focus/back-out, real return transition/save/HUD handoff and the quit save/handler.
- **Full actual-main sweep: 53/54 suites pass** with fresh guarded HOMEs and no script/parse errors, including audio, Hub, minigame UI, deduction, overflow, localization, guidance and Guardian suites. The single failure, `opening_blockers_test` "The guided route to Chemistry exists (0 points)", is pre-existing: it fails identically with PauseMenu removed before the suite and in the session worktree. It concerns Hall route generation, not this feature, and needs a separate fix.
- Session targeted suites pass: audio contract, room transitions, tutorial chain, panel overflow, UI design contract, staged guidance, guided crossing and Chemistry presentation.
- Visually inspected [Chinese settings](evidence/2026-10-18-pause-menu/01-pause-menu-zh.png), [English settings](evidence/2026-10-18-pause-menu/01-pause-menu.png), [return confirmation](evidence/2026-10-18-pause-menu/03-return-confirm-zh.png), [quit confirmation](evidence/2026-10-18-pause-menu/04-quit-confirm.png), [Hall pause](evidence/2026-10-18-pause-menu/05-hall-pause-zh.png), [title-screen Mute](evidence/2026-10-18-pause-menu/06-main-menu-settings-zh.png) and the [clean returned title](evidence/2026-10-18-pause-menu/07-returned-title.png) at 1024x768. Pixel sampling confirmed HUD rails beneath the veil are dimmed to the same level in Hall and Chemistry.
- A playable isolated Chinese preview of actual main is running (`PAUSE_MENU_PREVIEW_READY`) with HOME `.godot/pause-menu-preview/home`; the player's normal saves are untouched.

### Limits / next stage

- No on-screen touch button opens settings yet; touch players have no Esc. Physical gamepad Start/B and speaker listening were not hardware-tested.
- Headless suites still report shutdown-only ObjectDB/resource retention; this is not a leak audit.
- Proposed next stage: fix `opening_blockers_test` route generation, then add a touch-safe settings affordance.
- **Exact GitHub documentation update proposed:** after reviewing the implementation and test files above, synchronize `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, `docs/AGENT_STAGE_REPORT.md` (stage 37) and `docs/evidence/2026-10-18-pause-menu/`. Do not publish the Web build automatically.

---

## Stage: UX-20260907-36

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Improve unnatural ice/breakage and other effects, respecting real physical laws rather than adding decorative noise.
- **Delivery:** Actual main and compatible session updated. Existing eight stages, classifications, rewards, room callbacks, authored Hall geometry and unrelated dirty work remain intact. Local only; no commit, push or Web deployment.

### What changed

- **Ice:** a 257-state, asymmetric inward melt-front mask replaces whole-sprite scaling/fading. Surviving pixels remain grounded; the growing pool follows the model's lost ice mass using reference densities 917/1000. Initial normalized ice volume 1 becomes water volume 0.917.
- **Glass:** neutral transparent artwork no longer resembles blue ice. Seven complementary source-pixel regions move as one pane until the 0.60-second impact, then follow cached 240Hz gravity/contact integration. Convex-hull support prevents tray penetration; restitution 0.18, friction and sleep replace sine bounces and cloned upright triangles. Original regions remain visible through separation and settling.
- **Other materials:** wax slumps without rubber-like wobble; the original cloth texture tears progressively instead of swapping sprites; nails accelerate toward the magnet and stop on contact; salt/curds develop at irregular stationary sites. Liquid bottoms stay grounded, bubbles follow the falling liquid level, and emitted mist/smoke cannot begin with a fictitious pre-existing age.
- **Causality and audio:** all 16 samples state physical conditions. Slow changes are labelled time-compressed; boiling mist is identified as condensed droplets and the bronze core as fictional. Glass audio waits for impact, magnetic contact and spring release have matching cues, and quiet melt/dissolution/souring/crystallization no longer produce invented splashes or rattles. Pending cues cancel on replay, switching and close.
- **QA:** capture now explicitly draws before readback, avoiding indefinite `frame_post_draw` waits when macOS occludes a native window. The Chinese preview starts with an intact ice specimen, ready for Replay.

### Exact stage files

- New `scripts/sample_material_motion.gd` and UID; updated `scripts/sample_dish_view.gd`, `scripts/change_sorting_minigame.gd`.
- `assets/chemistry/sample_tray/materials.gdshader`, `specimens.svg`, regenerated `specimens.png`, `normalize_assets.gd`, `manifest.json`.
- New generated `assets/chemistry/sample_tray/physical_masks.png` and import metadata, `physical_geometry.json`, `physical_geometry.gd` and UID. The GDScript constant resource is preloaded for export; JSON is provenance, not a runtime dependency.
- New `tests/chemistry_material_motion_test.gd` and UID; updated `tests/chemistry_sample_renderer_test.gd`, `tests/chemistry_sample_renderer_capture.gd`, `tests/chemistry_presentation_test.gd`.
- `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, `assets/audio/README.md`, this report.
- Evidence in `docs/evidence/2026-09-07-material-naturalness/{before,after,validation}/` and `tests/captures/chemistry_material_motion/`, with ignore metadata. Stage35 evidence is preserved.

### Verification

- **Main 9/9 suites pass:** material motion, sample renderer, presentation, science contract, audio contract, Chemistry deduction, minigame UI polish, developer mode and room transitions.
- **Session 5/5 suites pass:** material motion, sample renderer, presentation, science and audio.
- Per root: **14,788 model checks** cover source partition, impact order, mass balance, contact energy loss, tray support, final rest and rendered 30/60/144 FPS invariance; **302 renderer checks** retain the 16 scientific presets and lifecycle contracts. No script/parse errors in final runs.
- Actual-main native EN/ZH room runs each pass **219 assertions** and produce **34 final 1024x768 images**. The UI audit still covers **96 stage/language states**. The full Chemistry deduction suite preserves the actual eight-stage completion/reward flow.
- **55 renderer PNGs** include all 16 before/changing/after comparisons and ten multi-time sequences; all 16 reset/replay pixel comparisons match exactly. Inspected [ice sequence](../tests/captures/chemistry_material_motion/motion-melting_ice.png), [glass sequence](../tests/captures/chemistry_material_motion/motion-breaking_glass.png), [cloth tear](evidence/2026-09-07-material-naturalness/after/11-cloth-tear-zh.png), [crystal growth](evidence/2026-09-07-material-naturalness/after/13-crystal-nucleation-zh.png), [fizz](evidence/2026-09-07-material-naturalness/after/15-gas-bubbles.png) and [boiling](evidence/2026-09-07-material-naturalness/after/16-boiling.png).
- M3 / GL Compatibility focused-UI p95 intervals were approximately **8.5-15.8 ms** in the five-sample capture probe. This includes a process-frame interval plus explicit drawing; it is not isolated GPU time, refresh rate, a directly comparable stage35 benchmark, or a Web performance guarantee.
- Godot headless editor parsing and `git diff --check` pass in both roots. Headless suites still report shutdown-only ObjectDB/resource retention, including existing audio resources; native captures exit cleanly. This is not a claim of a clean leak audit.

### Reproduce / boundaries / next stage

```bash
mkdir -p .godot/chemistry-vfx-check/home
HOME="$PWD/.godot/chemistry-vfx-check/home" \
  /Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script res://tests/chemistry_material_motion_test.gd
# Native room evidence: remove --headless, use chemistry_presentation_test.gd,
# and append: -- --capture --naturalness --zh
# Playable initial ice view: -- --preview --naturalness --zh
```

- This is a **constrained educational approximation, not perfect physical simulation**. Gravity uses presentation units; melt volume is inferred from a similar-section thickness model; heat transfer, reaction kinetics and fluid dynamics are not solved. Thin-shard tilt is a presentation projection, and fragments do not collide with each other. Conservation checks prove the stated model, not laboratory accuracy.
- Test saves are isolated. The actual-main preview uses `.godot/chemistry-vfx-motion-preview/home`; normal saves and existing editor/game processes are untouched.
- Protected main hashes remain: route `ec3cf1c03300b5689ec0893843767b849ea44010897896adf16cfb1b54f15890`; wall scene `7a1f47c280c793d9f95e21b8d46cc1c72ab1f1b2179bbb6e80d2cc3b4977d85a`.
- **Next:** human observation/readability and listening checks, then exported Web/mobile GPU validation. No physical gamepad or speaker/headphone listening claim is made.
- **Exact GitHub documentation update proposed:** review and synchronize `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, `docs/AGENT_STAGE_REPORT.md` (stage36), `assets/audio/README.md`, `assets/chemistry/sample_tray/manifest.json`, and the two stage36 evidence directories above with their reviewed source/assets/tests. Do not automatically publish the Web build.

---

## Stage: UX-20260907-35

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Make the Chemistry classroom's minigame visually compelling, with observable, believable material effects rather than tiny generic colour blocks.
- **Delivery:** Compatible changes are in the actual main project and session worktree. Main's newer investigation, shared-shell lifecycle, character, Hub, authored-route and collision work is preserved. No commit, push or Web deployment.

### Player-facing changes

- The room's existing launch now opens **Material Observation Lab / 变化观察实验台**. Only this minigame expands to a 940x704 panel: a large glass observation bench, sample selectors, replay, Chemical/Physical controls and explicit sealing replace the small simultaneous dish grid.
- Sixteen distinct raster-backed material presentations replace the generic crossfade. Paper progressively chars with grounded flames, smoke, embers and local warm reflection; ice shrinks into a pool without steam; glass fractures and settles; sugar disperses without gas; wax melts without a burning wick. Fizz/foam, boiling/steam, corrosion, egg coagulation, cloth tearing, magnetic attraction, curdling, salt crystallization, core reaction and spring recoil remain distinct. Slow processes explicitly say time-lapse.
- A 2.6-second observation can be replayed before classification. Selecting an answer does not erase the current animation. Sealing adds a 0.7-second result hold before judging; wrong submissions retain correct choices and restore the usable Seal label. Closing during observation or verification cancels owned effects/audio without granting completion.
- Six original non-looping material cues use the existing SFX bus. Replay replaces the prior sample voice, and pool metadata prevents cancellation from stopping a voice subsequently reused for unrelated UI feedback. The three music layers are never restarted.
- All eight authored stage sets, 16 classification booleans, substance sets, completion callbacks, evidence and rewards are retained. The cooked-egg explanation names protein change/coagulation rather than treating irreversibility alone as proof. Observation appearance never independently displays a classification badge.

### Exact stage files

- Both roots: `scripts/change_sorting_minigame.gd`, `scripts/sample_dish_view.gd`, `autoload/game_audio.gd`, `scenes/floor_1/chemistry_room.gd` (launch title only).
- Session only: compatible `clear_feedback()` addition in `scripts/minigame_shell.gd`; main's newer shell is not replaced.
- Both roots: `assets/chemistry/sample_tray/specimens.png`, `vessel_back.png`, `vessel_front.png`, their `.png.import` files, corresponding `.svg` masters and `.svg.import` files; `materials.gdshader` and UID, `normalize_assets.gd` and UID, `manifest.json`.
- Both roots: `assets/audio/sfx/sample_fire.wav`, `sample_bubbles.wav`, `sample_glass.wav`, `sample_water.wav`, `sample_grains.wav`, `sample_metal.wav` and their `.import` files; `tools/generate_audio_set.mjs`, `assets/audio/README.md`. Existing music/SFX were not regenerated.
- Both roots: new `tests/chemistry_presentation_test.gd`, `chemistry_sample_renderer_test.gd`, `chemistry_sample_renderer_capture.gd` and UIDs; updated `tests/minigame_science_contract_test.gd`. Main-only test updates: `tests/chemistry_deduction_test.gd`, `tests/minigame_ui_polish_test.gd`.
- Both roots: `tools/generate_minigame_answers.gd`, regenerated `docs/MINIGAME_ANSWERS.md`, `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- Evidence: `docs/evidence/2026-09-07-chemistry-effects/{before,after,validation}/` and `tests/captures/chemistry_sample_tray/`, including ignore metadata, images, logs and renderer result JSON.

### Verification and visual evidence

- Godot 4.7 headless editor parsing and `git diff --check` pass in both roots. No script/parse errors occurred in final runs.
- **Main 8/8 targeted suites pass:** `chemistry_presentation_test`, `chemistry_sample_renderer_test`, `minigame_science_contract_test`, `audio_contract_test`, `chemistry_deduction_test`, `minigame_ui_polish_test`, `developer_mode_test`, `room_transition_flow_test`.
- **Session 4/4 targeted suites pass:** presentation, renderer, science and audio. Renderer contracts pass **299 checks per root**. The main UI audit measures all **96 stage/language states** across six minigames; it was rerun with the new actual launch title.
- Actual-main native EN/ZH room-launched runs each pass **65 assertions**, producing **16 final 1024x768 screenshots**. Checks cover replay, sample switching, eight stage sample sets, no premature rewards, failed-seal retry, closing during effects, pause restoration and a retained closed node. The full Chemistry investigation test separately clears all eight stages and verifies room/save/reward progression.
- Validation caught and fixed a freed/null Submit-label update and stale retry text. Test assumptions were updated for the previously restored door question and for initial keyboard focus on Replay; this stage did not replace the Hall door flow.
- Renderer evidence includes **47 PNGs**, all 16 deterministic reset/replay pixel comparisons, and bounded hidden-view work. Actual focused-UI frame-wait p95 is approximately **11.8 ms** on Apple M3 / GL Compatibility; this is neither isolated GPU timing nor a Web performance claim.
- Audio inspection confirms stereo 44.1 kHz PCM16, 0.65-0.95-second cues and peak amplitudes 0.40-0.52 without clipping. The answer generator validates **94 entries** in each root.
- Visually inspected [paper burning](evidence/2026-09-07-chemistry-effects/after/04-paper-chars-flame-smoke-zh.png), [bubbles and foam](evidence/2026-09-07-chemistry-effects/after/06-gas-bubbles-and-foam-zh.png), [ice melting](evidence/2026-09-07-chemistry-effects/after/05-ice-pool-no-steam-zh.png), [glass fracture](evidence/2026-09-07-chemistry-effects/after/07-glass-fragments-zh.png), [crystallization](evidence/2026-09-07-chemistry-effects/after/08-time-lapse-crystals-zh.png), [English layout](evidence/2026-09-07-chemistry-effects/after/01-first-stage.png) and [six-sample final-stage layout](evidence/2026-09-07-chemistry-effects/after/02-final-stage-zh.png).
- **Baseline caveat:** `before/` records the old grid layout with already-staged raster specimens. It is not a pure before-image of the old colour-block renderer.
- Protected main hashes remain unchanged: Hall route `ec3cf1c03300b5689ec0893843767b849ea44010897896adf16cfb1b54f15890`; wall scene `7a1f47c280c793d9f95e21b8d46cc1c72ab1f1b2179bbb6e80d2cc3b4977d85a`.

### Reproduction / limits / next stage

```bash
mkdir -p .godot/chemistry-vfx-check/home
HOME="$PWD/.godot/chemistry-vfx-check/home" \
  /Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --editor --path . --quit
HOME="$PWD/.godot/chemistry-vfx-check/home" \
  /Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script res://tests/chemistry_presentation_test.gd
git diff --check
# For native evidence, remove --headless and append: -- --capture --zh
# For a playable isolated room launch, append instead: -- --preview --zh
```

- Final headless logs are under `validation/{main,session}/`; some CLI suites still report shutdown-only ObjectDB/resource retention (3-14 resources), including the existing music resources. Native presentation captures exit without errors. Do not call these shutdown diagnostics a clean leak audit.
- A detached actual-main Chinese preview was verified through its running process, native renderer startup and `CHEMISTRY_PREVIEW_READY`. It uses `.godot/chemistry-preview-final/home`; the normal player's saves and existing editor/game processes are untouched.
- These are stylized pixel-art material demonstrations, not a quantitative fluid/chemistry simulation. Headphone/speaker listening, unfamiliar-player reaction, physical gamepad and exported Web/mobile GPU performance were not newly tested.
- **Proposed next stage:** human playtest of observation readability and pacing, followed by listening and exported-build performance checks before publication.
- **Exact GitHub documentation update proposed:** synchronize `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, `docs/AGENT_STAGE_REPORT.md` (stage 35), generated `docs/MINIGAME_ANSWERS.md`, `assets/audio/README.md`, `assets/chemistry/sample_tray/manifest.json`, and the two evidence directories listed above, alongside their reviewed implementation/assets/tests. The maintainer reviews and publishes; no automatic publication is authorized.

---

## Stage: UX-20260907-34

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Specifically improve the top-left Hub layout and readability, not merely replace its artwork.
- **Scope:** Only Hub entry layout/presentation in actual main and session. Existing artwork, gameplay, door/CG, knowledge flow and internal Hub panels are preserved.

### Changes

- Fixed Bag/Key/Note/Map semantic slots. Unlocking Note no longer shifts the already-visible Map entry; gaps for unavailable intermediate tools are explicit.
- Permanent, outlined 14px function names replace the deliberately hidden labels. Key's state-refresh code no longer hides its caption. Shortcuts have a separate, non-overlapping region.
- Hit targets are 72x106 with consistent slot spacing and a slightly inset top margin. Artwork size and hover lift are unchanged.
- The preview is now a compact 332x112 paper region at `(12,132)`, below the caption row. Tool changes fade the preview without sliding it; pointer hover has a short dwell while keyboard focus remains immediate.

### Exact files

- `autoload/archive_ui.gd`, `scripts/hub_toolbar_entry.gd`, `scripts/key_hud.gd`.
- `tests/hub_toolbar_test.gd`: semantic-position, unlock stability, caption/key separation and preview-region assertions; native before/after capture selector.
- `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- `docs/evidence/2026-09-07-hub-layout/{before,after}/`: native main-project comparison images and ignore metadata.

### Verification

- New layout checks failed against the previous implementation, including Map movement on Note unlock and hidden names. The updated guarded Hub suite passes.
- Main native EN/ZH Hub checks passed **324 assertions** with 14 final captures; all four opening/closing paths, pause ownership, keyboard/controller-event focus and suppression remain covered. The comparison gallery contains 28 before/after PNGs.
- Session headless Hub suite passes **237 assertions**. Main existing `instrument_hubs_test` and `staged_hall_guidance_test` pass.
- Godot headless editor parsing and `git diff --check` passed in both roots.
- Inspected [Chinese layout](evidence/2026-09-07-hub-layout/after/06-hall-field-kit-zh.png), [fixed hover preview](evidence/2026-09-07-hub-layout/after/03-hall-bag-hover.png), and [previous layout](evidence/2026-09-07-hub-layout/before/06-hall-field-kit-zh.png) at 1024x768.

### Limits / handoff

- This stage adjusts the entry strip and its preview, not internal Bag/Key/Note/Map pages. Physical gamepad hardware and alternate resolutions were not newly tested.
- Tests used isolated HOME directories; normal player saves were not used. Some existing headless shutdown-resource diagnostics remain.
- A fresh actual-main Hub-layout preview was opened with an isolated test HOME and verified through its `GUIDANCE_PREVIEW_READY` output.
- No commit, push or Web deployment. Proposed GitHub update: review the three implementation files and test delta, then synchronize the four documentation files and this comparison gallery.

---

## Stage: UX-20260907-33

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Restore Chemistry's question, replace the false capture announcement with an almost-caught CG, draw original knowledge art, and redesign the footprint effects and Hub presentation.
- **Delivery:** Compatible increments are in the actual main project and session. Existing animation, room content, authored route and collision edits are preserved. No Web deployment is implied.

### Flow and presentation

1. **Question before entry.** The first-arrival branch no longer grants the Chemistry unlock directly. The existing key/knowledge gate supplies a dedicated four-choice panel. Wrong answers stay locked and remain retryable; a correct answer persists `door_chemistry_question_answered` and enables explicit entry. Correct-answer rewards are not duplicated. Normal completed visits remain unlocked.
2. **Near-miss CG, not failure text.** Entry shows a dedicated letterboxed scene with raster background/actor proxies: approach, lunge, the detective slipping inside, a closing door and Guardian recoil. The title is "ALMOST CAUGHT" / "差一点被抓住". Timed completion and skip both enter Chemistry without health loss; skip was also tested while the tree was paused. World collision/character scale is not animated by the CG.
3. **Original concept plates.** Five hand-authored, text-free pixel science illustrations replace the scene-prop crops. Each has a 96x128 editable pixel-grid SVG master, a 192x256 PNG delivery, palette/alpha constraints and provenance. They depict chemical/physical change, circuits, photosynthesis, independent time indicators and additive light.
4. **Actual small footprints.** New left/right 24x14 raster shoes replace polygon chevrons, large corner beams and expanding rings. Turn/stop pairs use the same small art; nearby straight/turn duplication is reduced. Only the next 480px are shown, passed marks retire, and a mild moving alpha shimmer replaces scale-bounce.
5. **Physical tool belt.** Tool silhouettes now sit on a narrow leather rail, without repeated cell cages or name bars. Hover lift and silhouette-edge feedback are distinct; names, purpose and truthful contents appear on paper preview slips. Existing Hub internals, unlocking, pause ownership and keyboard/controller navigation remain intact.

### Exact stage files

- `scripts/game_world.gd`, `autoload/case_locale.gd`.
- New `scripts/chemistry_door_question.gd`, `scripts/chemistry_near_miss_cg.gd`, `scripts/hall_footprint_marker.gd` and their UIDs.
- Artwork-only changes in `scripts/hall_knowledge_dossier.gd`.
- Toolbar changes in `autoload/archive_ui.gd`, `scripts/hub_toolbar_entry.gd`, `scripts/inventory_hud.gd`, `scripts/key_hud.gd`.
- New original assets/sources/manifests in `assets/ui/knowledge_plates/` and `assets/ui/guidance/footprints/`; the plate directory also contains its offline rasterizer and UID.
- New normalized belt assets/provenance in `assets/ui/tool_belt/`, plus `tools/derive_tool_belt_assets.gd` and UID. Original source item art is unchanged.
- New `tests/chemistry_entry_sequence_test.gd`, `tests/footprint_presentation_test.gd`, `tests/knowledge_plate_art_test.gd` and UIDs; updates to `tests/guardian_tutorial_chase_test.gd`, `tests/staged_hall_guidance_test.gd`, `tests/hub_toolbar_test.gd`.
- `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- Evidence directories: `2026-09-07-chemistry-entry/`, `2026-09-07-presentation/`, `2026-09-07-original-knowledge-art/`, `2026-09-07-tool-belt/` under `docs/evidence/`.

### Verification

- Actual-main reproduction initially failed **4 entry checks**: no question, premature unlock, premature near-miss, and false capture wording. These now pass.
- Godot 4.7 editor parsing and `git diff --check` passed in both roots.
- **13/13 targeted main suites** passed, including Chemistry entry, footprints, staged guidance, learning/review, Guardian tutorial/hunt, guided crossing, route authoring, capture recovery, room transitions, character motion, localization and panel bounds.
- **3/3 targeted session suites** passed across the different geometry: Chemistry entry, footprints and staged guidance.
- Guarded original-art and tool-belt tests were additionally rerun successfully in both roots with their required isolated HOME settings. Tool-belt delivery also passed its 217-check suites, native state captures and existing instrument-Hub regression.
- Actual-main EN/ZH entry runs capture the question, wrong answer, correct answer, approach, lunge and closed-door escape. These run the complete timed sequence, not only a direct finish callback. The headless case verifies safe skipped entry while paused.
- [Question](evidence/2026-09-07-chemistry-entry/01-chemistry-question-zh.png), [near-miss](evidence/2026-09-07-chemistry-entry/05-cg-near-miss-zh.png), [door closes](evidence/2026-09-07-chemistry-entry/06-door-closes-zh.png), [original knowledge plate](evidence/2026-09-07-presentation/03-file-knowledge-zh.png), [small footprints](evidence/2026-09-07-presentation/01-approach-knowledge-zh.png), [tool-belt hover](evidence/2026-09-07-tool-belt/after/03-hall-bag-hover.png).
- Read-only review found no significant issue in the new entry/CG/footprint wiring. Earlier CG layering defects found in visual inspection were corrected: the background renders above the matte, and the Guardian remains in front of the closing door.
- Main route and wall-scene hashes remain `ec3cf1c03300b5689ec0893843767b849ea44010897896adf16cfb1b54f15890` and `7a1f47c280c793d9f95e21b8d46cc1c72ab1f1b2179bbb6e80d2cc3b4977d85a`.

### Limits / maintainer handoff

- The CG is an in-engine animated composition of existing raster scene/character art, not a newly generated movie or newly painted character illustration. The five knowledge plates and footprint art are original new drawings.
- Fresh cases and standalone tutorial previews require the answer; legitimate already-unlocked normal returns do not repeat it.
- Hardware gamepad and non-native-resolution QA remain separate. Headless exits may emit the previously observed shutdown-resource diagnostics.
- The old preview was stopped and a fresh actual-main preview emitted `GUIDANCE_PREVIEW_READY` using an isolated test HOME. Website export/deployment remains separate; no commit, push, credential or remote operation was performed.
- Proposed GitHub update: review source/test deltas, then synchronize the four documentation files, asset manifests/provenance and these four evidence directories before a separately approved Web release.

---

## Stage: UX-20260907-32

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Knowledge should trigger before hugging a prop; leaving the tutorial must expose the player to real capture; interactions need actual knowledge screens; the Hub presentation needs a more refined, inviting design.
- **Scope:** Actual main project and compatible session changes. Previous work, authored route and wall geometry remain preserved. This supersedes the preceding stage's full-rehearsal protection and compact-tray presentation.

### Player-visible result

1. Hall knowledge uses a **72px approach margin**, with wall-visibility checks. Tests approach at a real clear point 36-64px from the exhibit. The tutorial stops queued motion and allows E/click there; doors keep 14px contact and prompt priority.
2. All five Hall subjects open a dedicated **illustrated knowledge dossier**: observation, scientific principle, two examples and an explicit filing action. Nothing is awarded merely by opening it. Collected exhibits reopen for review. New notebook records carry `content_key`; all five principles were verified in Chinese as well as English.
3. Protection is an **80px corridor around the continuous route**, not a global tutorial flag. After **1.1s outside**, the Guardian leaves scripted presentation, actually moves toward the player and can trigger capture/recovery. The player is not teleported back. Returning to the corridor restores guidance protection; compulsory reading and explicit route recording remain safe.
4. The Hub surface now has proportionate raster hero icons, nine-sliced instrument metal, parchment names and separate keycaps. Hover/focus reveals each tool's purpose and truthful live counts. The generic stretched button-frame tray is gone; internal Hub panels and input/pause ownership remain unchanged.

### Exact files changed this stage

- Guide/knowledge/pursuit: `scripts/game_world.gd`, `autoload/case_locale.gd`; new `scripts/hall_knowledge_dossier.gd` and its UID.
- Toolbar: `autoload/archive_ui.gd`, `autoload/note_hud.gd`, `scripts/hub_toolbar_entry.gd`.
- New derived surfaces: `assets/ui/hub_toolbar/instrument_metal.png`, `paper_inlay.png`, their `.import` files and `provenance.json`. These are normalized crops of existing project artwork, not newly generated illustrations.
- Tests: new `tests/hall_learning_experience_test.gd` and UID; updated `tests/staged_hall_guidance_test.gd`, `tests/guided_crossing_test.gd`, `tests/hall_route_authoring_test.gd`, `tests/hub_toolbar_test.gd`.
- Documentation: `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- Evidence: `docs/evidence/2026-09-07-learning-experience/` (16 native PNGs plus `.gdignore`) and `docs/evidence/2026-09-07-hub-refinement/` (21 before/after native PNGs and ignore metadata).

### Verification

- The initial actual-main reproduction failed **8 experience checks**, not just screenshots or a synthetic callback. Those failures are now resolved.
- Godot 4.7 headless editor parsing passed in main and session. The broader main selection exercised 13 targeted suites; a capture-recovery regression caused by an overbroad early return was corrected, and capture recovery reran successfully without weakening its test.
- Final focused run: **9/9 main invocations passed** (learning EN and ZH, staged guide, capture recovery, Guardian hunt/tutorial, guided crossing, route authoring, localization); **2/2 session tests passed** (learning and staged guide).
- Refined toolbar: **170 assertions per root**, native capture checks and the existing main instrument-Hub regression passed. The parent also reran the guarded toolbar test with matching isolated `HOME` / `HUB_TOOLBAR_TEST_HOME` in both roots.
- Native EN/ZH learning runs passed at **1024x768**: wide approach, injected wall rejection, substantive content before filing, real pointer filing, review, all five subjects, actual off-route Guardian displacement, fatal contact and visible recovery.
- Checked [the Chinese knowledge page](evidence/2026-09-07-learning-experience/02-chemistry-knowledge-dossier-zh.png), [comfortable approach](evidence/2026-09-07-learning-experience/01-comfortable-knowledge-stop-zh.png), [real pursuit](evidence/2026-09-07-learning-experience/08-real-off-route-pursuit-zh.png), and [the Hub's useful hover preview](evidence/2026-09-07-hub-refinement/after/03-hall-bag-hover.png).
- Read-only review found no additional significant issue in the new knowledge/protection wiring. `git diff --check` passed in both roots.
- Main authored route remains SHA-256 `ec3cf1c03300b5689ec0893843767b849ea44010897896adf16cfb1b54f15890`; wall scene remains `7a1f47c280c793d9f95e21b8d46cc1c72ab1f1b2179bbb6e80d2cc3b4977d85a`.

### Limits / next step

- Returning to the guide intentionally restores protection; it does not protect the player elsewhere. Explicit Shift+0 authoring is still harmless, while plain developer mode does not bypass the lesson.
- Physical controller hardware and non-native resolutions remain untested. Some test exits retain prior ObjectDB/resource shutdown diagnostics; no gameplay/script errors remain in the final checks.
- Local changes are applied in the actual main project. The old preview was stopped and a fresh learning/pursuit preview emitted `GUIDANCE_PREVIEW_READY` for that main path. It uses a separate test HOME and an initial Hall checkpoint. Website export/deployment is not part of this stage.
- Maintainer proposal: review the listed source/test changes, then synchronize the four documentation files, derived-surface provenance and the two evidence directories. No commit, push, remote change or credentials were used.

---

## Stage: UX-20260907-31

- **Date:** 2026-09-07
- **Status:** complete
- **Request:** Fix the still-visible wall-crossing/backward footsteps and missing knowledge stop in the user's running game; improve the top-left Hub artwork and layout.
- **Delivery correction:** The earlier route validation ran only in the session worktree. Both inspected Godot editors actually used `/Users/yaleshen/shadow-castle-stem-detective`, which also contained newer unsynchronized artwork, collision, animation and Hub changes. This stage applies compatible increments to that actual main project and verifies it directly. Prior dirty work is preserved.

### What the player now gets

- The route targets the visible knowledge sprite's feet, including the user's moved child transform: approximately `(627.46, 535.09)`, not the old parent origin `(419, 139)`.
- Completed route prefixes are omitted, including the recorded placeholder-to-spawn jump. Local connectors and marker positions are checked against real player collision; the route ends at a usable interaction edge rather than inside door art.
- A single queued automatic walk stops at approximately `(593.78, 547.22)`. E/click opens the knowledge, and explicit filing releases the onward route. Reading/closing without filing cannot release movement. The Guardian and its obstructing urgency chrome stand down during the required stop.
- The final queued leg is approximately 557px in this main layout and reaches an actually usable Chemistry-door prompt. The last navigation target uses the real 6px stopping tolerance rather than the 12px intermediate-waypoint shortcut.
- General developer mode (`0`) no longer automatically starts recording or bypasses the lesson. The named `record_hall_route` action uses **Shift+0** for explicit recording; it starts after spawn resolution and restores approach guidance if ended away from the knowledge.
- Bag/Key/Note/Map now share a compact 322x92 dark-brass/violet tray with consistent 72x64 raster-icon entries, bilingual labels, shortcut keycaps and hover/pressed/focus feedback. Locked tools, existing internal panels, shortcuts, cinematic suppression and pause ownership remain intact.

### Exact stage files

- Guide/input: `scripts/game_world.gd`, `scripts/player.gd`, `scripts/hall_route_recorder.gd` (usage comment), `autoload/dev_tools.gd`, `autoload/case_locale.gd`.
- Toolbar: `autoload/archive_ui.gd`, `autoload/note_hud.gd`, `scripts/inventory_hud.gd`, `scripts/key_hud.gd`, `scripts/map_hud.gd`; new `scripts/hub_toolbar_entry.gd` and its UID.
- Tests: new `tests/staged_hall_guidance_test.gd`, `tests/hub_toolbar_test.gd` and their UIDs; updated `tests/guardian_hunt_flow_test.gd`, `tests/hall_route_authoring_test.gd`. The fallback fixture now starts on real walkable floor, not an arbitrary point inside a wall.
- Documentation: `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report.
- Evidence: `docs/evidence/2026-09-07-main-guidance/` (nine PNGs, two runtime-provenance JSONs and `.gdignore`) and `docs/evidence/2026-09-07-hub-toolbar/` (eight PNGs and `.gdignore`).

### Preserved inputs and implementation

- The main project's authored route is unchanged: SHA-256 `ec3cf1c03300b5689ec0893843767b849ea44010897896adf16cfb1b54f15890`.
- Its edited wall scene is unchanged: SHA-256 `7a1f47c280c793d9f95e21b8d46cc1c72ab1f1b2179bbb6e80d2cc3b4977d85a`.
- Existing player post-collision stride logic and Guardian `present_scripted_step()` presentation were retained. Internal Chemistry-case and tactile Hub work was not replaced.
- No raster artwork was repainted. The toolbar crops/reuses existing raster icons and ornament. The UI pass verified protected-art/geometry hashes in both checkouts.

### Verification and evidence

- Both checkouts: Godot 4.7 headless editor parsing and `git diff --check` passed.
- Actual main: **12/12 targeted suites passed**: staged guidance, route authoring, guided crossing, Guardian hunt, Guardian tutorial, character motion, interaction stopping, room transitions, developer mode, toolbar, instrument Hubs and localization.
- Session worktree: **4/4 targeted suites passed**: staged guidance, route authoring, toolbar and developer mode. Its different older geometry remains supported.
- The toolbar suite was run with its required isolated HOME and matching `HUB_TOOLBAR_TEST_HOME`; its safety guard was not counted as a successful test. Toolbar assertions cover actual clicks, focus/controller events, suppression, localization and pause restoration.
- Actual-main native EN/ZH runs of `tests/staged_hall_guidance_test.gd -- --capture --main-evidence [--zh]` passed. The test checks continuous queued walking, physical route segments and marker locations, visible exhibit coordinates, an actual pointer click on the filing button, notebook state and the usable final door.
- [Required knowledge filing, Chinese](evidence/2026-09-07-main-guidance/03-file-knowledge-zh.png), [onward guide and full toolbar](evidence/2026-09-07-main-guidance/04-continue-to-chemistry-zh.png), [toolbar overview](evidence/2026-09-07-hub-toolbar/06-hall-field-kit-zh.png).
- [Runtime provenance](evidence/2026-09-07-main-guidance/runtime-zh.json) records the actual project path, source/route/wall hashes and 1024x768 viewport. This prevents mistaking a screenshot from another worktree for the user's build.
- A fresh native main-project preview was opened with an isolated test HOME and emitted `GUIDANCE_PREVIEW_READY` for the actual main path. It does not use the player's normal save directory.

### Limits and next step

- Stop any old debug run and rerun from the main project to load changed scripts; an already-running old instance is not evidence that disk changes failed.
- The website has not been re-exported or deployed. This is verified local delivery, not publication.
- Physical controller hardware and non-native resolutions remain untested. Some headless suites retain prior shutdown-only ObjectDB/resource diagnostics; native combined captures exited cleanly.
- Maintainer proposal: review the exact incremental source/test changes, then synchronize the documentation and evidence listed above. Export/deploy only as a separate approved action. No commit, push, remote or credential change was performed.

---

## Stage: DETECTIVE-20260905-30

- **Date:** 2026-09-05
- **Request:** Correct the candle multiplier metaphor, give all four Hubs tactile tool feedback, and implement a Chemistry investigation pilot rather than more quiz questions.
- **Outcome:** All three are implemented. Existing prior-stage dirty changes are preserved; local synchronization is incremental, not a reset or replacement of the user's checkout.

### Gameplay and presentation

1. **One candle, one wick, one flame.** `burn` remains the original oxygen-consumption multiplier. Thickness, flame width/height and light distinguish x1/x2/x3; it no longer means three separate wicks. Fuel exhaustion, smoke and sustained ventilation remain driven by the actual game. Eight-stage answers are unchanged, and the generated answer sheet uses the corrected terminology.
2. **Four distinct tools.** Bag artwork unfolds, the clicked item travels to the inspection plate, and a used bottle uncorks using slices of its existing raster. Keys insert into a test socket, turn, and move three lock followers. Dossier pages slide/turn with filing tabs and author-provided observed-detail accents; all text remains immediately readable. The Map writes known memory with an ink scan and allows selecting a visited location's already-filed clues. The ink shader only adds darkness; uncharted areas, hidden records and unvisited locations are not disclosed.
3. **Chemistry field case.** Inspect red liquid/powder/glass/vial → record observations → propose/revise blood, dye or reaction → read the physical protocol and complete the existing sample tray → compare controls/combinations → submit an interpretation → choose a report and the Butler statement it bears on → ask a follow-up. Hypotheses can be wrong without losing evidence or reputation. The UI does not preselect the useful evidence pair, pre-grade hypotheses, or expose the correct interpretation through a disabled submit button.
4. **Epistemic boundaries.** The comparison supports a chemical explanation of the colour, not a biological blood test, identity or intent. Reasoning is the detective's self-talk; Lin's writing remains physical evidence. Facts, revisable hypotheses and confirmed conclusions are separate journal sections. Revisions replace the existing record rather than adding duplicates.
5. **Persistence and progression.** Existing `fake_red_stain`, key/crafting and reputation IDs stay intact. New `chemistry_case_*` flags use the existing story-flag save mechanism. Old solved cases migrate without redoing the experiment or repeating rewards. The final board calls the raw evidence a comparison report; new cases must actually earn the interview, while old evidence-only saves keep their compatibility fallback.
6. **Input lifecycle.** Hub switching transfers pause ownership, and cancelled motion restores pivot as well as position/scale/rotation/modulation. Text fields do not lose typed shortcut letters to Hub switching. The case modal blocks hidden Hub opening, preserves keyboard focus on revised controls, and completed-case guidance sends the player onward rather than into another compulsory interview.

### Exact files changed in this stage

- `autoload/archive_ui.gd`.
- `scenes/floor_1/chemistry_room.gd`.
- `scripts/flame_air_minigame.gd`, `scripts/flame_jar_view.gd`, `scripts/inventory_hud.gd`, `scripts/key_hud.gd`, `scripts/clue_journal.gd`, `scripts/map_hud.gd`, `scripts/final_case_board.gd`.
- New `scripts/chemistry_case_state.gd`, `scripts/chemistry_case_ui.gd`, `scripts/hub_clue_list_item.gd`, `scripts/hub_key_teeth.gdshader`, `scripts/hub_map_ink.gdshader`, plus their `.uid` files.
- `tests/flame_presentation_test.gd`, `tests/tutorial_chain_test.gd`; new `tests/chemistry_deduction_test.gd`, `tests/instrument_hubs_test.gd` and their `.uid` files.
- `tools/generate_minigame_answers.gd`, `docs/MINIGAME_ANSWERS.md`, `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report, and the nine PNGs plus `.gdignore` under `docs/evidence/2026-09-05-detective-tools/`.

### Evidence (native 1024x768)

- [Single flame at each multiplier](evidence/2026-09-05-detective-tools/01-single-flame.png).
- [Bag specimen transfer](evidence/2026-09-05-detective-tools/02-bag-inspection.png), [key test socket](evidence/2026-09-05-detective-tools/03-key-test.png), [dossier turn](evidence/2026-09-05-detective-tools/04-dossier-turn.png), [known-location clues](evidence/2026-09-05-detective-tools/05-known-location.png).
- [An unsupported hypothesis stays revisable](evidence/2026-09-05-detective-tools/06-hypothesis-review.png), [evidence-linked questioning](evidence/2026-09-05-detective-tools/07-evidence-questioning.png), [Chinese case board](evidence/2026-09-05-detective-tools/08-case-zh.png), [persistent structured notebook](evidence/2026-09-05-detective-tools/09-case-notebook.png).

### Verification

- Headless editor parse and `git diff --check`: pass.
- **18 targeted suites pass**, covering the complete case, four tools, single-flame model, all minigame science/layout, Hub/UI design, localization, victim voice, room transitions, blackout/power restoration, save recovery, tutorial chain/opening, guided crossing, panel containment and update notice.
- The new Chemistry test uses actual focused Enter events for case controls, plays the existing eight-stage tray, tests unsupported/revised hypotheses, wrong evidence links, earned follow-up, fresh/partial/completed/legacy save round-trips, crafting/key access and Hall return. Native captures were refreshed after parent review.
- The obsolete tutorial-chain test formerly granted solved evidence directly on observation; it now verifies every step of the new objective sequence instead of bypassing the investigation.
- The generator verifies 94 checks and retains every answer. The 48-point authored Hall route remains byte-identical: SHA256 `8f6e11e3c88e8648616157901d9fcbb4b8f57d09bf4a6d2975ef148a5bea79bb`.
- Tests use isolated `HOME` directories. Unexpected engine/runtime errors are failures even if a test prints PASS. The corruption-recovery fixture intentionally emits a JSON parse diagnostic before proving backup recovery; existing audio shutdown-resource diagnostics are recorded separately, not treated as gameplay errors.
- Local delivery is complete: 41 stage-delta files were backed up where applicable, copied and byte-verified against the worktree. The user's 10 unrelated local changes and 48-point route were unchanged. The local checkout then passed editor parsing plus Chemistry, instrument Hubs, flame presentation, tutorial-chain, UI/finale and blackout tests (6/6).

### Limits / next stage

- This is one complete investigation pilot, not a rewrite of every room's narrative. The Butler comparison earns a relevant follow-up; it is not presented as proof of guilt.
- Effects retain existing raster artwork and use short code/shader motion; no new character/item illustrations were generated.
- EN/ZH and native desktop resolution were checked. Web export and other aspect ratios have not been revalidated in this stage.
- Suggested next step: unfamiliar-player Chemistry playtest, measuring whether players can explain why their hypothesis or evidence pairing is supported before extending the pattern to another room.
- No commit or remote publication is part of this stage.

---

## Stage: PLAY-20260905-29

- **Date:** 2026-09-05
- **Outcome:** A measured gameplay/UI polish pass, not a claim that every possible defect is eliminated. Reviewed the eight-room flow and a 15-screen menu/Hub/alchemy/finale gallery; fixed reproducible candle, shared-minigame and locomotion issues. Retained the authored route, puzzle answers, reward rules, artwork, collision sizes and save flow.

### Player-visible changes

- **Candle experiments:** 1/2/3 wicks now have distinct stems, candle widths and independent flames before and after ignition. Gas motes and an oxygen meter replace the water-like air surface. Ignition, depletion, smoke, sustained air and actual extinction order are explicit. A chosen jar can be removed from the prediction without clearing every other choice. Success copy also remains true when a flame never goes out.
- **All six shared-shell minigames:** failures persist until the next meaningful action; fresh attempts clear stale text; successes allow reading time plus an immediate **Next stage / Finish** button. Tab/Shift-Tab, Enter and Escape have visible focus/feedback. Animation unlock restores each button's prior disabled state instead of enabling impossible purchases. Closing, restarting or removing a hosting room cancels pending work and restores the pause state without awarding duplicate progress.
- **Timed harvest / plant bench:** keyboard harvest, visible bloom closure on timeout, unavailable refunds disabled, localized native target label.
- **Movement:** actual displacement drives cadence, blocked actors stand still, turns retain stride phase, and a reached Guardian waypoint no longer inserts a stationary tick. All eight Guardian direction rows are used. NPC gaze has a small direction deadband and acknowledgement scales around the feet. Interview NPCs remain stationary. Scripted Hall marks preserve the Guardian's stride pose instead of calling the idle reset every frame; safety positions are unchanged.

### Exact files

- Gameplay: `scripts/animated_npc.gd`, `scripts/player.gd`, `scripts/enemy.gd`, `scripts/game_world.gd`.
- Minigames: `scripts/flame_air_minigame.gd`, `scripts/flame_jar_view.gd`, `scripts/minigame_shell.gd`, `scripts/minigame_launcher.gd`, `scripts/change_sorting_minigame.gd`, `scripts/elapsed_time_minigame.gd`, `scripts/gear_train_minigame.gd`, `scripts/photosynthesis_minigame.gd`, `scripts/plant_bed_view.gd`, `scripts/moonlight_harvest_minigame.gd`, `scripts/moonleaf_pod.gd`.
- Tests: new `tests/flame_presentation_test.gd`, `tests/character_motion_test.gd`, `tests/minigame_ui_polish_test.gd`, `tests/character_motion_visual_capture.gd`, and their `.uid` files; updated `tests/minigame_science_contract_test.gd`.
- Documentation: `README.md`, `docs/AGENT_HANDOFF.md`, `docs/PROJECT_STATUS.md`, this report, and `docs/evidence/2026-09-05-gameplay-polish/` (`.gdignore` and seven PNGs below).

### Visual evidence

All captures are 1024x768. Evidence is kept out of game imports with `.gdignore`.

1. [Old identical cold candles](evidence/2026-09-05-gameplay-polish/01-candle-before.png).
2. [Distinct unlit wicks](evidence/2026-09-05-gameplay-polish/02-candle-wicks.png).
3. [Separate flames and oxygen supply](evidence/2026-09-05-gameplay-polish/03-candle-burning.png).
4. [Snuffed/sustained results and immediate Finish](evidence/2026-09-05-gameplay-polish/04-candle-outcome.png).
5. [Actual-motion animation with unchanged raster sheets](evidence/2026-09-05-gameplay-polish/05-locomotion.png).
6. [Readable sorting failure](evidence/2026-09-05-gameplay-polish/06-sorting-feedback.png).
7. [Harvest timeout visibly closes blooms](evidence/2026-09-05-gameplay-polish/07-harvest-timeout.png).

### Verification

- Godot 4.7 headless editor parsing and `git diff --check`: pass.
- **26 distinct targeted SceneTree suites passed**, including the three new contracts, all minigame science, layout, developer-mode, actor scale/presence, Guardian hunt/awareness/guided crossing, authored-route isolation, opening/tutorial chain, power restoration, room transitions, capture/save recovery, Library optics, Circuit benches, Hub/UI design and localization.
- UI contract measures **96 stage/language layouts** (six games, eight stages, EN/ZH), plus real keyboard input, timeout/retry, early close, auto/manual next stage and exactly-once final completion. Flame tests drive every stage's actual ignition and wrong-answer playback, not just a banner string.
- Tests run under separate isolated `HOME` directories. Both nonzero process exits and runtime/compile errors are treated as failures even if the script prints PASS. This exposed and corrected an existing eager-preload failure in the science suite.
- The 48-point authored route SHA256 remains `8f6e11e3c88e8648616157901d9fcbb4b8f57d09bf4a6d2975ef148a5bea79bb` before and after verification.
- Local synchronization completed with a backup and byte checks: 20 modified files and 16 new files copied to the user's Godot checkout. All 10 original local changes and the route were preserved. Headless parsing plus five focused tests (flame, character motion, minigame UI, guided crossing and room transitions) also passed in that checkout.
- No speculative dialogue-state resets were added: actual opening/power callers and existing flow tests already restore their own input state. The gallery's empty post-extraction frame was caused by an absent room backdrop after the bench closed, not a reproduced game freeze.

### Risks and next check

- Native 1024x768 and EN/ZH were checked; other aspect ratios, controllers and Web rendering need their own pass. This stage does not replace character art or rewrite the authored tutorial choreography.
- Some existing engine shutdown resource warnings remain in the test environment; no script errors were accepted as passing tests.
- Local Godot synchronization must preserve the user's modified `project.godot`, `scenes/wall_collisions.tscn`, eight untracked wall-art/provenance files and authored route. No commit or remote publication is part of this stage.
- Suggested next check: an unfamiliar-player run of the full opening and Chemistry transition, followed by a Web-specific input/render pass.

---

## Stage

- **Stage ID:** `ROUTE-20260904-28`
- **Stage name:** The tutorial route is walked by the author, not pathfound
- **Completed at:** `2026-09-04`
- **Status:** `complete`
- **User-visible outcome:** The Hall's floor markers pointed in directions that did not match the openings the player was looking at. The route was pathfound at runtime, and A* only guarantees a line is walkable — it cuts corners against walls, slips around collision the player cannot see, and runs diagonals across open floor. Turning on developer mode now records the walk; reaching the Chemistry door ends it and the tutorial follows that line from then on.

## What changed

- New `scripts/hall_route_store.gd`: reads and writes `data/hall_tutorial_route.json`. Stored as readable JSON with integer coordinates because the route is a design decision that has to be reviewable in a diff, not a binary asset. A malformed file is rejected whole — half a route strands the player mid-crossing and looks like broken pathfinding.
- New `scripts/hall_route_recorder.gd`: samples the walk every 48px (half the marker spacing, so corners survive), draws it live above the fog, and finishes on the door itself rather than wherever the walk stopped. There is deliberately no separate "start recording" key: the thing being authored is the walk, and a second switch is one more chance to finish the lap and find nothing was captured.
- `scripts/game_world.gd`: `_hall_route_points()` is now the single source for both the Guardian's line and the player's floor markers. They were already meant to be the same line but were read through two separate calls, so a change to one could leave the player following markers the leash counted as leaving the route.
- `scripts/game_world.gd`, `scripts/greenhouse_room.gd`, `scenes/floor_1/chemistry_room.gd`: these three each polled the `toggle_developer_mode` input action in `_process`, still bound to F3. After the hotkey moved to `0` they kept their own zoom and marker state while `GameState` had already flipped. They now follow `GameState.state_changed` rather than switching it themselves, which also avoids the double-toggle that would cancel the keypress out.

## Verification

- `tests/hall_route_authoring_test.gd` (new): a deliberately non-straight walk is captured as 23 points with its corners intact, finishes on the door, round-trips through the file, and — the assertion that matters most — the Hall actually reads its tutorial line from the authored route. Saving a file nothing consumes is the easiest failure here to miss. It also asserts the A* fallback still works with no file present, so a fresh checkout is not left without guidance.
- Full suite: **38/38 pass**, in this worktree and in the maintainer's checkout.

## Known risks

- The recorder writes to `res://`, which is read-only in an exported build. It is a developer tool gated behind developer mode, so it never runs for a player, but the authored JSON must be committed to ship.
- New `class_name` scripts do not resolve until the editor rebuilds its class cache. A checkout that pulls this change must reopen the project (or run `--headless --editor --quit`) before the route tooling loads.

## Correction to the previous report

The earlier claim that the maintainer's checkout timed out under editor contention was wrong. `timeout` does not exist on macOS, so those runs never started; the same mistake made a full-suite run report 38 failures that had not executed. Suite commands no longer use it.

## Proposed next stage

Walk and commit the real Hall route, then re-check the Guardian's trailing distance against the authored line rather than the pathfound one.

---

## Stage

- **Stage ID:** `DEV-20260902-27`
- **Stage name:** Developer mode, and a verified answer sheet for all 48 minigame stages
- **Completed at:** `2026-09-02`
- **Status:** `complete`
- **User-visible outcome:** Testing any room meant solving eight stages of a minigame by hand first, so reaching a late-game bug cost more time than diagnosing it. Pressing `0` now toggles developer mode from *every* room (it was wired to F3 inside the Circuit Room only, so it silently did nothing everywhere else — and on macOS F3 is Mission Control, so the game never received it at all), and while it is on each minigame panel grows a "开发：直接通关" button that settles the game as a full clear. The room receives exactly the pair of values a real clear sends, so rewards, story flags and the checkpoint all fire normally — only the manual solving is skipped. A generated answer sheet covers all six minigames.

## What changed

- New `autoload/dev_tools.gd` (`DevTools` autoload): owns the global `0` hotkey and a corner badge. It is a separate autoload rather than a branch inside `GameState` because minigames pause the whole tree — only `PROCESS_MODE_ALWAYS` still receives input, and giving `GameState` that mode would change the pause semantics of its own logic.
- `scripts/circuit_room.gd`: its local F3 handler is removed. It already subscribes to `state_changed`, so it keeps syncing its collision overlay.
- `scripts/minigame_shell.gd`: one dev button in the shared shell covers all six games, and any future one. `_on_dev_solve_pressed()` credits every stage before finishing, so `MinigameLauncher` reports `cleared_all=true` with the full stage count.
- New `tools/generate_minigame_answers.gd` → `docs/MINIGAME_ANSWERS.md`: 94 answers, each computed from the games' own constants and re-verified against their own judging functions. The generator refuses to write the file if any check fails.
- `docs/MINIGAME_ANSWERS.md`: all 6 games × 8 stages, with the rule each stage teaches.
- `scripts/game_world.gd`: the Hall-only "DEVELOPER MODE — F3" label is removed. The global badge replaces it, so the key name no longer lives in two places that can drift apart.
- `scripts/inventory_hud.gd` / `autoload/note_hud.gd`: the feature-unlock banner ("BAG HUB AWAKENED") was still printing English to a Chinese player. Both HUDs now translate at their single display sink rather than at each caller.

## Verification

- `tests/developer_mode_test.gd` (new): the hotkey survives the pause, and for each of the six games the room receives `cleared_all=true` with all 8 stages credited. It also asserts the button is hidden for normal players and appears when the mode is switched on mid-panel.
- Full suite: **37/37 pass**.
- The generator's own guard caught a false positive during development: `_picked` is `Array[int]`, so assigning an untyped `Array` was silently dropped and the empty gear train (ratio 1.0, "clockwise") happened to match level 4's target. Level 4 alone "passed" while nothing had been set. The search now builds a typed array and asserts the write landed.
- Visual: 5-jar stage with a wrong answer at 1024×768 — both footer buttons and every jar measured inside the panel.
- The hotkey test drives a real `InputEventKey` through the input chain rather than calling `toggle_developer_mode()` directly, so a wrong binding fails here. It also asserts the badge text names the key that is actually bound, and that typing the key into a focused `LineEdit` does not switch the mode.
- The first version of that test only exercised autoloads plus a bare minigame — no room was ever loaded, so a room script that swallowed the key would have passed. It now instantiates the Hall, Wake Room, Library and Greenhouse and presses the key inside each (4/4 toggle on and back off), which is the environment the player is actually in.

## Known risks

- `_sync_dev_button()` runs on every `GameState.state_changed`, which is emitted often. It only sets a label and a visibility flag, so the cost is negligible, but it is a per-signal callback rather than a one-time setup.
- Developer mode is session-only and defaults off; it is never written to a save. The clear button is hidden unless the mode is on.

## Investigated, not a code change

- The reported "wrong answer skews the whole layout" is **already fixed on `origin/main` (4251030)**. The local checkout at `/Users/yaleshen/shadow-castle-stem-detective` is stale at `831c522` and lacks `_banner.autowrap_mode` and the `PANEL_SIZE` height raise (560 → 648). Without wrapping the failure Label reports the entire sentence as its minimum width and drags the shared column — jars, title and footer — outside the fixed-width panel, which is exactly the screenshot. That checkout has 10 uncommitted files, so it was left untouched; it needs a pull by its owner.

## Proposed next stage

Re-check the Hall collision shapes the player reported earlier, now that developer mode makes late rooms reachable in seconds.

---

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
