// Pixel cats: the same cats, coats, hats and costumes, drawn as small pixel sprites.
// The sitting cat comes from the reference picture (style A); the side views are drawn from shapes in the same
// palette. Everything is built from letters (b body, h head, f face, r inner ear, v belly, t tail, d shade,
// e eye, p pink, u paw, k outline) so coats, costumes and hats are plain recolors and overlays.
(function (K) {
  'use strict';

  const hex = (n) => [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  const dk = (c, f) => c.map((v) => Math.max(0, Math.round(v * f)));
  const lt = (c, d) => c.map((v) => Math.min(255, v + d));
  const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
  const nums = (s) => String(s).match(/[\d.]+/g).slice(0, 3).map(Number);
  const mk = (w, h) => Array.from({ length: h }, () => new Array(w).fill(null));
  const copy = (g) => g.map((r) => r.slice());
  const hash = (a, b, c) => { let h = (Math.imul(a + 17, 374761393) ^ Math.imul(b + 31, 668265263) ^ Math.imul(c + 7, 2246822519)) >>> 0; h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0; return (h ^ (h >>> 16)) >>> 0; };

  const PAD_TOP = 9, PAD_SIDE = 4;

  // ---------- the sitting cat, from the reference picture ----------
  const FRONT_ASCII = [
    '....................', '...##d.....##d......', '..#bb#d...#bb#d.....', '..#pbb####bbpb#d....', '.#bppbbbbbbppb#d....',
    '.#bpbbbbbbbbpbb#d...', '.#bbbbbbbbbbbbb#d...', '#bbbbbbbbbbbbbbb#d..', 'bbbbbbbbbbbbbbbb#d..', '#bbbbebbbbebbbbbbd..',
    'bbbbpebpbbepbbd#d...', '.#bbbbbbbbbbbbbbd...', '..#bbbbbbbbbbb#d....', '...##bbbbbb###d.....', '..#bbbbbbbbbbb#d....',
    '..#bbbbbbbbbbbb#d...', '..#bbbb#bbbbb#bd#d..', '..#bbbb#bbbbb#bb#d..', '...#bbb#bbbb#bbbd#d.', '...#bbb#bbbb#bbdd#d.',
    '....#pb#bpb#bbdd#d..', '.....######d####d...', '....................',
  ];

  function frontBase() {
    const H = FRONT_ASCII.length, W = FRONT_ASCII[0].length;
    const g = FRONT_ASCII.map((r) => [...r].map((c) => (c === '.' ? null : c)));
    const empty = (x, y) => y < 0 || y >= H || x < 0 || x >= W || !g[y][x];
    const touches = (x, y) => empty(x - 1, y) || empty(x + 1, y) || empty(x, y - 1) || empty(x, y + 1);
    for (const ch of ['d', '#']) {                       // the old outline and drop shadow go; the outline is drawn again around the final shape
      const kill = [];
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g[y][x] === ch && touches(x, y)) kill.push([x, y]);
      kill.forEach(([x, y]) => { g[y][x] = null; });
    }
    const L = mk(W, H);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = g[y][x]; if (!c) continue;
      let o = c;
      if (c === '#') o = 'k';
      else if (y <= 12) {
        if (c === 'b') o = (((x - 7.5) / 5.6) ** 2 + ((y - 9.9) / 2.9) ** 2 <= 1) ? 'f' : 'h';           // the face a hood leaves open
        else if (c === 'p' && y <= 5) o = 'r';
      } else {
        if (c === 'b' || c === 'd') {
          if (x >= 13 && y >= 16) o = 't';
          else if (c === 'b' && x >= 6 && x <= 12 && y >= 15 && y <= 20) o = 'v';
        } else if (c === 'p' && y >= 19) o = 'u';
      }
      L[y][x] = o;
    }
    return L;
  }

  // ---------- the side view, drawn from shapes ----------
  const S = (g, x, y, c) => { if (y >= 0 && y < g.length && x >= 0 && x < g[0].length) g[y][x] = c; };
  const R = (g, x0, y0, x1, y1, c) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) S(g, x, y, c); };
  const E = (g, cx, cy, rx, ry, c) => { for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1) S(g, x, y, c); };
  const Ln = (g, x0, y0, x1, y1, c, t) => { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1); for (let i = 0; i <= n; i++) R(g, Math.round(x0 + (x1 - x0) * i / n), Math.round(y0 + (y1 - y0) * i / n), Math.round(x0 + (x1 - x0) * i / n) + t - 1, Math.round(y0 + (y1 - y0) * i / n) + t - 1, c); };

  function headAt(g, x0, hy, w, eye, kind) {
    R(g, x0, hy + 1, x0 + w - 1, hy + 9, 'h'); R(g, x0 + 1, hy, x0 + w - 2, hy, 'h');
    [[x0, hy + 1], [x0 + w - 1, hy + 1], [x0, hy + 9], [x0 + w - 1, hy + 9]].forEach(([x, y]) => S(g, x, y, null));
    [x0, x0 + w - 4].forEach((x) => { R(g, x, hy - 1, x + 3, hy, 'h'); R(g, x + 1, hy - 2, x + 2, hy - 2, 'h'); S(g, x + 1, hy - 1, 'r'); S(g, x + 2, hy - 1, 'r'); S(g, x + 1, hy, 'r'); });
    for (let y = hy + 3; y <= hy + 9; y++) for (let x = x0 + w - 6; x <= x0 + w - 1; x++) if (g[y][x] === 'h' && !(x === x0 + w - 6 && (y === hy + 3 || y === hy + 9))) g[y][x] = 'f';
    S(g, x0 + w - 5, hy + 4, eye); S(g, x0 + w - 5, hy + 5, eye);
    S(g, x0 + w - 1, hy + 6, 'p');
  }

  function sideBase(kind, k) {
    const W = 28, H = 22, g = mk(W, H);
    const arch = kind === 'hiss' ? 2 : 0, bob = kind === 'walk' && k % 2 ? -1 : 0;
    if (kind === 'walk' || kind === 'hiss') {
      const ph = k * Math.PI / 2, A = kind === 'hiss' ? 0 : 2, up = (a) => (Math.cos(a) > 0.5 ? 1 : 0);
      const legs = [[5 + Math.round(A * Math.sin(ph)), up(ph), 'b'], [8 + Math.round(A * Math.sin(ph + Math.PI)), up(ph + Math.PI), 'd'],
        [12 + Math.round(A * Math.sin(ph)), up(ph), 'd'], [15 + Math.round(A * Math.sin(ph + Math.PI)), up(ph + Math.PI), 'b']];
      const leg = ([x, lift, ch]) => { R(g, x, 14 + bob, x + 1, 19 - lift, ch); S(g, x, 19 - lift, ch === 'd' ? 'd' : 'u'); S(g, x + 1, 19 - lift, ch === 'd' ? 'd' : 'u'); };
      leg(legs[1]); leg(legs[2]);
      E(g, 10, 12 + bob - arch / 2, 7.4, 3.8 + arch * 0.4, 'b'); E(g, 10, 14 + bob, 5.4, 1.6, 'v');
      leg(legs[0]); leg(legs[3]);
      const hy = 4 + bob + (kind === 'hiss' ? 2 : 0);
      headAt(g, 13, hy, 12, 'e');
      if (kind === 'hiss') { R(g, 23, hy + 8, 24, hy + 9, 'k'); S(g, 22, hy + 8, 'w'); }
      const sw = k % 2;
      const tp = kind === 'hiss' ? [[4, 11], [2, 8], [2, 3], [3, 0]] : [[4, 11 + bob], [2, 10 + bob], [1 + sw, 7], [1 + sw, 4 + sw]];
      for (let i = 0; i < tp.length - 1; i++) Ln(g, tp[i][0], tp[i][1], tp[i + 1][0], tp[i + 1][1], 't', kind === 'hiss' ? 3 : 2);
    } else if (kind === 'run') {
      // gallop: 0 stretched out in the air, 1 front paws land, 2 legs gathered under, 3 hind legs push off
      const f = k % 4, by = [9, 10, 11, 10][f], hy = [2, 3, 4, 3][f];
      // far front, far hind, near front, near hind: [from x, from y, to x, to y]
      const legs = [
        [[15, 11, 22, 15], [7, 11, 1, 15], [16, 10, 23, 14], [6, 10, 0, 14]],
        [[14, 12, 13, 18], [7, 12, 2, 15], [16, 12, 18, 18], [6, 11, 1, 14]],
        [[14, 13, 10, 18], [8, 13, 12, 18], [15, 13, 12, 18], [7, 13, 10, 18]],
        [[15, 12, 20, 15], [8, 13, 6, 18], [16, 11, 22, 14], [7, 13, 4, 18]],
      ][f];
      const leg = ([x0, y0, x1, y1], c) => { Ln(g, x0, y0, x1, y1, c, 2); const paw = c === 'd' ? 'd' : 'u'; S(g, x1, y1 + 1, paw); S(g, x1 + 1, y1 + 1, paw); };
      leg(legs[0], 'd'); leg(legs[1], 'd');
      E(g, 11, by, f === 2 ? 6.6 : 8, f === 2 ? 4 : 3.4, 'b'); E(g, 11, by + 2, 5, 1.4, 'v');
      leg(legs[2], 'b'); leg(legs[3], 'b');
      headAt(g, 14, hy, 12, 'e');
      const tip = by - 2 - (f % 2);                                     // the tail streams out behind
      Ln(g, 4, by, 1, tip, 't', 2); Ln(g, 1, tip, 0, tip - 2, 't', 2);
    } else if (kind === 'sleep' || kind === 'loaf') {
      const b = k % 2, open = kind === 'loaf';
      E(g, 12, 16 - b * 0.5, 9.4, 3.6 + b * 0.5, 'b'); E(g, 12, 18, 7, 1.5, 'v');
      E(g, 20, 16 - b * 0.4, 5.2, 3.8, 'h');
      [17, 22].forEach((x) => { R(g, x, 11, x + 2, 12, 'h'); S(g, x + 1, 12, 'r'); S(g, x + 1, 11, 'r'); S(g, x + 1, 10, 'h'); });
      R(g, 23, 17, 25, 19, 'f'); S(g, 25, 17, 'p');
      if (open) { S(g, 19, 15, 'e'); S(g, 19, 16, 'e'); S(g, 23, 15, 'e'); S(g, 23, 16, 'e'); }
      else { S(g, 19, 16, 'k'); S(g, 20, 16, 'k'); S(g, 22, 16, 'k'); S(g, 23, 16, 'k'); }
      Ln(g, 3, 18, 6, 19, 't', 2); Ln(g, 2, 17, 3, 15, 't', 2);
    } else if (kind === 'jump') {
      const up = k % 2;
      E(g, 11, 9 + up, 8, 3.4, 'b'); E(g, 11, 11 + up, 6, 1.5, 'v');
      Ln(g, 16, 11 + up, 21, 14 + up, 'b', 2); Ln(g, 13, 12 + up, 18, 15 + up, 'd', 2);
      Ln(g, 5, 10 + up, 1, 14 + up, 'b', 2); Ln(g, 8, 11 + up, 4, 15 + up, 'd', 2);
      S(g, 21, 15 + up, 'u'); S(g, 22, 15 + up, 'u'); S(g, 1, 15 + up, 'u');
      headAt(g, 14, 1 + up, 12, 'e');
      Ln(g, 4, 8 + up, 2, 5 + up, 't', 2); Ln(g, 2, 5 + up, 3, 2 + up, 't', 2);
    }
    return g;
  }

  // A cat on a window side, head up, belly and paws against the wall on the right (x = 22).
  // slide: sliding down with the front claws dug in above the head.
  function climbBase(k, slide) {
    const g = mk(24, 32), st = k % 2 === 0 ? 1 : -1, bob = slide ? 0 : k % 2, sw = Math.floor(k / 2) % 2;
    const frontNear = slide ? 1 : 5 - 2 * st, frontFar = slide ? 2 : 6 + 2 * st;
    const hindNear = slide ? 28 : 25 + st, hindFar = slide ? 27 : 25 - st;
    const paw = (y, c) => R(g, 20, y, 21, y + 1, c);
    Ln(g, 17, 12 + bob, 19, frontFar, 'd', 2); paw(frontFar, 'd');
    Ln(g, 14, 23 + bob, 19, hindFar, 'd', 2); paw(hindFar, 'd');
    E(g, 14, 17 + bob, 4.2, 7, 'b'); E(g, 16.4, 17 + bob, 1.5, 5, 'v');
    Ln(g, 12, 23 + bob, 10, 27, 't', 2); Ln(g, 10, 27, 9 + sw, 30, 't', 2);
    Ln(g, 16, 12 + bob, 19, frontNear, 'b', 2); paw(frontNear, 'u');
    E(g, 15, 22 + bob, 2.6, 2.8, 'b');
    Ln(g, 16, 23 + bob, 19, hindNear, 'b', 2); paw(hindNear, 'u');
    headAt(g, 7, 3 + bob, 11, 'e');
    return g;
  }

  // families: a letter grid, padded for tall hats, with the point on the ground and the leg row
  const FAM = {};
  function pad(g) { const o = mk(g[0].length + PAD_SIDE * 2, g.length + PAD_TOP); g.forEach((r, y) => r.forEach((c, x) => { o[y + PAD_TOP][x + PAD_SIDE] = c; })); return o; }
  function family(key) {
    if (FAM[key]) return FAM[key];
    const [kind, k] = key.split(':'), n = +k || 0;
    let L, ground, legTop, wallX = null;
    if (kind === 'groom') {
      // washing: eyes shut, one front paw comes up to lick it (with the tongue out), then rubs the cheek and over the eye
      L = frontBase();
      for (const r of L) r.forEach((c, x) => { if (c === 'e') r[x] = 'k'; });
      const [px, py] = [[6, 11], [4, 8], [6, 11], [5, 10]][n % 4];
      // a dark line around the raised leg so it reads against the chest and face
      for (let y = py - 1; y <= 15; y++) for (const x of [px - 1, px + 2]) if (L[y][x]) L[y][x] = 'k';
      for (let x = px; x <= px + 1; x++) if (L[py - 1][x]) L[py - 1][x] = 'k';
      for (let y = py + 2; y <= 15; y++) for (let x = px; x <= px + 1; x++) L[y][x] = 'b';
      for (let y = py; y <= py + 1; y++) for (let x = px; x <= px + 1; x++) L[y][x] = 'u';
      if (n % 2 === 0) L[12][8] = 'p';
      ground = 20 + PAD_TOP; legTop = 17 + PAD_TOP;
    } else if (kind === 'climb' || kind === 'slide') { L = climbBase(n, kind === 'slide'); ground = (kind === 'slide' ? 29 : 26) + PAD_TOP; legTop = 999; wallX = 22 + PAD_SIDE; }
    else if (kind === 'sit') {
      L = frontBase();
      if (n === 1) for (const r of L) r.forEach((c, x) => { if (c === 'e') r[x] = 'k'; });                       // blink
      if (n === 2) { for (let y = 16; y < L.length; y++) for (let x = 13; x < L[0].length; x++) if (L[y][x] === 't') { L[y - 1][x] = L[y - 1][x] || 't'; } }
      if (n === 3) { for (let y = 1; y <= 4; y++) for (let x = 10; x <= 15; x++) if (L[y][x] && L[y + 1][x] === null) { L[y + 1][x] = L[y][x]; L[y][x] = null; } }
      ground = 20 + PAD_TOP; legTop = 17 + PAD_TOP;
    } else if (kind === 'walk' || kind === 'hiss') { L = sideBase(kind, n); ground = 19 + PAD_TOP; legTop = 15 + PAD_TOP; }
    else { L = sideBase(kind, n); ground = 19 + PAD_TOP; legTop = kind === 'run' ? 14 + PAD_TOP : 999; }
    L = pad(L);
    const Rg = L.map((row) => row.map((c) => ({ h: 'H', f: 'H', r: 'H', t: 'T', b: 'B', d: 'B', v: 'V', u: 'U' })[c] || c));
    return (FAM[key] = { L, R: Rg, ground, legTop, side: kind !== 'sit', cx: Math.floor(L[0].length / 2), wallX, lying: kind === 'sleep' || kind === 'loaf' });
  }

  // ---------- palette and coat patterns ----------
  function palette(look) {
    const base = hex(look.baseHex), acc = hex(look.accentHex), light = base.reduce((a, b) => a + b, 0) > 600;
    return {
      b: base, t: base, h: base, f: lt(base, 14), v: lt(base, 14), d: dk(base, light ? 0.88 : 0.82), s: acc, w: hex(0xF4F4F6),
      q: acc, z: hex(0x2B2A2F), p: hex(0xE8AAB4), u: hex(0xE8AAB4), r: hex(0xE8AAB4), e: nums(look.eyeL), E: nums(look.eyeR), k: [60, 56, 58],
    };
  }

  function coat(L, Rg, look, fam) {
    const pat = look.pattern, seed = look.seed % 997, H = L.length, W = L[0].length;
    const isBody = (c) => c === 'b' || c === 't';
    let top = H; L.forEach((row, y) => row.forEach((c) => { if (c && 'hfr'.includes(c)) top = Math.min(top, y); }));
    const tabby = pat === 'tabby' || pat === 'tabbyBicolor', bi = pat === 'bicolor' || pat === 'tabbyBicolor' || pat === 'colorpoint';
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = L[y][x]; if (!c) continue;
      if (tabby) {
        if (isBody(c) && ((fam.side ? x : y) + (fam.side ? 0 : (x >> 2)) + seed) % 3 === 0 && (fam.side ? y % 5 !== 0 : x % 6 !== 0)) L[y][x] = 's';
        else if (c === 'h' && y >= top + 2 && y <= top + 4 && (x + seed) % 3 === 0) L[y][x] = 's';
      }
      if (pat === 'calico' || pat === 'tortie') {
        const n = hash(Math.floor(x / 3), Math.floor(y / 3), seed) % 100;
        if (c !== 'e' && c !== 'k' && c !== 'p' && c !== 'u' && c !== 'r') {
          if (pat === 'calico') { if (n < 26) L[y][x] = 'q'; else if (n < 40) L[y][x] = 'z'; }
          else if (n < 42) L[y][x] = 'q';
        }
      }
    }
    if (bi && pat !== 'colorpoint') {
      let cx = 0, n = 0; L.forEach((row) => row.forEach((c, x) => { if (c && 'hf'.includes(c)) { cx += x; n++; } })); cx = cx / Math.max(1, n);
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
        const c = L[y][x]; if (!c) continue;
        if (c === 'v' || c === 'f' || c === 'u') L[y][x] = 'w';
        else if (!fam.side && c === 'h' && y >= top + 4 && Math.abs(x - cx) <= 1.2 + (y - top - 4) * 0.25) L[y][x] = 'w';
      }
    }
    if (pat === 'colorpoint') {
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
        const c = L[y][x]; if (!c) continue;
        if (c === 'f' || c === 't' || c === 'u' || c === 'r') L[y][x] = c === 'r' ? 'r' : 's';
        else if (c === 'h' && y <= top + 2) L[y][x] = 's';
        else if ((c === 'b' || c === 'd') && y >= fam.ground - 2) L[y][x] = 's';
      }
    }
  }

  // ---------- costumes ----------
  const EXTRAS = {
    c_shark: { fin: 0x4A6683 }, c_dino: { spikes: 0xF2C230 }, c_pinkdino: { spikes: 0xE04A6A }, c_monster: { spikes: 0x7E62B8 },
    c_bee: { stripes: 0x4A3423 }, c_party: { spots: [0xFFEB3B, 0x4FC3F7, 0x81C784] }, c_royal: { collar: 0xF4F2EE },
    c_spider: { web: 0x6E1015 }, c_plumber: { buttons: 0xF2C230 }, c_bunny: { pom: 0xFFFFFF }, c_kitty: { bow: 0xD7262F },
    c_ghost: { wave: true }, c_unicorn: {}, c_wizard: { stars: 0xF2C230 }, c_jester: { diamonds: 0xC9A227 }, c_cowboy: { bandana: 0xC62828 },
    c_penguin: { bow: 0xD7262F }, c_bear: { bow: 0x6B4423 }, c_panda: { bow: 0x4C9A3F }, c_frog: { bow: 0x3E8E41 },
  };

  function bodyBox(Rg) {
    let x0 = 999, x1 = -1, y0 = 999, y1 = -1;
    Rg.forEach((row, y) => row.forEach((c, x) => { if (c === 'B' || c === 'V') { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }));
    return { x0, x1, y0, y1 };
  }
  function topEdge(C, x, from, to) { for (let y = from; y <= to; y++) if (C[y] && C[y][x]) return y; return -1; }

  function outfit(C, Rg, fam, id, L) {
    const H = C.length, W = C[0].length, bb = bodyBox(Rg);
    const set = (x, y, c) => { if (y >= 0 && y < H && x >= 0 && x < W) C[y][x] = c; };
    const paint = (test, fn) => { for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (C[y][x] && test(Rg[y][x], x, y)) { const c = fn(x, y, C[y][x]); if (c) C[y][x] = c; } };
    if (id === 'cape') {
      const c = hex(0xC62828), c2 = hex(0x8E1B1B);
      if (fam.side) {
        // the cape lies over the back and trails behind the rump
        const midY = Math.floor((bb.y0 + bb.y1) / 2);
        for (let y = bb.y0; y <= midY; y++) for (let x = 0; x < W; x++) if (Rg[y][x] === 'B' && C[y][x]) set(x, y, c);
        for (let i = 1; i <= 3; i++) { const x = bb.x0 + 1 - i; if (x < 0) continue; for (let y = bb.y0 + i; y <= Math.min(H - 1, midY + i); y++) if (!C[y][x]) set(x, y, i === 3 ? c2 : c); }
        set(bb.x1 - 1, bb.y0, hex(0xF2C230));
      } else {
        // seen from the front: red edges on both sides, a gold clasp at the neck
        for (let y = bb.y0; y <= bb.y1; y++) {
          let mn = 999, mx = -1; for (let x = 0; x < W; x++) if (C[y][x] && (Rg[y][x] === 'B' || Rg[y][x] === 'V')) { mn = Math.min(mn, x); mx = Math.max(mx, x); }
          if (mn === 999) continue;
          for (let d = 1; d <= 2; d++) { if (mn - d >= 0 && !C[y][mn - d]) set(mn - d, y, d === 2 ? c2 : c); if (mx + d < W && !C[y][mx + d]) set(mx + d, y, d === 2 ? c2 : c); }
        }
        set(Math.floor((bb.x0 + bb.x1) / 2), bb.y0, hex(0xF2C230));
      }
      return;
    }
    if (id === 'bowtie') { const cx = fam.side ? bb.x1 - 1 : Math.round((bb.x0 + bb.x1) / 2), cy = fam.side ? bb.y0 + 2 : bb.y0 - 0; [-2, -1, 1, 2].forEach((d) => { set(cx + d, cy, hex(0xD7262F)); set(cx + d, cy + 1, hex(0xD7262F)); }); set(cx, cy, hex(0x8E1B1B)); set(cx, cy + 1, hex(0x8E1B1B)); return; }
    if (id === 'wings') {
      // fairy wings behind the cat: a big upper wing and a small lower one, pale with a lilac rim and a sparkle
      const fill = hex(0xF7DDF7), rim = hex(0xC59BE6), glint = hex(0xFFFFFF);
      const wing = (cx, cy, rx, ry) => {
        const inside = (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;
        for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
          if (!inside(x, y) || y < 0 || y >= H || x < 0 || x >= W || C[y][x]) continue;
          const edge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1);
          set(x, y, edge ? rim : fill);
        }
        const gx = Math.round(cx), gy = Math.round(cy - ry / 3);
        if (C[gy] && C[gy][gx] === fill) set(gx, gy, glint);
      };
      if (fam.wallX !== null) { wing(bb.x0 - 2, bb.y0 + 4, 2.6, 3.8); wing(bb.x0 - 1, bb.y0 + 9.5, 1.7, 2.2); }   // on a wall the back faces away from it
      else if (fam.lying) { const sx = bb.x0 + (bb.x1 - bb.x0) * 0.72; wing(sx - 1, bb.y0 - 4, 2.6, 3.6); wing(sx - 3.5, bb.y0 - 1, 1.8, 1.8); }   // lying: up from the shoulder blades
      else if (fam.side) { const sx = bb.x0 + (bb.x1 - bb.x0) * 0.55, sy = bb.y0; wing(sx - 2, sy - 3.5, 3.6, 3); wing(sx - 5, sy - 0.5, 2.4, 1.8); }
      else [[bb.x0, -1], [bb.x1, 1]].forEach(([x, d]) => { wing(x + d * 3, bb.y0 + 1, 2.8, 3.4); wing(x + d * 2, bb.y0 + 5.5, 1.8, 1.9); });
      return;
    }
    if (id === 'reactor') {
      if (fam.lying) return;                                          // lying on its chest: the reactor is underneath
      // on the chest: high on the front for a sitting cat; the front of the body, under the neck, side on
      let cx = Math.round((bb.x0 + bb.x1) / 2), cy = bb.y0 + 2;
      if (fam.side) {
        const midY = Math.floor((bb.y0 + bb.y1) / 2), wall = fam.wallX !== null;
        const ya = wall ? bb.y0 + 2 : Math.max(bb.y0, midY - 1), yb = wall ? Math.max(bb.y0 + 2, midY) : Math.max(bb.y0, bb.y1 - 1);
        let best = null;
        for (let y = ya; y <= yb; y++) for (let x = 0; x < W; x++) if ((Rg[y][x] === 'B' || Rg[y][x] === 'V') && C[y][x] && (!best || x > best[0])) best = [x, y];
        if (best) { cx = best[0] - (wall ? 1 : 2); cy = best[1]; }
      }
      R_(set, cx - 1, cy - 1, cx + 1, cy + 1, hex(0x9FE8FF)); set(cx, cy, hex(0xFFFFFF)); return;
    }
    const spec = K.costumes[id]; if (!spec) return;
    const body = hex(spec.body), belly = spec.belly ? hex(spec.belly) : body, paws = spec.paws ? hex(spec.paws) : null, legs = spec.legs ? hex(spec.legs) : null;
    paint((r) => r === 'B' || r === 'T', (x, y) => (legs && y >= fam.legTop ? legs : (L[y][x] === 'd' ? dk(body, 0.84) : body)));
    paint((r) => r === 'V', () => belly);
    if (paws) paint((r) => r === 'U', () => paws); else paint((r) => r === 'U', () => (legs || body));
    const ex = EXTRAS[id] || {};
    if (ex.stripes) { const c = hex(ex.stripes); paint((r) => r === 'B' || r === 'T' || r === 'V', (x, y) => (((fam.side ? x : y) >> 1) % 2 === 0 ? c : null)); }
    if (ex.spots) paint((r, x, y) => (r === 'B' || r === 'T') && hash(x, y, 5) % 9 === 0, (x, y) => hex(ex.spots[hash(x, y, 3) % ex.spots.length]));
    if (ex.web) { const c = hex(ex.web); paint((r, x, y) => (r === 'B' || r === 'T') && y < fam.legTop && (x % 4 === 0 || y % 4 === 0), () => c); }
    if (ex.stars) { const c = hex(ex.stars); paint((r, x, y) => (r === 'B') && hash(x, y, 11) % 12 === 0, () => c); }
    if (ex.diamonds) { const c = hex(ex.diamonds); paint((r, x, y) => (r === 'B') && (x + y) % 6 === 0 && x % 2 === 0, () => c); }
    if (ex.collar) { const c = hex(ex.collar); paint((r, x, y) => r === 'B' && y <= bb.y0 + 1, () => c); }
    if (ex.bandana) { const c = hex(ex.bandana); paint((r, x, y) => r === 'B' && y <= bb.y0 + 1, () => c); }
    if (ex.buttons) { const c = hex(ex.buttons), cx = Math.round((bb.x0 + bb.x1) / 2); set(cx - 2, bb.y0 + 2, c); set(cx + 2, bb.y0 + 2, c); }
    if (ex.bow) { const c = hex(ex.bow), cx = fam.side ? bb.x1 : Math.round((bb.x0 + bb.x1) / 2), cy = bb.y0; [-2, -1, 1, 2].forEach((d) => set(cx + d, cy, c)); set(cx, cy, dk(c, 0.7)); }
    if (ex.spikes || ex.fin) {
      const c = hex(ex.spikes || ex.fin), cols = [];
      if (fam.side && fam.wallX === null) { for (let x = bb.x0 + 1; x <= bb.x1 - 1; x += ex.fin ? 99 : 3) cols.push(x); if (ex.fin) cols.length = 0, cols.push(Math.round((bb.x0 + bb.x1) / 2)); }
      cols.forEach((x) => { const t = topEdge(C, x, 0, H - 1); if (t > 1) { set(x, t - 1, c); set(x, t - 2, c); if (ex.fin) { set(x - 1, t - 1, c); set(x + 1, t - 1, c); set(x, t - 3, c); } } });
      // tail spikes
      if (ex.spikes) for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (Rg[y][x] === 'T' && C[y][x] && y % 3 === 0) { const nx = fam.side ? x - 1 : x + 1; if (!C[y][nx]) set(nx, y, c); }
    }
    if (ex.pom) { let ex_ = null; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (Rg[y][x] === 'T' && C[y][x]) { if (!ex_ || (fam.side ? x < ex_[0] : x > ex_[0])) ex_ = [x, y]; } if (ex_) { const c = hex(ex.pom); R_(set, ex_[0] - 1, ex_[1] - 1, ex_[0] + 1, ex_[1] + 1, c); } }
  }
  const R_ = (set, x0, y0, x1, y1, c) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(x, y, c); };

  // ---------- hats ----------
  function headInfo(Rg, C) {
    let x0 = 999, x1 = -1, y0 = 999, y1 = -1;
    Rg.forEach((row, y) => row.forEach((c, x) => { if (c === 'H') { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }));
    let crown = y0; for (let y = y0; y <= y1; y++) { let n = 0; Rg[y].forEach((c) => { if (c === 'H') n++; }); if (n >= (x1 - x0 + 1) * 0.7) { crown = y; break; } }
    return { x0, x1, y0, y1, crown, cx: Math.round((x0 + x1) / 2), w: x1 - x0 + 1 };
  }

  function hat(C, L, Rg, fam, id, pal) {
    if (!id || id === 'none') return;
    const H = C.length, W = C[0].length, hd = headInfo(Rg, C), dir = fam.side ? 1 : 0;
    const set = (x, y, c) => { if (y >= 0 && y < H && x >= 0 && x < W) C[y][x] = c; };
    const box = (x0, y0, x1, y1, c) => R_(set, x0, y0, x1, y1, c);
    const col = hex;
    const headCells = (fn) => { for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (Rg[y][x] === 'H' && C[y][x]) { const c = fn(x, y, L[y][x], C[y][x]); if (c) C[y][x] = c; } };
    const clearEars = () => { for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (Rg[y][x] === 'H' && y < hd.crown) { C[y][x] = null; Rg[y][x] = null; } };
    const rimOf = (c) => dk(c, 0.72);
    // a hood: the head outside the face opening takes the colour
    const hood = (color, o) => {
      o = o || {};
      if (o.ears === 'none' || o.ears === 'round' || o.ears === 'long') clearEars();
      const rim = o.rim || rimOf(color), inner = o.inner || lt(color, 40);
      headCells((x, y, l) => {
        if (l === 'f') return o.face || null;
        if (l === 'e' || l === 'p') return null;
        if (l === 'r') return inner;
        const near = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => L[y + dy] && L[y + dy][x + dx] === 'f');
        return near ? rim : color;
      });
      if (o.ears === 'round') { const r = o.earColor || color, ri = o.earInner || null; [hd.x0 + 1, hd.x1 - 2].forEach((x) => { box(x - 0, hd.crown - 2, x + 2, hd.crown - 1, r); if (ri) set(x + 1, hd.crown - 1, ri); }); }
      if (o.ears === 'long') { const r = o.earColor || color; [hd.cx - 3, hd.cx + 1].forEach((x) => { box(x, hd.crown - 7, x + 1, hd.crown - 1, r); box(x, hd.crown - 6, x, hd.crown - 3, o.earInner || [240, 170, 190]); }); }
    };
    const topper = (rows, color, x0, y0) => rows.forEach((row, j) => [...row].forEach((ch, i) => { if (ch !== '.') set(x0 + i, y0 + j, ch === '#' ? color : ch === 'w' ? [250, 250, 250] : ch === 'y' ? [240, 192, 44] : ch === 'k' ? [40, 36, 40] : ch === 'r' ? [215, 38, 47] : color); }));
    const cx = hd.cx, cr = hd.crown, w = hd.w, hw = Math.floor(w / 2);
    const spikes = (c) => [cx - 3, cx - 1, cx + 1].forEach((x, i) => { box(x, cr - 2 - (i === 1 ? 1 : 0), x, cr - 1, c); });
    const dome = (c, trim) => { box(cx - hw + 1, cr - 2, cx + hw - 1, cr, c); box(cx - hw + 3, cr - 3, cx + hw - 3, cr - 3, c); if (trim) box(cx - hw + 1, cr - 1, cx + hw - 1, cr, trim); };
    const brim = (c, extra) => box(cx - hw - 1 + (dir ? 0 : 0), cr, cx + hw + (dir ? 2 : 1), cr, c);
    switch (id) {
      case 'crown': box(cx - hw + 2, cr - 1, cx + hw - 2, cr, col(0xF2C230)); [cx - hw + 2, cx, cx + hw - 2].forEach((x) => box(x, cr - 3, x, cr - 2, col(0xF2C230))); set(cx, cr, col(0xD7262F)); break;
      case 'party': { for (let i = 0; i < 6; i++) box(cx - 3 + Math.floor(i / 2), cr - 1 - i, cx + 3 - Math.floor(i / 2), cr - 1 - i, i % 2 ? col(0xFFEB3B) : col(0xF48FB1)); set(cx, cr - 7, col(0xFFFFFF)); break; }
      case 'bow': { const x = cx - hw + 2, c = col(0xD7262F); box(x - 2, cr - 2, x - 1, cr, c); box(x + 1, cr - 2, x + 2, cr, c); set(x, cr - 1, col(0x8E1B1B)); break; }
      case 'tophat': box(cx - hw + 1, cr - 6, cx + hw - 1, cr - 1, col(0x2A2730)); box(cx - hw - 1, cr, cx + hw + 1, cr, col(0x2A2730)); box(cx - hw + 1, cr - 2, cx + hw - 1, cr - 2, col(0xC62828)); break;
      case 'cap': hood(col(0xD7262F), { ears: 'none' }); box(cx - hw + 1, cr - 2, cx + hw - 1, cr - 1, col(0xD7262F)); box(cx + (dir ? 1 : -2), cr, cx + hw + (dir ? 2 : 0), cr, col(0x9E1B22)); set(cx, cr - 3, col(0xD7262F)); break;
      case 'santa': hood(col(0xD7262F), { ears: 'none', face: null }); box(cx - hw, cr - 1, cx + hw, cr, col(0xFFFFFF)); box(cx - hw + 1, cr - 3, cx + hw - 1, cr - 2, col(0xD7262F)); box(cx - 2, cr - 4, cx + 1, cr - 4, col(0xD7262F)); box(cx + 1, cr - 5, cx + 3, cr - 3, col(0xFFFFFF)); break;
      case 'witch': box(cx - hw - 1, cr, cx + hw + 1, cr, col(0x3B2A57)); for (let i = 0; i < 8; i++) box(cx - 2 + Math.floor(i / 3), cr - 1 - i, cx + 2 - Math.floor(i / 3), cr - 1 - i, col(0x4B3470)); box(cx - 2, cr - 2, cx + 2, cr - 2, col(0xF2C230)); break;
      case 'cowboy': box(cx - hw - 2, cr, cx + hw + 2, cr, col(0x8B5A2B)); box(cx - hw + 1, cr - 3, cx + hw - 1, cr - 1, col(0x8B5A2B)); box(cx - hw + 1, cr - 1, cx + hw - 1, cr - 1, col(0x5B3A1B)); break;
      case 'starhelm': hood(col(0x2C4A9C), { ears: 'none' }); box(cx - 1, cr + 1, cx + 1, cr + 1, col(0xFFFFFF)); set(cx, cr, col(0xFFFFFF)); set(cx, cr + 2, col(0xFFFFFF)); break;
      case 'ironhelm': hood(col(0xC62828), { ears: 'none', rim: col(0x8E1B1B) }); box(cx - hw + 1, cr + 1, cx + hw - 1, cr + 1, col(0xF2C230)); break;
      case 'shark': hood(col(0x5D7C9C), { ears: 'none' }); box(cx - 1, cr - 3, cx, cr - 1, col(0x4A6683)); set(cx - 1, cr - 4, col(0x4A6683)); break;
      case 'frog': hood(col(0x79A85A), { ears: 'round', earColor: col(0x79A85A) }); set(hd.x0 + 2, cr - 2, col(0xFFFFFF)); set(hd.x1 - 1, cr - 2, col(0xFFFFFF)); set(hd.x0 + 3, cr - 2, col(0x2A2730)); set(hd.x1, cr - 2, col(0x2A2730)); break;
      case 'spider': {
        // red mask over the head, the ears stay; web lines; big white eyes with black rims; white muzzle
        const red = col(0xD7262F), web = col(0x7A0F16), rimK = col(0x1E1A1E), white = col(0xFFFFFF);
        headCells((x, y, l) => (y < cr || l === 'p' || l === 'r' ? null : red));
        if (fam.side) {
          headCells((x, y, l) => (y >= cr && l !== 'p' && l !== 'r' && ((x - hd.x0) % 3 === 0 || (y - cr) % 3 === 2) ? web : null));
          for (let y = hd.y1 - 2; y <= hd.y1; y++) for (let x = hd.x1 - 3; x <= hd.x1; x++) if (Rg[y][x] === 'H' && C[y][x]) set(x, y, white);
          let eye = null; for (let y = 0; y < H && !eye; y++) for (let x = 0; x < W; x++) if (L[y][x] === 'e') { eye = [x, y]; break; }
          if (eye) { box(eye[0] - 2, eye[1] - 1, eye[0] + 1, eye[1] + 2, rimK); box(eye[0] - 1, eye[1], eye[0], eye[1] + 1, white); }
        } else {
          const put = (x, y, c) => { if (Rg[y + PAD_TOP][x + PAD_SIDE] === 'H' && C[y + PAD_TOP][x + PAD_SIDE]) set(x + PAD_SIDE, y + PAD_TOP, c); };
          [[7, 4], [7, 5], [7, 6], [7, 7], [7, 8], [6, 5], [5, 6], [4, 7], [8, 5], [9, 6], [10, 7], [4, 5], [10, 5], [3, 6], [11, 6], [2, 8], [12, 8], [1, 9], [13, 9], [2, 11], [13, 11]].forEach(([x, y]) => put(x, y, web));
          ['KKK..', 'KWWKK', 'KWWWK', '.KKKK'].forEach((row, j) => [...row].forEach((ch, i) => { if (ch === '.') return; const c = ch === 'K' ? rimK : white; put(2 + i, 7 + j, c); put(13 - i, 7 + j, c); }));
          for (let y = 11; y <= 12; y++) for (let x = 5; x <= 10; x++) put(x, y, white);
          put(6, 12, rimK); put(9, 12, rimK);
        }
        break;
      }
      case 'horns': hood(col(0x9AA3AD), { ears: 'none' }); [hd.x0 + 1, hd.x1 - 2].forEach((x, i) => { box(x, cr - 3, x + 1, cr - 1, col(0xF1E7D2)); set(i ? x + 2 : x - 1, cr - 4, col(0xF1E7D2)); }); break;
      case 'winged': hood(col(0xD8B24A), { ears: 'none' }); [[hd.x0 - 2, -1], [hd.x1 + 1, 1]].forEach(([x]) => { box(x, cr - 2, x + 1, cr - 1, col(0xFFFFFF)); set(x + (x < cx ? 0 : 1), cr - 3, col(0xFFFFFF)); }); break;
      case 'chick': hood(col(0xF6D44A), { ears: 'none' }); box(cx - 1, cr - 2, cx + 1, cr - 1, col(0xF6D44A)); set(cx, cr - 3, col(0xF6D44A)); break;
      case 'jester': hood(col(0x2E2A33), { ears: 'none' }); [[hd.x0, -1, 0x9B59B6], [hd.x1, 1, 0xC9A227]].forEach(([x, d, c]) => { box(x - (d > 0 ? 1 : 0), cr - 2, x + (d < 0 ? 1 : 0), cr - 1, col(c)); set(x + d * 2, cr - 3, col(0xF2C230)); }); set(cx, cr - 1, col(0x9B59B6)); break;
      case 'banana': hood(col(0xF6D84B), { ears: 'none' }); box(cx - 2, cr - 3, cx + 2, cr - 1, col(0xF6D84B)); set(cx, cr - 4, col(0x6B4A2B)); set(cx, cr - 5, col(0x6B4A2B)); break;
      case 'dino': hood(col(0x79A85A), { ears: 'none' }); spikes(col(0xF2C230)); break;
      case 'pinkdino': hood(col(0xF2A9C4), { ears: 'none' }); spikes(col(0xE04A6A)); break;
      case 'panda': hood(col(0xF4F2EE), { ears: 'round', earColor: col(0x2A2A2E) }); headCells((x, y, l) => (Math.abs(y - (cr + 4)) <= 1 && l === 'f' ? col(0x2A2A2E) : null)); break;
      case 'bunny': hood(col(0xF7F4F0), { ears: 'long', earColor: col(0xF7F4F0) }); break;
      case 'bee': hood(col(0xF4C430), { ears: 'none' }); headCells((x, y) => ((y - cr) % 4 === 1 ? col(0x4A3423) : null)); [cx - 2, cx + 1].forEach((x) => { set(x, cr - 2, col(0x4A3423)); set(x, cr - 3, col(0x4A3423)); set(x + (x < cx ? -1 : 1), cr - 4, col(0xF4C430)); }); break;
      case 'bear': hood(col(0xA7703F), { ears: 'round', earColor: col(0xA7703F), earInner: col(0x7B4F2A) }); break;
      case 'penguin': hood(col(0x2D3756), { ears: 'none', face: col(0xF4F2EE) }); if (dir) box(hd.x1, cr + 5, hd.x1 + 1, cr + 6, col(0xF0A12F)); else box(cx, cr + 6, cx + 1, cr + 7, col(0xF0A12F)); break;
      case 'merc': headCells((x, y, l) => (l === 'h' || l === 'r' ? col(0xC62828) : l === 'f' ? null : null)); headCells((x, y, l) => (l === 'f' && L[y][x] && (y <= cr + 5) ? col(0xC62828) : null)); break;
      case 'monster': hood(col(0x9B7FD1), { ears: 'none' }); [hd.x0 + 1, hd.x1 - 1].forEach((x) => { box(x - 1, cr - 3, x, cr - 1, col(0x7E62B8)); }); set(cx, cr, col(0xFFFFFF)); break;
      case 'ghost': hood(col(0xF6F4EE), { ears: 'none', rim: col(0xC9C6BC), face: col(0x2A2730) }); break;
      case 'unicorn': hood(col(0xF7F3EE), { ears: 'keep' }); for (let i = 0; i < 4; i++) set(cx, cr - 1 - i, i % 2 ? col(0xF2C230) : col(0xFFE27A)); break;
      case 'vampire': hood(col(0x2A2730), { ears: 'keep', inner: col(0x6E1015), rim: col(0x14121A) }); break;
      default: break;
    }
  }

  // ---------- assembling a cat ----------
  function build(fkey, look, eyes) {
    const fam = family(fkey), L = copy(fam.L), Rg = copy(fam.R), pal = palette(look), H = L.length, W = L[0].length;
    if (eyes !== 'open') L.forEach((row) => row.forEach((c, x) => { if (c === 'e') row[x] = 'k'; }));
    let ex = 0, en = 0; L.forEach((row) => row.forEach((c, x) => { if (c === 'e') { ex += x; en++; } }));
    coat(L, Rg, look, fam);
    const C = mk(W, H);
    const midX = fam.cx;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const c = L[y][x]; if (!c) continue; C[y][x] = c === 'e' && !fam.side && x > midX ? pal.E : (pal[c] || pal.b); }
    if (look.outfit && look.outfit !== 'none') outfit(C, Rg, fam, look.outfit, L);
    if (look.hat && look.hat !== 'none') hat(C, L, Rg, fam, look.hat, pal);
    // outline: dark, tinted by the colour it borders
    const out = copy(C), at = (x, y) => (C[y] && C[y][x]) || null;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const isK = L[y][x] === 'k' && C[y][x];
      if (C[y][x] && !isK) continue;
      const nb = [at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)].filter((c) => c && !(c === pal.k));
      if (!nb.length && !isK) continue;
      const src = nb[0] || pal.b;
      out[y][x] = dk(src, 0.36).map((v, i) => Math.max(v, [30, 28, 30][i]));
    }
    return { C: out, fam };
  }

  function rotate(g, q) {
    q = ((q % 4) + 4) % 4; let o = g;
    for (let i = 0; i < q; i++) { const H = o.length, W = o[0].length, n = mk(H, W); for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) n[W - 1 - x][y] = o[y][x]; o = n; }
    return o;
  }

  const cache = new Map();
  function sprite(look, fkey, rot, eyes) {
    const sig = [look.baseHex, look.accentHex, look.pattern, look.seed, look.eyeL, look.eyeR, look.hat, look.outfit, fkey, rot, eyes].join('|');
    let s = cache.get(sig); if (s) return s;
    if (cache.size > 600) cache.clear();
    const { C, fam } = build(fkey, look, eyes), g = rotate(C, rot);
    const H = g.length, W = g[0].length, cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    const cx = cv.getContext('2d'), id = cx.createImageData(W, H);
    let bx0 = W, bx1 = -1, by0 = H, by1 = -1;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const p = g[y][x]; if (!p) continue; const i = (y * W + x) * 4; id.data[i] = p[0]; id.data[i + 1] = p[1]; id.data[i + 2] = p[2]; id.data[i + 3] = 255; bx0 = Math.min(bx0, x); bx1 = Math.max(bx1, x); by0 = Math.min(by0, y); by1 = Math.max(by1, y); }
    cx.putImageData(id, 0, 0);
    // anchor: the middle of the feet for upright cats, the bounding box for turned ones
    const ax = rot === 0 ? (fam.wallX !== null ? fam.wallX : fam.cx) : (bx0 + bx1 + 1) / 2, ay = rot === 0 ? fam.ground + (fam.wallX !== null ? 1 : 2) : by1 + 1;   // climbers hang on the wall line
    s = { cv, ax, ay, W, H, bx0, bx1, by0, by1 }; cache.set(sig, s); return s;
  }

  // ---------- which sprite for which pose ----------
  function pick(ri, now, c) {
    const q = (a) => Math.round(a / (Math.PI / 2));
    const t = now + (c && c.tOffset ? c.tOffset : 0);
    const eyes = ['open', 'wide', 'angry', 'sleepy'].includes(ri.eyes) ? 'open' : 'closed';   // a tired cat still has its eyes open
    const walkK = (Math.floor(Math.abs(ri.phase) / (Math.PI / 2)) % 4);
    const sitK = (() => { const m = t % 6; if (m > 5.8) return 1; if (m > 3.2 && m < 3.5) return 2; if (m > 4.4 && m < 4.6) return 3; return 0; })();
    switch (ri.pose) {
      case 'walk': return { f: 'walk:' + walkK, rot: 0, eyes };
      case 'run': return { f: 'run:' + walkK, rot: 0, eyes };
      case 'stand': case 'eat': return { f: 'walk:1', rot: 0, eyes };
      case 'scratch': return { f: 'walk:' + (Math.floor(t * 6) % 2 ? 0 : 2), rot: 0, eyes };
      case 'groom': return { f: 'groom:' + (Math.floor(t * 3) % 4), rot: 0, eyes: 'closed' };
      case 'sit': case 'purr': case 'swat': case 'grumpy': return { f: 'sit:' + sitK, rot: 0, eyes: 'open' };
      case 'loaf': return { f: 'loaf:' + (Math.floor(t * 1.3) % 2), rot: 0, eyes: 'open' };
      case 'sleep': return { f: 'sleep:' + (Math.floor(t * 1.1) % 2), rot: 0, eyes: 'open' };
      case 'crouch': case 'stalk': case 'wiggle': return { f: 'loaf:' + (Math.floor(t * 2) % 2), rot: 0, eyes: 'open', shake: ri.pose === 'wiggle' ? Math.sin(t * 30) : 0 };
      case 'jump': return { f: 'jump:' + (ri.progress < 0.5 ? 0 : 1), rot: 0, eyes };
      case 'fall': return { f: 'jump:1', rot: q(ri.rotation), eyes: 'open' };
      case 'hiss': return { f: 'hiss:' + (Math.floor(t * 8) % 2), rot: 0, eyes: 'open', shake: Math.sin(t * 40) };
      // the wall is on the cat's right in the sprite; on a left wall it is mirrored
      case 'climb': return { f: 'climb:' + walkK, rot: 0, eyes, flip: ri.climbSide > 0, wall: true };
      case 'slide': return { f: 'slide:0', rot: 0, eyes: 'open', flip: ri.climbSide > 0, wall: true };
      case 'wallScratch': return { f: 'climb:' + (Math.floor(t * 6) % 2 ? 0 : 2), rot: 0, eyes };
      case 'traverse': return { f: 'walk:' + walkK, rot: 2, eyes };
      case 'hangSide': return { f: 'sit:0', rot: 0, eyes: 'open' };
      case 'hangBack': case 'dangle': return { f: 'sit:0', rot: 0, eyes: 'open' };
      case 'roll': return { f: 'sit:0', rot: q(ri.rotation), eyes: 'open' };
      default: return { f: 'sit:0', rot: 0, eyes };
    }
  }

  const cell = (scale) => Math.max(2, Math.round(1.9 * scale));

  function drawCat(ctx, c, ri, H, now) {
    const p = pick(ri, now, c), s = sprite(c.look, p.f, p.rot, p.eyes), cs = cell(c.scale);
    const flip = p.wall ? (p.flip ? -1 : 1) : (ri.facing < 0 ? -1 : 1) * (p.flip ? -1 : 1);
    ctx.save();
    ctx.imageSmoothingEnabled = false;
    ctx.translate(Math.round(c.x + (p.shake || 0) * cs * 0.5), Math.round(H - c.y));
    ctx.scale(flip, 1);
    if (ri.pose === 'jump' || ri.pose === 'fall' || ri.pose === 'dangle') ctx.translate(0, 0);
    ctx.drawImage(s.cv, -Math.round(s.ax * cs), -Math.round(s.ay * cs), s.W * cs, s.H * cs);
    ctx.restore();
  }

  /** A square picture of the sitting cat for menus. */
  function thumb(cfg, size) {
    const look = K.makeLook(cfg), s = sprite(look, 'sit:0', 0, 'open'), dpr = (typeof window !== 'undefined' && window.devicePixelRatio) || 1;
    const cv = document.createElement('canvas'); cv.width = cv.height = Math.round(size * dpr); cv.style.width = cv.style.height = size + 'px';
    const ctx = cv.getContext('2d'); ctx.imageSmoothingEnabled = false;
    const bw = s.bx1 - s.bx0 + 1, bh = s.by1 - s.by0 + 1, avail = size * dpr * 0.92;
    const k = Math.max(1, Math.floor(avail / Math.max(bw, bh))), w = bw * k, h = bh * k;
    ctx.drawImage(s.cv, s.bx0, s.by0, bw, bh, Math.round((cv.width - w) / 2), Math.round(cv.height - h - size * dpr * 0.03), w, h);
    return cv;
  }

  K.pixel = { drawCat, thumb, sprite, pick, cell };
})(globalThis.K = globalThis.K || {});
