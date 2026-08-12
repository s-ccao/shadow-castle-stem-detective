# Domain Docs

This is a single-context Godot game repository. Engineering skills should use the following documentation when exploring or changing the game.

## Before exploring

- Read root `CONTEXT.md` when it exists.
- Read any relevant decision records in `docs/adr/` when they exist.
- Read the project README and the relevant room, gameplay, or autoload scripts before changing behavior.

If a domain document does not yet exist, proceed without treating its absence as an error. Create domain documentation only when terminology or a technical decision needs to be made explicit.

## Layout

```text
/
├── CONTEXT.md                 # Shared game terminology and invariants, when needed
├── docs/
│   └── adr/                   # Architectural decisions, when needed
├── scenes/                    # Godot scenes and room layouts
├── scripts/                   # Gameplay and UI logic
├── autoload/                  # Persistent game state
└── assets/                    # Art, UI, and navigation resources
```

## Vocabulary

Use the terms established by `CONTEXT.md` if it exists. For this game, distinguish evidence, clues, materials, keys, rooms, story flags, checkpoints, and NPCs rather than using them interchangeably.

## Decision conflicts

If a proposed change conflicts with an ADR, explicitly identify that conflict and explain why the decision should be reopened rather than silently overriding it.
