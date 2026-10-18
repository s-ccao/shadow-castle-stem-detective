# Shadow Castle audio provenance

## Original generated assets

### `sfx/power_restore_surge.wav`

- **Purpose:** Circuit Room master-switch restoration impact.
- **Authorship:** Original deterministic synthesis created for this project; no samples or third-party recordings.
- **Generator:** `tools/generate_power_restore_sfx.mjs`.
- **Layers:** pitch-dropping relay impact, rising generator hum, deterministic electrical arcs, restrained arcane resonance.
- **Technical format:** 44.1 kHz, stereo, signed 16-bit PCM, 1.65 seconds, normalized to 0.72 peak amplitude for mix headroom.
- **License restrictions:** none beyond the repository/project's own distribution terms.

Re-run the generator after changing synthesis parameters, then let Godot reimport the WAV. Keep this file with any future music/SFX provenance entries.

### Chemistry observation cues

- **Purpose:** Material feedback for the Chemistry room's Material Observation Lab.
- **Authorship:** Original deterministic synthesis; no external samples, recordings or services.
- **Generator:** `node tools/generate_audio_set.mjs --chemistry-only`. This mode writes only the six cues below, leaving existing music and other SFX untouched.
- **Format:** 44.1 kHz, stereo, signed 16-bit PCM. All cues are short, non-looping and measured below clipping.

| File | Layers / use | Duration | Peak amplitude |
| --- | --- | --- | --- |
| `sfx/sample_fire.wav` | Filtered crackle and ember ticks | 0.85 s | 0.48 |
| `sfx/sample_bubbles.wav` | Staggered liquid bubble pops | 0.95 s | 0.48 |
| `sfx/sample_glass.wav` | Bright fracture and settling fragments | 0.65 s | 0.52 |
| `sfx/sample_water.wav` | Restrained liquid motion | 0.70 s | 0.42 |
| `sfx/sample_grains.wav` | Dry granular scattering | 0.65 s | 0.40 |
| `sfx/sample_metal.wav` | Damped metallic contact and resonance | 0.65 s | 0.44 |

`GameAudio` routes these through SFX. Replaying replaces the previous observation voice; switching samples or closing the experiment stops its owned voice without stopping a reused UI voice or restarting the music layers. These are stylized material cues, not recordings of laboratory experiments. Speaker/headphone listening QA remains a release check.

The naturalness pass schedules cues against each material's authored event time: glass is silent during its fall and sounds on impact, rather than at the Replay click. Pending events are cancelled on sample switch, replay or close. Melting ice, dissolving sugar, souring milk and growing salt crystals no longer produce invented splashes or rattles; the unused water cue remains an authored asset, not an automatic sound for every liquid. This is event synchronization at render-frame resolution, not a claim of sample-accurate hardware latency.
