import AppKit

// MARK: - Cats playing with each other

enum SocialKind { case sniff, boxing, wrestle, chase }

final class Duo {
    let a: Cat, b: Cat
    var kind: SocialKind
    var approaching = true
    var until: Double
    var deadline: Double
    var mid: CGFloat = 0
    var runner: Cat
    var runX: CGFloat = 0
    var chaseStart = 0.0
    var ended = false

    init(a: Cat, b: Cat, kind: SocialKind, now: Double) {
        self.a = a
        self.b = b
        self.kind = kind
        self.until = now + 10
        self.deadline = now + 30
        self.runner = a
    }
}

extension World {

    // MARK: hunting the laser: leap, catch, hang (max 3: left, right, back-to-user)

    func freeHangSlot(prefer: Int) -> Int? {
        let taken = Set(cats.values.filter { $0.state == .hang }.map(\.hangSlot))
        for s in [prefer, 1 - prefer, 2] where !taken.contains(s) { return s }
        return nil
    }

    func catchLeap(_ c: Cat) {
        let s = c.scale
        let dir: CGFloat = mouse.x >= c.pos.x ? 1 : -1
        startJump(c, to: CGPoint(x: mouse.x - dir * 20 * s, y: mouse.y - 22 * s), target: .ground, height: 24)
        c.catchJump = true
    }

    /// Called every frame of a catch leap. True when the cat got hold of the cursor.
    func tryCatch(_ c: Cat) -> Bool {
        let s = c.scale
        let paw = CGPoint(x: c.pos.x + c.facing * 24 * s, y: c.pos.y + 20 * s)
        guard hypot(paw.x - mouse.x, paw.y - mouse.y) < 36 * s else { return false }
        guard let slot = freeHangSlot(prefer: c.pos.x < mouse.x ? 0 : 1) else { return false }
        c.catchJump = false
        c.state = .hang
        c.hangSlot = slot
        c.surface = nil
        c.until = now + Double.random(in: 4...9)
        c.swing = 0
        c.swingV = -c.facing * 2.5   // momentum of the leap
        c.say("Meow!", 1.2, now: now)
        c.stats.fun = min(1, c.stats.fun + 0.15)
        // the cat with its back to you hangs in front of the others
        if slot == 2 { overlay.root.addSubview(c.view, positioned: .above, relativeTo: nil) }
        return true
    }

    func updateHang(_ c: Cat, _ dt: Double) {
        let s = c.scale
        // Pendulum hanging from the cursor: moving the cursor accelerates the pivot,
        // the body lags behind, swings back and slowly settles.
        let f = CGFloat(dt)
        let L = 48 * s
        let ax = max(-40000, min(40000, mouseAcc.dx))
        let ay = max(-40000, min(40000, mouseAcc.dy))
        let g = max(300, 1900 + ay)
        let alpha = -(g / L) * sin(c.swing) - (ax / L) * cos(c.swing) - 1.6 * c.swingV
        c.swingV += alpha * f
        c.swing += c.swingV * f
        if abs(c.swing) > 1.35 { c.swing = 1.35 * (c.swing > 0 ? 1 : -1); c.swingV *= -0.3 }
        switch c.hangSlot {
        case 0: c.facing = 1; c.pos = CGPoint(x: mouse.x - 16 * s, y: mouse.y - 56 * s)
        case 1: c.facing = -1; c.pos = CGPoint(x: mouse.x + 16 * s, y: mouse.y - 56 * s)
        default: c.pos = CGPoint(x: mouse.x, y: mouse.y - 56 * s)
        }
        let shaken = hypot(mouseVel.dx, mouseVel.dy) > 3500
        if !app.laser || now > c.until || shaken {
            startFall(c, gentle: !shaken)
            c.vel = CGVector(dx: mouseVel.dx * 0.25 + c.swingV * L * cos(c.swing) * 0.6, dy: max(-300, min(300, mouseVel.dy * 0.25)))
            c.swing = 0
            c.swingV = 0
            if shaken { c.say("Meow!!", 1.2, now: now, alert: true) }
            c.leapReady = now + 2
        }
    }

    // MARK: social play

    func trySocial(_ c: Cat) -> Bool {
        guard cats.count > 1, now > c.socialReady, !app.laser, c.stats.energy > 0.25, let surf = c.surface,
              Double.random(in: 0...1) < 0.35 else { return false }
        let ok: Set<CatState> = [.sit, .loaf, .groom, .walk]
        let others = cats.values.filter {
            $0 !== c && $0.duo == nil && $0.surface == surf && now > $0.socialReady &&
            ok.contains($0.state) && $0.stats.energy > 0.2 && abs($0.pos.x - c.pos.x) < 700
        }
        guard let o = others.randomElement() else { return false }
        let r = Double.random(in: 0...1)
        let kind: SocialKind = r < 0.3 ? .sniff : r < 0.55 ? .boxing : r < 0.8 ? .chase : .wrestle
        let d = Duo(a: c, b: o, kind: kind, now: now)
        duos.append(d)
        for x in [c, o] {
            x.duo = d
            x.state = .social
            x.goal = .none
            x.socialPose = .walk
            x.socialEyes = .open
            x.socialRot = 0
        }
        if kind == .chase { startChase(d, runner: o) }
        return true
    }

    func startChase(_ d: Duo, runner: Cat) {
        let chaser = runner === d.a ? d.b : d.a
        let dir: CGFloat = runner.pos.x >= chaser.pos.x ? 1 : -1
        d.kind = .chase
        d.approaching = false
        d.runner = runner
        d.runX = clampOn(runner.surface ?? .ground, runner.pos.x + dir * CGFloat.random(in: 250...600))
        if abs(d.runX - runner.pos.x) < 80 {   // cornered: run the other way
            d.runX = clampOn(runner.surface ?? .ground, runner.pos.x - dir * CGFloat.random(in: 250...600))
        }
        d.chaseStart = now
        d.until = now + 7
        runner.say("Meow!", 1.2, now: now)
    }

    func endDuo(_ d: Duo) {
        d.ended = true
        for c in [d.a, d.b] {
            c.duo = nil
            c.socialReady = now + Double.random(in: 15...40)
            c.socialRot = 0
            if c.state == .social {
                [{ self.idle(c, .sit, 2...4) }, { self.idle(c, .groom, 3...5) }, { self.idle(c, .loaf, 4...8) }].randomElement()!()
            }
        }
    }

    /// Moves a cat toward x on its surface; true when it got there.
    @discardableResult
    func moveSocial(_ c: Cat, to x0: CGFloat, speed: CGFloat, _ dt: Double) -> Bool {
        let x = clampOn(c.surface ?? .ground, x0)
        let dx = x - c.pos.x
        let step = speed * c.scale * CGFloat(dt)
        if abs(dx) <= step { c.pos.x = x; return true }
        c.facing = dx > 0 ? 1 : -1
        c.pos.x += c.facing * step
        c.phase += step / (c.scale * (speed > 100 ? 34 : 22)) * 2 * .pi
        c.socialPose = speed > 100 ? .run : .walk
        c.socialEyes = .open
        return false
    }

    func updateDuos(_ dt: Double) {
        for d in duos where !d.ended {
            let a = d.a, b = d.b
            guard a.state == .social, b.state == .social, a.surface != nil, a.surface == b.surface,
                  cats[a.cfg.id] === a, cats[b.cfg.id] === b, !app.laser, now < d.deadline else {
                endDuo(d)
                continue
            }
            stepDuo(d, dt)
        }
        duos.removeAll { $0.ended }
    }

    private func stepDuo(_ d: Duo, _ dt: Double) {
        let (l, r) = d.a.pos.x <= d.b.pos.x ? (d.a, d.b) : (d.b, d.a)
        let gap = 31 * (l.scale + r.scale) / 2
        let t = CGFloat(now)

        if d.approaching {
            let mid = clampOn(l.surface!, (l.pos.x + r.pos.x) / 2)
            let okL = moveSocial(l, to: mid - gap / 2, speed: 80, dt)
            let okR = moveSocial(r, to: mid + gap / 2, speed: 80, dt)
            if okL && okR {
                d.approaching = false
                d.mid = mid
                l.facing = 1
                r.facing = -1
                switch d.kind {
                case .sniff: d.until = now + 2.5
                case .boxing: d.until = now + 3.5
                case .wrestle: d.until = now + 3.5
                case .chase: break
                }
            }
            return
        }

        switch d.kind {
        case .sniff:
            for c in [l, r] { c.socialPose = .stand; c.socialEyes = .closed }
            l.facing = 1; r.facing = -1
            if now > d.until - 1, Int(now * 3) % 2 == 0, l.hearts.count < 2 {
                l.hearts.append((now, CGFloat.random(in: -6...6)))
            }
            if now > d.until {
                let x = Double.random(in: 0...1)
                if x < 0.35 { d.kind = .boxing; d.until = now + 3.5 }
                else if x < 0.55 { startChase(d, runner: Bool.random() ? l : r) }
                else { endDuo(d) }
            }

        case .boxing:
            l.facing = 1; r.facing = -1
            for c in [l, r] { c.socialPose = .swat; c.socialEyes = .wide }
            l.pos.x = d.mid - gap / 2 + sin(t * 3) * 3
            r.pos.x = d.mid + gap / 2 + sin(t * 3 + 1) * 3
            if Double.random(in: 0...1) < dt * 0.8 {
                (Bool.random() ? l : r).say(["Meow!", "Mew!"].randomElement()!, 0.7, now: now)
            }
            if now > d.until {
                if Double.random(in: 0...1) < 0.6 { d.kind = .wrestle; d.until = now + 3.5 }
                else { startChase(d, runner: Bool.random() ? l : r) }
            }

        case .wrestle:
            let center = clampOn(l.surface!, d.mid + sin(t * 2.2) * 30)
            l.pos.x = center - 7 * l.scale * cos(t * 5)
            r.pos.x = center + 7 * r.scale * cos(t * 5)
            l.socialRot += CGFloat(dt) * 9
            r.socialRot -= CGFloat(dt) * 9
            for c in [l, r] { c.socialPose = .roll; c.socialEyes = Bool.random() ? .angry : .closed }
            if Double.random(in: 0...1) < dt * 0.7 {
                (Bool.random() ? l : r).say(["Meow!", "Meeow!"].randomElement()!, 0.6, now: now)
            }
            if now > d.until {
                for c in [l, r] { c.socialRot = 0 }
                if Double.random(in: 0...1) < 0.5 { startChase(d, runner: Bool.random() ? l : r) } else { endDuo(d) }
            }

        case .chase:
            let runner = d.runner
            let chaser = runner === l ? r : l
            for c in [l, r] { c.socialRot = 0 }
            let arrived = moveSocial(runner, to: d.runX, speed: 160, dt)
            let dir: CGFloat = runner.pos.x >= chaser.pos.x ? 1 : -1
            moveSocial(chaser, to: runner.pos.x - dir * 18 * chaser.scale, speed: 172, dt)
            if hypot(runner.pos.x - chaser.pos.x, 0) < 24 * chaser.scale && now > d.chaseStart + 1.2 {
                d.kind = .wrestle
                d.mid = runner.pos.x
                d.until = now + 3
            } else if arrived || now > d.until {
                endDuo(d)
            }
        }
    }

    /// A grumpy cat hisses at anyone who comes too close; they back off.
    func grumpyHiss(_ c: Cat) {
        guard now > c.lastHiss + 2.5 else { return }
        for o in cats.values where o !== c && o.surface == c.surface && o.interruptible
            && abs(o.pos.x - c.pos.x) < 70 * c.scale {
            c.lastHiss = now
            c.facing = o.pos.x > c.pos.x ? 1 : -1
            startWalk(o, o.pos.x + (o.pos.x > c.pos.x ? 1 : -1) * 220, speed: 150)
            return
        }
    }

    // MARK: sleeping together

    /// A free spot right next to a sleeping cat (cats curl up touching, faces together).
    func snuggleSpot(_ c: Cat, beside t: Cat) -> CGFloat? {
        guard let surf = t.surface else { return nil }
        let gap = 40 * (c.scale + t.scale) / 2
        let first: CGFloat = c.pos.x < t.pos.x ? -1 : 1
        for side in [first, -first] {
            let x = t.pos.x + side * gap
            if abs(clampOn(surf, x) - x) > 6 { continue }
            let busy = cats.values.contains { o in
                o !== c && o !== t && o.surface == surf && abs(o.pos.x - x) < 18 * o.scale
            }
            if !busy { return x }
        }
        return nil
    }

    /// Go curl up next to someone who is already asleep.
    func joinSleeper(_ c: Cat, chance: Double) -> Bool {
        guard Double.random(in: 0...1) < chance, let cur = c.surface else { return false }
        let sleepers = cats.values.filter { $0 !== c && $0.state == .sleep && $0.surface != nil && snuggleSpot(c, beside: $0) != nil }
        // prefer someone on the same surface, then the closest
        guard let t = sleepers.min(by: { a, b in
            let pa = (a.surface == cur ? 0 : 2000) + abs(a.pos.x - c.pos.x)
            let pb = (b.surface == cur ? 0 : 2000) + abs(b.pos.x - c.pos.x)
            return pa < pb
        }) else { return false }
        c.goal = .snuggle(t.cfg.id)
        c.goalDeadline = now + 45
        if !pursueSnuggle(c, t.cfg.id) { c.goal = .none; return false }
        return true
    }

    func pursueSnuggle(_ c: Cat, _ id: UUID) -> Bool {
        guard let t = cats[id], t.state == .sleep, let surf = t.surface, let spot = snuggleSpot(c, beside: t) else {
            c.goal = .none
            return false
        }
        if navigate(c, to: surf, x: spot, speed: 40) {
            c.goal = .none
            c.facing = t.pos.x > c.pos.x ? 1 : -1
            startSleep(c)
            // fall asleep and wake up roughly together
            let end = max(c.until, t.until) + Double.random(in: 0...10)
            c.until = end
            t.until = end + Double.random(in: -5...5)
            c.snuggleWith = id
            t.snuggleWith = c.cfg.id
            c.hearts.append((now, 0))
        }
        return true
    }
}
