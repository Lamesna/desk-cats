#!/bin/zsh
# Builds Kotiki.app next to this script
set -e
cd "$(dirname "$0")"
APP="build/Kotiki.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# universal build: Apple Silicon + Intel
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $ARCH-apple-macos13.0 \
    -o "build/DeskCats-$ARCH" Sources/*.swift \
    -framework AppKit -framework SwiftUI
done
lipo -create build/DeskCats-arm64 build/DeskCats-x86_64 -output "$APP/Contents/MacOS/DeskCats"
rm -f build/DeskCats-arm64 build/DeskCats-x86_64
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Kotiki</string>
  <key>CFBundleDisplayName</key><string>Kotiki</string>
  <key>CFBundleIdentifier</key><string>local.deskcats</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>DeskCats</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.7</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string><string>zh-Hans</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Kotiki asks Finder where your desktop icons are, so the cats can walk on them.</string>
</dict></plist>
EOF
mkdir -p "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# system dialogs (the Finder permission prompt) follow the macOS language
for L in en ru zh-Hans; do mkdir -p "$APP/Contents/Resources/$L.lproj"; done
printf '%s\n' '"NSAppleEventsUsageDescription" = "Kotiki asks Finder where your desktop icons are, so the cats can walk on them.";' \
  > "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
printf '%s\n' '"NSAppleEventsUsageDescription" = "Kotiki узнаёт у Finder, где лежат иконки на рабочем столе, чтобы коты могли по ним ходить.";' \
  > "$APP/Contents/Resources/ru.lproj/InfoPlist.strings"
printf '%s\n' '"NSAppleEventsUsageDescription" = "Kotiki 会询问 Finder 桌面图标的位置，这样小猫就能在图标上行走。";' \
  > "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
codesign --force -s - "$APP" >/dev/null 2>&1 || true
echo "Done: $APP"
