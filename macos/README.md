# Kotiki for macOS

The native macOS version of Kotiki. See the [main README](../README.md) for what the cats do. Everything lives in the menu bar.

Requires macOS 13 or newer. Runs on Apple Silicon and Intel Macs. Download the ready app from the [latest release](https://github.com/MiLana-ec/desk-cats/releases/latest).

## Build from source

You need the Xcode command line tools (`xcode-select --install`).

```bash
cd macos
./build.sh
open build/Kotiki.app
```

`build.sh` produces a universal app for Apple Silicon and Intel. It is signed locally, without an Apple certificate. If macOS refuses to open it, right-click the app and choose Open.

## Permissions

- The app sees windows, widgets and the cursor without extra permissions.
- To let cats walk on your desktop icons, the app asks Finder where they are. macOS shows a one-time prompt: "Kotiki wants to control Finder". If you decline, the icons just stop being platforms.

## Controls

Hold Option and drag to pick up a cat or a bowl. The switch in the menu hides every cat; Quit closes the app.

## How it is built

Swift (AppKit and SwiftUI), no third-party libraries. The cats are drawn in code, with no image assets.

| File | What is inside |
|---|---|
| `Sources/CatRenderer.swift` | Cat drawing, poses, eyes, masks |
| `Sources/Costumes.swift` | Hood hats and costumes |
| `Sources/World.swift` | Windows as platforms, physics, cat behavior |
| `Sources/Hunt.swift` | Stalking, screen edges, sliding down, widgets and icons |
| `Sources/Play.swift` | Cat play, hanging from the cursor |
| `Sources/Overlay.swift` | Transparent window over the screen |
| `Sources/MenuUI.swift` | Menu bar interface |
| `Sources/Model.swift` | Coats, cat settings, saving |
| `Sources/Localization.swift` | English, Russian and Chinese text |
