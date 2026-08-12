# Character Art Pipeline

## Goal

Replace placeholder NPC blocks with full-body animated characters that match the existing top-down pixel player and castle backgrounds. Each NPC needed to be readable at gameplay scale, have a distinct silhouette, and support motion in all four directions.

## Iteration record

### Pass 1 — Detailed concept portraits (rejected)

The first generated character concepts were too realistic for the game. They also made Dr. Lin read older than intended. They were deliberately **not** kept in the project or used in gameplay.

**Reason for rejection:** visual mismatch. The player, rooms, and UI use small chibi-like pixel-art forms, so realistic rendering would make the character look pasted into a different game.

### Pass 2 — Pixel dialogue portraits and full-body references

The second pass established the approved direction: youthful Dr. Lin, strong silhouette colors, dark magical-academia clothing, and a compact pixel-art treatment. Portraits were wired to the dialogue UI, while full-body reference art helped lock in each character's costume before animation.

**Files:**

- `assets/characters/portraits_pixel_v2/`
- `assets/characters/full_body_pixel_v2/`

### Pass 3 — Final directional animation sheets

The final pass created the gameplay sheets used by the game. Every sheet is 1024 × 1024 pixels, divided into a 4 × 4 grid of 256 × 256 cells:

| Rows | Columns | Animation use |
| --- | --- | --- |
| Down, left, right, up | Four pose frames per direction | Walk cycle at 6 FPS; slow looping idle at 1.6 FPS |

**Final files:**

- `assets/characters/animated_pixel_v3/dr_lin_walk.png`
- `assets/characters/animated_pixel_v3/butler_walk.png`
- `assets/characters/animated_pixel_v3/gardener_walk.png`
- `assets/characters/animated_pixel_v3/mechanic_walk.png`
- `assets/characters/animated_pixel_v3/castle_guardian_walk.png`

## Integration decisions

1. **Reusable animation component.** [`scripts/animated_npc.gd`](../scripts/animated_npc.gd) slices any approved 4 × 4 sheet into named Godot animations, uses nearest-neighbor filtering to preserve pixel edges, and provides gentle patrol motion for living NPCs.
2. **Narrative fit.** Dr. Lin is not placed as a normal present-day room NPC. Her sheet appears as a blue memory echo during the Chemistry Room's vision event, preserving the story while still making the character visible and animated in-game.
3. **Collision and interaction remain independent.** NPC art is a visual child of the gameplay interaction/collision point. This lets the feet align with the ground while keeping player interaction zones stable.
4. **Guardian uses the same specification.** The Castle Guardian's `AnimatedSprite2D` uses the final sheet while its existing A* chase script selects animation direction from velocity.

## AI-art transparency

The image source material was generated through prompt-based image generation with visual references to the existing player sprite. It was then art-directed through the three passes above, chroma-keyed to transparent backgrounds, standardized into 1024 × 1024 sheets, checked for alpha support, and integrated into Godot scenes/scripts. The final artistic decision, technical integration, and playability checks were made in the project rather than treating the generated image as a finished asset.
