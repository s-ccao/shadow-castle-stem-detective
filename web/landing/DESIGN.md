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
| Bronze / ember | `--color-bronze`, `--color-ember`, `--color-ember-hot` | Button gradients, sparks, lantern |
| Night sky | `--color-night`, `--color-sky-*`, `--color-hill`, `--color-keep*`, `--color-near` | Hero scene layers only |
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
  ambient loops, parallax, the custom cursor, sparks and previews, and shrinks
  transitions to 150 ms fades.
- Ambient loops pause when off screen or when the tab is hidden. One shared
  requestAnimationFrame (`js/loop.js`) drives every continuous effect.
- Nothing auto-advances. Selection follows hover and focus.
- Canvas vignettes (`js/vignettes/`) are pure functions of loop progress: with
  motion off they draw one telling frame instead of looping. The demo board's
  bump and shake are the only bouncy motions, and both stop under "reduce".

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
