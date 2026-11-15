// The cats' world: windows as platforms, cats, bowls, mouse handling and the per-frame update.
// Port of World.swift (core). Movement helpers and decisions are in world-brain.js, hunting and play in world-play.js.
//
// Coordinates are y-up with the origin at the bottom-left corner of the screen (like the macOS app).
// A surface is null (in the air), 'ground', or a number (the id of the window the cat stands on).
(function (K) {
  'use strict';
  const PI = Math.PI;

  const rnd = (a, b) => a + Math.random() * (b - a);
  const chance = (p) => Math.random() < p;
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
  const isWin = (s) => typeof s === 'number';

  // ---------- platforms (tops of windows) ----------
  class Platform {
    constructor(id, rect, segs) { this.id = id; this.rect = rect; this.segs = segs; }
    get y() { return this.rect.maxY; }
    contains(x, tol) { tol = tol === undefined ? 3 : tol; return this.segs.some((s) => x >= s.lo - tol && x <= s.hi + tol); }
    nearestSeg(x) {
      let best = this.segs[0], bd = Infinity;
      for (const s of this.segs) { const d = x < s.lo ? s.lo - x : (x > s.hi ? x - s.hi : 0); if (d < bd) { bd = d; best = s; } }
      return best;
    }
    clampX(x, inset) {
      inset = inset === undefined ? 10 : inset;
      const s = this.nearestSeg(x), lo = s.lo + inset, hi = s.hi - inset;
      return lo > hi ? (s.lo + s.hi) / 2 : clamp(x, lo, hi);
    }
  }

  let nextBowlId = 1;
  class Bowl {
    constructor(kind, x, y) { this.id = nextBowlId++; this.kind = kind; this.x = x; this.y = y; this.surface = null; this.vy = 0; this.amount = 1; }
  }

  const SOLID_STATES = new Set(['sit', 'loaf', 'groom', 'sleep', 'scratch', 'walk', 'purr', 'crouch', 'grumpy',
    'hiss', 'eat', 'drink', 'stalk', 'wiggle', 'social', 'wallScratch']);
  const INTERRUPTIBLE = new Set(['sit', 'loaf', 'groom', 'walk', 'scratch', 'purr', 'crouch']);

  // ---------- one cat ----------
  class Cat {
    constructor(cfg, x, y, now) {
      this.cfg = cfg; this.look = K.makeLook(cfg);
      this.x = x; this.y = y;
      this.surface = null; this.state = 'fall'; this.until = 0;
      this.facing = 1; this.phase = 0; this.targetX = 0; this.speed = 50;
      this.climbWin = 0; this.climbSide = -1;
      this.jFrom = { x: 0, y: 0 }; this.jTo = { x: 0, y: 0 }; this.jStart = 0; this.jDur = 0.5; this.jH = 40; this.jTarget = 'ground';
      this.jumpToClimb = false; this.catchJump = false; this.leapReady = 0; this.hangSlot = 0;
      this.duo = null; this.socialPose = 'walk'; this.socialEyes = 'open'; this.socialRot = 0; this.socialReady = rnd(0, 20); this.lastHiss = 0;
      this.snuggleWith = null; this.swing = 0; this.swingV = 0;
      this.huntTarget = null; this.huntPause = 0; this.wiggleUntil = 0; this.pounceOn = null;
      this.edgeSide = -1; this.edgeTargetX = 0; this.edgeDescend = false;
      this.slideSide = -1; this.slideV = 0; this.slideGripUntil = 0;
      this.jumpToUnder = false; this.grabReadyAt = 0; this.underWin = 0; this.underOffset = 0; this.underTarget = 0; this.underLegs = 0;
      this.vx = 0; this.vy = -100; this.fallStartY = y; this.gentle = true;
      this.goal = null; this.goalX = 0; this.goalDeadline = 0;
      this.stats = { food: 0.8, water: 0.8, energy: 0.8, fun: 0.7, mood: 'Roaming' };
      this.bubble = null; this.bubbleUntil = 0; this.bubbleAlert = false;
      this.hearts = []; this.hoverTime = 0; this.lastHeart = 0; this.blinkAt = now + 2;
      this.tOffset = rnd(0, 100);
    }
    get scale() { return this.cfg.size; }
    say(text, secs, now, alert) { this.bubble = K.tr(text); this.bubbleUntil = now + secs; this.bubbleAlert = !!alert; }
    get bodyRect() {
      const s = this.scale, x = this.x, y = this.y;
      switch (this.state) {
        case 'dragged': return K.R(x - 16 * s, y - 4 * s, 32 * s, 58 * s);
        case 'hang': case 'underWin': return K.R(x - 16 * s, y - 2 * s, 32 * s, 60 * s);
        case 'climb': case 'wallClimb': case 'wallDown': case 'slideDown':
          return K.R(x - (this.climbSide < 0 ? 26 : 2) * s, y - 8 * s, 28 * s, 58 * s);
        default: return K.R(x - 28 * s, y - 2 * s, 56 * s, 46 * s);
      }
    }
    get interruptible() { return INTERRUPTIBLE.has(this.state); }
  }

  // ---------- the world ----------
  class World {
    /**
     * @param opts.width,opts.height  size of the screen in px
     * @param opts.visible            usable area {minX,minY,maxX,maxY} (the taskbar is outside), y-up
     */
    constructor(opts) {
      this.W = opts.width; this.H = opts.height;
      this.visible = opts.visible || { minX: 0, minY: 0, maxX: opts.width, maxY: opts.height };
      this.now = 0; this.tickCount = 0;
      this.cats = new Map(); this.bowls = [];
      this.platforms = new Map(); this.platformList = [];
      this.zRects = []; this.deskIDs = new Set(); this.windowRects = new Map();
      this.mouse = { x: 0, y: 0 }; this.mouseVel = { x: 0, y: 0 }; this.mouseAcc = { x: 0, y: 0 }; this.rawMouseVel = { x: 0, y: 0 };
      this.duos = [];
      this.running = true; this.laser = false; this.placing = null;
      this.dragCat = null; this.dragBowl = null; this.dragOffset = { x: 0, y: 0 }; this.dragSamples = [];
      this.lastStats = 0;
      this.events = { stats: null, bowls: null };
    }

    get groundY() { return this.visible.minY; }
    get minX() { return this.visible.minX + 34; }
    get maxX() { return this.visible.maxX - 34; }

    setVisible(v) { this.visible = v; }

    // ----- windows -----
    /**
     * @param list windows front to back: {id, x, y, w, h} (y = bottom edge, y-up); `desk: true` marks widgets
     */
    setWindows(list) {
      const rects = [], desk = [];
      for (const w of list) {
        const r = K.R(w.x, w.y, w.w, w.h);
        if (w.desk) desk.push([w.id, r]); else rects.push([w.id, r]);
      }
      this.deskIDs = new Set(desk.map((d) => d[0]));
      const deskStart = rects.length;
      this.windowRects = new Map(rects.concat(desk));
      this.zRects = rects.concat(desk);
      const all = rects.concat(desk);
      const result = [];
      all.forEach(([id, r], i) => {
        const y = r.maxY;
        // widgets may sit right under the top edge; the cat then pokes up over it
        const ceiling = i >= deskStart ? this.H - 36 : this.visible.maxY - 48;
        if (!(y < ceiling && y > this.groundY + 50)) return;
        let segs = [{ lo: Math.max(r.minX + 4, this.minX), hi: Math.min(r.maxX - 4, this.maxX) }];
        for (let j = 0; j < i; j++) {
          const o = all[j][1];
          if (o.minY < y + 36 && o.maxY > y - 2) segs = this.subtract(segs, o.minX - 6, o.maxX + 6);
        }
        segs = segs.filter((s) => s.hi - s.lo > 44);
        if (segs.length) result.push(new Platform(id, r, segs));
      });
      // carry riders along with moving windows
      const newMap = new Map(result.map((p) => [p.id, p]));
      for (const [id, old] of this.platforms) {
        const n = newMap.get(id);
        if (!n) continue;
        const dx = n.rect.minX - old.rect.minX;
        if (dx === 0) continue;
        for (const c of this.cats.values()) if (c.surface === id || (c.state === 'climb' && c.climbWin === id)) c.x += dx;
        for (const b of this.bowls) if (b.surface === id) b.x += dx;
      }
      this.platforms = newMap;
      this.platformList = result;
    }

    subtract(segs, a, b) {
      const out = [];
      for (const s of segs) {
        if (b <= s.lo || a >= s.hi) { out.push(s); continue; }
        if (a > s.lo) out.push({ lo: s.lo, hi: a });
        if (b < s.hi) out.push({ lo: b, hi: s.hi });
      }
      return out;
    }

    surfaceY(s) { return s === 'ground' ? this.groundY : (isWin(s) && this.platforms.has(s) ? this.platforms.get(s).y : null); }
    clampOn(s, x) {
      if (s === 'ground') return clamp(x, this.minX, this.maxX);
      const p = this.platforms.get(s);
      return p ? p.clampX(x, 12) : x;
    }
    landing(x, y0, y1) {
      let best = null;
      for (const p of this.platformList) {
        if (p.y <= y0 + 0.5 && p.y >= y1 && p.contains(x, 0) && (!best || p.y > best.y)) best = { surface: p.id, y: p.y };
      }
      if (!best && y1 <= this.groundY) best = { surface: 'ground', y: this.groundY };
      return best;
    }
    surfaceUnder(m) {
      let best = null;
      for (const p of this.platformList) {
        if (p.y <= m.y + 8 && m.y - p.y < 170 && p.contains(m.x, 0) && (!best || p.y > best.y)) best = p;
      }
      return best ? best.id : 'ground';
    }

    /** A platform worth visiting. Real windows first; widgets only when the cat can get there. */
    randomPlatform(c) {
      let all = this.platformList.filter((p) => p.segs.some((s) => s.hi - s.lo > 70));
      if (c && c.surface === 'ground') all = all.filter((p) => this.canReachFromGround(p, c));
      const wins = all.filter((p) => !this.deskIDs.has(p.id));
      if (wins.length && (wins.length === all.length || chance(0.85))) return pick(wins);
      return all.length ? pick(all) : null;
    }
    /** Can a cat on the floor get onto this platform (hop up, or leap onto its side and climb)? */
    canReachFromGround(p, c) {
      if (p.y - this.groundY < 150) return true;
      const gap = p.rect.minY - this.groundY;
      if (gap > 450) return false;
      const off = (gap > 20 ? 55 : 4) * c.scale;
      return p.segs.some((s) => (s.lo - off >= this.minX - 1 && this.sideVisible(p.id, true)) ||
        (s.hi + off <= this.maxX + 1 && this.sideVisible(p.id, false)));
    }

    // ----- config sync -----
    setCats(cfgs) {
      const wanted = new Set(cfgs.filter((c) => c.visible).map((c) => c.id));
      for (const id of [...this.cats.keys()]) if (!wanted.has(id)) this.cats.delete(id);
      for (const cfg of cfgs) {
        if (!cfg.visible) continue;
        const c = this.cats.get(cfg.id);
        if (c) {
          if (JSON.stringify(c.cfg) !== JSON.stringify(cfg)) { c.cfg = cfg; c.look = K.makeLook(cfg); }
        } else {
          const x = rnd(this.minX + 40, Math.max(this.minX + 41, this.maxX - 40));
          const n = new Cat(cfg, x, this.visible.maxY - 70, this.now);
          this.cats.set(cfg.id, n);
        }
      }
    }

    // ----- bowls -----
    bowlAction(a) {
      if (a === 'refillFood') this.bowls.filter((b) => b.kind === 'food').forEach((b) => { b.amount = 1; });
      else if (a === 'refillWater') this.bowls.filter((b) => b.kind === 'water').forEach((b) => { b.amount = 1; });
      else if (a === 'clear') this.bowls = [];
      else if (a === 'feedAll') for (const c of this.cats.values()) { c.stats.food = 1; c.stats.water = 1; c.say('Meow~', 2, this.now); }
      if (this.events.bowls) this.events.bowls(this.bowls.length);
    }
    addBowl(kind, p) {
      this.bowls.push(new Bowl(kind, clamp(p.x, this.minX, this.maxX), p.y));
      if (this.events.bowls) this.events.bowls(this.bowls.length);
      for (const c of this.cats.values()) if (c.interruptible) c.until = 0;    // hungry cats notice right away
    }
    nearestBowl(kind, c) {
      let best = null, bd = Infinity;
      for (const b of this.bowls) {
        if (b.kind !== kind || b.amount <= 0.01 || b.surface === null) continue;
        const d = Math.hypot(b.x - c.x, b.y - c.y);
        if (d < bd) { bd = d; best = b; }
      }
      return best;
    }
    updateBowl(b, dt) {
      if (b === this.dragBowl) return;
      if (b.surface !== null) {
        if (isWin(b.surface)) {
          const p = this.platforms.get(b.surface);
          if (p && p.contains(b.x, 4)) b.y = p.y; else { b.surface = null; b.vy = 0; }
        } else b.y = this.groundY;
        return;
      }
      const y0 = b.y;
      b.vy -= 1800 * dt;
      b.y += b.vy * dt;
      const l = this.landing(b.x, y0, b.y);
      if (l) { b.surface = l.surface; b.y = l.y; b.vy = 0; }
    }

    // ----- mouse -----
    catAt(p) { for (const c of this.cats.values()) { const r = c.bodyRect; if (p.x >= r.minX && p.x <= r.maxX && p.y >= r.minY && p.y <= r.maxY) return c; } return null; }
    bowlAt(p) { return this.bowls.find((b) => p.x >= b.x - 20 && p.x <= b.x + 20 && p.y >= b.y - 2 && p.y <= b.y + 22) || null; }

    /** Should the overlay catch mouse clicks right now? (Everything else passes through to your apps.) */
    wantsMouse(modifierHeld) {
      return !!this.placing || !!this.dragCat || !!this.dragBowl || (modifierHeld && (!!this.catAt(this.mouse) || !!this.bowlAt(this.mouse)));
    }

    mouseEvent(kind, p) {
      const now = this.now;
      if (kind === 'down') {
        if (this.placing) { this.addBowl(this.placing, p); this.placing = null; if (this.events.placed) this.events.placed(); return; }
        const c = this.catAt(p);
        if (c) {
          this.dragCat = c;
          c.state = 'dragged'; c.surface = null; c.goal = null; c.jumpToClimb = false; c.catchJump = false; c.jumpToUnder = false;
          c.say('Meow?!', 1.5, now);
          this.dragOffset = { x: 0, y: 44 * c.scale };
          c.x = p.x; c.y = p.y - this.dragOffset.y;
        } else {
          const b = this.bowlAt(p);
          if (b) { this.dragBowl = b; b.surface = null; this.dragOffset = { x: p.x - b.x, y: p.y - b.y }; }
        }
        this.dragSamples = [{ p, t: now }];
      } else if (kind === 'dragged') {
        this.dragSamples.push({ p, t: now });
        if (this.dragSamples.length > 8) this.dragSamples.shift();
        if (this.dragCat) { this.dragCat.x = p.x - this.dragOffset.x; this.dragCat.y = p.y - this.dragOffset.y; }
        if (this.dragBowl) { this.dragBowl.x = p.x - this.dragOffset.x; this.dragBowl.y = p.y - this.dragOffset.y; }
      } else if (kind === 'up') {
        let vx = 0, vy = 0;
        const s = this.dragSamples;
        if (s.length > 1 && s[s.length - 1].t - s[0].t > 0.01) {
          const dt = s[s.length - 1].t - s[0].t;
          vx = clamp((s[s.length - 1].p.x - s[0].p.x) / dt, -1400, 1400);
          vy = clamp((s[s.length - 1].p.y - s[0].p.y) / dt, -1400, 1400);
        }
        const c = this.dragCat;
        if (c) { c.state = 'fall'; c.vx = vx; c.vy = vy; c.fallStartY = c.y; c.gentle = false; }
        if (this.dragBowl) { this.dragBowl.surface = null; this.dragBowl.vy = 0; }
        this.dragCat = null; this.dragBowl = null;
      } else if (kind === 'rightDown') {
        this.placing = null;
        if (this.events.placed) this.events.placed();
      }
    }

    // ----- main step -----
    tick(now, mouse, leftDown) {
      if (!this.running) return;
      const dt = Math.min(1 / 20, Math.max(0, now - (this.lastTick || now)));
      this.lastTick = now; this.now = now; this.tickCount++;
      if (dt > 0) {
        const vx = (mouse.x - this.mouse.x) / dt, vy = (mouse.y - this.mouse.y) / dt;
        this.mouseVel = { x: this.mouseVel.x * 0.6 + vx * 0.4, y: this.mouseVel.y * 0.6 + vy * 0.4 };
        const ax = (vx - this.rawMouseVel.x) / dt, ay = (vy - this.rawMouseVel.y) / dt;
        this.mouseAcc = { x: this.mouseAcc.x * 0.5 + ax * 0.5, y: this.mouseAcc.y * 0.5 + ay * 0.5 };
        this.rawMouseVel = { x: vx, y: vy };
      }
      this.mouse = { x: mouse.x, y: mouse.y };
      // the button was released but the event never reached us
      if ((this.dragCat || this.dragBowl) && !leftDown) this.mouseEvent('up', this.mouse);
      this.updateDuos(dt);
      for (const b of this.bowls) this.updateBowl(b, dt);
      for (const c of this.cats.values()) this.update(c, dt);

      if (now - this.lastStats > 1) {
        this.lastStats = now;
        if (this.events.stats) {
          const d = {};
          for (const c of this.cats.values()) d[c.cfg.id] = Object.assign({}, c.stats);
          this.events.stats(d);
        }
      }
    }

    // ----- the cat's per-frame brain -----
    update(c, dt) {
      const f = dt, now = this.now, s = c.stats;
      // needs
      s.food = Math.max(0, s.food - dt / 1800);
      s.water = Math.max(0, s.water - dt / 1500);
      s.fun = Math.max(0, s.fun - dt / 1200);
      if (c.state === 'sleep') s.energy = Math.min(1, s.energy + dt / 70); else s.energy = Math.max(0, s.energy - dt / 900);
      s.mood = this.mood(c);

      if (c.bubble && now > c.bubbleUntil) c.bubble = null;
      if (c.state !== 'sleep') c.snuggleWith = null;
      else if (c.snuggleWith !== null && chance(dt * 0.12)) c.hearts.push({ born: now, dx: 0 });
      c.hearts = c.hearts.filter((h) => now - h.born <= 1.6);

      if (c.state === 'dragged') { c.phase += f * 4; return; }
      if (c.state === 'hang') { this.updateHang(c, dt); return; }
      if (c.surface === null && SOLID_STATES.has(c.state)) this.startFall(c, true);

      // support check
      if (c.surface !== null && c.state !== 'climb' && c.state !== 'jump' && c.state !== 'fall') {
        if (c.surface === 'ground') {
          c.y = this.groundY;
          if (c.state !== 'wallScratch') c.x = clamp(c.x, this.minX, this.maxX);
        } else {
          const p = this.platforms.get(c.surface);
          if (p && p.contains(c.x, 6)) c.y = p.y; else this.loseSupport(c);
        }
      }

      // laser pointer
      if (this.laser && s.energy > 0.08) {
        const near = Math.hypot(this.mouse.x - c.x, this.mouse.y - c.y) < 130;
        if (c.interruptible || ((c.state === 'sleep' || c.state === 'eat' || c.state === 'drink') && near)) this.laserChase(c, dt);
      } else {
        this.petting(c, dt);
      }

      switch (c.state) {
        case 'walk': {
          const dx = c.targetX - c.x, step = c.speed * f;
          if (Math.abs(dx) <= step) {
            c.x = c.targetX;
            if (this.laser) { c.state = 'crouch'; c.until = now + 1; } else this.decide(c);
          } else {
            c.facing = dx > 0 ? 1 : -1;
            c.x += c.facing * step;
            c.phase += step / (c.scale * (c.speed > 100 * c.scale ? 34 : 22)) * 2 * PI;   // longer strides when running
          }
          break;
        }
        case 'climb': {
          const p = this.platforms.get(c.climbWin);
          if (!p) { this.startFall(c); break; }
          if (!this.sideVisible(c.climbWin, c.climbSide < 0)) { this.loseSupport(c); break; }
          const seg = p.nearestSeg(c.x);
          c.x = c.climbSide < 0 ? seg.lo : seg.hi;
          // scramble in bursts: hind legs push, front paws grab
          c.phase += f * 10;
          const surge = 0.2 + 1.7 * Math.max(0, Math.sin(c.phase));
          c.y += 175 * surge * f * Math.sqrt(c.scale);
          if (c.y >= p.y - 30 * c.scale) {
            c.surface = c.climbWin; c.y = p.y;
            c.x = c.x - c.climbSide * 16 * c.scale;
            c.facing = -c.climbSide;
            c.state = 'sit'; c.until = now + 0.6;
          }
          break;
        }
        case 'jump': {
          const u = clamp((now - c.jStart) / c.jDur, 0, 1);
          c.x = c.jFrom.x + (c.jTo.x - c.jFrom.x) * u;
          c.y = c.jFrom.y + (c.jTo.y - c.jFrom.y) * u + Math.sin(u * PI) * c.jH;
          if (c.catchJump) {
            if (this.tryCatch(c)) break;
            if (u >= 1) {
              // missed (or no free spot on the cursor): drop back down
              c.catchJump = false;
              this.startFall(c, true);
              c.vx = c.facing * 40;
              if (chance(0.3)) c.say('Meow!', 0.8, now);
            }
            break;
          }
          if (c.jumpToUnder) { if (u >= 1) { c.jumpToUnder = false; this.beginUnder(c); } break; }
          if (u >= 1 && c.jumpToClimb) {
            // landed on the side of a window: grab it and start climbing
            c.jumpToClimb = false;
            const p = this.platforms.get(c.climbWin);
            if (p) { const seg = p.nearestSeg(c.x); c.x = c.climbSide < 0 ? seg.lo : seg.hi; c.state = 'climb'; c.phase = 0; }
            else this.startFall(c, true);
          } else if (u >= 1) {
            const y = this.surfaceY(c.jTarget);
            const ok = y !== null && (c.jTarget === 'ground' || (this.platforms.get(c.jTarget) && this.platforms.get(c.jTarget).contains(c.x, 6)));
            if (ok) {
              c.surface = c.jTarget; c.y = y;
              c.state = 'crouch'; c.until = now + (this.laser ? 1 : 0.22);       // absorb the landing
              if (c.pounceOn !== null) { const id = c.pounceOn; c.pounceOn = null; this.landPounce(c, id); }
            } else this.startFall(c, true);
          }
          break;
        }
        case 'fall': {
          const y0 = c.y;
          c.vy -= 1900 * f;
          c.x += c.vx * f; c.y += c.vy * f;
          if (c.x < this.minX) { c.x = this.minX; c.vx = Math.abs(c.vx) * 0.5; }
          if (c.x > this.maxX) { c.x = this.maxX; c.vx = -Math.abs(c.vx) * 0.5; }
          if (c.y > this.visible.maxY - 30 && c.vy > 0) c.vy = 0;
          if (c.vy <= 0) {
            const l = this.landing(c.x, y0, c.y);
            if (l) {
              c.surface = l.surface; c.y = l.y;
              const h = c.fallStartY - l.y;
              if (!c.gentle && h > 130) { c.state = 'hiss'; c.until = now + 1.7; s.fun = Math.max(0, s.fun - 0.1); }
              else { c.state = 'sit'; c.until = now + 0.8; }
              c.vx = 0; c.vy = 0; c.gentle = true;
            }
          }
          break;
        }
        case 'hiss':
          if (now > c.until) { c.state = 'grumpy'; c.until = now + 2.6; }
          break;
        case 'eat': case 'drink':
          if (now > c.until) {
            const eating = c.state === 'eat';
            if (eating) s.food = 1; else s.water = 1;
            const kind = eating ? 'food' : 'water';
            let best = null;
            for (const b of this.bowls) if (b.kind === kind && (!best || Math.abs(b.x - c.x) < Math.abs(best.x - c.x))) best = b;
            if (best) best.amount = Math.max(0, best.amount - 0.25);
            s.fun = Math.min(1, s.fun + 0.1);
            c.hearts.push({ born: now, dx: 0 });
            c.state = 'groom'; c.until = now + 3;
          }
          break;
        case 'purr':
          s.fun = Math.min(1, s.fun + dt * 0.06);
          if (now > c.until) this.decide(c);
          break;
        case 'sleep':
          if (now > c.until || (s.energy >= 1 && c.snuggleWith === null)) { c.state = 'sit'; c.until = now + 2; c.say('Meow~', 1.2, now); }
          break;
        case 'scratch':
          s.fun = Math.min(1, s.fun + dt * 0.02);
          if (now > c.until) this.decide(c);
          break;
        case 'grumpy':
          this.grumpyHiss(c);
          if (now > c.until) this.decide(c);
          break;
        case 'sit': case 'loaf': case 'groom': case 'crouch':
          if (now > c.until) this.decide(c);
          break;
        case 'stalk': this.huntStep(c, dt); break;
        case 'wiggle': this.wiggleStep(c); break;
        case 'wallClimb': case 'wallDown': this.edgeStep(c, dt); break;
        case 'underWin': this.underStep(c, dt); break;
        case 'slideDown': this.slideStep(c, dt); break;
        case 'wallScratch':
          s.fun = Math.min(1, s.fun + dt * 0.02);
          if (now > c.until) this.decide(c);
          break;
        default: break;   // dragged, hang, social: handled elsewhere
      }
    }

    mood(c) {
      switch (c.state) {
        case 'sleep': return 'Sleeping 💤';
        case 'hiss': case 'grumpy': return 'Offended 💢';
        case 'eat': return 'Eating';
        case 'drink': return 'Drinking';
        case 'purr': return 'Purring ♥';
        case 'scratch': return 'Sharpening claws';
        case 'climb': return 'Climbing up';
        case 'dragged': return 'Dangling';
        case 'crouch': return 'Hunting';
        case 'hang': return 'Hanging on the cursor';
        case 'stalk': return 'Stalking';
        case 'wiggle': return 'About to pounce';
        case 'wallClimb': case 'wallDown': return 'Climbing the screen edge';
        case 'underWin': return 'Hanging under a window';
        case 'slideDown': return 'Sliding down';
        case 'wallScratch': return 'Scratching the screen edge';
        case 'social': {
          const k = c.duo && c.duo.kind;
          return k === 'sniff' ? 'Sniffing noses' : k === 'boxing' ? 'Boxing' : k === 'wrestle' ? 'Play-fighting' : k === 'chase' ? 'Playing tag' : 'Playing';
        }
        default: break;
      }
      const s = c.stats;
      if (s.food < 0.3) return 'Hungry';
      if (s.water < 0.3) return 'Thirsty';
      if (s.energy < 0.25) return 'Sleepy';
      if (s.fun < 0.25) return 'Bored';
      return c.surface === 'ground' ? 'Roaming' : 'Sitting on a window';
    }

    startFall(c, gentle) {
      c.state = 'fall'; c.surface = null; c.vx = 0; c.vy = 0; c.fallStartY = c.y;
      c.gentle = !!gentle; c.goal = null; c.jumpToClimb = false; c.catchJump = false; c.pounceOn = null; c.huntTarget = null; c.jumpToUnder = false;
    }
  }

  Object.assign(K, { World, Cat, Bowl, Platform, rnd, chance, pick, clamp, isWin, INTERRUPTIBLE });
})(globalThis.K = globalThis.K || {});
