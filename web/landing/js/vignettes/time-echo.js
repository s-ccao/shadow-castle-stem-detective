// Time Echo: record a walk to the pressure plate, rewind, then let the violet
// echo hold the plate while your present self walks through the open gate.
const FLOOR = 30;
const PLATE = -10;
const START = -66;
const GATE = 44;
const TAU = Math.PI * 2;

function gear(c, x, y, r, teeth, angle) {
  c.beginPath();
  for (let i = 0; i < teeth * 2; i++) {
    const a = angle + (i / (teeth * 2)) * TAU;
    const rr = i % 2 ? r : r + 2.4;
    c.lineTo(x + Math.cos(a - 0.12) * rr, y + Math.sin(a - 0.12) * rr);
    c.lineTo(x + Math.cos(a + 0.12) * rr, y + Math.sin(a + 0.12) * rr);
  }
  c.closePath();
  c.moveTo(x + r * 0.35, y);
  c.arc(x, y, r * 0.35, 0, TAU);
  c.stroke();
}

// A small detective silhouette standing on the floor at x.
function walker(c, k, x, rgb, alpha, step) {
  if (alpha <= 0) return;
  c.globalAlpha = alpha;
  c.strokeStyle = c.fillStyle = k.col(rgb);
  c.lineWidth = 1.4;
  const swing = Math.sin(step) * 2.2;
  k.line(c, x, FLOOR - 7, x + swing, FLOOR);
  k.line(c, x, FLOOR - 7, x - swing, FLOOR);
  k.rrect(c, x - 2.6, FLOOR - 15, 5.2, 9, 1.6);
  c.fill();
  c.beginPath();
  c.arc(x, FLOOR - 18, 2.4, 0, TAU);
  c.fill();
  c.lineWidth = 0.9;
  k.line(c, x - 3.6, FLOOR - 20.2, x + 3.6, FLOOR - 20.2);
  c.fillRect(x - 2, FLOOR - 23.4, 4, 3.2);
  c.globalAlpha = 1;
}

function trail(c, k, from, to, rgb, alpha) {
  c.fillStyle = k.col(rgb, alpha);
  for (let x = from; x < to - 3; x += 5) c.fillRect(x - 0.6, FLOOR + 2.4, 1.2, 1.2);
}

export default {
  period: 8000,
  still: 0.7,
  draw(c, k, p, v, pal) {
    const fade = 1 - k.seg(p, 0.92, 1);
    const back = k.inOut(k.seg(p, 0.28, 0.4));
    const story = p < 0.28 ? p : p < 0.4 ? 0.28 * (1 - back) : p - 0.4;
    const exit = k.seg(p, 0.8, 0.86) * fade;
    k.backdrop(c, v, pal, -10, -6, 110, 0.1);

    c.lineWidth = 0.9;
    c.strokeStyle = k.col(pal.bronze, 0.22);
    gear(c, -46, -18, 16, 12, story * 12);
    gear(c, -21, -33, 10, 8, -story * 19 + 0.2);
    gear(c, 18, -30, 13, 10, story * 15);

    c.fillStyle = k.col(k.mix(pal.night, pal.stone, 0.45));
    c.fillRect(v.x0, FLOOR, v.x1 - v.x0, v.y1 - FLOOR);
    c.lineWidth = 0.7;
    c.strokeStyle = k.col(pal.edge, 0.6);
    k.line(c, v.x0, FLOOR, v.x1, FLOOR);
    k.halo(c, 66, 16, 18, k.mix(pal.moon, pal.a, exit), 0.18 + exit * 0.4);

    // Who stands on the plate decides the gate.
    const self = k.seg(p, 0.18, 0.2) * (1 - k.seg(p, 0.28, 0.3));
    const echo = k.seg(p, 0.55, 0.57) * fade;
    const open = Math.max(k.ease(k.seg(p, 0.18, 0.24)) * (1 - k.ease(k.seg(p, 0.28, 0.32))), k.ease(k.seg(p, 0.56, 0.62)) * fade);
    const glow = self ? pal.ember : pal.a;
    k.halo(c, PLATE, FLOOR, 12, glow, Math.max(self, echo) * 0.5);
    c.fillStyle = k.col(k.mix(pal.bronze, glow, Math.max(self, echo)));
    c.fillRect(PLATE - 7, FLOOR - 1.6 + Math.max(self, echo) * 0.7, 14, 1.6);

    c.fillStyle = k.col(k.mix(pal.night, pal.stone, 0.8));
    c.fillRect(GATE - 4, -14, 2, 44);
    c.fillRect(GATE + 2, -14, 2, 44);
    c.fillRect(GATE - 6, -17, 12, 3);
    c.save();
    c.beginPath();
    c.rect(GATE - 2, -14, 4, 44);
    c.clip();
    c.lineWidth = 0.8;
    c.strokeStyle = k.col(pal.bronze, 0.85);
    const top = -14 - open * 36;
    for (let x = GATE - 1.4; x <= GATE + 1.5; x += 1.4) k.line(c, x, top, x, FLOOR - open * 36);
    k.line(c, GATE - 2, top + 14, GATE + 2, top + 14);
    k.line(c, GATE - 2, top + 30, GATE + 2, top + 30);
    c.restore();

    // Record, rewind, replay.
    let recX = START + 56 * k.seg(p, 0.02, 0.18);
    if (p >= 0.28) recX = PLATE - 56 * back;
    if (p < 0.4) {
      trail(c, k, START, recX, k.mix(pal.ember, pal.a, back), 0.45 * fade);
      walker(c, k, recX, k.mix(pal.ember, pal.a, back), 1 - back * 0.4, recX * 0.5);
    } else {
      const echoX = START + 56 * k.seg(p, 0.4, 0.56);
      const nowX = START + 132 * k.seg(p, 0.46, 0.86);
      trail(c, k, START, echoX, pal.a, 0.35 * fade);
      k.halo(c, echoX, FLOOR - 12, 14, pal.a, 0.3 * fade);
      walker(c, k, echoX, pal.a, 0.68 * fade * k.seg(p, 0.4, 0.42), echoX * 0.5);
      walker(c, k, nowX, pal.ember, fade * k.seg(p, 0.44, 0.48), nowX * 0.5);
    }

    if (back > 0 && back < 1) {
      c.lineWidth = 0.8;
      for (let i = 0; i < 20; i++) {
        const x = -60 + k.rand(i) * 100 - back * (40 + k.rand(i + 40) * 50);
        const y = -24 + k.rand(i + 20) * 50;
        c.strokeStyle = k.col(pal.a, k.bump(back) * 0.7);
        k.line(c, x, y, x + 4, y);
      }
    }

    // Recorder lamp: record dot, rewind arrows, replay arrow.
    c.globalAlpha = fade;
    c.fillStyle = k.col(p < 0.28 ? pal.ember : pal.a, p < 0.28 ? 0.6 + 0.4 * Math.sin(p * 70) : 0.9);
    c.beginPath();
    if (p < 0.28) c.arc(-70, -40, 2.2, 0, TAU);
    else if (p < 0.4) {
      for (const x of [-68, -72]) {
        c.moveTo(x + 2.4, -42.4);
        c.lineTo(x, -40);
        c.lineTo(x + 2.4, -37.6);
      }
    } else {
      c.moveTo(-72, -42.6);
      c.lineTo(-67.6, -40);
      c.lineTo(-72, -37.4);
    }
    c.fill();
  },
};
