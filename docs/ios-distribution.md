# iOS Distribution Spec — Chronicler

How the native iOS Swift app (`Chronicler/Chronicler.xcodeproj`) gets onto devices:
**(A)** cabled installs to your own phones, and **(B)** TestFlight for everyone else.

## Account facts

| Thing | Value |
|---|---|
| Apple ID / signing identity | `corbin.mckeeth@gmail.com` |
| Team name | **Corbin McKeeth** (free personal team, upgraded in place to **paid** via Individual enrollment) |
| **Team ID** | `ZSTUXP8336` |
| Bundle identifier | `blackbird.llc.Chronicler` |
| App Store Connect app name | **Chronicler** · SKU `chronicler` |

Notes:
- There is **no "blackbird llc" team**. App Store Connect auto-labels the App ID
  `XC blackbird llc Chronicler` by converting the bundle id `blackbird.llc.Chronicler` — it's
  cosmetic. The owning team is **Corbin McKeeth**.
- Paid enrollment keeps the same Team ID; the project already signs with it.

## A. Cabled install (your own phones) — now lasts 1 year

Because the team is **paid**, `-allowProvisioningUpdates` mints a **1-year** dev profile
(was 7 days on the free account). No more weekly re-trust.

```bash
cd Chronicler
rm -rf build-device
xcodebuild -project Chronicler.xcodeproj -scheme Chronicler \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build-device -allowProvisioningUpdates build

UDID=$(xcrun devicectl list devices | awk '/connected/ && /iPhone/ {print $(NF-2)}')   # or hardcode
APP=build-device/Build/Products/Debug-iphoneos/Chronicler.app
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" blackbird.llc.Chronicler
```

- Device must be **connected + unlocked** (else `error 1011 unavailable` / `Locked`).
- Verify the profile is 1-year:
  `security cms -D -i "$APP/embedded.mobileprovision" | grep -A1 ExpirationDate`
- Known device: Hannah's iPhone (iPhone 14 Pro) — UDID `46DE9366-5707-562F-90AA-0C017AD74D12`.
- Devices do **not** need manual registration for cabled dev installs — Xcode auto-registers
  them (100 device slots/yr on the paid plan).

## B. TestFlight (remote testers — friends/family)

No cables, no device registration, no 7-day expiry. Build lasts 90 days; push a new one to refresh.

### One-time setup
1. Enroll in the Apple Developer Program ($99/yr, Individual). ✅ done
2. App Store Connect → create the app record: Name **Chronicler**, Bundle ID
   `blackbird.llc.Chronicler`, SKU `chronicler`, Full Access. ✅ done
3. App Store Connect → **Users and Access → Integrations → App Store Connect API** → generate a
   key (role **App Manager**). Save the one-time `AuthKey_XXXXXX.p8`. Record the **Issuer ID** and
   **Key ID**. (The `.p8` is gitignored — never commit it.)

### Ship a build
Pipeline lives in `Chronicler/fastlane/` (`Fastfile` `beta` lane + `Appfile`), invoked by
`deploy-ios.sh` at the repo root (the iOS mirror of Android's `deploy.sh`).

```bash
brew install fastlane            # one time
export APPLE_TEAM_ID=ZSTUXP8336
export ASC_KEY_ID=<key id>
export ASC_ISSUER_ID=<issuer id>
export ASC_KEY_PATH=/absolute/path/to/AuthKey_XXXXXX.p8
./deploy-ios.sh                  # archives, signs (app-store), uploads to TestFlight
```

Build number = git commit count (`number_of_commits`), so it's unique and monotonic — no
agvtool/project edits.

### Invite testers
- App Store Connect → **TestFlight** tab.
- **Internal testers** (people you add under Users and Access, up to 100): instant, no review.
- **External testers** (up to 10,000, by email or a **public link**): the *first* build needs a
  one-time **Beta App Review** (usually <24h); later builds are basically instant.

### What a tester does
1. Install the **TestFlight** app from the App Store (free).
2. Open your email invite or public link → **Accept** → **Install**.
3. Auto-updates when you push a new build.

## Backend caveat
The app talks to `https://chronicler.mckeeth.app`, currently a self-hosted box
(`192.168.1.71`). Fine for TestFlight, but a public App Store release needs a reliably hosted,
always-up backend. See the (future) release checklist before going public — biggest open items
are **content licensing**, **in-app account deletion**, and **production hosting**.
