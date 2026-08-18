# Ashford opening cinematic — source notes

## Purpose

These four image assets form one ordered prologue: **invitation → signal →
interruption → wake room**. They are deliberately text-free so localisation,
accessibility, and timing remain in `scripts/intro_cutscene.gd`.

## Generation record

- **Integrated:** 2026-08-13
- **Generator:** OpenAI image generation
- **Visual brief:** hand-crafted high-detail pixel art; midnight navy, wet stone,
  restrained violet light, aged brass, and no in-image UI or lettering.
- **Identity anchors:** a young brown-haired student detective in a worn brown
  coat and satchel; a young Dr. Lin with short black hair, round gold glasses,
  a navy-black research coat, and a notebook.

| Asset | Narrative cut |
| --- | --- |
| `intro_01_invitation.png` | The detective arrives at the storm-bound Ashford gate with Dr. Lin's invitation. |
| `intro_02_signal.png` | Dr. Lin sends a violet warning from the observatory as the estate blacks out. |
| `intro_03_interruption.png` | The castle locks itself and the detective loses a crucial stretch of memory. |
| `intro_04_wake.png` | He wakes in the locked first room beside the next lead. |

The atmosphere score is procedural and authored in
`scripts/intro_cutscene.gd`; it contains no third-party music samples.
