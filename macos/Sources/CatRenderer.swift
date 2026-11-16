import AppKit

// Flat silhouette style: no outlines, big pointy ears, white eyes with black pupils,
// tiny dash mouth, whiskers sticking out past the silhouette.

struct CatLook {
    let base: CGColor, accent: CGColor, white: CGColor
    let faceLine: CGColor, whisker: CGColor, lid: CGColor
    let pattern: CoatPattern
    let eyeL: CGColor, eyeR: CGColor
    let seed: UInt32
    let hat: String
    let outfit: String
    let baseHex: UInt32, accentHex: UInt32, eyeHexL: UInt32, eyeHexR: UInt32

    init(_ c: CatConfig) {
        let p = preset(c.coat)
        baseHex = p.base; accentHex = p.accent
        (eyeHexL, eyeHexR) = c.eyes.hexes
        let b = NSColor(hex: p.base)
        base = b.cgColor
        accent = NSColor(hex: p.accent).cgColor
        white = NSColor(hex: 0xF8F7F3).cgColor
        let lum = (b.usingColorSpace(.sRGB)?.brightnessComponent ?? 0.5)
        let dark = lum < 0.4 && p.pattern != .calico
        faceLine = dark ? NSColor(hex: 0xBDBCC2).cgColor : NSColor(hex: 0x3A3535).cgColor
        whisker = dark ? b.darker(0.7).cgColor : NSColor(hex: 0x3A3535, alpha: 0.75).cgColor
        // lids take the colour of the face (white face on calico/bicolor masks is close enough)
        lid = (p.pattern == .calico ? NSColor(hex: p.base) : b).cgColor
        pattern = p.pattern
        let e = c.eyes.colors
        eyeL = e.0.cgColor; eyeR = e.1.cgColor
        seed = c.seed
        // items that were renamed or removed: swap or take them off
        let h = c.hat == "pig" ? "pinkdino" : (c.hat ?? "none")
        hat = hatOptions.contains { $0.id == h } ? h : "none"
        let o = c.outfit ?? "none"
        outfit = outfitOptions.contains { $0.id == o } ? o : "none"
    }
}

enum Pose { case stand, walk, run, sit, loaf, crouch, sleep, scratch, climb, fall, jump, hiss, grumpy, eat, groom, purr, dangle,
            hangSide, hangBack, swat, roll, stalk, wiggle, traverse, slide, wallScratch }
enum EyeMode { case open, closed, happy, wide, angry, sleepy }

struct RenderInfo {
    var pose: Pose = .sit
    var facing: CGFloat = 1
    var phase: CGFloat = 0
    var t: Double = 0
    var eyes: EyeMode = .open
    var look: CGPoint = .zero
    var mouthOpen = false
    var climbSide: CGFloat = -1
    var rotation: CGFloat = 0
    var shake: CGFloat = 0
    var blush = false
    var swing: CGFloat = 0      // pendulum angle while hanging (world: + = body to the right)
    var progress: CGFloat = 0   // 0…1 through a jump
}

enum PartKind { case torso, haunch, leg, tail, head, ear }
struct Part { let kind: PartKind; let path: CGPath }

struct Geo {
    var parts: [Part] = []
    var head = CGPoint.zero
    var headR: CGFloat = 11.5
    var torsoRect = CGRect.zero
    var torsoC = CGPoint.zero
    var torsoShape: CGPath?      // the real silhouette of the body, for things that must sit on it
    var belly: CGRect?
    var chest: CGRect?
    var tail: [CGPoint] = []
    var tailW: CGFloat = 5
    var earsFlat = false
    var legLowY: CGFloat = 6
    var scratchMarks = false
    var grounded = true
    var overParts: [Part] = []
    var backView = false
    var pivot: CGPoint?
    var clawTrail: CGFloat = 0   // sliding down a wall: claw streaks above the paws
    var wallMarks = false        // scratching the screen side: streaks on the wall in front
}

private struct LCG {
    var s: UInt32
    mutating func next() -> CGFloat {
        s = s &* 1664525 &+ 1013904223
        return CGFloat(s >> 8) / CGFloat(1 << 24)
    }
}

func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func lerpP(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { P(lerp(a.x, b.x, t), lerp(a.y, b.y, t)) }
func smooth(_ x: CGFloat) -> CGFloat { let u = max(0, min(1, x)); return u * u * (3 - 2 * u) }

func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, rot: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rot)
    return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: &t)
}

func ovalRect(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
    CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
}

func stroked(_ pts: [CGPoint], _ w: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: pts)
    return p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4)
}

func chain(_ base: CGPoint, _ angles: [CGFloat], _ len: CGFloat) -> [CGPoint] {
    var pts = [base]
    var p = base
    let sub = 3
    for i in 0..<angles.count {
        let a0 = angles[i], a1 = angles[min(i + 1, angles.count - 1)]
        for j in 0..<sub {
            let a = (a0 + (a1 - a0) * CGFloat(j) / CGFloat(sub)) * .pi / 180
            p = P(p.x + cos(a) * len / CGFloat(sub), p.y + sin(a) * len / CGFloat(sub))
            pts.append(p)
        }
    }
    return pts
}

func poly(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: pts)
    p.closeSubpath()
    return p
}

let hatOptions: [(id: String, name: String)] = [
    ("none", "No hat"), ("shark", "Shark"), ("frog", "Frog"), ("crown", "Crown"), ("party", "Party hat"),
    ("bow", "Bow"), ("spider", "Spider mask"), ("horns", "Horned helm"), ("winged", "Winged helm"),
] + hoodHats
let outfitOptions: [(id: String, name: String)] = [
    ("none", "No costume"), ("cape", "Hero cape"), ("bowtie", "Bow tie"),
    ("shield", "Star shield"), ("reactor", "Glowing reactor"),
] + costumeOrder.map { ($0, costumes[$0]!.name) }

enum CatRenderer {

    // MARK: geometry per pose (cat faces +x, feet at origin, y up)

    private static func geo(_ ri: RenderInfo) -> Geo {
        var g = Geo()
        let t = CGFloat(ri.t)

        func leg(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat = 5.4) {
            g.parts.append(Part(kind: .leg, path: stroked([a, b], w)))
        }
        func leg3(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ w: CGFloat = 5.4) {
            g.parts.append(Part(kind: .leg, path: stroked([a, b, c], w)))
        }
        func torso(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat = 0) {
            let shape = ellipse(c, rx, ry, rot: rot)
            g.parts.append(Part(kind: .torso, path: shape))
            g.torsoShape = shape
            g.torsoRect = ovalRect(c.x, c.y, rx, ry)
            g.torsoC = c
        }
        func torsoPath(_ p: CGPath) {
            g.parts.append(Part(kind: .torso, path: p))
            g.torsoShape = p
            g.torsoRect = p.boundingBoxOfPath
            g.torsoC = P(g.torsoRect.midX, g.torsoRect.midY)
        }
        func tail(_ base: CGPoint, _ angles: [CGFloat], _ len: CGFloat, w: CGFloat = 4.8,
                  sway: CGFloat = 8, speed: CGFloat = 2.2) {
            var a = angles
            for i in a.indices {
                a[i] += sin(t * speed + CGFloat(i) * 0.7) * sway * CGFloat(i + 1) / CGFloat(a.count)
            }
            let pts = chain(base, a, len)
            g.tail = pts
            g.tailW = w
            g.parts.insert(Part(kind: .tail, path: stroked(pts, w)), at: 0)
        }
        func head(_ c: CGPoint, _ r: CGFloat = 11.5) { g.head = c; g.headR = r }

        /// Seated bell silhouette (narrow neck, wide base) as in the reference art.
        func bell(_ lean: CGFloat = 0) -> CGPath {
            let p = CGMutablePath()
            p.move(to: P(-6 + lean, 27))
            p.addQuadCurve(to: P(-15, 1.5), control: P(-14 + lean * 0.5, 15))
            p.addQuadCurve(to: P(-12, 0), control: P(-15, 0))
            p.addLine(to: P(11, 0))
            p.addQuadCurve(to: P(13, 2), control: P(13, 0))
            p.addQuadCurve(to: P(6 + lean, 27), control: P(12 + lean * 0.5, 13))
            p.addQuadCurve(to: P(-6 + lean, 27), control: P(lean, 30))
            p.closeSubpath()
            return p
        }

        switch ri.pose {
        case .climb:
            let p = ri.phase
            let bob = sin(p) * 2.2
            tail(P(-13, 5 + bob), [258, 264, 270, 276, 282, 288], 4.6, sway: 14, speed: 2.6)
            let push = cos(p) * 4.5
            for (i, dx) in [CGFloat(-2.5), 2.5].enumerated() {
                let lag = CGFloat(i) * 2
                leg3(P(-12 + dx * 0.5, 9 + bob), P(-17 + dx, -1 + bob * 0.5 + push * 0.3 + lag), P(-1.5, 2 + push + lag), 5.6)
            }
            torso(P(-10, 21 + bob), 9, 16.5, -0.14)
            let r1 = sin(p) * 5.5, r2 = sin(p + .pi) * 5.5
            leg(P(-5, 30 + bob), P(1.5, 41 + r2), 5.2)
            g.overParts.append(Part(kind: .leg, path: stroked([P(-5, 30 + bob), P(-0.5, 38 + bob), P(2.5, 47 + r1)], 5.4)))
            g.belly = ovalRect(-4, 21 + bob, 4.5, 12)
            g.chest = ovalRect(-5, 31 + bob, 5, 6)
            head(P(-14, 39 + bob), 11)
            g.legLowY = -100
            g.grounded = false

        case .wallScratch:
            // up on the hind legs at the screen side (wall at x = 18), front paws raking down
            let s1 = sin(t * 13) * 3.5, s2 = sin(t * 13 + .pi) * 3.5
            tail(P(-8, 3), [190, 160, 130, 110, 100, 95], 4.4, sway: 8, speed: 3)
            leg3(P(-1, 10), P(-5, 5), P(-2, 2.4), 5.6)
            leg3(P(3, 10), P(0, 5), P(4, 2.4), 5.6)
            torso(P(5, 22), 8.5, 17, -0.32)
            leg(P(8, 32), P(16.5, 54 + s1), 5)
            g.overParts.append(Part(kind: .leg, path: stroked([P(9, 31), P(14, 42), P(17, 50 + s2)], 5.2)))
            g.belly = ovalRect(8, 21, 4, 12)
            g.chest = ovalRect(10, 30, 5, 5)
            head(P(1, 35), 11)
            g.legLowY = 3.5
            g.wallMarks = true

        case .slide:
            // sliding down a window side, claws dug in above the head, hind legs braced on the wall
            let v = ri.progress
            let fl = sin(t * 30) * v * 1.5
            tail(P(-11, 6), [255, 262, 270, 278, 286, 294], 4.6, sway: 6 + v * 10, speed: 4)
            leg3(P(-11, 9), P(-19, 5), P(-1.5, 0 + fl), 5.4)
            leg3(P(-8, 8), P(-15, 1), P(-1.5, -3 - fl), 5.4)
            torso(P(-10, 21), 9, 16.5, -0.1)
            leg(P(-6, 31), P(1, 50 + fl), 5)
            g.overParts.append(Part(kind: .leg, path: stroked([P(-5, 30), P(-1, 41), P(2, 53 - fl)], 5.2)))
            g.belly = ovalRect(-4, 21, 4.5, 12)
            head(P(-13, 37), 11)
            g.earsFlat = true
            g.legLowY = -100
            g.grounded = false
            g.clawTrail = v

        case .stand, .walk, .eat:
            // lateral-sequence walk: hind-left, fore-left, hind-right, fore-right
            let amp: CGFloat = ri.pose == .walk ? 1 : 0
            let p = ri.phase
            let bob = amp * abs(sin(p)) * 0.8
            tail(P(-17, 17 + bob), [150, 132, 114, 100, 92, 86], 4.6)
            for (hx, off) in [(CGFloat(-13), CGFloat(0)), (-8, .pi), (8, .pi / 2), (13, 3 * .pi / 2)] {
                let fx = hx + sin(p + off) * 5.5 * amp
                let lift = max(0, cos(p + off)) * 3 * amp
                leg(P(hx, 13 + bob), P(fx, 2.4 + lift))
            }
            torso(P(0, 15.5 + bob), 18.5, 8.6)
            g.belly = ovalRect(2, 10.5 + bob, 12, 4.5)
            g.chest = ovalRect(13, 13 + bob, 5.5, 6)
            if ri.pose == .eat { head(P(21, 11 + sin(t * 6) * 0.6)) } else { head(P(19, 26 + bob * 0.5 + amp * sin(2 * ri.phase) * 0.4)) }

        case .run:
            // rotary gallop: the spine stretches (all legs out) and gathers (legs under the body)
            let p = ri.phase
            let e = sin(p)
            let air = max(0, e) * 3.5
            tail(P(-18, 17 + air), [172, 168, 165, 163, 162, 160], 4.6, sway: 10, speed: 8)
            for off in [CGFloat(0), 0.4] {
                let ph = p + off
                leg3(P(-12, 14 + air), P(-12 - 7 * sin(ph), 8 + air * 0.6),
                     P(-12 - 12 * sin(ph), 2.4 + max(0, -cos(ph)) * 4 + air * 0.4), 5.4)
            }
            torso(P(0, 15.5 + air), 19 + 3 * e, 8.6 - 1.2 * e, 0.06 * cos(p))
            for off in [CGFloat(0), 0.4] {
                let ph = p - 0.7 + off
                leg3(P(11, 14 + air), P(11 + 7 * sin(ph), 8 + air * 0.6),
                     P(11 + 13 * sin(ph), 2.4 + max(0, cos(ph)) * 4 + air * 0.4), 5.4)
            }
            g.belly = ovalRect(1, 10.5 + air, 12, 4)
            g.chest = ovalRect(13, 13 + air, 5.5, 5.5)
            head(P(21 + 2 * e, 23 + air * 0.6))

        case .sit, .purr, .grumpy, .groom, .swat:
            if ri.pose == .grumpy {
                tail(P(-12, 5), [170, 150, 135, 125, 118, 112], 4.6, sway: 24, speed: 7)
            } else if ri.pose == .swat {
                tail(P(-12, 5), [165, 140, 120, 108, 100, 94], 4.6, sway: 18, speed: 6)
            } else {
                tail(P(-12, 4), [190, 215, 260, 320, 10, 30], 4.4, sway: 5, speed: 1.4)   // curled around the base
            }
            torsoPath(bell())
            if ri.pose == .groom {
                leg(P(6, 16), P(9, 25 + sin(t * 7) * 2.5), 5)
            } else if ri.pose == .swat {
                let sw = sin(t * 11)
                leg(P(7, 17), P(17 + sw * 4, 21 + abs(sw) * 5), 5)
            }
            g.parts.append(Part(kind: .leg, path: ellipse(P(3, 1.6), 3.6, 2.3)))
            g.parts.append(Part(kind: .leg, path: ellipse(P(9, 1.6), 3.6, 2.3)))
            g.chest = ovalRect(4, 13, 6, 10)
            head(P(1, 31))
            g.earsFlat = ri.pose == .grumpy
            g.legLowY = 3.5

        case .loaf:
            tail(P(-19, 4), [200, 250, 300, 340, 0, 10], 4, sway: 4, speed: 1.2)
            torsoPath(CGPath(roundedRect: CGRect(x: -22, y: 0, width: 40, height: 18), cornerWidth: 13, cornerHeight: 9, transform: nil))
            g.chest = ovalRect(12, 7, 6, 6)
            head(P(15, 16))

        case .crouch:
            tail(P(-20, 10), [175, 172, 170, 172, 180, 195], 4.4, sway: 10, speed: 9)
            leg(P(-12, 9), P(-14, 2.4))
            leg(P(-8, 9), P(-9, 2.4))
            torso(P(-2, 10), 19, 7.6, -0.1)
            leg(P(10, 5), P(19, 2.4), 5)
            leg(P(13, 5), P(22, 2.4), 5)
            g.belly = ovalRect(0, 5.5, 11, 3.5)
            head(P(17, 12))
            g.earsFlat = false

        case .sleep:
            let b = sin(t * 1.5) * 0.6
            tail(P(-17, 8), [260, 300, 340, 5, 15, 20], 4.4, sway: 1.5, speed: 0.8)
            torso(P(0, 9.5), 19, 9.5 + b)
            leg(P(13, 3), P(18, 2.4), 4.6)
            head(P(11, 9 + b * 0.5), 10.5)

        case .scratch:
            tail(P(-20, 20), [105, 98, 92, 88, 84, 80], 4.6, sway: 6, speed: 2)
            leg(P(-13, 16), P(-14, 2.4))
            leg(P(-8, 15), P(-8, 2.4))
            torso(P(-2, 14), 19, 8.4, -0.24)
            let s1 = sin(t * 14) * 3, s2 = sin(t * 14 + .pi) * 3
            leg(P(9, 9), P(24 + s1, 2.4), 5)
            leg(P(12, 9), P(28 + s2, 3.2), 5)
            head(P(14, 13), 10.5)
            g.scratchMarks = true

        case .fall:
            tail(P(-17, 19), [100, 95, 90, 90, 90, 85], 4.6, sway: 14, speed: 9)
            leg(P(-11, 14), P(-22, 4))
            leg(P(-6, 14), P(-14, 0.5))
            torso(P(0, 17), 18, 9)
            leg(P(8, 14), P(16, 0.5))
            leg(P(12, 14), P(24, 4))
            g.belly = ovalRect(2, 11.5, 12, 5)
            head(P(19, 27))
            g.grounded = false

        case .jump:
            // keyframes: take-off stretch → tucked flight → front paws reaching down to land
            struct K { var hind: [CGPoint]; var front: [CGPoint]; var rx: CGFloat; var ry: CGFloat; var head: CGPoint; var tailA: CGFloat }
            let k0 = K(hind: [P(-28, 6), P(-25, 3)], front: [P(26, 22), P(28, 18)], rx: 23, ry: 7.6, head: P(23, 25), tailA: 185)
            let k1 = K(hind: [P(-7, 7), P(-3, 6)], front: [P(15, 8), P(18, 9)], rx: 19, ry: 9.5, head: P(20, 25), tailA: 165)
            let k2 = K(hind: [P(-24, 12), P(-21, 9)], front: [P(20, 0), P(24, 1.5)], rx: 22, ry: 8.2, head: P(22, 22), tailA: 150)
            let u = ri.progress
            let (a, b, w) = u < 0.45 ? (k0, k1, smooth(u / 0.45)) : (k1, k2, smooth((u - 0.45) / 0.55))
            let ta = lerp(a.tailA, b.tailA, w)
            tail(P(-19, 18), [ta, ta - 3, ta - 6, ta - 8, ta - 10, ta - 12], 4.8, sway: 4, speed: 4)
            for i in 0..<2 { leg(P(-13 + CGFloat(i) * 4, 15), lerpP(a.hind[i], b.hind[i], w)) }
            torso(P(0, 17), lerp(a.rx, b.rx, w), lerp(a.ry, b.ry, w))
            for i in 0..<2 { leg(P(11 + CGFloat(i) * 4, 15), lerpP(a.front[i], b.front[i], w)) }
            g.belly = ovalRect(2, 12.5, 14, 4)
            head(lerpP(a.head, b.head, w))
            g.grounded = false

        case .hiss:
            tail(P(-16, 25), [95, 92, 90, 88, 86, 84], 5, w: 9.5, sway: 3, speed: 12)
            leg(P(-12, 20), P(-13, 2.4))
            leg(P(-8, 20), P(-8, 2.4))
            torso(P(0, 22), 17, 10.5)
            let sp = CGMutablePath()
            let c = P(0, 22)
            for i in 0...18 {
                let a = (15 + CGFloat(i) * 150 / 18) * .pi / 180
                let r: CGFloat = i % 2 == 0 ? 1.0 : 1.25
                let pt = P(c.x + 17 * r * cos(a), c.y + 10.5 * r * sin(a))
                if i == 0 { sp.move(to: pt) } else { sp.addLine(to: pt) }
            }
            sp.addLine(to: c)
            sp.closeSubpath()
            g.parts.append(Part(kind: .torso, path: sp))
            g.torsoShape = sp
            leg(P(8, 20), P(9, 2.4))
            leg(P(12, 20), P(14, 2.4))
            g.belly = ovalRect(1, 15, 12, 5)
            g.chest = ovalRect(12, 19, 5.5, 5.5)
            head(P(19, 23))
            g.earsFlat = true

        case .dangle:
            tail(P(0, 8), [272, 268, 262, 258, 252, 248], 4.5, sway: 10, speed: 3)
            leg(P(-5, 10), P(-6, -3))
            leg(P(5, 10), P(6, -3))
            torso(P(0, 22), 9.5, 15)
            leg(P(-6, 30), P(-10, 19), 5)
            leg(P(6, 30), P(10, 19), 5)
            g.chest = ovalRect(0, 26, 6, 9)
            head(P(0, 42))
            g.grounded = false

        case .hangSide:
            let sw = sin(t * 3) * 3
            tail(P(-7, 10), [262, 268, 274, 280, 286, 292], 4.6, sway: 16, speed: 2.2)
            leg(P(-8, 12), P(-10 + sw, -1))
            leg(P(-3, 12), P(-1 - sw, 0))
            torso(P(-5, 25), 8.5, 15, -0.12)
            leg(P(-1, 37), P(5, 55), 5)
            g.overParts.append(Part(kind: .leg, path: stroked([P(-3, 35), P(1, 46), P(7, 56)], 5.2)))
            g.belly = ovalRect(-2, 24, 4.5, 11)
            g.chest = ovalRect(-3, 34, 5, 5)
            head(P(-9, 40), 11)
            g.legLowY = 4
            g.grounded = false
            g.pivot = P(6, 56)

        case .hangBack:
            let sw = sin(t * 3) * 3
            leg(P(-7, 34), P(-6, 57), 5.2)
            leg(P(7, 34), P(6, 57), 5.2)
            leg(P(-5, 12), P(-6 + sw, -1))
            leg(P(5, 12), P(6 - sw, -1))
            torso(P(0, 24), 10.5, 15)
            head(P(0, 42), 11.5)
            tail(P(0, 9), [268, 272, 276, 270, 262, 256], 4.6, sway: 16, speed: 2.2)
            if let ti = g.parts.firstIndex(where: { $0.kind == .tail }) { g.overParts.append(g.parts.remove(at: ti)) }
            g.legLowY = 4
            g.backView = true
            g.grounded = false
            g.pivot = P(0, 56)

        case .roll:
            tail(P(-12, 10), [200, 230, 260, 290, 320, 350], 4, sway: 20, speed: 8)
            for i in 0..<4 {
                let a = (CGFloat(i) * 90 + 45 + sin(t * 12 + CGFloat(i)) * 25) * .pi / 180
                leg(P(0, 14), P(cos(a) * 19, 14 + sin(a) * 19), 5)
            }
            torso(P(0, 14), 13, 12)
            head(P(7, 19), 10.5)

        case .stalk:
            let p = ri.phase
            tail(P(-20, 8), [182, 180, 178, 177, 180, 192], 4.4, sway: 6, speed: 6)
            for (hx, off) in [(CGFloat(-13), CGFloat(0)), (-8, .pi), (8, .pi / 2), (13, 3 * .pi / 2)] {
                let fx = hx + sin(p + off) * 3.5
                let lift = max(0, cos(p + off)) * 1.5
                leg(P(hx, 7.5), P(fx, 2.4 + lift), 5.2)
            }
            torso(P(-1, 9), 20, 6.8, 0.03)
            g.belly = ovalRect(1, 5, 13, 3.5)
            g.chest = ovalRect(14, 8, 5, 4)
            head(P(19, 10.5), 10.5)
            g.earsFlat = true

        case .wiggle:
            let w = sin(t * 16)
            tail(P(-19, 11), [178, 176, 175, 176, 182, 196], 4.4, sway: 8, speed: 12)
            leg(P(-12 + w * 1.5, 9.5), P(-14, 2.4))
            leg(P(-7 + w * 1.5, 9.5), P(-8, 2.4))
            torso(P(-2 + w * 1.2, 9), 19.5, 7.2, -0.1 + w * 0.04)
            leg(P(10, 4), P(19, 2.4), 4.8)
            leg(P(13, 4), P(22, 2.4), 4.8)
            g.belly = ovalRect(0, 5, 12, 3.5)
            head(P(18, 8.5), 10.5)
            g.earsFlat = true

        case .traverse:
            let p = ri.phase
            let sw = sin(t * 3) * 3
            tail(P(-7, 10), [262, 268, 274, 280, 286, 292], 4.6, sway: 16, speed: 2.2)
            leg(P(-8, 12), P(-10 + sw, -1))
            leg(P(-3, 12), P(-1 - sw, 0))
            torso(P(-5, 25), 8.5, 15, -0.12)
            let a = sin(p) * 6
            leg(P(-1, 37), P(3 - a, 55 - max(0, -cos(p)) * 3), 5)
            g.overParts.append(Part(kind: .leg, path: stroked([P(-3, 35), P(2, 46), P(8 + a, 56 - max(0, cos(p)) * 3)], 5.2)))
            g.belly = ovalRect(-2, 24, 4.5, 11)
            head(P(-9, 40), 11)
            g.legLowY = 4
            g.grounded = false
            g.pivot = P(5, 56)
        }
        return g
    }

    /// Tall pointed ears with slightly curved sides.
    static func earPaths(_ h: CGPoint, _ r: CGFloat, flat: Bool) -> [CGPath] {
        let k = r / 11.5
        func ear(_ s: CGFloat) -> CGPath {
            let outer = P(h.x + s * 11.5 * k, h.y + 2.5 * k)
            let inner = P(h.x + s * 2.5 * k, h.y + 9 * k)
            let tip = flat ? P(h.x + s * 19 * k, h.y + 9 * k) : P(h.x + s * 9.5 * k, h.y + 21.5 * k)
            let p = CGMutablePath()
            p.move(to: outer)
            p.addQuadCurve(to: tip, control: P(lerp(outer.x, tip.x, 0.5) + s * 1.6 * k, lerp(outer.y, tip.y, 0.5)))
            p.addQuadCurve(to: inner, control: P(lerp(tip.x, inner.x, 0.5) - s * 0.6 * k, lerp(tip.y, inner.y, 0.5) + 1.5 * k))
            p.closeSubpath()
            return p
        }
        return [ear(-1), ear(1)]
    }

    private static func headPath(_ h: CGPoint, _ r: CGFloat) -> CGPath {
        ellipse(P(h.x, h.y - 0.5 * r / 11.5), r * 1.17, r * 0.93)
    }

    // MARK: drawing

    static func draw(_ ctx: CGContext, look: CatLook, ri: RenderInfo) {
        let g = geo(ri)
        ctx.saveGState()
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        if g.grounded && ri.pose != .climb {
            ctx.setFillColor(NSColor(white: 0, alpha: 0.15).cgColor)
            let w: CGFloat = [.loaf, .sleep, .scratch, .stalk, .run].contains(ri.pose) ? 22 : 17
            ctx.addPath(ellipse(P(0, 0.4), w, 3))
            ctx.fillPath()
        }

        if ri.pose == .climb || ri.pose == .slide {
            if ri.climbSide > 0 { ctx.scaleBy(x: -1, y: 1) }
        } else {
            ctx.scaleBy(x: ri.facing, y: 1)
        }
        if ri.shake != 0 {
            ctx.translateBy(x: CGFloat.random(in: -ri.shake...ri.shake), y: CGFloat.random(in: -ri.shake...ri.shake) * 0.5)
        }
        if ri.rotation != 0 {
            ctx.translateBy(x: 0, y: 16)
            ctx.rotate(by: ri.rotation)
            ctx.translateBy(x: 0, y: -16)
        }
        if let pv = g.pivot {
            ctx.translateBy(x: pv.x, y: pv.y)
            ctx.rotate(by: ri.swing * ri.facing + sin(CGFloat(ri.t) * 2.4) * 0.04)
            ctx.translateBy(x: -pv.x, y: -pv.y)
        }

        let hat = look.hat
        let hidesEars = hatHidesEars(hat)

        // claw streaks on the wall above the paws
        if g.clawTrail > 0.05 {
            ctx.setStrokeColor(NSColor(white: 1, alpha: 0.55 * min(1, g.clawTrail + 0.3)).cgColor)
            ctx.setLineWidth(0.7)
            for (i, x) in [CGFloat(0.8), 2, 3.2].enumerated() {
                let top = 52 + 6 + g.clawTrail * 18 - CGFloat(i)
                ctx.move(to: P(x, 50)); ctx.addLine(to: P(x, top))
            }
            ctx.strokePath()
        }

        if g.wallMarks {
            ctx.setStrokeColor(NSColor(white: 1, alpha: 0.5).cgColor)
            ctx.setLineWidth(0.8)
            for (i, x) in [CGFloat(18.5), 20, 21.5].enumerated() {
                ctx.move(to: P(x, 36 + CGFloat(i))); ctx.addLine(to: P(x, 58 - CGFloat(i)))
            }
            ctx.strokePath()
        }

        // body
        fillGroup(ctx, look, g, g.parts)
        drawOutfit(ctx, look, g, ri)

        // head + ears
        var headParts: [Part] = hidesEars ? [] : earPaths(g.head, g.headR, flat: g.earsFlat).map { Part(kind: .ear, path: $0) }
        headParts.append(Part(kind: .head, path: headPath(g.head, g.headR)))
        fillGroup(ctx, look, g, headParts)

        if g.scratchMarks {
            ctx.setStrokeColor(NSColor(white: 0.45, alpha: 0.6).cgColor)
            ctx.setLineWidth(0.9)
            for i in 0..<3 {
                let x = 30 + CGFloat(i) * 2.2
                ctx.move(to: P(x, 1)); ctx.addLine(to: P(x + 1.5, 6))
            }
            ctx.strokePath()
        }

        if !g.backView { drawFace(ctx, look, g, ri) }
        drawHat(ctx, look, g, ri)
        if !g.overParts.isEmpty { fillGroup(ctx, look, g, g.overParts) }
        ctx.restoreGState()
    }

    private static func fillGroup(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ parts: [Part]) {
        let cos = costumes[look.outfit]
        func covered(_ k: PartKind) -> Bool {
            guard let cos else { return false }
            return k == .torso || k == .haunch || k == .leg || (k == .tail && cos.tail)
        }
        for p in parts {
            ctx.setFillColor(covered(p.kind) ? NSColor(hex: cos!.body).cgColor : look.base)
            ctx.addPath(p.path)
            ctx.fillPath()
        }
        for p in parts {
            ctx.saveGState()
            ctx.addPath(p.path)
            ctx.clip()
            if covered(p.kind) { costumePattern(ctx, cos!, g, p.kind, look.outfit) } else { drawPattern(ctx, look, g, p.kind) }
            ctx.restoreGState()
        }
    }

    private static func drawPattern(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ kind: PartKind) {
        switch look.pattern {
        case .solid: break
        case .tabby: stripes(ctx, look, g, kind)
        case .bicolor: whites(ctx, look, g, kind)
        case .tabbyBicolor: stripes(ctx, look, g, kind); whites(ctx, look, g, kind)
        case .calico: patches(ctx, look, g, kind, colors: [look.accent, NSColor(hex: 0x2B2A2F).cgColor])
        case .tortie: patches(ctx, look, g, kind, colors: [look.accent, NSColor(hex: 0xE09A55).cgColor], dense: true)
        case .colorpoint: points(ctx, look, g, kind)
        }
    }

    private static func stripes(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ kind: PartKind) {
        ctx.setStrokeColor(look.accent)
        let k = g.headR / 11.5
        switch kind {
        case .torso, .haunch:
            let r = g.torsoRect
            ctx.setLineWidth(2.4)
            for i in -3...3 {
                let x = r.midX + CGFloat(i) * 6.5
                ctx.move(to: P(x - 1, r.maxY + 3))
                ctx.addQuadCurve(to: P(x + 1.5, r.minY + r.height * 0.45), control: P(x + 2, r.maxY - r.height * 0.2))
            }
            ctx.strokePath()
        case .head:
            let h = g.head
            ctx.setLineWidth(1.5)
            for (dx, top) in [(CGFloat(-3), CGFloat(9.5)), (0, 11), (3, 9.5)] {
                ctx.move(to: P(h.x + dx * k, h.y + 6 * k)); ctx.addLine(to: P(h.x + dx * 0.8 * k, h.y + top * k))
            }
            ctx.strokePath()
        case .tail:
            ctx.setLineWidth(2.2)
            var i = 3
            while i < g.tail.count - 1 {
                let a = g.tail[i - 1], b = g.tail[i + 1], c = g.tail[i]
                let dx = b.x - a.x, dy = b.y - a.y
                let l = max(0.01, hypot(dx, dy))
                let nx = -dy / l * g.tailW, ny = dx / l * g.tailW
                ctx.move(to: P(c.x - nx, c.y - ny)); ctx.addLine(to: P(c.x + nx, c.y + ny))
                i += 4
            }
            ctx.strokePath()
        case .leg:
            ctx.setLineWidth(1.6)
            for y in [CGFloat(7), 10.5] { ctx.move(to: P(-60, y)); ctx.addLine(to: P(60, y)) }
            ctx.strokePath()
        case .ear: break
        }
    }

    private static func whites(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ kind: PartKind) {
        ctx.setFillColor(look.white)
        let k = g.headR / 11.5
        switch kind {
        case .torso, .haunch:
            if let b = g.belly { ctx.fillEllipse(in: b) }
            if let c = g.chest { ctx.fillEllipse(in: c) }
        case .leg:
            ctx.fill(CGRect(x: -80, y: -20, width: 160, height: g.legLowY + 20))
            if let c = g.chest { ctx.fillEllipse(in: c) }
        case .head:
            if g.backView { return }
            let h = g.head, fx = h.x + 1.4 * k
            ctx.fillEllipse(in: ovalRect(fx, h.y - 4.6 * k, 7 * k, 4.6 * k))
            ctx.addPath(poly([P(fx - 2.6 * k, h.y - 2 * k), P(fx, h.y + 7 * k), P(fx + 2.6 * k, h.y - 2 * k)]))
            ctx.fillPath()
        case .tail, .ear: break
        }
    }

    private static func patches(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ kind: PartKind,
                                colors: [CGColor], dense: Bool = false) {
        var rng = LCG(s: look.seed)
        let k = g.headR / 11.5
        let side: CGFloat = rng.next() > 0.5 ? 1 : -1
        switch kind {
        case .torso, .haunch:
            let r = g.torsoRect
            let n = dense ? 7 : 4
            for i in 0..<n {
                ctx.setFillColor(colors[i % colors.count])
                let c = P(r.minX + r.width * rng.next(), r.minY + r.height * (0.3 + 0.7 * rng.next()))
                let rr = (dense ? 4 : 5.5) + rng.next() * 4
                ctx.fillEllipse(in: ovalRect(c.x, c.y, rr * 1.2, rr))
            }
        case .head, .ear:
            let h = g.head
            ctx.setFillColor(colors[0])
            ctx.fillEllipse(in: ovalRect(h.x + side * 8 * k, h.y + 8 * k, 9 * k, 9 * k))
            ctx.setFillColor(colors[1])
            ctx.fillEllipse(in: ovalRect(h.x - side * 10 * k, h.y + 12 * k, 7 * k, 7 * k))
        case .tail:
            for (i, idx) in [g.tail.count / 3, g.tail.count * 2 / 3, g.tail.count - 1].enumerated() {
                guard idx < g.tail.count else { continue }
                ctx.setFillColor(colors[i % colors.count])
                let p = g.tail[idx]
                ctx.fillEllipse(in: ovalRect(p.x, p.y, 5, 5))
            }
        case .leg:
            if dense {
                ctx.setFillColor(colors[0])
                ctx.fill(CGRect(x: -80, y: 8, width: 160, height: 4))
            }
        }
    }

    private static func points(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ kind: PartKind) {
        let k = g.headR / 11.5
        switch kind {
        case .ear, .tail:
            ctx.setFillColor(look.accent)
            ctx.fill(CGRect(x: -200, y: -200, width: 400, height: 400))
        case .head:
            if g.backView { return }
            let h = g.head, fx = h.x + 1.4 * k
            ctx.setFillColor(look.accent.copy(alpha: 0.35)!)
            ctx.fillEllipse(in: ovalRect(fx, h.y - 2 * k, 9 * k, 7.5 * k))
            ctx.setFillColor(look.accent.copy(alpha: 0.85)!)
            ctx.fillEllipse(in: ovalRect(fx, h.y - 3.2 * k, 6.6 * k, 5.2 * k))
        case .leg:
            ctx.setFillColor(look.accent)
            ctx.fill(CGRect(x: -80, y: -20, width: 160, height: g.legLowY + 22))
        case .torso, .haunch: break
        }
    }

    // MARK: face

    private static func drawFace(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ ri: RenderInfo) {
        let k = g.headR / 11.5
        let h = g.head
        let frontal = ri.pose == .dangle
        let fx = h.x + (frontal ? 0 : 1.4 * k)
        let lk = (ri.pose == .climb || ri.pose == .slide) ? CGPoint(x: 0.5, y: 0.9) : CGPoint(x: ri.look.x * ri.facing, y: ri.look.y)
        let masked = look.hat == "spider"

        // whiskers stick out past the head
        ctx.setStrokeColor(look.whisker)
        ctx.setLineWidth(0.6)
        for s in [CGFloat(-1), 1] {
            for j in [CGFloat(-1), 0, 1] {
                ctx.move(to: P(fx + s * 8 * k, h.y - 2.8 * k + j * 1.1 * k))
                ctx.addLine(to: P(fx + s * 19 * k, h.y - 1.6 * k + j * 2.6 * k))
            }
        }
        ctx.strokePath()
        if masked { return }

        let eyes = [(P(fx - 4.9 * k, h.y + 0.3 * k), look.eyeL, true), (P(fx + 4.9 * k, h.y + 0.3 * k), look.eyeR, false)]
        for (p, color, isLeft) in eyes {
            drawEye(ctx, look, at: p, iris: color, mode: ri.eyes, lookDir: lk, k: k, isLeft: isLeft, frontal: frontal)
        }

        if ri.blush {
            ctx.setFillColor(NSColor(hex: 0xF27C8E, alpha: 0.4).cgColor)
            for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(fx + s * 7.8 * k, h.y - 3.2 * k, 2.2 * k, 1.4 * k)) }
        }

        // tiny dash mouth / open mouth
        if ri.mouthOpen {
            ctx.setFillColor(NSColor(hex: 0x3A1F25).cgColor)
            ctx.fillEllipse(in: ovalRect(fx, h.y - 4.6 * k, 2.1 * k, 1.9 * k))
            ctx.setFillColor(NSColor.white.cgColor)
            for s in [CGFloat(-1), 1] {
                ctx.addPath(poly([P(fx + s * 1.6 * k, h.y - 3.1 * k), P(fx + s * 0.7 * k, h.y - 3.1 * k), P(fx + s * 1.15 * k, h.y - 4.3 * k)]))
                ctx.fillPath()
            }
        } else {
            ctx.setStrokeColor(look.faceLine)
            ctx.setLineWidth(0.95 * k)
            ctx.move(to: P(fx - 0.9 * k, h.y - 3.4 * k)); ctx.addLine(to: P(fx + 0.9 * k, h.y - 3.4 * k))
            ctx.strokePath()
        }
    }

    private static func drawEye(_ ctx: CGContext, _ look: CatLook, at p: CGPoint, iris: CGColor, mode: EyeMode,
                                lookDir: CGPoint, k: CGFloat, isLeft: Bool, frontal: Bool) {
        ctx.setStrokeColor(look.faceLine)
        switch mode {
        case .closed:
            ctx.setLineWidth(1.1 * k)
            ctx.move(to: P(p.x - 2.9 * k, p.y + 0.3 * k))
            ctx.addQuadCurve(to: P(p.x + 2.9 * k, p.y + 0.3 * k), control: P(p.x, p.y - 2.2 * k))
            ctx.strokePath()
        case .happy:
            ctx.setLineWidth(1.1 * k)
            ctx.move(to: P(p.x - 2.9 * k, p.y - 0.9 * k))
            ctx.addQuadCurve(to: P(p.x + 2.9 * k, p.y - 0.9 * k), control: P(p.x, p.y + 2.8 * k))
            ctx.strokePath()
        case .open, .wide, .angry, .sleepy:
            let wide = mode == .wide
            let rx = (wide ? 3.8 : 3.3) * k, ry = (wide ? 4.3 : 3.8) * k
            let white = ovalRect(p.x, p.y, rx, ry)
            ctx.setFillColor(NSColor(hex: 0xFAFAF7).cgColor)
            ctx.fillEllipse(in: white)
            ctx.saveGState()
            ctx.addEllipse(in: white)
            ctx.clip()
            let side = frontal ? 0 : 0.7 * k
            let pc = P(p.x + lookDir.x * 1.1 * k + side, p.y + lookDir.y * 0.9 * k - 0.3 * k)
            if !wide {
                ctx.setFillColor(iris)
                ctx.fillEllipse(in: ovalRect(pc.x, pc.y, 2.3 * k, 2.5 * k))
            }
            let pr = (wide ? 1.4 : 1.7) * k
            ctx.setFillColor(NSColor(hex: 0x111111).cgColor)
            ctx.fillEllipse(in: ovalRect(pc.x, pc.y, pr, pr * 1.08))
            // lids: "meh" flat lid or angry slanted lid, in face colour
            if mode == .sleepy || mode == .angry {
                let s: CGFloat = isLeft ? 1 : -1
                let a = mode == .angry ? P(p.x - s * (rx + 1), p.y + ry * 0.95) : P(p.x - rx - 1, p.y + ry * 0.1)
                let b = mode == .angry ? P(p.x + s * (rx + 1), p.y - ry * 0.15) : P(p.x + rx + 1, p.y + ry * 0.1)
                ctx.setFillColor(look.lid)
                ctx.addPath(poly([a, b, P(b.x, p.y + ry + 2), P(a.x, p.y + ry + 2)]))
                ctx.fillPath()
            }
            ctx.restoreGState()
        }
    }

    // MARK: accessories

    private static func neckPoint(_ g: Geo) -> CGPoint {
        let dx = g.torsoC.x - g.head.x, dy = g.torsoC.y - g.head.y
        let l = max(0.01, hypot(dx, dy))
        return P(g.head.x + dx / l * g.headR * 0.85, g.head.y + dy / l * g.headR * 0.85)
    }

    private static func drawOutfit(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ ri: RenderInfo) {
        let t = CGFloat(ri.t)
        let n = neckPoint(g)
        let r = g.torsoRect
        let k = g.headR / 11.5
        switch look.outfit {
        case "cape":
            let wave = sin(t * 3) * 2
            ctx.setFillColor(NSColor(hex: 0xD32F2F).cgColor)
            let p = CGMutablePath()
            if g.backView {
                p.move(to: P(n.x - 5, n.y + 1))
                p.addLine(to: P(n.x + 5, n.y + 1))
                p.addLine(to: P(r.maxX + 3 + wave * 0.5, r.minY + 1))
                p.addLine(to: P(r.minX - 3 + wave * 0.5, r.minY + 1))
            } else {
                // narrow strip over the shoulders and back, the loose end flutters past the rump
                p.move(to: P(n.x + 1, n.y + 2.5))
                p.addQuadCurve(to: P(r.minX + 2, r.maxY), control: P(r.midX, r.maxY + 2.5))
                p.addLine(to: P(r.minX - 10 + wave * 1.5, r.maxY - 6 + wave))
                p.addLine(to: P(r.minX - 6 + wave, r.maxY - 10 + wave * 0.5))
                p.addLine(to: P(r.minX + 4, r.maxY - 4))
                p.addQuadCurve(to: P(n.x - 1, n.y - 2.5), control: P(r.midX, r.maxY - 2))
            }
            p.closeSubpath()
            ctx.addPath(p)
            ctx.fillPath()
            ctx.setFillColor(NSColor(hex: 0xF5C542).cgColor)
            ctx.fillEllipse(in: ovalRect(n.x, n.y, 1.8, 1.8))

        case "scarf":
            let a = atan2(g.head.y - g.torsoC.y, g.head.x - g.torsoC.x)
            ctx.saveGState()
            ctx.translateBy(x: n.x, y: n.y)
            ctx.rotate(by: a - .pi / 2)
            let band = CGPath(roundedRect: CGRect(x: -9.5 * k, y: -2.4 * k, width: 19 * k, height: 4.8 * k),
                              cornerWidth: 2.2 * k, cornerHeight: 2.2 * k, transform: nil)
            let tailP = CGPath(roundedRect: CGRect(x: 2 * k, y: -11 * k, width: 4.2 * k, height: 10 * k),
                               cornerWidth: 1.5 * k, cornerHeight: 1.5 * k, transform: nil)
            for path in [tailP, band] {
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                ctx.setFillColor(NSColor(hex: 0xE53935).cgColor)
                ctx.fill(CGRect(x: -20, y: -20, width: 40, height: 40))
                ctx.setFillColor(NSColor(hex: 0xFFF3E0).cgColor)
                var x: CGFloat = -12 * k
                while x < 12 * k { ctx.fill(CGRect(x: x, y: -20, width: 1.6 * k, height: 40)); x += 4 * k }
                ctx.restoreGState()
            }
            ctx.restoreGState()

        case "bowtie":
            if g.backView { return }
            let c = P(n.x + 1.5 * k, n.y - 1 * k)
            ctx.setFillColor(NSColor(hex: 0xE53935).cgColor)
            ctx.addPath(poly([c, P(c.x - 4.5 * k, c.y + 2.6 * k), P(c.x - 4.5 * k, c.y - 2.6 * k)]))
            ctx.addPath(poly([c, P(c.x + 4.5 * k, c.y + 2.6 * k), P(c.x + 4.5 * k, c.y - 2.6 * k)]))
            ctx.fillPath()
            ctx.setFillColor(NSColor(hex: 0xB71C1C).cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 1.4 * k, 1.4 * k))

        case "shield":
            let c = r.width >= r.height ? P(r.midX - r.width * 0.12, r.maxY - 2.5) : P(r.minX + 4, r.midY + 3)
            let rings: [(CGFloat, UInt32)] = [(6.5, 0xC62828), (5, 0xF5F5F5), (3.6, 0xC62828), (2.5, 0x1E4FA3)]
            for (rr, col) in rings {
                ctx.setFillColor(NSColor(hex: col).cgColor)
                ctx.fillEllipse(in: ovalRect(c.x, c.y, rr, rr))
            }
            var star: [CGPoint] = []
            for i in 0..<10 {
                let a = CGFloat(i) * .pi / 5 + .pi / 2
                let rr: CGFloat = i % 2 == 0 ? 2.2 : 0.9
                star.append(P(c.x + cos(a) * rr, c.y + sin(a) * rr))
            }
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(poly(star))
            ctx.fillPath()

        case "reactor":
            if g.backView { return }
            let c = g.chest.map { P($0.midX, $0.midY) } ?? P(n.x + 2, n.y - 4)
            let pulse = 1 + 0.12 * sin(t * 4)
            ctx.setFillColor(NSColor(hex: 0x7FE7FF, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 4.6 * pulse, 4.6 * pulse))
            ctx.setFillColor(NSColor(hex: 0x9AA4AE).cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 3.1, 3.1))
            ctx.setFillColor(NSColor(hex: 0x8DF0FF).cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 2.3, 2.3))
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 1, 1))
        default: drawCostumeExtras(ctx, look, g, ri)
        }
    }

    private static func drawHat(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ ri: RenderInfo) {
        let h = g.head
        let k = g.headR / 11.5
        let fx = h.x + (ri.pose == .dangle ? 0 : 1.4 * k)
        switch look.hat {
        case "shark":
            let c = P(h.x, h.y + 1.5 * k)
            let blue = NSColor(hex: 0x5D7C9C).cgColor
            ctx.setFillColor(blue)
            ctx.addPath(poly([P(c.x - 4 * k, c.y + 13 * k), P(c.x + 2 * k, c.y + 23 * k), P(c.x + 6 * k, c.y + 12.5 * k)]))
            for s in [CGFloat(-1), 1] {
                ctx.addPath(poly([P(c.x + s * 14 * k, c.y - 2 * k), P(c.x + s * 22 * k, c.y - 9 * k), P(c.x + s * 12.5 * k, c.y - 9 * k)]))
            }
            ctx.fillPath()
            let outer = ellipse(c, 16 * k, 15.5 * k)
            let opening = ellipse(P(fx, h.y - 0.6 * k), 12 * k, 10.4 * k)
            let hood = CGMutablePath()
            hood.addPath(outer)
            if !g.backView { hood.addPath(opening) }
            ctx.addPath(hood)
            ctx.fillPath(using: .evenOdd)
            if g.backView { return }
            // white rim and teeth
            let rim = CGMutablePath()
            rim.addPath(ellipse(P(fx, h.y - 0.6 * k), 13.8 * k, 12.2 * k))
            rim.addPath(opening)
            ctx.setFillColor(NSColor(hex: 0xF2EEE4).cgColor)
            ctx.addPath(rim)
            ctx.fillPath(using: .evenOdd)
            for i in 0..<7 {
                let a = (152 - CGFloat(i) * 21) * .pi / 180
                let da: CGFloat = 8 * .pi / 180
                let e = { (ang: CGFloat) in P(fx + cos(ang) * 12 * k, h.y - 0.6 * k + sin(ang) * 10.4 * k) }
                let tip = P(fx + cos(a) * 8.6 * k, h.y - 0.6 * k + sin(a) * 7.2 * k)
                ctx.addPath(poly([e(a - da), tip, e(a + da)]))
            }
            ctx.fillPath()
            ctx.setFillColor(NSColor(hex: 0x1B1B1F).cgColor)
            for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(c.x + s * 7 * k, c.y + 10 * k, 1.6 * k, 1.8 * k)) }
            ctx.setFillColor(NSColor.white.cgColor)
            for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(c.x + s * 7 * k + 0.5 * k, c.y + 10.6 * k, 0.5 * k, 0.5 * k)) }

        case "frog":
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 3.2 * k, width: 80, height: 80))
            ctx.setFillColor(NSColor(hex: 0x6DBA4E).cgColor)
            ctx.addPath(ellipse(P(h.x, h.y + 3 * k), 13.5 * k, 11 * k))
            ctx.fillPath()
            ctx.restoreGState()
            for s in [CGFloat(-1), 1] {
                let e = P(h.x + s * 6.5 * k, h.y + 13.5 * k)
                ctx.setFillColor(NSColor(hex: 0x6DBA4E).cgColor)
                ctx.fillEllipse(in: ovalRect(e.x, e.y, 4.6 * k, 4.4 * k))
                if g.backView { continue }
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fillEllipse(in: ovalRect(e.x, e.y + 0.3 * k, 3.4 * k, 3.4 * k))
                ctx.setFillColor(NSColor(hex: 0x1B1B1F).cgColor)
                ctx.fillEllipse(in: ovalRect(e.x + 0.4 * k, e.y + 0.3 * k, 1.7 * k, 1.9 * k))
            }
            if !g.backView {
                ctx.setFillColor(NSColor(hex: 0xF48FB1, alpha: 0.8).cgColor)
                for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(h.x + s * 9.5 * k, h.y + 5.5 * k, 1.8 * k, 1.1 * k)) }
            }

        case "crown":
            let y0 = h.y + 7.5 * k
            let pts = [P(h.x - 6 * k, y0), P(h.x - 6.5 * k, y0 + 6.5 * k), P(h.x - 3 * k, y0 + 3.5 * k), P(h.x, y0 + 8 * k),
                       P(h.x + 3 * k, y0 + 3.5 * k), P(h.x + 6.5 * k, y0 + 6.5 * k), P(h.x + 6 * k, y0)]
            ctx.setFillColor(NSColor(hex: 0xF2C230).cgColor)
            ctx.addPath(poly(pts))
            ctx.fillPath()
            ctx.setFillColor(NSColor(hex: 0xE53935).cgColor)
            ctx.fillEllipse(in: ovalRect(h.x, y0 + 2 * k, 1.3 * k, 1.3 * k))
            ctx.setFillColor(NSColor(hex: 0x42A5F5).cgColor)
            for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(h.x + s * 3.8 * k, y0 + 1.6 * k, 0.9 * k, 0.9 * k)) }

        case "party":
            let base = P(h.x + 1.5 * k, h.y + 8 * k)
            let tip = P(h.x + 5 * k, h.y + 23 * k)
            let cone = poly([P(base.x - 5 * k, base.y), tip, P(base.x + 5 * k, base.y)])
            ctx.saveGState()
            ctx.addPath(cone)
            ctx.clip()
            ctx.setFillColor(NSColor(hex: 0xF06292).cgColor)
            ctx.fill(CGRect(x: h.x - 30, y: h.y - 30, width: 60, height: 80))
            ctx.setFillColor(NSColor(hex: 0xFFEB3B).cgColor)
            for i in 0..<4 {
                let y = base.y + CGFloat(i) * 4 * k + 1.5 * k
                ctx.fill(CGRect(x: h.x - 30, y: y, width: 60, height: 1.5 * k))
            }
            ctx.restoreGState()
            ctx.setFillColor(NSColor(hex: 0x4FC3F7).cgColor)
            ctx.fillEllipse(in: ovalRect(tip.x, tip.y, 2.2 * k, 2.2 * k))

        case "bow":
            let c = P(h.x + 7 * k, h.y + 8.5 * k)
            ctx.setFillColor(NSColor(hex: 0xFF6FA5).cgColor)
            ctx.addPath(poly([c, P(c.x - 4.5 * k, c.y + 3.2 * k), P(c.x - 4 * k, c.y - 2.8 * k)]))
            ctx.addPath(poly([c, P(c.x + 4.5 * k, c.y + 3.2 * k), P(c.x + 4 * k, c.y - 2.8 * k)]))
            ctx.fillPath()
            ctx.setFillColor(NSColor(hex: 0xE04887).cgColor)
            ctx.fillEllipse(in: ovalRect(c.x, c.y, 1.5 * k, 1.5 * k))

        case "spider":
            let red = NSColor(hex: 0xD7262F).cgColor
            // fill head and each ear on its own: overlapping shapes in one path would leave a hole
            let shapes = [headPath(h, g.headR)] + earPaths(h, g.headR, flat: g.earsFlat)
            ctx.setFillColor(red)
            for sh in shapes { ctx.addPath(sh); ctx.fillPath() }
            // web: spokes from a small hub + polygon rings between the spokes (no dark blob in the middle)
            ctx.saveGState()
            ctx.addPath(headPath(h, g.headR))
            ctx.clip()
            ctx.setStrokeColor(NSColor(hex: 0x5C0A12).cgColor)
            ctx.setLineWidth(max(0.55, 0.62 * k))
            let c = P(fx, h.y - 1.2 * k)
            let spokes = 8
            let step: CGFloat = 2 * CGFloat.pi / CGFloat(spokes)
            let ang: [CGFloat] = (0..<spokes).map { (i: Int) -> CGFloat in CGFloat(i) * step + CGFloat.pi / 8 }
            for a in ang {
                ctx.move(to: P(c.x + cos(a) * 1.8 * k, c.y + sin(a) * 1.8 * k))
                ctx.addLine(to: P(c.x + cos(a) * 26 * k, c.y + sin(a) * 26 * k))
            }
            for rr in [4.6, 9.0, 13.5, 18.5] as [CGFloat] {
                for i in 0..<spokes {
                    let a0 = ang[i], a1 = ang[(i + 1) % spokes]
                    let p0 = P(c.x + cos(a0) * rr * k, c.y + sin(a0) * rr * k)
                    let p1 = P(c.x + cos(a1) * rr * k, c.y + sin(a1) * rr * k)
                    let wrap: CGFloat = i == spokes - 1 ? CGFloat.pi : 0
                    let am: CGFloat = (a0 + a1) / 2 + wrap
                    let sag = P(c.x + cos(am) * rr * 0.86 * k, c.y + sin(am) * rr * 0.86 * k)
                    ctx.move(to: p0); ctx.addQuadCurve(to: p1, control: sag)
                }
            }
            ctx.strokePath()
            ctx.restoreGState()
            if g.backView { return }
            // big almond lenses with a bold black rim
            for s in [CGFloat(-1), 1] {
                let e = P(fx + s * 4.8 * k, h.y + 0.8 * k)
                let inner = P(e.x - s * 2.6 * k, e.y - 2.3 * k)
                let outer = P(e.x + s * 3.9 * k, e.y + 2.9 * k)
                let lens = CGMutablePath()
                lens.move(to: inner)
                lens.addQuadCurve(to: outer, control: P(e.x + s * 3.6 * k, e.y - 2.6 * k))
                lens.addQuadCurve(to: inner, control: P(e.x - s * 3.4 * k, e.y + 3.2 * k))
                lens.closeSubpath()
                ctx.setStrokeColor(NSColor(hex: 0x111111).cgColor)
                ctx.setLineWidth(1.5 * k)
                ctx.addPath(lens)
                ctx.strokePath()
                ctx.setFillColor(NSColor(hex: 0xFAFAF7).cgColor)
                ctx.addPath(lens)
                ctx.fillPath()
            }
        case "horns":
            let gold = NSColor(hex: 0xE3B23C).cgColor
            ctx.setStrokeColor(gold)
            ctx.setLineCap(.round)
            for s in [CGFloat(-1), 1] {
                let p = CGMutablePath()
                p.move(to: P(h.x + s * 6.5 * k, h.y + 8 * k))
                p.addCurve(to: P(h.x + s * 8 * k, h.y + 29 * k),
                           control1: P(h.x + s * 15 * k, h.y + 12 * k), control2: P(h.x + s * 15 * k, h.y + 26 * k))
                ctx.setLineWidth(3.4 * k)
                ctx.addPath(p)
                ctx.strokePath()
            }
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 3.5 * k, width: 80, height: 80))
            ctx.setFillColor(gold)
            ctx.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k))
            ctx.fillPath()
            ctx.restoreGState()
            if !g.backView {
                ctx.setFillColor(NSColor(hex: 0x2E7D32).cgColor)
                ctx.addPath(poly([P(fx - 2 * k, h.y + 4 * k), P(fx, h.y + 11 * k), P(fx + 2 * k, h.y + 4 * k)]))
                ctx.fillPath()
            }

        case "winged":
            ctx.setFillColor(NSColor.white.cgColor)
            for s in [CGFloat(-1), 1] {
                for (i, len) in [CGFloat(11), 9, 7].enumerated() {
                    let base = P(h.x + s * 11 * k, h.y + (6 + CGFloat(i) * 2) * k)
                    let a = (40 + CGFloat(i) * 18) * .pi / 180
                    let tip = P(base.x + s * cos(a) * len * k, base.y + sin(a) * len * k)
                    ctx.addPath(stroked([base, tip], 2.6 * k))
                }
            }
            ctx.fillPath()
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 3.5 * k, width: 80, height: 80))
            ctx.setFillColor(NSColor(hex: 0xC9CED6).cgColor)
            ctx.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.setFillColor(NSColor(hex: 0x9AA2AD).cgColor)
            ctx.fill(CGRect(x: h.x - 12.6 * k, y: h.y + 3.5 * k, width: 25.2 * k, height: 1.8 * k))
        default: drawHood(ctx, look, g, ri, fx: fx, k: k)
        }
    }

    // MARK: preview image for the menu

    static func image(_ cfg: CatConfig, size: CGFloat, pose: Pose = .sit) -> NSImage {
        let look = CatLook(cfg)
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = size / 64
            ctx.translateBy(x: size / 2, y: 6 * s)
            ctx.scaleBy(x: s, y: s)
            var ri = RenderInfo()
            ri.pose = pose
            ri.t = 0.6
            draw(ctx, look: look, ri: ri)
            return true
        }
    }
}
