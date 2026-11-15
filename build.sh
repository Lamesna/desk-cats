#!/bin/zsh
# Собирает Котики.app рядом со скриптом
set -e
cd "$(dirname "$0")"
APP="build/Котики.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/DeskCats" Sources/*.swift \
  -framework AppKit -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Котики</string>
  <key>CFBundleDisplayName</key><string>Котики</string>
  <key>CFBundleIdentifier</key><string>local.deskcats</string>
  <key>CFBundleExecutable</key><string>DeskCats</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Котики узнают у Finder, где лежат иконки на рабочем столе, чтобы ходить по ним.</string>
</dict></plist>
EOF
codesign --force -s - "$APP" >/dev/null 2>&1 || true
echo "Готово: $APP"
