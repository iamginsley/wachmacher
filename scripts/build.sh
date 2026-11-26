#!/bin/zsh
# Builds Wachmacher.app (menu bar only).
#
#   scripts/build.sh             ad-hoc signed build for this Mac  → build/Wachmacher.app
#   scripts/build.sh --install   same, then copy to /Applications and start it
#   scripts/build.sh --release   universal build, Developer ID + hardened runtime (used by release.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

# Overridable for testing the update flow with an older local build.
VERSION=${VERSION:-1.2}
BUILD=${BUILD:-3}
FEED_URL=${FEED_URL:-https://iamginsley.github.io/wachmacher/appcast.xml}
TEAM_ID=2567P974L9   # personal team, never the INNIO team

MODE="${1:-}"
APP=build/Wachmacher.app
rm -rf build/Wachmacher.app build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Compiling"
if [[ "$MODE" == "--release" ]]; then
  swift build -c release --product Wachmacher --arch arm64 --arch x86_64
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Wachmacher"
else
  swift build -c release --product Wachmacher
  BIN="$(swift build -c release --show-bin-path)/Wachmacher"
fi
cp "$BIN" "$APP/Contents/MacOS/Wachmacher"
mkdir -p "$APP/Contents/Frameworks"
ditto "$(dirname "$BIN")/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

echo "▸ App icon"
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
swift Tools/make-icon.swift build/icon_1024.png >/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Wachmacher</string>
  <key>CFBundleDisplayName</key><string>Wachmacher</string>
  <key>CFBundleIdentifier</key><string>de.gintsberger.wachmacher</string>
  <key>CFBundleExecutable</key><string>Wachmacher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Dominik Gintsberger</string>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>hih/nlF8+blaM8jgJ8fhFe5MLsR7yxTMiNB8NCzwCOU=</string>
</dict>
</plist>
PLIST

echo "▸ Signing"
if [[ "$MODE" == "--release" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "($TEAM_ID)" \
    | head -1 | sed -E 's/.*"(.*)"/\1/')
  [[ -n "$IDENTITY" ]] || { echo "✗ No Developer ID Application certificate for team $TEAM_ID"; exit 1; }
  SIGN=(codesign --force --options runtime --timestamp --sign "$IDENTITY")
else
  SIGN=(codesign --force --sign -)
fi
# Sparkle must be signed inside out: XPC services, helpers, framework, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Updater.app"
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$APP"
echo "✓ $APP ($VERSION, build $BUILD)"

if [[ "$MODE" == "--install" ]]; then
  pkill -x Wachmacher || true
  rm -rf /Applications/Wachmacher.app
  cp -R "$APP" /Applications/
  open /Applications/Wachmacher.app
  echo "✓ Installed and started /Applications/Wachmacher.app"
fi
