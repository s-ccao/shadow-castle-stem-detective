// Evidence Rush: cards land on the board, threads tie evidence to testimony,
// one link flashes as the contradiction, then the whole board lights up.
// [x, y, w, h, testimony?]
const CARDS = [
  [-50, -27, 36, 18, 1],
  [-50, 0, 36, 18, 1],
  [-50, 27, 36, 18, 1],
  [12, -28, 26, 20, 0],
  [44, -14, 26, 20, 0],
  [14, 8, 26, 20, 0],
  [46, 26, 26, 20, 0],
];
// [evidence, testimony, start]: the last link is the contradiction.
const LINKS = [
  [3, 0, 0.36],
  [5, 1, 0.44],
  [6, 2, 0.52],
];

function card(c, k, pal, i, p, fade, glow) {
  const [x, y, w, h, says] = CARDS[i];
  const at = 0.03 + i * 0.045;
  const q = k.ease(k.seg(p, at, at + 0.14));
  if (!q) return;
  const side = says ? -1 : 1;
  const hot = Math.min(1, glow);
  c.save();
  c.globalAlpha = fade * k.seg(p, at, at + 0.03);
  c.translate(x + side * (1 - q) * 46, y + (1 - q) * 64);
  c.rotate(side * (1 - q) * 0.7 + (k.rand(i + 7) - 0.5) * 0.12);
  k.halo(c, 0, 0, w * 0.8, pal.a, hot * 0.3);
  k.rrect(c, -w / 2, -h / 2, w, h, 1.5);
  c.fillStyle = k.col(k.mix(pal.night, pal.ink, 0.12));
  c.fill();
  c.lineWidth = 0.6;
  c.strokeStyle = k.col(k.mix(pal.bronze, pal.a, hot), 0.55 + hot * 0.45);
  c.stroke();
  c.fillStyle = k.col(pal.ink, 0.3);
  if (says) {
    c.beginPath();
    c.arc(-w / 2 + 6, 1, 3.4, 0, 7);
    c.fill();
    for (let j = 0; j < 3; j++) c.fillRect(-w / 2 + 12, -3.6 + j * 4, 10 + k.rand(i * 5 + j) * 10, 1.4);
  } else {
    c.fillRect(-w / 2 + 3, h / 2 - 4.5, (w - 6) * (0.45 + k.rand(i) * 0.45), 1.4);
    c.fillStyle = k.col(pal.moon, 0.16);
    c.fillRect(-w / 2 + 3, -h / 2 + 4.5, w - 6, h - 11);
    c.strokeStyle = k.col(pal.moon, 0.45);
    c.beginPath();
    c.arc(-1, -h / 2 + 9, 2.4, 0, 7);
    c.moveTo(0.8, -h / 2 + 10.8);
    c.lineTo(3, -h / 2 + 13);
    c.stroke();
  }
  c.fillStyle = k.col(hot > 0.3 ? pal.a : pal.bronze);
  c.beginPath();
  c.arc(0, -h / 2 + 2.5, 1.3, 0, 7);
  c.fill();
  c.restore();
}

export default {
  period: 7200,
  still: 0.72,
  draw(c, k, p, v, pal) {
    const fade = 1 - k.seg(p, 0.93, 1);
    const found = k.ease(k.seg(p, 0.62, 0.68));
    const lit = k.ease(k.seg(p, 0.8, 0.87));
    const pulse = found * (1 - lit) * (0.5 + 0.5 * Math.sin(p * 88));
    k.backdrop(c, v, pal, 0, 0, 120, 0.1 + lit * 0.14);
    c.globalAlpha = fade;

    k.rrect(c, -76, -45, 152, 90, 3);
    c.fillStyle = k.col(k.mix(pal.night, pal.bronze, 0.09));
    c.fill();
    c.lineWidth = 0.8;
    c.strokeStyle = k.col(k.mix(pal.bronze, pal.a, lit), 0.35 + lit * 0.45);
    c.stroke();
    c.fillStyle = k.col(pal.ink, 0.05);
    for (let i = 0; i < 40; i++) c.fillRect(-74 + k.rand(i) * 148, -43 + k.rand(i + 50) * 86, 0.7, 0.7);

    // The round clock: it runs until the contradiction is found.
    const left = 1 - 0.85 * k.seg(p, 0.06, 0.62);
    c.lineWidth = 1.2;
    c.strokeStyle = k.col(pal.bronze, 0.5);
    c.beginPath();
    c.arc(64, -34, 6, 0, 7);
    c.stroke();
    c.strokeStyle = k.col(pal.a, 0.9);
    c.beginPath();
    c.arc(64, -34, 6, -Math.PI / 2, -Math.PI / 2 + left * Math.PI * 2);
    c.stroke();
    c.fillStyle = k.col(pal.bronze, 0.8);
    c.fillRect(62.8, -43, 2.4, 2);

    for (let i = 0; i < CARDS.length; i++) {
      card(c, k, pal, i, p, fade, (i === 2 || i === 6 ? pulse + found * 0.4 : 0) + lit * 0.6);
    }

    LINKS.forEach(([from, to, start], i) => {
      const q = k.ease(k.seg(p, start, start + 0.08));
      if (!q) return;
      const ax = CARDS[from][0];
      const ay = CARDS[from][1] - CARDS[from][3] / 2 + 2.5;
      const bx = CARDS[to][0];
      const by = CARDS[to][1] - CARDS[to][3] / 2 + 2.5;
      const mx = (ax + bx) / 2;
      const my = (ay + by) / 2 + 10;
      const odd = i === LINKS.length - 1;
      const hot = Math.max(lit, odd ? pulse : 0);
      c.beginPath();
      c.moveTo(ax, ay);
      for (let s = 1; s <= 16; s++) {
        const t = (s / 16) * q;
        const u = 1 - t;
        c.lineTo(u * u * ax + 2 * u * t * mx + t * t * bx, u * u * ay + 2 * u * t * my + t * t * by);
      }
      c.lineWidth = 0.8 + hot * 0.8;
      c.strokeStyle = k.col(pal.a, 0.5 + hot * 0.5);
      c.stroke();
      if (!odd || !found) return;
      // The contradiction: a "not equal" seal pinned on the thread.
      const x = 0.25 * ax + 0.5 * mx + 0.25 * bx;
      const y = 0.25 * ay + 0.5 * my + 0.25 * by;
      const r = 5.4 * k.ease(k.seg(p, 0.62, 0.7));
      k.halo(c, x, y, 18, pal.a, 0.3 * found + pulse * 0.3);
      c.fillStyle = k.col(pal.night);
      c.beginPath();
      c.arc(x, y, r, 0, 7);
      c.fill();
      c.lineWidth = 0.9;
      c.strokeStyle = k.col(pal.a);
      c.stroke();
      k.line(c, x - r * 0.5, y - r * 0.2, x + r * 0.5, y - r * 0.2);
      k.line(c, x - r * 0.5, y + r * 0.2, x + r * 0.5, y + r * 0.2);
      k.line(c, x + r * 0.3, y - r * 0.6, x - r * 0.3, y + r * 0.6);
    });
  },
};
