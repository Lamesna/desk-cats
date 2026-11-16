// Hunting, screen edges, getting down, hanging under windows, stairs between windows,
// the laser, play between cats and sleeping together. Port of Hunt.swift and Play.swift.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { World, rnd, chance, pick, clamp, isWin } = K;
  const P = World.prototype;

  // =====================================================================================
  // Stalking another cat (sleeping, or with its back turned)
  // =====================================================================================
  P.tryAmbush = function (c) {
    const now = this.now;
    if (this.cats.size < 2 || now <= c.socialReady || this.laser || c.stats.energy <= 0.3 || c.surface === null || !chance(0.3)) return false;
    const targets = [...this.cats.values()].filter((t) => {
      if (t === c || t.duo || t.surface !== c.surface) return false;
      const d = Math.abs(t.x - c.x);
      if (!(d > 110 * c.scale && d < 700)) return false;
      const backTurned = t.facing * (t.x - c.x) > 0;
      return t.state === 'sleep' || (backTurned && ['sit', 'loaf', 'groom', 'eat', 'drink'].includes(t.state));
    });
    if (!targets.length) return false;
    const t = pick(targets);
    c.state = 'stalk'; c.huntTarget = t.cfg.id; c.until = now + 25; c.goal = null;
    c.socialReady = now + rnd(25, 50);
    return true;
  };

  P.abortHunt = function (c) {
    c.huntTarget = null;
    if (chance(0.5)) this.idle(c, 'groom', 2, 4); else this.idle(c, 'sit', 2, 4);   // pretend nothing happened
  };

  P.huntTargetValid = function (c) {
    const t = c.huntTarget !== null ? this.cats.get(c.huntTarget) : null;
    if (!t || t.surface === null || t.surface !== c.surface || t.duo || this.laser || this.now >= c.until) return null;
    if (!(t.state === 'sleep' || t.interruptible || t.state === 'eat' || t.state === 'drink')) return null;
    return t;
  };

  P.huntStep = function (c, dt) {
    const t = this.huntTargetValid(c);
    if (!t) { this.abortHunt(c); return; }
    const dx = t.x - c.x, now = this.now;
    c.facing = dx >= 0 ? 1 : -1;
    // the prey looks this way: freeze on the spot
    const watched = t.state !== 'sleep' && t.facing * (c.x - t.x) > 0;
    if (watched || now < c.huntPause) return;
    if (chance(dt * 0.45)) c.huntPause = now + rnd(0.4, 1.1);
    if (Math.abs(dx) < 70 * c.scale) { c.state = 'wiggle'; c.wiggleUntil = now + rnd(0.8, 1.5); return; }
    const step = 24 * c.scale * dt;
    c.x += c.facing * step;
    c.phase += step / (c.scale * 14) * 2 * PI;
  };

  P.wiggleStep = function (c) {
    const t = this.huntTargetValid(c);
    if (!t) { this.abortHunt(c); return; }
    c.facing = t.x >= c.x ? 1 : -1;
    if (this.now <= c.wiggleUntil || t.surface === null) return;
    c.pounceOn = t.cfg.id; c.huntTarget = null;
    this.startJump(c, { x: t.x - c.facing * 14 * c.scale, y: t.y }, t.surface, 34);
  };

  P.landPounce = function (c, id) {
    const t = this.cats.get(id), now = this.now;
    if (!t || t.surface !== c.surface || Math.abs(t.x - c.x) >= 80 * c.scale || t.duo) return;
    if (!(t.state === 'sleep' || t.interruptible || t.state === 'eat' || t.state === 'drink')) return;
    const wasAsleep = t.state === 'sleep';
    t.snuggleWith = null;
    if (wasAsleep && chance(0.3)) {
      // woke up grumpy: hisses, the hunter flees
      t.state = 'hiss'; t.until = now + 1.5; t.facing = c.x > t.x ? 1 : -1;
      this.startWalk(c, c.x + (c.x >= t.x ? 1 : -1) * 260, 170);
      return;
    }
    if (wasAsleep) t.say('Meow?!', 1, now);
    const d = new Duo(c, t, 'wrestle', now);
    d.approaching = false; d.mid = (c.x + t.x) / 2; d.until = now + 3.5;
    this.duos.push(d);
    for (const x of [c, t]) { x.duo = d; x.state = 'social'; x.goal = null; x.socialRot = 0; x.socialReady = now + rnd(15, 40); }
  };

  // =====================================================================================
  // Screen edges: up a side wall, then back down or drop
  // =====================================================================================
  P.pursueEdge = function (c, side) {
    const stand = side < 0 ? this.minX : this.maxX;
    if (this.navigate(c, 'ground', stand)) {
      c.goal = null; c.edgeSide = side; c.climbSide = -side;                  // body stays inside the screen
      c.edgeDescend = chance(0.5);
      c.edgeTargetX = this.groundY + (this.visible.maxY - this.visible.minY) * rnd(0.3, 0.7);   // climb to some height, not the top
      c.surface = null;
      c.x = side < 0 ? this.visible.minX : this.visible.maxX;
      c.phase = 0; c.state = 'wallClimb';
    }
    return true;
  };

  P.startEdgeTour = function (c) {
    const v = this.visible, side = c.x - v.minX < v.maxX - c.x ? -1 : 1;
    c.goal = { k: 'edge', side }; c.goalDeadline = this.now + 60;
    this.pursueEdge(c, side);
  };

  P.edgeStep = function (c, dt) {
    const s = c.scale, v = this.visible, wall = c.edgeSide < 0 ? v.minX : v.maxX;
    if (c.state === 'wallClimb') {
      c.x = wall;
      c.phase += dt * 10;
      c.y += 175 * (0.2 + 1.7 * Math.max(0, Math.sin(c.phase))) * dt * Math.sqrt(s);
      if (c.y >= Math.min(c.edgeTargetX, v.maxY - 70 * s)) {
        if (c.edgeDescend) c.state = 'wallDown';                               // climb back down the same side
        else {
          const side = c.edgeSide;
          this.startFall(c, true);                                             // push off the wall and drop
          c.vx = -side * 130; c.vy = 80; c.facing = -side;
        }
      }
    } else if (c.state === 'wallDown') {
      c.x = wall; c.phase -= dt * 8; c.y -= 95 * s * dt;
      if (c.y <= this.groundY) {
        c.surface = 'ground'; c.y = this.groundY; c.x = wall - c.edgeSide * 22 * s; c.facing = -c.edgeSide;
        this.idle(c, 'sit', 1, 2);
      }
    }
  };

  // =====================================================================================
  // Getting down from a window: jump, or slide down the side clawing at it
  // =====================================================================================
  P.getDown = function (c, toward) {
    const id = c.surface, p = isWin(id) ? this.platforms.get(id) : null;
    if (this.laser || !p || p.y - this.groundY <= 110 || !chance(0.5)) { this.jumpDown(c, toward); return; }
    // only real window sides (not a cut made by another window in front), fully on screen
    const seg = p.nearestSeg(c.x), sides = [], v = this.visible;
    if (Math.abs(seg.lo - Math.max(p.rect.minX + 4, this.minX)) < 1 && p.rect.minX > v.minX + 40 && this.sideVisible(id, true)) sides.push(-1);
    if (Math.abs(seg.hi - Math.min(p.rect.maxX - 4, this.maxX)) < 1 && p.rect.maxX < v.maxX - 40 && this.sideVisible(id, false)) sides.push(1);
    if (!sides.length) { this.jumpDown(c, toward); return; }
    sides.sort((a, b) => Math.abs((a < 0 ? seg.lo : seg.hi) - c.x) - Math.abs((b < 0 ? seg.lo : seg.hi) - c.x));
    c.slideSide = sides[0];
    c.goal = { k: 'slide', id }; c.goalDeadline = this.now + 30;
    this.pursueSlide(c);
  };

  P.pursueSlide = function (c) {
    const g = c.goal;
    const p = g && g.k === 'slide' && c.surface === g.id ? this.platforms.get(g.id) : null;
    if (!p) { c.goal = null; return false; }
    const seg = p.nearestSeg(c.x), stand = this.clampOn(g.id, c.slideSide < 0 ? seg.lo : seg.hi);
    if (Math.abs(c.x - stand) > 4) { this.startWalk(c, stand); return true; }
    // over the edge: hang on with the front claws and start sliding
    c.goal = null; c.state = 'slideDown'; c.climbWin = g.id; c.climbSide = c.slideSide; c.surface = null;
    c.x = c.slideSide < 0 ? p.rect.minX : p.rect.maxX;
    c.y = p.y - 26 * c.scale;
    c.slideV = 0; c.slideGripUntil = this.now + 0.35;
    return true;
  };

  P.slideStep = function (c, dt) {
    const s = c.scale, now = this.now, p = this.platforms.get(c.climbWin);
    if (!p) { this.startFall(c); return; }                                      // window vanished under the claws
    if (!this.sideVisible(c.climbWin, c.climbSide < 0)) { this.loseSupport(c); return; }   // covered by another window
    c.x = c.climbSide < 0 ? p.rect.minX : p.rect.maxX;
    if (now < c.slideGripUntil) c.slideV = Math.max(0, c.slideV - 1400 * dt);   // claws caught: brake hard
    else {
      c.slideV = Math.min(320, c.slideV + 700 * dt);                            // slipping down faster and faster
      if (chance(dt * 1.8)) c.slideGripUntil = now + rnd(0.15, 0.45);
    }
    c.y -= c.slideV * dt;
    c.phase += dt * (c.slideV > 20 ? 12 : 2);
    const bottom = Math.max(this.groundY, p.rect.minY);
    if (c.y <= bottom + 6) {
      if (bottom <= this.groundY + 1) {
        c.surface = 'ground'; c.y = this.groundY; c.x = c.x + c.climbSide * 18 * s; c.facing = c.climbSide;
        this.idle(c, 'crouch', 0.3, 0.4);
      } else {
        // the window hangs above the floor: swing under it, or push off and drop
        const side = c.climbSide, r = this.windowRects.get(c.climbWin);
        if (chance(0.5) && r && r.minY - this.groundY > 70 * s) {
          c.underWin = c.climbWin;
          c.underOffset = side < 0 ? 16 * s : r.width - 16 * s;
          c.underLegs = 0;
          c.y = r.minY - 56 * s;
          this.beginUnder(c);
          return;
        }
        this.startFall(c, true);
        c.vx = side * 90; c.vy = 60; c.facing = side;
      }
    }
  };

  // =====================================================================================
  // Visibility: only use edges that no other window covers
  // =====================================================================================
  P.visibleBottomSegs = function (id) {
    const i = this.zRects.findIndex((z) => z[0] === id);
    if (i < 0) return [];
    const r = this.zRects[i][1];
    let segs = [{ lo: Math.max(r.minX + 10, this.minX), hi: Math.min(r.maxX - 10, this.maxX) }];
    for (let j = 0; j < i; j++) {
      const o = this.zRects[j][1];
      if (o.minY < r.minY + 6 && o.maxY > r.minY - 6) segs = this.subtract(segs, o.minX - 8, o.maxX + 8);
    }
    return segs.filter((s) => s.hi - s.lo > 60);
  };

  /** Is the left or right side of this window in plain view, not hidden behind another window? */
  P.sideVisible = function (id, left) {
    const i = this.zRects.findIndex((z) => z[0] === id);
    if (i < 0) return true;
    const r = this.zRects[i][1], x = left ? r.minX : r.maxX;
    const lo = Math.max(r.minY, this.groundY) + 8, hi = r.maxY - 8;
    for (let j = 0; j < i; j++) {
      const o = this.zRects[j][1];
      if (o.minX - 3 <= x && o.maxX + 3 >= x && o.minY < hi && o.maxY > lo) return false;
    }
    return true;
  };

  // =====================================================================================
  // Hanging from the bottom edge of a window, paw over paw
  // =====================================================================================
  const distTo = (x, s) => (x < s.lo ? s.lo - x : (x > s.hi ? x - s.hi : 0));

  P.tryUnder = function (c) {
    const s = c.scale;
    let best = null;
    for (const [id, r] of this.zRects) {
      const gap = r.minY - this.groundY;
      if (!(gap > 75 * s && gap < 300 && r.width > 140)) continue;
      for (const seg of this.visibleBottomSegs(id)) {
        const d = distTo(c.x, seg);
        if (!best || d < best.dist) best = { id, seg, dist: d };
      }
    }
    if (!best) return false;
    c.goal = { k: 'under', id: best.id };
    c.goalX = Math.min(Math.max(c.x, best.seg.lo + 20 * s), best.seg.hi - 20 * s);
    c.goalDeadline = this.now + 30;
    return this.pursueUnder(c, best.id);
  };

  P.pursueUnder = function (c, id) {
    const r = this.windowRects.get(id);
    if (!r || c.surface !== 'ground' || !(r.minY - this.groundY > 70 * c.scale) || !this.visibleBottomSegs(id).length) { c.goal = null; return false; }
    if (!this.navigate(c, 'ground', c.goalX)) return true;
    // only grab the part of the edge that is in plain view
    if (!this.visibleBottomSegs(id).some((s) => c.x >= s.lo && c.x <= s.hi)) { c.goal = null; return false; }
    c.goal = null; c.underWin = id; c.underOffset = c.x - r.minX; c.underLegs = 0;
    this.startJump(c, { x: c.x, y: r.minY - 56 * c.scale }, 'ground', 20);
    c.jumpToUnder = true;
    return true;
  };

  P.beginUnder = function (c) {
    const r = this.windowRects.get(c.underWin);
    if (!r) { this.startFall(c, true); return; }
    c.surface = null; c.state = 'underWin'; c.underOffset = c.x - r.minX;
    this.pickUnderTarget(c, r);
  };

  P.pickUnderTarget = function (c, r) {
    const s = c.scale, segs = this.visibleBottomSegs(c.underWin);
    // stay on the uncovered stretch of the edge the cat is hanging from
    let cur = null, bd = Infinity;
    for (const g of segs) { const d = distTo(c.x, g); if (d < bd) { bd = d; cur = g; } }
    if (!cur) { c.underTarget = c.underOffset; return; }
    const lo = cur.lo + 16 * s - r.minX, hi = cur.hi - 16 * s - r.minX;
    if (!(hi > lo)) { c.underTarget = c.underOffset; return; }
    let t = rnd(lo, hi);
    if (Math.abs(t - c.underOffset) < 80) t = c.underOffset < (lo + hi) / 2 ? hi : lo;
    c.underTarget = t;
  };

  P.underStep = function (c, dt) {
    const s = c.scale, r = this.windowRects.get(c.underWin);
    if (!r) { this.startFall(c); return; }                                       // window closed: down it goes
    if (r.minY - this.groundY < 50 * s) { this.startFall(c, true); return; }
    // another window now covers this part of the edge: let go
    if (!this.visibleBottomSegs(c.underWin).some((g) => c.x >= g.lo - 14 && c.x <= g.hi + 14)) { this.loseSupport(c); return; }
    const dx = c.underTarget - c.underOffset, step = 40 * s * dt;
    if (Math.abs(dx) <= step) {
      // a neighbouring window with its bottom edge in line: keep going paw over paw
      const right = c.facing > 0;
      const nearEnd = right ? c.underOffset > r.width - 40 * s : c.underOffset < 40 * s;
      let next = null;
      if (nearEnd) {
        for (const [nid, r2] of this.windowRects) {
          if (nid !== c.underWin && Math.abs(r2.minY - r.minY) < 8 && (right ? Math.abs(r2.minX - r.maxX) < 14 : Math.abs(r2.maxX - r.minX) < 14) &&
            this.visibleBottomSegs(nid).length) { next = [nid, r2]; break; }
        }
      }
      if (next) {
        const [nid, nr] = next;
        const segs = this.visibleBottomSegs(nid).sort((a, b) => Math.abs((a.lo + a.hi) / 2 - c.x) - Math.abs((b.lo + b.hi) / 2 - c.x));
        const seg = segs[0];
        c.underWin = nid; c.underOffset = c.x - nr.minX;
        const lo = seg.lo + 16 * s - nr.minX, hi = seg.hi - 16 * s - nr.minX;
        c.underTarget = right ? Math.max(lo, hi) : Math.min(lo, hi);
        return;
      }
      c.underLegs += 1;
      if (c.underLegs >= 2 || chance(0.5)) {
        const side = c.facing;
        this.startFall(c, true);                                                 // let go and drop to the floor
        c.vx = side * 50; c.vy = 0;
        return;
      }
      this.pickUnderTarget(c, r);
    } else {
      c.facing = dx > 0 ? 1 : -1;
      c.underOffset += c.facing * step;
      c.phase += step / (s * 12) * 2 * PI;
    }
    c.x = r.minX + c.underOffset;                                                // follows the window if it is moved
    c.y = r.minY - 56 * s;
  };

  // =====================================================================================
  // Scratching the side of the screen like a scratching post
  // =====================================================================================
  P.startWallScratch = function (c) {
    const v = this.visible, side = c.x - v.minX < v.maxX - c.x ? -1 : 1;
    c.goal = { k: 'scratchWall', side }; c.goalDeadline = this.now + 40;
    this.pursueWallScratch(c, side);
  };

  P.pursueWallScratch = function (c, side) {
    const stand = side < 0 ? this.minX : this.maxX;
    if (!this.navigate(c, 'ground', stand)) return true;
    c.goal = null; c.facing = side;
    const wall = side < 0 ? this.visible.minX : this.visible.maxX;
    c.x = wall - side * 18 * c.scale;                                            // front paws reach the very edge
    c.state = 'wallScratch'; c.until = this.now + rnd(3, 5);
    return true;
  };

  // =====================================================================================
  // Travelling between windows like stairs
  // =====================================================================================
  /** Where a cat on `a` can jump to land on `b`, if it is close enough (up to a step, down to a drop). */
  P.hop = function (a, b) {
    const dy = b.y - a.y;
    let best = null;
    for (const sa of a.segs) {
      const la = sa.lo + 14, ha = sa.hi - 14;
      if (ha < la) continue;
      for (const sb of b.segs) {
        const lb = sb.lo + 14, hb = sb.hi - 14;
        if (hb < lb) continue;
        let fromX, toX;
        if (ha < lb) { fromX = ha; toX = lb; }
        else if (hb < la) { fromX = la; toX = hb; }
        else { const x = (Math.max(la, lb) + Math.min(ha, hb)) / 2; fromX = x; toX = x; }   // overlap: straight up or down
        const d = Math.abs(toX - fromX);
        const ok = dy > 0 ? (dy <= 150 && d <= 220) : (-dy <= 520 && d <= 300);
        if (ok && (!best || d < best.d)) best = { fromX, toX, d };
      }
    }
    return best;
  };

  P.neighbors = function (a) { return this.platformList.filter((p) => p.id !== a.id && this.hop(a, p)); };

  /** First window to hop to on the way to `goal`, searching a few steps ahead. */
  P.nextHop = function (a, goal, depth) {
    depth = depth || 5;
    const visited = new Set([a.id]);
    let queue = [];
    for (const n of this.neighbors(a)) {
      if (n.id === goal) return n;
      visited.add(n.id); queue.push([n, n]);
    }
    for (let d = 1; queue.length && d < depth; d++) {
      const next = [];
      for (const [node, first] of queue) {
        for (const n of this.neighbors(node)) {
          if (visited.has(n.id)) continue;
          if (n.id === goal) return first;
          visited.add(n.id); next.push([n, first]);
        }
      }
      queue = next;
    }
    return null;
  };

  /** Every platform a cat on `a` can reach by hopping, within a few steps. */
  P.reachablePlatforms = function (a, depth) {
    depth = depth || 5;
    const visited = new Set([a.id]);
    let frontier = [a];
    const out = [];
    for (let i = 0; i < depth; i++) {
      const next = [];
      for (const node of frontier) {
        for (const n of this.neighbors(node)) {
          if (visited.has(n.id)) continue;
          visited.add(n.id); out.push(n); next.push(n);
        }
      }
      frontier = next;
      if (!frontier.length) break;
    }
    return out.filter((p) => p.segs.some((s) => s.hi - s.lo > 70));
  };

  // =====================================================================================
  // Losing the footing: fall, or catch the window in front
  // =====================================================================================
  P.loseSupport = function (c) {
    if (this.now > c.grabReadyAt && chance(0.55) && this.grabFrontWindow(c)) return;
    this.startFall(c);
  };

  /** Jump sideways onto the nearest uncovered side of a window that now surrounds the cat,
   *  cling to it in the middle of the window and climb to its top. */
  P.grabFrontWindow = function (c) {
    const s = c.scale, bx = c.x, by = c.y + 20 * s;
    let best = null;
    for (const [id, r] of this.zRects) {
      const p = this.platforms.get(id);
      if (!p || !(bx >= r.minX - 60 && bx <= r.maxX + 60 && by >= r.minY - 40 && by <= r.maxY + 40) || !(p.y - by > 30)) continue;
      for (const left of [true, false]) {
        if (!this.sideVisible(id, left)) continue;
        const edge = left ? r.minX : r.maxX;
        if (!(edge > this.minX - 1 && edge < this.maxX + 1)) continue;
        const d = Math.abs(bx - edge);
        if (!best || d < best.d) best = { p, left, d };
      }
    }
    if (!best) return false;
    const side = best.left ? -1 : 1, seg = best.p.nearestSeg(c.x), edge = best.left ? seg.lo : seg.hi;
    const grabY = Math.min(Math.max(c.y, best.p.rect.minY + 24 * s), best.p.y - 70 * s);
    c.goal = null; c.grabReadyAt = this.now + 4; c.climbWin = best.p.id; c.climbSide = side;
    this.startJump(c, { x: edge, y: grabY }, 'ground', 14);
    c.jDur = 0.28 + best.d / 1100;
    c.jumpToClimb = true;
    c.say('Meow!', 1, this.now);
    return true;
  };

  // =====================================================================================
  // Hunting the laser: leap, catch, hang (one cat at a time, right under the dot)
  // =====================================================================================
  P.freeHangSlot = function (prefer) {
    return [...this.cats.values()].some((c) => c.state === 'hang') ? null : 2;
  };

  P.catchLeap = function (c) {
    const s = c.scale, dir = this.mouse.x >= c.x ? 1 : -1;
    this.startJump(c, { x: this.mouse.x - dir * 20 * s, y: this.mouse.y - 22 * s }, 'ground', 24);
    c.catchJump = true;
  };

  /** Called every frame of a catch leap. True when the cat got hold of the cursor. */
  P.tryCatch = function (c) {
    const s = c.scale, m = this.mouse;
    if (!(Math.hypot(c.x + c.facing * 24 * s - m.x, c.y + 20 * s - m.y) < 36 * s)) return false;
    const slot = this.freeHangSlot(c.x < m.x ? 0 : 1);
    if (slot === null) return false;
    c.catchJump = false; c.state = 'hang'; c.hangSlot = slot; c.surface = null;
    c.until = this.now + rnd(4, 9);
    c.swing = 0; c.swingV = -c.facing * 2.5;                                      // momentum of the leap
    c.say('Meow!', 1.2, this.now);
    c.stats.fun = Math.min(1, c.stats.fun + 0.15);
    return true;
  };

  P.updateHang = function (c, dt) {
    const s = c.scale, m = this.mouse, now = this.now;
    // Pendulum hanging from the cursor: moving the cursor accelerates the pivot,
    // the body lags behind, swings back and slowly settles.
    const L = 48 * s;
    const ax = clamp(this.mouseAcc.x, -40000, 40000), ay = clamp(this.mouseAcc.y, -40000, 40000);
    const g = Math.max(300, 1900 + ay);
    const alpha = -(g / L) * Math.sin(c.swing) - (ax / L) * Math.cos(c.swing) - 1.6 * c.swingV;
    c.swingV += alpha * dt;
    c.swing += c.swingV * dt;
    if (Math.abs(c.swing) > 1.35) { c.swing = c.swing > 0 ? 1.35 : -1.35; c.swingV *= -0.3; }
    if (c.hangSlot === 0) { c.facing = 1; c.x = m.x - 16 * s; c.y = m.y - 56 * s; }
    else if (c.hangSlot === 1) { c.facing = -1; c.x = m.x + 16 * s; c.y = m.y - 56 * s; }
    else { c.x = m.x; c.y = m.y - 56 * s; }
    const shaken = Math.hypot(this.mouseVel.x, this.mouseVel.y) > 3500;
    if (!this.laser || now > c.until || shaken) {
      this.startFall(c, !shaken);
      c.vx = this.mouseVel.x * 0.25 + c.swingV * L * Math.cos(c.swing) * 0.6;
      c.vy = clamp(this.mouseVel.y * 0.25, -300, 300);
      c.swing = 0; c.swingV = 0;
      if (shaken) c.say('Meow!!', 1.2, now, true);
      c.leapReady = now + 2;
    }
  };

  // =====================================================================================
  // Play between cats
  // =====================================================================================
  class Duo {
    constructor(a, b, kind, now) {
      this.a = a; this.b = b; this.kind = kind; this.approaching = true;
      this.until = now + 10; this.deadline = now + 30; this.mid = 0; this.runner = a; this.runX = 0; this.chaseStart = 0; this.ended = false;
    }
  }
  K.Duo = Duo;

  P.trySocial = function (c) {
    const now = this.now;
    if (this.cats.size < 2 || now <= c.socialReady || this.laser || c.stats.energy <= 0.25 || c.surface === null || !chance(0.35)) return false;
    const ok = ['sit', 'loaf', 'groom', 'walk'];
    const others = [...this.cats.values()].filter((o) => o !== c && !o.duo && o.surface === c.surface && now > o.socialReady &&
      ok.includes(o.state) && o.stats.energy > 0.2 && Math.abs(o.x - c.x) < 700);
    if (!others.length) return false;
    const o = pick(others), r = Math.random();
    const kind = r < 0.3 ? 'sniff' : r < 0.55 ? 'boxing' : r < 0.8 ? 'chase' : 'wrestle';
    const d = new Duo(c, o, kind, now);
    this.duos.push(d);
    for (const x of [c, o]) { x.duo = d; x.state = 'social'; x.goal = null; x.socialPose = 'walk'; x.socialEyes = 'open'; x.socialRot = 0; }
    if (kind === 'chase') this.startChase(d, o);
    return true;
  };

  P.startChase = function (d, runner) {
    const chaser = runner === d.a ? d.b : d.a, dir = runner.x >= chaser.x ? 1 : -1, surf = runner.surface === null ? 'ground' : runner.surface;
    d.kind = 'chase'; d.approaching = false; d.runner = runner;
    d.runX = this.clampOn(surf, runner.x + dir * rnd(250, 600));
    if (Math.abs(d.runX - runner.x) < 80) d.runX = this.clampOn(surf, runner.x - dir * rnd(250, 600));   // cornered: run the other way
    d.chaseStart = this.now; d.until = this.now + 7;
    runner.say('Meow!', 1.2, this.now);
  };

  P.endDuo = function (d) {
    d.ended = true;
    for (const c of [d.a, d.b]) {
      c.duo = null; c.socialReady = this.now + rnd(15, 40); c.socialRot = 0;
      if (c.state === 'social') pick([() => this.idle(c, 'sit', 2, 4), () => this.idle(c, 'groom', 3, 5), () => this.idle(c, 'loaf', 4, 8)])();
    }
  };

  /** Moves a cat toward x on its surface; true when it got there. */
  P.moveSocial = function (c, x0, speed, dt) {
    const x = this.clampOn(c.surface === null ? 'ground' : c.surface, x0), dx = x - c.x, step = speed * c.scale * dt;
    if (Math.abs(dx) <= step) { c.x = x; return true; }
    c.facing = dx > 0 ? 1 : -1;
    c.x += c.facing * step;
    c.phase += step / (c.scale * (speed > 100 ? 34 : 22)) * 2 * PI;
    c.socialPose = speed > 100 ? 'run' : 'walk';
    c.socialEyes = 'open';
    return false;
  };

  P.updateDuos = function (dt) {
    for (const d of this.duos) {
      if (d.ended) continue;
      const a = d.a, b = d.b;
      if (!(a.state === 'social' && b.state === 'social' && a.surface !== null && a.surface === b.surface &&
        this.cats.get(a.cfg.id) === a && this.cats.get(b.cfg.id) === b && !this.laser && this.now < d.deadline)) { this.endDuo(d); continue; }
      this.stepDuo(d, dt);
    }
    this.duos = this.duos.filter((d) => !d.ended);
  };

  P.stepDuo = function (d, dt) {
    const now = this.now;
    const [l, r] = d.a.x <= d.b.x ? [d.a, d.b] : [d.b, d.a];
    const gap = 31 * (l.scale + r.scale) / 2, t = now;

    if (d.approaching) {
      const mid = this.clampOn(l.surface, (l.x + r.x) / 2);
      const okL = this.moveSocial(l, mid - gap / 2, 80, dt), okR = this.moveSocial(r, mid + gap / 2, 80, dt);
      if (okL && okR) {
        d.approaching = false; d.mid = mid; l.facing = 1; r.facing = -1;
        if (d.kind === 'sniff') d.until = now + 2.5;
        else if (d.kind === 'boxing' || d.kind === 'wrestle') d.until = now + 3.5;
      }
      return;
    }

    switch (d.kind) {
      case 'sniff':
        for (const c of [l, r]) { c.socialPose = 'stand'; c.socialEyes = 'closed'; }
        l.facing = 1; r.facing = -1;
        if (now > d.until - 1 && Math.floor(now * 3) % 2 === 0 && l.hearts.length < 2) l.hearts.push({ born: now, dx: rnd(-6, 6) });
        if (now > d.until) {
          const x = Math.random();
          if (x < 0.35) { d.kind = 'boxing'; d.until = now + 3.5; }
          else if (x < 0.55) this.startChase(d, chance(0.5) ? l : r);
          else this.endDuo(d);
        }
        break;
      case 'boxing':
        l.facing = 1; r.facing = -1;
        for (const c of [l, r]) { c.socialPose = 'swat'; c.socialEyes = 'wide'; }
        l.x = d.mid - gap / 2 + Math.sin(t * 3) * 3;
        r.x = d.mid + gap / 2 + Math.sin(t * 3 + 1) * 3;
        if (chance(dt * 0.8)) (chance(0.5) ? l : r).say(pick(['Meow!', 'Mew!']), 0.7, now);
        if (now > d.until) { if (chance(0.6)) { d.kind = 'wrestle'; d.until = now + 3.5; } else this.startChase(d, chance(0.5) ? l : r); }
        break;
      case 'wrestle': {
        const center = this.clampOn(l.surface, d.mid + Math.sin(t * 2.2) * 30);
        l.x = center - 7 * l.scale * Math.cos(t * 5);
        r.x = center + 7 * r.scale * Math.cos(t * 5);
        l.socialRot += dt * 9; r.socialRot -= dt * 9;
        for (const c of [l, r]) { c.socialPose = 'roll'; c.socialEyes = chance(0.5) ? 'angry' : 'closed'; }
        if (chance(dt * 0.7)) (chance(0.5) ? l : r).say(pick(['Meow!', 'Meeow!']), 0.6, now);
        if (now > d.until) {
          l.socialRot = 0; r.socialRot = 0;
          if (chance(0.5)) this.startChase(d, chance(0.5) ? l : r); else this.endDuo(d);
        }
        break;
      }
      case 'chase': {
        const runner = d.runner, chaser = runner === l ? r : l;
        l.socialRot = 0; r.socialRot = 0;
        const arrived = this.moveSocial(runner, d.runX, 160, dt);
        const dir = runner.x >= chaser.x ? 1 : -1;
        this.moveSocial(chaser, runner.x - dir * 18 * chaser.scale, 172, dt);
        if (Math.abs(runner.x - chaser.x) < 24 * chaser.scale && now > d.chaseStart + 1.2) { d.kind = 'wrestle'; d.mid = runner.x; d.until = now + 3; }
        else if (arrived || now > d.until) this.endDuo(d);
        break;
      }
      default: break;
    }
  };

  /** A grumpy cat hisses at anyone who comes too close; they back off. */
  P.grumpyHiss = function (c) {
    if (this.now <= c.lastHiss + 2.5) return;
    for (const o of this.cats.values()) {
      if (o !== c && o.surface === c.surface && o.interruptible && Math.abs(o.x - c.x) < 70 * c.scale) {
        c.lastHiss = this.now;
        c.facing = o.x > c.x ? 1 : -1;
        this.startWalk(o, o.x + (o.x > c.x ? 1 : -1) * 220, 150);
        return;
      }
    }
  };

  // =====================================================================================
  // Sleeping together
  // =====================================================================================
  /** A free spot right next to a sleeping cat (cats curl up touching, faces together). */
  P.snuggleSpot = function (c, t) {
    if (t.surface === null) return null;
    const gap = 40 * (c.scale + t.scale) / 2, first = c.x < t.x ? -1 : 1;
    for (const side of [first, -first]) {
      const x = t.x + side * gap;
      if (Math.abs(this.clampOn(t.surface, x) - x) > 6) continue;
      const busy = [...this.cats.values()].some((o) => o !== c && o !== t && o.surface === t.surface && Math.abs(o.x - x) < 18 * o.scale);
      if (!busy) return x;
    }
    return null;
  };

  /** Go curl up next to someone who is already asleep. */
  P.joinSleeper = function (c, p) {
    if (!chance(p) || c.surface === null) return false;
    const sleepers = [...this.cats.values()].filter((o) => o !== c && o.state === 'sleep' && o.surface !== null && this.snuggleSpot(c, o) !== null);
    if (!sleepers.length) return false;
    // prefer someone on the same surface, then the closest
    const cost = (o) => (o.surface === c.surface ? 0 : 2000) + Math.abs(o.x - c.x);
    sleepers.sort((a, b) => cost(a) - cost(b));
    const t = sleepers[0];
    c.goal = { k: 'snuggle', id: t.cfg.id }; c.goalDeadline = this.now + 45;
    if (!this.pursueSnuggle(c, t.cfg.id)) { c.goal = null; return false; }
    return true;
  };

  P.pursueSnuggle = function (c, id) {
    const t = this.cats.get(id), spot = t && t.state === 'sleep' && t.surface !== null ? this.snuggleSpot(c, t) : null;
    if (!t || spot === null) { c.goal = null; return false; }
    if (this.navigate(c, t.surface, spot, 40)) {
      c.goal = null;
      c.facing = t.x > c.x ? 1 : -1;
      this.startSleep(c);
      // fall asleep and wake up roughly together
      const end = Math.max(c.until, t.until) + rnd(0, 10);
      c.until = end; t.until = end + rnd(-5, 5);
      c.snuggleWith = id; t.snuggleWith = c.cfg.id;
      c.hearts.push({ born: this.now, dx: 0 });
    }
    return true;
  };
})(globalThis.K = globalThis.K || {});
