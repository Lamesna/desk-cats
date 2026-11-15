// Drawing helpers and the body shapes for every pose. Port of the first half of CatRenderer.swift.
// Coordinates are y-up with the cat's feet at the origin and the cat facing +x (like the Swift version);
// the caller flips the canvas so y points up.
(function (K) {
  'use strict';
  const PI = Math.PI;

  const P = (x, y) => ({ x, y });
  const lerp = (a, b, t) => a + (b - a) * t;
  const lerpP = (a, b, t) => P(lerp(a.x, b.x, t), lerp(a.y, b.y, t));
  const smooth = (x) => { const u = Math.max(0, Math.min(1, x)); return u * u * (3 - 2 * u); };

  // rectangle with the same handy fields as CGRect
  function R(x, y, w, h) {
    return { x, y, w, h, width: w, height: h, minX: x, minY: y, maxX: x + w, maxY: y + h, midX: x + w / 2, midY: y + h / 2 };
  }
  const ovalRect = (cx, cy, rx, ry) => R(cx - rx, cy - ry, 2 * rx, 2 * ry);

  function ellipse(c, rx, ry, rot) {
    const p = new Path2D();
    p.ellipse(c.x, c.y, rx, ry, rot || 0, 0, 2 * PI);
    return p;
  }

  function poly(pts) {
    const p = new Path2D();
    p.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length; i++) p.lineTo(pts[i].x, pts[i].y);
    p.closePath();
    return p;
  }

  /**
   * Outline of a polyline with round caps and joins, as a fillable/clippable path.
   * Canvas cannot turn a stroke into a path, so it is built as the union of a circle at every point
   * and a rectangle along every segment. All pieces wind the same way, so the nonzero rule unions them.
   */
  function stroked(pts, w) {
    const p = new Path2D();
    const r = w / 2;
    for (const pt of pts) p.arc(pt.x, pt.y, r, 0, 2 * PI, false);
    for (let i = 0; i + 1 < pts.length; i++) {
      const a = pts[i], b = pts[i + 1];
      const dx = b.x - a.x, dy = b.y - a.y;
      const l = Math.hypot(dx, dy);
      if (l < 1e-6) continue;
      const nx = -dy / l * r, ny = dx / l * r;
      // (a+n, a-n, b-n, b+n) winds counter-clockwise for this normal, the same way as the circles
      p.moveTo(a.x + nx, a.y + ny);
      p.lineTo(a.x - nx, a.y - ny);
      p.lineTo(b.x - nx, b.y - ny);
      p.lineTo(b.x + nx, b.y + ny);
      p.closePath();
    }
    return p;
  }

  /** Chain of short segments; angles in degrees, interpolated so the curve is smooth. */
  function chain(base, angles, len) {
    const pts = [base];
    let p = base;
    const sub = 3;
    for (let i = 0; i < angles.length; i++) {
      const a0 = angles[i], a1 = angles[Math.min(i + 1, angles.length - 1)];
      for (let j = 0; j < sub; j++) {
        const a = (a0 + (a1 - a0) * j / sub) * PI / 180;
        p = P(p.x + Math.cos(a) * len / sub, p.y + Math.sin(a) * len / sub);
        pts.push(p);
      }
    }
    return pts;
  }

  // ---- colors ----
  const rgbOf = (hex) => [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255];
  const css = (hex, a) => { const c = rgbOf(hex); return `rgba(${c[0]},${c[1]},${c[2]},${a === undefined ? 1 : a})`; };
  const darker = (hex, f) => { const c = rgbOf(hex); return `rgb(${Math.round(c[0] * f)},${Math.round(c[1] * f)},${Math.round(c[2] * f)})`; };
  const whiteA = (a) => `rgba(255,255,255,${a})`;
  const grayA = (v, a) => { const n = Math.round(v * 255); return `rgba(${n},${n},${n},${a})`; };

  /**
   * Context wrapper that behaves like CGContext: path pieces accumulate until a fill, stroke or clip
   * consumes them. That keeps the ported drawing code close to the Swift original.
   */
  class G {
    constructor(ctx) { this.c = ctx; this.cur = new Path2D(); }
    save() { this.c.save(); }
    restore() { this.c.restore(); }
    translate(x, y) { this.c.translate(x, y); }
    scale(x, y) { this.c.scale(x, y); }
    rotate(a) { this.c.rotate(a); }
    fill(col) { this.c.fillStyle = col; }
    stroke(col) { this.c.strokeStyle = col; }
    lw(w) { this.c.lineWidth = w; }
    addPath(p) { this.cur.addPath(p); }
    fillPath(rule) { this.c.fill(this.cur, rule || 'nonzero'); this.cur = new Path2D(); }
    strokePath() { this.c.stroke(this.cur); this.cur = new Path2D(); }
    clip(rule) { this.c.clip(this.cur, rule || 'nonzero'); this.cur = new Path2D(); }
    clipRect(r) { const p = new Path2D(); p.rect(r.x, r.y, r.w, r.h); this.c.clip(p); }
    move(p) { this.cur.moveTo(p.x, p.y); }
    line(p) { this.cur.lineTo(p.x, p.y); }
    quad(to, ctrl) { this.cur.quadraticCurveTo(ctrl.x, ctrl.y, to.x, to.y); }
    addEllipse(r) { this.cur.ellipse(r.midX, r.midY, r.w / 2, r.h / 2, 0, 0, 2 * PI); }
    fillEllipse(r) { const p = new Path2D(); p.ellipse(r.midX, r.midY, r.w / 2, r.h / 2, 0, 0, 2 * PI); this.c.fill(p); }
    strokeEllipse(r) { const p = new Path2D(); p.ellipse(r.midX, r.midY, r.w / 2, r.h / 2, 0, 0, 2 * PI); this.c.stroke(p); }
    fillRect(r) { this.c.fillRect(r.x, r.y, r.w, r.h); }
    roundRect(x, y, w, h, rx) { const p = new Path2D(); p.roundRect(x, y, w, h, rx); return p; }
  }

  /** The colors of one cat, worked out once from its config. */
  function makeLook(c) {
    const p = K.preset(c.coat);
    const [br, bg, bb] = rgbOf(p.base);
    const lum = Math.max(br, bg, bb) / 255;                       // HSB brightness
    const dark = lum < 0.4 && p.pattern !== 'calico';
    const [e1, e2] = K.eyeRGB(c.eyes);
    const hat = c.hat === 'pig' ? 'pinkdino' : (c.hat || 'none');
    const outfit = c.outfit || 'none';
    return {
      base: css(p.base), baseHex: p.base, accent: css(p.accent), accentHex: p.accent, white: css(0xF8F7F3),
      faceLine: dark ? css(0xBDBCC2) : css(0x3A3535),
      whisker: dark ? darker(p.base, 0.7) : css(0x3A3535, 0.75),
      // lids take the colour of the face
      lid: css(p.pattern === 'calico' ? p.base : p.base),
      pattern: p.pattern,
      eyeL: css(e1), eyeR: css(e2),
      seed: c.seed >>> 0,
      hat: K.hatIds && K.hatIds.has(hat) ? hat : 'none',
      outfit: K.outfitIds && K.outfitIds.has(outfit) ? outfit : 'none',
    };
  }

  // ---- body geometry per pose ----
  function geo(ri) {
    const g = {
      parts: [], head: P(0, 0), headR: 11.5, torsoRect: R(0, 0, 0, 0), torsoC: P(0, 0), belly: null, chest: null,
      tail: [], tailW: 5, earsFlat: false, legLowY: 6, scratchMarks: false, grounded: true, overParts: [],
      backView: false, pivot: null, clawTrail: 0, wallMarks: false,
    };
    const t = ri.t;
    const sin = Math.sin, cos = Math.cos, abs = Math.abs, max = Math.max;

    const leg = (a, b, w) => g.parts.push({ kind: 'leg', path: stroked([a, b], w === undefined ? 5.4 : w) });
    const leg3 = (a, b, c, w) => g.parts.push({ kind: 'leg', path: stroked([a, b, c], w === undefined ? 5.4 : w) });
    const torso = (c, rx, ry, rot) => {
      g.parts.push({ kind: 'torso', path: ellipse(c, rx, ry, rot || 0) });
      g.torsoRect = ovalRect(c.x, c.y, rx, ry);
      g.torsoC = c;
    };
    const torsoPath = (p, rect) => {
      g.parts.push({ kind: 'torso', path: p });
      g.torsoRect = rect;
      g.torsoC = P(rect.midX, rect.midY);
    };
    const tail = (base, angles, len, o) => {
      o = o || {};
      const w = o.w === undefined ? 4.8 : o.w, sway = o.sway === undefined ? 8 : o.sway, speed = o.speed === undefined ? 2.2 : o.speed;
      const a = angles.map((v, i) => v + sin(t * speed + i * 0.7) * sway * (i + 1) / angles.length);
      const pts = chain(base, a, len);
      g.tail = pts;
      g.tailW = w;
      g.parts.unshift({ kind: 'tail', path: stroked(pts, w) });
    };
    const head = (c, r) => { g.head = c; g.headR = r === undefined ? 11.5 : r; };

    // seated bell silhouette (narrow neck, wide base)
    const bell = () => {
      const p = new Path2D();
      p.moveTo(-6, 27);
      p.quadraticCurveTo(-14, 15, -15, 1.5);
      p.quadraticCurveTo(-15, 0, -12, 0);
      p.lineTo(11, 0);
      p.quadraticCurveTo(13, 0, 13, 2);
      p.quadraticCurveTo(12, 13, 6, 27);
      p.quadraticCurveTo(0, 30, -6, 27);
      p.closePath();
      return p;
    };
    const BELL_RECT = R(-15, 0, 28, 30);

    switch (ri.pose) {
      case 'climb': {
        const p = ri.phase, bob = sin(p) * 2.2;
        tail(P(-13, 5 + bob), [258, 264, 270, 276, 282, 288], 4.6, { sway: 14, speed: 2.6 });
        const push = cos(p) * 4.5;
        [-2.5, 2.5].forEach((dx, i) => {
          const lag = i * 2;
          leg3(P(-12 + dx * 0.5, 9 + bob), P(-17 + dx, -1 + bob * 0.5 + push * 0.3 + lag), P(-1.5, 2 + push + lag), 5.6);
        });
        torso(P(-10, 21 + bob), 9, 16.5, -0.14);
        const r1 = sin(p) * 5.5, r2 = sin(p + PI) * 5.5;
        leg(P(-5, 30 + bob), P(1.5, 41 + r2), 5.2);
        g.overParts.push({ kind: 'leg', path: stroked([P(-5, 30 + bob), P(-0.5, 38 + bob), P(2.5, 47 + r1)], 5.4) });
        g.belly = ovalRect(-4, 21 + bob, 4.5, 12);
        g.chest = ovalRect(-5, 31 + bob, 5, 6);
        head(P(-14, 39 + bob), 11);
        g.legLowY = -100;
        g.grounded = false;
        break;
      }
      case 'wallScratch': {
        const s1 = sin(t * 13) * 3.5, s2 = sin(t * 13 + PI) * 3.5;
        tail(P(-8, 3), [190, 160, 130, 110, 100, 95], 4.4, { sway: 8, speed: 3 });
        leg3(P(-1, 10), P(-5, 5), P(-2, 2.4), 5.6);
        leg3(P(3, 10), P(0, 5), P(4, 2.4), 5.6);
        torso(P(5, 22), 8.5, 17, -0.32);
        leg(P(8, 32), P(16.5, 54 + s1), 5);
        g.overParts.push({ kind: 'leg', path: stroked([P(9, 31), P(14, 42), P(17, 50 + s2)], 5.2) });
        g.belly = ovalRect(8, 21, 4, 12);
        g.chest = ovalRect(10, 30, 5, 5);
        head(P(1, 35), 11);
        g.legLowY = 3.5;
        g.wallMarks = true;
        break;
      }
      case 'slide': {
        const v = ri.progress, fl = sin(t * 30) * v * 1.5;
        tail(P(-11, 6), [255, 262, 270, 278, 286, 294], 4.6, { sway: 6 + v * 10, speed: 4 });
        leg3(P(-11, 9), P(-19, 5), P(-1.5, 0 + fl), 5.4);
        leg3(P(-8, 8), P(-15, 1), P(-1.5, -3 - fl), 5.4);
        torso(P(-10, 21), 9, 16.5, -0.1);
        leg(P(-6, 31), P(1, 50 + fl), 5);
        g.overParts.push({ kind: 'leg', path: stroked([P(-5, 30), P(-1, 41), P(2, 53 - fl)], 5.2) });
        g.belly = ovalRect(-4, 21, 4.5, 12);
        head(P(-13, 37), 11);
        g.earsFlat = true;
        g.legLowY = -100;
        g.grounded = false;
        g.clawTrail = v;
        break;
      }
      case 'stand': case 'walk': case 'eat': {
        // lateral-sequence walk
        const amp = ri.pose === 'walk' ? 1 : 0, p = ri.phase, bob = amp * abs(sin(p)) * 0.8;
        tail(P(-17, 17 + bob), [150, 132, 114, 100, 92, 86], 4.6);
        [[-13, 0], [-8, PI], [8, PI / 2], [13, 3 * PI / 2]].forEach(([hx, off]) => {
          const fx = hx + sin(p + off) * 5.5 * amp, lift = max(0, cos(p + off)) * 3 * amp;
          leg(P(hx, 13 + bob), P(fx, 2.4 + lift));
        });
        torso(P(0, 15.5 + bob), 18.5, 8.6);
        g.belly = ovalRect(2, 10.5 + bob, 12, 4.5);
        g.chest = ovalRect(13, 13 + bob, 5.5, 6);
        if (ri.pose === 'eat') head(P(21, 11 + sin(t * 6) * 0.6));
        else head(P(19, 26 + bob * 0.5 + amp * sin(2 * ri.phase) * 0.4));
        break;
      }
      case 'run': {
        // rotary gallop: the spine stretches and gathers
        const p = ri.phase, e = sin(p), air = max(0, e) * 3.5;
        tail(P(-18, 17 + air), [172, 168, 165, 163, 162, 160], 4.6, { sway: 10, speed: 8 });
        for (const off of [0, 0.4]) {
          const ph = p + off;
          leg3(P(-12, 14 + air), P(-12 - 7 * sin(ph), 8 + air * 0.6),
            P(-12 - 12 * sin(ph), 2.4 + max(0, -cos(ph)) * 4 + air * 0.4), 5.4);
        }
        torso(P(0, 15.5 + air), 19 + 3 * e, 8.6 - 1.2 * e, 0.06 * cos(p));
        for (const off of [0, 0.4]) {
          const ph = p - 0.7 + off;
          leg3(P(11, 14 + air), P(11 + 7 * sin(ph), 8 + air * 0.6),
            P(11 + 13 * sin(ph), 2.4 + max(0, cos(ph)) * 4 + air * 0.4), 5.4);
        }
        g.belly = ovalRect(1, 10.5 + air, 12, 4);
        g.chest = ovalRect(13, 13 + air, 5.5, 5.5);
        head(P(21 + 2 * e, 23 + air * 0.6));
        break;
      }
      case 'sit': case 'purr': case 'grumpy': case 'groom': case 'swat': {
        if (ri.pose === 'grumpy') tail(P(-12, 5), [170, 150, 135, 125, 118, 112], 4.6, { sway: 24, speed: 7 });
        else if (ri.pose === 'swat') tail(P(-12, 5), [165, 140, 120, 108, 100, 94], 4.6, { sway: 18, speed: 6 });
        else tail(P(-12, 4), [190, 215, 260, 320, 10, 30], 4.4, { sway: 5, speed: 1.4 });   // curled around the base
        torsoPath(bell(), BELL_RECT);
        if (ri.pose === 'groom') {
          leg(P(6, 16), P(9, 25 + sin(t * 7) * 2.5), 5);
        } else if (ri.pose === 'swat') {
          const sw = sin(t * 11);
          leg(P(7, 17), P(17 + sw * 4, 21 + abs(sw) * 5), 5);
        }
        g.parts.push({ kind: 'leg', path: ellipse(P(3, 1.6), 3.6, 2.3) });
        g.parts.push({ kind: 'leg', path: ellipse(P(9, 1.6), 3.6, 2.3) });
        g.chest = ovalRect(4, 13, 6, 10);
        head(P(1, 31));
        g.earsFlat = ri.pose === 'grumpy';
        g.legLowY = 3.5;
        break;
      }
      case 'loaf': {
        tail(P(-19, 4), [200, 250, 300, 340, 0, 10], 4, { sway: 4, speed: 1.2 });
        const rp = new Path2D(); rp.roundRect(-22, 0, 40, 18, 13);
        torsoPath(rp, R(-22, 0, 40, 18));
        g.chest = ovalRect(12, 7, 6, 6);
        head(P(15, 16));
        break;
      }
      case 'crouch': {
        tail(P(-20, 10), [175, 172, 170, 172, 180, 195], 4.4, { sway: 10, speed: 9 });
        leg(P(-12, 9), P(-14, 2.4));
        leg(P(-8, 9), P(-9, 2.4));
        torso(P(-2, 10), 19, 7.6, -0.1);
        leg(P(10, 5), P(19, 2.4), 5);
        leg(P(13, 5), P(22, 2.4), 5);
        g.belly = ovalRect(0, 5.5, 11, 3.5);
        head(P(17, 12));
        g.earsFlat = false;
        break;
      }
      case 'sleep': {
        const b = sin(t * 1.5) * 0.6;
        tail(P(-17, 8), [260, 300, 340, 5, 15, 20], 4.4, { sway: 1.5, speed: 0.8 });
        torso(P(0, 9.5), 19, 9.5 + b);
        leg(P(13, 3), P(18, 2.4), 4.6);
        head(P(11, 9 + b * 0.5), 10.5);
        break;
      }
      case 'scratch': {
        tail(P(-20, 20), [105, 98, 92, 88, 84, 80], 4.6, { sway: 6, speed: 2 });
        leg(P(-13, 16), P(-14, 2.4));
        leg(P(-8, 15), P(-8, 2.4));
        torso(P(-2, 14), 19, 8.4, -0.24);
        const s1 = sin(t * 14) * 3, s2 = sin(t * 14 + PI) * 3;
        leg(P(9, 9), P(24 + s1, 2.4), 5);
        leg(P(12, 9), P(28 + s2, 3.2), 5);
        head(P(14, 13), 10.5);
        g.scratchMarks = true;
        break;
      }
      case 'fall': {
        tail(P(-17, 19), [100, 95, 90, 90, 90, 85], 4.6, { sway: 14, speed: 9 });
        leg(P(-11, 14), P(-22, 4));
        leg(P(-6, 14), P(-14, 0.5));
        torso(P(0, 17), 18, 9);
        leg(P(8, 14), P(16, 0.5));
        leg(P(12, 14), P(24, 4));
        g.belly = ovalRect(2, 11.5, 12, 5);
        head(P(19, 27));
        g.grounded = false;
        break;
      }
      case 'jump': {
        // keyframes: take-off stretch, tucked flight, front paws reaching down to land
        const k0 = { hind: [P(-28, 6), P(-25, 3)], front: [P(26, 22), P(28, 18)], rx: 23, ry: 7.6, head: P(23, 25), tailA: 185 };
        const k1 = { hind: [P(-7, 7), P(-3, 6)], front: [P(15, 8), P(18, 9)], rx: 19, ry: 9.5, head: P(20, 25), tailA: 165 };
        const k2 = { hind: [P(-24, 12), P(-21, 9)], front: [P(20, 0), P(24, 1.5)], rx: 22, ry: 8.2, head: P(22, 22), tailA: 150 };
        const u = ri.progress;
        const a = u < 0.45 ? k0 : k1, b = u < 0.45 ? k1 : k2;
        const w = u < 0.45 ? smooth(u / 0.45) : smooth((u - 0.45) / 0.55);
        const ta = lerp(a.tailA, b.tailA, w);
        tail(P(-19, 18), [ta, ta - 3, ta - 6, ta - 8, ta - 10, ta - 12], 4.8, { sway: 4, speed: 4 });
        for (let i = 0; i < 2; i++) leg(P(-13 + i * 4, 15), lerpP(a.hind[i], b.hind[i], w));
        torso(P(0, 17), lerp(a.rx, b.rx, w), lerp(a.ry, b.ry, w));
        for (let i = 0; i < 2; i++) leg(P(11 + i * 4, 15), lerpP(a.front[i], b.front[i], w));
        g.belly = ovalRect(2, 12.5, 14, 4);
        head(lerpP(a.head, b.head, w));
        g.grounded = false;
        break;
      }
      case 'hiss': {
        tail(P(-16, 25), [95, 92, 90, 88, 86, 84], 5, { w: 9.5, sway: 3, speed: 12 });
        leg(P(-12, 20), P(-13, 2.4));
        leg(P(-8, 20), P(-8, 2.4));
        torso(P(0, 22), 17, 10.5);
        const sp = new Path2D(), c = P(0, 22);
        for (let i = 0; i <= 18; i++) {
          const a = (15 + i * 150 / 18) * PI / 180, r = i % 2 === 0 ? 1.0 : 1.25;
          const pt = P(c.x + 17 * r * cos(a), c.y + 10.5 * r * sin(a));
          if (i === 0) sp.moveTo(pt.x, pt.y); else sp.lineTo(pt.x, pt.y);
        }
        sp.lineTo(c.x, c.y);
        sp.closePath();
        g.parts.push({ kind: 'torso', path: sp });
        leg(P(8, 20), P(9, 2.4));
        leg(P(12, 20), P(14, 2.4));
        g.belly = ovalRect(1, 15, 12, 5);
        g.chest = ovalRect(12, 19, 5.5, 5.5);
        head(P(19, 23));
        g.earsFlat = true;
        break;
      }
      case 'dangle': {
        tail(P(0, 8), [272, 268, 262, 258, 252, 248], 4.5, { sway: 10, speed: 3 });
        leg(P(-5, 10), P(-6, -3));
        leg(P(5, 10), P(6, -3));
        torso(P(0, 22), 9.5, 15);
        leg(P(-6, 30), P(-10, 19), 5);
        leg(P(6, 30), P(10, 19), 5);
        g.chest = ovalRect(0, 26, 6, 9);
        head(P(0, 42));
        g.grounded = false;
        break;
      }
      case 'hangSide': {
        const sw = sin(t * 3) * 3;
        tail(P(-7, 10), [262, 268, 274, 280, 286, 292], 4.6, { sway: 16, speed: 2.2 });
        leg(P(-8, 12), P(-10 + sw, -1));
        leg(P(-3, 12), P(-1 - sw, 0));
        torso(P(-5, 25), 8.5, 15, -0.12);
        leg(P(-1, 37), P(5, 55), 5);
        g.overParts.push({ kind: 'leg', path: stroked([P(-3, 35), P(1, 46), P(7, 56)], 5.2) });
        g.belly = ovalRect(-2, 24, 4.5, 11);
        g.chest = ovalRect(-3, 34, 5, 5);
        head(P(-9, 40), 11);
        g.legLowY = 4;
        g.grounded = false;
        g.pivot = P(6, 56);
        break;
      }
      case 'hangBack': {
        const sw = sin(t * 3) * 3;
        leg(P(-7, 34), P(-6, 57), 5.2);
        leg(P(7, 34), P(6, 57), 5.2);
        leg(P(-5, 12), P(-6 + sw, -1));
        leg(P(5, 12), P(6 - sw, -1));
        torso(P(0, 24), 10.5, 15);
        head(P(0, 42), 11.5);
        tail(P(0, 9), [268, 272, 276, 270, 262, 256], 4.6, { sway: 16, speed: 2.2 });
        const ti = g.parts.findIndex((p) => p.kind === 'tail');
        if (ti >= 0) g.overParts.push(g.parts.splice(ti, 1)[0]);
        g.legLowY = 4;
        g.backView = true;
        g.grounded = false;
        g.pivot = P(0, 56);
        break;
      }
      case 'roll': {
        tail(P(-12, 10), [200, 230, 260, 290, 320, 350], 4, { sway: 20, speed: 8 });
        for (let i = 0; i < 4; i++) {
          const a = (i * 90 + 45 + sin(t * 12 + i) * 25) * PI / 180;
          leg(P(0, 14), P(cos(a) * 19, 14 + sin(a) * 19), 5);
        }
        torso(P(0, 14), 13, 12);
        head(P(7, 19), 10.5);
        break;
      }
      case 'stalk': {
        const p = ri.phase;
        tail(P(-20, 8), [182, 180, 178, 177, 180, 192], 4.4, { sway: 6, speed: 6 });
        [[-13, 0], [-8, PI], [8, PI / 2], [13, 3 * PI / 2]].forEach(([hx, off]) => {
          const fx = hx + sin(p + off) * 3.5, lift = max(0, cos(p + off)) * 1.5;
          leg(P(hx, 7.5), P(fx, 2.4 + lift), 5.2);
        });
        torso(P(-1, 9), 20, 6.8, 0.03);
        g.belly = ovalRect(1, 5, 13, 3.5);
        g.chest = ovalRect(14, 8, 5, 4);
        head(P(19, 10.5), 10.5);
        g.earsFlat = true;
        break;
      }
      case 'wiggle': {
        const w = sin(t * 16);
        tail(P(-19, 11), [178, 176, 175, 176, 182, 196], 4.4, { sway: 8, speed: 12 });
        leg(P(-12 + w * 1.5, 9.5), P(-14, 2.4));
        leg(P(-7 + w * 1.5, 9.5), P(-8, 2.4));
        torso(P(-2 + w * 1.2, 9), 19.5, 7.2, -0.1 + w * 0.04);
        leg(P(10, 4), P(19, 2.4), 4.8);
        leg(P(13, 4), P(22, 2.4), 4.8);
        g.belly = ovalRect(0, 5, 12, 3.5);
        head(P(18, 8.5), 10.5);
        g.earsFlat = true;
        break;
      }
      case 'traverse': {
        const p = ri.phase, sw = sin(t * 3) * 3;
        tail(P(-7, 10), [262, 268, 274, 280, 286, 292], 4.6, { sway: 16, speed: 2.2 });
        leg(P(-8, 12), P(-10 + sw, -1));
        leg(P(-3, 12), P(-1 - sw, 0));
        torso(P(-5, 25), 8.5, 15, -0.12);
        const a = sin(p) * 6;
        leg(P(-1, 37), P(3 - a, 55 - max(0, -cos(p)) * 3), 5);
        g.overParts.push({ kind: 'leg', path: stroked([P(-3, 35), P(2, 46), P(8 + a, 56 - max(0, cos(p)) * 3)], 5.2) });
        g.belly = ovalRect(-2, 24, 4.5, 11);
        head(P(-9, 40), 11);
        g.legLowY = 4;
        g.grounded = false;
        g.pivot = P(5, 56);
        break;
      }
      default: break;
    }
    return g;
  }

  /** Tall pointed ears with slightly curved sides. */
  function earPaths(h, r, flat) {
    const k = r / 11.5;
    const ear = (s) => {
      const outer = P(h.x + s * 11.5 * k, h.y + 2.5 * k);
      const inner = P(h.x + s * 2.5 * k, h.y + 9 * k);
      const tip = flat ? P(h.x + s * 19 * k, h.y + 9 * k) : P(h.x + s * 9.5 * k, h.y + 21.5 * k);
      const p = new Path2D();
      p.moveTo(outer.x, outer.y);
      p.quadraticCurveTo(lerp(outer.x, tip.x, 0.5) + s * 1.6 * k, lerp(outer.y, tip.y, 0.5), tip.x, tip.y);
      p.quadraticCurveTo(lerp(tip.x, inner.x, 0.5) - s * 0.6 * k, lerp(tip.y, inner.y, 0.5) + 1.5 * k, inner.x, inner.y);
      p.closePath();
      return p;
    };
    return [ear(-1), ear(1)];
  }

  const headPath = (h, r) => ellipse(P(h.x, h.y - 0.5 * r / 11.5), r * 1.17, r * 0.93);

  Object.assign(K, {
    P, lerp, lerpP, smooth, R, ovalRect, ellipse, poly, stroked, chain, css, darker, whiteA, grayA, rgbOf,
    G, makeLook, geo, earPaths, headPath,
  });
})(globalThis.K = globalThis.K || {});
