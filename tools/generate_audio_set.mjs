import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Deterministic, original audio set for Shadow Castle: STEM Detective.
// Everything here is synthesized from oscillators and seeded noise -- there are
// no samples and no third-party source audio anywhere in this file.
//
// Two families are produced:
//   * one-shot SFX, mixed dry so the runtime bus chain owns the space, and
//   * three adaptive music layers that are bar-aligned and phase-exact, so the
//     runtime can crossfade between them without a seam or a tempo slip.
//
// The music layers all share LOOP_SECONDS and every partial is snapped to an
// integer multiple of 1/LOOP_SECONDS. That is what makes the loop points
// sample-exact: each oscillator completes a whole number of cycles per loop, so
// the last frame joins the first with no discontinuity to click on.

const SAMPLE_RATE = 44100;
const CHANNELS = 2;
const BITS_PER_SAMPLE = 16;

const LOOP_SECONDS = 8.0;
const LOOP_HZ = 1 / LOOP_SECONDS;

// D natural minor. The case is a mystery, not a tragedy: minor, but open.
const NOTE = {
  D1: 36.71,
  A1: 55.0,
  D2: 73.42,
  F2: 87.31,
  A2: 110.0,
  C3: 130.81,
  D3: 146.83,
  E3: 164.81,
  F3: 174.61,
  G3: 196.0,
  A3: 220.0,
  Bb3: 233.08,
  C4: 261.63,
  D4: 293.66,
  E4: 329.63,
  F4: 349.23,
  A4: 440.0,
  D5: 587.33,
};

// ---------------------------------------------------------------- utilities

function makeRandom(seed) {
  let state = seed >>> 0;
  return function randomSigned() {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) / 0xffffffff) * 2 - 1;
  };
}

function smoothstep(edge0, edge1, value) {
  const x = Math.max(0, Math.min(1, (value - edge0) / (edge1 - edge0)));
  return x * x * (3 - 2 * x);
}

/** Snap a frequency so it completes whole cycles inside one loop. */
function snapToLoop(frequency) {
  return Math.max(LOOP_HZ, Math.round(frequency / LOOP_HZ) * LOOP_HZ);
}

function makeBuffer(seconds) {
  const frames = Math.floor(SAMPLE_RATE * seconds);
  return { frames, seconds, left: new Float64Array(frames), right: new Float64Array(frames) };
}

function addSample(buffer, frame, value, pan = 0) {
  if (frame < 0 || frame >= buffer.frames) {
    return;
  }
  const l = Math.min(1, 1 - pan);
  const r = Math.min(1, 1 + pan);
  buffer.left[frame] += value * l;
  buffer.right[frame] += value * r;
}

/**
 * Sustained tone written across the whole loop. Because the frequency is
 * loop-snapped and the amplitude shape is a function of loop phase, the result
 * is seamless by construction.
 */
function layerDrone(buffer, frequency, amplitude, options = {}) {
  const { detune = 0, pan = 0, partials = [1], shape = null } = options;
  const base = snapToLoop(frequency);
  const detuned = snapToLoop(frequency + detune);
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    const t = frame / SAMPLE_RATE;
    const phase = t / buffer.seconds;
    let value = 0;
    for (let index = 0; index < partials.length; index += 1) {
      const gain = partials[index];
      if (gain === 0) {
        continue;
      }
      const multiple = index + 1;
      value += Math.sin(2 * Math.PI * base * multiple * t) * gain;
      value += Math.sin(2 * Math.PI * detuned * multiple * t + 0.7) * gain * 0.5;
    }
    const envelope = shape == null ? 1 : shape(phase);
    addSample(buffer, frame, value * amplitude * envelope, pan);
  }
}

/** Plucked/struck tone with an exponential decay, placed at a beat position. */
function strikeTone(buffer, atSeconds, frequency, amplitude, options = {}) {
  const { decay = 6.0, pan = 0, partials = [1, 0.28, 0.12], wrap = true } = options;
  const startFrame = Math.round(atSeconds * SAMPLE_RATE);
  const length = Math.min(buffer.frames, Math.ceil((6 / decay) * SAMPLE_RATE));
  for (let offset = 0; offset < length; offset += 1) {
    const t = offset / SAMPLE_RATE;
    const envelope = Math.exp(-t * decay);
    let value = 0;
    for (let index = 0; index < partials.length; index += 1) {
      value += Math.sin(2 * Math.PI * frequency * (index + 1) * t) * partials[index];
    }
    let frame = startFrame + offset;
    if (frame >= buffer.frames) {
      // Tails wrap into the head of the loop so a decaying note is never cut
      // off at the loop point.
      if (!wrap) {
        break;
      }
      frame -= buffer.frames;
    }
    addSample(buffer, frame, value * amplitude * envelope, pan);
  }
}

/** Low percussive thump with a fast downward pitch sweep. */
function strikeDrum(buffer, atSeconds, fromHz, toHz, amplitude, decay) {
  const startFrame = Math.round(atSeconds * SAMPLE_RATE);
  const length = Math.min(buffer.frames, Math.ceil((6 / decay) * SAMPLE_RATE));
  let phase = 0;
  for (let offset = 0; offset < length; offset += 1) {
    const t = offset / SAMPLE_RATE;
    const envelope = Math.exp(-t * decay);
    const frequency = toHz + (fromHz - toHz) * Math.exp(-t * 18);
    phase += (2 * Math.PI * frequency) / SAMPLE_RATE;
    let frame = startFrame + offset;
    if (frame >= buffer.frames) {
      frame -= buffer.frames;
    }
    addSample(buffer, frame, Math.sin(phase) * amplitude * envelope, 0);
  }
}

/** Seeded, band-limited noise burst -- brushes, air, paper, arcs. */
function strikeNoise(buffer, atSeconds, amplitude, options = {}) {
  const { decay = 22, pan = 0, highpass = 0.7, seed = 0x2f6b1d77, wrap = true } = options;
  const random = makeRandom(seed);
  const startFrame = Math.round(atSeconds * SAMPLE_RATE);
  const length = Math.min(buffer.frames, Math.ceil((7 / decay) * SAMPLE_RATE));
  let previous = 0;
  for (let offset = 0; offset < length; offset += 1) {
    const t = offset / SAMPLE_RATE;
    const raw = random();
    const filtered = raw - previous * highpass;
    previous = raw;
    const envelope = Math.exp(-t * decay);
    let frame = startFrame + offset;
    if (frame >= buffer.frames) {
      if (!wrap) {
        break;
      }
      frame -= buffer.frames;
    }
    addSample(buffer, frame, filtered * amplitude * envelope, pan);
  }
}

function writeWav(buffer, outputPath, peakTarget = 0.86) {
  let peak = 0;
  for (let frame = 0; frame < buffer.frames; frame += 1) {
    peak = Math.max(peak, Math.abs(buffer.left[frame]), Math.abs(buffer.right[frame]));
  }
  const normalization = peak > 0 ? peakTarget / peak : 1;
  const bytesPerSample = BITS_PER_SAMPLE / 8;
  const dataSize = buffer.frames * CHANNELS * bytesPerSample;
  const out = Buffer.alloc(44 + dataSize);
  let offset = 0;
  const writeString = (value) => {
    out.write(value, offset, "ascii");
    offset += value.length;
  };
  const writeU16 = (value) => {
    out.writeUInt16LE(value, offset);
    offset += 2;
  };
  const writeU32 = (value) => {
    out.writeUInt32LE(value, offset);
    offset += 4;
  };

  writeString("RIFF");
  writeU32(36 + dataSize);
  writeString("WAVE");
  writeString("fmt ");
  writeU32(16);
  writeU16(1);
  writeU16(CHANNELS);
  writeU32(SAMPLE_RATE);
  writeU32(SAMPLE_RATE * CHANNELS * bytesPerSample);
  writeU16(CHANNELS * bytesPerSample);
  writeU16(BITS_PER_SAMPLE);
  writeString("data");
  writeU32(dataSize);

  for (let frame = 0; frame < buffer.frames; frame += 1) {
    const l = Math.max(-1, Math.min(1, buffer.left[frame] * normalization));
    const r = Math.max(-1, Math.min(1, buffer.right[frame] * normalization));
    out.writeInt16LE(Math.round(l * 32767), offset);
    offset += 2;
    out.writeInt16LE(Math.round(r * 32767), offset);
    offset += 2;
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, out);
  return { peak, normalization };
}

// ------------------------------------------------------------- music layers

const BEAT = LOOP_SECONDS / 8; // 8 beats per loop = 60 BPM at 1 beat/second.

/**
 * Layer 1 -- the archive at rest. A low bowed drone with a slow breathing swell
 * and a handful of sparse celesta notes. This plays everywhere, always.
 */
function buildMusicBed() {
  const buffer = makeBuffer(LOOP_SECONDS);
  const breathe = (phase) => 0.62 + 0.38 * (0.5 - 0.5 * Math.cos(2 * Math.PI * phase));

  layerDrone(buffer, NOTE.D2, 0.30, { detune: 0.35, partials: [1, 0.30, 0.13, 0.06], shape: breathe });
  layerDrone(buffer, NOTE.A2, 0.16, { detune: -0.28, pan: -0.18, partials: [1, 0.22, 0.08], shape: breathe });
  layerDrone(buffer, NOTE.F3, 0.075, {
    detune: 0.22,
    pan: 0.22,
    partials: [1, 0.16],
    shape: (phase) => 0.35 + 0.65 * smoothstep(0.1, 0.55, phase) * (1 - smoothstep(0.62, 0.98, phase)),
  });

  // Sparse celesta: a falling D-minor figure that leaves plenty of silence.
  strikeTone(buffer, 0 * BEAT, NOTE.D5, 0.085, { decay: 3.1, pan: 0.32 });
  strikeTone(buffer, 3 * BEAT, NOTE.A4, 0.070, { decay: 3.4, pan: -0.28 });
  strikeTone(buffer, 5 * BEAT, NOTE.F4, 0.060, { decay: 3.6, pan: 0.20 });
  strikeTone(buffer, 6.5 * BEAT, NOTE.D4, 0.055, { decay: 3.0, pan: -0.14 });

  return buffer;
}

/**
 * Layer 2 -- something is aware of you. Adds a slow heart-thump on the strong
 * beats and a tremolo minor second that refuses to resolve.
 */
function buildMusicTension() {
  const buffer = makeBuffer(LOOP_SECONDS);

  strikeDrum(buffer, 0 * BEAT, 96, 44, 0.52, 6.4);
  strikeDrum(buffer, 0.62 * BEAT, 88, 42, 0.34, 7.2);
  strikeDrum(buffer, 4 * BEAT, 96, 44, 0.52, 6.4);
  strikeDrum(buffer, 4.62 * BEAT, 88, 42, 0.34, 7.2);

  // Tremolo bed: an unresolved semitone rubbing against the tonic.
  const tremolo = (phase) => 0.5 + 0.5 * Math.sin(2 * Math.PI * 6 * phase * (LOOP_SECONDS / 1.0));
  layerDrone(buffer, NOTE.E3, 0.085, {
    detune: 0.4,
    pan: -0.3,
    partials: [1, 0.2],
    shape: (phase) => tremolo(phase) * smoothstep(0.0, 0.35, phase),
  });
  layerDrone(buffer, NOTE.F3, 0.085, {
    detune: -0.4,
    pan: 0.3,
    partials: [1, 0.2],
    shape: (phase) => tremolo(phase) * smoothstep(0.0, 0.35, phase),
  });

  strikeNoise(buffer, 2 * BEAT, 0.10, { decay: 9, pan: 0.4, seed: 0x11c7a3f1 });
  strikeNoise(buffer, 6 * BEAT, 0.09, { decay: 11, pan: -0.4, seed: 0x7ac41b09 });

  return buffer;
}

/**
 * Layer 3 -- the Guardian has you. A driving eighth-note ostinato plus low
 * brass stabs. Bar-aligned with the other layers so it can be faded in on top
 * of them without restarting the music.
 */
function buildMusicChase() {
  const buffer = makeBuffer(LOOP_SECONDS);

  const ostinato = [NOTE.D3, NOTE.D3, NOTE.F3, NOTE.D3, NOTE.E3, NOTE.D3, NOTE.C3, NOTE.D3];
  for (let step = 0; step < 16; step += 1) {
    const at = step * (BEAT / 2);
    const note = ostinato[step % ostinato.length];
    const accent = step % 4 === 0 ? 1.0 : 0.62;
    strikeTone(buffer, at, note, 0.16 * accent, {
      decay: 11,
      pan: step % 2 === 0 ? -0.16 : 0.16,
      partials: [1, 0.42, 0.2, 0.08],
    });
  }

  // Low brass stabs on the bar lines.
  for (const at of [0, 4]) {
    strikeTone(buffer, at * BEAT, NOTE.D2, 0.30, { decay: 4.0, partials: [1, 0.55, 0.3, 0.16, 0.08] });
    strikeTone(buffer, at * BEAT, NOTE.A2, 0.16, { decay: 4.2, partials: [1, 0.4, 0.18] });
  }
  strikeTone(buffer, 7 * BEAT, NOTE.Bb3, 0.15, { decay: 5.0, pan: 0.25, partials: [1, 0.45, 0.2] });

  strikeDrum(buffer, 2 * BEAT, 150, 52, 0.40, 9.0);
  strikeDrum(buffer, 6 * BEAT, 150, 52, 0.40, 9.0);

  return buffer;
}

// ---------------------------------------------------------------- one-shots

function buildUiSelect() {
  const buffer = makeBuffer(0.14);
  strikeTone(buffer, 0.0, NOTE.A4, 0.5, { decay: 34, partials: [1, 0.3, 0.1], wrap: false });
  strikeNoise(buffer, 0.0, 0.16, { decay: 130, highpass: 0.92, seed: 0x3d91f22b, wrap: false });
  return buffer;
}

function buildUiConfirm() {
  const buffer = makeBuffer(0.42);
  strikeTone(buffer, 0.0, NOTE.A3, 0.42, { decay: 9, partials: [1, 0.35, 0.14], wrap: false });
  strikeTone(buffer, 0.075, NOTE.D4, 0.40, { decay: 7.5, partials: [1, 0.3, 0.12], wrap: false });
  strikeTone(buffer, 0.075, NOTE.F4, 0.22, { decay: 7.0, pan: 0.2, partials: [1, 0.25], wrap: false });
  return buffer;
}

function buildUiBack() {
  const buffer = makeBuffer(0.22);
  strikeTone(buffer, 0.0, NOTE.D3, 0.42, { decay: 22, partials: [1, 0.25], wrap: false });
  strikeNoise(buffer, 0.0, 0.12, { decay: 70, highpass: 0.55, seed: 0x5b2ce417, wrap: false });
  return buffer;
}

function buildItemPickup() {
  const buffer = makeBuffer(0.5);
  strikeTone(buffer, 0.0, NOTE.D4, 0.34, { decay: 11, partials: [1, 0.4, 0.18], wrap: false });
  strikeTone(buffer, 0.055, NOTE.A4, 0.30, { decay: 9, pan: 0.18, partials: [1, 0.3], wrap: false });
  strikeTone(buffer, 0.11, NOTE.D5, 0.24, { decay: 7.5, pan: -0.14, partials: [1, 0.22], wrap: false });
  return buffer;
}

function buildNoteFile() {
  const buffer = makeBuffer(0.36);
  // Paper slide, then the stamp landing on it.
  strikeNoise(buffer, 0.0, 0.30, { decay: 16, highpass: 0.86, seed: 0x64af0c93, wrap: false });
  strikeDrum(buffer, 0.13, 190, 70, 0.42, 26);
  strikeNoise(buffer, 0.13, 0.20, { decay: 46, highpass: 0.5, seed: 0x1e77b405, wrap: false });
  return buffer;
}

function buildSwitchThrow() {
  const buffer = makeBuffer(0.34);
  // Blade leaves the housing, then seats hard into the contact.
  strikeNoise(buffer, 0.0, 0.22, { decay: 60, highpass: 0.8, seed: 0x2ab98d61, wrap: false });
  strikeDrum(buffer, 0.085, 320, 96, 0.55, 30);
  strikeNoise(buffer, 0.085, 0.26, { decay: 40, highpass: 0.62, seed: 0x77e21ca5, wrap: false });
  strikeTone(buffer, 0.085, NOTE.A2, 0.20, { decay: 20, partials: [1, 0.5, 0.25], wrap: false });
  return buffer;
}

function buildBenchPass() {
  const buffer = makeBuffer(1.1);
  // A circuit closing: D minor resolving up to F major -- earned, not triumphal.
  for (const [at, note, gain] of [
    [0.0, NOTE.D3, 0.30],
    [0.0, NOTE.F3, 0.24],
    [0.0, NOTE.A3, 0.20],
    [0.18, NOTE.F3, 0.26],
    [0.18, NOTE.A3, 0.22],
    [0.18, NOTE.C4, 0.20],
    [0.36, NOTE.D4, 0.24],
    [0.36, NOTE.A4, 0.16],
  ]) {
    strikeTone(buffer, at, note, gain, { decay: 3.4, partials: [1, 0.34, 0.15, 0.06], wrap: false });
  }
  strikeNoise(buffer, 0.36, 0.10, { decay: 5.5, highpass: 0.9, seed: 0x40b6e13d, wrap: false });
  return buffer;
}

function buildBenchFail() {
  const buffer = makeBuffer(0.55);
  // A dull, shorted buzz. Discouraging, never harsh.
  const frames = buffer.frames;
  let phase = 0;
  for (let frame = 0; frame < frames; frame += 1) {
    const t = frame / SAMPLE_RATE;
    const envelope = Math.exp(-t * 7.0) * (1 - smoothstep(0.42, 0.55, t));
    const frequency = 92 - 18 * smoothstep(0, 0.5, t);
    phase += (2 * Math.PI * frequency) / SAMPLE_RATE;
    const square = Math.sign(Math.sin(phase)) * 0.35 + Math.sin(phase) * 0.65;
    addSample(buffer, frame, square * 0.42 * envelope, 0);
  }
  strikeNoise(buffer, 0.0, 0.14, { decay: 26, highpass: 0.45, seed: 0x0cd7fa19, wrap: false });
  return buffer;
}

function buildPotionExtract() {
  const buffer = makeBuffer(1.35);
  // Reagents feeding in, a rising extraction, then the flask settling.
  const frames = buffer.frames;
  let phase = 0;
  for (let frame = 0; frame < frames; frame += 1) {
    const t = frame / SAMPLE_RATE;
    const rise = smoothstep(0.0, 0.72, t);
    const envelope = smoothstep(0, 0.12, t) * (1 - smoothstep(0.78, 1.05, t));
    const frequency = 180 + 520 * rise;
    phase += (2 * Math.PI * frequency) / SAMPLE_RATE;
    const body = Math.sin(phase) * 0.5 + Math.sin(phase * 2.01) * 0.16;
    addSample(buffer, frame, body * 0.30 * envelope, Math.sin(t * 5.0) * 0.25);
  }
  // Bubbles.
  const bubbleRandom = makeRandom(0x59a10f37);
  for (let index = 0; index < 14; index += 1) {
    const at = 0.05 + index * 0.052;
    const note = 300 + Math.abs(bubbleRandom()) * 520;
    strikeTone(buffer, at, note, 0.08, { decay: 40, pan: bubbleRandom() * 0.5, partials: [1], wrap: false });
  }
  // The finished potion settles into the flask.
  strikeTone(buffer, 0.92, NOTE.D4, 0.26, { decay: 4.5, partials: [1, 0.3, 0.12], wrap: false });
  strikeTone(buffer, 0.92, NOTE.A4, 0.18, { decay: 4.8, pan: 0.2, partials: [1, 0.22], wrap: false });
  strikeNoise(buffer, 0.92, 0.09, { decay: 7, highpass: 0.93, seed: 0x2c840be5, wrap: false });
  return buffer;
}

function buildGuardianAlert() {
  const buffer = makeBuffer(1.5);
  // Low brass cluster: the moment it notices you.
  strikeTone(buffer, 0.0, NOTE.D1, 0.40, { decay: 2.6, partials: [1, 0.6, 0.34, 0.2, 0.1], wrap: false });
  strikeTone(buffer, 0.0, NOTE.A1, 0.26, { decay: 2.8, partials: [1, 0.5, 0.26], wrap: false });
  strikeTone(buffer, 0.02, NOTE.D2, 0.22, { decay: 3.0, pan: -0.2, partials: [1, 0.45, 0.2], wrap: false });
  strikeTone(buffer, 0.02, NOTE.E3, 0.12, { decay: 3.2, pan: 0.25, partials: [1, 0.4], wrap: false });
  strikeNoise(buffer, 0.0, 0.16, { decay: 4.0, highpass: 0.35, seed: 0x6f3d2a11, wrap: false });
  return buffer;
}

// -------------------------------------------------------------------- build

const MUSIC = [
  ["music_bed.wav", buildMusicBed, 0.62],
  ["music_tension.wav", buildMusicTension, 0.58],
  ["music_chase.wav", buildMusicChase, 0.70],
];

const SFX = [
  ["ui_select.wav", buildUiSelect, 0.52],
  ["ui_confirm.wav", buildUiConfirm, 0.70],
  ["ui_back.wav", buildUiBack, 0.50],
  ["item_pickup.wav", buildItemPickup, 0.72],
  ["note_file.wav", buildNoteFile, 0.62],
  ["switch_throw.wav", buildSwitchThrow, 0.80],
  ["bench_pass.wav", buildBenchPass, 0.78],
  ["bench_fail.wav", buildBenchFail, 0.62],
  ["potion_extract.wav", buildPotionExtract, 0.76],
  ["guardian_alert.wav", buildGuardianAlert, 0.88],
];

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const musicDirectory = path.resolve(toolDirectory, "../assets/audio/music");
const sfxDirectory = path.resolve(toolDirectory, "../assets/audio/sfx");

for (const [name, build, peakTarget] of MUSIC) {
  const buffer = build();
  const outputPath = path.join(musicDirectory, name);
  const { peak, normalization } = writeWav(buffer, outputPath, peakTarget);
  console.log(
    `GENERATED: music/${name}  ${buffer.seconds.toFixed(2)}s  peak=${peak.toFixed(4)}  norm=${normalization.toFixed(4)}`
  );
}

for (const [name, build, peakTarget] of SFX) {
  const buffer = build();
  const outputPath = path.join(sfxDirectory, name);
  const { peak, normalization } = writeWav(buffer, outputPath, peakTarget);
  console.log(
    `GENERATED: sfx/${name}  ${buffer.seconds.toFixed(2)}s  peak=${peak.toFixed(4)}  norm=${normalization.toFixed(4)}`
  );
}

console.log(`FORMAT: ${SAMPLE_RATE} Hz, stereo, 16-bit PCM`);
console.log(`MUSIC LOOP: ${LOOP_SECONDS.toFixed(2)} s, ${(60 / BEAT).toFixed(1)} BPM, bar-aligned across all layers`);
