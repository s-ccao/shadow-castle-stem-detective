# Animated Pixel v5 — imported character models

These are normalized, engine-ready PNG sheets assembled from the user's recent local downloads on 2026-08-12.

- `castle_guardian_walk_8dir.png`: 8 directions × 8 walk frames, `128×156` per frame. Source GIFs had mixed heights (`140`, `148`, and `156` pixels); each frame is bottom-aligned to one shared ground baseline before packing.
- `butler_idle_8dir.png`: 8 directions × 8 breathing frames, `48×68` per frame. It replaces the older Chemistry Butler sheet and is also used by the Castle Hall Butler.

Both sheets preserve transparent backgrounds, use nearest-neighbor filtering in runtime, and retain the source cadence of 200 ms per frame (5 FPS).
