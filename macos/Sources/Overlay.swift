import AppKit

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Overlay {
    enum MouseKind { case down, dragged, up, rightDown }

    let window: OverlayWindow
    let root = RootView()
    let ghost = BowlView()
    let laser = LaserView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    var onMouse: ((MouseKind, CGPoint) -> Void)?

    init() {
        let frame = NSScreen.screens.first?.frame ?? .zero
        window = OverlayWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // above the menu bar, so cats can sit on widgets right under it (clicks still pass through)
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        root.frame = CGRect(origin: .zero, size: frame.size)
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        window.contentView = root
        ghost.frame = CGRect(x: 0, y: 0, width: 46, height: 30)
        ghost.alphaValue = 0.6
        ghost.isHidden = true
        laser.isHidden = true
        root.addSubview(ghost)
        root.addSubview(laser)
        root.onMouse = { [weak self] k, e in
            guard let self else { return }
            let p = self.window.convertPoint(toScreen: e.locationInWindow)
            self.onMouse?(k, p)
        }
    }
}

final class RootView: NSView {
    var onMouse: ((Overlay.MouseKind, NSEvent) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) { onMouse?(.down, e) }
    override func mouseDragged(with e: NSEvent) { onMouse?(.dragged, e) }
    override func mouseUp(with e: NSEvent) { onMouse?(.up, e) }
    override func rightMouseDown(with e: NSEvent) { onMouse?(.rightDown, e) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let v = super.hitTest(point)
        return v == nil ? nil : self
    }
}

// MARK: - Cat view

final class CatView: NSView {
    var look: CatLook?
    var info = RenderInfo()
    var scale: CGFloat = 1
    var bubble: String?
    var bubbleAlert = false
    var hearts: [(CGFloat, CGFloat)] = []
    var sleeping = false
    var dust = false
    var now = 0.0

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let look else { return }
        let s = scale
        let anchor = CGPoint(x: 75 * s, y: 45 * s)
        PixelCats.draw(ctx, look: look, ri: info, scale: s, at: anchor)

        let headTop: CGFloat
        switch info.pose {
        case .sleep, .loaf, .crouch, .eat: headTop = 30
        case .climb: headTop = 52
        case .dangle: headTop = 58
        default: headTop = 46
        }

        // zzz
        if sleeping {
            for i in 0..<3 {
                let ph = (now * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = anchor.x + (14 + CGFloat(ph) * 16) * s * info.facing
                let y = anchor.y + (26 + CGFloat(ph) * 30) * s
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: (8 + CGFloat(ph) * 6) * s, weight: .bold),
                    .foregroundColor: NSColor(hex: 0x6E7DB8, alpha: 1 - CGFloat(ph)),
                ]
                ("z" as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            }
        }

        // hearts
        for (age, dx) in hearts {
            let a = max(0, 1 - age / 1.6)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12 * s, weight: .bold),
                .foregroundColor: NSColor(hex: 0xF0527A, alpha: a),
            ]
            ("♥" as NSString).draw(at: CGPoint(x: anchor.x + dx * s - 5 * s, y: anchor.y + (headTop - 4 + age * 26) * s), withAttributes: attrs)
        }

        // speech bubble
        if let text = bubble {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(10, 10.5 * s), weight: .bold),
                .foregroundColor: bubbleAlert ? NSColor(hex: 0xD93A3A) : NSColor(hex: 0x34302E),
            ]
            let str = text as NSString
            let sz = str.size(withAttributes: attrs)
            let w = sz.width + 12, h = sz.height + 6
            var x = anchor.x - w / 2 + 6 * s * info.facing
            x = min(max(2, x), bounds.width - w - 2)
            let y = anchor.y + (headTop + 6) * s
            let r = CGRect(x: x, y: y, width: w, height: h)
            let path = NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2)
            let tail = NSBezierPath()
            tail.move(to: CGPoint(x: anchor.x - 3, y: y + 1))
            tail.line(to: CGPoint(x: anchor.x + 1, y: y - 5))
            tail.line(to: CGPoint(x: anchor.x + 5, y: y + 1))
            NSColor.white.withAlphaComponent(0.96).setFill()
            NSColor(hex: 0x34302E, alpha: 0.7).setStroke()
            path.lineWidth = 1.2
            path.fill(); path.stroke()
            tail.fill()
            str.draw(at: CGPoint(x: x + 6, y: y + 3), withAttributes: attrs)
        }
    }
}

// MARK: - Bowl view

final class BowlView: NSView {
    var kind: BowlKind = .food { didSet { needsDisplay = true } }
    var amount: Double = 1

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let bowlColor = kind == .food ? NSColor(hex: 0xE2604F) : NSColor(hex: 0x4D8FDB)
        // shadow
        NSColor(white: 0, alpha: 0.15).setFill()
        NSBezierPath(ovalIn: CGRect(x: 4, y: 1, width: w - 8, height: 5)).fill()
        // contents
        let top = CGRect(x: 6, y: 12, width: w - 12, height: 8)
        if amount > 0.01 {
            if kind == .food {
                let n = Int(ceil(amount * 9))
                let pts: [(CGFloat, CGFloat)] = [(12, 16), (18, 18), (24, 17), (30, 18), (35, 16), (15, 19), (21, 20), (27, 20), (32, 19)]
                for (i, p) in pts.prefix(n).enumerated() {
                    NSColor(hex: i % 2 == 0 ? 0x9B5E34 : 0xB9773F).setFill()
                    NSBezierPath(ovalIn: CGRect(x: p.0 - 3, y: p.1 - 2 + CGFloat(amount) * 2, width: 6, height: 4.5)).fill()
                }
            } else {
                NSColor(hex: 0x8CCBF5, alpha: 0.95).setFill()
                let h = 3 + CGFloat(amount) * 4
                NSBezierPath(ovalIn: CGRect(x: top.minX + 1, y: 14 + CGFloat(amount) * 2, width: top.width - 2, height: h)).fill()
            }
        } else {
            NSColor(hex: 0x6B3A2E, alpha: 0.35).setFill()
            NSBezierPath(ovalIn: top.insetBy(dx: 2, dy: 1)).fill()
        }
        // bowl body
        let body = NSBezierPath()
        body.move(to: CGPoint(x: 4, y: 16))
        body.line(to: CGPoint(x: w - 4, y: 16))
        body.curve(to: CGPoint(x: w - 10, y: 3), controlPoint1: CGPoint(x: w - 5, y: 9), controlPoint2: CGPoint(x: w - 7, y: 4))
        body.line(to: CGPoint(x: 10, y: 3))
        body.curve(to: CGPoint(x: 4, y: 16), controlPoint1: CGPoint(x: 7, y: 4), controlPoint2: CGPoint(x: 5, y: 9))
        body.close()
        bowlColor.setFill()
        body.fill()
        NSColor(hex: 0x34302E, alpha: 0.8).setStroke()
        body.lineWidth = 1.4
        body.stroke()
        // rim
        let rim = NSBezierPath(ovalIn: CGRect(x: 3, y: 13.5, width: w - 6, height: 5))
        rim.lineWidth = 1.4
        bowlColor.darker(1.15).setFill()
        rim.stroke()
        // paw print
        NSColor.white.withAlphaComponent(0.85).setFill()
        let cx = w / 2, cy: CGFloat = 8
        NSBezierPath(ovalIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 4)).fill()
        for dx in [-3.2, -1.1, 1.1, 3.2] as [CGFloat] {
            NSBezierPath(ovalIn: CGRect(x: cx + dx - 1, y: cy + 1.8 - abs(dx) * 0.25, width: 2, height: 2)).fill()
        }
    }
}

// MARK: - Laser dot

final class LaserView: NSView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let pulse = 1 + 0.15 * sin(CGFloat(CACurrentMediaTime()) * 12)
        for (r, a) in [(13.0, 0.12), (8.0, 0.25), (4.5, 0.9)] as [(CGFloat, CGFloat)] {
            NSColor(srgbRed: 1, green: 0.1, blue: 0.1, alpha: a).setFill()
            let rr = r * pulse
            NSBezierPath(ovalIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)).fill()
        }
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: CGRect(x: c.x - 1.5, y: c.y - 0.5, width: 2.5, height: 2.5)).fill()
    }
}
