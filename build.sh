#!/bin/zsh
# Builds Wachmacher.app (menu bar only) and optionally installs it to /Applications.
# Usage: ./build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Wachmacher.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
swift Tools/make-icon.swift build/icon_1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 6 -parse-as-library \
  -target arm64-apple-macos14 \
  Sources/*.swift -o "$APP/Contents/MacOS/Wachmacher"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Wachmacher</string>
  <key>CFBundleDisplayName</key><string>Wachmacher</string>
  <key>CFBundleIdentifier</key><string>de.gintsberger.wachmacher</string>
  <key>CFBundleExecutable</key><string>Wachmacher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Wachmacher || true
  rm -rf /Applications/Wachmacher.app
  cp -R "$APP" /Applications/
  open /Applications/Wachmacher.app
  echo "Installed and started /Applications/Wachmacher.app"
fi
