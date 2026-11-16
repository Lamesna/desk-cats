import AppKit

// Pixel cats: the same cats, coats, hats and costumes, drawn as small pixel sprites.
// The sitting cat comes from a reference picture (style A); the side views are drawn from shapes in the same
// palette. Everything is built from letters (b body, h head, f face, r inner ear, v belly, t tail, d shade,
// e eye, p pink, u paw, k outline) so coats, costumes and hats are plain recolours and overlays.
// Same design as windows/src/pixel.js.

struct RGB: Equatable {
    var r: Int, g: Int, b: Int
    init(_ r: Int, _ g: Int, _ b: Int) { self.r = r; self.g = g; self.b = b }
    init(hex: UInt32) { r = Int((hex >> 16) & 255); g = Int((hex >> 8) & 255); b = Int(hex & 255) }
    func dk(_ f: Double) -> RGB { RGB(max(0, Int((Double(r) * f).rounded())), max(0, Int((Double(g) * f).rounded())), max(0, Int((Double(b) * f).rounded()))) }
    func lt(_ d: Int) -> RGB { RGB(min(255, r + d), min(255, g + d), min(255, b + d)) }
}

private typealias LGrid = [[Character?]]
private typealias CGrid = [[RGB?]]

private func blank<T>(_ w: Int, _ h: Int) -> [[T?]] { [[T?]](repeating: [T?](repeating: nil, count: w), count: h) }

private func phash(_ a: Int, _ b: Int, _ c: Int) -> UInt32 {
    var h = (UInt32(truncatingIfNeeded: a + 17) &* 374761393) ^ (UInt32(truncatingIfNeeded: b + 31) &* 668265263) ^ (UInt32(truncatingIfNeeded: c + 7) &* 2246822519)
    h = (h ^ (h >> 13)) &* 1274126177
    return h ^ (h >> 16)
}

/// A letter grid with drawing helpers.
private struct Sheet {
    var g: LGrid
    var w: Int { g.first?.count ?? 0 }
    var h: Int { g.count }
    init(_ w: Int, _ h: Int) { g = blank(w, h) }
    subscript(x: Int, y: Int) -> Character? {
        get { y >= 0 && y < h && x >= 0 && x < w ? g[y][x] : nil }
        set { if y >= 0 && y < h && x >= 0 && x < w { g[y][x] = newValue } }
    }
    mutating func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: Character?) {
        guard y0 <= y1, x0 <= x1 else { return }
        for y in y0...y1 { for x in x0...x1 { self[x, y] = c } }
    }
    mutating func ell(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: Character) {
        for y in Int((cy - ry).rounded(.down))...Int((cy + ry).rounded(.up)) {
            for x in Int((cx - rx).rounded(.down))...Int((cx + rx).rounded(.up)) {
                let dx = (Double(x) - cx) / rx, dy = (Double(y) - cy) / ry
                if dx * dx + dy * dy <= 1 { self[x, y] = c }
            }
        }
    }
    mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: Character, _ t: Int) {
        let n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in 0...n {
            let x = Int((Double(x0) + Double(x1 - x0) * Double(i) / Double(n)).rounded())
            let y = Int((Double(y0) + Double(y1 - y0) * Double(i) / Double(n)).rounded())
            rect(x, y, x + t - 1, y + t - 1, c)
        }
    }
}

enum PixelCats {
    static let padTop = 9, padSide = 4

    // MARK: sprites

    private static let frontASCII = [
        "....................", "...##d.....##d......", "..#bb#d...#bb#d.....", "..#pbb####bbpb#d....", ".#bppbbbbbbppb#d....",
        ".#bpbbbbbbbbpbb#d...", ".#bbbbbbbbbbbbb#d...", "#bbbbbbbbbbbbbbb#d..", "bbbbbbbbbbbbbbbb#d..", "#bbbbebbbbebbbbbbd..",
        "bbbbpebpbbepbbd#d...", ".#bbbbbbbbbbbbbbd...", "..#bbbbbbbbbbb#d....", "...##bbbbbb###d.....", "..#bbbbbbbbbbb#d....",
        "..#bbbbbbbbbbbb#d...", "..#bbbb#bbbbb#bd#d..", "..#bbbb#bbbbb#bb#d..", "...#bbb#bbbb#bbbd#d.", "...#bbb#bbbb#bbdd#d.",
        "....#pb#bpb#bbdd#d..", ".....######d####d...", "....................",
    ]

    private static func frontBase() -> LGrid {
        var g: LGrid = frontASCII.map { $0.map { $0 == "." ? nil : $0 } }
        let H = g.count, W = g[0].count
        func empty(_ x: Int, _ y: Int) -> Bool { y < 0 || y >= H || x < 0 || x >= W || g[y][x] == nil }
        func touches(_ x: Int, _ y: Int) -> Bool { empty(x - 1, y) || empty(x + 1, y) || empty(x, y - 1) || empty(x, y + 1) }
        // the old outline and drop shadow go; the outline is drawn again around the final shape
        for ch: Character in ["d", "#"] {
            var kill: [(Int, Int)] = []
            for y in 0..<H { for x in 0..<W where g[y][x] == ch && touches(x, y) { kill.append((x, y)) } }
            for (x, y) in kill { g[y][x] = nil }
        }
        var L: LGrid = blank(W, H)
        for y in 0..<H {
            for x in 0..<W {
                guard let c = g[y][x] else { continue }
                var o = c
                if c == "#" { o = "k" }
                else if y <= 12 {
                    if c == "b" {
                        let face = y >= 8 && y <= 11 && x >= 3 && x <= 13 && !((x == 3 || x == 13) && (y == 8 || y == 11))
                        o = face ? "f" : "h"
                    } else if c == "p" && y <= 5 { o = "r" }
                } else {
                    if c == "b" || c == "d" {
                        if x >= 13 && y >= 16 { o = "t" }
                        else if c == "b" && x >= 6 && x <= 12 && y >= 15 && y <= 20 { o = "v" }
                    } else if c == "p" && y >= 19 { o = "u" }
                }
                L[y][x] = o
            }
        }
        return L
    }

    private static func headAt(_ s: inout Sheet, _ x0: Int, _ hy: Int, _ w: Int, _ eye: Character) {
        s.rect(x0, hy + 1, x0 + w - 1, hy + 9, "h"); s.rect(x0 + 1, hy, x0 + w - 2, hy, "h")
        for (x, y) in [(x0, hy + 1), (x0 + w - 1, hy + 1), (x0, hy + 9), (x0 + w - 1, hy + 9)] { s[x, y] = nil }
        for x in [x0, x0 + w - 4] {
            s.rect(x, hy - 1, x + 3, hy, "h"); s.rect(x + 1, hy - 2, x + 2, hy - 2, "h")
            s[x + 1, hy - 1] = "r"; s[x + 2, hy - 1] = "r"; s[x + 1, hy] = "r"
        }
        for y in (hy + 5)...(hy + 9) { for x in (x0 + w - 4)...(x0 + w - 1) where s[x, y] == "h" { s[x, y] = "f" } }
        s[x0 + w - 5, hy + 4] = eye; s[x0 + w - 5, hy + 5] = eye
        s[x0 + w - 1, hy + 6] = "p"
    }

    private static func sideBase(_ kind: String, _ k: Int) -> LGrid {
        var s = Sheet(28, 22)
        let arch = kind == "hiss" ? 2.0 : 0, bob = kind == "walk" && k % 2 == 1 ? -1 : 0
        if kind == "walk" || kind == "hiss" {
            let ph = Double(k) * .pi / 2, A = kind == "hiss" ? 0.0 : 2
            func up(_ a: Double) -> Int { cos(a) > 0.5 ? 1 : 0 }
            func off(_ a: Double) -> Int { Int((A * sin(a)).rounded()) }
            let legs: [(Int, Int, Character)] = [(5 + off(ph), up(ph), "b"), (8 + off(ph + .pi), up(ph + .pi), "d"),
                                                 (12 + off(ph), up(ph), "d"), (15 + off(ph + .pi), up(ph + .pi), "b")]
            func leg(_ l: (Int, Int, Character)) {
                s.rect(l.0, 14 + bob, l.0 + 1, 19 - l.1, l.2)
                let paw: Character = l.2 == "d" ? "d" : "u"
                s[l.0, 19 - l.1] = paw; s[l.0 + 1, 19 - l.1] = paw
            }
            leg(legs[1]); leg(legs[2])
            s.ell(10, 12 + Double(bob) - arch / 2, 7.4, 3.8 + arch * 0.4, "b"); s.ell(10, 14 + Double(bob), 5.4, 1.6, "v")
            leg(legs[0]); leg(legs[3])
            let hy = 4 + bob + (kind == "hiss" ? 2 : 0)
            headAt(&s, 13, hy, 12, "e")
            if kind == "hiss" { s.rect(23, hy + 8, 24, hy + 9, "k"); s[22, hy + 8] = "w" }
            let sw = k % 2
            let tp: [(Int, Int)] = kind == "hiss" ? [(4, 11), (2, 8), (2, 3), (3, 0)] : [(4, 11 + bob), (2, 10 + bob), (1 + sw, 7), (1 + sw, 4 + sw)]
            for i in 0..<(tp.count - 1) { s.line(tp[i].0, tp[i].1, tp[i + 1].0, tp[i + 1].1, "t", kind == "hiss" ? 3 : 2) }
        } else if kind == "sleep" || kind == "loaf" {
            let b = Double(k % 2), open = kind == "loaf"
            s.ell(12, 16 - b * 0.5, 9.4, 3.6 + b * 0.5, "b"); s.ell(12, 18, 7, 1.5, "v")
            s.ell(20, 16 - b * 0.4, 5.2, 3.8, "h")
            for x in [17, 22] { s.rect(x, 11, x + 2, 12, "h"); s[x + 1, 12] = "r"; s[x + 1, 11] = "r"; s[x + 1, 10] = "h" }
            s.rect(23, 17, 25, 19, "f"); s[25, 17] = "p"
            if open { s[19, 15] = "e"; s[19, 16] = "e"; s[23, 15] = "e"; s[23, 16] = "e" }
            else { s[19, 16] = "k"; s[20, 16] = "k"; s[22, 16] = "k"; s[23, 16] = "k" }
            s.line(3, 18, 6, 19, "t", 2); s.line(2, 17, 3, 15, "t", 2)
        } else if kind == "jump" {
            let u = k % 2
            s.ell(11, 9 + Double(u), 8, 3.4, "b"); s.ell(11, 11 + Double(u), 6, 1.5, "v")
            s.line(16, 11 + u, 21, 14 + u, "b", 2); s.line(13, 12 + u, 18, 15 + u, "d", 2)
            s.line(5, 10 + u, 1, 14 + u, "b", 2); s.line(8, 11 + u, 4, 15 + u, "d", 2)
            s[21, 15 + u] = "u"; s[22, 15 + u] = "u"; s[1, 15 + u] = "u"
            headAt(&s, 14, 1 + u, 12, "e")
            s.line(4, 8 + u, 2, 5 + u, "t", 2); s.line(2, 5 + u, 3, 2 + u, "t", 2)
        }
        return s.g
    }

    private struct Family { let L: LGrid; let R: LGrid; let ground: Int; let legTop: Int; let side: Bool; let cx: Int }
    private static var families: [String: Family] = [:]

    private static func family(_ key: String) -> Family {
        if let f = families[key] { return f }
        let parts = key.split(separator: ":"), kind = String(parts[0]), n = Int(parts.count > 1 ? parts[1] : "0") ?? 0
        var L: LGrid, ground: Int, legTop: Int
        if kind == "sit" {
            L = frontBase()
            if n == 1 { for y in L.indices { for x in L[y].indices where L[y][x] == "e" { L[y][x] = "k" } } }         // blink
            if n == 2 { for y in 16..<L.count { for x in 13..<L[0].count where L[y][x] == "t" { if L[y - 1][x] == nil { L[y - 1][x] = "t" } } } }
            if n == 3 { for y in 1...4 { for x in 10...15 where L[y][x] != nil && L[y + 1][x] == nil { L[y + 1][x] = L[y][x]; L[y][x] = nil } } }
            ground = 20 + padTop; legTop = 17 + padTop
        } else {
            L = sideBase(kind, n); ground = 19 + padTop
            legTop = (kind == "walk" || kind == "hiss") ? 15 + padTop : 999
        }
        var P: LGrid = blank(L[0].count + padSide * 2, L.count + padTop)
        for y in L.indices { for x in L[y].indices { P[y + padTop][x + padSide] = L[y][x] } }
        let map: [Character: Character] = ["h": "H", "f": "H", "r": "H", "t": "T", "b": "B", "d": "B", "v": "V", "u": "U"]
        let R: LGrid = P.map { $0.map { c in c.map { map[$0] ?? $0 } } }
        let f = Family(L: P, R: R, ground: ground, legTop: legTop, side: kind != "sit", cx: P[0].count / 2)
        families[key] = f
        return f
    }

    // MARK: palette and coats

    private static func palette(_ look: CatLook) -> [Character: RGB] {
        let base = RGB(hex: look.baseHex), acc = RGB(hex: look.accentHex), light = base.r + base.g + base.b > 600
        let pink = RGB(hex: 0xE8AAB4)
        return ["b": base, "t": base, "h": base, "f": base.lt(14), "v": base.lt(14), "d": base.dk(light ? 0.88 : 0.82), "s": acc,
                "w": RGB(hex: 0xF4F4F6), "q": acc, "z": RGB(hex: 0x2B2A2F), "p": pink, "u": pink, "r": pink,
                "e": RGB(hex: look.eyeHexL), "E": RGB(hex: look.eyeHexR), "k": RGB(60, 56, 58)]
    }

    private static func coat(_ L: inout LGrid, _ look: CatLook, _ fam: Family) {
        let pat = look.pattern, seed = Int(look.seed % 997), H = L.count, W = L[0].count
        func isBody(_ c: Character) -> Bool { c == "b" || c == "t" }
        var top = H
        for y in 0..<H { for x in 0..<W { if let c = L[y][x], "hfr".contains(c) { top = min(top, y) } } }
        let tabby = pat == .tabby || pat == .tabbyBicolor, bi = pat == .bicolor || pat == .tabbyBicolor
        for y in 0..<H {
            for x in 0..<W {
                guard let c = L[y][x] else { continue }
                if tabby {
                    let a = fam.side ? x : y + (x >> 2), keep = fam.side ? y % 5 != 0 : x % 6 != 0
                    if isBody(c) && (a + seed) % 3 == 0 && keep { L[y][x] = "s" }
                    else if c == "h" && y >= top + 2 && y <= top + 4 && (x + seed) % 3 == 0 { L[y][x] = "s" }
                }
                if pat == .calico || pat == .tortie, !"ekpur".contains(c) {
                    let n = Int(phash(x / 3, y / 3, seed) % 100)
                    if pat == .calico { if n < 26 { L[y][x] = "q" } else if n < 40 { L[y][x] = "z" } }
                    else if n < 42 { L[y][x] = "q" }
                }
            }
        }
        if bi {
            var sx = 0, n = 0
            for y in 0..<H { for x in 0..<W { if let c = L[y][x], "hf".contains(c) { sx += x; n += 1 } } }
            let cx = Double(sx) / Double(max(1, n))
            for y in 0..<H {
                for x in 0..<W {
                    guard let c = L[y][x] else { continue }
                    if c == "v" || c == "f" || c == "u" { L[y][x] = "w" }
                    else if !fam.side && c == "h" && y >= top + 4 && abs(Double(x) - cx) <= 1.2 + Double(y - top - 4) * 0.25 { L[y][x] = "w" }
                }
            }
        }
        if pat == .colorpoint {
            for y in 0..<H {
                for x in 0..<W {
                    guard let c = L[y][x] else { continue }
                    if c == "f" || c == "t" || c == "u" { L[y][x] = "s" }
                    else if c == "h" && y <= top + 2 { L[y][x] = "s" }
                    else if (c == "b" || c == "d") && y >= fam.ground - 2 { L[y][x] = "s" }
                }
            }
        }
    }

    // MARK: costumes

    private struct Extras {
        var fin: UInt32? = nil, spikes: UInt32? = nil, stripes: UInt32? = nil, spots: [UInt32]? = nil, collar: UInt32? = nil
        var web: UInt32? = nil, buttons: UInt32? = nil, pom: UInt32? = nil, bow: UInt32? = nil, stars: UInt32? = nil, diamonds: UInt32? = nil
    }
    private static let extras: [String: Extras] = [
        "c_shark": Extras(fin: 0x4A6683), "c_dino": Extras(spikes: 0xF2C230), "c_pinkdino": Extras(spikes: 0xE04A6A),
        "c_monster": Extras(spikes: 0x7E62B8), "c_bee": Extras(stripes: 0x4A3423), "c_party": Extras(spots: [0xFFEB3B, 0x4FC3F7, 0x81C784]),
        "c_royal": Extras(collar: 0xF4F2EE), "c_spider": Extras(web: 0x6E1015), "c_plumber": Extras(buttons: 0xF2C230),
        "c_bunny": Extras(pom: 0xFFFFFF), "c_kitty": Extras(bow: 0xD7262F), "c_wizard": Extras(stars: 0xF2C230),
        "c_jester": Extras(diamonds: 0xC9A227), "c_cowboy": Extras(collar: 0xC62828), "c_penguin": Extras(bow: 0xD7262F),
        "c_bear": Extras(bow: 0x6B4423), "c_panda": Extras(bow: 0x4C9A3F), "c_frog": Extras(bow: 0x3E8E41),
    ]

    private struct Box { var x0 = 999, x1 = -1, y0 = 999, y1 = -1 }

    private static func outfit(_ C: inout CGrid, _ R: LGrid, _ L: LGrid, _ fam: Family, _ id: String) {
        let H = C.count, W = C[0].count
        var bb = Box()
        for y in 0..<H { for x in 0..<W where R[y][x] == "B" || R[y][x] == "V" { bb.x0 = min(bb.x0, x); bb.x1 = max(bb.x1, x); bb.y0 = min(bb.y0, y); bb.y1 = max(bb.y1, y) } }
        guard bb.x1 >= 0 else { return }
        func set(_ x: Int, _ y: Int, _ c: RGB) { if y >= 0 && y < H && x >= 0 && x < W { C[y][x] = c } }
        func box(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: RGB) { for y in y0...y1 { for x in x0...x1 { set(x, y, c) } } }
        func paint(_ test: (Character?, Int, Int) -> Bool, _ fn: (Int, Int) -> RGB?) {
            for y in 0..<H { for x in 0..<W where C[y][x] != nil && test(R[y][x], x, y) { if let c = fn(x, y) { C[y][x] = c } } }
        }
        let mx = (bb.x0 + bb.x1) / 2, my = (bb.y0 + bb.y1) / 2 - 1
        switch id {
        case "cape":
            let c = RGB(hex: 0xC62828), c2 = RGB(hex: 0x8E1B1B)
            for y in bb.y0...bb.y1 {
                var mn = 999, mxx = -1
                for x in 0..<W where C[y][x] != nil && R[y][x] == "B" { mn = min(mn, x); mxx = max(mxx, x) }
                guard mn < 999 else { continue }
                if fam.side { for i in 1...3 where mn - i >= 0 && C[y][mn - i] == nil { set(mn - i, y + i - 1, i == 3 ? c2 : c) } }
                else { if mn > 0 && C[y][mn - 1] == nil { set(mn - 1, y, c) }; if mxx + 1 < W && C[y][mxx + 1] == nil { set(mxx + 1, y, c2) } }
            }
            return
        case "bowtie":
            let cx = fam.side ? bb.x1 - 1 : mx, cy = fam.side ? bb.y0 + 2 : bb.y0
            for d in [-2, -1, 1, 2] { set(cx + d, cy, RGB(hex: 0xD7262F)); set(cx + d, cy + 1, RGB(hex: 0xD7262F)) }
            set(cx, cy, RGB(hex: 0x8E1B1B)); set(cx, cy + 1, RGB(hex: 0x8E1B1B)); return
        case "shield": box(mx - 1, my - 1, mx + 1, my + 1, RGB(hex: 0x2F5DAE)); set(mx, my, RGB(hex: 0xF4F2EE)); return
        case "reactor": box(mx - 1, my - 1, mx + 1, my + 1, RGB(hex: 0x9FE8FF)); set(mx, my, RGB(hex: 0xFFFFFF)); return
        default: break
        }
        guard let spec = costumes[id] else { return }
        let body = RGB(hex: spec.body), belly = spec.belly.map { RGB(hex: $0) } ?? body
        let paws = spec.paws.map { RGB(hex: $0) }, legs = spec.legs.map { RGB(hex: $0) }
        paint({ r, _, _ in r == "B" || r == "T" }) { x, y in (legs != nil && y >= fam.legTop) ? legs! : (L[y][x] == "d" ? body.dk(0.84) : body) }
        paint({ r, _, _ in r == "V" }) { _, _ in belly }
        paint({ r, _, _ in r == "U" }) { _, _ in paws ?? legs ?? body }
        let ex = extras[id] ?? Extras()
        if let s = ex.stripes { let c = RGB(hex: s); paint({ r, _, _ in r == "B" || r == "T" || r == "V" }) { x, y in ((fam.side ? x : y) >> 1) % 2 == 0 ? c : nil } }
        if let sp = ex.spots { paint({ r, x, y in (r == "B" || r == "T") && phash(x, y, 5) % 9 == 0 }) { x, y in RGB(hex: sp[Int(phash(x, y, 3) % UInt32(sp.count))]) } }
        if let w = ex.web { let c = RGB(hex: w); paint({ r, x, y in (r == "B" || r == "T") && (x + y) % 5 == 0 }) { _, _ in c } }
        if let s = ex.stars { let c = RGB(hex: s); paint({ r, x, y in r == "B" && phash(x, y, 11) % 12 == 0 }) { _, _ in c } }
        if let d = ex.diamonds { let c = RGB(hex: d); paint({ r, x, y in r == "B" && (x + y) % 6 == 0 && x % 2 == 0 }) { _, _ in c } }
        if let k = ex.collar { let c = RGB(hex: k); paint({ r, _, y in r == "B" && y <= bb.y0 + 1 }) { _, _ in c } }
        if let b = ex.buttons { let c = RGB(hex: b); set(mx - 2, bb.y0 + 2, c); set(mx + 2, bb.y0 + 2, c) }
        if let b = ex.bow { let c = RGB(hex: b), cx = fam.side ? bb.x1 : mx; for d in [-2, -1, 1, 2] { set(cx + d, bb.y0, c) }; set(cx, bb.y0, c.dk(0.7)) }
        if let hx = ex.spikes ?? ex.fin {
            let c = RGB(hex: hx)
            var cols: [Int] = []
            if ex.fin != nil { cols = [mx] }
            else if fam.side { cols = Array(stride(from: bb.x0 + 1, through: bb.x1 - 1, by: 3)) }
            else { cols = [bb.x0 + 3, bb.x1 - 3] }
            for x in cols {
                var t = -1
                for y in 0..<H where C[y][x] != nil { t = y; break }
                guard t > 1 else { continue }
                set(x, t - 1, c); set(x, t - 2, c)
                if ex.fin != nil { set(x - 1, t - 1, c); set(x + 1, t - 1, c); set(x, t - 3, c) }
            }
            if ex.spikes != nil {
                for y in Swift.stride(from: 0, to: H, by: 3) {
                    for x in 0..<W where R[y][x] == "T" && C[y][x] != nil {
                        let nx = fam.side ? x - 1 : x + 1
                        if nx >= 0 && nx < W && C[y][nx] == nil { set(nx, y, c) }
                    }
                }
            }
        }
        if let p = ex.pom {
            var end: (Int, Int)? = nil
            for y in 0..<H { for x in 0..<W where R[y][x] == "T" && C[y][x] != nil { if end == nil || (fam.side ? x < end!.0 : x > end!.0) { end = (x, y) } } }
            if let e = end { box(e.0 - 1, e.1 - 1, e.0 + 1, e.1 + 1, RGB(hex: p)) }
        }
    }

    // MARK: hats

    private static func hat(_ C: inout CGrid, _ L: LGrid, _ R: inout LGrid, _ fam: Family, _ id: String) {
        guard id != "none" else { return }
        let H = C.count, W = C[0].count, dir = fam.side ? 1 : 0
        var x0 = 999, x1 = -1, y0 = 999, y1 = -1
        for y in 0..<H { for x in 0..<W where R[y][x] == "H" { x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) } }
        guard x1 >= 0 else { return }
        var crown = y0
        for y in y0...y1 { let n = R[y].filter { $0 == "H" }.count; if Double(n) >= Double(x1 - x0 + 1) * 0.7 { crown = y; break } }
        let cx = (x0 + x1) / 2, cr = crown, hw = (x1 - x0 + 1) / 2
        func set(_ x: Int, _ y: Int, _ c: RGB) { if y >= 0 && y < H && x >= 0 && x < W { C[y][x] = c } }
        func box(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ col: RGB) { guard a <= c, b <= d else { return }; for y in b...d { for x in a...c { set(x, y, col) } } }
        func col(_ h: UInt32) -> RGB { RGB(hex: h) }
        func headCells(_ fn: (Int, Int, Character?) -> RGB?) {
            for y in 0..<H { for x in 0..<W where R[y][x] == "H" && C[y][x] != nil { if let c = fn(x, y, L[y][x]) { C[y][x] = c } } }
        }
        func clearEars() { for y in 0..<min(H, crown) { for x in 0..<W where R[y][x] == "H" { C[y][x] = nil; R[y][x] = nil } } }
        func hood(_ color: RGB, ears: String = "none", rim: RGB? = nil, inner: RGB? = nil, face: RGB? = nil, earColor: RGB? = nil, earInner: RGB? = nil) {
            if ears != "keep" { clearEars() }
            let rimC = rim ?? color.dk(0.72), innerC = inner ?? color.lt(40)
            headCells { x, y, l in
                if l == "f" { return face }
                if l == "e" || l == "p" { return nil }
                if l == "r" { return innerC }
                let near = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { d in
                    let yy = y + d.1, xx = x + d.0
                    return yy >= 0 && yy < H && xx >= 0 && xx < W && L[yy][xx] == "f"
                }
                return near ? rimC : color
            }
            if ears == "round" { for x in [x0 + 1, x1 - 2] { box(x, cr - 2, x + 2, cr - 1, earColor ?? color); if let ei = earInner { set(x + 1, cr - 1, ei) } } }
            if ears == "long" { for x in [cx - 3, cx + 1] { box(x, cr - 7, x + 1, cr - 1, earColor ?? color); box(x, cr - 6, x, cr - 3, earInner ?? RGB(240, 170, 190)) } }
        }
        func spikes(_ c: RGB) { for (i, x) in [cx - 3, cx - 1, cx + 1].enumerated() { box(x, cr - 2 - (i == 1 ? 1 : 0), x, cr - 1, c) } }
        let white = col(0xFFFFFF)
        switch id {
        case "crown":
            box(cx - hw + 2, cr - 1, cx + hw - 2, cr, col(0xF2C230))
            for x in [cx - hw + 2, cx, cx + hw - 2] { box(x, cr - 3, x, cr - 2, col(0xF2C230)) }
            set(cx, cr, col(0xD7262F))
        case "party":
            for i in 0..<6 { box(cx - 3 + i / 2, cr - 1 - i, cx + 3 - i / 2, cr - 1 - i, i % 2 == 1 ? col(0xFFEB3B) : col(0xF48FB1)) }
            set(cx, cr - 7, white)
        case "bow":
            let x = cx - hw + 2, c = col(0xD7262F)
            box(x - 2, cr - 2, x - 1, cr, c); box(x + 1, cr - 2, x + 2, cr, c); set(x, cr - 1, col(0x8E1B1B))
        case "tophat":
            box(cx - hw + 1, cr - 6, cx + hw - 1, cr - 1, col(0x2A2730)); box(cx - hw - 1, cr, cx + hw + 1, cr, col(0x2A2730))
            box(cx - hw + 1, cr - 2, cx + hw - 1, cr - 2, col(0xC62828))
        case "cap":
            hood(col(0xD7262F)); box(cx - hw + 1, cr - 2, cx + hw - 1, cr - 1, col(0xD7262F))
            box(cx + (dir == 1 ? 1 : -2), cr, cx + hw + (dir == 1 ? 2 : 0), cr, col(0x9E1B22)); set(cx, cr - 3, col(0xD7262F))
        case "santa":
            hood(col(0xD7262F)); box(cx - hw, cr - 1, cx + hw, cr, white); box(cx - hw + 1, cr - 3, cx + hw - 1, cr - 2, col(0xD7262F))
            box(cx - 2, cr - 4, cx + 1, cr - 4, col(0xD7262F)); box(cx + 1, cr - 5, cx + 3, cr - 3, white)
        case "witch":
            box(cx - hw - 1, cr, cx + hw + 1, cr, col(0x3B2A57))
            for i in 0..<8 { box(cx - 2 + i / 3, cr - 1 - i, cx + 2 - i / 3, cr - 1 - i, col(0x4B3470)) }
            box(cx - 2, cr - 2, cx + 2, cr - 2, col(0xF2C230))
        case "cowboy":
            box(cx - hw - 2, cr, cx + hw + 2, cr, col(0x8B5A2B)); box(cx - hw + 1, cr - 3, cx + hw - 1, cr - 1, col(0x8B5A2B))
            box(cx - hw + 1, cr - 1, cx + hw - 1, cr - 1, col(0x5B3A1B))
        case "starhelm":
            hood(col(0x2C4A9C)); box(cx - 1, cr + 1, cx + 1, cr + 1, white); set(cx, cr, white); set(cx, cr + 2, white)
        case "ironhelm": hood(col(0xC62828), rim: col(0x8E1B1B)); box(cx - hw + 1, cr + 1, cx + hw - 1, cr + 1, col(0xF2C230))
        case "shark": hood(col(0x5D7C9C)); box(cx - 1, cr - 3, cx, cr - 1, col(0x4A6683)); set(cx - 1, cr - 4, col(0x4A6683))
        case "frog":
            hood(col(0x79A85A), ears: "round", earColor: col(0x79A85A))
            set(x0 + 2, cr - 2, white); set(x1 - 1, cr - 2, white); set(x0 + 3, cr - 2, col(0x2A2730)); set(x1, cr - 2, col(0x2A2730))
        case "spider":
            headCells { _, _, l in l == "e" ? white : (l == "p" ? nil : col(0xD7262F)) }
            headCells { x, y, l in (x + y) % 4 == 0 && l != "e" ? col(0x6E1015) : nil }
        case "horns":
            hood(col(0x9AA3AD))
            for (i, x) in [x0 + 1, x1 - 2].enumerated() { box(x, cr - 3, x + 1, cr - 1, col(0xF1E7D2)); set(i == 1 ? x + 2 : x - 1, cr - 4, col(0xF1E7D2)) }
        case "winged":
            hood(col(0xD8B24A))
            for x in [x0 - 2, x1 + 1] { box(x, cr - 2, x + 1, cr - 1, white); set(x + (x < cx ? 0 : 1), cr - 3, white) }
        case "chick": hood(col(0xF6D44A)); box(cx - 1, cr - 2, cx + 1, cr - 1, col(0xF6D44A)); set(cx, cr - 3, col(0xF6D44A))
        case "jester":
            hood(col(0x2E2A33))
            for (x, d, c) in [(x0, -1, UInt32(0x9B59B6)), (x1, 1, UInt32(0xC9A227))] {
                box(x - (d > 0 ? 1 : 0), cr - 2, x + (d < 0 ? 1 : 0), cr - 1, col(c)); set(x + d * 2, cr - 3, col(0xF2C230))
            }
            set(cx, cr - 1, col(0x9B59B6))
        case "banana": hood(col(0xF6D84B)); box(cx - 2, cr - 3, cx + 2, cr - 1, col(0xF6D84B)); set(cx, cr - 4, col(0x6B4A2B)); set(cx, cr - 5, col(0x6B4A2B))
        case "dino": hood(col(0x79A85A)); spikes(col(0xF2C230))
        case "pinkdino": hood(col(0xF2A9C4)); spikes(col(0xE04A6A))
        case "panda":
            hood(col(0xF4F2EE), ears: "round", earColor: col(0x2A2A2E))
            headCells { _, y, l in abs(y - (cr + 4)) <= 1 && l == "f" ? col(0x2A2A2E) : nil }
        case "bunny": hood(col(0xF7F4F0), ears: "long", earColor: col(0xF7F4F0))
        case "bee":
            hood(col(0xF4C430))
            headCells { _, y, _ in (y - cr) % 4 == 1 ? col(0x4A3423) : nil }
            for x in [cx - 2, cx + 1] { set(x, cr - 2, col(0x4A3423)); set(x, cr - 3, col(0x4A3423)); set(x + (x < cx ? -1 : 1), cr - 4, col(0xF4C430)) }
        case "bear": hood(col(0xA7703F), ears: "round", earColor: col(0xA7703F), earInner: col(0x7B4F2A))
        case "penguin":
            hood(col(0x2D3756), face: col(0xF4F2EE))
            if dir == 1 { box(x1, cr + 5, x1 + 1, cr + 6, col(0xF0A12F)) } else { box(cx, cr + 6, cx + 1, cr + 7, col(0xF0A12F)) }
        case "merc":
            headCells { _, _, l in l == "h" || l == "r" ? col(0xC62828) : nil }
            headCells { _, y, l in l == "f" && y <= cr + 5 ? col(0xC62828) : nil }
        case "monster":
            hood(col(0x9B7FD1)); for x in [x0 + 1, x1 - 1] { box(x - 1, cr - 3, x, cr - 1, col(0x7E62B8)) }; set(cx, cr, white)
        case "ghost": hood(col(0xF6F4EE), rim: col(0xC9C6BC), face: col(0x2A2730))
        case "unicorn": hood(col(0xF7F3EE), ears: "keep"); for i in 0..<4 { set(cx, cr - 1 - i, i % 2 == 1 ? col(0xF2C230) : col(0xFFE27A)) }
        case "vampire": hood(col(0x2A2730), ears: "keep", rim: col(0x14121A), inner: col(0x6E1015))
        default: break
        }
    }

    // MARK: assembling

    private static func build(_ fkey: String, _ look: CatLook, _ eyesOpen: Bool) -> (CGrid, Family) {
        let fam = family(fkey)
        var L = fam.L, R = fam.R
        let pal = palette(look), H = L.count, W = L[0].count
        if !eyesOpen { for y in 0..<H { for x in 0..<W where L[y][x] == "e" { L[y][x] = "k" } } }
        coat(&L, look, fam)
        var C: CGrid = blank(W, H)
        for y in 0..<H {
            for x in 0..<W {
                guard let c = L[y][x] else { continue }
                C[y][x] = (c == "e" && !fam.side && x > fam.cx) ? pal["E"] : (pal[c] ?? pal["b"])
            }
        }
        if look.outfit != "none" { outfit(&C, R, L, fam, look.outfit) }
        if look.hat != "none" { hat(&C, L, &R, fam, look.hat) }
        // outline: dark, tinted by the colour it borders
        var out = C
        let kc = pal["k"]!
        func at(_ x: Int, _ y: Int) -> RGB? { y >= 0 && y < H && x >= 0 && x < W ? C[y][x] : nil }
        for y in 0..<H {
            for x in 0..<W {
                let isK = L[y][x] == "k" && C[y][x] != nil
                if C[y][x] != nil && !isK { continue }
                let nb = [at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)].compactMap { $0 }.filter { $0 != kc }
                if nb.isEmpty && !isK { continue }
                let d = (nb.first ?? pal["b"]!).dk(0.36)
                out[y][x] = RGB(max(d.r, 30), max(d.g, 28), max(d.b, 30))
            }
        }
        return (out, fam)
    }

    private static func rotate(_ g: CGrid, _ q: Int) -> CGrid {
        var o = g
        for _ in 0..<(((q % 4) + 4) % 4) {
            let H = o.count, W = o[0].count
            var n: CGrid = blank(H, W)
            for y in 0..<H { for x in 0..<W { n[W - 1 - x][y] = o[y][x] } }
            o = n
        }
        return o
    }

    struct Sprite { let img: CGImage; let ax: CGFloat; let ay: CGFloat; let w: Int; let h: Int; let box: CGRect }
    private static var cache: [String: Sprite] = [:]

    static func sprite(_ look: CatLook, _ fkey: String, rot: Int, eyesOpen: Bool) -> Sprite? {
        let sig = "\(look.baseHex)|\(look.accentHex)|\(look.pattern)|\(look.seed)|\(look.eyeHexL)|\(look.eyeHexR)|\(look.hat)|\(look.outfit)|\(fkey)|\(rot)|\(eyesOpen)"
        if let s = cache[sig] { return s }
        if cache.count > 600 { cache.removeAll() }
        let (C, fam) = build(fkey, look, eyesOpen)
        let g = rotate(C, rot), H = g.count, W = g[0].count
        var data = [UInt8](repeating: 0, count: W * H * 4)
        var bx0 = W, bx1 = -1, by0 = H, by1 = -1
        for y in 0..<H {
            for x in 0..<W {
                guard let p = g[y][x] else { continue }
                let i = (y * W + x) * 4
                data[i] = UInt8(p.r); data[i + 1] = UInt8(p.g); data[i + 2] = UInt8(p.b); data[i + 3] = 255
                bx0 = min(bx0, x); bx1 = max(bx1, x); by0 = min(by0, y); by1 = max(by1, y)
            }
        }
        guard bx1 >= 0, let provider = CGDataProvider(data: Data(data) as CFData),
              let img = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        // anchor: the middle of the feet for upright cats, the bounding box for turned ones
        let ax = rot == 0 ? CGFloat(fam.cx) : CGFloat(bx0 + bx1 + 1) / 2
        let ay = rot == 0 ? CGFloat(fam.ground + 2) : CGFloat(by1 + 1)
        let s = Sprite(img: img, ax: ax, ay: ay, w: W, h: H, box: CGRect(x: bx0, y: by0, width: bx1 - bx0 + 1, height: by1 - by0 + 1))
        cache[sig] = s
        return s
    }

    // MARK: which sprite for which pose

    struct Pick { var f: String; var rot = 0; var eyesOpen = true; var flip = false; var shake: CGFloat = 0 }

    static func pick(_ ri: RenderInfo) -> Pick {
        func q(_ a: CGFloat) -> Int { Int((a / (.pi / 2)).rounded()) }
        let t = ri.t
        let open: Bool
        switch ri.eyes { case .open, .wide, .angry: open = true; default: open = false }
        let walkK = Int(abs(ri.phase) / (.pi / 2)) % 4
        let m = t.truncatingRemainder(dividingBy: 6)
        let sitK = m > 5.8 ? 1 : (m > 3.2 && m < 3.5) ? 2 : (m > 4.4 && m < 4.6) ? 3 : 0
        let paw = Int(t * 6) % 2 == 1 ? 0 : 2
        switch ri.pose {
        case .walk: return Pick(f: "walk:\(walkK)", eyesOpen: open)
        case .run: return Pick(f: Int(abs(ri.phase) / .pi) % 2 == 1 ? "jump:0" : "jump:1", eyesOpen: open)
        case .stand, .eat: return Pick(f: "walk:1", eyesOpen: open)
        case .scratch: return Pick(f: "walk:\(paw)", eyesOpen: open)
        case .sit, .purr, .groom, .swat, .grumpy:
            return Pick(f: "sit:\(sitK)", eyesOpen: ri.pose == .groom ? open : true)
        case .loaf: return Pick(f: "loaf:\(Int(t * 1.3) % 2)")
        case .sleep: return Pick(f: "sleep:\(Int(t * 1.1) % 2)")
        case .crouch, .stalk, .wiggle:
            return Pick(f: "loaf:\(Int(t * 2) % 2)", shake: ri.pose == .wiggle ? CGFloat(sin(t * 30)) : 0)
        case .jump: return Pick(f: "jump:\(ri.progress < 0.5 ? 0 : 1)", eyesOpen: open)
        case .fall: return Pick(f: "jump:1", rot: q(ri.rotation))
        case .hiss: return Pick(f: "hiss:\(Int(t * 8) % 2)", shake: CGFloat(sin(t * 40)))
        case .climb: return Pick(f: "walk:\(walkK)", rot: 1, eyesOpen: open, flip: ri.climbSide > 0)
        case .wallScratch: return Pick(f: "walk:\(paw)", rot: 1, eyesOpen: open, flip: ri.climbSide > 0)
        case .slide: return Pick(f: "walk:1", rot: 3, flip: ri.climbSide < 0)
        case .traverse: return Pick(f: "walk:\(walkK)", rot: 2, eyesOpen: open)
        case .hangSide, .hangBack, .dangle: return Pick(f: "sit:0")
        case .roll: return Pick(f: "sit:0", rot: q(ri.rotation))
        }
    }

    static func cell(_ scale: CGFloat) -> CGFloat { max(2, (1.9 * scale).rounded()) }

    /// Draws a cat with its feet at `at` in a y-up context.
    static func draw(_ ctx: CGContext, look: CatLook, ri: RenderInfo, scale: CGFloat, at: CGPoint) {
        let p = pick(ri)
        guard let s = sprite(look, p.f, rot: p.rot, eyesOpen: p.eyesOpen) else { return }
        let cs = cell(scale)
        let flip: CGFloat = (ri.facing < 0 ? -1 : 1) * (p.flip ? -1 : 1)
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)
        ctx.translateBy(x: (at.x + p.shake * cs * 0.5).rounded(), y: at.y.rounded())
        ctx.scaleBy(x: flip, y: 1)
        ctx.draw(s.img, in: CGRect(x: -(s.ax * cs).rounded(), y: (s.ay * cs).rounded() - CGFloat(s.h) * cs,
                                   width: CGFloat(s.w) * cs, height: CGFloat(s.h) * cs))
        ctx.restoreGState()
    }

    /// The sitting cat, cropped and scaled up by whole pixels, for menus.
    static func image(_ cfg: CatConfig, size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        guard let s = sprite(CatLook(cfg), "sit:0", rot: 0, eyesOpen: true), let crop = s.img.cropping(to: s.box) else { return img }
        let k = max(1, (size * 0.92 / max(s.box.width, s.box.height)).rounded(.down))
        let w = s.box.width * k, h = s.box.height * k
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.interpolationQuality = .none
            ctx.draw(crop, in: CGRect(x: ((size - w) / 2).rounded(), y: (size * 0.03).rounded(), width: w, height: h))
        }
        img.unlockFocus()
        return img
    }
}
