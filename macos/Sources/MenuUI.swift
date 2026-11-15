import SwiftUI
import AppKit

struct CatThumb: View {
    let cfg: CatConfig
    var size: CGFloat = 44
    var body: some View {
        Image(nsImage: CatRenderer.image(cfg, size: size * 2))
            .resizable()
            .frame(width: size, height: size)
    }
}

struct StatBar: View {
    let icon: String
    let value: Double
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 9))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(value < 0.3 ? Color.red.opacity(0.8) : color)
                        .frame(width: max(3, g.size.width * value))
                }
            }
            .frame(height: 5)
        }
    }
}

struct MenuView: View {
    @ObservedObject var state = AppState.shared
    @State private var editing: UUID?
    var close: () -> Void

    /// Popover must fit under the menu bar on any screen.
    static var height: CGFloat {
        min(640, (NSScreen.screens.first?.visibleFrame.height ?? 800) - 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let id = editing, let idx = state.cats.firstIndex(where: { $0.id == id }) {
                    CatEditor(cat: $state.cats[idx], done: { editing = nil }, remove: {
                        state.cats.remove(at: idx)
                        editing = nil
                    })
                } else {
                    main
                }
            }
            .padding(16)
        }
        .frame(width: 360, height: Self.height)
    }

    var main: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kotiki").font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Toggle("", isOn: $state.running).toggleStyle(.switch).labelsHidden()
            }
            Text(state.running ? tr("Cats are roaming your screen") : tr("All cats are hidden. Switch on to bring them back."))
                .font(.caption).foregroundStyle(.secondary)

            if state.running {
                VStack(spacing: 6) {
                    ForEach($state.cats) { $cat in
                        catRow($cat)
                    }
                }

                Button {
                    let c = state.randomCat()
                    state.cats.append(c)
                    editing = c.id
                } label: {
                    Label(tr("Add a cat"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: NSColor(hex: 0xE8913A)))

                Divider()

                Toggle(isOn: $state.laser) {
                    Label(tr("Laser pointer instead of cursor"), systemImage: "light.max")
                }
                .toggleStyle(.switch)

                Text(tr("Care")).font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    careButton(tr("Food bowl"), "fork.knife") { state.placing = .food; close() }
                    careButton(tr("Water bowl"), "drop.fill") { state.placing = .water; close() }
                    careButton(tr("Refill food"), "arrow.clockwise") { state.onBowlAction?("refillFood") }
                    careButton(tr("Refill water"), "arrow.clockwise") { state.onBowlAction?("refillWater") }
                    careButton(tr("Feed everyone"), "heart.fill") { state.onBowlAction?("feedAll") }
                    careButton(tr("Remove bowls"), "trash") { state.onBowlAction?("clear") }
                }
                if state.placing != nil {
                    Text(tr("Click anywhere on the screen to place the bowl. Right-click to cancel."))
                        .font(.caption).foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("• Hold the cursor over a cat and it purrs"))
                    Text(tr("• ⌥ Option + drag: pick up a cat or a bowl"))
                    Text(tr("• Close a window and the cat on it tumbles down"))
                }
                .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Picker(tr("Language"), selection: $state.lang) {
                    ForEach(Lang.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                Spacer()
            }
            Button(role: .destructive) { NSApp.terminate(nil) } label: {
                Label(tr("Quit (remove all cats)"), systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
    }

    func careButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    func catRow(_ cat: Binding<CatConfig>) -> some View {
        let c = cat.wrappedValue
        let st = state.stats[c.id] ?? CatStats()
        return HStack(spacing: 10) {
            CatThumb(cfg: c).opacity(c.visible ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(c.name).font(.system(size: 13, weight: .semibold))
                    Text(c.visible ? tr(st.mood) : tr("Hidden")).font(.caption2).foregroundStyle(.secondary)
                }
                if c.visible {
                    HStack(spacing: 6) {
                        StatBar(icon: "🍗", value: st.food, color: .orange)
                        StatBar(icon: "💧", value: st.water, color: .blue)
                    }
                    HStack(spacing: 6) {
                        StatBar(icon: "⚡", value: st.energy, color: .yellow)
                        StatBar(icon: "❤️", value: st.fun, color: .pink)
                    }
                }
            }
            Spacer(minLength: 4)
            Button { cat.wrappedValue.visible.toggle() } label: {
                Image(systemName: c.visible ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .help(c.visible ? tr("Hide") : tr("Show"))
            Button { editing = c.id } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .help(tr("Customize"))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}

struct CatEditor: View {
    @Binding var cat: CatConfig
    var done: () -> Void
    var remove: () -> Void

    /// A tile showing this cat with one option applied.
    func tile(with change: (inout CatConfig) -> Void, name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        var preview = cat
        change(&preview)
        return Button(action: action) {
            VStack(spacing: 2) {
                CatThumb(cfg: preview, size: 54)
                Text(name).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.orange : Color.clear, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04))))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { done() } label: { Label(tr("Back"), systemImage: "chevron.left") }.buttonStyle(.borderless)
                Spacer()
            }
            HStack(spacing: 14) {
                CatThumb(cfg: cat, size: 90)
                VStack(alignment: .leading, spacing: 6) {
                    TextField(tr("Name"), text: $cat.name).textFieldStyle(.roundedBorder)
                    Text(tr(preset(cat.coat).name)).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(tr("Size")).font(.caption)
                        Slider(value: $cat.size, in: 0.7...2.0)
                    }
                }
            }

            Text(tr("Coat")).font(.headline)
            do {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(coatPresets) { p in
                        var preview = cat
                        let _ = { preview.coat = p.id }()
                        Button {
                            cat.coat = p.id
                        } label: {
                            VStack(spacing: 2) {
                                CatThumb(cfg: preview, size: 46)
                                Text(tr(p.name)).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .stroke(cat.coat == p.id ? Color.orange : Color.clear, lineWidth: 2)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04))))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(tr("Eyes")).font(.headline)
            HStack(spacing: 8) {
                ForEach(EyeColor.allCases) { e in
                    Button { cat.eyes = e } label: {
                        HStack(spacing: 1) {
                            Circle().fill(Color(nsColor: e.colors.0)).frame(width: 12, height: 12)
                            Circle().fill(Color(nsColor: e.colors.1)).frame(width: 12, height: 12)
                        }
                        .padding(5)
                        .background(Capsule().stroke(cat.eyes == e ? Color.orange : Color.secondary.opacity(0.3), lineWidth: cat.eyes == e ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(tr(e.name))
                }
            }

            Text(tr("Hat")).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(hatOptions, id: \.id) { o in
                    tile(with: { $0.hat = o.id }, name: tr(o.name), selected: (cat.hat ?? "none") == o.id) { cat.hat = o.id }
                }
            }

            Text(tr("Costume")).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(outfitOptions, id: \.id) { o in
                    tile(with: { $0.outfit = o.id }, name: tr(o.name), selected: (cat.outfit ?? "none") == o.id) { cat.outfit = o.id }
                }
            }

            HStack {
                Button(role: .destructive) { remove() } label: { Label(tr("Delete cat"), systemImage: "trash") }
                Spacer()
                Button(tr("Done")) { done() }.buttonStyle(.borderedProminent).tint(.orange)
            }
        }
    }
}
