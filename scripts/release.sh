#!/bin/zsh
# Builds a Developer ID signed, notarized DMG of Wachmacher.
#
#   scripts/release.sh                  tests, universal build, DMG, notarize, staple
#   scripts/release.sh --skip-notarize  same without notarization (local testing only)
#
# One-time setup (Developer ID certificate, notarytool keychain profile): docs/release.md.
set -euo pipefail
cd "$(dirname "$0")/.."

# Credentials are per team, so the Smoll Notch profile works as well.
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_PROFILE=wachmacher
  security find-generic-password -s "com.apple.gke.notary.tool" -a "com.apple.gke.notary.tool.saved-creds.wachmacher" \
    >/dev/null 2>&1 || NOTARY_PROFILE=smoll-notch
fi
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
SKIP_NOTARIZE=false
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=true

OUT=build/release
rm -rf $OUT && mkdir -p $OUT

echo "▸ Running tests"
swift test --quiet

scripts/build.sh --release
APP=build/Wachmacher.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
DMG=$OUT/Wachmacher-$VERSION.dmg
NOTES=docs/changelog/$VERSION.md
[[ -f $NOTES ]] || { echo "✗ Missing release notes: $NOTES"; exit 1; }

echo "▸ Verifying signature"
codesign --verify --deep --strict --verbose=1 "$APP"
SIGNATURE=$(codesign -dvv "$APP" 2>&1)
[[ "$SIGNATURE" == *"Authority=Developer ID Application"* && "$SIGNATURE" == *"TeamIdentifier=2567P974L9"* ]] \
  || { echo "✗ App is not signed with Developer ID of team 2567P974L9"; exit 1; }
[[ "$(lipo -archs "$APP/Contents/MacOS/Wachmacher")" == *x86_64*arm64* ]] \
  || { echo "✗ Binary is not universal"; exit 1; }

echo "▸ Building DMG"
STAGING=$OUT/dmg
mkdir -p $STAGING && cp -R "$APP" $STAGING/ && ln -s /Applications $STAGING/Programme
hdiutil create -volname "Wachmacher" -srcfolder $STAGING -fs HFS+ -format UDZO -ov $DMG -quiet
IDENTITY=$(print -r -- "$SIGNATURE" | sed -n 's/^Authority=\(Developer ID Application.*\)/\1/p' | head -1)
codesign --sign "$IDENTITY" --timestamp $DMG

if $SKIP_NOTARIZE; then
  echo "⚠ Skipped notarization: $DMG only runs on this Mac without a Gatekeeper warning."
  exit 0
fi

echo "▸ Notarizing (profile $NOTARY_PROFILE)"
xcrun notarytool submit $DMG --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple $DMG
spctl --assess --type open --context context:primary-signature --verbose $DMG

echo "▸ Signing the update for Sparkle and writing site/appcast.xml"
# Private key lives in the login keychain (account "wachmacher"), see docs/release.md.
ED_SIGNATURE=$($SPARKLE_BIN/sign_update --account wachmacher -p $DMG)
LENGTH=$(stat -f %z $DMG)
python3 -I scripts/update-appcast.py "$VERSION" "$BUILD" \
  "https://github.com/iamginsley/wachmacher/releases/download/v$VERSION/Wachmacher-$VERSION.dmg" \
  "$LENGTH" "$ED_SIGNATURE" "$NOTES"

# Stable name for https://github.com/iamginsley/wachmacher/releases/latest/download/Wachmacher.dmg
cp $DMG $OUT/Wachmacher.dmg
echo "✓ $DMG"
echo "  Upload both $DMG (Sparkle) and $OUT/Wachmacher.dmg (website) to release v$VERSION,"
echo "  then commit site/appcast.xml and run scripts/publish-site.sh."
