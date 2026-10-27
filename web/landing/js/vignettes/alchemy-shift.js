// Alchemy Shift: two liquids pour into the flask, the brew turns elixir green
// and glows, the order slip ticks off and the combo bursts into sparks.
const TAU = Math.PI * 2;
const JOIN = 12 - Math.sqrt(18 * 18 - 4.5 * 4.5);
const A_LEFT = Math.atan2(JOIN - 12, -4.5);
const A_RIGHT = Math.atan2(JOIN - 12, 4.5);

function flask(c) {
  c.beginPath();
  c.moveTo(-4.5, -16);
  c.lineTo(-4.5, JOIN);
  c.arc(0, 12, 18, A_LEFT, A_RIGHT, true);
  c.lineTo(4.5, -16);
}

// A tilted vessel pouring a stream into the flask's mouth.
function pour(c, k, pal, side, rgb, from, to, p) {
  const tilt = k.ease(k.seg(p, from - 0.06, from)) * (1 - k.ease(k.seg(p, to, to + 0.06))) * 0.9;
  c.save();
  c.translate(side * 40, -28);
  c.rotate(-side * tilt);
  k.rrect(c, -5, -6, 10, 12, 2.5);
  c.fillStyle = k.col(pal.moon, 0.08);
  c.fill();
  c.fillStyle = k.col(rgb, 0.8);
  c.fillRect(-4, 0, 8, 5);
  c.lineWidth = 0.7;
  c.strokeStyle = k.col(pal.moon, 0.6);
  c.stroke();
  c.strokeRect(-1.8, -10, 3.6, 4);
  c.restore();
  const head = k.seg(p, from, from + 0.04);
  const tail = k.seg(p, to - 0.04, to);
  if (head <= tail) return;
  const sx = side * (40 - 10 * Math.sin(0.9));
  const sy = -28 - 10 * Math.cos(0.9);
  const mx = side * 18;
  const ex = side * 1.5;
  const at = (t) => [(1 - t) ** 2 * sx + 2 * (1 - t) * t * mx + t * t * ex, (1 - t) ** 2 * sy + 2 * (1 - t) * t * -34 + t * t * -17];
  c.beginPath();
  for (let s = 0; s <= 12; s++) c.lineTo(...at(tail + ((head - tail) * s) / 12));
  c.lineWidth = 1.5;
  c.strokeStyle = k.col(rgb, 0.85);
  c.stroke();
  c.fillStyle = k.col(rgb);
  for (let j = 0; j < 3; j++) {
    const t = (p * 14 + j / 3) % 1;
    if (t > tail && t < head) c.fillRect(...at(t).map((n) => n - 0.7), 1.4, 1.4);
  }
}

export default {
  period: 7000,
  still: 0.62,
  draw(c, k, p, v, pal) {
    const fade = 1 - k.seg(p, 0.95, 1);
    const drain = k.seg(p, 0.84, 0.95);
    const fill = k.ease(k.seg(p, 0.1, 0.45)) * (1 - drain);
    const green = k.ease(k.seg(p, 0.4, 0.52)) * (1 - drain);
    const done = k.seg(p, 0.56, 0.74);
    const level = 30 - 30 * fill;
    const brew = k.mix(k.mix(pal.arcane, pal.ember, k.seg(p, 0.16, 0.4) * 0.5), pal.a, green);
    k.backdrop(c, v, pal, 0, 10, 80, 0.06 + green * 0.2);
    c.globalAlpha = fade;

    c.fillStyle = k.col(k.mix(pal.night, pal.bronze, 0.1));
    c.fillRect(v.x0, 44, v.x1 - v.x0, v.y1 - 44);
    c.lineWidth = 1.2;
    c.strokeStyle = k.col(pal.bronze, 0.7);
    k.line(c, -14, 31, 14, 31);
    k.line(c, -12, 31, -17, 44);
    k.line(c, 12, 31, 17, 44);
    const flick = Math.sin(p * 80) * 0.8;
    c.beginPath();
    c.moveTo(-2.6, 42);
    c.quadraticCurveTo(-2.8, 37, 0, 33.5 - flick);
    c.quadraticCurveTo(2.8, 37, 2.6, 42);
    c.fillStyle = k.col(pal.ember, 0.85);
    c.fill();

    k.halo(c, 0, 12, 36, pal.a, green * 0.45);
    c.save();
    flask(c);
    c.closePath();
    c.clip();
    c.fillStyle = k.col(pal.moon, 0.06);
    c.fillRect(-20, -18, 40, 50);
    if (fill > 0.01) {
      c.beginPath();
      c.moveTo(-20, 32);
      for (let x = -20; x <= 20; x += 2) c.lineTo(x, level + Math.sin(x * 0.5 + p * 40) * 0.6);
      c.lineTo(20, 32);
      c.fillStyle = k.col(brew, 0.85);
      c.fill();
      c.lineWidth = 0.6;
      for (let i = 0; i < 10; i++) {
        const rise = (p * 3 + k.rand(i + 10)) % 1;
        const y = 29 - rise * (29 - level);
        if (y < level + 1) continue;
        c.strokeStyle = k.col(pal.moon, 0.55 * (1 - rise));
        c.beginPath();
        c.arc(-11 + k.rand(i) * 22, y, 0.7 + k.rand(i + 5) * 0.8, 0, TAU);
        c.stroke();
      }
    }
    c.restore();
    flask(c);
    c.lineWidth = 0.9;
    c.strokeStyle = k.col(pal.moon, 0.75);
    c.stroke();
    k.rrect(c, -6.5, -18.5, 13, 2.5, 1);
    c.stroke();
    c.lineWidth = 1.4;
    c.strokeStyle = k.col(pal.moon, 0.25);
    c.beginPath();
    c.arc(0, 12, 14, 3.6, 4.3);
    c.stroke();

    pour(c, k, pal, -1, pal.arcane, 0.08, 0.36, p);
    pour(c, k, pal, 1, pal.ember, 0.18, 0.42, p);

    // The order slip, its tick and the combo pips.
    k.rrect(c, -15, -47, 30, 11, 1.5);
    c.fillStyle = k.col(k.mix(pal.night, pal.ink, 0.1));
    c.fill();
    c.lineWidth = 0.6;
    c.strokeStyle = k.col(k.mix(pal.bronze, pal.a, done ? 1 : 0), 0.6);
    c.stroke();
    c.fillStyle = k.col(pal.ink, 0.35);
    c.fillRect(-12, -44, 14, 1.3);
    c.fillRect(-12, -40.5, 9, 1.3);
    c.strokeStyle = k.col(pal.bronze, 0.8);
    c.strokeRect(5.5, -44.5, 6, 6);
    const tick = k.seg(p, 0.56, 0.6) * (1 - drain);
    if (tick) {
      c.lineWidth = 1.2;
      c.strokeStyle = k.col(pal.a);
      c.beginPath();
      c.moveTo(6.8, -41.6);
      c.lineTo(6.8 + 1.8 * Math.min(1, tick * 2), -41.6 + 2 * Math.min(1, tick * 2));
      if (tick > 0.5) c.lineTo(8.6 + 3 * (tick - 0.5) * 2, -39.6 - 4.4 * (tick - 0.5) * 2);
      c.stroke();
    }
    for (let i = 0; i < 3; i++) {
      const on = i < 2 ? 1 : k.ease(k.seg(p, 0.58, 0.62)) * (1 - drain);
      const r = 1.8 * (i < 2 ? 1 : 1 + k.bump(k.seg(p, 0.58, 0.66)) * 0.6);
      c.fillStyle = k.col(on ? pal.a : pal.bronze, 0.35 + on * 0.6);
      c.beginPath();
      c.moveTo(21 + i * 5, -41.5 - r);
      c.lineTo(21 + i * 5 + r, -41.5);
      c.lineTo(21 + i * 5, -41.5 + r);
      c.lineTo(21 + i * 5 - r, -41.5);
      c.fill();
    }

    if (done > 0 && done < 1) {
      c.globalCompositeOperation = "lighter";
      c.lineWidth = 1;
      c.strokeStyle = k.col(pal.a, (1 - done) * 0.8);
      c.beginPath();
      c.arc(0, 10, 8 + 42 * k.ease(done), 0, TAU);
      c.stroke();
      for (let i = 0; i < 24; i++) {
        const a = k.rand(i) * TAU;
        const d = (16 + k.rand(i + 30) * 30) * k.ease(done);
        c.fillStyle = k.col(k.mix(pal.a, pal.ember, k.rand(i + 60)), 1 - done);
        c.fillRect(Math.cos(a) * d - 0.5, 8 + Math.sin(a) * d + 26 * done * done - 0.5, 1, 1);
      }
    }
  },
};
