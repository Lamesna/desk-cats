import AppKit
import QuartzCore

// MARK: - Platforms (tops of open windows)

struct Platform {
    let id: CGWindowID
    var rect: CGRect
    var segs: [(lo: CGFloat, hi: CGFloat)]
    var y: CGFloat { rect.maxY }

    func contains(_ x: CGFloat, tol: CGFloat = 3) -> Bool {
        segs.contains { x >= $0.lo - tol && x <= $0.hi + tol }
    }
    func nearestSeg(_ x: CGFloat) -> (lo: CGFloat, hi: CGFloat) {
        segs.min { dist($0, x) < dist($1, x) }!
    }
    func clampX(_ x: CGFloat, inset: CGFloat = 10) -> CGFloat {
        let s = nearestSeg(x)
        let lo = s.lo + inset, hi = s.hi - inset
        return lo > hi ? (s.lo + s.hi) / 2 : min(max(x, lo), hi)
    }
    private func dist(_ s: (lo: CGFloat, hi: CGFloat), _ x: CGFloat) -> CGFloat {
        x < s.lo ? s.lo - x : (x > s.hi ? x - s.hi : 0)
    }
}

enum Surface: Equatable { case ground, window(CGWindowID) }

final class Bowl {
    let id = UUID()
    let kind: BowlKind
    var pos: CGPoint
    var surface: Surface?
    var vy: CGFloat = 0
    var amount: Double = 1
    let view = BowlView()
    init(kind: BowlKind, pos: CGPoint) {
        self.kind = kind
        self.pos = pos
        view.kind = kind
    }
}

enum CatState { case sit, loaf, groom, sleep, scratch, walk, climb, jump, fall, hiss, grumpy, eat, drink, purr, dragged, crouch, hang, social,
                       stalk, wiggle, wallClimb, underWin, wallDown, slideDown, wallScratch }

enum Goal: Equatable { case none, eat(UUID), drink(UUID), visit(CGWindowID), sleepUp(CGWindowID), snuggle(UUID), edge(CGFloat), slide(CGWindowID), under(CGWindowID), scratchWall(CGFloat) }

// MARK: - Cat

final class Cat {
    var cfg: CatConfig
    var look: CatLook
    var pos: CGPoint
    var surface: Surface?
    var state: CatState = .fall
    var until: Double = 0
    var facing: CGFloat = 1
    var phase: CGFloat = 0
    var targetX: CGFloat = 0
    var speed: CGFloat = 50
    var climbWin: CGWindowID = 0
    var climbSide: CGFloat = -1
    var jFrom = CGPoint.zero, jTo = CGPoint.zero
    var jStart = 0.0, jDur = 0.5
    var jH: CGFloat = 40
    var jTarget: Surface = .ground
    var jumpToClimb = false
    var catchJump = false
    var leapReady = 0.0
    var hangSlot = 0
    var duo: Duo?
    var socialPose: Pose = .walk
    var socialEyes: EyeMode = .open
    var socialRot: CGFloat = 0
    var socialReady = Double.random(in: 0...20)
    var lastHiss = 0.0
    var snuggleWith: UUID?
    var swing: CGFloat = 0
    var swingV: CGFloat = 0
    var huntTarget: UUID?
    var huntPause = 0.0
    var wiggleUntil = 0.0
    var pounceOn: UUID?
    var edgeSide: CGFloat = -1
    var edgeTargetX: CGFloat = 0
    var edgeDescend = false
    var slideSide: CGFloat = -1
    var slideV: CGFloat = 0
    var slideGripUntil = 0.0
    var jumpToUnder = false
    var underWin: CGWindowID = 0
    var underOffset: CGFloat = 0
    var underTarget: CGFloat = 0
    var underLegs = 0
    var vel = CGVector.zero
    var fallStartY: CGFloat = 0
    var gentle = true
    var goal: Goal = .none
    var goalX: CGFloat = 0
    var goalDeadline = 0.0
    var stats = CatStats()
    var bubble: String?
    var bubbleUntil = 0.0
    var bubbleAlert = false
    var hearts: [(born: Double, dx: CGFloat)] = []
    var hoverTime = 0.0
    var lastHeart = 0.0
    var blinkAt = 0.0
    let tOffset = Double.random(in: 0...100)
    let view = CatView()

    var scale: CGFloat { CGFloat(cfg.size) }

    init(cfg: CatConfig, pos: CGPoint) {
        self.cfg = cfg
        self.look = CatLook(cfg)
        self.pos = pos
        self.fallStartY = pos.y
    }

    func say(_ text: String, _ secs: Double, now: Double, alert: Bool = false) {
        bubble = tr(text)
        bubbleUntil = now + secs
        bubbleAlert = alert
    }

    var bodyRect: CGRect {
        let s = scale
        switch state {
        case .dragged: return CGRect(x: pos.x - 16 * s, y: pos.y - 4 * s, width: 32 * s, height: 58 * s)
        case .hang, .underWin: return CGRect(x: pos.x - 16 * s, y: pos.y - 2 * s, width: 32 * s, height: 60 * s)
        case .climb, .wallClimb, .wallDown, .slideDown: return CGRect(x: pos.x - (climbSide < 0 ? 26 : 2) * s, y: pos.y - 8 * s, width: 28 * s, height: 58 * s)
        default: return CGRect(x: pos.x - 28 * s, y: pos.y - 2 * s, width: 56 * s, height: 46 * s)
        }
    }

    var interruptible: Bool {
        [.sit, .loaf, .groom, .walk, .scratch, .purr, .crouch].contains(state)
    }
}

// MARK: - World

final class World {
    let app = AppState.shared
    let overlay: Overlay
    var cats: [UUID: Cat] = [:]
    var bowls: [Bowl] = []
    var platforms: [CGWindowID: Platform] = [:]
    var platformList: [Platform] = []
    var screen = CGRect.zero
    var visible = CGRect.zero
    var now = CACurrentMediaTime()
    var lastTick = CACurrentMediaTime()
    var tickCount = 0
    var mouse = CGPoint.zero
    var mouseVel = CGVector.zero
    var iconRects: [CGRect] = []
    var iconFetchBusy = false
    let iconQueue = DispatchQueue(label: "deskcats.icons")
    var widgetPIDs: [Int32: Bool] = [:]
    var finderPIDs: [Int32: Bool] = [:]
    var windowRects: [CGWindowID: CGRect] = [:]   // every app window, for hanging under them
    var mouseAcc = CGVector.zero
    var rawMouseVel = CGVector.zero
    var duos: [Duo] = []
    var timer: Timer?
    var lastStats = 0.0
    let debug = ProcessInfo.processInfo.environment["DESKCATS_DEBUG"] != nil

    var dragCat: Cat?
    var dragBowl: Bowl?
    var dragOffset = CGPoint.zero
    var dragSamples: [(CGPoint, Double)] = []

    var groundY: CGFloat { visible.minY }
    var minX: CGFloat { visible.minX + 34 }
    var maxX: CGFloat { visible.maxX - 34 }

    init() {
        overlay = Overlay()
        updateScreen(force: true)
        overlay.onMouse = { [weak self] kind, p in self?.mouseEvent(kind, p) }
        app.onCatsChanged = { [weak self] in self?.syncCats() }
        app.onRunningChanged = { [weak self] in self?.applyRunning() }
        app.onBowlAction = { [weak self] a in self?.bowlAction(a) }
        refreshPlatforms()
        syncCats()
        applyRunning()
        let t = Timer(timeInterval: 1.0 / 40, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        startIconWatcher()
    }

    func applyRunning() {
        if app.running {
            overlay.window.orderFrontRegardless()
            lastTick = CACurrentMediaTime()
        } else {
            overlay.window.orderOut(nil)
            app.laser = false
            app.placing = nil
        }
    }

    // MARK: screen + windows

    func updateScreen(force: Bool = false) {
        guard let s = NSScreen.screens.first else { return }
        if force || s.frame != screen || s.visibleFrame != visible {
            screen = s.frame
            visible = s.visibleFrame
            overlay.window.setFrame(screen, display: true)
        }
    }

    func refreshPlatforms() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let primaryH = screen.height
        // front-to-back: app windows, then things lying on the desktop (widgets, icons)
        var rects: [(CGWindowID, CGRect)] = []
        var desk: [(CGWindowID, CGRect)] = []
        var desktopShown = false
        for w in list {
            guard let layer = w[kCGWindowLayer as String] as? Int,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != myPID,
                  let num = w[kCGWindowNumber as String] as? Int,
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd) else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a < 0.1 { continue }
            let cocoa = CGRect(x: r.minX, y: primaryH - r.maxY, width: r.width, height: r.height)
            if layer < 0, r.width >= screen.width * 0.9, isFinder(pid) { desktopShown = true }
            if layer == 0 {
                if r.width < 120 || r.height < 60 { continue }
                rects.append((CGWindowID(num), cocoa))
            } else if layer < 0, isWidgetOwner(pid), r.width >= 60, r.width < screen.width * 0.8 {
                desk.append((CGWindowID(num), cocoa))
            }
        }
        let deskStart = rects.count
        windowRects = Dictionary(rects + (desktopShown ? desk : []), uniquingKeysWith: { a, _ in a })
        if desktopShown {
            rects += desk
            for (i, r) in iconRects.enumerated() { rects.append((0xF000_0000 + CGWindowID(i), r)) }
        }
        var result: [Platform] = []
        for (i, (id, r)) in rects.enumerated() {
            let y = r.maxY
            // widgets and icons may sit right under the menu bar; the cat then pokes up over it
            let ceiling = i >= deskStart ? screen.maxY - 36 : visible.maxY - 48
            guard y < ceiling, y > groundY + 50 else { continue }
            var segs: [(lo: CGFloat, hi: CGFloat)] = [(max(r.minX + 4, minX), min(r.maxX - 4, maxX))]
            for j in 0..<i {
                let o = rects[j].1
                if o.minY < y + 36 && o.maxY > y - 2 {
                    segs = subtract(segs, o.minX - 6, o.maxX + 6)
                }
            }
            segs = segs.filter { $0.hi - $0.lo > 44 }
            if !segs.isEmpty { result.append(Platform(id: id, rect: r, segs: segs)) }
        }
        // carry riders along with moving windows
        var newMap: [CGWindowID: Platform] = [:]
        for p in result { newMap[p.id] = p }
        for (id, old) in platforms {
            guard let n = newMap[id] else { continue }
            let dx = n.rect.minX - old.rect.minX
            if dx == 0 { continue }
            for c in cats.values where c.surface == .window(id) || (c.state == .climb && c.climbWin == id) { c.pos.x += dx }
            for b in bowls where b.surface == .window(id) { b.pos.x += dx }
        }
        platforms = newMap
        platformList = result
    }

    private func subtract(_ segs: [(lo: CGFloat, hi: CGFloat)], _ a: CGFloat, _ b: CGFloat) -> [(lo: CGFloat, hi: CGFloat)] {
        var out: [(lo: CGFloat, hi: CGFloat)] = []
        for s in segs {
            if b <= s.lo || a >= s.hi { out.append(s); continue }
            if a > s.lo { out.append((s.lo, a)) }
            if b < s.hi { out.append((b, s.hi)) }
        }
        return out
    }

    func surfaceY(_ s: Surface) -> CGFloat? {
        switch s {
        case .ground: return groundY
        case .window(let id): return platforms[id]?.y
        }
    }

    func clampOn(_ s: Surface, _ x: CGFloat) -> CGFloat {
        switch s {
        case .ground: return min(max(x, minX), maxX)
        case .window(let id): return platforms[id]?.clampX(x, inset: 12) ?? x
        }
    }

    func landing(x: CGFloat, from y0: CGFloat, to y1: CGFloat) -> (Surface, CGFloat)? {
        var best: (Surface, CGFloat)?
        for p in platformList where p.y <= y0 + 0.5 && p.y >= y1 && p.contains(x, tol: 0) {
            if best == nil || p.y > best!.1 { best = (.window(p.id), p.y) }
        }
        if best == nil && y1 <= groundY { best = (.ground, groundY) }
        return best
    }

    func surfaceUnder(_ m: CGPoint) -> Surface {
        var best: Platform?
        for p in platformList where p.y <= m.y + 8 && m.y - p.y < 170 && p.contains(m.x, tol: 0) {
            if best == nil || p.y > best!.y { best = p }
        }
        return best.map { .window($0.id) } ?? .ground
    }

    func randomPlatform() -> Platform? {
        let c = platformList.filter { p in p.segs.contains { $0.hi - $0.lo > 70 } }
        return c.randomElement()
    }

    // MARK: cats sync

    func syncCats() {
        let cfgs = app.cats
        let wanted = Set(cfgs.filter(\.visible).map(\.id))
        for (id, c) in cats where !wanted.contains(id) {
            c.view.removeFromSuperview()
            cats[id] = nil
        }
        for cfg in cfgs where cfg.visible {
            if let c = cats[cfg.id] {
                if c.cfg != cfg { c.cfg = cfg; c.look = CatLook(cfg) }
            } else {
                let x = CGFloat.random(in: minX + 40...max(minX + 41, maxX - 40))
                let c = Cat(cfg: cfg, pos: CGPoint(x: x, y: visible.maxY - 70))
                c.vel = CGVector(dx: 0, dy: -100)
                c.gentle = true
                c.blinkAt = now + 2
                overlay.root.addSubview(c.view)
                cats[cfg.id] = c
            }
        }
    }

    // MARK: bowls

    func bowlAction(_ a: String) {
        switch a {
        case "refillFood": bowls.filter { $0.kind == .food }.forEach { $0.amount = 1 }
        case "refillWater": bowls.filter { $0.kind == .water }.forEach { $0.amount = 1 }
        case "clear":
            bowls.forEach { $0.view.removeFromSuperview() }
            bowls.removeAll()
        case "feedAll":
            for c in cats.values { c.stats.food = 1; c.stats.water = 1; c.say("Meow~", 2, now: now) }
        default: break
        }
        app.bowlCount = bowls.count
    }

    func addBowl(_ kind: BowlKind, at p: CGPoint) {
        let b = Bowl(kind: kind, pos: CGPoint(x: min(max(p.x, minX), maxX), y: p.y))
        overlay.root.addSubview(b.view, positioned: .below, relativeTo: nil)
        bowls.append(b)
        app.bowlCount = bowls.count
        // hungry cats notice the new bowl right away
        for c in cats.values where c.interruptible { c.until = 0 }
    }

    func bowl(_ id: UUID) -> Bowl? { bowls.first { $0.id == id } }

    func nearestBowl(_ kind: BowlKind, to c: Cat) -> Bowl? {
        bowls.filter { $0.kind == kind && $0.amount > 0.01 && $0.surface != nil }
            .min { hypot($0.pos.x - c.pos.x, $0.pos.y - c.pos.y) < hypot($1.pos.x - c.pos.x, $1.pos.y - c.pos.y) }
    }

    func updateBowl(_ b: Bowl, _ dt: Double) {
        if b.view === dragBowl?.view { return }
        if let s = b.surface {
            if case .window(let id) = s {
                if let p = platforms[id], p.contains(b.pos.x, tol: 4) { b.pos.y = p.y } else { b.surface = nil; b.vy = 0 }
            } else { b.pos.y = groundY }
            return
        }
        let y0 = b.pos.y
        b.vy -= 1800 * CGFloat(dt)
        b.pos.y += b.vy * CGFloat(dt)
        if let (s, y) = landing(x: b.pos.x, from: y0, to: b.pos.y) {
            b.surface = s
            b.pos.y = y
            b.vy = 0
        }
    }

    // MARK: mouse

    func catAt(_ p: CGPoint) -> Cat? {
        cats.values.first { $0.bodyRect.contains(p) }
    }

    func bowlAt(_ p: CGPoint) -> Bowl? {
        bowls.first { CGRect(x: $0.pos.x - 20, y: $0.pos.y - 2, width: 40, height: 24).contains(p) }
    }

    func updateMouseCapture() {
        let opt = NSEvent.modifierFlags.contains(.option)
        let want = app.placing != nil || dragCat != nil || dragBowl != nil ||
            (opt && (catAt(mouse) != nil || bowlAt(mouse) != nil))
        if overlay.window.ignoresMouseEvents == want { overlay.window.ignoresMouseEvents = !want }
        overlay.ghost.isHidden = app.placing == nil
        if let k = app.placing {
            overlay.ghost.kind = k
            overlay.ghost.frame.origin = CGPoint(x: mouse.x - 23 - screen.minX, y: mouse.y - 4 - screen.minY)
        }
        overlay.laser.isHidden = !app.laser
        if app.laser {
            overlay.laser.frame.origin = CGPoint(x: mouse.x - 15 - screen.minX, y: mouse.y - 15 - screen.minY)
            overlay.laser.needsDisplay = true
        }
    }

    func mouseEvent(_ kind: Overlay.MouseKind, _ p: CGPoint) {
        switch kind {
        case .down:
            if let k = app.placing {
                addBowl(k, at: p)
                app.placing = nil
                return
            }
            if let c = catAt(p) {
                dragCat = c
                c.state = .dragged
                c.surface = nil
                c.goal = .none
                c.jumpToClimb = false
                c.catchJump = false
                c.jumpToUnder = false
                c.say("Meow?!", 1.5, now: now)
                dragOffset = CGPoint(x: 0, y: 44 * c.scale)
                c.pos = CGPoint(x: p.x, y: p.y - dragOffset.y)
            } else if let b = bowlAt(p) {
                dragBowl = b
                b.surface = nil
                dragOffset = CGPoint(x: p.x - b.pos.x, y: p.y - b.pos.y)
            }
            dragSamples = [(p, now)]
        case .dragged:
            dragSamples.append((p, now))
            if dragSamples.count > 8 { dragSamples.removeFirst() }
            if let c = dragCat { c.pos = CGPoint(x: p.x - dragOffset.x, y: p.y - dragOffset.y) }
            if let b = dragBowl { b.pos = CGPoint(x: p.x - dragOffset.x, y: p.y - dragOffset.y) }
        case .up:
            var v = CGVector.zero
            if let first = dragSamples.first, let last = dragSamples.last, last.1 - first.1 > 0.01 {
                let dt = CGFloat(last.1 - first.1)
                v = CGVector(dx: (last.0.x - first.0.x) / dt, dy: (last.0.y - first.0.y) / dt)
                v.dx = max(-1400, min(1400, v.dx))
                v.dy = max(-1400, min(1400, v.dy))
            }
            if let c = dragCat {
                c.state = .fall
                c.vel = v
                c.fallStartY = c.pos.y
                c.gentle = false
            }
            if let b = dragBowl { b.surface = nil; b.vy = 0 }
            dragCat = nil
            dragBowl = nil
        case .rightDown:
            app.placing = nil
        }
    }

    // MARK: tick

    func tick() {
        guard app.running else { return }
        now = CACurrentMediaTime()
        let dt = min(1.0 / 20, now - lastTick)
        lastTick = now
        tickCount += 1
        if tickCount % 40 == 0 { updateScreen() }
        if tickCount % 3 == 0 { refreshPlatforms() }
        let m = NSEvent.mouseLocation
        if dt > 0 {
            let v = CGVector(dx: (m.x - mouse.x) / dt, dy: (m.y - mouse.y) / dt)
            mouseVel = CGVector(dx: mouseVel.dx * 0.6 + v.dx * 0.4, dy: mouseVel.dy * 0.6 + v.dy * 0.4)
            let a = CGVector(dx: (v.dx - rawMouseVel.dx) / dt, dy: (v.dy - rawMouseVel.dy) / dt)
            mouseAcc = CGVector(dx: mouseAcc.dx * 0.5 + a.dx * 0.5, dy: mouseAcc.dy * 0.5 + a.dy * 0.5)
            rawMouseVel = v
        }
        mouse = m
        if (dragCat != nil || dragBowl != nil) && NSEvent.pressedMouseButtons & 1 == 0 {
            mouseEvent(.up, mouse)   // the button was released but the event never reached us
        }
        updateMouseCapture()
        updateDuos(dt)

        for b in bowls {
            updateBowl(b, dt)
            b.view.amount = b.amount
            b.view.frame = CGRect(x: b.pos.x - 23 - screen.minX, y: b.pos.y - 3 - screen.minY, width: 46, height: 30)
            b.view.needsDisplay = true
        }
        for c in cats.values {
            update(c, dt)
            let s = c.scale
            c.view.frame = CGRect(x: c.pos.x - 75 * s - screen.minX, y: c.pos.y - 45 * s - screen.minY, width: 150 * s, height: 150 * s)
            c.view.scale = s
            c.view.look = c.look
            c.view.info = renderInfo(c)
            c.view.bubble = c.bubble
            c.view.bubbleAlert = c.bubbleAlert
            c.view.hearts = c.hearts.map { (CGFloat(now - $0.born), $0.dx) }
            c.view.sleeping = c.state == .sleep
            c.view.dust = c.state == .social && c.socialPose == .roll
            c.view.now = now
            // calm poses animate slowly: redraw them less often to save CPU
            let calm: Set<CatState> = [.sit, .loaf, .sleep, .groom]
            if !calm.contains(c.state) || c.bubble != nil || tickCount % 3 == 0 { c.view.needsDisplay = true }
        }

        if now - lastStats > 1 {
            lastStats = now
            if debug {
                let cs = cats.values.map { "\($0.cfg.name):\($0.state) \($0.surface.map { "\($0)" } ?? "air") x=\(Int($0.pos.x)) y=\(Int($0.pos.y))" }
                FileHandle.standardError.write("platforms=\(platformList.count) ground=\(Int(groundY)) | \(cs.joined(separator: " | "))\n".data(using: .utf8)!)
            }
            var d: [UUID: CatStats] = [:]
            for c in cats.values { d[c.cfg.id] = c.stats }
            if d != app.stats { app.stats = d }
        }
    }

    // MARK: cat brain

    func update(_ c: Cat, _ dt: Double) {
        let f = CGFloat(dt)
        // needs
        c.stats.food = max(0, c.stats.food - dt / 1800)
        c.stats.water = max(0, c.stats.water - dt / 1500)
        c.stats.fun = max(0, c.stats.fun - dt / 1200)
        if c.state == .sleep { c.stats.energy = min(1, c.stats.energy + dt / 70) }
        else { c.stats.energy = max(0, c.stats.energy - dt / 900) }
        c.stats.mood = mood(c)

        if let _ = c.bubble, now > c.bubbleUntil { c.bubble = nil }
        if c.state != .sleep { c.snuggleWith = nil }
        else if c.snuggleWith != nil && Double.random(in: 0...1) < dt * 0.12 { c.hearts.append((now, 0)) }
        c.hearts.removeAll { now - $0.born > 1.6 }

        if c.state == .dragged { c.phase += f * 4; return }
        if c.state == .hang { updateHang(c, dt); return }
        let needsFloor: Set<CatState> = [.sit, .loaf, .groom, .sleep, .scratch, .walk, .purr, .crouch, .grumpy,
                                         .hiss, .eat, .drink, .stalk, .wiggle, .social, .wallScratch]
        if c.surface == nil && needsFloor.contains(c.state) { startFall(c, gentle: true) }

        // support check
        if let s = c.surface, c.state != .climb, c.state != .jump, c.state != .fall {
            switch s {
            case .ground:
                c.pos.y = groundY
                if c.state != .wallScratch { c.pos.x = min(max(c.pos.x, minX), maxX) }
            case .window(let id):
                if let p = platforms[id], p.contains(c.pos.x, tol: 6) { c.pos.y = p.y } else { startFall(c) }
            }
        }

        // laser pointer
        if app.laser && c.stats.energy > 0.08 {
            let near = hypot(mouse.x - c.pos.x, mouse.y - c.pos.y) < 130
            if c.interruptible || ((c.state == .sleep || c.state == .eat || c.state == .drink) && near) {
                laserChase(c, dt)
            }
        } else {
            petting(c, dt)
        }

        switch c.state {
        case .walk:
            let dx = c.targetX - c.pos.x
            let step = c.speed * f
            if abs(dx) <= step {
                c.pos.x = c.targetX
                if app.laser { c.state = .crouch; c.until = now + 1 } else { decide(c) }
            } else {
                c.facing = dx > 0 ? 1 : -1
                c.pos.x += c.facing * step
                // longer strides when running (gallop)
                c.phase += step / (c.scale * (c.speed > 100 * c.scale ? 34 : 22)) * 2 * .pi
            }

        case .climb:
            guard let p = platforms[c.climbWin] else { startFall(c); break }
            let seg = p.nearestSeg(c.pos.x)
            c.pos.x = c.climbSide < 0 ? seg.lo : seg.hi
            // scramble in bursts: hind legs push → fast surge, front paws grab → short pause
            c.phase += f * 10
            let surge = 0.2 + 1.7 * max(0, sin(c.phase))
            c.pos.y += 175 * surge * f * c.scale.squareRoot()
            if c.pos.y >= p.y - 30 * c.scale {
                c.surface = .window(c.climbWin)
                c.pos.y = p.y
                c.pos.x = c.pos.x - c.climbSide * 16 * c.scale
                c.facing = -c.climbSide
                c.state = .sit
                c.until = now + 0.6
            }

        case .jump:
            let u = max(0, min(1, (now - c.jStart) / c.jDur))
            let uu = CGFloat(u)
            c.pos.x = c.jFrom.x + (c.jTo.x - c.jFrom.x) * uu
            c.pos.y = c.jFrom.y + (c.jTo.y - c.jFrom.y) * uu + sin(uu * .pi) * c.jH
            if c.catchJump {
                if tryCatch(c) { break }
                if u >= 1 {
                    // missed (or no free spot on the cursor): drop back down
                    c.catchJump = false
                    startFall(c, gentle: true)
                    c.vel.dx = c.facing * 40
                    if Double.random(in: 0...1) < 0.3 { c.say("Meow!", 0.8, now: now) }
                }
                break
            }
            if c.jumpToUnder {
                if u >= 1 { c.jumpToUnder = false; beginUnder(c) }
                break
            }
            if u >= 1 && c.jumpToClimb {
                // landed on the side of a window: grab it and start climbing
                c.jumpToClimb = false
                if let p = platforms[c.climbWin] {
                    let seg = p.nearestSeg(c.pos.x)
                    c.pos.x = c.climbSide < 0 ? seg.lo : seg.hi
                    c.state = .climb
                    c.phase = 0
                } else {
                    startFall(c, gentle: true)
                }
            } else if u >= 1 {
                if let y = surfaceY(c.jTarget), c.jTarget == .ground || platforms[idOf(c.jTarget)]?.contains(c.pos.x, tol: 6) == true {
                    c.surface = c.jTarget
                    c.pos.y = y
                    if app.laser { c.state = .crouch; c.until = now + 1 } else { c.state = .crouch; c.until = now + 0.22 }  // absorb the landing
                    if let id = c.pounceOn { c.pounceOn = nil; landPounce(c, id) }
                } else {
                    startFall(c, gentle: true)
                }
            }

        case .fall:
            let y0 = c.pos.y
            c.vel.dy -= 1900 * f
            c.pos.x += c.vel.dx * f
            c.pos.y += c.vel.dy * f
            if c.pos.x < minX { c.pos.x = minX; c.vel.dx = abs(c.vel.dx) * 0.5 }
            if c.pos.x > maxX { c.pos.x = maxX; c.vel.dx = -abs(c.vel.dx) * 0.5 }
            if c.pos.y > visible.maxY - 30 && c.vel.dy > 0 { c.vel.dy = 0 }
            if c.vel.dy <= 0, let (s, y) = landing(x: c.pos.x, from: y0, to: c.pos.y) {
                c.surface = s
                c.pos.y = y
                let h = c.fallStartY - y
                if !c.gentle && h > 130 {
                    c.state = .hiss
                    c.until = now + 1.7
                    c.stats.fun = max(0, c.stats.fun - 0.1)
                } else {
                    c.state = .sit
                    c.until = now + 0.8
                }
                c.vel = .zero
                c.gentle = true
            }

        case .hiss:
            if now > c.until {
                c.state = .grumpy
                c.until = now + 2.6
            }

        case .eat, .drink:
            if now > c.until {
                if case .eat = c.state { c.stats.food = 1 } else { c.stats.water = 1 }
                let kind: BowlKind = c.state == .eat ? .food : .water
                if let b = bowls.filter({ $0.kind == kind }).min(by: { abs($0.pos.x - c.pos.x) < abs($1.pos.x - c.pos.x) }) {
                    b.amount = max(0, b.amount - 0.25)
                }
                c.stats.fun = min(1, c.stats.fun + 0.1)
                c.hearts.append((now, 0))
                c.state = .groom
                c.until = now + 3
            }

        case .purr:
            c.stats.fun = min(1, c.stats.fun + dt * 0.06)
            if now > c.until { decide(c) }

        case .sleep:
            if now > c.until || (c.stats.energy >= 1 && c.snuggleWith == nil) {
                c.state = .sit
                c.until = now + 2
                c.say("Meow~", 1.2, now: now)
            }

        case .scratch:
            c.stats.fun = min(1, c.stats.fun + dt * 0.02)
            if now > c.until { decide(c) }

        case .grumpy:
            grumpyHiss(c)
            if now > c.until { decide(c) }

        case .sit, .loaf, .groom, .crouch:
            if now > c.until { decide(c) }

        case .stalk: huntStep(c, dt)
        case .wiggle: wiggleStep(c)
        case .wallClimb, .wallDown: edgeStep(c, dt)
        case .underWin: underStep(c, dt)
        case .slideDown: slideStep(c, dt)
        case .wallScratch:
            c.stats.fun = min(1, c.stats.fun + dt * 0.02)
            if now > c.until { decide(c) }
        case .dragged, .hang, .social: break
        }
    }

    private func idOf(_ s: Surface) -> CGWindowID {
        if case .window(let id) = s { return id }
        return 0
    }

    func mood(_ c: Cat) -> String {
        switch c.state {
        case .sleep: return "Sleeping 💤"
        case .hiss, .grumpy: return "Offended 💢"
        case .eat: return "Eating"
        case .drink: return "Drinking"
        case .purr: return "Purring ♥"
        case .scratch: return "Sharpening claws"
        case .climb: return "Climbing up"
        case .dragged: return "Dangling"
        case .crouch: return "Hunting"
        case .hang: return "Hanging on the cursor"
        case .stalk: return "Stalking"
        case .wiggle: return "About to pounce"
        case .wallClimb, .wallDown: return "Climbing the screen edge"
        case .underWin: return "Hanging under a window"
        case .slideDown: return "Sliding down"
        case .wallScratch: return "Scratching the screen edge"
        case .social:
            switch c.duo?.kind {
            case .sniff: return "Sniffing noses"
            case .boxing: return "Boxing"
            case .wrestle: return "Play-fighting"
            case .chase: return "Playing tag"
            default: return "Playing"
            }
        default: break
        }
        if c.stats.food < 0.3 { return "Hungry" }
        if c.stats.water < 0.3 { return "Thirsty" }
        if c.stats.energy < 0.25 { return "Sleepy" }
        if c.stats.fun < 0.25 { return "Bored" }
        return c.surface == .ground ? "Roaming" : "Sitting on a window"
    }

    func startFall(_ c: Cat, gentle: Bool = false) {
        c.state = .fall
        c.surface = nil
        c.vel = .zero
        c.fallStartY = c.pos.y
        c.gentle = gentle
        c.goal = .none
        c.jumpToClimb = false
        c.catchJump = false
        c.pounceOn = nil
        c.huntTarget = nil
        c.jumpToUnder = false
    }

    func startWalk(_ c: Cat, _ x: CGFloat, speed: CGFloat? = nil) {
        guard let s = c.surface else { return }
        c.targetX = clampOn(s, x)
        c.speed = (speed ?? 46) * c.scale
        c.state = .walk
    }

    func startJump(_ c: Cat, to p: CGPoint, target: Surface, height: CGFloat? = nil) {
        c.jFrom = c.pos
        c.jTo = p
        c.jStart = now + 0.1   // short crouch before take-off
        let d = hypot(p.x - c.pos.x, p.y - c.pos.y)
        c.jDur = Double(0.32 + d / 900)
        c.jH = height ?? max(20, (p.y - c.pos.y) * 0.35 + 30)
        c.jTarget = target
        c.facing = p.x >= c.pos.x ? 1 : -1
        c.surface = nil
        c.state = .jump
    }

    func jumpDown(_ c: Cat, toward x: CGFloat) {
        let tx = min(max(c.pos.x + (x >= c.pos.x ? 50 : -50), minX), maxX)
        startJump(c, to: CGPoint(x: tx, y: groundY), target: .ground, height: 26)
    }

    func idle(_ c: Cat, _ s: CatState, _ r: ClosedRange<Double>) {
        c.state = s
        c.until = now + Double.random(in: r)
    }

    func startSleep(_ c: Cat, short: Bool = false) {
        c.state = .sleep
        c.until = now + (short ? Double.random(in: 15...30) : Double.random(in: 40...120))
    }

    /// Returns true when the cat stands on `s` at `tx`; otherwise starts the next step toward it.
    @discardableResult
    func navigate(_ c: Cat, to s: Surface, x tx0: CGFloat, speed: CGFloat? = nil) -> Bool {
        guard let cur = c.surface else { return false }
        let tx = clampOn(s, tx0)
        if cur == s {
            if abs(c.pos.x - tx) < 4 { return true }
            startWalk(c, tx, speed: speed)
            return false
        }
        switch (cur, s) {
        case (.window, .ground):
            getDown(c, toward: tx)
        case (.ground, .window(let id)):
            guard let p = platforms[id] else { return false }
            let seg = p.nearestSeg(c.pos.x)
            let height = p.y - groundY
            if height < 150 {
                let inside = p.clampX(c.pos.x, inset: 16)
                if abs(inside - c.pos.x) < 70 {
                    startJump(c, to: CGPoint(x: inside, y: p.y), target: s)
                } else {
                    startWalk(c, inside + (c.pos.x < inside ? -50 : 50), speed: speed)
                }
                return false
            }
            let useLeft = abs(c.pos.x - seg.lo) < abs(c.pos.x - seg.hi)
            let edge = useLeft ? seg.lo : seg.hi
            let side: CGFloat = useLeft ? -1 : 1
            // window hangs above the floor → run up and leap onto its side
            let gap = p.rect.minY - groundY
            let floating = gap > 20
            if floating && gap > 450 { c.goal = .none; return false }   // too high to leap from the floor
            let base = edge + side * (floating ? 55 : 4) * c.scale
            if abs(c.pos.x - base) > 5 {
                startWalk(c, base, speed: speed)
            } else if floating {
                c.climbWin = id
                c.climbSide = side
                let grabY = min(p.rect.minY + 20, p.y - 40 * c.scale)
                startJump(c, to: CGPoint(x: edge, y: grabY), target: .ground, height: 26)
                c.jDur = Double(0.3 + min(1.0, (grabY - groundY) / 900))
                c.jumpToClimb = true
            } else {
                c.state = .climb
                c.climbWin = id
                c.climbSide = side
                c.surface = nil
                c.pos.x = edge
                c.phase = 0
            }
        case (.window(let a), .window(let b)):
            guard let pa = platforms[a], let pb = platforms[b] else { jumpDown(c, toward: tx); return false }
            let land = pb.clampX(c.pos.x, inset: 16)
            if abs(pb.y - pa.y) < 230 && abs(land - c.pos.x) < 280 {
                startJump(c, to: CGPoint(x: land, y: pb.y), target: s)
            } else {
                jumpDown(c, toward: tx)
            }
        default: break
        }
        return false
    }

    func pursueGoal(_ c: Cat) -> Bool {
        switch c.goal {
        case .none: return false
        case .snuggle(let id): return pursueSnuggle(c, id)
        case .edge(let side): return pursueEdge(c, side)
        case .slide: return pursueSlide(c)
        case .under(let id): return pursueUnder(c, id)
        case .scratchWall(let side): return pursueWallScratch(c, side)
        case .eat(let id), .drink(let id):
            guard let b = bowl(id), b.amount > 0.01, let bs = b.surface else { c.goal = .none; return false }
            let side: CGFloat = c.pos.x < b.pos.x ? -1 : 1
            let tx = b.pos.x + side * 21 * c.scale
            let hungry: CGFloat = 70
            if navigate(c, to: bs, x: tx, speed: hungry) {
                c.facing = -side
                if case .eat = c.goal { c.state = .eat } else { c.state = .drink }
                c.until = now + 4
                c.goal = .none
            }
            return true
        case .visit(let id), .sleepUp(let id):
            guard platforms[id] != nil else { c.goal = .none; return false }
            if c.surface == .window(id) {
                let sleepy = c.goal == .sleepUp(id)
                c.goal = .none
                if sleepy { startSleep(c) } else {
                    [{ self.idle(c, .loaf, 6...14) }, { self.startSleep(c, short: true) },
                     { self.idle(c, .scratch, 2.5...4) }, { self.idle(c, .sit, 3...6) }].randomElement()!()
                }
                return true
            }
            navigate(c, to: .window(id), x: c.goalX)
            return true
        }
    }

    func decide(_ c: Cat) {
        if c.goal != .none {
            if now > c.goalDeadline { c.goal = .none } else if pursueGoal(c) { return }
        }
        func setGoal(_ g: Goal, x: CGFloat = 0) {
            c.goal = g
            c.goalX = x
            c.goalDeadline = now + 45
            if !pursueGoal(c) { idle(c, .sit, 2...4) }
        }
        if c.stats.food < 0.35, let b = nearestBowl(.food, to: c) { setGoal(.eat(b.id)); return }
        if c.stats.water < 0.35, let b = nearestBowl(.water, to: c) { setGoal(.drink(b.id)); return }
        if c.stats.food < 0.25 && Double.random(in: 0...1) < 0.5 {
            c.say("Meow!", 2.5, now: now); idle(c, .sit, 3...5); return
        }
        if c.stats.water < 0.25 && Double.random(in: 0...1) < 0.5 {
            c.say("Meow!", 2.5, now: now); idle(c, .sit, 3...5); return
        }
        if c.stats.energy < 0.25 {
            if joinSleeper(c, chance: 0.85) { return }
            if case .window = c.surface { startSleep(c); return }
            if let p = randomPlatform(), Double.random(in: 0...1) < 0.75 {
                setGoal(.sleepUp(p.id), x: p.clampX(CGFloat.random(in: p.rect.minX...p.rect.maxX), inset: 30)); return
            }
            startSleep(c); return
        }
        if c.stats.energy < 0.6, joinSleeper(c, chance: 0.25) { return }
        if tryAmbush(c) { return }
        if trySocial(c) { return }
        if c.surface == .ground && Double.random(in: 0...1) < 0.04 { startEdgeTour(c); return }
        if c.surface == .ground && Double.random(in: 0...1) < 0.06 { startWallScratch(c); return }
        if c.surface == .ground && Double.random(in: 0...1) < 0.12 && tryUnder(c) { return }
        let r = Double.random(in: 0...1)
        if c.surface == .ground {
            if r < 0.32 {
                startWalk(c, CGFloat.random(in: minX...maxX))
            } else if r < 0.58, let p = randomPlatform() {
                setGoal(.visit(p.id), x: p.clampX(CGFloat.random(in: p.rect.minX...p.rect.maxX), inset: 30))
            } else if r < 0.72 {
                idle(c, .sit, 3...7)
            } else if r < 0.84 {
                idle(c, .loaf, 5...12)
            } else if r < 0.89 {
                idle(c, .groom, 3...5)
            } else if r < 0.95 {
                idle(c, .scratch, 2.5...4)      // claws on the bottom edge of the screen
            } else if !joinSleeper(c, chance: 0.6) {
                startSleep(c, short: true)
            }
        } else if case .window(let id) = c.surface, let p = platforms[id] {
            if r < 0.22 {
                startWalk(c, CGFloat.random(in: p.rect.minX...p.rect.maxX))
            } else if r < 0.42 {
                if !joinSleeper(c, chance: 0.5) { startSleep(c) }
            } else if r < 0.57 {
                idle(c, .loaf, 6...14)
            } else if r < 0.71 {
                idle(c, .scratch, 2.5...4)
            } else if r < 0.80 {
                idle(c, Bool.random() ? .sit : .groom, 3...6)
            } else if r < 0.91, let q = platformList.filter({ $0.id != id && abs($0.y - p.y) < 230 }).randomElement() {
                navigate(c, to: .window(q.id), x: c.pos.x)
                if c.state != .jump { idle(c, .sit, 2...3) }
            } else {
                getDown(c, toward: c.pos.x + CGFloat.random(in: -100...100))
            }
        } else {
            idle(c, .sit, 1...2)
        }
    }

    func laserChase(_ c: Cat, _ dt: Double) {
        guard c.surface != nil else { return }
        let ts = surfaceUnder(mouse)
        c.stats.fun = min(1, c.stats.fun + dt * 0.04)
        c.goal = .none
        let up = mouse.y - c.pos.y
        if now > c.leapReady && abs(mouse.x - c.pos.x) < 150 * c.scale && up > 75 && up < 460
            && Double.random(in: 0...1) < dt * 2.5 {
            c.leapReady = now + Double.random(in: 0.7...1.6)
            catchLeap(c)
            return
        }
        if c.surface == ts {
            let tx = clampOn(ts, mouse.x)
            let dx = tx - c.pos.x
            if abs(dx) > 16 * c.scale {
                startWalk(c, tx, speed: 190)
            } else {
                if c.state != .crouch { c.state = .crouch }
                c.until = now + 1
                c.facing = mouse.x >= c.pos.x ? 1 : -1
                if mouse.y - c.pos.y < 80 && Double.random(in: 0...1) < dt * 1.6 {
                    startJump(c, to: CGPoint(x: clampOn(ts, mouse.x + c.facing * 12), y: c.pos.y), target: ts, height: 30)
                }
            }
        } else {
            navigate(c, to: ts, x: mouse.x, speed: 190)
        }
    }

    func petting(_ c: Cat, _ dt: Double) {
        let pettable = c.interruptible || c.state == .sleep
        if pettable && c.bodyRect.contains(mouse) && dragCat == nil {
            c.hoverTime += dt
        } else {
            c.hoverTime = max(0, c.hoverTime - dt * 2)
        }
        guard c.hoverTime > 0.5 else { return }
        if c.state != .sleep {
            if c.state != .purr { c.state = .purr }
            c.until = now + 1.5
        }
        c.stats.fun = min(1, c.stats.fun + dt * 0.08)
        if now - c.lastHeart > 0.45 {
            c.lastHeart = now
            c.hearts.append((now, CGFloat.random(in: -12...12)))
        }
    }

    func renderInfo(_ c: Cat) -> RenderInfo {
        var ri = RenderInfo()
        ri.t = now + c.tOffset
        ri.facing = c.facing
        ri.phase = c.phase
        switch c.state {
        case .walk: ri.pose = c.speed > 100 * c.scale ? .run : .walk
        case .sit: ri.pose = .sit
        case .loaf: ri.pose = .loaf
        case .groom: ri.pose = .groom; ri.eyes = .closed
        case .sleep: ri.pose = .sleep; ri.eyes = .closed
        case .scratch: ri.pose = .scratch; ri.eyes = .happy
        case .climb: ri.pose = .climb; ri.climbSide = c.climbSide
        case .jump:
            let u = (now - c.jStart) / c.jDur
            if u < 0 {
                ri.pose = .crouch      // gathering before the take-off
            } else {
                ri.pose = .jump
                ri.progress = CGFloat(u)
                ri.rotation = CGFloat(0.3 * cos(u * .pi)) * (c.jTo.y >= c.jFrom.y ? 1 : 0.6)
            }
            ri.eyes = .wide
        case .fall:
            ri.pose = .fall; ri.eyes = .wide; ri.mouthOpen = true
            ri.rotation = sin(CGFloat(ri.t) * 7) * 0.22
        case .hiss: ri.pose = .hiss; ri.eyes = .angry; ri.mouthOpen = true; ri.shake = 0.9
        case .grumpy: ri.pose = .grumpy; ri.eyes = .angry
        case .eat, .drink: ri.pose = .eat; ri.eyes = .closed
        case .purr: ri.pose = .purr; ri.eyes = .happy; ri.blush = true
        case .dragged: ri.pose = .dangle; ri.eyes = .wide
        case .crouch: ri.pose = .crouch; ri.eyes = .wide
        case .hang:
            ri.pose = c.hangSlot == 2 ? .hangBack : .hangSide
            ri.eyes = c.hangSlot == 1 ? .happy : .wide
            ri.swing = c.swing
        case .stalk: ri.pose = .stalk; ri.eyes = .wide
        case .wiggle: ri.pose = .wiggle; ri.eyes = .wide
        case .wallClimb, .wallDown: ri.pose = .climb; ri.climbSide = c.climbSide
        case .wallScratch: ri.pose = .wallScratch; ri.eyes = .happy
        case .slideDown:
            ri.pose = .slide; ri.eyes = .wide; ri.climbSide = c.climbSide
            ri.progress = min(1, c.slideV / 320)
        case .underWin: ri.pose = .traverse; ri.swing = sin(c.phase) * 0.12
        case .social:
            ri.pose = c.socialPose
            ri.eyes = c.socialEyes
            ri.rotation = c.socialRot
            ri.blush = c.duo?.kind == .sniff
        }
        if ri.eyes == .open {
            if now > c.blinkAt + 0.14 { c.blinkAt = now + Double.random(in: 2.5...6) }
            if now > c.blinkAt { ri.eyes = .closed }
            else if c.stats.energy < 0.2 { ri.eyes = .sleepy }
        }
        if (c.state == .stalk || c.state == .wiggle), let id = c.huntTarget, let t = cats[id] {
            let dx = t.pos.x - c.pos.x, dy = t.pos.y - c.pos.y
            let l = max(1, hypot(dx, dy))
            ri.look = CGPoint(x: dx / l, y: dy / l)
        } else if app.laser || c.state == .crouch {
            let dx = mouse.x - c.pos.x, dy = mouse.y - (c.pos.y + 28 * c.scale)
            let l = max(1, hypot(dx, dy))
            ri.look = CGPoint(x: dx / l, y: dy / l)
        }
        return ri
    }
}
