#!/bin/bash
# Builds dist/Kotiki-<version>-Windows-x64.zip from this folder. Works on macOS or Linux (and Git Bash on Windows).
# Needs: node/npm (for `npm install`), curl, unzip, zip, and a shasum or sha256sum tool.
set -euo pipefail
cd "$(dirname "$0")/.."

ELECTRON_VERSION="$(node -p "require('./node_modules/electron/package.json').version")"
VERSION="$(node -p "require('./package.json').version")"
OUT="dist/Kotiki-win32-x64"
CACHE="${KOTIKI_CACHE:-$HOME/.cache/kotiki}"
ZIP="electron-v${ELECTRON_VERSION}-win32-x64.zip"
BASE="https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}"

# 1. the official Electron build for Windows, checked against its published checksum
mkdir -p "$CACHE"
if [ ! -f "$CACHE/$ZIP" ]; then
  echo "Downloading Electron $ELECTRON_VERSION for Windows..."
  curl -fsSL -o "$CACHE/$ZIP" "$BASE/$ZIP"
fi
curl -fsSL -o "$CACHE/SHASUMS256-$ELECTRON_VERSION.txt" "$BASE/SHASUMS256.txt"
WANT="$(grep " \*\?$ZIP\$" "$CACHE/SHASUMS256-$ELECTRON_VERSION.txt" | awk '{print $1}')"
if command -v sha256sum >/dev/null; then HAVE="$(sha256sum "$CACHE/$ZIP" | awk '{print $1}')"; else HAVE="$(shasum -a 256 "$CACHE/$ZIP" | awk '{print $1}')"; fi
[ -n "$WANT" ] && [ "$WANT" = "$HAVE" ] || { echo "Checksum mismatch for $ZIP"; exit 1; }
echo "Electron checksum OK"

# 2. lay out the app next to the Electron runtime
rm -rf "$OUT"
mkdir -p "$OUT"
unzip -q "$CACHE/$ZIP" -d "$OUT"
mv "$OUT/electron.exe" "$OUT/Kotiki.exe"
rm -f "$OUT/resources/default_app.asar"
# keep only the languages the app speaks
find "$OUT/locales" -name '*.pak' ! -name 'en-US.pak' ! -name 'ru.pak' ! -name 'zh-CN.pak' -delete

APP="$OUT/resources/app"
mkdir -p "$APP/node_modules"
cp main.js preload.js winlist.js overlay.html overlay.js menu.html menu.js package.json "$APP/"
cp -R src assets "$APP/"
# koffi: only the Windows x64 build is needed
mkdir -p "$APP/node_modules/koffi"
for f in index.js indirect.js package.json LICENSE.txt lib; do cp -R "node_modules/koffi/$f" "$APP/node_modules/koffi/"; done
mkdir -p "$APP/node_modules/koffi/build/koffi"
cp -R node_modules/koffi/build/koffi/win32_x64 "$APP/node_modules/koffi/build/koffi/"

cp LICENSE "$OUT/LICENSE-Kotiki.txt" 2>/dev/null || cp ../LICENSE "$OUT/LICENSE-Kotiki.txt"
cat > "$OUT/README.txt" <<EOF
Kotiki ${VERSION} (beta) for Windows

1. Unzip this folder anywhere (Documents or Desktop is fine).
2. Double-click Kotiki.exe. A cat icon appears in the notification area at the right of the taskbar;
   if you do not see it, click the little arrow (^) and drag the icon out.
3. Click the icon to open the menu: add cats, dress them, put bowls, turn on the laser pointer, pick a language.

Windows may show "Windows protected your PC" because the app is not signed. Click "More info", then "Run anyway".
Hold Ctrl and drag to pick up a cat or a bowl. Quit from the menu to remove all cats.
EOF

# 3. zip it
ARCHIVE="Kotiki-${VERSION}-Windows-x64.zip"
rm -f dist/Kotiki-*-Windows-x64.zip
(cd dist && zip -q -r -X "$ARCHIVE" "Kotiki-win32-x64")
ls -lh "dist/$ARCHIVE" | awk '{print "built:", $9, $5}'
