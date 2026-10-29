// The potions' click sequences, each about three seconds, drawn over the page in the
// pointer's light (light.js). potion.js loads this module the first time the pointer
// comes near a bottle and calls one of these with the bottle that was clicked; each
// returns a function that draws a frame and answers whether it is still running.
// Every sequence belongs to its case: the lantern's beam, luminol, refraction,
// echolocation, a rewind, a transmutation circle, a rune ward.
export function createScenes(k) {
  const { TAU, rand, pick, rgba, mix, glowOf, white, ink, moon, ember, arcane, luminolBlue, ultraviolet, spectrum, caseColor, CASES, RUNES, RUNE_FONT } = k;
  const clamp01 = (t) => Math.min(1, Math.max(0, t));
  const phase = (age, start, dur) => clamp01((age - start) / dur);
  const ease = (t) => 1 - (1 - t) ** 3;

  // A line of light: a wide glow, a bright body and a white core.
  function beam(g, pts, color, width, alpha) {
    g.beginPath();
    pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y)));
    g.lineCap = "round";
    g.lineJoin = "round";
    g.strokeStyle = rgba(color, 1);
    g.globalAlpha = alpha * 0.2;
    g.lineWidth = width * 6;
    g.stroke();
    g.globalAlpha = alpha * 0.6;
    g.lineWidth = width * 2.2;
    g.stroke();
    g.strokeStyle = rgba(mix(color, ink, 0.6), 1);
    g.globalAlpha = alpha * 0.95;
    g.lineWidth = width;
    g.stroke();
  }

  // A polyline cut to a length, for beams that travel.
  function cut(pts, cum, len) {
    const out = [pts[0]];
    for (let i = 1; i < pts.length; i += 1) {
      if (cum[i] <= len) {
        out.push(pts[i]);
        continue;
      }
      const f = (len - cum[i - 1]) / (cum[i] - cum[i - 1] || 1);
      out.push([pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * f, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * f]);
      break;
    }
    return out;
  }

  // ---------- Evidence Rush: luminol ----------
  // The potion erupts and spatters the wall; ultraviolet sweeps across, every stain it
  // passes answers in luminol blue, and a hidden fingerprint develops behind it.
  function makeSplat(d, now) {
    const dir = Math.atan2(d.vy, d.vx);
    const r = d.r * (1.1 + Math.hypot(d.vx, d.vy) * 0.9);
    const n = 9 + Math.floor(rand(0, 6));
    return {
      x: d.x,
      y: d.land,
      dir,
      r,
      stretch: rand(1.35, 1.9),
      t: now,
      litAt: 0,
      spikes: Array.from({ length: n }, (_, i) => {
        const a = (i / n) * TAU + rand(-0.2, 0.2);
        return { a, len: r * rand(0.25, 0.75) * (1 + 0.9 * Math.max(0, Math.cos(a))), w: rand(0.09, 0.16) };
      }),
      sats: Array.from({ length: 1 + Math.floor(rand(0, 3)) }, (_, i) => ({ d: r * (2.4 + i * 1.2 + rand(0, 0.7)), a: rand(-0.18, 0.18), r: r * rand(0.14, 0.3) })),
    };
  }

  function drawSplat(g, s, now, sy, sweepX, fade, red) {
    if (!s.litAt && sweepX >= s.x) s.litAt = now;
    const lit = s.litAt ? Math.min(1, (now - s.litAt) / 260) : 0;
    const grow = Math.min(1, (now - s.t) / 110);
    const pulse = lit ? 0.82 + 0.18 * Math.sin(now * 0.011 + s.x * 0.05) : 1;
    g.save();
    g.translate(s.x, s.y - sy);
    g.rotate(s.dir);
    g.globalAlpha = (0.3 + 0.45 * lit) * fade * pulse;
    g.drawImage(glowOf(lit > 0.5 ? luminolBlue : red), -s.r * 3.4, -s.r * 3.4, s.r * 6.8, s.r * 6.8);
    g.globalAlpha = (0.8 + 0.2 * lit) * fade * pulse;
    g.fillStyle = rgba(mix(red, luminolBlue, Math.round(lit * 4) / 4), 1);
    g.beginPath();
    g.ellipse(0, 0, s.r * s.stretch * grow, s.r * grow, 0, 0, TAU);
    g.fill();
    g.beginPath();
    for (const spike of s.spikes) {
      // Spines leave the rim of the stretched body.
      const rim = (a) => [Math.cos(a) * s.r * s.stretch * 0.92, Math.sin(a) * s.r * 0.92];
      const [ax, ay] = rim(spike.a - spike.w);
      const [bx, by] = rim(spike.a + spike.w);
      const [cx, cy] = rim(spike.a);
      const reach = 1 + (spike.len / s.r) * grow;
      g.moveTo(ax, ay);
      g.lineTo(cx * reach, cy * reach);
      g.lineTo(bx, by);
      g.closePath();
    }
    g.fill();
    for (const sat of s.sats) {
      g.beginPath();
      g.arc(Math.cos(sat.a) * sat.d * grow, Math.sin(sat.a) * sat.d * grow, sat.r, 0, TAU);
      g.fill();
    }
    g.restore();
  }

  function luminol(b) {
    const t0 = performance.now();
    const red = b.color;
    const mouth = [b.x, b.y - b.h / 2];
    const floor = b.y + b.h / 2;
    const drops = Array.from({ length: 40 }, (_, i) => {
      const big = i < 6;
      const a = -Math.PI / 2 + rand(-1.15, 1.15);
      const v = big ? rand(0.3, 0.5) : rand(0.34, 0.85);
      return { x: mouth[0] + rand(-3, 3), y: mouth[1], vx: Math.cos(a) * v, vy: Math.sin(a) * v, r: big ? rand(5.5, 8) : rand(2.2, 5), land: floor + rand(-55, 80), t: t0 + rand(0, 180), done: false };
    });
    const splats = [];
    // The hidden print: one spiral ridge, broken into ridge endings, inside an egg.
    const size = 220 * Math.max(0.85, b.s);
    const ridges = [];
    const spacing = size * 0.032;
    const egg = (x, y) => (x / (size * 0.36)) ** 2 + ((y - size * 0.02) / (size * (y < 0 ? 0.5 : 0.42))) ** 2 <= 1;
    let run = [];
    let gapUntil = 0;
    let nextGap = rand(0.9, 2.6);
    const flush = () => {
      if (run.length > 2) ridges.push(run);
      run = [];
    };
    for (let th = 0.6; th < 13 * TAU; th += 0.045) {
      const r = spacing * (th / TAU) + 2;
      // Pressed, not drawn: the whorl leans and its ridges waver.
      const x = Math.cos(th) * r * 0.82 + Math.sin(th * 2.1 + r * 0.05) * 1.6;
      const y = Math.sin(th) * r * 1.08 + Math.cos(th * 1.7) * 1.4 + r * 0.06;
      if (th < gapUntil || !egg(x, y)) {
        flush();
        continue;
      }
      run.push([x, y, 0.55 + 0.45 * Math.sin(th * 0.7 + r * 0.03) ** 2]);
      if (th > nextGap) {
        flush();
        gapUntil = th + rand(0.08, 0.22);
        nextGap = gapUntil + rand(0.7, 2.8);
      }
    }
    flush();
    const pc = [b.x - b.dir * size * 0.15, floor - size * 0.2];
    const left = pc[0] - 240;
    const right = pc[0] + 240;
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3400) return false;
      const fade = 1 - phase(age, 2600, 800);
      g.globalCompositeOperation = "lighter";
      g.lineCap = "round";
      g.lineJoin = "round";
      // The eruption: a white-hot flash, then a crimson bloom and ring at the mouth.
      if (age < 520) {
        const kk = age / 520;
        if (age < 200) {
          const hot = 1 - age / 200;
          g.globalAlpha = hot * hot;
          const rw = 26 + age * 0.35;
          g.drawImage(white, mouth[0] - rw, mouth[1] - sy - rw, rw * 2, rw * 2);
        }
        g.globalAlpha = (1 - kk) ** 2;
        const r = 40 + kk * 170;
        g.drawImage(glowOf(red), mouth[0] - r, mouth[1] - sy - r, r * 2, r * 2);
        g.strokeStyle = rgba(red, 1);
        g.lineWidth = 2.4 * (1 - kk) + 0.5;
        g.beginPath();
        g.arc(mouth[0], mouth[1] - sy, 10 + kk * 96, 0, TAU);
        g.stroke();
      }
      // Drops in flight, streaked by their speed, spattering where they land.
      for (const d of drops) {
        if (d.done || now < d.t) continue;
        d.vy += 0.0016 * dt;
        d.x += d.vx * dt;
        d.y += d.vy * dt;
        if (d.vy > 0 && d.y >= d.land) {
          d.done = true;
          splats.push(makeSplat(d, now));
          continue;
        }
        const tx = d.x - d.vx * 26;
        const ty = d.y - sy - d.vy * 26;
        const trail = g.createLinearGradient(tx, ty, d.x, d.y - sy);
        trail.addColorStop(0, rgba(red, 0));
        trail.addColorStop(1, rgba(red, 0.95));
        g.globalAlpha = 0.5;
        g.drawImage(glowOf(red), d.x - d.r * 3, d.y - sy - d.r * 3, d.r * 6, d.r * 6);
        g.globalAlpha = 1;
        g.strokeStyle = trail;
        g.lineWidth = d.r * 1.8;
        g.beginPath();
        g.moveTo(tx, ty);
        g.lineTo(d.x, d.y - sy);
        g.stroke();
        g.fillStyle = rgba(mix(red, ink, 0.25), 1);
        g.beginPath();
        g.arc(d.x, d.y - sy, d.r, 0, TAU);
        g.fill();
        g.fillStyle = rgba(ink, 0.9);
        g.beginPath();
        g.arc(d.x - d.r * 0.35, d.y - sy - d.r * 0.35, d.r * 0.3, 0, TAU);
        g.fill();
      }
      // Ultraviolet sweeps across; stains and the print answer behind it.
      const sweep = phase(age, 650, 1100);
      const sx = left + (right - left) * sweep;
      for (const sp of splats) drawSplat(g, sp, now, sy, age > 650 ? sx : -1e9, fade, red);
      if (age > 650) {
        const top = pc[1] - sy - size * 0.8;
        if (sweep < 1) {
          const band = g.createLinearGradient(sx - 70, 0, sx + 16, 0);
          band.addColorStop(0, rgba(ultraviolet, 0));
          band.addColorStop(0.78, rgba(ultraviolet, 0.32));
          band.addColorStop(1, rgba(ultraviolet, 0));
          g.globalAlpha = 1;
          g.fillStyle = band;
          g.fillRect(sx - 70, top, 86, size * 1.6);
          const line = g.createLinearGradient(0, top, 0, top + size * 1.6);
          line.addColorStop(0, rgba(ultraviolet, 0));
          line.addColorStop(0.5, rgba(mix(ultraviolet, ink, 0.4), 0.9));
          line.addColorStop(1, rgba(ultraviolet, 0));
          g.fillStyle = line;
          g.fillRect(sx + 11, top, 2, size * 1.6);
        }
        g.save();
        g.beginPath();
        g.rect(left - 20, top, sx - left + 20, size * 1.6);
        g.clip();
        const pulse = 0.85 + 0.15 * Math.sin(age * 0.012);
        g.globalAlpha = 0.16 * fade * pulse;
        g.strokeStyle = rgba(luminolBlue, 1);
        g.lineWidth = 7;
        g.beginPath();
        for (const pts of ridges) pts.forEach(([x, y], i) => (i ? g.lineTo(pc[0] + x, pc[1] - sy + y) : g.moveTo(pc[0] + x, pc[1] - sy + y)));
        g.stroke();
        g.strokeStyle = rgba(mix(luminolBlue, ink, 0.5), 1);
        g.lineWidth = 1.7;
        for (const pts of ridges) {
          g.globalAlpha = 0.95 * fade * pulse * pts[Math.floor(pts.length / 2)][2];
          g.beginPath();
          pts.forEach(([x, y], i) => (i ? g.lineTo(pc[0] + x, pc[1] - sy + y) : g.moveTo(pc[0] + x, pc[1] - sy + y)));
          g.stroke();
        }
        g.restore();
      }
      return true;
    };
  }

  // ---------- Shadow Castle: the lantern ----------
  // The potion catches fire at the mouth and becomes a detective's lantern. Its beam
  // sweeps the dark in shafts of light, lighting the dust it passes through and pooling
  // where it lands, and the wall's hidden evidence develops wherever it falls. Then the
  // flame gutters out in a curl of smoke.
  function lantern(b) {
    const t0 = performance.now();
    const gold = b.color;
    const hot = mix(gold, ink, 0.55);
    const S = Math.max(0.85, b.s);
    const mouth = [b.x, b.y - b.h / 2];
    const vx = window.innerWidth / 2 - mouth[0];
    const vy = window.innerHeight / 2 - (mouth[1] - window.scrollY);
    const centre = Math.hypot(vx, vy) > 120 ? Math.atan2(vy, vx) : -Math.PI / 2;
    const from = centre - b.dir * 1.1;
    const across = b.dir * 2.2;
    const len = 540;
    const shafts = Array.from({ length: 9 }, (_, i) => ({ off: (i - 4) * 0.058 + rand(-0.018, 0.018), w: rand(0.01, 0.026), reach: rand(0.65, 1), ph: rand(0, TAU), sp: rand(0.0015, 0.004) }));
    // Dust hangs in the air across the whole sweep; the beam lights whatever it crosses.
    const motes = Array.from({ length: 380 }, () => {
      const a = from + across * rand(-0.15, 1.15);
      const d = rand(26, len * 0.9);
      return { x: Math.cos(a) * d, y: Math.sin(a) * d, tw: rand(0, TAU), r: rand(0.6, 2.1), glint: Math.random() < 0.12, ph: rand(0, TAU) };
    });
    const embers = [];
    const smoke = [];
    let nextReveal = 0;
    const wedge = (g, x, y, a, spread, r) => {
      g.beginPath();
      g.moveTo(x, y);
      g.arc(x, y, r, a - spread, a + spread);
      g.closePath();
      g.fill();
    };
    const drop = (g, x, y, w, h, lean) => {
      const tx = x + lean;
      g.beginPath();
      g.moveTo(x - w, y);
      g.bezierCurveTo(x - w * 1.15, y - h * 0.38, tx - w * 0.4, y - h * 0.72, tx, y - h);
      g.bezierCurveTo(tx + w * 0.4, y - h * 0.72, x + w * 1.15, y - h * 0.38, x + w, y);
      g.quadraticCurveTo(x, y + w * 0.9, x - w, y);
      g.closePath();
      g.fill();
    };
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3600) return false;
      const fade = 1 - phase(age, 2500, 800);
      const mx = mouth[0];
      const my = mouth[1] - sy;
      g.globalCompositeOperation = "lighter";
      // Ignition: a flash and a ring of light.
      if (age < 420) {
        const kk = age / 420;
        g.globalAlpha = (1 - kk) ** 2;
        const r = 30 + 120 * kk;
        g.drawImage(white, mx - r * 0.7, my - r * 0.7, r * 1.4, r * 1.4);
        g.strokeStyle = rgba(hot, 1);
        g.lineWidth = 2;
        g.beginPath();
        g.arc(mx, my, 20 + 170 * ease(kk), 0, TAU);
        g.stroke();
      }
      // The beam.
      const on = phase(age, 160, 320) * fade;
      if (on > 0) {
        const ang = from + across * ease(phase(age, 280, 2050));
        const narrow = 1 - 0.45 * phase(age, 2200, 600);
        const cone = g.createRadialGradient(mx, my, 4, mx, my, len);
        cone.addColorStop(0, rgba(hot, 0.85));
        cone.addColorStop(0.18, rgba(hot, 0.42));
        cone.addColorStop(0.6, rgba(gold, 0.16));
        cone.addColorStop(1, rgba(gold, 0));
        g.fillStyle = cone;
        for (const [spread, alpha] of [[0.4, 0.35], [0.26, 0.6], [0.11, 0.8]]) {
          g.globalAlpha = on * alpha;
          wedge(g, mx, my, ang, spread * narrow, len);
        }
        // Shafts of light inside it, drifting and breathing.
        for (const s of shafts) {
          g.globalAlpha = on * (0.3 + 0.25 * (1 + Math.sin(now * s.sp * 2.6 + s.ph)));
          wedge(g, mx, my, ang + (s.off + Math.sin(now * s.sp + s.ph) * 0.015) * narrow, s.w, len * s.reach);
        }
        // Its edges, crisp as a lantern shutter's.
        g.lineWidth = 1.1;
        for (const e of [-1, 1]) {
          const a = ang + e * 0.26 * narrow;
          const ex = mx + Math.cos(a) * len * 0.8;
          const ey = my + Math.sin(a) * len * 0.8;
          const edge = g.createLinearGradient(mx, my, ex, ey);
          edge.addColorStop(0, rgba(hot, 0.75));
          edge.addColorStop(1, rgba(gold, 0));
          g.strokeStyle = edge;
          g.globalAlpha = on;
          g.beginPath();
          g.moveTo(mx, my);
          g.lineTo(ex, ey);
          g.stroke();
        }
        // A pool of light where it lands.
        const pd = len * 0.58;
        const half = pd * Math.tan(0.26 * narrow);
        g.save();
        g.translate(mx + Math.cos(ang) * pd, my + Math.sin(ang) * pd);
        g.rotate(ang);
        g.scale(0.6, 1);
        g.globalAlpha = on * 0.55;
        g.drawImage(glowOf(gold), -half, -half, half * 2, half * 2);
        g.restore();
        // The dust the beam passes through.
        const spread = 0.3 * narrow;
        for (const m of motes) {
          const d = Math.hypot(m.x, m.y);
          let off = Math.atan2(m.y, m.x) - ang;
          off -= Math.round(off / TAU) * TAU;
          const lit = 1 - Math.abs(off) / spread;
          if (lit <= 0) continue;
          const tw = 0.5 + 0.5 * Math.sin(now * 0.007 + m.tw);
          const x = mx + m.x + Math.sin(now * 0.0011 + m.ph) * 4;
          const y = my + m.y + Math.cos(now * 0.0009 + m.ph) * 4;
          g.globalAlpha = on * tw * (1 - d / len) * Math.min(1, lit * 2.2);
          g.drawImage(white, x - m.r * 2, y - m.r * 2, m.r * 4, m.r * 4);
          if (m.glint && tw > 0.8) {
            const s = m.r * 12 * (tw - 0.8);
            g.strokeStyle = rgba(ink, 1);
            g.lineWidth = 0.8;
            g.beginPath();
            g.moveTo(x - s, y);
            g.lineTo(x + s, y);
            g.moveTo(x, y - s);
            g.lineTo(x, y + s);
            g.stroke();
          }
        }
        // Where the beam falls, the lantern (lantern.js) develops the wall's evidence.
        if (now > nextReveal && age < 2300) {
          nextReveal = now + 110;
          for (const d of [140, 260, 380, 490]) {
            document.dispatchEvent(new CustomEvent("sc:reveal", { detail: { x: mx + Math.cos(ang) * d, y: my + sy + Math.sin(ang) * d, r: 160 } }));
          }
        }
      }
      // The flame: a teardrop licked sideways, blue at the root and white at the heart.
      const burn = phase(age, 0, 140) * (1 - phase(age, 2350, 550));
      if (burn > 0) {
        const fl = 0.84 + 0.1 * Math.sin(now * 0.023) + 0.06 * Math.sin(now * 0.057 + 1.3);
        const H = 62 * S * fl * (0.4 + 0.6 * burn);
        const W = 10.5 * S * (0.5 + 0.5 * burn);
        const lean = (Math.sin(now * 0.009) * 0.6 + Math.sin(now * 0.021 + 2) * 0.4) * W * 0.7;
        const base = my + 3 * S;
        const gr = 64 * S;
        g.globalAlpha = burn * 0.85;
        g.drawImage(glowOf(gold), mx - gr, base - H * 0.45 - gr, gr * 2, gr * 2);
        const outer = g.createLinearGradient(0, base + W, 0, base - H);
        outer.addColorStop(0, rgba(moon, 0.75));
        outer.addColorStop(0.18, rgba(hot, 0.95));
        outer.addColorStop(0.55, rgba(gold, 0.85));
        outer.addColorStop(1, rgba(ember, 0));
        g.fillStyle = outer;
        g.globalAlpha = burn;
        for (const s of [-1, 1]) drop(g, mx + s * W * 0.75, base, W * 0.55, H * (0.5 + 0.08 * Math.sin(now * 0.03 + s)), lean + s * W * 0.9);
        drop(g, mx, base, W, H, lean);
        const core = g.createLinearGradient(0, base, 0, base - H * 0.55);
        core.addColorStop(0, rgba(ink, 1));
        core.addColorStop(0.6, rgba(hot, 0.8));
        core.addColorStop(1, rgba(hot, 0));
        g.fillStyle = core;
        drop(g, mx, base - W * 0.15, W * 0.45, H * 0.55, lean * 0.5);
      }
      // Embers curl up out of the fire, and smoke once it goes out.
      if (age < 2400 && embers.length < 70 && Math.random() < dt / 26) {
        embers.push({ x: mx + rand(-8, 8) * b.s, y: my + sy - 8, vx: rand(-0.03, 0.03), vy: rand(-0.13, -0.06), t: now, life: rand(900, 1700), ph: rand(0, TAU) });
      }
      for (let i = embers.length - 1; i >= 0; i -= 1) {
        const e = embers[i];
        const life = (now - e.t) / e.life;
        if (life >= 1) {
          embers.splice(i, 1);
          continue;
        }
        e.vx += Math.sin(now * 0.004 + e.ph) * 0.0004 * dt;
        e.x += e.vx * dt;
        e.y += e.vy * dt;
        const r = 2.4 * (1 - life * 0.6);
        g.globalAlpha = (1 - life) * (0.6 + 0.4 * Math.sin(now * 0.03 + e.ph)) * fade;
        g.drawImage(glowOf(ember), e.x - r * 3, e.y - sy - r * 3, r * 6, r * 6);
        g.drawImage(white, e.x - r * 0.6, e.y - sy - r * 0.6, r * 1.2, r * 1.2);
      }
      if (age > 2350 && age < 2750 && Math.random() < dt / 34) {
        smoke.push({ x: mx + rand(-3, 3), y: my + sy - 4, t: now, ph: rand(0, TAU), life: rand(650, 850) });
      }
      for (let i = smoke.length - 1; i >= 0; i -= 1) {
        const p = smoke[i];
        const life = (now - p.t) / p.life;
        if (life >= 1) {
          smoke.splice(i, 1);
          continue;
        }
        const rise = (now - p.t) * 0.07;
        const r = (6 + 22 * life) * S;
        const x = p.x + Math.sin(life * 4 + p.ph) * 10 * life;
        g.globalAlpha = 0.28 * (1 - life) * Math.min(1, life * 6);
        g.drawImage(glowOf(moon), x - r, p.y - rise - sy - r, r * 2, r * 2);
      }
      return true;
    };
  }

  // ---------- Prism Lab: refraction ----------
  // A crystal prism forms above the bottle; a white beam rises into it and leaves as
  // the spectrum, each colour racing off and bouncing from unseen mirrors, until the
  // crystal shatters into glints.
  function prism(b) {
    const t0 = performance.now();
    const mouth = [b.x, b.y - b.h / 2];
    const S = Math.max(0.85, b.s);
    const above = mouth[1] - window.scrollY > 240;
    const c = above ? [b.x, mouth[1] - 76 * S] : [b.x + b.dir * 96 * S, b.y - b.h * 0.15];
    const aim = above ? -Math.PI / 2 : Math.atan2(window.innerHeight / 2 - (c[1] - window.scrollY), window.innerWidth / 2 - c[0]);
    const R = 34 * S;
    const rot0 = rand(-0.3, 0.3);
    const rays = spectrum.map((color, i) => {
      let ang = aim + (i - 3) * 0.17 + rand(-0.04, 0.04);
      const pts = [[0, 0]];
      let x = 0;
      let y = 0;
      for (let hop = 0; hop < 3; hop += 1) {
        const len = hop === 0 ? rand(130, 200) : rand(90, 170);
        x += Math.cos(ang) * len;
        y += Math.sin(ang) * len;
        pts.push([x, y]);
        ang += (Math.random() < 0.5 ? 1 : -1) * rand(0.9, 1.7);
      }
      const cum = [0];
      for (let j = 1; j < pts.length; j += 1) cum.push(cum[j - 1] + Math.hypot(pts[j][0] - pts[j - 1][0], pts[j][1] - pts[j - 1][1]));
      return { color, pts, cum, delay: i * 45 };
    });
    const shards = [];
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3200) return false;
      const fade = 1 - phase(age, 2450, 750);
      const cx = c[0];
      const cy = c[1] - sy;
      const my = mouth[1] - sy;
      g.globalCompositeOperation = "lighter";
      // The white beam rises from the bottle into the crystal.
      if (age < 2400) {
        const rise = ease(phase(age, 0, 300));
        beam(g, [[mouth[0], my], [mouth[0] + (cx - mouth[0]) * rise, my + (cy + R * 0.5 - my) * rise]], ink, 1.6, fade);
      }
      // The crystal: glass, facets, and its own light.
      const form = ease(phase(age, 80, 420)) * (age < 2400 ? 1 : 0);
      if (form > 0) {
        const rot = rot0 + age * 0.0005;
        const tri = [0, 1, 2].map((j) => [cx + Math.cos(rot - Math.PI / 2 + (j * TAU) / 3) * R * form, cy + Math.sin(rot - Math.PI / 2 + (j * TAU) / 3) * R * form]);
        g.globalAlpha = 0.5 * fade;
        g.drawImage(glowOf(mix(b.color, ink, 0.3)), cx - R * 2.4, cy - R * 2.4, R * 4.8, R * 4.8);
        g.globalAlpha = 0.16 * fade;
        g.fillStyle = rgba(moon, 1);
        g.beginPath();
        tri.forEach(([x, y], j) => (j ? g.lineTo(x, y) : g.moveTo(x, y)));
        g.closePath();
        g.fill();
        g.globalAlpha = 0.95 * fade;
        g.strokeStyle = rgba(ink, 1);
        g.lineWidth = 1.6;
        g.stroke();
        g.globalAlpha = 0.4 * fade;
        g.lineWidth = 1;
        g.beginPath();
        for (const [x, y] of tri) {
          g.moveTo(cx, cy);
          g.lineTo(x, y);
        }
        g.stroke();
      }
      // The spectrum, each ray bouncing off mirrors that only show where it strikes.
      for (const ray of rays) {
        const p = phase(age, 400 + ray.delay, 760);
        if (p <= 0) continue;
        const total = ray.cum[ray.cum.length - 1];
        const len = total * ease(p);
        const pts = cut(ray.pts.map(([x, y]) => [cx + x, cy + y]), ray.cum, len);
        beam(g, pts, ray.color, 1.5, fade);
        const [tx, ty] = pts[pts.length - 1];
        if (p < 1) {
          g.globalAlpha = fade;
          g.drawImage(glowOf(ray.color), tx - 14, ty - 14, 28, 28);
          g.drawImage(white, tx - 4, ty - 4, 8, 8);
        }
        for (let j = 1; j < ray.pts.length - 1; j += 1) {
          if (ray.cum[j] > len) break;
          const mxp = cx + ray.pts[j][0];
          const myp = cy + ray.pts[j][1];
          const inA = Math.atan2(ray.pts[j][1] - ray.pts[j - 1][1], ray.pts[j][0] - ray.pts[j - 1][0]);
          const outA = Math.atan2(ray.pts[j + 1][1] - ray.pts[j][1], ray.pts[j + 1][0] - ray.pts[j][0]);
          const mirror = (inA + outA) / 2 + Math.PI / 2;
          g.globalAlpha = 0.85 * fade;
          g.strokeStyle = rgba(ink, 1);
          g.lineWidth = 1.4;
          g.beginPath();
          g.moveTo(mxp - Math.cos(mirror) * 9, myp - Math.sin(mirror) * 9);
          g.lineTo(mxp + Math.cos(mirror) * 9, myp + Math.sin(mirror) * 9);
          g.stroke();
          g.globalAlpha = 0.6 * fade;
          g.drawImage(glowOf(ray.color), mxp - 16, myp - 16, 32, 32);
        }
      }
      // The crystal shatters into glints.
      if (age > 2380 && !shards.length) {
        for (let i = 0; i < 28; i += 1) {
          const a = rand(0, TAU);
          const v = rand(0.08, 0.28);
          shards.push({ x: cx, y: cy + sy, vx: Math.cos(a) * v, vy: Math.sin(a) * v, rot: rand(0, TAU), vr: rand(-0.012, 0.012), color: pick(spectrum), t: now, life: rand(550, 850), size: rand(3, 7) });
        }
      }
      for (const sh of shards) {
        const life = (now - sh.t) / sh.life;
        if (life >= 1) continue;
        sh.x += sh.vx * dt;
        sh.y += sh.vy * dt;
        sh.rot += sh.vr * dt;
        const x = sh.x;
        const y = sh.y - sy;
        g.globalAlpha = 1 - life;
        g.drawImage(glowOf(sh.color), x - sh.size * 2, y - sh.size * 2, sh.size * 4, sh.size * 4);
        g.fillStyle = rgba(mix(sh.color, ink, 0.5), 1);
        g.beginPath();
        for (let j = 0; j < 3; j += 1) {
          const a = sh.rot + (j * TAU) / 3;
          const px = x + Math.cos(a) * sh.size;
          const py = y + Math.sin(a) * sh.size * 0.6;
          if (j) g.lineTo(px, py);
          else g.moveTo(px, py);
        }
        g.closePath();
        g.fill();
      }
      return true;
    };
  }

  // ---------- Echo Corridor: echolocation ----------
  // A ping, then sound waves roll out; whatever the wavefront touches on the page
  // shows its outline for a moment, and each thing pings back.
  function echo(b) {
    const t0 = performance.now();
    const cx0 = b.x;
    const cy0 = b.y;
    const teal = b.color;
    const sy0 = window.scrollY;
    const things = [...document.querySelectorAll("main h1, main h2, main h3, main p, main img, main figure, main .case-card, main .action, main .btn, main dl")]
      .map((el) => el.getBoundingClientRect())
      .filter((r) => r.width > 8 && r.height > 8)
      .map((r) => ({ x: r.left, y: r.top + sy0, w: r.width, h: r.height, pinged: 0 }))
      .map((t) => ({ ...t, d: Math.hypot(t.x + t.w / 2 - cx0, t.y + t.h / 2 - cy0) }))
      .filter((t) => t.d < 600)
      .sort((a, b2) => a.d - b2.d)
      .slice(0, 36);
    const MAXR = 560;
    const pulses = [0, 360, 720, 1080];
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3000) return false;
      const fade = 1 - phase(age, 2400, 600);
      const cx = cx0;
      const cy = cy0 - sy;
      g.globalCompositeOperation = "lighter";
      if (age < 240) {
        const kk = age / 240;
        g.globalAlpha = (1 - kk) ** 2;
        const r = 20 + 70 * kk;
        g.drawImage(white, cx - r, cy - r, r * 2, r * 2);
        g.drawImage(glowOf(teal), cx - r * 2, cy - r * 2, r * 4, r * 4);
      }
      for (const start of pulses) {
        const p = phase(age, start, 1500);
        if (p <= 0 || p >= 1) continue;
        const R = 14 + MAXR * ease(p);
        const strength = (1 - p) ** 1.1 * fade;
        const inner = Math.max(0, R - 50);
        // The wavefront: a bright leading edge with a fading wake.
        const wake = g.createRadialGradient(cx, cy, inner, cx, cy, R);
        wake.addColorStop(0, rgba(teal, 0));
        wake.addColorStop(0.82, rgba(teal, 0.22 * strength));
        wake.addColorStop(1, rgba(mix(teal, ink, 0.5), 0.8 * strength));
        g.globalAlpha = 1;
        g.fillStyle = wake;
        g.beginPath();
        g.arc(cx, cy, R, 0, TAU);
        g.arc(cx, cy, inner, 0, TAU, true);
        g.fill("evenodd");
        // What the sound finds: outlines inside the front.
        g.save();
        g.beginPath();
        g.arc(cx, cy, R + 3, 0, TAU);
        g.arc(cx, cy, Math.max(0, R - 26), 0, TAU, true);
        g.clip("evenodd");
        g.globalAlpha = 0.95 * strength;
        g.strokeStyle = rgba(mix(teal, ink, 0.35), 1);
        g.lineWidth = 1.6;
        for (const t of things) g.strokeRect(t.x + 0.5, t.y - sy + 0.5, t.w, t.h);
        g.restore();
        // The first wave sets each thing pinging back.
        if (start === 0) for (const t of things) if (!t.pinged && R >= t.d) t.pinged = now;
      }
      // Echoes coming back: small rings from the things the sound found.
      for (const t of things) {
        if (!t.pinged) continue;
        const q = (now - t.pinged) / 700;
        if (q < 0 || q > 1) continue;
        const ex = t.x + t.w / 2;
        const ey = t.y + t.h / 2 - sy;
        g.globalAlpha = (1 - q) * 0.8 * fade;
        g.strokeStyle = rgba(teal, 1);
        g.lineWidth = 1.2;
        g.beginPath();
        g.arc(ex, ey, 6 + q * 34, 0, TAU);
        g.stroke();
        g.globalAlpha = (1 - q) * 0.6 * fade;
        g.drawImage(glowOf(teal), ex - 10, ey - 10, 20, 20);
      }
      return true;
    };
  }

  // ---------- Time Echo: the rewind ----------
  // A clock face forms; its hands race backwards, time ripples fold inwards, the
  // bottle's past selves trail behind it and sand streams back up into it. Then
  // everything stops, and lets go.
  function time(b) {
    const t0 = performance.now();
    const col = b.color;
    const R = 122 * Math.max(0.85, b.s);
    const mouth = [b.x, b.y - b.h / 2];
    const numerals = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"];
    const sand = Array.from({ length: 110 }, () => ({ a: rand(0, TAU), d: rand(R * 0.7, R * 2.3), sp: rand(0.75, 1.15), r: rand(0.8, 1.9), vy: 0, y: 0 }));
    const spinAt = (age) => {
      const t = Math.min(age, 2000) / 1000;
      return -(t * t) * 7;
    };
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3400) return false;
      const fade = 1 - phase(age, 2700, 700);
      const cx = b.x;
      const cy = b.y - sy;
      const form = ease(phase(age, 0, 450));
      g.globalCompositeOperation = "lighter";
      // The dial.
      g.globalAlpha = 0.18 * form * fade;
      g.drawImage(glowOf(col), cx - R * 1.5, cy - R * 1.5, R * 3, R * 3);
      g.strokeStyle = rgba(mix(col, ink, 0.3), 1);
      g.globalAlpha = 0.9 * form * fade;
      g.lineWidth = 2;
      g.beginPath();
      g.arc(cx, cy, R * form, 0, TAU);
      g.stroke();
      g.lineWidth = 1;
      g.beginPath();
      g.arc(cx, cy, R * 0.9 * form, 0, TAU);
      for (let j = 0; j < 60; j += 1) {
        const a = (j / 60) * TAU;
        const inner = j % 5 ? 0.86 : 0.8;
        g.moveTo(cx + Math.cos(a) * R * inner * form, cy + Math.sin(a) * R * inner * form);
        g.lineTo(cx + Math.cos(a) * R * 0.9 * form, cy + Math.sin(a) * R * 0.9 * form);
      }
      g.stroke();
      g.fillStyle = rgba(mix(col, ink, 0.45), 1);
      g.font = `600 ${Math.round(12 * Math.max(0.85, b.s))}px Fraunces, Georgia, serif`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      numerals.forEach((n, j) => {
        const a = (j / 12) * TAU - Math.PI / 2;
        g.fillText(n, cx + Math.cos(a) * R * 0.68 * form, cy + Math.sin(a) * R * 0.68 * form);
      });
      // The hands run backwards, faster and faster, and stop dead at two seconds.
      const spin = spinAt(age);
      g.strokeStyle = rgba(ink, 1);
      g.lineCap = "round";
      for (const [turn, len, width] of [[spin * 0.25, 0.42, 3], [spin * 3, 0.66, 1.8]]) {
        const a = turn - Math.PI / 2;
        g.globalAlpha = form * fade;
        g.lineWidth = width;
        g.beginPath();
        g.moveTo(cx, cy);
        g.lineTo(cx + Math.cos(a) * R * len, cy + Math.sin(a) * R * len);
        g.stroke();
      }
      // Time folding inwards: rings that shrink towards the centre.
      if (age > 250 && age < 2000) {
        for (let j = 0; j < 3; j += 1) {
          const p = ((age - 250) / 800 + j / 3) % 1;
          g.globalAlpha = p * 0.55 * fade;
          g.strokeStyle = rgba(col, 1);
          g.lineWidth = 1.5;
          g.beginPath();
          g.arc(cx, cy, R * 1.9 * (1 - p) + 4, 0, TAU);
          g.stroke();
        }
      }
      // Past selves: the bottle's outline, trailing behind in time.
      const ghosts = phase(age, 300, 300) * (1 - phase(age, 2000, 600));
      if (ghosts > 0) {
        for (let j = 1; j <= 4; j += 1) {
          g.save();
          g.translate(b.x - b.dir * j * 11 * b.s, cy + Math.sin(age * 0.004 + j) * 3);
          g.globalAlpha = (0.42 - j * 0.08) * ghosts * fade;
          g.strokeStyle = rgba(col, 1);
          g.lineWidth = 1.5;
          g.stroke(b.outline);
          g.restore();
        }
      }
      // The freeze: a single tick of light when the hands stop.
      if (age > 2000 && age < 2350) {
        const q = (age - 2000) / 350;
        g.globalAlpha = (1 - q) ** 2 * 0.8;
        g.drawImage(white, cx - R * 0.5, cy - R * 0.5, R, R);
      }
      // Sand: spiralling back up into the bottle, held when time stops, then falling.
      const mx = mouth[0];
      const myd = mouth[1];
      for (const s of sand) {
        const q = ease(phase(age, 200, 1800 * s.sp));
        const a = s.a + q * 1.6 * b.dir;
        let x = mx + Math.cos(a) * s.d * (1 - q);
        let y = myd + Math.sin(a) * s.d * (1 - q) * 0.8;
        if (age > 2400) {
          const t = age - 2400;
          y += 0.5 * 0.0009 * t * t;
          x += Math.cos(a) * t * 0.02;
        }
        g.globalAlpha = (q < 0.98 ? 0.85 : 0.3) * fade * phase(age, 200, 200);
        g.fillStyle = rgba(mix(col, ink, 0.5), 1);
        g.fillRect(x - s.r / 2, y - sy - s.r / 2, s.r, s.r);
      }
      return true;
    };
  }

  // ---------- Alchemy Shift: the transmutation circle ----------
  // A circle of transmutation draws itself around the bottle; the potion runs through
  // every case's colour, orbs of all of them spiral in, and the circle's nodes burst
  // into elemental sparks.
  function transmute(b) {
    const t0 = performance.now();
    const col = b.color;
    const R = 132 * Math.max(0.85, b.s);
    const glyphs = ["☉", "☽", "☿", "♀", "♂", "♃"];
    const orbs = Array.from({ length: 42 }, (_, i) => ({ a: (i / 42) * TAU, d: R * rand(1.05, 1.75), color: caseColor[CASES[i % CASES.length]], sp: rand(0.8, 1.25), r: rand(2, 4) }));
    const sparks = [];
    b.cycle = t0; // potion.js runs the potion through every colour
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3300) return false;
      const fade = 1 - phase(age, 2600, 700);
      const cx = b.x;
      const cy = b.y - sy;
      const draw = ease(phase(age, 0, 800));
      const turn = age * 0.0006;
      const flare = Math.max(0, 1 - Math.abs(age - 800) / 260);
      g.globalCompositeOperation = "lighter";
      g.globalAlpha = (0.16 + 0.5 * flare) * fade;
      g.drawImage(glowOf(col), cx - R * 1.6, cy - R * 1.6, R * 3.2, R * 3.2);
      g.strokeStyle = rgba(mix(col, ink, 0.3 + 0.4 * flare), 1);
      g.lineWidth = 2;
      g.globalAlpha = 0.95 * fade;
      g.beginPath();
      g.arc(cx, cy, R, -Math.PI / 2, -Math.PI / 2 + draw * TAU);
      g.stroke();
      g.lineWidth = 1;
      g.beginPath();
      g.arc(cx, cy, R * 0.88, Math.PI / 2, Math.PI / 2 - draw * TAU, true);
      g.stroke();
      // Two triangles, turning: the hexagram at the heart of the circle.
      const hex = phase(age, 250, 550);
      if (hex > 0) {
        g.globalAlpha = 0.9 * hex * fade;
        for (const off of [0, Math.PI]) {
          g.beginPath();
          for (let j = 0; j <= 3; j += 1) {
            const a = turn * (off ? -1 : 1) + off - Math.PI / 2 + (j * TAU) / 3;
            const x = cx + Math.cos(a) * R * 0.88;
            const y = cy + Math.sin(a) * R * 0.88;
            if (j) g.lineTo(x, y);
            else g.moveTo(x, y);
          }
          g.stroke();
        }
        g.fillStyle = rgba(mix(col, ink, 0.5), 1);
        g.font = `${Math.round(16 * Math.max(0.85, b.s))}px 'Apple Symbols', 'Segoe UI Symbol', serif`;
        g.textAlign = "center";
        g.textBaseline = "middle";
        glyphs.forEach((glyph, j) => {
          const a = turn - Math.PI / 2 + (j * TAU) / 6;
          const x = cx + Math.cos(a) * R * 1.12;
          const y = cy + Math.sin(a) * R * 1.12;
          g.globalAlpha = hex * fade;
          g.drawImage(glowOf(col), x - 14, y - 14, 28, 28);
          g.fillText(glyph, x, y);
        });
      }
      // Orbs of every case's colour spiral into the bottle.
      for (const o of orbs) {
        const q = phase(age, 700, 1500 * o.sp);
        if (q <= 0 || q >= 1) continue;
        const a = o.a + turn * 4 + q * 3;
        const d = o.d * (1 - ease(q));
        const x = cx + Math.cos(a) * d;
        const y = cy + Math.sin(a) * d;
        const a2 = a - 0.18;
        const d2 = o.d * (1 - ease(Math.max(0, q - 0.06)));
        g.globalAlpha = Math.sin(q * Math.PI) * fade;
        g.strokeStyle = rgba(o.color, 1);
        g.lineWidth = o.r;
        g.beginPath();
        g.moveTo(cx + Math.cos(a2) * d2, cy + Math.sin(a2) * d2);
        g.lineTo(x, y);
        g.stroke();
        g.drawImage(glowOf(o.color), x - o.r * 3, y - o.r * 3, o.r * 6, o.r * 6);
        g.drawImage(white, x - o.r * 0.7, y - o.r * 0.7, o.r * 1.4, o.r * 1.4);
      }
      // The nodes burst: sparks curve out from each of the six.
      if (age > 1700 && !sparks.length) {
        for (let j = 0; j < 6; j += 1) {
          const a = turn - Math.PI / 2 + (j * TAU) / 6;
          for (let n = 0; n < 6; n += 1) {
            const v = rand(0.12, 0.3);
            const out = a + rand(-0.5, 0.5);
            sparks.push({ x: b.x + Math.cos(a) * R * 1.12, y: b.y + Math.sin(a) * R * 1.12, vx: Math.cos(out) * v, vy: Math.sin(out) * v, curl: rand(-0.0006, 0.0006), color: caseColor[pick(CASES)], t: now, life: rand(600, 1100) });
          }
        }
      }
      for (const s of sparks) {
        const life = (now - s.t) / s.life;
        if (life >= 1) continue;
        const vx = s.vx;
        s.vx += -s.vy * s.curl * dt;
        s.vy += vx * s.curl * dt;
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        g.globalAlpha = (1 - life) * fade;
        g.drawImage(glowOf(s.color), s.x - 8, s.y - sy - 8, 16, 16);
        g.drawImage(white, s.x - 2, s.y - sy - 2, 4, 4);
      }
      return true;
    };
  }

  // ---------- Rune Defense: the ward ----------
  // Two rings of runes wheel around the bottle and raise a dome of hexagonal light,
  // brightest at its rim. Red bolts crackle in from the dark and each breaks on the dome
  // in a ripple and a spray of sparks. Then the runes close in and seal the ward into
  // the bottle.
  function ward(b) {
    const t0 = performance.now();
    const col = b.color;
    const hot = mix(col, ink, 0.5);
    const foe = caseColor["evidence-rush"];
    const fillCol = rgba(col, 1);
    const edgeCol = rgba(hot, 1);
    const sparkCols = [rgba(hot, 1), rgba(mix(foe, ink, 0.45), 1)];
    const S = Math.max(0.85, b.s);
    const R = 142 * S;
    const cell = 19 * S;
    const cells = [];
    for (let q = -10; q <= 10; q += 1) {
      for (let r = -10; r <= 10; r += 1) {
        const x = cell * Math.sqrt(3) * (q + r / 2);
        const y = cell * 1.5 * r;
        const d = Math.hypot(x, y);
        if (d <= R - cell * 0.55) cells.push({ x, y, d, ph: rand(0, TAU) });
      }
    }
    const rings = [
      { r: R * 1.16, n: 20, dir: 1 },
      { r: R * 0.62, n: 12, dir: -1 },
    ].map((ring) => ({ ...ring, glyphs: Array.from({ length: ring.n }, () => pick(RUNES)) }));
    const attacks = Array.from({ length: 11 }, (_, i) => ({ a: rand(0, TAU), t: 880 + i * 105 + rand(0, 70), from: rand(340, 470), done: false }));
    const impacts = [];
    const sparks = [];
    let sealedAt = 0;
    const hexPath = (g, x, y, r) => {
      g.moveTo(x + r * Math.cos(Math.PI / 6), y + r * Math.sin(Math.PI / 6));
      for (let j = 1; j <= 6; j += 1) g.lineTo(x + r * Math.cos(Math.PI / 6 + (j * TAU) / 6), y + r * Math.sin(Math.PI / 6 + (j * TAU) / 6));
    };
    return (g, now, dt, sy) => {
      const age = now - t0;
      if (age > 3400) return false;
      const seal = ease(phase(age, 2350, 520));
      const shrink = 1 - seal;
      const fade = 1 - phase(age, 2750, 500);
      const form = ease(phase(age, 0, 520));
      const cx = b.x;
      const cy = b.y - sy;
      g.globalCompositeOperation = "lighter";
      // The dome glows at its rim, like a bubble seen head-on.
      const rise = phase(age, 300, 500) * fade;
      const domeR = R * shrink;
      if (rise > 0 && domeR > 4) {
        const dome = g.createRadialGradient(cx, cy, domeR * 0.55, cx, cy, domeR);
        dome.addColorStop(0, rgba(col, 0));
        dome.addColorStop(0.8, rgba(col, 0.08));
        dome.addColorStop(1, rgba(hot, 0.3));
        g.fillStyle = dome;
        g.globalAlpha = rise;
        g.beginPath();
        g.arc(cx, cy, domeR, 0, TAU);
        g.fill();
        g.strokeStyle = edgeCol;
        g.lineWidth = 7;
        g.globalAlpha = rise * 0.16;
        g.stroke();
        g.lineWidth = 1.6;
        g.globalAlpha = rise * 0.85;
        g.stroke();
      }
      // The cells: edges lit by the wave that raises them and by every hit's ripple.
      g.lineWidth = 1.1;
      g.fillStyle = fillCol;
      g.strokeStyle = edgeCol;
      for (const c of cells) {
        const at = 300 + (c.d / R) * 480;
        const on = phase(age, at, 200) * fade;
        if (on <= 0 || shrink <= 0.02) continue;
        const fres = (c.d / R) ** 2;
        const wave = Math.exp(-(((age - at - 100) / 110) ** 2));
        let ripple = 0;
        for (const im of impacts) {
          const t = now - im.t;
          if (t > 650) continue;
          const di = Math.hypot(c.x - im.x, c.y - im.y);
          ripple += Math.exp(-(((di - t * 0.42) / 16) ** 2)) * (1 - t / 650);
          if (di < cell * 1.2) ripple += Math.max(0, 1 - t / 260);
        }
        ripple = Math.min(1.2, ripple);
        const shimmer = 0.5 + 0.5 * Math.sin(now * 0.004 + c.ph);
        g.beginPath();
        hexPath(g, cx + c.x * shrink, cy + c.y * shrink, cell * 0.9 * shrink);
        g.globalAlpha = on * Math.min(1, 0.03 + 0.07 * fres + 0.3 * wave + 0.45 * ripple);
        g.fill();
        g.globalAlpha = on * Math.min(1, 0.1 + 0.4 * fres + 0.15 * shimmer * fres + 0.9 * wave + 0.9 * ripple);
        g.stroke();
      }
      // The runes wheel in opposite directions, then spin up and close in.
      g.font = `${Math.round(15 * S)}px ${RUNE_FONT}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = rgba(mix(col, ink, 0.45), 1);
      for (const ring of rings) {
        const rr = ring.r * form * (1 - seal * 0.92);
        const spin = ring.dir * (age * 0.0008 + seal * 2.4);
        g.globalAlpha = 0.45 * form * fade;
        g.beginPath();
        g.arc(cx, cy, rr, 0, TAU);
        g.stroke();
        ring.glyphs.forEach((glyph, j) => {
          const a = spin + (j / ring.n) * TAU;
          const x = cx + Math.cos(a) * rr;
          const y = cy + Math.sin(a) * rr;
          const pulse = 0.65 + 0.35 * Math.sin(now * 0.006 + j);
          g.globalAlpha = form * fade * pulse * 0.45;
          g.drawImage(glowOf(col), x - 11 * S, y - 11 * S, 22 * S, 22 * S);
          g.globalAlpha = form * fade * pulse;
          g.fillText(glyph, x, y);
        });
      }
      // The attack: red bolts crackling in from the dark.
      for (const at of attacks) {
        if (at.done || age < at.t) continue;
        const p = phase(age, at.t, 300);
        const head = at.from - (at.from - R) * p ** 1.3;
        const tail = Math.min(at.from, head + 90);
        const ca = Math.cos(at.a);
        const sa = Math.sin(at.a);
        const pts = [];
        for (let i = 0; i <= 6; i += 1) {
          const dd = tail + (head - tail) * (i / 6);
          const j = i === 0 || i === 6 ? 0 : rand(-7, 7);
          pts.push([cx + ca * dd - sa * j, cy + sa * dd + ca * j]);
        }
        beam(g, pts, foe, 1.3, fade);
        g.globalAlpha = fade;
        g.drawImage(glowOf(foe), pts[6][0] - 14, pts[6][1] - 14, 28, 28);
        if (p >= 1) {
          at.done = true;
          const ix = ca * R;
          const iy = sa * R;
          impacts.push({ x: ix, y: iy, t: now });
          for (let n = 0; n < 16; n += 1) {
            const a = at.a + rand(-1.25, 1.25);
            const v = rand(0.12, 0.36);
            sparks.push({ x: b.x + ix, y: b.y + iy, vx: Math.cos(a) * v, vy: Math.sin(a) * v, t: now, life: rand(320, 650), col: sparkCols[n % 2] });
          }
        }
      }
      // Each hit flares and lights an arc of the rim.
      g.lineWidth = 2.5;
      g.strokeStyle = edgeCol;
      for (const im of impacts) {
        const t = (now - im.t) / 380;
        if (t >= 1) continue;
        const x = cx + im.x * shrink;
        const y = cy + im.y * shrink;
        const r = 26 + 40 * t;
        g.globalAlpha = (1 - t) ** 2 * fade;
        g.drawImage(glowOf(foe), x - r, y - r, r * 2, r * 2);
        g.drawImage(white, x - r * 0.4, y - r * 0.4, r * 0.8, r * 0.8);
        const a = Math.atan2(im.y, im.x);
        g.globalAlpha = (1 - t) * fade;
        g.beginPath();
        g.arc(cx, cy, R * shrink, a - 0.15 - t * 0.5, a + 0.15 + t * 0.5);
        g.stroke();
      }
      for (let i = sparks.length - 1; i >= 0; i -= 1) {
        const s = sparks[i];
        const life = (now - s.t) / s.life;
        if (life >= 1) {
          sparks.splice(i, 1);
          continue;
        }
        s.vy += 0.0004 * dt;
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        g.globalAlpha = (1 - life) * fade;
        g.strokeStyle = s.col;
        g.lineWidth = 1.3;
        g.beginPath();
        g.moveTo(s.x - s.vx * 14, s.y - sy - s.vy * 14);
        g.lineTo(s.x, s.y - sy);
        g.stroke();
      }
      // Sealed: the ward goes into the bottle in one last flash.
      if (seal >= 1 && !sealedAt) {
        sealedAt = now;
        b.flash = now;
      }
      if (sealedAt) {
        const t = (now - sealedAt) / 450;
        if (t < 1) {
          const r = 30 + 120 * ease(t);
          g.globalAlpha = (1 - t) ** 2;
          g.drawImage(glowOf(col), cx - r, cy - r, r * 2, r * 2);
          g.strokeStyle = edgeCol;
          g.lineWidth = 2;
          g.beginPath();
          g.arc(cx, cy, r * 0.8, 0, TAU);
          g.stroke();
        }
      }
      return true;
    };
  }

  return { lantern, luminol, prism, echo, time, transmute, ward };
}
