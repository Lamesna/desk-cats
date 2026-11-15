import AppKit

extension World {

    // MARK: - Stalking another cat (sleeping, or with its back turned)

    func tryAmbush(_ c: Cat) -> Bool {
        guard cats.count > 1, now > c.socialReady, !app.laser, c.stats.energy > 0.3, let surf = c.surface,
              Double.random(in: 0...1) < 0.3 else { return false }
        let targets = cats.values.filter { t in
            guard t !== c, t.duo == nil, t.surface == surf else { return false }
            let d = abs(t.pos.x - c.pos.x)
            guard d > 110 * c.scale, d < 700 else { return false }
            let backTurned = t.facing * (t.pos.x - c.pos.x) > 0
            return t.state == .sleep || (backTurned && [.sit, .loaf, .groom, .eat, .drink].contains(t.state))
        }
        guard let t = targets.randomElement() else { return false }
        c.state = .stalk
        c.huntTarget = t.cfg.id
        c.until = now + 25
        c.goal = .none
        c.socialReady = now + Double.random(in: 25...50)
        return true
    }

    func abortHunt(_ c: Cat) {
        c.huntTarget = nil
        // pretend nothing happened
        Bool.random() ? idle(c, .groom, 2...4) : idle(c, .sit, 2...4)
    }

    private func huntTargetValid(_ c: Cat) -> Cat? {
        guard let id = c.huntTarget, let t = cats[id], t.surface != nil, t.surface == c.surface, t.duo == nil,
              !app.laser, now < c.until,
              t.state == .sleep || t.interruptible || t.state == .eat || t.state == .drink else { return nil }
        return t
    }

    func huntStep(_ c: Cat, _ dt: Double) {
        guard let t = huntTargetValid(c) else { abortHunt(c); return }
        let dx = t.pos.x - c.pos.x
        c.facing = dx >= 0 ? 1 : -1
        // the prey looks this way → freeze on the spot
        let watched = t.state != .sleep && t.facing * (c.pos.x - t.pos.x) > 0
        if watched || now < c.huntPause { return }
        if Double.random(in: 0...1) < dt * 0.45 { c.huntPause = now + Double.random(in: 0.4...1.1) }
        if abs(dx) < 70 * c.scale {
            c.state = .wiggle
            c.wiggleUntil = now + Double.random(in: 0.8...1.5)
            return
        }
        let step = 24 * c.scale * CGFloat(dt)
        c.pos.x += c.facing * step
        c.phase += step / (c.scale * 14) * 2 * .pi
    }

    func wiggleStep(_ c: Cat) {
        guard let t = huntTargetValid(c) else { abortHunt(c); return }
        c.facing = t.pos.x >= c.pos.x ? 1 : -1
        guard now > c.wiggleUntil, let surf = t.surface else { return }
        c.pounceOn = t.cfg.id
        c.huntTarget = nil
        startJump(c, to: CGPoint(x: t.pos.x - c.facing * 14 * c.scale, y: t.pos.y), target: surf, height: 34)
    }

    func landPounce(_ c: Cat, _ id: UUID) {
        guard let t = cats[id], t.surface == c.surface, abs(t.pos.x - c.pos.x) < 80 * c.scale, t.duo == nil,
              t.state == .sleep || t.interruptible || t.state == .eat || t.state == .drink else { return }
        let wasAsleep = t.state == .sleep
        t.snuggleWith = nil
        if wasAsleep && Double.random(in: 0...1) < 0.3 {
            // woke up grumpy: hisses, the hunter flees
            t.state = .hiss
            t.until = now + 1.5
            t.facing = c.pos.x > t.pos.x ? 1 : -1
            startWalk(c, c.pos.x + (c.pos.x >= t.pos.x ? 1 : -1) * 260, speed: 170)
            return
        }
        if wasAsleep { t.say("Meow?!", 1, now: now) }
        let d = Duo(a: c, b: t, kind: .wrestle, now: now)
        d.approaching = false
        d.mid = (c.pos.x + t.pos.x) / 2
        d.until = now + 3.5
        duos.append(d)
        for x in [c, t] {
            x.duo = d
            x.state = .social
            x.goal = .none
            x.socialRot = 0
            x.socialReady = now + Double.random(in: 15...40)
        }
    }

    // MARK: - Screen edges: up a side wall, along the top, down or drop

    func pursueEdge(_ c: Cat, _ side: CGFloat) -> Bool {
        let stand = side < 0 ? minX : maxX
        if navigate(c, to: .ground, x: stand) {
            c.goal = .none
            c.edgeSide = side
            c.climbSide = -side          // body stays inside the screen
            c.edgeDescend = Bool.random()
            // climb up to some height on the screen side, not to the very top
            c.edgeTargetX = groundY + visible.height * CGFloat.random(in: 0.3...0.7)
            c.surface = nil
            c.pos.x = side < 0 ? visible.minX : visible.maxX
            c.phase = 0
            c.state = .wallClimb
        }
        return true
    }

    func startEdgeTour(_ c: Cat) {
        let side: CGFloat = c.pos.x - visible.minX < visible.maxX - c.pos.x ? -1 : 1
        c.goal = .edge(side)
        c.goalDeadline = now + 60
        _ = pursueEdge(c, side)
    }

    func edgeStep(_ c: Cat, _ dt: Double) {
        let f = CGFloat(dt)
        let s = c.scale
        let wall = c.edgeSide < 0 ? visible.minX : visible.maxX
        switch c.state {
        case .wallClimb:
            c.pos.x = wall
            c.phase += f * 10
            c.pos.y += 175 * (0.2 + 1.7 * max(0, sin(c.phase))) * f * s.squareRoot()
            if c.pos.y >= min(c.edgeTargetX, visible.maxY - 70 * s) {
                if c.edgeDescend {
                    c.state = .wallDown           // climb back down the same side
                } else {
                    let side = c.edgeSide
                    startFall(c, gentle: true)    // push off the wall and drop
                    c.vel = CGVector(dx: -side * 130, dy: 80)
                    c.facing = -side
                }
            }
        case .wallDown:
            c.pos.x = wall
            c.phase -= f * 8
            c.pos.y -= 95 * s * f
            if c.pos.y <= groundY {
                c.surface = .ground
                c.pos.y = groundY
                c.pos.x = wall - c.edgeSide * 22 * s
                c.facing = -c.edgeSide
                idle(c, .sit, 1...2)
            }
        default: break
        }
    }

    // MARK: - Desktop icons (asked from Finder in the background)

    func startIconWatcher() {
        let t = Timer(timeInterval: 4, repeats: true) { [weak self] _ in self?.fetchIcons() }
        RunLoop.main.add(t, forMode: .common)
        fetchIcons()
    }

    func fetchIcons() {
        guard app.running, !iconFetchBusy else { return }
        iconFetchBusy = true
        let primaryH = screen.height
        iconQueue.async { [weak self] in
            let src = """
            tell application "Finder" to get {desktop position of every item of desktop, \
            icon size of icon view options of window of desktop}
            """
            var err: NSDictionary?
            var rects: [CGRect] = []
            if let res = NSAppleScript(source: src)?.executeAndReturnError(&err), res.numberOfItems == 2,
               let list = res.atIndex(1) {
                let size = CGFloat(res.atIndex(2)?.int32Value ?? 64)
                if list.numberOfItems > 0 {
                    for i in 1...list.numberOfItems {
                        guard let p = list.atIndex(i), p.numberOfItems == 2,
                              let x = p.atIndex(1)?.int32Value, let y = p.atIndex(2)?.int32Value,
                              x >= 0, y >= 0 else { continue }
                        // desktop position = icon centre, top-left origin; label sits under the icon
                        let top = primaryH - (CGFloat(y) - size / 2)
                        rects.append(CGRect(x: CGFloat(x) - size / 2 - 4, y: top - size - 28, width: size + 8, height: size + 28))
                    }
                }
            }
            DispatchQueue.main.async {
                self?.iconRects = rects
                self?.iconFetchBusy = false
            }
        }
    }

    /// Finder owns the full-screen desktop window; it is absent in full-screen app spaces.
    func isFinder(_ pid: Int32) -> Bool {
        if let v = finderPIDs[pid] { return v }
        let v = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.finder"
        finderPIDs[pid] = v
        return v
    }

    /// Desktop widgets are separate windows owned by Notification Center.
    func isWidgetOwner(_ pid: Int32) -> Bool {
        if let v = widgetPIDs[pid] { return v }
        let v = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.notificationcenterui"
        widgetPIDs[pid] = v
        return v
    }

    // MARK: - Getting down from a window: jump, or slide down the side clawing at it

    func getDown(_ c: Cat, toward x: CGFloat) {
        guard !app.laser, case .window(let id)? = c.surface, let p = platforms[id],
              p.y - groundY > 110, Bool.random() else { jumpDown(c, toward: x); return }
        // only real window sides (not a cut made by another window in front), fully on screen
        let seg = p.nearestSeg(c.pos.x)
        var sides: [CGFloat] = []
        if abs(seg.lo - max(p.rect.minX + 4, minX)) < 1 && p.rect.minX > visible.minX + 40 { sides.append(-1) }
        if abs(seg.hi - min(p.rect.maxX - 4, maxX)) < 1 && p.rect.maxX < visible.maxX - 40 { sides.append(1) }
        guard !sides.isEmpty else { jumpDown(c, toward: x); return }
        c.slideSide = sides.min { abs(($0 < 0 ? seg.lo : seg.hi) - c.pos.x) < abs(($1 < 0 ? seg.lo : seg.hi) - c.pos.x) }!
        c.goal = .slide(id)
        c.goalDeadline = now + 30
        _ = pursueSlide(c)
    }

    func pursueSlide(_ c: Cat) -> Bool {
        guard case .slide(let id) = c.goal, c.surface == .window(id), let p = platforms[id] else {
            c.goal = .none
            return false
        }
        let seg = p.nearestSeg(c.pos.x)
        let stand = clampOn(.window(id), c.slideSide < 0 ? seg.lo : seg.hi)
        if abs(c.pos.x - stand) > 4 {
            startWalk(c, stand)
            return true
        }
        // over the edge: hang on with the front claws and start sliding
        c.goal = .none
        c.state = .slideDown
        c.climbWin = id
        c.climbSide = c.slideSide
        c.surface = nil
        c.pos.x = c.slideSide < 0 ? p.rect.minX : p.rect.maxX
        c.pos.y = p.y - 26 * c.scale
        c.slideV = 0
        c.slideGripUntil = now + 0.35
        return true
    }

    func slideStep(_ c: Cat, _ dt: Double) {
        let f = CGFloat(dt)
        let s = c.scale
        guard let p = platforms[c.climbWin] else { startFall(c); return }   // window vanished under the claws
        c.pos.x = c.climbSide < 0 ? p.rect.minX : p.rect.maxX
        if now < c.slideGripUntil {
            c.slideV = max(0, c.slideV - 1400 * f)          // claws caught: brake hard
        } else {
            c.slideV = min(320, c.slideV + 700 * f)         // slipping down faster and faster
            if Double.random(in: 0...1) < dt * 1.8 { c.slideGripUntil = now + Double.random(in: 0.15...0.45) }
        }
        c.pos.y -= c.slideV * f
        c.phase += f * (c.slideV > 20 ? 12 : 2)
        let bottom = max(groundY, p.rect.minY)
        if c.pos.y <= bottom + 6 {
            if bottom <= groundY + 1 {
                c.surface = .ground
                c.pos.y = groundY
                c.pos.x = c.pos.x + c.climbSide * 18 * s
                c.facing = c.climbSide
                idle(c, .crouch, 0.3...0.4)
            } else {
                // the window hangs above the floor: swing under it, or push off and drop
                let side = c.climbSide
                if Bool.random(), let r = windowRects[c.climbWin], r.minY - groundY > 70 * s {
                    c.underWin = c.climbWin
                    c.underOffset = side < 0 ? 16 * s : r.width - 16 * s
                    c.underLegs = 0
                    c.pos.y = r.minY - 56 * s
                    beginUnder(c)
                    return
                }
                startFall(c, gentle: true)
                c.vel = CGVector(dx: side * 90, dy: 60)
                c.facing = side
            }
        }
    }

    // MARK: - Hanging from the bottom edge of a window, paw over paw

    func tryUnder(_ c: Cat) -> Bool {
        let s = c.scale
        let options = windowRects.filter { _, r in
            let gap = r.minY - groundY
            return gap > 75 * s && gap < 300 && r.width > 140 && r.maxX > minX + 60 && r.minX < maxX - 60
        }
        guard let (id, r) = options.min(by: { abs($0.value.midX - c.pos.x) < abs($1.value.midX - c.pos.x) }) else { return false }
        c.goal = .under(id)
        c.goalX = min(max(c.pos.x, max(r.minX, minX) + 30 * s), min(r.maxX, maxX) - 30 * s)
        c.goalDeadline = now + 30
        return pursueUnder(c, id)
    }

    func pursueUnder(_ c: Cat, _ id: CGWindowID) -> Bool {
        guard let r = windowRects[id], c.surface == .ground, r.minY - groundY > 70 * c.scale else { c.goal = .none; return false }
        if !navigate(c, to: .ground, x: c.goalX) { return true }
        // right under the edge: leap up and grab it
        c.goal = .none
        c.underWin = id
        c.underOffset = c.pos.x - r.minX
        c.underLegs = 0
        startJump(c, to: CGPoint(x: c.pos.x, y: r.minY - 56 * c.scale), target: .ground, height: 20)
        c.jumpToUnder = true
        return true
    }

    func beginUnder(_ c: Cat) {
        guard let r = windowRects[c.underWin] else { startFall(c, gentle: true); return }
        c.surface = nil
        c.state = .underWin
        c.underOffset = c.pos.x - r.minX
        pickUnderTarget(c, r)
    }

    private func pickUnderTarget(_ c: Cat, _ r: CGRect) {
        let s = c.scale
        let lo = max(r.minX, minX) + 16 * s - r.minX, hi = min(r.maxX, maxX) - 16 * s - r.minX
        guard hi > lo else { c.underTarget = c.underOffset; return }
        var t = CGFloat.random(in: lo...hi)
        if abs(t - c.underOffset) < 80 { t = c.underOffset < (lo + hi) / 2 ? hi : lo }
        c.underTarget = t
    }

    func underStep(_ c: Cat, _ dt: Double) {
        let s = c.scale
        guard let r = windowRects[c.underWin] else { startFall(c); return }   // window closed: down it goes
        if r.minY - groundY < 50 * s { startFall(c, gentle: true); return }
        let dx = c.underTarget - c.underOffset
        let step = 40 * s * CGFloat(dt)
        if abs(dx) <= step {
            // a neighbouring widget/window with its bottom edge in line: keep going paw over paw
            let right = c.facing > 0
            let nearEnd = right ? c.underOffset > r.width - 40 * s : c.underOffset < 40 * s
            if nearEnd, let (nid, nr) = windowRects.first(where: { id, r2 in
                id != c.underWin && abs(r2.minY - r.minY) < 8 &&
                (right ? abs(r2.minX - r.maxX) < 14 : abs(r2.maxX - r.minX) < 14)
            }) {
                c.underWin = nid
                c.underOffset = c.pos.x - nr.minX
                let lo = max(nr.minX, minX) + 16 * s - nr.minX, hi = min(nr.maxX, maxX) - 16 * s - nr.minX
                c.underTarget = right ? max(lo, hi) : min(lo, hi)
                return
            }
            c.underLegs += 1
            if c.underLegs >= 2 || Bool.random() {
                let side = c.facing
                startFall(c, gentle: true)               // let go and drop to the floor
                c.vel = CGVector(dx: side * 50, dy: 0)
                return
            }
            pickUnderTarget(c, r)
        } else {
            c.facing = dx > 0 ? 1 : -1
            c.underOffset += c.facing * step
            c.phase += step / (s * 12) * 2 * .pi
        }
        // follows the window if it is moved
        c.pos.x = r.minX + c.underOffset
        c.pos.y = r.minY - 56 * s
    }

    // MARK: - Scratching the side of the screen like a scratching post

    func startWallScratch(_ c: Cat) {
        let side: CGFloat = c.pos.x - visible.minX < visible.maxX - c.pos.x ? -1 : 1
        c.goal = .scratchWall(side)
        c.goalDeadline = now + 40
        _ = pursueWallScratch(c, side)
    }

    func pursueWallScratch(_ c: Cat, _ side: CGFloat) -> Bool {
        let stand = side < 0 ? minX : maxX
        if !navigate(c, to: .ground, x: stand) { return true }
        c.goal = .none
        c.facing = side
        let wall = side < 0 ? visible.minX : visible.maxX
        c.pos.x = wall - side * 18 * c.scale     // front paws reach the very edge
        c.state = .wallScratch
        c.until = now + Double.random(in: 3...5)
        return true
    }
}
