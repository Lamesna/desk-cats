import AppKit

// Hood hats and onesie costumes in the spirit of the reference sheets.
// Character-like items are generic look-alikes: no letters, logos or names.

private func C(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor { NSColor(hex: hex, alpha: a).cgColor }

// MARK: - Costumes (recolour the body, then add details)

struct Costume {
    let name: String
    let body: UInt32
    var belly: UInt32? = nil
    var paws: UInt32? = nil
    var legs: UInt32? = nil
    var tail = false            // the costume covers the tail too
    var stripes: UInt32? = nil
    var spots: [UInt32]? = nil  // seeded dots (leopard, polka dots)
}

let costumes: [String: Costume] = [
    "c_chick":   Costume(name: "Chick", body: 0xF6D44A, paws: 0xF0A12F),
    "c_shark":   Costume(name: "Shark", body: 0x5D7C9C, belly: 0xF2EEE6, paws: 0xF2EEE6, tail: true),
    "c_vampire": Costume(name: "Vampire", body: 0x2A2730, paws: 0x1C1A20),
    "c_dino":    Costume(name: "Dinosaur", body: 0x79A85A, belly: 0xF1E3A0, paws: 0xF1E3A0, tail: true),
    "c_bunny":   Costume(name: "Bunny", body: 0xF7F4F0, paws: 0xFFFFFF, tail: true),
    "c_panda":   Costume(name: "Panda", body: 0xF4F2EE, legs: 0x2A2A2E),
    "c_plumber": Costume(name: "Overalls", body: 0xD9302C, paws: 0xF4F2EE, legs: 0x2F5DAE),
    "c_kitty":   Costume(name: "Bow jumpsuit", body: 0xF7F5F2, paws: 0xF7F5F2, legs: 0xD7262F),
    "c_bee":     Costume(name: "Bee", body: 0xF4C430, stripes: 0x4A3423),
    "c_wizard":  Costume(name: "Wizard", body: 0x2C2F55, legs: 0x2C2F55),
    "c_frog":    Costume(name: "Froggy", body: 0x79A85A, belly: 0xF1EBC4, paws: 0x79A85A),
    "c_cowboy":  Costume(name: "Cowboy", body: 0x8B5A2B, belly: 0xF1E7D2, legs: 0xF4F2EE),
    "c_penguin": Costume(name: "Penguin", body: 0x2D3756, belly: 0xF4F2EE, paws: 0xF4F2EE),
    "c_pinkdino": Costume(name: "Pink dino", body: 0xF2A9C4, belly: 0xFBE3EC, paws: 0xFBE3EC, tail: true),
    "c_bear":    Costume(name: "Teddy bear", body: 0xA7703F, belly: 0xE8C9A0, paws: 0x7B4F2A),
    "c_ghost":   Costume(name: "Ghost", body: 0xF6F4EE, tail: true),
    "c_banana":  Costume(name: "Banana", body: 0xF6D84B, paws: 0x6B4A2B),
    "c_merc":    Costume(name: "Mercenary", body: 0xC62828, legs: 0x2A2A2E),
    "c_spider":  Costume(name: "Spider", body: 0xD7262F, paws: 0xD7262F, legs: 0x1E4FA3),
    "c_royal":   Costume(name: "Royal robe", body: 0xB71C1C, paws: 0xF4F2EE),
    "c_party":   Costume(name: "Party", body: 0xF48FB1, paws: 0xFFFFFF, spots: [0xFFEB3B, 0x4FC3F7, 0x81C784]),
    "c_trickster": Costume(name: "Trickster", body: 0x2E7D32, belly: 0xE3B23C, legs: 0x1B1B1F),
    "c_jester":  Costume(name: "Jester", body: 0x2E2A33, belly: 0xF2EEE8, paws: 0xF4A7C0),
    "c_monster": Costume(name: "Monster", body: 0x9B7FD1, belly: 0xD9CCF2, paws: 0x7E62B8, tail: true),
    "c_unicorn": Costume(name: "Unicorn", body: 0xF7F3EE, paws: 0xF2C230, tail: true),
]
let costumeOrder = ["c_chick", "c_shark", "c_vampire", "c_dino", "c_bunny", "c_panda", "c_plumber", "c_kitty",
                    "c_bee", "c_wizard", "c_frog", "c_cowboy", "c_penguin", "c_pinkdino",
                    "c_bear", "c_ghost", "c_banana", "c_merc", "c_spider", "c_royal", "c_party", "c_trickster",
                    "c_jester", "c_monster", "c_unicorn"]

let hoodHats: [(id: String, name: String)] = [
    ("chick", "Chick"), ("jester", "Black jester"), ("banana", "Banana"), ("dino", "Dinosaur"),
    ("panda", "Panda"), ("bunny", "Bunny"), ("cap", "Red cap"), ("bee", "Bee"), ("cowboy", "Cowboy"),
    ("bear", "Teddy bear"), ("penguin", "Penguin"), ("merc", "Mercenary mask"), ("witch", "Witch"),
    ("monster", "Monster"), ("ghost", "Ghost"), ("unicorn", "Unicorn"), ("pinkdino", "Pink dino"),
    ("vampire", "Vampire"), ("santa", "Santa"), ("tophat", "Top hat"), ("starhelm", "Star helmet"),
    ("ironhelm", "Iron helmet"),
]

func hatHidesEars(_ id: String) -> Bool {
    !["none", "crown", "party", "bow", "spider", "merc", "tophat"].contains(id)
}

extension CatRenderer {

    static func costumePattern(_ ctx: CGContext, _ cos: Costume, _ g: Geo, _ kind: PartKind, _ id: String) {
        let r = g.torsoRect
        if id == "c_unicorn" && kind == .tail {
            let cols: [UInt32] = [0xF48FB1, 0xFFE082, 0x81D4FA, 0xB39DDB]
            for (i, p) in g.tail.enumerated() where i > g.tail.count / 3 {
                ctx.setFillColor(C(cols[(i / 2) % cols.count]))
                ctx.fillEllipse(in: ovalRect(p.x, p.y, 3.4, 3.4))
            }
        }
        if let st = cos.stripes, kind != .leg {
            ctx.setStrokeColor(C(st))
            ctx.setLineWidth(id == "c_bee" ? 4 : 2.6)
            let step: CGFloat = id == "c_bee" ? 8 : 6
            var x = r.minX - 20
            while x < r.maxX + 20 {
                ctx.move(to: P(x, r.minY - 30)); ctx.addLine(to: P(x + 3, r.maxY + 30))
                x += step
            }
            if kind == .tail {
                for p in g.tail.enumerated() where p.offset % 5 == 3 {
                    ctx.move(to: P(p.element.x - 6, p.element.y)); ctx.addLine(to: P(p.element.x + 6, p.element.y))
                }
            }
            ctx.strokePath()
        }
        switch id {
        case "c_plumber", "c_kitty":
            // overalls: lower half of the torso in the overall colour
            if kind == .torso || kind == .haunch, let l = cos.legs {
                ctx.setFillColor(C(l))
                ctx.fill(r.width >= r.height ? CGRect(x: r.minX - 5, y: r.minY - 5, width: r.width + 10, height: r.height * 0.55 + 5)
                                             : CGRect(x: r.minX - 5, y: r.minY - 5, width: r.width + 10, height: r.height * 0.6 + 5))
            }
        case "c_cowboy":
            if kind == .leg {
                ctx.setFillColor(C(0x2B2A2F))
                for (x, y) in [(-12.0, 9.0), (-7.0, 5.0), (9.0, 8.0), (14.0, 4.0), (4.0, 3.0)] as [(CGFloat, CGFloat)] {
                    ctx.fillEllipse(in: ovalRect(x, y, 2.4, 1.8))
                }
            }
        case "c_spider":
            if kind == .torso || kind == .haunch {
                // web lines on the red, blue sides below
                let c = g.chest.map { P($0.midX, $0.midY) } ?? P(r.midX, r.midY)
                ctx.setStrokeColor(C(0x5C0A12))
                ctx.setLineWidth(0.5)
                for i in 0..<8 {
                    let a = CGFloat(i) * .pi / 4
                    ctx.move(to: c); ctx.addLine(to: P(c.x + Darwin.cos(a) * 40, c.y + Darwin.sin(a) * 40))
                }
                for rr in [5.0, 10.0, 15.0, 20.0] as [CGFloat] { ctx.addEllipse(in: ovalRect(c.x, c.y, rr, rr * 0.85)) }
                ctx.strokePath()
                ctx.setFillColor(C(0x1E4FA3))
                ctx.fill(r.width >= r.height ? CGRect(x: r.minX - 5, y: r.minY - 5, width: r.width + 10, height: r.height * 0.32 + 5)
                                             : CGRect(x: r.minX - 5, y: r.minY - 5, width: r.width * 0.3 + 5, height: r.height + 10))
            }
        case "c_merc":
            if kind == .torso || kind == .haunch {
                ctx.setFillColor(C(0x2A2A2E))
                ctx.fill(CGRect(x: r.minX - 5, y: r.minY - 5, width: r.width + 10, height: r.height * 0.35 + 5))
            }
        case "c_wizard":
            if kind == .torso || kind == .haunch || kind == .leg {
                ctx.setFillColor(C(0xF5C542))
                var rng: UInt32 = 7
                for _ in 0..<5 {
                    rng = rng &* 1664525 &+ 1013904223
                    let fx = CGFloat(rng >> 8 & 0xFF) / 255, fy = CGFloat(rng >> 16 & 0xFF) / 255
                    ctx.addPath(star(P(r.minX + r.width * fx, r.minY + r.height * fy), 1.8))
                }
                ctx.fillPath()
            }
        default: break
        }
        if let sp = cos.spots {
            var rng = UInt32(truncatingIfNeeded: id.hashValue & 0xFFFF) | 1
            let area = kind == .tail ? CGRect(x: -60, y: -40, width: 120, height: 120) : r.insetBy(dx: -4, dy: -4)
            for i in 0..<(kind == .tail ? 24 : 14) {
                rng = rng &* 1664525 &+ 1013904223
                let fx = CGFloat(rng >> 8 & 0xFF) / 255, fy = CGFloat(rng >> 16 & 0xFF) / 255
                ctx.setFillColor(C(sp[i % sp.count]))
                let pt = kind == .leg ? P(-20 + 45 * fx, 1 + 14 * fy) : P(area.minX + area.width * fx, area.minY + area.height * fy)
                ctx.fillEllipse(in: ovalRect(pt.x, pt.y, 1.6, 1.3))
            }
        }
        if let b = cos.belly, kind != .tail {
            ctx.setFillColor(C(b))
            if let x = g.belly { ctx.fillEllipse(in: x) }
            if let x = g.chest { ctx.fillEllipse(in: x) }
        }
        if kind == .leg {
            if let l = cos.legs { ctx.setFillColor(C(l)); ctx.fill(CGRect(x: -80, y: -40, width: 160, height: 200)) }
            if id == "c_cowboy" {
                ctx.setFillColor(C(0x2B2A2F))
                for (x, y) in [(-12.0, 9.0), (-7.0, 5.0), (9.0, 8.0), (14.0, 4.0), (4.0, 3.0)] as [(CGFloat, CGFloat)] {
                    ctx.fillEllipse(in: ovalRect(x, y, 2.4, 1.8))
                }
            }
            if let p = cos.paws { ctx.setFillColor(C(p)); ctx.fill(CGRect(x: -80, y: -20, width: 160, height: g.legLowY + 20)) }
        }
    }

    static func star(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        var pts: [CGPoint] = []
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 + .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.42
            pts.append(P(c.x + cos(a) * rr, c.y + sin(a) * rr))
        }
        return poly(pts)
    }

    static func neck(_ g: Geo) -> CGPoint {
        let dx = g.torsoC.x - g.head.x, dy = g.torsoC.y - g.head.y
        let l = max(0.01, hypot(dx, dy))
        return P(g.head.x + dx / l * g.headR * 0.85, g.head.y + dy / l * g.headR * 0.85)
    }

    /// Points along the back of the torso with outward normals (for spikes, fins, wings).
    static func backLine(_ g: Geo, count: Int) -> [(CGPoint, CGPoint)] {
        let r = g.torsoRect
        let horizontal = r.width >= r.height
        let (a0, a1): (CGFloat, CGFloat) = horizontal ? (150, 35) : (205, 105)
        return (0..<count).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(max(1, count - 1))) * .pi / 180
            let p = P(r.midX + cos(a) * r.width / 2, r.midY + sin(a) * r.height / 2)
            return (p, P(cos(a), sin(a)))
        }
    }

    /// Spikes along the back, all parallel: they point the same way (up, leaning toward the tail).
    static func backSpikes(_ ctx: CGContext, _ g: Geo, count: Int, color: UInt32, length: CGFloat, width: CGFloat) {
        let pts = backLine(g, count: count)
        var ax: CGFloat = 0, ay: CGFloat = 0
        for (_, n) in pts { ax += n.x; ay += n.y }
        ax -= 0.45 * CGFloat(pts.count)                  // lean toward the tail (-x)
        let l = max(0.01, hypot(ax, ay))
        let dir = P(ax / l, ay / l)
        let side = P(dir.y, -dir.x)
        ctx.setFillColor(C(color))
        for (p, _) in pts {
            ctx.addPath(poly([P(p.x - side.x * width, p.y - side.y * width), P(p.x + dir.x * length, p.y + dir.y * length),
                              P(p.x + side.x * width, p.y + side.y * width)]))
        }
        ctx.fillPath()
    }

    static func bow(_ ctx: CGContext, _ c: CGPoint, _ s: CGFloat, _ color: UInt32) {
        ctx.setFillColor(C(color))
        ctx.addPath(poly([c, P(c.x - 4.5 * s, c.y + 2.8 * s), P(c.x - 4.5 * s, c.y - 2.8 * s)]))
        ctx.addPath(poly([c, P(c.x + 4.5 * s, c.y + 2.8 * s), P(c.x + 4.5 * s, c.y - 2.8 * s)]))
        ctx.fillPath()
        ctx.setFillColor(NSColor(hex: color).darker(0.75).cgColor)
        ctx.fillEllipse(in: ovalRect(c.x, c.y, 1.4 * s, 1.4 * s))
    }

    /// Forked tail fin set across the direction of the last tail segment.
    static func tailFin(_ ctx: CGContext, _ g: Geo, _ color: UInt32) {
        guard g.tail.count > 3, let tip = g.tail.last else { return }
        let prev = g.tail[g.tail.count - 3]
        let l = max(0.01, hypot(tip.x - prev.x, tip.y - prev.y))
        let d = P((tip.x - prev.x) / l, (tip.y - prev.y) / l)
        let n = P(-d.y, d.x)
        func at(_ a: CGFloat, _ b: CGFloat) -> CGPoint { P(tip.x + d.x * a + n.x * b, tip.y + d.y * a + n.y * b) }
        ctx.setFillColor(C(color))
        ctx.addPath(poly([at(-2.5, 2.6), at(4.5, 7.5), at(2.2, 0), at(4.5, -7.5), at(-2.5, -2.6)]))
        ctx.fillPath()
    }

    static func ermine(_ ctx: CGContext, _ n: CGPoint, _ k: CGFloat) {
        ctx.setFillColor(C(0xF4F2EE))
        ctx.addPath(ellipse(n, 8 * k, 3.2 * k)); ctx.fillPath()
        ctx.setFillColor(C(0x1B1B1F))
        for dx in [-5.0, -1.5, 2.0, 5.5] as [CGFloat] { ctx.fillEllipse(in: ovalRect(n.x + dx * k, n.y, 0.6 * k, 0.9 * k)) }
    }

    /// Zig-zag ruffle collar around the neck.
    static func ruff(_ ctx: CGContext, _ n: CGPoint, _ k: CGFloat, _ color: UInt32, pom: UInt32) {
        var pts: [CGPoint] = []
        for i in 0..<16 {
            let a = CGFloat(i) * .pi / 8
            let r: CGFloat = (i % 2 == 0 ? 7.5 : 4.5) * k
            pts.append(P(n.x + cos(a) * r, n.y + sin(a) * r * 0.55))
        }
        ctx.setFillColor(C(color)); ctx.addPath(poly(pts)); ctx.fillPath()
        ctx.setFillColor(C(pom))
        for i in stride(from: 0, to: 16, by: 4) { ctx.fillEllipse(in: ovalRect(pts[i].x, pts[i].y, 1 * k, 1 * k)) }
    }

    static func cloak(_ ctx: CGContext, _ g: Geo, _ t: CGFloat, outer: UInt32, inner: UInt32) {
        let n = neck(g), r = g.torsoRect
        let wave = sin(t * 3) * 2
        let p = CGMutablePath()
        p.move(to: P(n.x + 1, n.y + 3))
        p.addQuadCurve(to: P(r.minX - 4 + wave, r.maxY + 2), control: P(r.midX, r.maxY + 4))
        p.addLine(to: P(r.minX - 11 + wave * 1.5, r.minY + 2))
        p.addLine(to: P(r.minX + 2, r.minY + 4))
        p.addQuadCurve(to: P(n.x - 1, n.y - 3), control: P(r.midX - 2, r.midY))
        p.closeSubpath()
        ctx.setFillColor(C(inner))
        ctx.addPath(p)
        ctx.fillPath()
        ctx.saveGState()
        ctx.translateBy(x: 1.5, y: 1.2)
        ctx.setFillColor(C(outer))
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()
    }

    static func drawCostumeExtras(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ ri: RenderInfo) {
        let t = CGFloat(ri.t)
        let n = neck(g), r = g.torsoRect
        let k = g.headR / 11.5
        let front = P(n.x + 1.5 * k, n.y - 1 * k)
        switch look.outfit {
        case "c_chick":
            if !g.backView { bow(ctx, front, k, 0xF0A12F) }
        case "c_shark":
            if let (p, nrm) = backLine(g, count: 5).dropFirst(2).first {
                ctx.setFillColor(C(0x5D7C9C))
                ctx.addPath(poly([P(p.x - 4, p.y - 1), P(p.x + nrm.x * 9 - 3, p.y + nrm.y * 9), P(p.x + 4, p.y)]))
                ctx.fillPath()
            }
            tailFin(ctx, g, 0x5D7C9C)
        case "c_vampire":
            cloak(ctx, g, t, outer: 0x1E1C22, inner: 0xB3202A)
            if !g.backView {
                bow(ctx, front, k, 0xD7262F)
                ctx.setFillColor(C(0x8C8C94))
                for i in 0..<2 { ctx.fillEllipse(in: ovalRect(front.x + 1, front.y - 4 - CGFloat(i) * 3.5, 0.9, 0.9)) }
            }
        case "c_dino", "c_pinkdino":
            backSpikes(ctx, g, count: 6, color: look.outfit == "c_dino" ? 0xF2C230 : 0xE04A6A, length: 5.5, width: 2.8)
        case "c_bunny":
            if !g.backView { bow(ctx, front, k * 0.85, 0xF48FB1) }
            if let b = g.tail.first {
                ctx.setFillColor(C(0xFFFFFF))
                ctx.fillEllipse(in: ovalRect(b.x - 1, b.y, 4.5, 4.5))
            }
        case "c_panda":
            if !g.backView { bow(ctx, front, k * 0.85, 0x4C9A3F) }
        case "c_plumber", "c_kitty":
            if g.backView { break }
            let horizontal = r.width >= r.height
            let topY = horizontal ? r.minY + r.height * 0.55 : r.minY + r.height * 0.6
            ctx.setStrokeColor(C(look.outfit == "c_plumber" ? 0x2F5DAE : 0xD7262F))
            ctx.setLineWidth(1.6)
            ctx.move(to: P(front.x - 2, topY)); ctx.addLine(to: P(n.x - 1, n.y))
            ctx.move(to: P(front.x + 3, topY)); ctx.addLine(to: P(n.x + 3, n.y))
            ctx.strokePath()
            if look.outfit == "c_plumber" {
                ctx.setFillColor(C(0xF5C542))
                ctx.fillEllipse(in: ovalRect(front.x - 2, topY, 1.2, 1.2))
                ctx.fillEllipse(in: ovalRect(front.x + 3, topY, 1.2, 1.2))
            } else {
                // little white cat face on the bib and a big red bow
                let c = P(front.x, topY - 3)
                ctx.setFillColor(C(0xFFFFFF))
                ctx.fillEllipse(in: ovalRect(c.x, c.y, 2.6, 2.1))
                ctx.addPath(poly([P(c.x - 2.4, c.y + 0.8), P(c.x - 1.8, c.y + 3), P(c.x - 0.6, c.y + 1.6)]))
                ctx.addPath(poly([P(c.x + 2.4, c.y + 0.8), P(c.x + 1.8, c.y + 3), P(c.x + 0.6, c.y + 1.6)]))
                ctx.fillPath()
                bow(ctx, P(n.x - 3 * k, n.y + 2 * k), k, 0xD7262F)
            }
        case "c_spider":
            break
        case "c_royal":
            cloak(ctx, g, t, outer: 0xB71C1C, inner: 0xF4F2EE)
            ermine(ctx, n, k)
        case "c_party":
            ruff(ctx, n, k, 0xFFFFFF, pom: 0xFFEB3B)
        case "c_trickster":
            cloak(ctx, g, t, outer: 0x2E7D32, inner: 0xE3B23C)
            ctx.setFillColor(C(0xE3B23C)); ctx.fillEllipse(in: ovalRect(n.x, n.y, 1.8, 1.8))
        case "c_jester":
            ruff(ctx, n, k, 0xF2EEE8, pom: 0xF4A7C0)
            if !g.backView {
                ctx.setFillColor(C(0xF4A7C0))
                for i in 0..<2 { ctx.fillEllipse(in: ovalRect(front.x, front.y - 4.5 - CGFloat(i) * 3.5, 1.1, 1.1)) }
            }
        case "c_monster":
            backSpikes(ctx, g, count: 5, color: 0x7E62B8, length: 4.5, width: 2.2)
        case "c_unicorn":
            // rainbow mane along the back
            let cols: [UInt32] = [0xF48FB1, 0xFFE082, 0x81D4FA, 0xB39DDB, 0xF48FB1]
            for (i, (p, nrm)) in backLine(g, count: 5).enumerated() {
                ctx.setFillColor(C(cols[i]))
                ctx.fillEllipse(in: ovalRect(p.x + nrm.x * 1.5, p.y + nrm.y * 1.5, 3, 3))
            }
        case "c_bee":
            let pts = backLine(g, count: 5)
            let p = pts[1].0
            ctx.setFillColor(C(0xCFE8F7, 0.75))
            ctx.fillEllipse(in: ovalRect(p.x - 3, p.y + 5, 5, 7))
            ctx.fillEllipse(in: ovalRect(p.x + 3, p.y + 5, 4, 6))
            if !g.backView { bow(ctx, front, k * 0.8, 0x4A3423) }
        case "c_wizard":
            cloak(ctx, g, t, outer: 0x2C2F55, inner: 0x6B3FA0)
            ctx.setFillColor(C(0xF5C542))
            ctx.fillEllipse(in: ovalRect(n.x, n.y, 1.8, 1.8))
        case "c_frog":
            if !g.backView { bow(ctx, front, k * 0.85, 0x3E8E41) }
        case "c_cowboy":
            if !g.backView {
                ctx.setFillColor(C(0xC62828))
                ctx.addPath(poly([P(n.x - 4 * k, n.y + 1), P(n.x + 4.5 * k, n.y + 1), P(front.x + 1, n.y - 6 * k)]))
                ctx.fillPath()
                ctx.setFillColor(C(0xF5C542))
                ctx.addPath(star(P(front.x - 2, n.y - 9 * k), 2.2))
                ctx.fillPath()
            }
            // belt with a plain buckle
            ctx.saveGState()
            if let tp = g.parts.first(where: { $0.kind == .torso }) { ctx.addPath(tp.path); ctx.clip() }
            ctx.setFillColor(C(0x3B2A1A))
            let horizontal = r.width >= r.height
            let belt = horizontal ? CGRect(x: r.minX + r.width * 0.25, y: r.minY - 2, width: 3.5, height: r.height + 4)
                                  : CGRect(x: r.minX - 2, y: r.minY + r.height * 0.3, width: r.width + 4, height: 3.5)
            ctx.fill(belt)
            ctx.restoreGState()
            ctx.setFillColor(C(0xD9A93A))
            ctx.fill(CGRect(x: belt.midX - 1.6, y: (horizontal ? r.minY + 3 : belt.midY) - 1.6, width: 3.2, height: 3.2))
        case "c_penguin":
            if !g.backView { bow(ctx, front, k * 0.85, 0xD7262F) }
        case "c_bear":
            if !g.backView { bow(ctx, front, k * 0.85, 0x6B4423) }
        case "c_ghost":
            // a sheet over the whole body with a wavy hem and two holes
            let top = n.y + 2
            let bottomY = g.grounded ? 0.5 : r.minY - 4
            let p = CGMutablePath()
            p.move(to: P(r.minX - 4, bottomY))
            p.addLine(to: P(r.minX - 3, r.midY))
            p.addQuadCurve(to: P(r.maxX + 3, r.midY), control: P(r.midX, top + 14))
            p.addLine(to: P(r.maxX + 4, bottomY))
            let w = (r.width + 8) / 5
            for i in 0..<5 {
                let x0 = r.maxX + 4 - CGFloat(i) * w
                p.addQuadCurve(to: P(x0 - w, bottomY), control: P(x0 - w / 2, bottomY + 3 + sin(t * 4 + CGFloat(i)) * 1.5))
            }
            p.closeSubpath()
            ctx.setFillColor(C(0xF6F4EE))
            ctx.addPath(p)
            ctx.fillPath()
            if !g.backView {
                ctx.setFillColor(C(0x2B2A2F))
                ctx.fillEllipse(in: ovalRect(r.midX + 2, r.midY + 2, 1.6, 2.2))
                ctx.fillEllipse(in: ovalRect(r.midX + 7, r.midY + 2, 1.6, 2.2))
            }
        case "c_banana":
            // peel flaps hanging from the neck
            for (dx, ang) in [(-1.0, 200.0), (1.0, 300.0), (0.0, 250.0)] as [(CGFloat, CGFloat)] {
                let a = ang * .pi / 180
                let base = P(n.x + dx * 3, n.y)
                let tip = P(base.x + cos(a) * 14, base.y + sin(a) * 14)
                ctx.setFillColor(C(0xF6D84B))
                ctx.addPath(stroked([base, tip], 5.5))
                ctx.fillPath()
                ctx.setFillColor(C(0xFFF3B8))
                ctx.addPath(stroked([P(lerp(base.x, tip.x, 0.3), lerp(base.y, tip.y, 0.3)), tip], 2.4))
                ctx.fillPath()
            }
        case "c_merc":
            ctx.saveGState()
            if let tp = g.parts.first(where: { $0.kind == .torso }) { ctx.addPath(tp.path); ctx.clip() }
            ctx.setStrokeColor(C(0x6B4423))
            ctx.setLineWidth(2.2)
            ctx.move(to: P(r.minX, r.minY)); ctx.addLine(to: P(r.maxX, r.maxY))
            ctx.move(to: P(r.minX, r.maxY)); ctx.addLine(to: P(r.maxX, r.minY))
            ctx.strokePath()
            ctx.restoreGState()
            if !g.backView {
                ctx.setFillColor(C(0x2A2A2E))
                ctx.fillEllipse(in: ovalRect(r.midX, r.midY, 2.6, 2.6))
                ctx.setFillColor(C(0xC62828))
                ctx.fillEllipse(in: ovalRect(r.midX, r.midY, 1.6, 1.6))
            }
        default: break
        }
    }

    // MARK: - Hood hats

    /// A hood around the face; `behind` draws ears/antennae first, `top` draws the face printed on the hood.
    private static func hood(_ ctx: CGContext, _ g: Geo, fx: CGFloat, k: CGFloat, color: UInt32, rim: UInt32? = nil,
                             tall: CGFloat = 0, behind: () -> Void = {}, top: () -> Void = {}) {
        let h = g.head
        behind()
        let c = P(h.x, h.y + 1.5 * k + tall * 0.5)
        let outer = ellipse(c, 15.5 * k, (15 + tall * 0.5) * k)
        let opening = ellipse(P(fx, h.y - 0.6 * k), 11.6 * k, 10.2 * k)
        let path = CGMutablePath()
        path.addPath(outer)
        if !g.backView { path.addPath(opening) }
        ctx.setFillColor(C(color))
        ctx.addPath(path)
        ctx.fillPath(using: .evenOdd)
        if !g.backView, let rim {
            let ring = CGMutablePath()
            ring.addPath(ellipse(P(fx, h.y - 0.6 * k), 13 * k, 11.5 * k))
            ring.addPath(opening)
            ctx.setFillColor(C(rim))
            ctx.addPath(ring)
            ctx.fillPath(using: .evenOdd)
        }
        if !g.backView { top() }
    }

    private static func dots(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ gap: CGFloat, _ r: CGFloat) {
        ctx.setFillColor(C(0x1B1B1F))
        ctx.fillEllipse(in: ovalRect(x - gap, y, r, r * 1.1))
        ctx.fillEllipse(in: ovalRect(x + gap, y, r, r * 1.1))
        ctx.setFillColor(C(0xFFFFFF))
        ctx.fillEllipse(in: ovalRect(x - gap + r * 0.35, y + r * 0.4, r * 0.35, r * 0.35))
        ctx.fillEllipse(in: ovalRect(x + gap + r * 0.35, y + r * 0.4, r * 0.35, r * 0.35))
    }

    private static func blush(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ gap: CGFloat, _ k: CGFloat) {
        ctx.setFillColor(C(0xF48FB1, 0.7))
        ctx.fillEllipse(in: ovalRect(x - gap, y, 1.8 * k, 1.1 * k))
        ctx.fillEllipse(in: ovalRect(x + gap, y, 1.8 * k, 1.1 * k))
    }

    private static func smile(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ k: CGFloat) {
        ctx.setStrokeColor(C(0x1B1B1F))
        ctx.setLineWidth(0.6 * k)
        ctx.move(to: P(x - 1.6 * k, y)); ctx.addQuadCurve(to: P(x, y), control: P(x - 0.8 * k, y - 1 * k))
        ctx.addQuadCurve(to: P(x + 1.6 * k, y), control: P(x + 0.8 * k, y - 1 * k))
        ctx.strokePath()
    }

    private static func roundEars(_ ctx: CGContext, _ h: CGPoint, _ k: CGFloat, _ color: UInt32, inner: UInt32?) {
        for s in [CGFloat(-1), 1] {
            let e = P(h.x + s * 11 * k, h.y + 14 * k)
            ctx.setFillColor(C(color))
            ctx.fillEllipse(in: ovalRect(e.x, e.y, 4.6 * k, 4.6 * k))
            if let inner { ctx.setFillColor(C(inner)); ctx.fillEllipse(in: ovalRect(e.x, e.y, 2.4 * k, 2.4 * k)) }
        }
    }

    private static func pointEars(_ ctx: CGContext, _ h: CGPoint, _ k: CGFloat, _ color: UInt32, inner: UInt32?) {
        for s in [CGFloat(-1), 1] {
            let tri = [P(h.x + s * 14 * k, h.y + 8 * k), P(h.x + s * 11 * k, h.y + 22 * k), P(h.x + s * 4 * k, h.y + 14 * k)]
            ctx.setFillColor(C(color)); ctx.addPath(poly(tri)); ctx.fillPath()
            if let inner {
                let c = P((tri[0].x + tri[1].x + tri[2].x) / 3, (tri[0].y + tri[1].y + tri[2].y) / 3)
                ctx.setFillColor(C(inner))
                ctx.addPath(poly(tri.map { P($0.x + (c.x - $0.x) * 0.45, $0.y + (c.y - $0.y) * 0.45) }))
                ctx.fillPath()
            }
        }
    }

    static func drawHood(_ ctx: CGContext, _ look: CatLook, _ g: Geo, _ ri: RenderInfo, fx: CGFloat, k: CGFloat) {
        let h = g.head
        let fy = h.y + 12.5 * k            // the face printed on the hood
        switch look.hat {
        case "chick":
            hood(ctx, g, fx: fx, k: k, color: 0xF6D44A, rim: 0xFBE58A, behind: {
                ctx.setFillColor(C(0xF6D44A))
                for a in [80.0, 100.0, 120.0] as [CGFloat] {
                    let r = a * .pi / 180
                    ctx.addPath(stroked([P(h.x, h.y + 15 * k), P(h.x + cos(r) * 7 * k, h.y + 15 * k + sin(r) * 7 * k)], 2.4 * k))
                }
                for s in [CGFloat(-1), 1] { ctx.addPath(ellipse(P(h.x + s * 15 * k, h.y - 3 * k), 4 * k, 6 * k, rot: s * 0.4)) }
                ctx.fillPath()
            }, top: {
                dots(ctx, fx, fy, 3.6 * k, 1.1 * k)
                ctx.setFillColor(C(0xF0A12F))
                ctx.fillEllipse(in: ovalRect(fx, fy - 2.4 * k, 2.4 * k, 1.4 * k))
            })
        case "jester":
            hood(ctx, g, fx: fx, k: k, color: 0x2E2A33, rim: 0xF2EEE8, behind: {
                for s in [CGFloat(-1), 1] {
                    let tip = P(h.x + s * 18 * k, h.y + 21 * k)
                    ctx.setFillColor(C(0x2E2A33))
                    ctx.addPath(poly([P(h.x + s * 4 * k, h.y + 15 * k), tip, P(h.x + s * 14 * k, h.y + 7 * k)]))
                    ctx.fillPath()
                    ctx.setFillColor(C(0x1B1B1F))
                    ctx.fillEllipse(in: ovalRect(tip.x, tip.y, 1.8 * k, 1.8 * k))
                }
            }, top: {
                ctx.setFillColor(C(0xF4A7C0))
                ctx.fillEllipse(in: ovalRect(fx, fy, 2.6 * k, 2.3 * k))
                ctx.fill(CGRect(x: fx - 1.4 * k, y: fy - 3.2 * k, width: 2.8 * k, height: 1.6 * k))
                ctx.setFillColor(C(0x2E2A33))
                ctx.fillEllipse(in: ovalRect(fx - 1 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k))
                ctx.fillEllipse(in: ovalRect(fx + 1 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k))
            })
        case "vampire":
            // slicked black hair with a widow's peak, little bat wings at the sides
            ctx.setFillColor(C(0x1E1C22))
            for s in [CGFloat(-1), 1] {
                let b = P(h.x + s * 10 * k, h.y + 9 * k)
                ctx.addPath(poly([b, P(b.x + s * 9 * k, b.y + 7 * k), P(b.x + s * 7 * k, b.y + 3 * k), P(b.x + s * 10 * k, b.y + 1 * k),
                                  P(b.x + s * 6 * k, b.y - 1 * k), P(b.x + s * 2 * k, b.y - 3 * k)]))
            }
            ctx.fillPath()
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 3 * k, width: 80, height: 80))
            let hair = CGMutablePath()
            hair.addPath(ellipse(P(h.x, h.y + 2 * k), 13.4 * k, 11.4 * k))
            ctx.addPath(hair); ctx.fillPath()
            ctx.restoreGState()
            if !g.backView {
                ctx.addPath(poly([P(fx - 6 * k, h.y + 3.2 * k), P(fx, h.y + 0.2 * k), P(fx + 6 * k, h.y + 3.2 * k)]))
                ctx.fillPath()
            }
        case "santa":
            // red floppy hat, white fur brim, tip with a pompom flopping to the side
            let sway = sin(CGFloat(ri.t) * 1.6) * 1.2 * k
            let hat = CGMutablePath()
            hat.move(to: P(h.x - 12 * k, h.y + 6 * k))
            hat.addQuadCurve(to: P(h.x + 4 * k, h.y + 22 * k), control: P(h.x - 9 * k, h.y + 20 * k))
            hat.addQuadCurve(to: P(h.x + 15 * k + sway, h.y + 10 * k), control: P(h.x + 13 * k, h.y + 22 * k))
            hat.addQuadCurve(to: P(h.x + 9 * k, h.y + 15 * k), control: P(h.x + 12 * k, h.y + 15 * k))
            hat.addQuadCurve(to: P(h.x + 12 * k, h.y + 6 * k), control: P(h.x + 10 * k, h.y + 10 * k))
            hat.closeSubpath()
            ctx.setFillColor(C(0xD32F2F)); ctx.addPath(hat); ctx.fillPath()
            ctx.setFillColor(C(0xFAFAF7))
            ctx.addPath(CGPath(roundedRect: CGRect(x: h.x - 13.6 * k, y: h.y + 3.4 * k, width: 27.2 * k, height: 4.6 * k),
                               cornerWidth: 2.3 * k, cornerHeight: 2.3 * k, transform: nil)); ctx.fillPath()
            ctx.fillEllipse(in: ovalRect(h.x + 15 * k + sway, h.y + 9.5 * k, 3.2 * k, 3.2 * k))
        case "tophat":
            ctx.setFillColor(C(0x1E1C22))
            ctx.addPath(ellipse(P(h.x, h.y + 9 * k), 8.5 * k, 1.8 * k)); ctx.fillPath()
            ctx.fill(CGRect(x: h.x - 5.5 * k, y: h.y + 9 * k, width: 11 * k, height: 10 * k))
            ctx.addPath(ellipse(P(h.x, h.y + 19 * k), 5.5 * k, 1.2 * k)); ctx.fillPath()
            ctx.setFillColor(C(0xD32F2F))
            ctx.fill(CGRect(x: h.x - 5.5 * k, y: h.y + 10.2 * k, width: 11 * k, height: 1.8 * k))
        case "starhelm":
            ctx.setFillColor(C(0xF4F2EE))
            for s in [CGFloat(-1), 1] {
                for (i, len) in [CGFloat(7), 5.5].enumerated() {
                    let base = P(h.x + s * 11.5 * k, h.y + (6 + CGFloat(i) * 2) * k)
                    let a = (45 + CGFloat(i) * 20) * .pi / 180
                    ctx.addPath(stroked([base, P(base.x + s * cos(a) * len * k, base.y + sin(a) * len * k)], 2.2 * k))
                }
            }
            ctx.fillPath()
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 3.5 * k, width: 80, height: 80))
            ctx.setFillColor(C(0x1E4FA3))
            ctx.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k)); ctx.fillPath()
            ctx.restoreGState()
            if !g.backView {
                ctx.setFillColor(C(0xFFFFFF))
                ctx.addPath(star(P(fx, h.y + 8.5 * k), 2.8 * k)); ctx.fillPath()
            }
        case "ironhelm":
            ctx.setFillColor(C(0xB71C1C))
            ctx.addPath(ellipse(P(h.x, h.y - 0.4 * k), 13.8 * k, 11.2 * k)); ctx.fillPath()
            if !g.backView {
                let plate = CGMutablePath()
                plate.move(to: P(fx - 8.5 * k, h.y + 5 * k))
                plate.addLine(to: P(fx + 8.5 * k, h.y + 5 * k))
                plate.addQuadCurve(to: P(fx, h.y - 9.5 * k), control: P(fx + 9 * k, h.y - 7 * k))
                plate.addQuadCurve(to: P(fx - 8.5 * k, h.y + 5 * k), control: P(fx - 9 * k, h.y - 7 * k))
                ctx.setFillColor(C(0xE3B23C)); ctx.addPath(plate); ctx.fillPath()
                ctx.setFillColor(C(0x8DF0FF))
                for s in [CGFloat(-1), 1] {
                    ctx.addPath(poly([P(fx + s * 1.5 * k, h.y + 0.4 * k), P(fx + s * 6 * k, h.y + 1.4 * k), P(fx + s * 5.5 * k, h.y - 0.4 * k)]))
                }
                ctx.fillPath()
                ctx.setStrokeColor(C(0x9C7A1E)); ctx.setLineWidth(0.6 * k)
                ctx.move(to: P(fx - 3 * k, h.y - 5 * k)); ctx.addLine(to: P(fx + 3 * k, h.y - 5 * k)); ctx.strokePath()
            }
        case "banana":
            // yellow peel hood: brown stem on top, two strips of peel flopping open at the sides
            hood(ctx, g, fx: fx, k: k, color: 0xF6D84B, rim: 0xFFF3B8, behind: {
                ctx.setFillColor(C(0x6B4A2B))
                ctx.addPath(CGPath(roundedRect: CGRect(x: h.x - 1.8 * k, y: h.y + 15 * k, width: 3.6 * k, height: 6 * k),
                                   cornerWidth: 1.2 * k, cornerHeight: 1.2 * k, transform: nil))
                ctx.fillPath()
            })
            for s in [CGFloat(-1), 1] {
                let base = P(h.x + s * 7 * k, h.y + 13 * k)
                let mid = P(h.x + s * 17 * k, h.y + 9 * k)
                let tip = P(h.x + s * 18.5 * k, h.y - 1 * k)
                ctx.setFillColor(C(0xF6D84B))
                ctx.addPath(stroked([base, mid, tip], 5 * k)); ctx.fillPath()
                if !g.backView {
                    ctx.setFillColor(C(0xFFF3B8))
                    ctx.addPath(stroked([P(lerp(base.x, mid.x, 0.5), lerp(base.y, mid.y, 0.5)), mid, tip], 2.2 * k)); ctx.fillPath()
                }
                ctx.setFillColor(C(0x6B4A2B))
                ctx.fillEllipse(in: ovalRect(tip.x, tip.y - 1.4 * k, 1.3 * k, 1.1 * k))
            }
        case "dino", "pinkdino":
            let pink = look.hat == "pinkdino"
            hood(ctx, g, fx: fx, k: k, color: pink ? 0xF2A9C4 : 0x79A85A, rim: pink ? 0xFBE3EC : nil, behind: {
                // a row of spikes down the back of the head, all leaning the same way (up and back)
                ctx.setFillColor(C(pink ? 0xE04A6A : 0xF2C230))
                let dir = P(-0.55, 0.83)
                let side = P(dir.y, -dir.x)
                for i in 0..<5 {
                    let a = (85 + CGFloat(i) * 27) * .pi / 180
                    let b = P(h.x + cos(a) * 14 * k, h.y + 1.5 * k + sin(a) * 13.5 * k)
                    ctx.addPath(poly([P(b.x - side.x * 2.6 * k, b.y - side.y * 2.6 * k), P(b.x + dir.x * 5.5 * k, b.y + dir.y * 5.5 * k),
                                      P(b.x + side.x * 2.6 * k, b.y + side.y * 2.6 * k)]))
                }
                ctx.fillPath()
            }, top: {
                ctx.setStrokeColor(C(0x1B1B1F)); ctx.setLineWidth(0.7 * k)
                for s in [CGFloat(-1), 1] {
                    ctx.move(to: P(fx + s * 3.6 * k - 1.2 * k, fy)); ctx.addQuadCurve(to: P(fx + s * 3.6 * k + 1.2 * k, fy), control: P(fx + s * 3.6 * k, fy + 1.4 * k))
                }
                ctx.strokePath()
                smile(ctx, fx, fy - 2 * k, k)
                blush(ctx, fx, fy - 1.5 * k, 6 * k, k)
            })
        case "panda":
            hood(ctx, g, fx: fx, k: k, color: 0xF4F2EE, behind: {
                roundEars(ctx, h, k, 0x2A2A2E, inner: nil)
            }, top: {
                ctx.setFillColor(C(0x2A2A2E))
                for s in [CGFloat(-1), 1] { ctx.addPath(ellipse(P(fx + s * 4 * k, fy), 2.2 * k, 1.6 * k, rot: s * -0.5)) }
                ctx.fillPath()
                ctx.setFillColor(C(0xFFFFFF))
                for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(fx + s * 4 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k)) }
                ctx.setFillColor(C(0x2A2A2E))
                ctx.fillEllipse(in: ovalRect(fx, fy - 2 * k, 0.9 * k, 0.6 * k))
            })
        case "bunny":
            hood(ctx, g, fx: fx, k: k, color: 0xF3EDE2, behind: {
                // long ears standing straight up, a little apart
                for s in [CGFloat(-1), 1] {
                    let c = P(h.x + s * 5.5 * k, h.y + 22 * k)
                    ctx.setFillColor(C(0xF3EDE2))
                    ctx.addPath(ellipse(c, 3.8 * k, 10.5 * k, rot: s * -0.12)); ctx.fillPath()
                    if !g.backView {
                        ctx.setFillColor(C(0xF6C1CF))
                        ctx.addPath(ellipse(P(c.x, c.y + 0.5 * k), 1.8 * k, 7.5 * k, rot: s * -0.12)); ctx.fillPath()
                    }
                }
            }, top: {
                dots(ctx, fx, fy, 3.6 * k, 0.9 * k)
                ctx.setFillColor(C(0xF48FB1))
                ctx.fillEllipse(in: ovalRect(fx, fy - 1.8 * k, 0.9 * k, 0.6 * k))
                blush(ctx, fx, fy - 1.6 * k, 6 * k, k)
            })
        case "cap":
            ctx.saveGState()
            ctx.clip(to: CGRect(x: h.x - 40, y: h.y + 4 * k, width: 80, height: 80))
            ctx.setFillColor(C(0xD9302C))
            ctx.addPath(ellipse(P(h.x, h.y + 3.5 * k), 13 * k, 11 * k))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.setFillColor(C(0xB52420))
            ctx.addPath(ellipse(P(fx + 7 * k, h.y + 4.6 * k), 9 * k, 2.2 * k, rot: 0.08))
            ctx.fillPath()
            if !g.backView {
                ctx.setFillColor(C(0xFFFFFF))
                ctx.fillEllipse(in: ovalRect(fx + 1 * k, h.y + 9.5 * k, 3.2 * k, 3 * k))
            }
        case "bee":
            hood(ctx, g, fx: fx, k: k, color: 0xF4C430, behind: {
                ctx.setFillColor(C(0xCFE8F7, 0.8))
                for s in [CGFloat(-1), 1] { ctx.addPath(ellipse(P(h.x + s * 17 * k, h.y + 10 * k), 5 * k, 3.5 * k, rot: s * 0.4)) }
                ctx.fillPath()
                ctx.setStrokeColor(C(0x4A3423)); ctx.setLineWidth(0.8 * k)
                for s in [CGFloat(-1), 1] { ctx.move(to: P(h.x + s * 3 * k, h.y + 15 * k)); ctx.addLine(to: P(h.x + s * 6 * k, h.y + 23 * k)) }
                ctx.strokePath()
                ctx.setFillColor(C(0x4A3423))
                for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(h.x + s * 6 * k, h.y + 23 * k, 1.6 * k, 1.6 * k)) }
            })
            // stripes across the hood
            ctx.saveGState()
            ctx.addPath(ellipse(P(h.x, h.y + 1.5 * k), 15.5 * k, 15 * k))
            ctx.addPath(ellipse(P(fx, h.y - 0.6 * k), 11.6 * k, 10.2 * k))
            ctx.clip(using: .evenOdd)
            ctx.setFillColor(C(0x4A3423))
            for y in [CGFloat(8), 13] { ctx.fill(CGRect(x: h.x - 20 * k, y: h.y + y * k, width: 40 * k, height: 2.4 * k)) }
            ctx.restoreGState()
        case "cowboy":
            ctx.setStrokeColor(C(0x5A3A1C)); ctx.setLineWidth(0.5)
            if !g.backView {
                ctx.move(to: P(h.x - 12 * k, h.y + 5 * k)); ctx.addLine(to: P(fx, h.y - 11 * k)); ctx.addLine(to: P(h.x + 12 * k, h.y + 5 * k))
                ctx.strokePath()
            }
            ctx.setFillColor(C(0x8B5A2B))
            ctx.addPath(CGPath(roundedRect: CGRect(x: h.x - 7 * k, y: h.y + 6 * k, width: 14 * k, height: 10 * k),
                               cornerWidth: 4 * k, cornerHeight: 4 * k, transform: nil))
            ctx.fillPath()
            ctx.addPath(ellipse(P(h.x, h.y + 6.5 * k), 18 * k, 3.4 * k))
            ctx.fillPath()
            ctx.setFillColor(C(0x5A3A1C))
            ctx.fill(CGRect(x: h.x - 7 * k, y: h.y + 7.5 * k, width: 14 * k, height: 1.6 * k))
            if !g.backView {
                ctx.setFillColor(C(0xF5C542))
                ctx.addPath(star(P(fx, h.y + 12 * k), 2.4 * k)); ctx.fillPath()
            }
        case "bear":
            hood(ctx, g, fx: fx, k: k, color: 0xA7703F, behind: {
                roundEars(ctx, h, k, 0xA7703F, inner: 0xE0B68A)
            }, top: {
                ctx.setFillColor(C(0xE8C9A0))
                ctx.fillEllipse(in: ovalRect(fx, fy - 1.6 * k, 3 * k, 2.2 * k))
                dots(ctx, fx, fy + 0.8 * k, 4 * k, 0.9 * k)
                ctx.setFillColor(C(0x3B2A1A))
                ctx.fillEllipse(in: ovalRect(fx, fy - 1 * k, 0.9 * k, 0.6 * k))
            })
        case "penguin":
            hood(ctx, g, fx: fx, k: k, color: 0x2D3756, behind: {
                ctx.setFillColor(C(0x2D3756))
                ctx.fillEllipse(in: ovalRect(h.x, h.y + 17 * k, 2.4 * k, 2 * k))
            }, top: {
                ctx.setFillColor(C(0xF4F2EE))
                ctx.fillEllipse(in: ovalRect(fx, fy - 0.5 * k, 7.5 * k, 3.6 * k))
                dots(ctx, fx, fy, 3.4 * k, 0.9 * k)
                ctx.setFillColor(C(0xF0A12F))
                ctx.addPath(poly([P(fx - 1.3 * k, fy - 1.4 * k), P(fx + 1.3 * k, fy - 1.4 * k), P(fx, fy - 3 * k)])); ctx.fillPath()
                blush(ctx, fx, fy - 1.4 * k, 5.5 * k, k)
            })
        case "merc":
            // full face mask over head and ears, black patches around white eye slits; two hilts behind
            ctx.setStrokeColor(C(0x2A2A2E)); ctx.setLineWidth(1.8 * k)
            for s in [CGFloat(-1), 1] { ctx.move(to: P(h.x + s * 9 * k, h.y + 4 * k)); ctx.addLine(to: P(h.x + s * 16 * k, h.y + 19 * k)) }
            ctx.strokePath()
            ctx.setFillColor(C(0xC62828))
            ctx.addPath(ellipse(P(h.x, h.y - 0.5 * k), 13.6 * k, 10.9 * k)); ctx.fillPath()
            // the cat's own ear shapes, slightly enlarged, so no fur peeks out at the edges
            for e in earPaths(h, g.headR * 1.04, flat: g.earsFlat) { ctx.addPath(e); ctx.fillPath() }
            if !g.backView {
                for s in [CGFloat(-1), 1] {
                    let e = P(fx + s * 5 * k, h.y + 0.6 * k)
                    let patch = CGMutablePath()
                    patch.move(to: P(e.x - s * 3.2 * k, e.y - 2.4 * k))
                    patch.addQuadCurve(to: P(e.x + s * 4.6 * k, e.y + 3.4 * k), control: P(e.x + s * 5.2 * k, e.y - 3.4 * k))
                    patch.addQuadCurve(to: P(e.x - s * 3.2 * k, e.y - 2.4 * k), control: P(e.x - s * 4.6 * k, e.y + 4 * k))
                    ctx.setFillColor(C(0x111111)); ctx.addPath(patch); ctx.fillPath()
                    ctx.setFillColor(C(0xFAFAF7))
                    ctx.addPath(ellipse(P(e.x + s * 0.4 * k, e.y + 0.4 * k), 2.1 * k, 1.1 * k, rot: s * 0.45)); ctx.fillPath()
                }
            }
        case "witch":
            ctx.setFillColor(C(0x3A3440))
            ctx.addPath(ellipse(P(h.x, h.y + 6.5 * k), 17 * k, 3.4 * k))
            ctx.fillPath()
            let cone = CGMutablePath()
            cone.move(to: P(h.x - 9 * k, h.y + 6.5 * k))
            cone.addQuadCurve(to: P(h.x + 14 * k, h.y + 26 * k), control: P(h.x - 1 * k, h.y + 24 * k))
            cone.addQuadCurve(to: P(h.x + 9 * k, h.y + 6.5 * k), control: P(h.x + 7 * k, h.y + 16 * k))
            cone.closeSubpath()
            ctx.addPath(cone); ctx.fillPath()
            ctx.setFillColor(C(0x7E57C2))
            ctx.fill(CGRect(x: h.x - 8.6 * k, y: h.y + 7.5 * k, width: 17.4 * k, height: 2.4 * k))
            if !g.backView {
                ctx.setFillColor(C(0xF5C542))
                ctx.addPath(star(P(h.x + 5 * k, h.y + 8.7 * k), 2 * k)); ctx.fillPath()
            }
        case "monster":
            hood(ctx, g, fx: fx, k: k, color: 0x9B7FD1, behind: {
                for s in [CGFloat(-1), 1] {
                    ctx.setStrokeColor(C(0x7E62B8)); ctx.setLineWidth(1.4 * k)
                    ctx.move(to: P(h.x + s * 5 * k, h.y + 14 * k)); ctx.addLine(to: P(h.x + s * 8 * k, h.y + 22 * k)); ctx.strokePath()
                    ctx.setFillColor(C(0xFFFFFF)); ctx.fillEllipse(in: ovalRect(h.x + s * 8 * k, h.y + 23 * k, 2.6 * k, 2.6 * k))
                    ctx.setFillColor(C(0x1B1B1F)); ctx.fillEllipse(in: ovalRect(h.x + s * 8 * k + 0.4 * k, h.y + 23 * k, 1.2 * k, 1.2 * k))
                }
            }, top: {
                ctx.setFillColor(C(0xFFFFFF))
                for i in 0..<7 {
                    let a = (152 - CGFloat(i) * 21) * .pi / 180
                    let da: CGFloat = 8 * .pi / 180
                    let e = { (ang: CGFloat) in P(fx + cos(ang) * 11.6 * k, h.y - 0.6 * k + sin(ang) * 10.2 * k) }
                    ctx.addPath(poly([e(a - da), P(fx + cos(a) * 8.8 * k, h.y - 0.6 * k + sin(a) * 7.6 * k), e(a + da)]))
                }
                ctx.fillPath()
                smile(ctx, fx, fy, k)
                blush(ctx, fx, fy + 0.4 * k, 5 * k, k)
            })
        case "ghost":
            ctx.setFillColor(C(0xF6F4EE))
            let p = CGMutablePath()
            p.move(to: P(h.x - 15 * k, h.y - 12 * k))
            p.addLine(to: P(h.x - 15 * k, h.y + 4 * k))
            p.addQuadCurve(to: P(h.x + 15 * k, h.y + 4 * k), control: P(h.x, h.y + 27 * k))
            p.addLine(to: P(h.x + 15 * k, h.y - 12 * k))
            p.addQuadCurve(to: P(h.x + 8 * k, h.y - 10 * k), control: P(h.x + 12 * k, h.y - 9 * k))
            p.addLine(to: P(h.x + 10 * k, h.y - 1 * k))
            p.addLine(to: P(h.x - 10 * k, h.y - 1 * k))
            p.addLine(to: P(h.x - 8 * k, h.y - 10 * k))
            p.addQuadCurve(to: P(h.x - 15 * k, h.y - 12 * k), control: P(h.x - 12 * k, h.y - 9 * k))
            p.closeSubpath()
            let path = CGMutablePath()
            path.addPath(p)
            if !g.backView { path.addPath(ellipse(P(fx, h.y - 0.6 * k), 11.2 * k, 9.8 * k)) }
            ctx.addPath(path); ctx.fillPath(using: .evenOdd)
            if !g.backView {
                ctx.setFillColor(C(0x1B1B1F))
                for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(fx + s * 3.6 * k, fy, 1.4 * k, 1.9 * k)) }
            }
        case "unicorn":
            hood(ctx, g, fx: fx, k: k, color: 0xF7F3EE, behind: {
                pointEars(ctx, h, k, 0xF7F3EE, inner: 0xF6C1CF)
                for (i, col) in [0xF48FB1, 0x81D4FA, 0xB39DDB, 0xFFE082].enumerated() {
                    ctx.setFillColor(C(UInt32(col)))
                    ctx.fillEllipse(in: ovalRect(h.x + (9 + CGFloat(i) * 1.5) * k, h.y + (16 - CGFloat(i) * 2.4) * k, 2.4 * k, 2.4 * k))
                }
            }, top: {
                dots(ctx, fx, fy - 0.5 * k, 3.6 * k, 0.9 * k)
                smile(ctx, fx, fy - 2.5 * k, k)
                blush(ctx, fx, fy - 2 * k, 5.8 * k, k)
            })
            ctx.setFillColor(C(0xF2C230))
            ctx.addPath(poly([P(h.x - 2.2 * k, h.y + 15.5 * k), P(h.x + 0.5 * k, h.y + 26 * k), P(h.x + 2.2 * k, h.y + 15.5 * k)]))
            ctx.fillPath()
        case "pig":
            hood(ctx, g, fx: fx, k: k, color: 0xF2A6B4, behind: {
                ctx.setFillColor(C(0xEE90A2))
                for s in [CGFloat(-1), 1] {
                    ctx.addPath(poly([P(h.x + s * 7 * k, h.y + 14 * k), P(h.x + s * 16 * k, h.y + 17 * k), P(h.x + s * 13 * k, h.y + 8 * k)]))
                }
                ctx.fillPath()
            }, top: {
                ctx.setFillColor(C(0xF7C4CE))
                ctx.fillEllipse(in: ovalRect(fx, fy - 1.6 * k, 2.8 * k, 2 * k))
                ctx.setFillColor(C(0xC86A7C))
                for s in [CGFloat(-1), 1] { ctx.fillEllipse(in: ovalRect(fx + s * 1 * k, fy - 1.6 * k, 0.5 * k, 0.8 * k)) }
                dots(ctx, fx, fy + 1.4 * k, 4 * k, 0.8 * k)
            })
        default: break
        }
    }
}
