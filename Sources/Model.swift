import AppKit
import SwiftUI

// MARK: - Colors

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    func darker(_ f: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.sRGB) else { return self }
        return NSColor(srgbRed: c.redComponent * f, green: c.greenComponent * f, blue: c.blueComponent * f, alpha: 1)
    }
}

// MARK: - Coats

enum CoatPattern: String, Codable {
    case solid, tabby, bicolor, tabbyBicolor, calico, tortie, colorpoint
}

struct CoatPreset: Identifiable {
    let id: String
    let name: String
    let base: UInt32
    let accent: UInt32      // stripes / patches / points
    let pattern: CoatPattern
    let eyes: EyeColor
}

let coatPresets: [CoatPreset] = [
    .init(id: "grayWhite",  name: "Gray and white",      base: 0x8E949C, accent: 0x5F656D, pattern: .bicolor,      eyes: .green),
    .init(id: "ginger",     name: "Ginger",           base: 0xEC9440, accent: 0xC4661C, pattern: .tabby,        eyes: .amber),
    .init(id: "black",      name: "Black",          base: 0x2B2A2F, accent: 0x1A1A1D, pattern: .solid,        eyes: .yellow),
    .init(id: "white",      name: "White",           base: 0xF6F5F1, accent: 0xE4E2DC, pattern: .solid,        eyes: .blue),
    .init(id: "blue",       name: "Blue",         base: 0x8693A6, accent: 0x6D7A8C, pattern: .solid,        eyes: .copper),
    .init(id: "gingerWhite",name: "Ginger and white",      base: 0xEC9440, accent: 0xC4661C, pattern: .tabbyBicolor, eyes: .green),
    .init(id: "tuxedo",     name: "Tuxedo",         base: 0x2B2A2F, accent: 0x1A1A1D, pattern: .bicolor,      eyes: .green),
    .init(id: "calico",     name: "Calico",     base: 0xF6F3EC, accent: 0xE4893A, pattern: .calico,       eyes: .amber),
    .init(id: "tortie",     name: "Tortoiseshell",     base: 0x3B2F2A, accent: 0xC9732E, pattern: .tortie,       eyes: .amber),
    .init(id: "grayTabby",  name: "Gray tabby", base: 0xA2A29C, accent: 0x55554F, pattern: .tabby,        eyes: .green),
    .init(id: "brownTabby", name: "Brown tabby", base: 0xA97C52, accent: 0x4E3524, pattern: .tabby,        eyes: .yellow),
    .init(id: "cream",      name: "Cream",        base: 0xF2DCB5, accent: 0xDDB47E, pattern: .tabby,        eyes: .copper),
    .init(id: "siamese",    name: "Siamese",        base: 0xF1E8D8, accent: 0x5A4636, pattern: .colorpoint,   eyes: .blue),
    .init(id: "chocolate",  name: "Chocolate",      base: 0x6E4632, accent: 0x52321F, pattern: .solid,        eyes: .yellow),
    .init(id: "smoky",      name: "Smoky",        base: 0x5F6168, accent: 0x45474D, pattern: .solid,        eyes: .yellow),
    .init(id: "silver",     name: "Silver",     base: 0xCDD1D4, accent: 0x6B7176, pattern: .tabby,        eyes: .green),
    .init(id: "peach",      name: "Peach",      base: 0xF5C08E, accent: 0xE09A5B, pattern: .tabbyBicolor, eyes: .amber),
    .init(id: "grayBlack",  name: "Black and white", base: 0xF4F2EE, accent: 0x2B2A2F, pattern: .calico,     eyes: .yellow),
]

func preset(_ id: String) -> CoatPreset { coatPresets.first { $0.id == id } ?? coatPresets[0] }

enum EyeColor: String, Codable, CaseIterable, Identifiable {
    case green, yellow, amber, blue, copper, odd
    var id: String { rawValue }
    var name: String {
        switch self {
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .amber: return "Amber"
        case .blue: return "Blue"
        case .copper: return "Copper"
        case .odd: return "Odd eyes"
        }
    }
    var colors: (NSColor, NSColor) {
        switch self {
        case .green: return (NSColor(hex: 0x7BC24A), NSColor(hex: 0x7BC24A))
        case .yellow: return (NSColor(hex: 0xEACB45), NSColor(hex: 0xEACB45))
        case .amber: return (NSColor(hex: 0xE39A2C), NSColor(hex: 0xE39A2C))
        case .blue: return (NSColor(hex: 0x62AEEA), NSColor(hex: 0x62AEEA))
        case .copper: return (NSColor(hex: 0xC8732E), NSColor(hex: 0xC8732E))
        case .odd: return (NSColor(hex: 0x62AEEA), NSColor(hex: 0xEACB45))
        }
    }
}

// MARK: - Cat config (persisted)

struct CatConfig: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var coat: String
    var eyes: EyeColor
    var size: Double = 1.2
    var visible: Bool = true
    var seed: UInt32 = UInt32.random(in: 1...UInt32.max)
    var hat: String? = nil      // optional so older saved cats still load
    var outfit: String? = nil
}

let catNames = ["Whiskers", "Misty", "Fluffy", "Ginger", "Smokey", "Simba", "Luna", "Hush", "Muffin", "Mochi",
                "Bun", "Fenya", "Sleepy", "Bagel", "Peach", "Ember", "Snowball", "Marquis", "Nightie", "Pumpkin"]

struct CatStats: Equatable {
    var food: Double = 0.8
    var water: Double = 0.8
    var energy: Double = 0.8
    var fun: Double = 0.7
    var mood: String = "Roaming"
}

enum BowlKind: String { case food, water }

// MARK: - App state shared by UI and the world

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var cats: [CatConfig] = [] { didSet { if cats != oldValue { save(); onCatsChanged?() } } }
    @Published var running = true { didSet { if running != oldValue { onRunningChanged?() } } }
    @Published var laser = false
    @Published var placing: BowlKind? = nil
    @Published var stats: [UUID: CatStats] = [:]
    @Published var bowlCount = 0

    var onCatsChanged: (() -> Void)?
    var onRunningChanged: (() -> Void)?
    var onBowlAction: ((String) -> Void)?

    private let key = "deskcats.cats.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([CatConfig].self, from: data), !saved.isEmpty {
            cats = saved
        } else {
            cats = [CatConfig(name: "Whiskers", coat: "grayWhite", eyes: .green)]
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(cats) { UserDefaults.standard.set(data, forKey: key) }
    }

    func randomCat() -> CatConfig {
        let p = coatPresets.randomElement()!
        let used = Set(cats.map(\.name))
        let name = catNames.first { !used.contains($0) } ?? "Cat \(cats.count + 1)"
        return CatConfig(name: name, coat: p.id, eyes: p.eyes, size: Double.random(in: 1.0...1.35))
    }
}
