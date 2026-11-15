import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var world: World!

    func applicationDidFinishLaunching(_ n: Notification) {
        world = World()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Kotiki")
            b.action = #selector(toggle)
            b.target = self
        }
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: MenuView(close: { [weak self] in
            self?.popover.performClose(nil)
        }))
        // Fixed size: otherwise the popover grows to the full content height and runs off the screen.
        host.sizingOptions = []
        let size = NSSize(width: 360, height: MenuView.height)
        host.view.frame = NSRect(origin: .zero, size: size)
        host.preferredContentSize = size
        popover.contentViewController = host
        popover.contentSize = size
    }

    @objc func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let b = statusItem.button {
            popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
