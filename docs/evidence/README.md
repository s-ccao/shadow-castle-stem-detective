# Evidence

Screenshots under this folder are not hand-taken. Every one of them is the
output of a harness in `tests/`, which names its own directory and creates it
if it is missing:

```gdscript
const EVIDENCE_DIRECTORY := "res://docs/evidence/2026-08-14-guardian-hunt"
DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(...))
```

So the harness is the check, and the images are its receipt. Deleting a receipt
removes no coverage; re-running the harness prints it again.

```bash
$GODOT --script tests/guardian_hunt_visual_capture.gd
# The UI gallery names its own run:
$GODOT --script tests/ui_visual_gallery.gd -- --output=some-stage
```

The one thing that cannot be re-run is a `before/` capture: it photographed
code that no longer exists. Those, and the analysis files that are not images
(`alpha-metrics*.csv`, `STANDARD_FLOW_PRESSURE_AUDIT.md`), are the only
irreplaceable contents here.

## None of this ships

`docs/evidence/.gdignore` makes Godot skip the whole folder. It imports nothing
here — there is not a single `.import` file under `docs/`, against 256 under
`assets/` — so none of it is packed into an export and the game never reads it.
Do not remove that file, or the next batch of captures becomes game resources.

## What is kept

- `before/`, `after/`, `furniture-corrected/` — the pairs a change is argued
  from.
- The newest capture of each topic.
- Everything that is not an image.

## What is removed

- `*-regression/` — a harness re-run during unrelated work whose result was
  "nothing moved". A receipt for a non-event.
- Stage snapshots that a later one replaced. The naming says which: `X` is
  superseded by `Xb`, `X-b`, `X-v2`, `Xc`, and `X-review`/`X-redesign` by
  `X-release`.

Deleting only shrinks the working tree. Git history keeps the blobs, so a
clone is the same size either way; that would need a history rewrite, which is
not worth breaking every existing clone for.
