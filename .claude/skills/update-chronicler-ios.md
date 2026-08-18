# /update-chronicler-ios

Ship the native iOS Swift app. **Superseded by `./deploy-ios.sh`** — this skill now just
documents the two paths and the traps.

> The old version of this skill built the retired MAUI app over USB with `dotnet build` and
> synced its version from the server. All of that is gone: the app is Swift/SwiftUI at
> `Chronicler/Chronicler.xcodeproj`, and the version derives from `VERSION` + commit count.

## TestFlight (the normal path)

```bash
./deploy-ios.sh
```

Archives, signs `app-store`, uploads. Credentials come from the gitignored
`Chronicler/fastlane/.env` — nothing to export.

- Build number = git commit count, so **the same commit can't be uploaded twice**. Commit first.
- Redirect the output to a file; don't pipe through `tail` (fastlane prints a changelog at the
  end, so the tail is noise and the real error scrolls past).
- Failures are usually an expired Apple agreement, not code. See the table in
  `docs/ios-distribution.md`.
- Processing takes 5–15 min before the build appears in TestFlight.

## Cabled install (your own device)

Paid team, so `-allowProvisioningUpdates` mints a 1-year profile — no weekly re-trust.

```bash
cd Chronicler
xcodebuild -project Chronicler.xcodeproj -scheme Chronicler \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build-device -allowProvisioningUpdates build

UDID=$(xcrun devicectl list devices | awk '/connected/ && /iPhone/ {print $(NF-2)}')
APP=build-device/Build/Products/Debug-iphoneos/Chronicler.app
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" blackbird.llc.Chronicler
```

Device must be connected **and unlocked** or you get `error 1011 unavailable` / `Locked`.

## Simulator (development)

```bash
cd Chronicler
xcodebuild -project Chronicler.xcodeproj -scheme Chronicler \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Chronicler.app
xcrun simctl launch booted blackbird.llc.Chronicler
```

Full reference: `docs/ios-distribution.md`.
