# Release

Wachmacher is not in the Mac App Store: posting mouse events needs Accessibility, which the App Sandbox
does not allow. It ships as a Developer ID signed, notarized DMG as a GitHub Release.

## One-time setup

1. **Developer ID certificate** (personal team `2567P974L9`, never the INNIO team). Check with:
   ```
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
2. **Notarization credentials** in the keychain (never in the repo). Credentials are per team, so the
   existing `smoll-notch` profile works and `scripts/release.sh` falls back to it. A dedicated profile:
   ```
   xcrun notarytool store-credentials wachmacher --apple-id <apple-id> --team-id 2567P974L9
   ```
   Override with `NOTARY_PROFILE=...`.

## Every release

1. Bump `VERSION` (user-visible) and `BUILD` (always) in `scripts/build.sh`.
2. Run:
   ```
   scripts/release.sh
   ```
   It runs the tests, builds a universal binary, signs with Developer ID and hardened runtime, builds the
   DMG (with a link to Programme), notarizes, staples and checks Gatekeeper. Result:
   `build/release/Wachmacher-<version>.dmg` plus a copy named `Wachmacher.dmg`. Upload the copy: the
   website downloads `releases/latest/download/Wachmacher.dmg`.
3. Smoke test: open the DMG, drag the app to Programme, start it. The cup appears; click toggles,
   right click opens the menu, a timer empties the cup, the settings open with ⌘,.
   `pmset -g assertions | grep Wachmacher` shows the assertions while awake.
4. Commit the version bump, tag and publish:
   ```
   git tag v<version> && git push origin v<version>
   gh release create v<version> build/release/Wachmacher.dmg --title "Wachmacher <version>" --notes "..."
   ```

`scripts/release.sh --skip-notarize` skips notarization for a quick local check.

## Website

`site/` is served by GitHub Pages from the `gh-pages` branch (https://iamginsley.github.io/wachmacher/).
After merging site changes into main:
```
scripts/publish-site.sh
```
The download page reads version, size and checksum of the latest release from the GitHub API, so a new
release needs no website change. Preview locally with `python3 -m http.server 4174 --directory site`.

## Checklist

- [ ] Version and build number bumped in `scripts/build.sh`
- [ ] Tests green (the script runs them)
- [ ] DMG notarized and stapled (`spctl` says "accepted, source=Notarized Developer ID")
- [ ] Smoke test
- [ ] Privacy policy current (`site/datenschutz.html`), `Resources/PrivacyInfo.xcprivacy` unchanged unless data use changed
- [ ] Tag pushed, GitHub Release with `Wachmacher.dmg`
