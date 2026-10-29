# Design — shadowcastledetective.com

The locked design system for every page in `web/landing`. New pages share it;
they may differ only where "Per-page allowances" says so. Tokens live in
[`tokens.css`](tokens.css); never write a raw colour, font or easing in a
stylesheet — add a named token first.

## Genre and voice

- **Genre:** atmospheric. A gothic case archive at night: violet paper, brass
  instruments, parchment ink, moonlight.
- **Voice:** a detective's case notes. Short declaratives, concrete verbs, no
  hype. Never invent numbers, quotes or player counts; every figure on the site
  must be true today (8 playable areas, 5 animated NPCs, 22 documented
  versions are sourced from `README.md` and `docs/DEVELOPMENT_HISTORY.md`).
- **Honesty rules** (enforced by `tools/check_site.py`): only a game whose
  status is `playable` may offer a play link; unfinished games say "Coming
  soon" in words, not colour alone; generated key art is labelled as concept
  art; planned features are introduced as planned.

## Palette roles

| Role | Token | Use |
| --- | --- | --- |
| Paper | `--color-paper` … `--color-paper-3` | Page and surface layers |
| Ink | `--color-ink`, `--color-ink-2`, `--color-ink-3` | Headings, body, quiet meta |
| Brass accent | `--color-accent`, `--color-focus` | One primary action per view, focus rings |
| Moonlight | `--color-moon`, `--color-moon-2`, `--color-moon-glow` | Key light, coming-soon status, glass edges |
| Bronze / ember | `--color-bronze`, `--color-ember`, `--color-ember-hot` | Button gradients, the lantern, evidence markers |
| Night sky | `--color-night`, `--color-sky-*`, `--color-hill`, `--color-keep*`, `--color-near` | The page sky (on `html`) and hero scene layers |
| Spectrum | `--color-spectrum-1` … `-7` | Prism Lab's castle and the lantern's prism sketch only, never UI |
| Case accents | `--game-<slug>` | One per catalogue entry; tints its card, window, stage and page hero |

The moon lights the scene from the upper left. Every illustration, glow and
gradient keeps that direction.

## Typography

- **Display:** Fraunces 600/800, roman only (no italic headings), tight
  tracking (`-0.035em`); Chinese falls back to Songti SC / Noto Serif SC with
  `0.02em` tracking.
- **Body:** IBM Plex Sans 400/600; Chinese falls back to PingFang SC / Noto Sans SC.
- **Labels, stamps, HUD numbers:** IBM Plex Mono 500, uppercase with wide
  tracking in English only.
- Hero headlines stay under 50 characters; longer copy steps down a size.

## Space and shape

- 4 pt scale through `--space-*`; page gutter `--page-gutter`; content width
  `--content-max`.
- Corners: `--radius-sm` for buttons and stamps (archive tabs, not pills);
  `--radius-lg`/`--radius-xl` for cards and the library panel; pills only for
  segmented switches.
- Glass (`--color-glass`) is reserved for the navigation, the library and
  floating controls over imagery.

## Motion

- Animate `transform` and `opacity` only; filters only for one-off reveals.
- Easings: `--ease-out` for entrances, `--ease-in-out` for movement within the
  frame, `--ease-in` for exits. No bounce or overshoot on UI state.
- Durations: `--dur-micro` 120 ms (press), `--dur-short` 220 ms (hover),
  `--dur-long` 420 ms (panels), `--dur-scene` 600 ms (library), `--dur-reveal`
  900 ms (images developing).
- Every animated system reads `html[data-motion]`. "reduce" comes from the
  system setting or the site's Animations switch (footer, library); it stops
  ambient loops, parallax, the custom cursor, the pointer's light, the keyhole,
  cipher headings, lightning and previews, holds the potion and the castles still, and
  shrinks transitions to 150 ms fades.
- Ambient loops pause when off screen or when the tab is hidden. One shared
  requestAnimationFrame (`js/loop.js`) drives every continuous effect.
- Nothing auto-advances. Selection follows hover and focus.
- Canvas vignettes (`js/vignettes/`) are pure functions of loop progress: with
  motion off they draw one telling frame instead of looping. The demo board's
  bump and shake are the only bouncy motions, and both stop under "reduce".
- An element that script moves every frame and CSS also scales or rotates is
  positioned with the `translate` property, never `transform`: the individual
  `scale` and `rotate` properties apply after `translate` but before
  `transform`, so they would scale the position too (the magnifier once jumped
  towards the page corner on every press).
- The case-file library is a modal `<dialog>`, drawn in the browser's top layer
  above every z-index. Anything that must show above it, like the magnifier
  and the pointer's light, has to live inside the open dialog; `js/overlay.js`
  moves those overlays in and out automatically.
- Camera flashes are local (a glow at the click, never the whole screen) and
  limited to three a second.

## Night sky and pointer light

Every page sits in the same night (`css/night.css`, `js/night/`). Behind the
content, in order:

1. **Sky** (CSS on `html`): moon haze from the upper left, an arcane glow low on
   the right, fine grain, deepening to night. `body`, the footer and case heroes
   stay transparent so it shows through.
2. **Fog** (`night/sky.js`): drifting banks and two breathing moon shafts,
   sliding with the page at their own depths.
3. **Castles** (`night/castles.js`): one castle per case stands on the hills at
   the foot of every page, each with its own outline (Shadow Castle's keep and
   rose window, Evidence Rush's court hall and clock, Prism Lab's crystal
   spires, Echo Corridor's arcade, Time Echo's hourglass tower, Alchemy Shift's
   onion dome and still, Rune Defense's bastion). Windows burn in the case's
   accent: the playable case is lit, the others glow faintly until they come
   into focus. The skyline turns to the case being read (its page, or the card
   under the pointer on the hub) and pans with the scroll elsewhere.
4. **Rune circuitry** (`night/runes.js`): faint brass traces and rune pads
   etched into the walls; lightning energizes them.
5. **Evidence** (`night/lantern.js`, fine pointers): the wall hides UV prints,
   footprints, chalk formulas, sketches, seals and red thread. The pointer's
   lantern develops them; they fade back within two seconds. Holding still
   widens the pool. A click develops a wide circle, and on bare wall drops a
   numbered evidence marker.
6. **The potion** (`night/potion.js`): a bottle (flask, Erlenmeyer, vial,
   round-bottom in turn, each with its stopper) stands in the largest open space
   at the start of each chapter, holding one case's potion and colour. As the
   reading line (62% down the screen) passes, the potion pours over the lip and
   runs down the page behind the content, routed through the gaps (text costs
   most, pictures little, the outer edges more), shading into the next potion's
   colour and pouring into the next bottle, which fills; once full, the stream
   that filled it dries up into the night. The stream is bright only where it
   pours, at its front, under the pointer and in lightning; elsewhere it sinks
   to a faint trace and thins into rising mist, and behind text it dims so the
   text stays readable. Touching a bottle lifts its stopper and lets out vapour;
   each potion answers the pointer in its own way, over its bottle and along its
   stream: the lantern potion sheds sparks, luminol drips and stains, the prism
   potion splits into its spectrum, the echo draught rings, the time potion
   turns a clock back and holds its sand, transmutation bubbles and runs
   through every colour, and the ward oil raises runes.

   A click plays the potion's own sequence over the page, about three seconds
   long (`night/potion-scenes.js`, loaded the first time the pointer nears a
   bottle; at most three play at once). Sequences aim into open space and
   towards the middle of the screen, so a bottle near the top still shows its
   whole effect.
   - **Lantern** (Shadow Castle): the potion catches fire at the mouth, a flame
     blue at the root and white at the heart. A lantern beam sweeps the dark in
     shafts of light, lighting the dust it crosses and pooling where it lands,
     and the wall's hidden evidence develops under it. The flame gutters out in
     smoke.
   - **Luminol** (Evidence Rush): the potion erupts in a crown of droplets that
     spatter the wall; a sweep of ultraviolet turns the spatter luminol blue and
     develops a hidden fingerprint behind it.
   - **Refraction** (Prism Lab): a crystal forms above the bottle, or beside it
     near the top of the screen. A white beam enters it and leaves as the
     spectrum, each colour bouncing off unseen mirrors, until the crystal
     shatters into glints.
   - **Echolocation** (Echo Corridor): a ping, then sound waves roll out;
     whatever a wavefront touches on the page shows its outline for a moment
     and pings back.
   - **Rewind** (Time Echo): a clock face forms; its hands race backwards, time
     ripples fold inwards, the bottle's past selves trail behind it and sand
     streams back up into it. Then everything stops and lets go.
   - **Transmutation** (Alchemy Shift): a circle of transmutation draws itself
     around the bottle; the potion runs through every case's colour, orbs of
     every colour spiral in and the circle's nodes burst into sparks.
   - **Ward** (Rune Defense): two rings of runes wheel around the bottle and
     raise a dome of hexagonal light, brightest at its rim. Red bolts crackle in
     from the dark and break on it in ripples and sparks; then the runes close
     in and seal the ward into the bottle in a flash.

**Lightning** answers the scroll up to eleven times a second, some strikes
forking to a second target, and the storm also strikes on its own every second
or two (not while the tab is hidden or the case files are open): from the
clouds onto a bottle (which lights up), the head of the flowing potion, a
castle's spire (whose windows flare) or a rune, with a rune flaring where it
lands. Strikes show the potion's whole course for a moment, at most about three
times a second. Those strikes fall behind
the content, so text they cross stays readable; while a hero fills most of the
screen they strike it from in front instead: one of the hub castle's windows or
its flag, or the sky of the case painting. Moving the pointer throws lightning
at the nearest bottle, lighting it, or at a rune pad; a click bursts into a ring
of runes and a surge through the circuitry, and a click on a bottle draws the
lightning into it. Every bolt is a thin line with a small glow, far below the
area that makes a flash hazardous, and none strikes under reduced motion. The
walls stay dark until lightning reaches them: no field of dots that reads as
stars.

In front of the content, one screened canvas (`night/light.js`) under the
magnifier carries the pointer's light: the lantern's glow and flashes, the
pointer's lightning, the click's ring and the potions' click sequences.
Painters register with it and it stops drawing when none has light left. Full-bleed heroes cover the layers
behind them, so those skip drawing while a hero fills the screen.

The story layer (`js/story.js`, `js/loupe.js`): the first page of a visit opens
through a keyhole (`?intro=1` replays it); headings resolve out of alchemical
and runic cipher as they arrive, keeping their accessible name meanwhile; Roman
case numerals drift behind each chapter; over a capture or the case painting
the magnifier really magnifies (pixel captures at whole multiples of their
pixels), scans while held still, then locks the evidence.

Budgets: canvases at most 1.5× device pixels (1× on phones and low-core
machines, and for the evidence wall); the castles redraw at 30 fps while idle;
the circuitry and lightning draw only while something is lit; potion particles
capped at 320 (150 on low-power devices), stream colours quantized so glow
sprites stay few; the potion's routes are re-planned in idle time; at most two
new evidence cells painted per frame with the rest prepared in idle time.

## Components

- **Navigation (N10):** transparent over the hero, a glass bar after 24 px of
  scroll, hidden while scrolling down, back on scroll up or focus.
- **Footer (Ft5):** one statement line, links, language and motion switches.
- **Buttons:** `.btn--primary` (brass, one per view), `.btn--ghost` (glass).
  All eight states are styled: default, hover, focus-visible, active,
  disabled, loading, error, success.
- **Stamps:** `.stamp[data-status]` — Playable, In development, Coming soon.
- **Case cards and the case-file library:** see `css/cards.css` and
  `css/library.css`. The library is a modal dialog: focus moves in, Esc closes,
  focus returns to its opener.
- **Mechanic vignettes:** a 160 × 100 unit canvas scene per upcoming game, in
  the case's accent over night, with moonlight and brass as supporting light.
  Shown in a card's art on hover (or Preview on touch), across the library
  stage, and in a round lens inside the case page's seal rings.
- **Screenshots:** evidence-photograph frames (`.feature-capture`, the
  featured frame's brass corners) that develop like prints; captures follow the
  page language.
- **Demo board (`css/demo.css`):** an evidence board panel with a HUD of
  mono-type chips, statement and evidence cards as real buttons, moonlit
  threads for links that hold and the case accent for the contradiction. It
  says "Demo" in a stamp and never presents itself as a game build.
- **Archive filter:** pill toggle buttons with `aria-pressed` and counts.
- **Concept-art label (`.art-tag`):** a small glass pill in mono capitals in the
  corner of any generated art ("Concept art" / 概念图). It steps aside while a
  card plays its mechanic preview and never appears on screenshots or paintings.

## Languages

English is written in the HTML. Chinese strings live in `src/i18n/zh.json`
(interface) and `data/games.json` (catalogue); `tools/site_build.py` merges
them into `i18n/zh.json`. Mark translatable elements with `data-i18n`,
`data-i18n-html` or `data-i18n-attr`; never put `data-i18n` on an element that
contains other elements.

## Per-page allowances

- The hub hero may use the layered castle scene; case pages use their own art
  or emblem with the shared fog and rain.
- Case pages may change their accent (`--game-<slug>`), never the palette,
  type or components.
