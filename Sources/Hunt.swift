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
        if abs(seg.lo - max(p.rect.minX + 4, minX)) < 1 && p.rect.minX > visible.minX + 40 && sideVisible(id, left: true) { sides.append(-1) }
        if abs(seg.hi - min(p.rect.maxX - 4, maxX)) < 1 && p.rect.maxX < visible.maxX - 40 && sideVisible(id, left: false) { sides.append(1) }
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
        if !sideVisible(c.climbWin, left: c.climbSide < 0) { loseSupport(c); return }   // covered by another window
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

    /// Stretches of a window's bottom edge that no other window covers.
    func visibleBottomSegs(_ id: CGWindowID) -> [(lo: CGFloat, hi: CGFloat)] {
        guard let i = zRects.firstIndex(where: { $0.0 == id }) else { return [] }
        let r = zRects[i].1
        var segs: [(lo: CGFloat, hi: CGFloat)] = [(max(r.minX + 10, minX), min(r.maxX - 10, maxX))]
        for j in 0..<i {
            let o = zRects[j].1
            if o.minY < r.minY + 6 && o.maxY > r.minY - 6 { segs = subtract(segs, o.minX - 8, o.maxX + 8) }
        }
        return segs.filter { $0.hi - $0.lo > 60 }
    }

    /// Is the left or right side of this window in plain view, not hidden behind another window?
    func sideVisible(_ id: CGWindowID, left: Bool) -> Bool {
        guard let i = zRects.firstIndex(where: { $0.0 == id }) else { return true }   // desktop icons
        let r = zRects[i].1
        let x = left ? r.minX : r.maxX
        let lo = max(r.minY, groundY) + 8, hi = r.maxY - 8
        for j in 0..<i {
            let o = zRects[j].1
            if o.minX - 3 <= x && o.maxX + 3 >= x && o.minY < hi && o.maxY > lo { return false }
        }
        return true
    }

    func tryUnder(_ c: Cat) -> Bool {
        let s = c.scale
        var best: (id: CGWindowID, seg: (lo: CGFloat, hi: CGFloat), dist: CGFloat)?
        for (id, r) in zRects {
            let gap = r.minY - groundY
            guard gap > 75 * s, gap < 300, r.width > 140 else { continue }
            for seg in visibleBottomSegs(id) {
                let d = c.pos.x < seg.lo ? seg.lo - c.pos.x : (c.pos.x > seg.hi ? c.pos.x - seg.hi : 0)
                if best == nil || d < best!.dist { best = (id, seg, d) }
            }
        }
        guard let b = best else { return false }
        c.goal = .under(b.id)
        c.goalX = min(max(c.pos.x, b.seg.lo + 20 * s), b.seg.hi - 20 * s)
        c.goalDeadline = now + 30
        return pursueUnder(c, b.id)
    }

    func pursueUnder(_ c: Cat, _ id: CGWindowID) -> Bool {
        guard let r = windowRects[id], c.surface == .ground, r.minY - groundY > 70 * c.scale,
              !visibleBottomSegs(id).isEmpty else { c.goal = .none; return false }
        if !navigate(c, to: .ground, x: c.goalX) { return true }
        // only grab the part of the edge that is in plain view
        guard visibleBottomSegs(id).contains(where: { c.pos.x >= $0.lo && c.pos.x <= $0.hi }) else { c.goal = .none; return false }
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
        // stay on the uncovered stretch of the edge the cat is hanging from
        let segs = visibleBottomSegs(c.underWin)
        guard let cur = segs.min(by: { a, b in
            let da = c.pos.x < a.lo ? a.lo - c.pos.x : (c.pos.x > a.hi ? c.pos.x - a.hi : 0)
            let db = c.pos.x < b.lo ? b.lo - c.pos.x : (c.pos.x > b.hi ? c.pos.x - b.hi : 0)
            return da < db
        }) else { c.underTarget = c.underOffset; return }
        let lo = cur.lo + 16 * s - r.minX, hi = cur.hi - 16 * s - r.minX
        guard hi > lo else { c.underTarget = c.underOffset; return }
        var t = CGFloat.random(in: lo...hi)
        if abs(t - c.underOffset) < 80 { t = c.underOffset < (lo + hi) / 2 ? hi : lo }
        c.underTarget = t
    }

    func underStep(_ c: Cat, _ dt: Double) {
        let s = c.scale
        guard let r = windowRects[c.underWin] else { startFall(c); return }   // window closed: down it goes
        if r.minY - groundY < 50 * s { startFall(c, gentle: true); return }
        // another window now covers this part of the edge: let go
        if !visibleBottomSegs(c.underWin).contains(where: { c.pos.x >= $0.lo - 14 && c.pos.x <= $0.hi + 14 }) {
            loseSupport(c)
            return
        }
        let dx = c.underTarget - c.underOffset
        let step = 40 * s * CGFloat(dt)
        if abs(dx) <= step {
            // a neighbouring widget/window with its bottom edge in line: keep going paw over paw
            let right = c.facing > 0
            let nearEnd = right ? c.underOffset > r.width - 40 * s : c.underOffset < 40 * s
            if nearEnd, let (nid, nr) = windowRects.first(where: { id, r2 in
                id != c.underWin && abs(r2.minY - r.minY) < 8 &&
                (right ? abs(r2.minX - r.maxX) < 14 : abs(r2.maxX - r.minX) < 14) && !visibleBottomSegs(id).isEmpty
            }), let seg = visibleBottomSegs(nid).min(by: { abs(($0.lo + $0.hi) / 2 - c.pos.x) < abs(($1.lo + $1.hi) / 2 - c.pos.x) }) {
                c.underWin = nid
                c.underOffset = c.pos.x - nr.minX
                let lo = seg.lo + 16 * s - nr.minX, hi = seg.hi - 16 * s - nr.minX
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

    // MARK: - Travelling between windows like stairs

    struct Hop { let fromX: CGFloat; let toX: CGFloat }

    /// Where a cat on `a` can jump to land on `b`, if it is close enough (up to a step, down to a drop).
    func hop(from a: Platform, to b: Platform) -> Hop? {
        let dy = b.y - a.y
        var best: (Hop, CGFloat)?
        for sa in a.segs {
            let la = sa.lo + 14, ha = sa.hi - 14
            guard ha >= la else { continue }
            for sb in b.segs {
                let lb = sb.lo + 14, hb = sb.hi - 14
                guard hb >= lb else { continue }
                let fromX: CGFloat, toX: CGFloat
                if ha < lb { fromX = ha; toX = lb }
                else if hb < la { fromX = la; toX = hb }
                else { let x = (max(la, lb) + min(ha, hb)) / 2; fromX = x; toX = x }   // overlap: straight up or down
                let d = abs(toX - fromX)
                let ok = dy > 0 ? (dy <= 150 && d <= 220) : (-dy <= 520 && d <= 300)
                if ok, best == nil || d < best!.1 { best = (Hop(fromX: fromX, toX: toX), d) }
            }
        }
        return best?.0
    }

    func neighbors(_ a: Platform) -> [Platform] {
        platformList.filter { $0.id != a.id && hop(from: a, to: $0) != nil }
    }

    /// First window to hop to on the way to `goal`, searching a few steps ahead.
    func nextHop(from a: Platform, to goal: CGWindowID, depth: Int = 5) -> Platform? {
        var visited: Set<CGWindowID> = [a.id]
        var queue: [(node: Platform, first: Platform)] = []
        for n in neighbors(a) {
            if n.id == goal { return n }
            visited.insert(n.id)
            queue.append((n, n))
        }
        var d = 1
        while !queue.isEmpty && d < depth {
            var next: [(node: Platform, first: Platform)] = []
            for (node, first) in queue {
                for n in neighbors(node) where !visited.contains(n.id) {
                    if n.id == goal { return first }
                    visited.insert(n.id)
                    next.append((n, first))
                }
            }
            queue = next
            d += 1
        }
        return nil
    }

    /// Every platform a cat on `a` can reach by hopping, within a few steps.
    func reachablePlatforms(from a: Platform, depth: Int = 5) -> [Platform] {
        var visited: Set<CGWindowID> = [a.id]
        var frontier = [a]
        var out: [Platform] = []
        for _ in 0..<depth {
            var next: [Platform] = []
            for node in frontier {
                for n in neighbors(node) where !visited.contains(n.id) {
                    visited.insert(n.id)
                    out.append(n)
                    next.append(n)
                }
            }
            frontier = next
            if frontier.isEmpty { break }
        }
        return out.filter { $0.segs.contains { $0.hi - $0.lo > 70 } }
    }

    // MARK: - Losing the footing: fall, or catch the window in front

    /// The ground went from under the cat (another window slid over it, or the window moved).
    /// Sometimes it falls; sometimes it grabs the edge of the window in front and scrambles up it.
    func loseSupport(_ c: Cat) {
        if now > c.grabReadyAt, Double.random(in: 0...1) < 0.55, grabFrontWindow(c) { return }
        startFall(c)
    }

    /// Jump sideways onto the nearest uncovered side of a window that now surrounds the cat,
    /// cling to it in the middle of the window and climb to its top.
    func grabFrontWindow(_ c: Cat) -> Bool {
        let s = c.scale
        let body = CGPoint(x: c.pos.x, y: c.pos.y + 20 * s)
        var best: (p: Platform, left: Bool, dist: CGFloat)?
        for (id, r) in zRects {
            guard let p = platforms[id], r.insetBy(dx: -60, dy: -40).contains(body), p.y - body.y > 30 else { continue }
            for left in [true, false] {
                guard sideVisible(id, left: left) else { continue }
                let edge = left ? r.minX : r.maxX
                guard edge > minX - 1, edge < maxX + 1 else { continue }
                let d = abs(body.x - edge)
                if best == nil || d < best!.dist { best = (p, left, d) }
            }
        }
        guard let b = best else { return false }
        let side: CGFloat = b.left ? -1 : 1
        let seg = b.p.nearestSeg(c.pos.x)
        let edge = b.left ? seg.lo : seg.hi
        let grabY = min(max(c.pos.y, b.p.rect.minY + 24 * s), b.p.y - 70 * s)
        c.goal = .none
        c.grabReadyAt = now + 4
        c.climbWin = b.p.id
        c.climbSide = side
        startJump(c, to: CGPoint(x: edge, y: grabY), target: .ground, height: 14)
        c.jDur = Double(0.28 + b.dist / 1100)
        c.jumpToClimb = true
        c.say("Meow!", 1, now: now)
        return true
    }
}
