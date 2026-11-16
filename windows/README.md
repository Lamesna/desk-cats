# Kotiki for Windows (beta)

The Windows version of Kotiki, a separate port of the macOS app built with Electron. See the [main README](../README.md) for what the cats do. Requires Windows 10 or 11, 64-bit.

Download `Kotiki-0.2.0-Windows-x64.zip` from the [Windows release](https://github.com/MiLana-ec/desk-cats/releases/tag/windows-v0.2.0), unzip it and run `Kotiki.exe`.

## Pixel cats

The menu has a "Pixel cats" switch. It turns every cat, coat, hat and costume into pixel art (one look or the other, never both). The pixel cat is drawn from a hand-made sprite plus recolors, so all 18 coats, 31 hats and 25 costumes work. Poses are shared between sprites: sitting, walking, running, jumping, sleeping, hissing, and climbing (the side view turned upright).

## Good to know

- This is a beta. It was developed and checked on a Mac; the Windows-specific parts (window detection, click-through, tray icon) have not been tested on many real Windows machines yet. Bug reports are welcome.
- Cats walk on the taskbar and on open windows. Desktop icons and widgets are not platforms on Windows.
- Hold **Ctrl** and drag to pick up a cat or a bowl.
- The app is not signed, so SmartScreen may say "Windows protected your PC". Click "More info", then "Run anyway".
- The cat icon lives in the notification area. On Windows 11 it may be tucked under the ^ arrow; drag it out to keep it visible.
- Your cats are saved in `%APPDATA%\kotiki\kotiki.json`.

## Run from source

You need Node.js 20 or newer.

```bash
cd windows
npm install
npm start
```

`npm test` runs a headless simulation of the cats (stairs between windows, visible edges only, falls and grabs, a long run).

## Build the zip

```bash
cd windows
npm install
npm run pack:win
```

This downloads the official Electron build for Windows, checks its SHA-256 checksum and writes `dist/Kotiki-<version>-Windows-x64.zip`. It works on macOS, Linux and Git Bash.

## How it is built

| File | What is inside |
|---|---|
| `main.js` | Tray icon, menu window, overlay window, saved settings |
| `winlist.js` | Lists open windows through the Win32 API (koffi) |
| `overlay.js`, `menu.js` | The transparent cat canvas and the menu |
| `src/render-*.js`, `src/costumes.js`, `src/hoods.js` | Cat drawing, coats, hats and costumes |
| `src/pixel.js` | Pixel renderer: sprites, coats, hats, costumes |
| `src/world*.js` | Platforms, physics and cat behavior |
| `src/loc.js` | English, Russian and Chinese text |
| `test/sim.js` | Headless behavior tests |
