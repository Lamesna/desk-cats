// Costumes: body colors, patterns and extras (spikes, capes, bows). Port of Costumes.swift, first half.
// Character-like items are generic look-alikes: no letters, logos or names.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { P, lerp, R, ovalRect, ellipse, poly, stroked, css } = K;

  const C = (name, body, o) => Object.assign({ name, body, tail: false }, o || {});
  K.costumes = {
    c_chick: C('Chick', 0xF6D44A, { paws: 0xF0A12F }),
    c_shark: C('Shark', 0x5D7C9C, { belly: 0xF2EEE6, paws: 0xF2EEE6, tail: true }),
    c_vampire: C('Vampire', 0x2A2730, { paws: 0x1C1A20 }),
    c_dino: C('Dinosaur', 0x79A85A, { belly: 0xF1E3A0, paws: 0xF1E3A0, tail: true }),
    c_bunny: C('Bunny', 0xF7F4F0, { paws: 0xFFFFFF, tail: true }),
    c_panda: C('Panda', 0xF4F2EE, { legs: 0x2A2A2E }),
    c_plumber: C('Overalls', 0xD9302C, { paws: 0xF4F2EE, legs: 0x2F5DAE }),
    c_kitty: C('Bow jumpsuit', 0xF7F5F2, { paws: 0xF7F5F2, legs: 0xD7262F }),
    c_bee: C('Bee', 0xF4C430, { stripes: 0x4A3423 }),
    c_wizard: C('Wizard', 0x2C2F55, { legs: 0x2C2F55 }),
    c_frog: C('Froggy', 0x79A85A, { belly: 0xF1EBC4, paws: 0x79A85A }),
    c_cowboy: C('Cowboy', 0x8B5A2B, { belly: 0xF1E7D2, legs: 0xF4F2EE }),
    c_penguin: C('Penguin', 0x2D3756, { belly: 0xF4F2EE, paws: 0xF4F2EE }),
    c_pinkdino: C('Pink dino', 0xF2A9C4, { belly: 0xFBE3EC, paws: 0xFBE3EC, tail: true }),
    c_bear: C('Teddy bear', 0xA7703F, { belly: 0xE8C9A0, paws: 0x7B4F2A }),
    c_ghost: C('Ghost', 0xF6F4EE, { tail: true }),
    c_banana: C('Banana', 0xF6D84B, { paws: 0x6B4A2B }),
    c_merc: C('Mercenary', 0xC62828, { legs: 0x2A2A2E }),
    c_spider: C('Spider', 0xD7262F, { paws: 0xD7262F, legs: 0x1E4FA3 }),
    c_royal: C('Royal robe', 0xB71C1C, { paws: 0xF4F2EE }),
    c_party: C('Party', 0xF48FB1, { paws: 0xFFFFFF, spots: [0xFFEB3B, 0x4FC3F7, 0x81C784] }),
    c_trickster: C('Trickster', 0x2E7D32, { belly: 0xE3B23C, legs: 0x1B1B1F }),
    c_jester: C('Jester', 0x2E2A33, { belly: 0xF2EEE8, paws: 0xF4A7C0 }),
    c_monster: C('Monster', 0x9B7FD1, { belly: 0xD9CCF2, paws: 0x7E62B8, tail: true }),
    c_unicorn: C('Unicorn', 0xF7F3EE, { paws: 0xF2C230, tail: true }),
  };
  K.costumeOrder = ['c_chick', 'c_shark', 'c_vampire', 'c_dino', 'c_bunny', 'c_panda', 'c_plumber', 'c_kitty',
    'c_bee', 'c_wizard', 'c_frog', 'c_cowboy', 'c_penguin', 'c_pinkdino', 'c_bear', 'c_ghost', 'c_banana', 'c_merc',
    'c_spider', 'c_royal', 'c_party', 'c_trickster', 'c_jester', 'c_monster', 'c_unicorn'];

  K.hoodHats = [
    ['chick', 'Chick'], ['jester', 'Black jester'], ['banana', 'Banana'], ['dino', 'Dinosaur'],
    ['panda', 'Panda'], ['bunny', 'Bunny'], ['cap', 'Red cap'], ['bee', 'Bee'], ['cowboy', 'Cowboy'],
    ['bear', 'Teddy bear'], ['penguin', 'Penguin'], ['merc', 'Mercenary mask'], ['witch', 'Witch'],
    ['monster', 'Monster'], ['ghost', 'Ghost'], ['unicorn', 'Unicorn'], ['pinkdino', 'Pink dino'],
    ['vampire', 'Vampire'], ['santa', 'Santa'], ['tophat', 'Top hat'], ['starhelm', 'Star helmet'],
    ['ironhelm', 'Iron helmet'],
  ];

  K.hatOptions = [
    ['none', 'No hat'], ['shark', 'Shark'], ['frog', 'Frog'], ['crown', 'Crown'], ['party', 'Party hat'],
    ['bow', 'Bow'], ['spider', 'Spider mask'], ['horns', 'Horned helm'], ['winged', 'Winged helm'],
  ].concat(K.hoodHats).map(([id, name]) => ({ id, name }));
  K.outfitOptions = [
    ['none', 'No costume'], ['cape', 'Hero cape'], ['bowtie', 'Bow tie'], ['shield', 'Star shield'], ['reactor', 'Glowing reactor'],
  ].concat(K.costumeOrder.map((id) => [id, K.costumes[id].name])).map(([id, name]) => ({ id, name }));
  K.hatIds = new Set(K.hatOptions.map((o) => o.id));
  K.outfitIds = new Set(K.outfitOptions.map((o) => o.id));

  K.hatHidesEars = (id) => !['none', 'crown', 'party', 'bow', 'spider', 'merc', 'tophat'].includes(id);

  // point-in-shape tests need a canvas context; this one is never drawn on
  let hitCtx = null;
  const hit = (path, x, y) => {
    if (!hitCtx) hitCtx = (typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(1, 1) : document.createElement('canvas')).getContext('2d');
    return hitCtx.isPointInPath(path, x, y);
  };

  const hashId = (s) => { let h = 7; for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) & 0xFFFF; return h | 1; };

  K.star = function (c, r) {
    const pts = [];
    for (let i = 0; i < 10; i++) {
      const a = i * PI / 5 + PI / 2, rr = i % 2 === 0 ? r : r * 0.42;
      pts.push(P(c.x + Math.cos(a) * rr, c.y + Math.sin(a) * rr));
    }
    return poly(pts);
  };

  function costumePattern(gc, cos, g, kind, id) {
    const r = g.torsoRect;
    if (id === 'c_unicorn' && kind === 'tail') {
      const cols = [0xF48FB1, 0xFFE082, 0x81D4FA, 0xB39DDB];
      g.tail.forEach((p, i) => {
        if (i > Math.floor(g.tail.length / 3)) { gc.fill(css(cols[Math.floor(i / 2) % cols.length])); gc.fillEllipse(ovalRect(p.x, p.y, 3.4, 3.4)); }
      });
    }
    if (cos.stripes !== undefined && kind !== 'leg') {
      gc.stroke(css(cos.stripes));
      gc.lw(id === 'c_bee' ? 4 : 2.6);
      const step = id === 'c_bee' ? 8 : 6;
      for (let x = r.minX - 20; x < r.maxX + 20; x += step) { gc.move(P(x, r.minY - 30)); gc.line(P(x + 3, r.maxY + 30)); }
      if (kind === 'tail') g.tail.forEach((p, i) => { if (i % 5 === 3) { gc.move(P(p.x - 6, p.y)); gc.line(P(p.x + 6, p.y)); } });
      gc.strokePath();
    }
    const torsoish = kind === 'torso' || kind === 'haunch';
    switch (id) {
      case 'c_plumber': case 'c_kitty':
        // overalls: lower half of the torso in the overall colour
        if (torsoish && cos.legs !== undefined) {
          gc.fill(css(cos.legs));
          gc.fillRect(r.width >= r.height ? R(r.minX - 5, r.minY - 5, r.width + 10, r.height * 0.55 + 5)
            : R(r.minX - 5, r.minY - 5, r.width + 10, r.height * 0.6 + 5));
        }
        break;
      case 'c_cowboy':
        if (kind === 'leg') cowSpots(gc);
        break;
      case 'c_spider':
        if (torsoish) {
          // web lines on the red, blue sides below
          const c = g.chest ? P(g.chest.midX, g.chest.midY) : P(r.midX, r.midY);
          gc.stroke(css(0x5C0A12));
          gc.lw(0.5);
          for (let i = 0; i < 8; i++) { const a = i * PI / 4; gc.move(c); gc.line(P(c.x + Math.cos(a) * 40, c.y + Math.sin(a) * 40)); }
          for (const rr of [5, 10, 15, 20]) gc.addEllipse(ovalRect(c.x, c.y, rr, rr * 0.85));
          gc.strokePath();
          gc.fill(css(0x1E4FA3));
          gc.fillRect(r.width >= r.height ? R(r.minX - 5, r.minY - 5, r.width + 10, r.height * 0.32 + 5)
            : R(r.minX - 5, r.minY - 5, r.width * 0.3 + 5, r.height + 10));
        }
        break;
      case 'c_merc':
        if (torsoish) { gc.fill(css(0x2A2A2E)); gc.fillRect(R(r.minX - 5, r.minY - 5, r.width + 10, r.height * 0.35 + 5)); }
        break;
      case 'c_wizard':
        if (torsoish || kind === 'leg') {
          gc.fill(css(0xF5C542));
          let rng = 7;
          for (let i = 0; i < 5; i++) {
            rng = (Math.imul(rng, 1664525) + 1013904223) >>> 0;
            const fx = ((rng >>> 8) & 0xFF) / 255, fy = ((rng >>> 16) & 0xFF) / 255;
            gc.addPath(K.star(P(r.minX + r.width * fx, r.minY + r.height * fy), 1.8));
          }
          gc.fillPath();
        }
        break;
      default: break;
    }
    if (cos.spots) {
      let rng = hashId(id);
      const area = kind === 'tail' ? R(-60, -40, 120, 120) : R(r.minX - 4, r.minY - 4, r.width + 8, r.height + 8);
      const n = kind === 'tail' ? 24 : 14;
      for (let i = 0; i < n; i++) {
        rng = (Math.imul(rng, 1664525) + 1013904223) >>> 0;
        const fx = ((rng >>> 8) & 0xFF) / 255, fy = ((rng >>> 16) & 0xFF) / 255;
        gc.fill(css(cos.spots[i % cos.spots.length]));
        const pt = kind === 'leg' ? P(-20 + 45 * fx, 1 + 14 * fy) : P(area.minX + area.width * fx, area.minY + area.height * fy);
        gc.fillEllipse(ovalRect(pt.x, pt.y, 1.6, 1.3));
      }
    }
    if (cos.belly !== undefined && kind !== 'tail') {
      gc.fill(css(cos.belly));
      if (g.belly) gc.fillEllipse(g.belly);
      if (g.chest) gc.fillEllipse(g.chest);
    }
    if (kind === 'leg') {
      if (cos.legs !== undefined) { gc.fill(css(cos.legs)); gc.fillRect(R(-80, -40, 160, 200)); }
      if (id === 'c_cowboy') cowSpots(gc);
      if (cos.paws !== undefined) { gc.fill(css(cos.paws)); gc.fillRect(R(-80, -20, 160, g.legLowY + 20)); }
    }
  }
  function cowSpots(gc) {
    gc.fill(css(0x2B2A2F));
    for (const [x, y] of [[-12, 9], [-7, 5], [9, 8], [14, 4], [4, 3]]) gc.fillEllipse(ovalRect(x, y, 2.4, 1.8));
  }

  function neck(g) {
    const dx = g.torsoC.x - g.head.x, dy = g.torsoC.y - g.head.y, l = Math.max(0.01, Math.hypot(dx, dy));
    return P(g.head.x + dx / l * g.headR * 0.85, g.head.y + dy / l * g.headR * 0.85);
  }

  /** Points along the back of the torso with outward directions (for spikes, fins, wings). */
  function backLine(g, count) {
    const r = g.torsoRect, horizontal = r.width >= r.height;
    const [a0, a1] = horizontal ? [150, 35] : [205, 105];
    const centre = P(r.midX, r.midY);
    const out = [];
    for (let i = 0; i < count; i++) {
      const a = (a0 + (a1 - a0) * i / Math.max(1, count - 1)) * PI / 180;
      const dir = P(Math.cos(a), Math.sin(a));
      // walk out from the middle of the body to the real edge of the silhouette (a seated cat is
      // narrow at the neck, so a plain ellipse would leave the spikes floating in the air)
      if (!g.torsoShape || !hit(g.torsoShape, centre.x, centre.y)) {
        out.push([P(centre.x + dir.x * r.width / 2, centre.y + dir.y * r.height / 2), dir]);
        continue;
      }
      const inside = (d) => hit(g.torsoShape, centre.x + dir.x * d, centre.y + dir.y * d);
      let lo = 0, hi = 1;
      const limit = Math.max(r.width, r.height) + 12;
      while (hi < limit && inside(hi)) { lo = hi; hi += 1; }
      for (let j = 0; j < 8; j++) { const m = (lo + hi) / 2; if (inside(m)) lo = m; else hi = m; }
      const d = Math.max(0, lo - 1.4);                       // the base sits just inside the body: no gap
      out.push([P(centre.x + dir.x * d, centre.y + dir.y * d), dir]);
    }
    return out;
  }

  /** Spikes along the back, all parallel: they point the same way (up, leaning toward the tail). */
  function backSpikes(gc, g, count, color, length, width) {
    const pts = backLine(g, count);
    let ax = 0, ay = 0;
    for (const [, n] of pts) { ax += n.x; ay += n.y; }
    ax -= 0.45 * pts.length;                                 // lean toward the tail (-x)
    const l = Math.max(0.01, Math.hypot(ax, ay));
    const dir = P(ax / l, ay / l), side = P(dir.y, -dir.x);
    gc.fill(css(color));
    for (const [p] of pts) {
      gc.addPath(poly([P(p.x - side.x * width, p.y - side.y * width), P(p.x + dir.x * length, p.y + dir.y * length),
        P(p.x + side.x * width, p.y + side.y * width)]));
    }
    gc.fillPath();
  }

  function bow(gc, c, s, color) {
    gc.fill(css(color));
    gc.addPath(poly([c, P(c.x - 4.5 * s, c.y + 2.8 * s), P(c.x - 4.5 * s, c.y - 2.8 * s)]));
    gc.addPath(poly([c, P(c.x + 4.5 * s, c.y + 2.8 * s), P(c.x + 4.5 * s, c.y - 2.8 * s)]));
    gc.fillPath();
    gc.fill(K.darker(color, 0.75));
    gc.fillEllipse(ovalRect(c.x, c.y, 1.4 * s, 1.4 * s));
  }

  /** Forked tail fin set across the direction of the last tail segment. */
  function tailFin(gc, g, color) {
    if (g.tail.length <= 3) return;
    const tip = g.tail[g.tail.length - 1], prev = g.tail[g.tail.length - 3];
    const l = Math.max(0.01, Math.hypot(tip.x - prev.x, tip.y - prev.y));
    const d = P((tip.x - prev.x) / l, (tip.y - prev.y) / l), n = P(-d.y, d.x);
    const at = (a, b) => P(tip.x + d.x * a + n.x * b, tip.y + d.y * a + n.y * b);
    gc.fill(css(color));
    gc.addPath(poly([at(-2.5, 2.6), at(4.5, 7.5), at(2.2, 0), at(4.5, -7.5), at(-2.5, -2.6)]));
    gc.fillPath();
  }

  function ermine(gc, n, k) {
    gc.fill(css(0xF4F2EE));
    gc.addPath(ellipse(n, 8 * k, 3.2 * k)); gc.fillPath();
    gc.fill(css(0x1B1B1F));
    for (const dx of [-5, -1.5, 2, 5.5]) gc.fillEllipse(ovalRect(n.x + dx * k, n.y, 0.6 * k, 0.9 * k));
  }

  /** Zig-zag ruffle collar around the neck. */
  function ruff(gc, n, k, color, pom) {
    const pts = [];
    for (let i = 0; i < 16; i++) {
      const a = i * PI / 8, r = (i % 2 === 0 ? 7.5 : 4.5) * k;
      pts.push(P(n.x + Math.cos(a) * r, n.y + Math.sin(a) * r * 0.55));
    }
    gc.fill(css(color)); gc.addPath(poly(pts)); gc.fillPath();
    gc.fill(css(pom));
    for (let i = 0; i < 16; i += 4) gc.fillEllipse(ovalRect(pts[i].x, pts[i].y, 1 * k, 1 * k));
  }

  function cloak(gc, g, t, outer, inner) {
    const n = neck(g), r = g.torsoRect, wave = Math.sin(t * 3) * 2;
    const p = new Path2D();
    p.moveTo(n.x + 1, n.y + 3);
    p.quadraticCurveTo(r.midX, r.maxY + 4, r.minX - 4 + wave, r.maxY + 2);
    p.lineTo(r.minX - 11 + wave * 1.5, r.minY + 2);
    p.lineTo(r.minX + 2, r.minY + 4);
    p.quadraticCurveTo(r.midX - 2, r.midY, n.x - 1, n.y - 3);
    p.closePath();
    gc.fill(css(inner)); gc.addPath(p); gc.fillPath();
    gc.save();
    gc.translate(1.5, 1.2);
    gc.fill(css(outer)); gc.addPath(p); gc.fillPath();
    gc.restore();
  }

  function drawCostumeExtras(gc, look, g, ri) {
    const t = ri.t, n = neck(g), r = g.torsoRect, k = g.headR / 11.5;
    const front = P(n.x + 1.5 * k, n.y - 1 * k);
    const back = g.backView;
    switch (look.outfit) {
      case 'c_chick': if (!back) bow(gc, front, k, 0xF0A12F); break;
      case 'c_shark': {
        const line = backLine(g, 5);
        if (line.length > 2) {
          const [p, nrm] = line[2];
          gc.fill(css(0x5D7C9C));
          gc.addPath(poly([P(p.x - 4, p.y - 1), P(p.x + nrm.x * 9 - 3, p.y + nrm.y * 9), P(p.x + 4, p.y)]));
          gc.fillPath();
        }
        tailFin(gc, g, 0x5D7C9C);
        break;
      }
      case 'c_vampire':
        cloak(gc, g, t, 0x1E1C22, 0xB3202A);
        if (!back) {
          bow(gc, front, k, 0xD7262F);
          gc.fill(css(0x8C8C94));
          for (let i = 0; i < 2; i++) gc.fillEllipse(ovalRect(front.x + 1, front.y - 4 - i * 3.5, 0.9, 0.9));
        }
        break;
      case 'c_dino': backSpikes(gc, g, 6, 0xF2C230, 5.5, 2.8); break;
      case 'c_pinkdino': backSpikes(gc, g, 6, 0xE04A6A, 5.5, 2.8); break;
      case 'c_bunny':
        if (!back) bow(gc, front, k * 0.85, 0xF48FB1);
        if (g.tail.length) { const b = g.tail[0]; gc.fill(css(0xFFFFFF)); gc.fillEllipse(ovalRect(b.x - 1, b.y, 4.5, 4.5)); }
        break;
      case 'c_panda': if (!back) bow(gc, front, k * 0.85, 0x4C9A3F); break;
      case 'c_plumber': case 'c_kitty': {
        if (back) break;
        const horizontal = r.width >= r.height;
        const topY = horizontal ? r.minY + r.height * 0.55 : r.minY + r.height * 0.6;
        gc.stroke(css(look.outfit === 'c_plumber' ? 0x2F5DAE : 0xD7262F));
        gc.lw(1.6);
        gc.move(P(front.x - 2, topY)); gc.line(P(n.x - 1, n.y));
        gc.move(P(front.x + 3, topY)); gc.line(P(n.x + 3, n.y));
        gc.strokePath();
        if (look.outfit === 'c_plumber') {
          gc.fill(css(0xF5C542));
          gc.fillEllipse(ovalRect(front.x - 2, topY, 1.2, 1.2));
          gc.fillEllipse(ovalRect(front.x + 3, topY, 1.2, 1.2));
        } else {
          // little white cat face on the bib and a big red bow
          const c = P(front.x, topY - 3);
          gc.fill(css(0xFFFFFF));
          gc.fillEllipse(ovalRect(c.x, c.y, 2.6, 2.1));
          gc.addPath(poly([P(c.x - 2.4, c.y + 0.8), P(c.x - 1.8, c.y + 3), P(c.x - 0.6, c.y + 1.6)]));
          gc.addPath(poly([P(c.x + 2.4, c.y + 0.8), P(c.x + 1.8, c.y + 3), P(c.x + 0.6, c.y + 1.6)]));
          gc.fillPath();
          bow(gc, P(n.x - 3 * k, n.y + 2 * k), k, 0xD7262F);
        }
        break;
      }
      case 'c_royal': cloak(gc, g, t, 0xB71C1C, 0xF4F2EE); ermine(gc, n, k); break;
      case 'c_party': ruff(gc, n, k, 0xFFFFFF, 0xFFEB3B); break;
      case 'c_trickster':
        cloak(gc, g, t, 0x2E7D32, 0xE3B23C);
        gc.fill(css(0xE3B23C)); gc.fillEllipse(ovalRect(n.x, n.y, 1.8, 1.8));
        break;
      case 'c_jester':
        ruff(gc, n, k, 0xF2EEE8, 0xF4A7C0);
        if (!back) { gc.fill(css(0xF4A7C0)); for (let i = 0; i < 2; i++) gc.fillEllipse(ovalRect(front.x, front.y - 4.5 - i * 3.5, 1.1, 1.1)); }
        break;
      case 'c_monster': backSpikes(gc, g, 5, 0x7E62B8, 4.5, 2.2); break;
      case 'c_unicorn': {
        // rainbow mane along the back
        const cols = [0xF48FB1, 0xFFE082, 0x81D4FA, 0xB39DDB, 0xF48FB1];
        backLine(g, 5).forEach(([p, nrm], i) => { gc.fill(css(cols[i])); gc.fillEllipse(ovalRect(p.x + nrm.x * 1.5, p.y + nrm.y * 1.5, 3, 3)); });
        break;
      }
      case 'c_bee': {
        const p = backLine(g, 5)[1][0];
        gc.fill(css(0xCFE8F7, 0.75));
        gc.fillEllipse(ovalRect(p.x - 3, p.y + 5, 5, 7));
        gc.fillEllipse(ovalRect(p.x + 3, p.y + 5, 4, 6));
        if (!back) bow(gc, front, k * 0.8, 0x4A3423);
        break;
      }
      case 'c_wizard':
        cloak(gc, g, t, 0x2C2F55, 0x6B3FA0);
        gc.fill(css(0xF5C542)); gc.fillEllipse(ovalRect(n.x, n.y, 1.8, 1.8));
        break;
      case 'c_frog': if (!back) bow(gc, front, k * 0.85, 0x3E8E41); break;
      case 'c_cowboy': {
        if (!back) {
          gc.fill(css(0xC62828));
          gc.addPath(poly([P(n.x - 4 * k, n.y + 1), P(n.x + 4.5 * k, n.y + 1), P(front.x + 1, n.y - 6 * k)]));
          gc.fillPath();
          gc.fill(css(0xF5C542));
          gc.addPath(K.star(P(front.x - 2, n.y - 9 * k), 2.2));
          gc.fillPath();
        }
        // belt with a plain buckle
        gc.save();
        const tp = g.parts.find((p) => p.kind === 'torso');
        if (tp) { gc.addPath(tp.path); gc.clip(); }
        gc.fill(css(0x3B2A1A));
        const horizontal = r.width >= r.height;
        const belt = horizontal ? R(r.minX + r.width * 0.25, r.minY - 2, 3.5, r.height + 4) : R(r.minX - 2, r.minY + r.height * 0.3, r.width + 4, 3.5);
        gc.fillRect(belt);
        gc.restore();
        gc.fill(css(0xD9A93A));
        gc.fillRect(R(belt.midX - 1.6, (horizontal ? r.minY + 3 : belt.midY) - 1.6, 3.2, 3.2));
        break;
      }
      case 'c_penguin': if (!back) bow(gc, front, k * 0.85, 0xD7262F); break;
      case 'c_bear': if (!back) bow(gc, front, k * 0.85, 0x6B4423); break;
      case 'c_ghost': {
        // a sheet over the whole body with a wavy hem and two holes
        const top = n.y + 2, bottomY = g.grounded ? 0.5 : r.minY - 4;
        const p = new Path2D();
        p.moveTo(r.minX - 4, bottomY);
        p.lineTo(r.minX - 3, r.midY);
        p.quadraticCurveTo(r.midX, top + 14, r.maxX + 3, r.midY);
        p.lineTo(r.maxX + 4, bottomY);
        const w = (r.width + 8) / 5;
        for (let i = 0; i < 5; i++) {
          const x0 = r.maxX + 4 - i * w;
          p.quadraticCurveTo(x0 - w / 2, bottomY + 3 + Math.sin(t * 4 + i) * 1.5, x0 - w, bottomY);
        }
        p.closePath();
        gc.fill(css(0xF6F4EE)); gc.addPath(p); gc.fillPath();
        if (!back) {
          gc.fill(css(0x2B2A2F));
          gc.fillEllipse(ovalRect(r.midX + 2, r.midY + 2, 1.6, 2.2));
          gc.fillEllipse(ovalRect(r.midX + 7, r.midY + 2, 1.6, 2.2));
        }
        break;
      }
      case 'c_banana':
        // peel flaps hanging from the neck
        for (const [dx, ang] of [[-1, 200], [1, 300], [0, 250]]) {
          const a = ang * PI / 180, base = P(n.x + dx * 3, n.y), tip = P(base.x + Math.cos(a) * 14, base.y + Math.sin(a) * 14);
          gc.fill(css(0xF6D84B)); gc.addPath(stroked([base, tip], 5.5)); gc.fillPath();
          gc.fill(css(0xFFF3B8)); gc.addPath(stroked([P(lerp(base.x, tip.x, 0.3), lerp(base.y, tip.y, 0.3)), tip], 2.4)); gc.fillPath();
        }
        break;
      case 'c_merc': {
        gc.save();
        const tp = g.parts.find((p) => p.kind === 'torso');
        if (tp) { gc.addPath(tp.path); gc.clip(); }
        gc.stroke(css(0x6B4423));
        gc.lw(2.2);
        gc.move(P(r.minX, r.minY)); gc.line(P(r.maxX, r.maxY));
        gc.move(P(r.minX, r.maxY)); gc.line(P(r.maxX, r.minY));
        gc.strokePath();
        gc.restore();
        if (!back) {
          gc.fill(css(0x2A2A2E)); gc.fillEllipse(ovalRect(r.midX, r.midY, 2.6, 2.6));
          gc.fill(css(0xC62828)); gc.fillEllipse(ovalRect(r.midX, r.midY, 1.6, 1.6));
        }
        break;
      }
      default: break;
    }
  }

  K.costumePattern = costumePattern;
  K.drawCostumeExtras = drawCostumeExtras;
  K.bow = bow;
})(globalThis.K = globalThis.K || {});
