// Movement helpers, navigation between surfaces, decisions, laser chase, petting, render info.
// Port of the second half of World.swift.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { World, rnd, chance, pick, clamp, isWin } = K;
  const P = World.prototype;

  P.startWalk = function (c, x, speed) {
    if (c.surface === null) return;
    c.targetX = this.clampOn(c.surface, x);
    c.speed = (speed === undefined ? 46 : speed) * c.scale;
    c.state = 'walk';
  };

  P.startJump = function (c, to, target, height) {
    c.jFrom = { x: c.x, y: c.y };
    c.jTo = { x: to.x, y: to.y };
    c.jStart = this.now + 0.1;                           // short crouch before take-off
    const d = Math.hypot(to.x - c.x, to.y - c.y);
    c.jDur = 0.32 + d / 900;
    c.jH = height === undefined ? Math.max(20, (to.y - c.y) * 0.35 + 30) : height;
    c.jTarget = target;
    c.facing = to.x >= c.x ? 1 : -1;
    c.surface = null;
    c.state = 'jump';
  };

  P.jumpDown = function (c, toward) {
    const tx = clamp(c.x + (toward >= c.x ? 50 : -50), this.minX, this.maxX);
    this.startJump(c, { x: tx, y: this.groundY }, 'ground', 26);
  };

  P.idle = function (c, state, lo, hi) { c.state = state; c.until = this.now + rnd(lo, hi); };

  P.startSleep = function (c, short) {
    c.state = 'sleep';
    c.until = this.now + (short ? rnd(15, 30) : rnd(40, 120));
  };

  /** Returns true when the cat stands on `s` at `tx`; otherwise starts the next step toward it. */
  P.navigate = function (c, s, tx0, speed) {
    const cur = c.surface;
    if (cur === null) return false;
    const tx = this.clampOn(s, tx0);
    if (cur === s) {
      if (Math.abs(c.x - tx) < 4) return true;
      this.startWalk(c, tx, speed);
      return false;
    }
    if (isWin(cur) && s === 'ground') {
      this.getDown(c, tx);
    } else if (cur === 'ground' && isWin(s)) {
      const id = s, p = this.platforms.get(id);
      if (!p) return false;
      const seg = p.nearestSeg(c.x), height = p.y - this.groundY;
      if (height < 150) {
        const inside = p.clampX(c.x, 16);
        if (Math.abs(inside - c.x) < 70) this.startJump(c, { x: inside, y: p.y }, s);
        else this.startWalk(c, inside + (c.x < inside ? -50 : 50), speed);
        return false;
      }
      // window hangs above the floor: run up and leap onto its side
      const gap = p.rect.minY - this.groundY, floating = gap > 20;
      if (floating && gap > 450) { c.goal = null; return false; }      // too high to leap from the floor
      const off = (floating ? 55 : 4) * c.scale;
      const leftOK = seg.lo - off >= this.minX - 1 && this.sideVisible(id, true);
      const rightOK = seg.hi + off <= this.maxX + 1 && this.sideVisible(id, false);
      if (!leftOK && !rightOK) { c.goal = null; return false; }        // no room to stand beside it
      let useLeft = Math.abs(c.x - seg.lo) < Math.abs(c.x - seg.hi);
      if (useLeft && !leftOK) useLeft = false;
      if (!useLeft && !rightOK) useLeft = true;
      const edge = useLeft ? seg.lo : seg.hi, side = useLeft ? -1 : 1, base = edge + side * off;
      if (Math.abs(c.x - base) > 5) {
        this.startWalk(c, base, speed);
      } else if (floating) {
        c.climbWin = id; c.climbSide = side;
        const grabY = Math.min(p.rect.minY + 20, p.y - 40 * c.scale);
        this.startJump(c, { x: edge, y: grabY }, 'ground', 26);
        c.jDur = 0.3 + Math.min(1.0, (grabY - this.groundY) / 900);
        c.jumpToClimb = true;
      } else {
        c.state = 'climb'; c.climbWin = id; c.climbSide = side; c.surface = null; c.x = edge; c.phase = 0;
      }
    } else if (isWin(cur) && isWin(s)) {
      const pa = this.platforms.get(cur);
      if (!pa || !this.platforms.has(s)) { this.jumpDown(c, tx); return false; }
      // walk to the right edge, hop to the next window on the way (like climbing stairs)
      const q = this.nextHop(pa, s), h = q && this.hop(pa, q);
      if (q && h) {
        if (Math.abs(c.x - h.fromX) > 6) {
          this.startWalk(c, h.fromX, speed);
        } else {
          const d = Math.abs(h.toX - h.fromX), dy = q.y - pa.y;
          this.startJump(c, { x: h.toX, y: q.y }, q.id, 26 + Math.min(50, d * 0.25) + Math.max(0, dy * 0.6));
        }
        return false;
      }
      this.getDown(c, tx);                                            // no way across: go down and climb up from the floor
    }
    return false;
  };

  P.pursueGoal = function (c) {
    const g = c.goal, now = this.now;
    if (!g) return false;
    switch (g.k) {
      case 'snuggle': return this.pursueSnuggle(c, g.id);
      case 'edge': return this.pursueEdge(c, g.side);
      case 'slide': return this.pursueSlide(c);
      case 'under': return this.pursueUnder(c, g.id);
      case 'scratchWall': return this.pursueWallScratch(c, g.side);
      case 'eat': case 'drink': {
        const b = this.bowls.find((x) => x.id === g.id);
        if (!b || b.amount <= 0.01 || b.surface === null) { c.goal = null; return false; }
        const side = c.x < b.x ? -1 : 1, tx = b.x + side * 21 * c.scale;
        if (this.navigate(c, b.surface, tx, 70)) {
          c.facing = -side;
          c.state = g.k === 'eat' ? 'eat' : 'drink';
          c.until = now + 4;
          c.goal = null;
        }
        return true;
      }
      case 'visit': case 'sleepUp': {
        if (!this.platforms.has(g.id)) { c.goal = null; return false; }
        if (c.surface === g.id) {
          const sleepy = g.k === 'sleepUp';
          c.goal = null;
          if (sleepy) this.startSleep(c);
          else pick([() => this.idle(c, 'loaf', 6, 14), () => this.startSleep(c, true), () => this.idle(c, 'scratch', 2.5, 4), () => this.idle(c, 'sit', 3, 6)])();
          return true;
        }
        this.navigate(c, g.id, c.goalX);
        return true;
      }
      default: return false;
    }
  };

  P.decide = function (c) {
    const now = this.now, s = c.stats;
    if (c.goal) {
      if (now > c.goalDeadline) c.goal = null; else if (this.pursueGoal(c)) return;
    }
    const setGoal = (g, x) => {
      c.goal = g; c.goalX = x || 0; c.goalDeadline = now + 45;
      if (!this.pursueGoal(c)) this.idle(c, 'sit', 2, 4);
    };
    let b;
    if (s.food < 0.35 && (b = this.nearestBowl('food', c))) { setGoal({ k: 'eat', id: b.id }); return; }
    if (s.water < 0.35 && (b = this.nearestBowl('water', c))) { setGoal({ k: 'drink', id: b.id }); return; }
    if (s.food < 0.25 && chance(0.5)) { c.say('Meow!', 2.5, now); this.idle(c, 'sit', 3, 5); return; }
    if (s.water < 0.25 && chance(0.5)) { c.say('Meow!', 2.5, now); this.idle(c, 'sit', 3, 5); return; }
    if (s.energy < 0.25) {
      if (this.joinSleeper(c, 0.85)) return;
      if (isWin(c.surface)) { this.startSleep(c); return; }
      const p = this.randomPlatform(c);
      if (p && chance(0.75)) { setGoal({ k: 'sleepUp', id: p.id }, p.clampX(rnd(p.rect.minX, p.rect.maxX), 30)); return; }
      this.startSleep(c); return;
    }
    if (s.energy < 0.6 && this.joinSleeper(c, 0.25)) return;
    if (this.tryAmbush(c)) return;
    if (this.trySocial(c)) return;
    if (c.surface === 'ground' && chance(0.04)) { this.startEdgeTour(c); return; }
    if (c.surface === 'ground' && chance(0.06)) { this.startWallScratch(c); return; }
    if (c.surface === 'ground' && chance(0.12) && this.tryUnder(c)) return;
    const r = Math.random();
    if (c.surface === 'ground') {
      let p;
      if (r < 0.32) this.startWalk(c, rnd(this.minX, this.maxX));
      else if (r < 0.58 && (p = this.randomPlatform(c))) setGoal({ k: 'visit', id: p.id }, p.clampX(rnd(p.rect.minX, p.rect.maxX), 30));
      else if (r < 0.72) this.idle(c, 'sit', 3, 7);
      else if (r < 0.84) this.idle(c, 'loaf', 5, 12);
      else if (r < 0.89) this.idle(c, 'groom', 3, 5);
      else if (r < 0.95) this.idle(c, 'scratch', 2.5, 4);                 // claws on the bottom edge of the screen
      else if (!this.joinSleeper(c, 0.6)) this.startSleep(c, true);
    } else if (isWin(c.surface) && this.platforms.has(c.surface)) {
      const p = this.platforms.get(c.surface);
      let q;
      if (r < 0.22) this.startWalk(c, rnd(p.rect.minX, p.rect.maxX));
      else if (r < 0.42) { if (!this.joinSleeper(c, 0.5)) this.startSleep(c); }
      else if (r < 0.57) this.idle(c, 'loaf', 6, 14);
      else if (r < 0.71) this.idle(c, 'scratch', 2.5, 4);
      else if (r < 0.80) this.idle(c, chance(0.5) ? 'sit' : 'groom', 3, 6);
      else if (r < 0.91 && (q = pick(this.reachablePlatforms(p)))) setGoal({ k: 'visit', id: q.id }, q.clampX(rnd(q.rect.minX, q.rect.maxX), 30));
      else this.getDown(c, c.x + rnd(-100, 100));
    } else {
      this.idle(c, 'sit', 1, 2);
    }
  };

  P.laserChase = function (c, dt) {
    if (c.surface === null) return;
    const now = this.now, m = this.mouse, ts = this.surfaceUnder(m);
    c.stats.fun = Math.min(1, c.stats.fun + dt * 0.04);
    c.goal = null;
    const up = m.y - c.y;
    if (now > c.leapReady && Math.abs(m.x - c.x) < 150 * c.scale && up > 75 && up < 460 && chance(dt * 2.5)) {
      c.leapReady = now + rnd(0.7, 1.6);
      this.catchLeap(c);
      return;
    }
    if (c.surface === ts) {
      const tx = this.clampOn(ts, m.x), dx = tx - c.x;
      if (Math.abs(dx) > 16 * c.scale) {
        this.startWalk(c, tx, 190);
      } else {
        if (c.state !== 'crouch') c.state = 'crouch';
        c.until = now + 1;
        c.facing = m.x >= c.x ? 1 : -1;
        if (m.y - c.y < 80 && chance(dt * 1.6)) this.startJump(c, { x: this.clampOn(ts, m.x + c.facing * 12), y: c.y }, ts, 30);
      }
    } else {
      this.navigate(c, ts, m.x, 190);
    }
  };

  P.petting = function (c, dt) {
    const now = this.now, r = c.bodyRect, m = this.mouse;
    const pettable = c.interruptible || c.state === 'sleep';
    if (pettable && m.x >= r.minX && m.x <= r.maxX && m.y >= r.minY && m.y <= r.maxY && !this.dragCat) c.hoverTime += dt;
    else c.hoverTime = Math.max(0, c.hoverTime - dt * 2);
    if (c.hoverTime <= 0.5) return;
    if (c.state !== 'sleep') {
      if (c.state !== 'purr') c.state = 'purr';
      c.until = now + 1.5;
    }
    c.stats.fun = Math.min(1, c.stats.fun + dt * 0.08);
    if (now - c.lastHeart > 0.45) { c.lastHeart = now; c.hearts.push({ born: now, dx: rnd(-12, 12) }); }
  };

  /** Everything the renderer needs to draw this cat right now. */
  P.renderInfo = function (c) {
    const now = this.now;
    const ri = {
      pose: 'sit', facing: c.facing, phase: c.phase, t: now + c.tOffset, eyes: 'open', look: { x: 0, y: 0 },
      mouthOpen: false, climbSide: -1, rotation: 0, shake: 0, blush: false, swing: 0, progress: 0,
    };
    switch (c.state) {
      case 'walk': ri.pose = c.speed > 100 * c.scale ? 'run' : 'walk'; break;
      case 'sit': ri.pose = 'sit'; break;
      case 'loaf': ri.pose = 'loaf'; break;
      case 'groom': ri.pose = 'groom'; ri.eyes = 'closed'; break;
      case 'sleep': ri.pose = 'sleep'; ri.eyes = 'closed'; break;
      case 'scratch': ri.pose = 'scratch'; ri.eyes = 'happy'; break;
      case 'climb': ri.pose = 'climb'; ri.climbSide = c.climbSide; break;
      case 'jump': {
        const u = (now - c.jStart) / c.jDur;
        if (u < 0) ri.pose = 'crouch';                                      // gathering before the take-off
        else {
          ri.pose = 'jump'; ri.progress = u;
          ri.rotation = 0.3 * Math.cos(u * PI) * (c.jTo.y >= c.jFrom.y ? 1 : 0.6);
        }
        ri.eyes = 'wide';
        break;
      }
      case 'fall': ri.pose = 'fall'; ri.eyes = 'wide'; ri.mouthOpen = true; ri.rotation = Math.sin(ri.t * 7) * 0.22; break;
      case 'hiss': ri.pose = 'hiss'; ri.eyes = 'angry'; ri.mouthOpen = true; ri.shake = 0.9; break;
      case 'grumpy': ri.pose = 'grumpy'; ri.eyes = 'angry'; break;
      case 'eat': case 'drink': ri.pose = 'eat'; ri.eyes = 'closed'; break;
      case 'purr': ri.pose = 'purr'; ri.eyes = 'happy'; ri.blush = true; break;
      case 'dragged': ri.pose = 'dangle'; ri.eyes = 'wide'; break;
      case 'crouch': ri.pose = 'crouch'; ri.eyes = 'wide'; break;
      case 'hang': ri.pose = c.hangSlot === 2 ? 'hangBack' : 'hangSide'; ri.eyes = c.hangSlot === 1 ? 'happy' : 'wide'; ri.swing = c.swing; break;
      case 'stalk': ri.pose = 'stalk'; ri.eyes = 'wide'; break;
      case 'wiggle': ri.pose = 'wiggle'; ri.eyes = 'wide'; break;
      case 'wallClimb': case 'wallDown': ri.pose = 'climb'; ri.climbSide = c.climbSide; break;
      case 'wallScratch': ri.pose = 'wallScratch'; ri.eyes = 'happy'; break;
      case 'slideDown': ri.pose = 'slide'; ri.eyes = 'wide'; ri.climbSide = c.climbSide; ri.progress = Math.min(1, c.slideV / 320); break;
      case 'underWin': ri.pose = 'traverse'; ri.swing = Math.sin(c.phase) * 0.12; break;
      case 'social': ri.pose = c.socialPose; ri.eyes = c.socialEyes; ri.rotation = c.socialRot; ri.blush = !!c.duo && c.duo.kind === 'sniff'; break;
      default: break;
    }
    if (ri.eyes === 'open') {
      if (now > c.blinkAt + 0.14) c.blinkAt = now + rnd(2.5, 6);
      if (now > c.blinkAt) ri.eyes = 'closed';
      else if (c.stats.energy < 0.2) ri.eyes = 'sleepy';
    }
    const prey = (c.state === 'stalk' || c.state === 'wiggle') && c.huntTarget !== null ? this.cats.get(c.huntTarget) : null;
    if (prey) {
      const dx = prey.x - c.x, dy = prey.y - c.y, l = Math.max(1, Math.hypot(dx, dy));
      ri.look = { x: dx / l, y: dy / l };
    } else if (this.laser || c.state === 'crouch') {
      const dx = this.mouse.x - c.x, dy = this.mouse.y - (c.y + 28 * c.scale), l = Math.max(1, Math.hypot(dx, dy));
      ri.look = { x: dx / l, y: dy / l };
    }
    return ri;
  };
})(globalThis.K = globalThis.K || {});
