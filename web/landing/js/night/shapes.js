import { tokenRgb } from "../loop.js";
import { TAU, rgba, rng } from "./kit.js";

// The subjects the moon dust gathers into (dust.js). Each is drawn on a 400 px
// canvas in the site's colour tokens; the dust samples the drawing, so strokes come
// out dense and fills sparse, and every mote keeps the colour it landed on.
export const S = 400;

export function palette() {
  const tone = (name) => {
    const rgb = tokenRgb(name);
    return (a) => rgba(rgb, a);
  };
  return {
    moon: tone("--color-moon"),
    moon2: tone("--color-moon-2"),
    ink: tone("--color-ink"),
    accent: tone("--color-accent"),
    bronze: tone("--color-bronze"),
    ember: tone("--color-ember"),
    arcane: tone("--color-arcane"),
    red: tone("--game-evidence-rush"),
    alchemy: tone("--game-alchemy-shift"),
    echo: tone("--game-echo-corridor"),
    time: tone("--game-time-echo"),
    rune: tone("--game-rune-defense"),
    games: ["shadow-castle", "evidence-rush", "prism-lab", "echo-corridor", "time-echo", "alchemy-shift", "rune-defense"].map((slug) => tone(`--game-${slug}`)),
    spectrum: [1, 2, 3, 4, 5, 6, 7].map((n) => tone(`--color-spectrum-${n}`)),
  };
}

function line(g, x1, y1, x2, y2) {
  g.beginPath();
  g.moveTo(x1, y1);
  g.lineTo(x2, y2);
  g.stroke();
}

function circle(g, x, y, r, fill) {
  g.beginPath();
  g.arc(x, y, r, 0, TAU);
  if (fill) g.fill();
  else g.stroke();
}

export const PAINT = {
  moon(g, C) {
    g.save();
    g.beginPath();
    g.rect(0, 0, S, S);
    g.arc(250, 160, 106, 0, TAU, true);
    g.clip("evenodd");
    g.fillStyle = C.moon(0.42);
    circle(g, 200, 196, 120, true);
    g.strokeStyle = C.moon(1);
    g.lineWidth = 7;
    circle(g, 200, 196, 120);
    g.restore();
    g.strokeStyle = C.moon2(0.25);
    g.lineWidth = 3;
    circle(g, 200, 196, 168);
    g.fillStyle = C.moon(1);
    for (const [x, y, r] of [[60, 70, 4], [330, 330, 3], [350, 60, 5], [40, 300, 3], [300, 380, 2.5], [90, 360, 3.5], [372, 200, 3]]) circle(g, x, y, r, true);
  },
  castle(g, C) {
    const body = new Path2D();
    body.rect(72, 232, 256, 88);
    body.rect(52, 150, 52, 170);
    body.rect(296, 170, 52, 150);
    body.rect(150, 122, 100, 198);
    for (let x = 150; x < 250; x += 22) body.rect(x, 108, 12, 14);
    body.moveTo(46, 150);
    body.lineTo(78, 92);
    body.lineTo(110, 150);
    body.moveTo(290, 170);
    body.lineTo(322, 116);
    body.lineTo(354, 170);
    body.moveTo(184, 108);
    body.lineTo(200, 48);
    body.lineTo(216, 108);
    g.fillStyle = C.moon2(0.2);
    g.fill(body);
    g.strokeStyle = C.moon(0.95);
    g.lineWidth = 4.5;
    g.stroke(body);
    g.fillStyle = C.ember(1);
    for (const [x, y, w, h] of [[168, 160, 11, 18], [221, 160, 11, 18], [194, 204, 12, 20], [72, 192, 11, 15], [316, 206, 11, 15], [110, 262, 9, 13], [282, 262, 9, 13]]) g.fillRect(x, y, w, h);
    g.strokeStyle = C.ember(1);
    g.lineWidth = 4;
    g.beginPath();
    g.moveTo(180, 320);
    g.lineTo(180, 290);
    g.arc(200, 290, 20, Math.PI, 0);
    g.lineTo(220, 320);
    g.stroke();
    g.fillStyle = C.moon(0.5);
    circle(g, 336, 66, 26, true);
    g.strokeStyle = C.moon(1);
    g.lineWidth = 4;
    circle(g, 336, 66, 26);
    g.strokeStyle = C.moon2(0.6);
    g.lineWidth = 3;
    line(g, 16, 322, 384, 322);
  },
  magnifier(g, C) {
    g.fillStyle = C.moon(0.1);
    circle(g, 168, 168, 96, true);
    g.strokeStyle = C.accent(1);
    g.lineWidth = 15;
    circle(g, 168, 168, 108);
    g.strokeStyle = C.bronze(0.9);
    g.lineWidth = 3;
    circle(g, 168, 168, 92);
    g.strokeStyle = C.moon(0.9);
    g.lineWidth = 6;
    g.beginPath();
    g.arc(168, 168, 72, 3.6, 4.6);
    g.stroke();
    g.lineCap = "round";
    g.strokeStyle = C.bronze(1);
    g.lineWidth = 30;
    line(g, 252, 252, 356, 356);
    g.strokeStyle = C.accent(1);
    g.lineWidth = 40;
    line(g, 244, 244, 262, 262);
    g.fillStyle = C.moon(0.6);
    g.font = "700 128px Fraunces, Georgia, serif";
    g.textAlign = "center";
    g.textBaseline = "middle";
    g.fillText("?", 168, 176);
  },
  web(g, C) {
    const pins = [[78, 92], [200, 58], [324, 100], [112, 222], [250, 192], [350, 256], [150, 334], [292, 330]];
    const links = [[0, 1], [1, 2], [0, 3], [1, 4], [2, 4], [3, 4], [4, 5], [3, 6], [4, 7], [5, 7], [6, 7], [2, 5]];
    g.strokeStyle = C.red(1);
    g.lineWidth = 3.5;
    for (const [a, b] of links) {
      const [x1, y1] = pins[a];
      const [x2, y2] = pins[b];
      g.beginPath();
      g.moveTo(x1, y1);
      g.quadraticCurveTo((x1 + x2) / 2, Math.max(y1, y2) + 16, x2, y2);
      g.stroke();
    }
    g.strokeStyle = C.ink(0.75);
    g.lineWidth = 3;
    for (const [x, y] of [pins[0], pins[2], pins[6], pins[5]]) {
      g.strokeRect(x - 30, y + 14, 60, 42);
      line(g, x - 20, y + 28, x + 20, y + 28);
      line(g, x - 20, y + 40, x + 8, y + 40);
    }
    g.fillStyle = C.accent(1);
    for (const [x, y] of pins) circle(g, x, y, 10, true);
  },
  flask(g, C) {
    const left = Math.atan2(-92.4, -22);
    const right = Math.atan2(-92.4, 22);
    g.save();
    g.beginPath();
    g.arc(200, 255, 92, 0, TAU);
    g.clip();
    g.fillStyle = C.alchemy(0.5);
    g.fillRect(100, 262, 200, 120);
    g.strokeStyle = C.alchemy(1);
    g.lineWidth = 4;
    line(g, 100, 262, 300, 262);
    g.restore();
    g.strokeStyle = C.moon(0.95);
    g.lineWidth = 7;
    g.beginPath();
    g.moveTo(178, 70);
    g.lineTo(178, 162.6);
    g.arc(200, 255, 95, left, right, true);
    g.lineTo(222, 70);
    g.stroke();
    g.lineWidth = 10;
    line(g, 164, 70, 236, 70);
    g.strokeStyle = C.alchemy(1);
    g.lineWidth = 3;
    for (const [x, y, r] of [[200, 302, 10], [168, 322, 6], [234, 290, 7], [200, 214, 6], [195, 140, 5], [205, 104, 4]]) circle(g, x, y, r);
    g.strokeStyle = C.arcane(0.7);
    for (const dx of [-14, 8, 26]) {
      g.beginPath();
      g.moveTo(200 + dx, 58);
      g.bezierCurveTo(186 + dx, 36, 214 + dx, 24, 198 + dx, 6);
      g.stroke();
    }
  },
  gears(g, C) {
    const gear = (cx, cy, r, teeth) => {
      const path = new Path2D();
      const step = TAU / teeth;
      for (let i = 0; i < teeth; i += 1) {
        const a = i * step;
        [[a, r], [a + step * 0.12, r + 18], [a + step * 0.42, r + 18], [a + step * 0.54, r]].forEach(([ang, rad], k) => {
          const x = cx + Math.cos(ang) * rad;
          const y = cy + Math.sin(ang) * rad;
          if (i === 0 && k === 0) path.moveTo(x, y);
          else path.lineTo(x, y);
        });
      }
      path.closePath();
      g.fillStyle = C.bronze(0.16);
      g.fill(path);
      g.strokeStyle = C.bronze(1);
      g.lineWidth = 6;
      g.stroke(path);
      g.strokeStyle = C.accent(1);
      circle(g, cx, cy, r * 0.28);
      for (let k = 0; k < 5; k += 1) {
        const ang = (k / 5) * TAU + 0.3;
        line(g, cx + Math.cos(ang) * r * 0.28, cy + Math.sin(ang) * r * 0.28, cx + Math.cos(ang) * r * 0.8, cy + Math.sin(ang) * r * 0.8);
      }
    };
    gear(160, 228, 96, 14);
    gear(304, 122, 56, 9);
    gear(314, 302, 34, 7);
  },
  // Seven case doors, one per game, in each game's colour.
  doors(g, C) {
    [196, 180, 164, 146, 164, 180, 196].forEach((top, k) => {
      const x = 28 + k * 50;
      const path = new Path2D();
      path.moveTo(x, 306);
      path.lineTo(x, top + 20);
      path.arc(x + 20, top + 20, 20, Math.PI, 0);
      path.lineTo(x + 40, 306);
      g.fillStyle = C.games[k](0.2);
      g.fill(path);
      g.strokeStyle = C.games[k](1);
      g.lineWidth = 5;
      g.stroke(path);
      g.fillStyle = C.games[k](1);
      circle(g, x + 20, 262, 4.5, true);
    });
    g.strokeStyle = C.moon(0.55);
    g.lineWidth = 3;
    line(g, 14, 312, 386, 312);
    g.fillStyle = C.moon(0.55);
    circle(g, 200, 74, 24, true);
    g.strokeStyle = C.moon(1);
    circle(g, 200, 74, 24);
  },
  prism(g, C) {
    g.fillStyle = C.moon(0.12);
    g.strokeStyle = C.moon(1);
    g.lineWidth = 8;
    g.beginPath();
    g.moveTo(200, 92);
    g.lineTo(292, 258);
    g.lineTo(108, 258);
    g.closePath();
    g.fill();
    g.stroke();
    g.strokeStyle = C.ink(1);
    g.lineWidth = 7;
    line(g, 6, 222, 152, 184);
    g.lineWidth = 4;
    g.strokeStyle = C.ink(0.55);
    line(g, 152, 184, 246, 176);
    g.lineWidth = 8;
    C.spectrum.forEach((tone, k) => {
      g.strokeStyle = tone(1);
      line(g, 246, 176, 396, 116 + k * 22);
    });
  },
  hourglass(g, C) {
    g.strokeStyle = C.time(0.45);
    g.lineWidth = 3;
    circle(g, 200, 200, 182);
    for (let k = 0; k < 12; k += 1) {
      const a = (k / 12) * TAU;
      line(g, 200 + Math.cos(a) * 168, 200 + Math.sin(a) * 168, 200 + Math.cos(a) * 182, 200 + Math.sin(a) * 182);
    }
    g.strokeStyle = C.bronze(1);
    g.lineWidth = 10;
    line(g, 118, 72, 282, 72);
    line(g, 118, 328, 282, 328);
    g.lineWidth = 6;
    line(g, 132, 72, 132, 328);
    line(g, 268, 72, 268, 328);
    g.strokeStyle = C.moon(1);
    g.beginPath();
    g.moveTo(152, 84);
    g.lineTo(248, 84);
    g.quadraticCurveTo(248, 150, 206, 200);
    g.quadraticCurveTo(248, 250, 248, 316);
    g.lineTo(152, 316);
    g.quadraticCurveTo(152, 250, 194, 200);
    g.quadraticCurveTo(152, 150, 152, 84);
    g.stroke();
    g.fillStyle = C.ember(0.75);
    g.beginPath();
    g.moveTo(168, 124);
    g.lineTo(232, 124);
    g.lineTo(200, 186);
    g.fill();
    g.beginPath();
    g.moveTo(160, 312);
    g.lineTo(240, 312);
    g.lineTo(200, 276);
    g.fill();
    g.strokeStyle = C.ember(1);
    g.lineWidth = 3;
    line(g, 200, 192, 200, 290);
  },
  waves(g, C) {
    g.fillStyle = C.echo(1);
    circle(g, 70, 200, 15, true);
    for (let k = 1; k <= 7; k += 1) {
      g.strokeStyle = C.echo(1 - k * 0.09);
      g.lineWidth = 7 - k * 0.55;
      g.beginPath();
      g.arc(70, 200, k * 44, -0.72, 0.72);
      g.stroke();
    }
    g.strokeStyle = C.moon(0.55);
    g.lineWidth = 4;
    line(g, 372, 40, 372, 360);
    for (let k = 1; k <= 3; k += 1) {
      g.strokeStyle = C.time(0.7 - k * 0.15);
      g.beginPath();
      g.arc(372, 200, k * 38, Math.PI - 0.6, Math.PI + 0.6);
      g.stroke();
    }
  },
  runes(g, C) {
    g.strokeStyle = C.rune(1);
    g.lineWidth = 5;
    circle(g, 200, 200, 172);
    g.lineWidth = 3;
    circle(g, 200, 200, 128);
    for (const turn of [0, Math.PI]) {
      g.beginPath();
      for (let k = 0; k < 3; k += 1) {
        const a = turn - Math.PI / 2 + (k / 3) * TAU;
        g.lineTo(200 + Math.cos(a) * 128, 200 + Math.sin(a) * 128);
      }
      g.closePath();
      g.stroke();
    }
    g.fillStyle = C.rune(1);
    g.font = "34px 'Apple Symbols', 'Segoe UI Historic', 'Noto Sans Runic', serif";
    g.textAlign = "center";
    g.textBaseline = "middle";
    const glyphs = "ᚠᚱᚦᛟᛉᛗᚹᛞ";
    for (let k = 0; k < 8; k += 1) {
      const a = (k / 8) * TAU - Math.PI / 2;
      g.fillText(glyphs[k], 200 + Math.cos(a) * 150, 200 + Math.sin(a) * 150);
    }
    g.fillStyle = C.accent(1);
    circle(g, 200, 200, 18, true);
  },
  fingerprint(g, C) {
    const r = rng(7);
    g.lineWidth = 5;
    for (let k = 0; k < 15; k += 1) {
      const s = 0.12 + k * 0.064;
      const start = r() * TAU;
      const cut = start + 1 + r() * (TAU - 2.4);
      g.strokeStyle = k % 3 ? C.red(1) : C.ember(1);
      g.beginPath();
      g.ellipse(200, 196 + k * 2, 112 * s, 150 * s, 0, start, cut);
      g.stroke();
      g.beginPath();
      g.ellipse(200, 196 + k * 2, 112 * s, 150 * s, 0, cut + 0.3 + r() * 0.4, start + TAU - 0.25);
      g.stroke();
    }
  },
  keyhole(g, C) {
    g.fillStyle = C.bronze(0.14);
    g.strokeStyle = C.accent(1);
    g.lineWidth = 7;
    g.beginPath();
    g.roundRect(128, 40, 144, 320, 72);
    g.fill();
    g.stroke();
    g.fillStyle = C.ember(0.55);
    g.strokeStyle = C.ember(1);
    g.lineWidth = 5;
    g.beginPath();
    g.arc(200, 160, 38, Math.PI * 0.62, Math.PI * 2.38);
    g.lineTo(232, 290);
    g.lineTo(168, 290);
    g.closePath();
    g.fill();
    g.stroke();
    g.strokeStyle = C.ember(0.3);
    g.lineWidth = 3;
    for (let k = -3; k <= 3; k += 1) line(g, 200 + k * 6, 300, 200 + k * 34, 396);
  },
};

// Sample a drawing as `count` motes: positions in formation units (-1..1) and colours.
export function sampleShape(paint, C, count, r) {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = S;
  const g = canvas.getContext("2d", { willReadFrequently: true });
  paint(g, C);
  const data = g.getImageData(0, 0, S, S).data;
  const lit = [];
  for (let p = 0; p < S * S; p += 1) if (data[p * 4 + 3] > 10) lit.push(p);
  const pos = new Float32Array(count * 3);
  const col = new Float32Array(count * 3);
  let n = 0;
  for (let guard = 0; n < count && guard < count * 40 && lit.length; guard += 1) {
    const p = lit[Math.floor(r() * lit.length)];
    if (r() * 255 > data[p * 4 + 3]) continue;
    pos[n * 3] = ((p % S) + r() - 0.5 - S / 2) / (S / 2);
    pos[n * 3 + 1] = (Math.floor(p / S) + r() - 0.5 - S / 2) / (S / 2);
    pos[n * 3 + 2] = (r() - 0.5) * 0.3;
    col[n * 3] = data[p * 4] / 255;
    col[n * 3 + 1] = data[p * 4 + 1] / 255;
    col[n * 3 + 2] = data[p * 4 + 2] / 255;
    n += 1;
  }
  return { pos, col, n };
}
