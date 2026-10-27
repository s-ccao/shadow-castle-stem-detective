// Echo Corridor: a pulse rolls out through a dark maze, walls flash into view
// as it passes, and the patrolling guard turns towards the sound.
// Walls in maze cells (16 units): [i1, j1, i2, j2].
const WALLS = [
  [0, 0, 9, 0], [0, 5, 9, 5], [0, 0, 0, 2], [0, 3, 0, 5], [9, 0, 9, 3], [9, 4, 9, 5],
  [2, 0, 2, 2], [1, 3, 3, 3], [3, 3, 3, 4], [4, 1, 4, 4], [5, 0, 5, 1], [5, 2, 7, 2],
  [6, 3, 6, 5], [7, 1, 8, 1], [8, 2, 8, 4], [1, 4, 2, 4], [4, 4, 5, 4],
];
const PULSES = [0.06, 0.54];
const SPAN = 0.34;
const REACH = 150;
const TAU = Math.PI * 2;

const playerX = (p) => -66 + 44 * p;

export default {
  period: 6400,
  still: 0.2,
  draw(c, k, p, v, pal) {
    const fade = k.seg(p, 0, 0.04) * (1 - k.seg(p, 0.94, 1));
    k.backdrop(c, v, pal, -30, 0, 110, 0.05);
    const waves = PULSES.map((p0) => {
      const q = k.seg(p, p0, p0 + SPAN);
      return { p0, q, r: REACH * k.ease(q), x: playerX(p0), live: q > 0 && q < 1 };
    });
    const light = (x, y) => {
      let lit = 0.05;
      for (const w of waves) {
        if (!w.live) continue;
        const d = Math.hypot(x - w.x, y);
        if (w.r >= d) lit = Math.max(lit, (1 - w.q) ** 0.7 * Math.max(0.15, 1 - (w.r - d) / 70));
      }
      return lit * fade;
    };

    c.fillStyle = k.col(pal.dim, 0.06);
    for (let i = 0; i < 9; i++) for (let j = 0; j < 5; j++) c.fillRect(-64.5 + i * 16, -32.5 + j * 16, 1, 1);
    k.halo(c, 78, 16, 16, pal.moon, 0.14);

    c.globalCompositeOperation = "lighter";
    c.lineCap = "butt";
    for (const [i1, j1, i2, j2] of WALLS) {
      const x1 = -72 + i1 * 16;
      const y1 = -40 + j1 * 16;
      const x2 = -72 + i2 * 16;
      const y2 = -40 + j2 * 16;
      const n = Math.max(1, Math.round(Math.hypot(x2 - x1, y2 - y1) / 4));
      for (let s = 0; s < n; s++) {
        const ax = x1 + ((x2 - x1) * s) / n;
        const ay = y1 + ((y2 - y1) * s) / n;
        const bx = x1 + ((x2 - x1) * (s + 1)) / n;
        const by = y1 + ((y2 - y1) * (s + 1)) / n;
        const lit = light((ax + bx) / 2, (ay + by) / 2);
        c.lineWidth = 2.8;
        c.strokeStyle = k.col(pal.a, lit * 0.2);
        k.line(c, ax, ay, bx, by);
        c.lineWidth = 0.9;
        c.strokeStyle = k.col(pal.a, lit);
        k.line(c, ax, ay, bx, by);
      }
    }
    c.lineCap = "round";
    for (const w of waves) {
      if (!w.live) continue;
      c.lineWidth = 1;
      c.strokeStyle = k.col(pal.a, (1 - w.q) * 0.75 * fade);
      c.beginPath();
      c.arc(w.x, 0, w.r, 0, TAU);
      c.stroke();
      c.strokeStyle = k.col(pal.a, (1 - w.q) * 0.25 * fade);
      c.beginPath();
      c.arc(w.x, 0, w.r * 0.82, 0, TAU);
      c.stroke();
    }

    // The guard patrols the upper corridor and turns when a pulse reaches it.
    const px = playerX(p);
    const gx = 31 - 19 * Math.cos(TAU * p);
    const gy = -16;
    let alert = 0;
    for (const w of waves) {
      const d = Math.hypot(gx - w.x, gy);
      if (d >= REACH) continue;
      const hit = w.p0 + SPAN * (1 - Math.cbrt(1 - d / REACH));
      alert = Math.max(alert, p >= hit ? 1 - k.seg(p, hit + 0.12, hit + 0.3) : 0);
    }
    alert *= fade;
    const look = alert > 0.2 ? Math.atan2(-gy, px - gx) : Math.sin(TAU * p) >= 0 ? 0 : Math.PI;
    c.fillStyle = k.col(pal.a, 0.05 + alert * 0.28);
    c.beginPath();
    c.moveTo(gx, gy);
    c.arc(gx, gy, 24, look - 0.42, look + 0.42);
    c.closePath();
    c.fill();
    k.halo(c, px, 0, 9, pal.ember, 0.35 * fade);
    c.globalCompositeOperation = "source-over";

    c.globalAlpha = fade;
    c.fillStyle = k.col(k.mix(pal.night, pal.dim, 0.4));
    c.beginPath();
    c.arc(gx, gy, 3, 0, TAU);
    c.fill();
    c.lineWidth = 0.6;
    c.strokeStyle = k.col(pal.dim, 0.8);
    c.stroke();
    c.fillStyle = k.col(pal.a, 0.5 + alert * 0.5);
    c.fillRect(gx + Math.cos(look) * 1.8 - 0.6, gy + Math.sin(look) * 1.8 - 0.6, 1.2, 1.2);
    if (alert > 0.05) {
      c.globalAlpha = alert;
      c.lineWidth = 1.1;
      c.strokeStyle = k.col(pal.a);
      k.line(c, gx, gy - 12.5, gx, gy - 8.6);
      c.fillStyle = k.col(pal.a);
      c.fillRect(gx - 0.55, gy - 7, 1.1, 1.1);
      c.globalAlpha = fade;
    }
    c.fillStyle = k.col(pal.ember);
    c.beginPath();
    c.arc(px, 0, 2, 0, TAU);
    c.fill();
  },
};
