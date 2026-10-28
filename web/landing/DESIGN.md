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
| Spectrum | `--color-spectrum-1` … `-7` | The prism trail and the prism motif only, never UI |
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
  cipher headings and previews, holds the moon dust in its current shape, and
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
3. **Moon dust** (`night/dust.js`, WebGL): as a chapter reaches the middle of
   the screen, the dust gathers into its subject (`night/shapes.js`): the moon,
   the castle, a magnifier, the evidence web, a flask, gears, the seven case
   doors in their accents, and one motif per upcoming game. It forms in the
   largest open space between the content, never on top of reading; with no
   room it sits dimly behind. The pointer parts it like a lens, a click sends a
   shockwave, fast scrolling draws it into rain. Software WebGL gets no dust.
4. **Evidence** (`night/lantern.js`, fine pointers): the wall hides UV prints,
   footprints, chalk formulas, sketches, seals and red thread. The pointer's
   lantern develops them; they fade back within two seconds. Holding still
   widens the pool. A click develops a wide circle, and on bare wall drops a
   numbered evidence marker.

In front of the content, one screened canvas (`night/light.js`) under the
magnifier carries the pointer's light: the lantern's glow, the prism trail
(white light that disperses into the spectrum, wider the faster the hand) and
the click's flash and ring. Painters register with it and it stops drawing when
none has light left. Full-bleed heroes cover the layers behind them, so those
skip drawing while a hero fills the screen.

The story layer (`js/story.js`, `js/loupe.js`): the first page of a visit opens
through a keyhole (`?intro=1` replays it); headings resolve out of alchemical
and runic cipher as they arrive, keeping their accessible name meanwhile; Roman
case numerals drift behind each chapter; over a capture or the case painting
the magnifier really magnifies (pixel captures at whole multiples of their
pixels), scans while held still, then locks the evidence.

Budgets: about 14,000 motes (6,000 on phones and low-core machines), canvases
at most 1.5× device pixels (the evidence wall at 1×), at most two new evidence
cells painted per frame with the rest prepared in idle time.

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
