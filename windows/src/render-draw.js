// Coat patterns, face, simple outfits, simple hats and the main draw call.
// Port of the second half of CatRenderer.swift. Costumes and hoods live in costumes.js.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { P, lerp, R, ovalRect, ellipse, poly, stroked, css, whiteA, grayA } = K;

  // seeded random numbers, same generator as the Swift version so patches look the same
  function makeRng(seed) {
    let s = seed >>> 0;
    return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return (s >>> 8) / 16777216; };
  }

  // ---------- coat patterns ----------
  function drawPattern(gc, look, g, kind) {
    switch (look.pattern) {
      case 'tabby': stripes(gc, look, g, kind); break;
      case 'bicolor': whites(gc, look, g, kind); break;
      case 'tabbyBicolor': stripes(gc, look, g, kind); whites(gc, look, g, kind); break;
      case 'calico': patches(gc, look, g, kind, [look.accent, css(0x2B2A2F)], false); break;
      case 'tortie': patches(gc, look, g, kind, [look.accent, css(0xE09A55)], true); break;
      case 'colorpoint': points(gc, look, g, kind); break;
      default: break;
    }
  }

  function stripes(gc, look, g, kind) {
    gc.stroke(look.accent);
    const k = g.headR / 11.5;
    switch (kind) {
      case 'torso': case 'haunch': {
        const r = g.torsoRect;
        gc.lw(2.4);
        for (let i = -3; i <= 3; i++) {
          const x = r.midX + i * 6.5;
          gc.move(P(x - 1, r.maxY + 3));
          gc.quad(P(x + 1.5, r.minY + r.height * 0.45), P(x + 2, r.maxY - r.height * 0.2));
        }
        gc.strokePath();
        break;
      }
      case 'head': {
        const h = g.head;
        gc.lw(1.5);
        for (const [dx, top] of [[-3, 9.5], [0, 11], [3, 9.5]]) {
          gc.move(P(h.x + dx * k, h.y + 6 * k)); gc.line(P(h.x + dx * 0.8 * k, h.y + top * k));
        }
        gc.strokePath();
        break;
      }
      case 'tail': {
        gc.lw(2.2);
        for (let i = 3; i < g.tail.length - 1; i += 4) {
          const a = g.tail[i - 1], b = g.tail[i + 1], c = g.tail[i];
          const dx = b.x - a.x, dy = b.y - a.y, l = Math.max(0.01, Math.hypot(dx, dy));
          const nx = -dy / l * g.tailW, ny = dx / l * g.tailW;
          gc.move(P(c.x - nx, c.y - ny)); gc.line(P(c.x + nx, c.y + ny));
        }
        gc.strokePath();
        break;
      }
      case 'leg': {
        gc.lw(1.6);
        for (const y of [7, 10.5]) { gc.move(P(-60, y)); gc.line(P(60, y)); }
        gc.strokePath();
        break;
      }
      default: break;
    }
  }

  function whites(gc, look, g, kind) {
    gc.fill(look.white);
    const k = g.headR / 11.5;
    switch (kind) {
      case 'torso': case 'haunch':
        if (g.belly) gc.fillEllipse(g.belly);
        if (g.chest) gc.fillEllipse(g.chest);
        break;
      case 'leg':
        gc.fillRect(R(-80, -20, 160, g.legLowY + 20));
        if (g.chest) gc.fillEllipse(g.chest);
        break;
      case 'head': {
        if (g.backView) return;
        const h = g.head, fx = h.x + 1.4 * k;
        gc.fillEllipse(ovalRect(fx, h.y - 4.6 * k, 7 * k, 4.6 * k));
        gc.addPath(poly([P(fx - 2.6 * k, h.y - 2 * k), P(fx, h.y + 7 * k), P(fx + 2.6 * k, h.y - 2 * k)]));
        gc.fillPath();
        break;
      }
      default: break;
    }
  }

  function patches(gc, look, g, kind, colors, dense) {
    const rng = makeRng(look.seed);
    const k = g.headR / 11.5;
    const side = rng() > 0.5 ? 1 : -1;
    switch (kind) {
      case 'torso': case 'haunch': {
        const r = g.torsoRect;
        const n = dense ? 7 : 4;
        for (let i = 0; i < n; i++) {
          gc.fill(colors[i % colors.length]);
          const c = P(r.minX + r.width * rng(), r.minY + r.height * (0.3 + 0.7 * rng()));
          const rr = (dense ? 4 : 5.5) + rng() * 4;
          gc.fillEllipse(ovalRect(c.x, c.y, rr * 1.2, rr));
        }
        break;
      }
      case 'head': case 'ear': {
        const h = g.head;
        gc.fill(colors[0]);
        gc.fillEllipse(ovalRect(h.x + side * 8 * k, h.y + 8 * k, 9 * k, 9 * k));
        gc.fill(colors[1]);
        gc.fillEllipse(ovalRect(h.x - side * 10 * k, h.y + 12 * k, 7 * k, 7 * k));
        break;
      }
      case 'tail': {
        const n = g.tail.length;
        [Math.floor(n / 3), Math.floor(n * 2 / 3), n - 1].forEach((idx, i) => {
          if (idx >= n) return;
          gc.fill(colors[i % colors.length]);
          const p = g.tail[idx];
          gc.fillEllipse(ovalRect(p.x, p.y, 5, 5));
        });
        break;
      }
      case 'leg':
        if (dense) { gc.fill(colors[0]); gc.fillRect(R(-80, 8, 160, 4)); }
        break;
      default: break;
    }
  }

  function points(gc, look, g, kind) {
    const k = g.headR / 11.5;
    switch (kind) {
      case 'ear': case 'tail':
        gc.fill(look.accent);
        gc.fillRect(R(-200, -200, 400, 400));
        break;
      case 'head': {
        if (g.backView) return;
        const h = g.head, fx = h.x + 1.4 * k;
        gc.fill(css(look.accentHex, 0.35));
        gc.fillEllipse(ovalRect(fx, h.y - 2 * k, 9 * k, 7.5 * k));
        gc.fill(css(look.accentHex, 0.85));
        gc.fillEllipse(ovalRect(fx, h.y - 3.2 * k, 6.6 * k, 5.2 * k));
        break;
      }
      case 'leg':
        gc.fill(look.accent);
        gc.fillRect(R(-80, -20, 160, g.legLowY + 22));
        break;
      default: break;
    }
  }

  // ---------- face ----------
  function drawFace(gc, look, g, ri) {
    const k = g.headR / 11.5, h = g.head;
    const frontal = ri.pose === 'dangle';
    const fx = h.x + (frontal ? 0 : 1.4 * k);
    const lk = (ri.pose === 'climb' || ri.pose === 'slide') ? P(0.5, 0.9) : P(ri.look.x * ri.facing, ri.look.y);
    const masked = look.hat === 'spider';

    // whiskers stick out past the head
    gc.stroke(look.whisker);
    gc.lw(0.6);
    for (const s of [-1, 1]) {
      for (const j of [-1, 0, 1]) {
        gc.move(P(fx + s * 8 * k, h.y - 2.8 * k + j * 1.1 * k));
        gc.line(P(fx + s * 19 * k, h.y - 1.6 * k + j * 2.6 * k));
      }
    }
    gc.strokePath();
    if (masked) return;

    const eyes = [[P(fx - 4.9 * k, h.y + 0.3 * k), look.eyeL, true], [P(fx + 4.9 * k, h.y + 0.3 * k), look.eyeR, false]];
    for (const [p, color, isLeft] of eyes) drawEye(gc, look, p, color, ri.eyes, lk, k, isLeft, frontal);

    if (ri.blush) {
      gc.fill(css(0xF27C8E, 0.4));
      for (const s of [-1, 1]) gc.fillEllipse(ovalRect(fx + s * 7.8 * k, h.y - 3.2 * k, 2.2 * k, 1.4 * k));
    }

    // tiny dash mouth / open mouth
    if (ri.mouthOpen) {
      gc.fill(css(0x3A1F25));
      gc.fillEllipse(ovalRect(fx, h.y - 4.6 * k, 2.1 * k, 1.9 * k));
      gc.fill('white');
      for (const s of [-1, 1]) {
        gc.addPath(poly([P(fx + s * 1.6 * k, h.y - 3.1 * k), P(fx + s * 0.7 * k, h.y - 3.1 * k), P(fx + s * 1.15 * k, h.y - 4.3 * k)]));
        gc.fillPath();
      }
    } else {
      gc.stroke(look.faceLine);
      gc.lw(0.95 * k);
      gc.move(P(fx - 0.9 * k, h.y - 3.4 * k)); gc.line(P(fx + 0.9 * k, h.y - 3.4 * k));
      gc.strokePath();
    }
  }

  function drawEye(gc, look, p, iris, mode, lookDir, k, isLeft, frontal) {
    gc.stroke(look.faceLine);
    if (mode === 'closed') {
      gc.lw(1.1 * k);
      gc.move(P(p.x - 2.9 * k, p.y + 0.3 * k));
      gc.quad(P(p.x + 2.9 * k, p.y + 0.3 * k), P(p.x, p.y - 2.2 * k));
      gc.strokePath();
    } else if (mode === 'happy') {
      gc.lw(1.1 * k);
      gc.move(P(p.x - 2.9 * k, p.y - 0.9 * k));
      gc.quad(P(p.x + 2.9 * k, p.y - 0.9 * k), P(p.x, p.y + 2.8 * k));
      gc.strokePath();
    } else {
      const wide = mode === 'wide';
      const rx = (wide ? 3.8 : 3.3) * k, ry = (wide ? 4.3 : 3.8) * k;
      const white = ovalRect(p.x, p.y, rx, ry);
      gc.fill(css(0xFAFAF7));
      gc.fillEllipse(white);
      gc.save();
      gc.addEllipse(white);
      gc.clip();
      const side = frontal ? 0 : 0.7 * k;
      const pc = P(p.x + lookDir.x * 1.1 * k + side, p.y + lookDir.y * 0.9 * k - 0.3 * k);
      if (!wide) { gc.fill(iris); gc.fillEllipse(ovalRect(pc.x, pc.y, 2.3 * k, 2.5 * k)); }
      const pr = (wide ? 1.4 : 1.7) * k;
      gc.fill(css(0x111111));
      gc.fillEllipse(ovalRect(pc.x, pc.y, pr, pr * 1.08));
      // lids: flat "meh" lid or angry slanted lid, in face colour
      if (mode === 'sleepy' || mode === 'angry') {
        const s = isLeft ? 1 : -1;
        const a = mode === 'angry' ? P(p.x - s * (rx + 1), p.y + ry * 0.95) : P(p.x - rx - 1, p.y + ry * 0.1);
        const b = mode === 'angry' ? P(p.x + s * (rx + 1), p.y - ry * 0.15) : P(p.x + rx + 1, p.y + ry * 0.1);
        gc.fill(look.lid);
        gc.addPath(poly([a, b, P(b.x, p.y + ry + 2), P(a.x, p.y + ry + 2)]));
        gc.fillPath();
      }
      gc.restore();
    }
  }

  // ---------- accessories ----------
  function neckPoint(g) {
    const dx = g.torsoC.x - g.head.x, dy = g.torsoC.y - g.head.y;
    const l = Math.max(0.01, Math.hypot(dx, dy));
    return P(g.head.x + dx / l * g.headR * 0.85, g.head.y + dy / l * g.headR * 0.85);
  }

  function drawOutfit(gc, look, g, ri) {
    const t = ri.t, n = neckPoint(g), r = g.torsoRect, k = g.headR / 11.5;
    switch (look.outfit) {
      case 'cape': {
        const wave = Math.sin(t * 3) * 2;
        gc.fill(css(0xD32F2F));
        const p = new Path2D();
        if (g.backView) {
          p.moveTo(n.x - 5, n.y + 1);
          p.lineTo(n.x + 5, n.y + 1);
          p.lineTo(r.maxX + 3 + wave * 0.5, r.minY + 1);
          p.lineTo(r.minX - 3 + wave * 0.5, r.minY + 1);
        } else {
          // narrow strip over the shoulders and back, the loose end flutters past the rump
          p.moveTo(n.x + 1, n.y + 2.5);
          p.quadraticCurveTo(r.midX, r.maxY + 2.5, r.minX + 2, r.maxY);
          p.lineTo(r.minX - 10 + wave * 1.5, r.maxY - 6 + wave);
          p.lineTo(r.minX - 6 + wave, r.maxY - 10 + wave * 0.5);
          p.lineTo(r.minX + 4, r.maxY - 4);
          p.quadraticCurveTo(r.midX, r.maxY - 2, n.x - 1, n.y - 2.5);
        }
        p.closePath();
        gc.addPath(p);
        gc.fillPath();
        gc.fill(css(0xF5C542));
        gc.fillEllipse(ovalRect(n.x, n.y, 1.8, 1.8));
        break;
      }
      case 'bowtie': {
        if (g.backView) return;
        const c = P(n.x + 1.5 * k, n.y - 1 * k);
        gc.fill(css(0xE53935));
        gc.addPath(poly([c, P(c.x - 4.5 * k, c.y + 2.6 * k), P(c.x - 4.5 * k, c.y - 2.6 * k)]));
        gc.addPath(poly([c, P(c.x + 4.5 * k, c.y + 2.6 * k), P(c.x + 4.5 * k, c.y - 2.6 * k)]));
        gc.fillPath();
        gc.fill(css(0xB71C1C));
        gc.fillEllipse(ovalRect(c.x, c.y, 1.4 * k, 1.4 * k));
        break;
      }
      case 'shield': {
        const c = r.width >= r.height ? P(r.midX - r.width * 0.12, r.maxY - 2.5) : P(r.minX + 4, r.midY + 3);
        for (const [rr, col] of [[6.5, 0xC62828], [5, 0xF5F5F5], [3.6, 0xC62828], [2.5, 0x1E4FA3]]) {
          gc.fill(css(col));
          gc.fillEllipse(ovalRect(c.x, c.y, rr, rr));
        }
        gc.fill('white');
        gc.addPath(K.star(c, 2.2));
        gc.fillPath();
        break;
      }
      case 'reactor': {
        if (g.backView) return;
        const c = g.chest ? P(g.chest.midX, g.chest.midY) : P(n.x + 2, n.y - 4);
        const pulse = 1 + 0.12 * Math.sin(t * 4);
        gc.fill(css(0x7FE7FF, 0.3));
        gc.fillEllipse(ovalRect(c.x, c.y, 4.6 * pulse, 4.6 * pulse));
        gc.fill(css(0x9AA4AE));
        gc.fillEllipse(ovalRect(c.x, c.y, 3.1, 3.1));
        gc.fill(css(0x8DF0FF));
        gc.fillEllipse(ovalRect(c.x, c.y, 2.3, 2.3));
        gc.fill('white');
        gc.fillEllipse(ovalRect(c.x, c.y, 1, 1));
        break;
      }
      default: K.drawCostumeExtras(gc, look, g, ri);
    }
  }

  function drawHat(gc, look, g, ri) {
    const h = g.head, k = g.headR / 11.5;
    const fx = h.x + (ri.pose === 'dangle' ? 0 : 1.4 * k);
    switch (look.hat) {
      case 'shark': {
        const c = P(h.x, h.y + 1.5 * k);
        gc.fill(css(0x5D7C9C));
        gc.addPath(poly([P(c.x - 4 * k, c.y + 13 * k), P(c.x + 2 * k, c.y + 23 * k), P(c.x + 6 * k, c.y + 12.5 * k)]));
        for (const s of [-1, 1]) {
          gc.addPath(poly([P(c.x + s * 14 * k, c.y - 2 * k), P(c.x + s * 22 * k, c.y - 9 * k), P(c.x + s * 12.5 * k, c.y - 9 * k)]));
        }
        gc.fillPath();
        const outer = ellipse(c, 16 * k, 15.5 * k);
        const opening = ellipse(P(fx, h.y - 0.6 * k), 12 * k, 10.4 * k);
        const hood = new Path2D();
        hood.addPath(outer);
        if (!g.backView) hood.addPath(opening);
        gc.addPath(hood);
        gc.fillPath('evenodd');
        if (g.backView) return;
        // white rim and teeth
        const rim = new Path2D();
        rim.addPath(ellipse(P(fx, h.y - 0.6 * k), 13.8 * k, 12.2 * k));
        rim.addPath(opening);
        gc.fill(css(0xF2EEE4));
        gc.addPath(rim);
        gc.fillPath('evenodd');
        for (let i = 0; i < 7; i++) {
          const a = (152 - i * 21) * PI / 180, da = 8 * PI / 180;
          const e = (ang) => P(fx + Math.cos(ang) * 12 * k, h.y - 0.6 * k + Math.sin(ang) * 10.4 * k);
          const tip = P(fx + Math.cos(a) * 8.6 * k, h.y - 0.6 * k + Math.sin(a) * 7.2 * k);
          gc.addPath(poly([e(a - da), tip, e(a + da)]));
        }
        gc.fillPath();
        gc.fill(css(0x1B1B1F));
        for (const s of [-1, 1]) gc.fillEllipse(ovalRect(c.x + s * 7 * k, c.y + 10 * k, 1.6 * k, 1.8 * k));
        gc.fill('white');
        for (const s of [-1, 1]) gc.fillEllipse(ovalRect(c.x + s * 7 * k + 0.5 * k, c.y + 10.6 * k, 0.5 * k, 0.5 * k));
        break;
      }
      case 'frog': {
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 3.2 * k, 80, 80));
        gc.fill(css(0x6DBA4E));
        gc.addPath(ellipse(P(h.x, h.y + 3 * k), 13.5 * k, 11 * k));
        gc.fillPath();
        gc.restore();
        for (const s of [-1, 1]) {
          const e = P(h.x + s * 6.5 * k, h.y + 13.5 * k);
          gc.fill(css(0x6DBA4E));
          gc.fillEllipse(ovalRect(e.x, e.y, 4.6 * k, 4.4 * k));
          if (g.backView) continue;
          gc.fill('white');
          gc.fillEllipse(ovalRect(e.x, e.y + 0.3 * k, 3.4 * k, 3.4 * k));
          gc.fill(css(0x1B1B1F));
          gc.fillEllipse(ovalRect(e.x + 0.4 * k, e.y + 0.3 * k, 1.7 * k, 1.9 * k));
        }
        if (!g.backView) {
          gc.fill(css(0xF48FB1, 0.8));
          for (const s of [-1, 1]) gc.fillEllipse(ovalRect(h.x + s * 9.5 * k, h.y + 5.5 * k, 1.8 * k, 1.1 * k));
        }
        break;
      }
      case 'crown': {
        const y0 = h.y + 7.5 * k;
        const pts = [P(h.x - 6 * k, y0), P(h.x - 6.5 * k, y0 + 6.5 * k), P(h.x - 3 * k, y0 + 3.5 * k), P(h.x, y0 + 8 * k),
          P(h.x + 3 * k, y0 + 3.5 * k), P(h.x + 6.5 * k, y0 + 6.5 * k), P(h.x + 6 * k, y0)];
        gc.fill(css(0xF2C230));
        gc.addPath(poly(pts));
        gc.fillPath();
        gc.fill(css(0xE53935));
        gc.fillEllipse(ovalRect(h.x, y0 + 2 * k, 1.3 * k, 1.3 * k));
        gc.fill(css(0x42A5F5));
        for (const s of [-1, 1]) gc.fillEllipse(ovalRect(h.x + s * 3.8 * k, y0 + 1.6 * k, 0.9 * k, 0.9 * k));
        break;
      }
      case 'party': {
        const base = P(h.x + 1.5 * k, h.y + 8 * k), tip = P(h.x + 5 * k, h.y + 23 * k);
        const cone = poly([P(base.x - 5 * k, base.y), tip, P(base.x + 5 * k, base.y)]);
        gc.save();
        gc.addPath(cone);
        gc.clip();
        gc.fill(css(0xF06292));
        gc.fillRect(R(h.x - 30, h.y - 30, 60, 80));
        gc.fill(css(0xFFEB3B));
        for (let i = 0; i < 4; i++) {
          const y = base.y + i * 4 * k + 1.5 * k;
          gc.fillRect(R(h.x - 30, y, 60, 1.5 * k));
        }
        gc.restore();
        gc.fill(css(0x4FC3F7));
        gc.fillEllipse(ovalRect(tip.x, tip.y, 2.2 * k, 2.2 * k));
        break;
      }
      case 'bow': {
        const c = P(h.x + 7 * k, h.y + 8.5 * k);
        gc.fill(css(0xFF6FA5));
        gc.addPath(poly([c, P(c.x - 4.5 * k, c.y + 3.2 * k), P(c.x - 4 * k, c.y - 2.8 * k)]));
        gc.addPath(poly([c, P(c.x + 4.5 * k, c.y + 3.2 * k), P(c.x + 4 * k, c.y - 2.8 * k)]));
        gc.fillPath();
        gc.fill(css(0xE04887));
        gc.fillEllipse(ovalRect(c.x, c.y, 1.5 * k, 1.5 * k));
        break;
      }
      case 'spider': {
        // fill head and each ear on its own: overlapping shapes in one path would leave a hole
        const shapes = [K.headPath(h, g.headR), ...K.earPaths(h, g.headR, g.earsFlat)];
        gc.fill(css(0xD7262F));
        for (const sh of shapes) { gc.addPath(sh); gc.fillPath(); }
        // web: spokes from a small hub + polygon rings between the spokes
        gc.save();
        gc.addPath(K.headPath(h, g.headR));
        gc.clip();
        gc.stroke(css(0x5C0A12));
        gc.lw(Math.max(0.55, 0.62 * k));
        const c = P(fx, h.y - 1.2 * k);
        const spokes = 8, step = 2 * PI / spokes;
        const ang = Array.from({ length: spokes }, (_, i) => i * step + PI / 8);
        for (const a of ang) {
          gc.move(P(c.x + Math.cos(a) * 1.8 * k, c.y + Math.sin(a) * 1.8 * k));
          gc.line(P(c.x + Math.cos(a) * 26 * k, c.y + Math.sin(a) * 26 * k));
        }
        for (const rr of [4.6, 9.0, 13.5, 18.5]) {
          for (let i = 0; i < spokes; i++) {
            const a0 = ang[i], a1 = ang[(i + 1) % spokes];
            const p0 = P(c.x + Math.cos(a0) * rr * k, c.y + Math.sin(a0) * rr * k);
            const p1 = P(c.x + Math.cos(a1) * rr * k, c.y + Math.sin(a1) * rr * k);
            const am = (a0 + a1) / 2 + (i === spokes - 1 ? PI : 0);
            const sag = P(c.x + Math.cos(am) * rr * 0.86 * k, c.y + Math.sin(am) * rr * 0.86 * k);
            gc.move(p0); gc.quad(p1, sag);
          }
        }
        gc.strokePath();
        gc.restore();
        if (g.backView) return;
        // big almond lenses with a bold black rim
        for (const s of [-1, 1]) {
          const e = P(fx + s * 4.8 * k, h.y + 0.8 * k);
          const inner = P(e.x - s * 2.6 * k, e.y - 2.3 * k), outer = P(e.x + s * 3.9 * k, e.y + 2.9 * k);
          const lens = new Path2D();
          lens.moveTo(inner.x, inner.y);
          lens.quadraticCurveTo(e.x + s * 3.6 * k, e.y - 2.6 * k, outer.x, outer.y);
          lens.quadraticCurveTo(e.x - s * 3.4 * k, e.y + 3.2 * k, inner.x, inner.y);
          lens.closePath();
          gc.stroke(css(0x111111));
          gc.lw(1.5 * k);
          gc.addPath(lens);
          gc.strokePath();
          gc.fill(css(0xFAFAF7));
          gc.addPath(lens);
          gc.fillPath();
        }
        break;
      }
      case 'horns': {
        const gold = css(0xE3B23C);
        gc.stroke(gold);
        for (const s of [-1, 1]) {
          const p = new Path2D();
          p.moveTo(h.x + s * 6.5 * k, h.y + 8 * k);
          p.bezierCurveTo(h.x + s * 15 * k, h.y + 12 * k, h.x + s * 15 * k, h.y + 26 * k, h.x + s * 8 * k, h.y + 29 * k);
          gc.lw(3.4 * k);
          gc.addPath(p);
          gc.strokePath();
        }
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 3.5 * k, 80, 80));
        gc.fill(gold);
        gc.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k));
        gc.fillPath();
        gc.restore();
        if (!g.backView) {
          gc.fill(css(0x2E7D32));
          gc.addPath(poly([P(fx - 2 * k, h.y + 4 * k), P(fx, h.y + 11 * k), P(fx + 2 * k, h.y + 4 * k)]));
          gc.fillPath();
        }
        break;
      }
      case 'winged': {
        gc.fill('white');
        for (const s of [-1, 1]) {
          [11, 9, 7].forEach((len, i) => {
            const base = P(h.x + s * 11 * k, h.y + (6 + i * 2) * k);
            const a = (40 + i * 18) * PI / 180;
            const tip = P(base.x + s * Math.cos(a) * len * k, base.y + Math.sin(a) * len * k);
            gc.addPath(stroked([base, tip], 2.6 * k));
          });
        }
        gc.fillPath();
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 3.5 * k, 80, 80));
        gc.fill(css(0xC9CED6));
        gc.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k));
        gc.fillPath();
        gc.restore();
        gc.fill(css(0x9AA2AD));
        gc.fillRect(R(h.x - 12.6 * k, h.y + 3.5 * k, 25.2 * k, 1.8 * k));
        break;
      }
      default: K.drawHood(gc, look, g, ri, fx, k);
    }
  }

  // ---------- body parts with costume / coat ----------
  function fillGroup(gc, look, g, parts) {
    const cos = K.costumes[look.outfit];
    const covered = (kind) => !!cos && (kind === 'torso' || kind === 'haunch' || kind === 'leg' || (kind === 'tail' && cos.tail));
    for (const p of parts) {
      gc.fill(covered(p.kind) ? css(cos.body) : look.base);
      gc.addPath(p.path);
      gc.fillPath();
    }
    for (const p of parts) {
      gc.save();
      gc.addPath(p.path);
      gc.clip();
      if (covered(p.kind)) K.costumePattern(gc, cos, g, p.kind, look.outfit);
      else drawPattern(gc, look, g, p.kind);
      gc.restore();
    }
  }

  /**
   * Draw one cat. The caller sets up the canvas so that (0,0) is the cat's feet, y points up and one unit
   * is one cat pixel (see overlay.js).
   */
  function draw(gc, look, ri) {
    const g = K.geo(ri);
    gc.save();
    gc.c.lineJoin = 'round';
    gc.c.lineCap = 'round';

    if (g.grounded && ri.pose !== 'climb') {
      gc.fill(grayA(0, 0.15));
      const w = ['loaf', 'sleep', 'scratch', 'stalk', 'run'].includes(ri.pose) ? 22 : 17;
      gc.addPath(ellipse(P(0, 0.4), w, 3));
      gc.fillPath();
    }

    if (ri.pose === 'climb' || ri.pose === 'slide') {
      if (ri.climbSide > 0) gc.scale(-1, 1);
    } else {
      gc.scale(ri.facing, 1);
    }
    if (ri.shake) gc.translate((Math.random() * 2 - 1) * ri.shake, (Math.random() * 2 - 1) * ri.shake * 0.5);
    if (ri.rotation) { gc.translate(0, 16); gc.rotate(ri.rotation); gc.translate(0, -16); }
    if (g.pivot) {
      gc.translate(g.pivot.x, g.pivot.y);
      gc.rotate(ri.swing * ri.facing + Math.sin(ri.t * 2.4) * 0.04);
      gc.translate(-g.pivot.x, -g.pivot.y);
    }

    const hidesEars = K.hatHidesEars(look.hat);

    // claw streaks on the wall above the paws
    if (g.clawTrail > 0.05) {
      gc.stroke(whiteA(0.55 * Math.min(1, g.clawTrail + 0.3)));
      gc.lw(0.7);
      [0.8, 2, 3.2].forEach((x, i) => {
        gc.move(P(x, 50)); gc.line(P(x, 52 + 6 + g.clawTrail * 18 - i));
      });
      gc.strokePath();
    }
    if (g.wallMarks) {
      gc.stroke(whiteA(0.5));
      gc.lw(0.8);
      [18.5, 20, 21.5].forEach((x, i) => { gc.move(P(x, 36 + i)); gc.line(P(x, 58 - i)); });
      gc.strokePath();
    }

    // body
    fillGroup(gc, look, g, g.parts);
    drawOutfit(gc, look, g, ri);

    // head + ears
    const headParts = hidesEars ? [] : K.earPaths(g.head, g.headR, g.earsFlat).map((path) => ({ kind: 'ear', path }));
    headParts.push({ kind: 'head', path: K.headPath(g.head, g.headR) });
    fillGroup(gc, look, g, headParts);

    if (g.scratchMarks) {
      gc.stroke(grayA(0.45, 0.6));
      gc.lw(0.9);
      for (let i = 0; i < 3; i++) { const x = 30 + i * 2.2; gc.move(P(x, 1)); gc.line(P(x + 1.5, 6)); }
      gc.strokePath();
    }

    if (!g.backView) drawFace(gc, look, g, ri);
    drawHat(gc, look, g, ri);
    if (g.overParts.length) fillGroup(gc, look, g, g.overParts);
    gc.restore();
  }

  K.draw = draw;
})(globalThis.K = globalThis.K || {});
