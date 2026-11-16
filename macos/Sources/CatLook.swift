import AppKit

// What a cat looks like and what it is doing, shared by the world and the pixel renderer (Pixel.swift).

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
