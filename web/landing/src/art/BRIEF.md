# Art direction brief — case-file key art

Concept key art for the six upcoming games on shadowcastledetective.com. Each
image is labelled **Concept art** on the site (enforced by `tools/check_site.py`)
until the game exists and real screenshots replace it. Shadow Castle keeps its
painted hero (`assets/hero-castle.jpg`) and in-game captures.

## Game frame

- Player fantasy: a detective-scientist working cases in and around Ashford Castle at night.
- Core verbs (per case): link evidence · bend light · see with sound · replay your past self · brew to order · hold the gate with runes.
- Where the art appears: case cards (16:10, ~290 px wide), the library stage (fills ~900 × 670 px behind text), case-page heroes (up to ~1200 px wide), Open Graph previews (1200 × 630).
- Display: dark UI; text sits over the lower-left third of every image.

## Visual system

- Shape language: tall gothic verticals, pointed arches, round seals; one clear focal object per image.
- Silhouette priorities: the focal mechanism reads in the top-right two thirds; the lower-left third stays calm and dark for copy.
- Value structure: mostly very dark (night interiors and exteriors); one bright focal light; no large mid-grey areas.
- Palette roles: night `#030309`–`#191231` violets; moonlight `#b9def4` as cool key light; brass `#e8a127` and ember `#fda856` as warm practical light; **one case accent** as the dominant glow (see prompts).
- Materials: weathered stone, brass, old glass, parchment, iron.
- Edge treatment: crisp silhouettes against glow; soft atmospheric haze between depths.
- Lighting: moonlight from the **upper left**, every image; the case accent lights the focal object.
- Detail density: high in the focal area, low at the edges and in the copy zone.
- Style: high-detail pixel-art illustration in the manner of the game's own hero painting (attach `web/landing/assets/hero-castle.jpg` as the style reference), painterly lighting, readable at card size.
- Explicit exclusions: text, letters, numbers, logos, UI, frames, borders, watermarks, signatures, modern objects, photorealism, close-up faces.

## Technical contract

- Master: 16:9, at least 2048 × 1152, PNG or high-quality JPEG, sRGB, no transparency.
- Safe areas: keep the focal subject inside the centre-right 60 % so 4:5 and 1:1 crops still work.
- Deliverables made from the master (by `tools`/scripts in phase 3): 16:9 stage/hero, 16:10 card, 1200 × 630 Open Graph; WebP plus JPEG fallback, versioned file names under `assets/games/<slug>/`.

## Visual target and workflow

1. Generate 2–4 candidates per game with the prompt in `prompts.md`, the style reference attached.
2. Save them to `~/Desktop/shadow-castle-key-art/<slug>/` (outside the repository).
3. Phase 3 picks one per game from a contact sheet, normalises crops and records provenance in `manifest.json` and `PROVENANCE.md`.
4. Approval owner: the user. Nothing ships without approval at card and stage size.
