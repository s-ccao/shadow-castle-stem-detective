// Prism Lab: moonlight finds its way. Two mirrors turn into line, a prism fans
// the beam into a spectrum, and the lock on the sealed door wakes.
const S = [-64, -32];
const M1 = [-36, 24];
const M2 = [0, -28];
const P = [30, 8];
const F = [34.5, 8];
const SPECTRUM = [
  [255, 96, 96],
  [255, 166, 77],
  [255, 226, 110],
  [124, 226, 140],
  [96, 170, 255],
  [180, 130, 255],
];

function unit(a, b) {
  const x = b[0] - a[0];
  const y = b[1] - a[1];
  const l = Math.hypot(x, y);
  return [x / l, y / l, l];
}

const D0 = unit(S, M1);
const D1 = unit(M1, M2);
const D2 = unit(M2, P);
const turn = (d, a) => [d[0] * Math.cos(a) - d[1] * Math.sin(a), d[0] * Math.sin(a) + d[1] * Math.cos(a)];

function beam(c, k, rgb, [x, y], d, len) {
  if (len <= 0) return;
  const x2 = x + d[0] * len;
  const y2 = y + d[1] * len;
  c.lineWidth = 3.4;
  c.strokeStyle = k.col(rgb, 0.12);
  k.line(c, x, y, x2, y2);
  c.lineWidth = 0.9;
  c.strokeStyle = k.col(rgb, 0.9);
  k.line(c, x, y, x2, y2);
  k.halo(c, x2, y2, 4.5, rgb, 0.45);
}

// A mirror's face bisects the incoming and outgoing beams.
function mirror(c, k, pal, [x, y], din, dout) {
  let nx = dout[0] - din[0];
  let ny = dout[1] - din[1];
  const l = Math.hypot(nx, ny);
  nx /= l;
  ny /= l;
  const tx = -ny * 7;
  const ty = nx * 7;
  c.lineWidth = 2.4;
  c.strokeStyle = k.col(pal.bronze, 0.9);
  k.line(c, x - tx - nx * 1.3, y - ty - ny * 1.3, x + tx - nx * 1.3, y + ty - ny * 1.3);
  c.lineWidth = 1;
  c.strokeStyle = k.col(pal.moon);
  k.line(c, x - tx, y - ty, x + tx, y + ty);
}

export default {
  period: 7600,
  still: 0.7,
  draw(c, k, p, v, pal) {
    const fade = 1 - k.seg(p, 0.9, 1);
    const fan = k.ease(k.seg(p, 0.42, 0.5)) * fade;
    const lock = k.ease(k.seg(p, 0.5, 0.58)) * fade;
    k.backdrop(c, v, pal, 66, 12, 64, 0.05 + lock * 0.22);

    // The arched window the moonlight enters through.
    k.halo(c, -68, -38, 20, pal.moon, 0.22);
    c.beginPath();
    c.moveTo(-74, -30);
    c.lineTo(-74, -40);
    c.arc(-68, -40, 6, Math.PI, 0);
    c.lineTo(-62, -30);
    c.closePath();
    c.fillStyle = k.col(pal.moon, 0.28);
    c.fill();
    c.lineWidth = 0.8;
    c.strokeStyle = k.col(pal.edge, 0.9);
    c.stroke();
    c.strokeStyle = k.col(pal.night, 0.7);
    k.line(c, -68, -46, -68, -30);
    k.line(c, -74, -37, -62, -37);
    for (let i = 0; i < 12; i++) {
      const y = ((k.rand(i) * 90 + p * 24) % 90) - 45;
      c.fillStyle = k.col(pal.moon, 0.3 * k.bump((y + 45) / 90));
      c.fillRect(-66 + k.rand(i + 30) * 40 + y * 0.3, y, 0.8, 0.8);
    }

    c.lineWidth = 0.6;
    c.strokeStyle = k.col(pal.edge, 0.35);
    k.line(c, v.x0, 42, v.x1, 42);
    for (let x = -72; x < 80; x += 12) k.line(c, x, 42, x - 3, 48);

    // The sealed door and its lock.
    c.beginPath();
    c.moveTo(58, 42);
    c.lineTo(58, -6);
    c.arc(68, -6, 10, Math.PI, 0);
    c.lineTo(78, 42);
    c.closePath();
    c.fillStyle = k.col(k.mix(pal.night, pal.stone, 0.75));
    c.fill();
    c.lineWidth = 0.8;
    c.strokeStyle = k.col(k.mix(pal.edge, pal.a, lock), 0.5 + lock * 0.4);
    c.stroke();
    c.strokeStyle = k.col(pal.a, lock * 0.8);
    k.line(c, 68, -14, 68, 42);
    c.beginPath();
    c.arc(68, 12, 5, 0, 7);
    c.fillStyle = k.col(k.mix(pal.night, pal.a, lock * 0.8));
    c.fill();
    c.lineWidth = 1;
    c.strokeStyle = k.col(k.mix(pal.bronze, pal.a, lock));
    c.stroke();
    c.fillStyle = k.col(pal.night);
    c.fillRect(67.2, 10, 1.6, 4);

    // Stands: a floor pedestal, a ceiling bracket, the prism's plinth.
    c.fillStyle = k.col(pal.bronze, 0.5);
    c.fillRect(-37.5, 26, 3, 16);
    c.fillRect(-41, 40, 10, 2);
    c.fillRect(27.5, 14, 5, 28);
    c.fillRect(24, 13, 12, 1.6);
    c.lineWidth = 1.2;
    c.strokeStyle = k.col(pal.bronze, 0.5);
    k.line(c, 0, -31, 0, -56);

    const d1 = turn(D1, (1 - k.inOut(k.seg(p, 0.12, 0.26))) * 0.75);
    const d2 = turn(D2, (1 - k.inOut(k.seg(p, 0.3, 0.42))) * -0.7);
    mirror(c, k, pal, M1, D0, d1);
    mirror(c, k, pal, M2, D1, d2);
    c.beginPath();
    c.moveTo(30, -1);
    c.lineTo(22, 14);
    c.lineTo(38, 14);
    c.closePath();
    c.fillStyle = k.col(k.mix(pal.moon, pal.a, fan), 0.12 + fan * 0.22);
    c.fill();
    c.lineWidth = 0.8;
    c.strokeStyle = k.col(pal.moon, 0.8);
    c.stroke();

    c.globalCompositeOperation = "lighter";
    c.globalAlpha = fade;
    beam(c, k, pal.moon, S, D0, D0[2] * k.seg(p, 0, 0.08));
    beam(c, k, pal.moon, M1, d1, D1[2] * k.seg(p, 0.08, 0.12));
    if (p > 0.26) beam(c, k, pal.moon, M2, d2, D2[2] * k.seg(p, 0.26, 0.3));
    c.globalAlpha = 1;
    if (fan) {
      k.halo(c, 30, 8, 16, pal.a, fan * 0.35);
      SPECTRUM.forEach((rgb, j) => {
        const x2 = F[0] + (58 - F[0]) * fan;
        const y2 = F[1] + (-1 + j * 4.6 - F[1]) * fan;
        c.lineWidth = 2.6;
        c.strokeStyle = k.col(rgb, 0.14 * fade);
        k.line(c, F[0], F[1], x2, y2);
        c.lineWidth = 0.8;
        c.strokeStyle = k.col(rgb, 0.8 * fade);
        k.line(c, F[0], F[1], x2, y2);
      });
    }
    if (lock) {
      const ring = k.seg(p, 0.5, 0.68);
      k.halo(c, 68, 12, 28, pal.a, lock * 0.45);
      c.lineWidth = 0.8;
      c.strokeStyle = k.col(pal.a, (1 - ring) * lock * 0.9);
      c.beginPath();
      c.arc(68, 12, 5 + ring * 18, 0, 7);
      c.stroke();
      for (let i = 0; i < 8; i++) {
        c.fillStyle = k.col(pal.a, k.bump((p * 3 + k.rand(i)) % 1) * lock * 0.9);
        c.fillRect(59 + k.rand(i + 9) * 18, -2 + k.rand(i + 19) * 30, 0.9, 0.9);
      }
    }
  },
};
