import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Deterministic, original power-restoration one-shot for Shadow Castle.
// Layers: low generator impact, rising transformer hum, asymmetric electrical
// arcs and a short energized tail. No samples or third-party source audio.

const SAMPLE_RATE = 44100;
const CHANNELS = 2;
const BITS_PER_SAMPLE = 16;
const DURATION_SECONDS = 1.65;
const FRAME_COUNT = Math.floor(SAMPLE_RATE * DURATION_SECONDS);
const BURSTS = [0.055, 0.16, 0.285, 0.46, 0.72, 1.02];

let randomState = 0x5a17c9e3;
function randomSigned() {
  randomState ^= randomState << 13;
  randomState ^= randomState >>> 17;
  randomState ^= randomState << 5;
  return ((randomState >>> 0) / 0xffffffff) * 2 - 1;
}

function smoothstep(edge0, edge1, value) {
  const x = Math.max(0, Math.min(1, (value - edge0) / (edge1 - edge0)));
  return x * x * (3 - 2 * x);
}

const left = new Float64Array(FRAME_COUNT);
const right = new Float64Array(FRAME_COUNT);
let lowPhase = 0;
let humPhase = 0;
let previousNoise = 0;

for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
  const t = frame / SAMPLE_RATE;

  // Heavy relay impact: a fast pitch drop with a restrained sub harmonic.
  const impactEnvelope = Math.exp(-t * 8.6);
  const impactFrequency = 86 - 48 * smoothstep(0, 0.34, t);
  lowPhase += (Math.PI * 2 * impactFrequency) / SAMPLE_RATE;
  const impact =
    Math.sin(lowPhase) * impactEnvelope * 0.58 +
    Math.sin(lowPhase * 0.51) * impactEnvelope * 0.19;

  // Generator catches and stabilizes into a low mechanical/electrical hum.
  const humAttack = smoothstep(0.06, 0.48, t);
  const humRelease = 1 - smoothstep(1.22, DURATION_SECONDS, t);
  const humFrequency = 48 + 19 * smoothstep(0.08, 0.92, t);
  humPhase += (Math.PI * 2 * humFrequency) / SAMPLE_RATE;
  const hum =
    (Math.sin(humPhase) * 0.19 +
      Math.sin(humPhase * 2.01 + 0.35) * 0.075 +
      Math.sin(humPhase * 3.98) * 0.025) *
    humAttack *
    humRelease;

  // High-passed deterministic noise provides electrical texture.
  const rawNoise = randomSigned();
  const highNoise = rawNoise - previousNoise * 0.88;
  previousNoise = rawNoise;

  let arcLeft = 0;
  let arcRight = 0;
  for (let index = 0; index < BURSTS.length; index += 1) {
    const delta = t - BURSTS[index];
    if (delta < -0.018 || delta > 0.13) continue;
    const width = 0.018 + index * 0.0025;
    const envelope = Math.exp(-(delta * delta) / (2 * width * width));
    const chirpFrequency = 760 + index * 173 + Math.max(delta, 0) * 4800;
    const chirp = Math.sin(Math.PI * 2 * chirpFrequency * delta) * 0.20;
    const crackle = highNoise * 0.23;
    const burst = (chirp + crackle) * envelope;
    const pan = index % 2 === 0 ? 0.72 : 0.28;
    arcLeft += burst * (1 - pan * 0.42);
    arcRight += burst * (0.58 + pan * 0.42);
  }

  // A faint glassy resonance makes the power source feel arcane, not modern.
  const resonanceEnvelope = smoothstep(0.18, 0.42, t) * (1 - smoothstep(1.08, 1.55, t));
  const resonance =
    (Math.sin(Math.PI * 2 * 523.25 * t) * 0.027 +
      Math.sin(Math.PI * 2 * 783.99 * t + 0.7) * 0.018) *
    resonanceEnvelope;

  const fadeIn = smoothstep(0, 0.004, t);
  const fadeOut = 1 - smoothstep(1.42, DURATION_SECONDS, t);
  left[frame] = (impact + hum + arcLeft + resonance) * fadeIn * fadeOut;
  right[frame] = (impact * 0.97 + hum + arcRight + resonance * 1.04) * fadeIn * fadeOut;
}

let peak = 0;
for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
  peak = Math.max(peak, Math.abs(left[frame]), Math.abs(right[frame]));
}
const normalization = peak > 0 ? 0.72 / peak : 1;

const bytesPerSample = BITS_PER_SAMPLE / 8;
const dataSize = FRAME_COUNT * CHANNELS * bytesPerSample;
const buffer = Buffer.alloc(44 + dataSize);
let offset = 0;
function writeString(value) {
  buffer.write(value, offset, "ascii");
  offset += value.length;
}
function writeU16(value) {
  buffer.writeUInt16LE(value, offset);
  offset += 2;
}
function writeU32(value) {
  buffer.writeUInt32LE(value, offset);
  offset += 4;
}

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

for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
  const l = Math.max(-1, Math.min(1, left[frame] * normalization));
  const r = Math.max(-1, Math.min(1, right[frame] * normalization));
  buffer.writeInt16LE(Math.round(l * 32767), offset);
  offset += 2;
  buffer.writeInt16LE(Math.round(r * 32767), offset);
  offset += 2;
}

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const outputPath = path.resolve(toolDirectory, "../assets/audio/sfx/power_restore_surge.wav");
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, buffer);
console.log(`GENERATED: ${outputPath}`);
console.log(`FORMAT: ${SAMPLE_RATE} Hz, stereo, 16-bit PCM, ${DURATION_SECONDS.toFixed(2)} s`);
console.log(`SOURCE_PEAK: ${peak.toFixed(5)}  NORMALIZATION: ${normalization.toFixed(5)}`);
