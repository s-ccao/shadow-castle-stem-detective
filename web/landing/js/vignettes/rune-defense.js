// Rune Defense: runes are set along the road, shadows march on the gate, and
// one rune's burst arcs to the next until the whole line has fired.
const TAU = Math.PI * 2;
const PATH = [[-90, -20], [-56, -20], [-34, 6], [-6, 16], [20, -4], [44, 2], [64, 0]];
const RUNES = [[-45, -7], [-20, 11], [7, 6], [32, -1]];
const PLACE = [0.04, 0.09, 0.14, 0.19];
const FIRE = [0.5, 0.54, 0.58, 0.62];
const WALK = [0, 0.07, 0.14, 0.21, 0.28];
const FALL = [0.64, 0.62, 0.6, 0.56, 0.52];
const SPEED = 230;

function along(s) {
  for (let i = 1; i < PATH.length; i++) {
    const [ax, ay] = PATH[i - 1];
    const [bx, by] = PATH[i];
    const l = Math.hypot(bx - ax, by - ay);
    if (s <= l) return [ax + ((bx - ax) * s) / l, ay + ((by - ay) * s) / l];
    s -= l;
  }
  return PATH[PATH.length - 1];
}

function rune(c, k, pal, i, p) {
  const [x, y] = RUNES[i];
  const set = k.ease(k.seg(p, PLACE[i], PLACE[i] + 0.04));
  if (!set) return;
  const charge = 0.3 + 0.7 * k.bump(k.seg(p, FIRE[i] - 0.02, FIRE[i] + 0.16));
  const flash = k.seg(p, PLACE[i], PLACE[i] + 0.06);
  c.lineWidth = 0.8;
  if (flash < 1) {
    c.strokeStyle = k.col(pal.a, (1 - flash) * 0.8);
    c.beginPath();
    c.arc(x, y, 6 + flash * 10, 0, TAU);
    c.stroke();
  }
  k.halo(c, x, y, 11, pal.a, charge * 0.45);
  c.strokeStyle = k.col(pal.a, 0.35 + charge * 0.65);
  c.beginPath();
  c.arc(x, y, 6.5 * set, 0, TAU);
  c.moveTo(x + 4.6 * set, y);
  c.arc(x, y, 4.6 * set, 0, TAU);
  for (let n = 0; n < 3; n++) {
    const a = k.rand(i * 3 + n) * TAU;
    const b = a + 1.4 + k.rand(i * 3 + n + 20) * 1.8;
    c.moveTo(x + Math.cos(a) * 3.6 * set, y + Math.sin(a) * 3.6 * set);
    c.lineTo(x + Math.cos(b) * 3.6 * set, y + Math.sin(b) * 3.6 * set);
  }
  c.stroke();
}

export default {
  period: 8000,
  still: 0.6,
  draw(c, k, p, v, pal) {
    const fade = 1 - k.seg(p, 0.9, 1);
    const held = k.bump(k.seg(p, 0.64, 0.9));
    k.backdrop(c, v, pal, 10, 4, 100, 0.06 + held * 0.08);
    c.globalAlpha = fade;

    c.lineWidth = 0.5;
    c.strokeStyle = k.col(pal.edge, 0.07);
    for (let x = -84; x < 64; x += 12) k.line(c, x, v.y0, x, v.y1);
    for (let y = -48; y < 50; y += 12) k.line(c, v.x0, y, 64, y);
    c.beginPath();
    PATH.forEach(([x, y]) => c.lineTo(x, y));
    c.lineWidth = 14;
    c.strokeStyle = k.col(k.mix(pal.night, pal.stone, 0.5));
    c.stroke();
    c.lineWidth = 10;
    c.strokeStyle = k.col(k.mix(pal.night, pal.stone, 0.68));
    c.stroke();

    // The wall and its gate.
    c.fillStyle = k.col(k.mix(pal.night, pal.stone, 0.85));
    c.fillRect(64, v.y0, v.x1 - 64, v.y1 - v.y0);
    for (let y = -52; y < 52; y += 10) c.fillRect(60, y, 4, 5);
    c.lineWidth = 0.7;
    c.strokeStyle = k.col(pal.edge, 0.5);
    k.line(c, 64, v.y0, 64, v.y1);
    k.halo(c, 64, 0, 24, pal.a, held * 0.5);
    k.rrect(c, 60, -9, 8, 18, 3);
    c.fillStyle = k.col(pal.night);
    c.fill();
    c.strokeStyle = k.col(k.mix(pal.bronze, pal.a, held), 0.9);
    c.stroke();

    for (let i = 0; i < RUNES.length; i++) rune(c, k, pal, i, p);

    WALK.forEach((start, i) => {
      if (p < start) return;
      const gone = k.seg(p, FALL[i], FALL[i] + 0.1);
      const [x, y] = along(SPEED * (Math.min(p, FALL[i]) - start));
      if (gone > 0) {
        if (gone >= 1) return;
        for (let n = 0; n < 10; n++) {
          const a = k.rand(i * 10 + n) * TAU;
          const d = 10 * k.ease(gone) * (0.4 + k.rand(n + 70));
          c.fillStyle = k.col(k.mix(pal.a, pal.arcane, k.rand(n)), 1 - gone);
          c.fillRect(x + Math.cos(a) * d - 0.5, y + Math.sin(a) * d - gone * 6 - 0.5, 1, 1);
        }
        return;
      }
      const bob = Math.sin(p * 90 + i * 2) * 0.6;
      c.globalAlpha = fade * k.seg(p, start, start + 0.03);
      c.fillStyle = k.col(pal.night, 0.7);
      c.beginPath();
      c.ellipse(x, y + 3.6, 4, 1.2, 0, 0, TAU);
      c.fill();
      c.fillStyle = k.col(k.mix(pal.night, pal.arcane, 0.3));
      c.beginPath();
      c.moveTo(x - 3, y - 3.4 + bob);
      c.lineTo(x - 1.8, y - 6.4 + bob);
      c.lineTo(x - 0.6, y - 3.6 + bob);
      c.lineTo(x + 0.6, y - 3.6 + bob);
      c.lineTo(x + 1.8, y - 6.4 + bob);
      c.lineTo(x + 3, y - 3.4 + bob);
      c.ellipse(x, y - 0.6 + bob, 4.2, 3.6, 0, -0.5, Math.PI + 0.5);
      c.fill();
      c.fillStyle = k.col(pal.moon, 0.95);
      c.fillRect(x - 2, y - 1.8 + bob, 1, 1);
      c.fillRect(x + 1, y - 1.8 + bob, 1, 1);
      c.globalAlpha = fade;
    });

    // Bursts, and the arcs that carry each one to the next rune.
    c.globalCompositeOperation = "lighter";
    const flicker = Math.floor(p * 160);
    RUNES.forEach(([x, y], i) => {
      const q = k.seg(p, FIRE[i], FIRE[i] + 0.1);
      if (q > 0 && q < 1) {
        k.halo(c, x, y, 24 * k.ease(q), pal.a, (1 - q) * 0.4);
        c.lineWidth = 1;
        c.strokeStyle = k.col(pal.a, 1 - q);
        c.beginPath();
        c.arc(x, y, 4 + 18 * k.ease(q), 0, TAU);
        c.stroke();
      }
      if (!i || p < FIRE[i] - 0.025 || p > FIRE[i] + 0.02) return;
      const [ax, ay] = RUNES[i - 1];
      const nx = -(y - ay) / Math.hypot(x - ax, y - ay);
      const ny = (x - ax) / Math.hypot(x - ax, y - ay);
      c.beginPath();
      for (let j = 0; j <= 7; j++) {
        const off = j && j < 7 ? (k.rand(flicker * 8 + j) - 0.5) * 7 : 0;
        c.lineTo(ax + ((x - ax) * j) / 7 + nx * off, ay + ((y - ay) * j) / 7 + ny * off);
      }
      c.lineWidth = 2.6;
      c.strokeStyle = k.col(pal.a, 0.25);
      c.stroke();
      c.lineWidth = 0.9;
      c.strokeStyle = k.col(pal.ember, 0.95);
      c.stroke();
    });
    for (let i = 0; i < 10 && held; i++) {
      const rise = (p * 2 + k.rand(i)) % 1;
      c.fillStyle = k.col(pal.a, held * (1 - rise) * 0.8);
      c.fillRect(-40 + k.rand(i + 10) * 100, 20 - rise * 50, 0.9, 0.9);
    }
  },
};
