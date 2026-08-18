# Chronicler

ASP.NET C# API/data layer + multiple frontends consuming it over HTTP REST.

## Architecture direction (in progress)

Moving off the single MAUI/Blazor-hybrid frontend toward **separation of concerns**: the
C# backend stays authoritative, frontends are independent per platform.

> **⚠️ FEATURE PARITY IS MANDATORY.** There are THREE active frontends — **web** (`src/chronicler-react`),
> **iOS** (`Chronicler/`), **Android** (`android/`). Any user-facing change — a feature, a theme, a
> font, a fix, a behavior tweak — MUST be implemented in **all three**, not just the one being worked
> on. Do not consider a task done until web + iOS + Android all have it. If you can only do some now,
> say so explicitly and track the rest. Themes especially: web, iOS, and Android must offer the same
> set (currently **nine**: Tesla / Steampunk / Garden / Dark Academia / Blackletter Noir /
> Wild West / Neon Sunset / Molten Forge / Ransom Note) and look/behave equivalently per platform.

- **Backend** — `src/Chronicler.Api` (.NET REST, JWT auth). Stays C#. Source of truth.
- **iOS** — **native Swift/SwiftUI** app at repo-root `Chronicler/`. Consumes the API over HTTP. Runs on the **Simulator** for development and ships to **TestFlight** via `./deploy-ios.sh` (see `docs/ios-distribution.md`).
- **Android** — **native Kotlin/Compose** app at `android/`. Consumes the API over HTTP. Built to an APK and shipped through the existing endpoint pipeline (`deploy.sh` → `updates/` → `/api/update/apk`, in-app self-update). Same deploy *mechanism* as before, native Kotlin app instead of MAUI.
- **Web** — **native React/Vite** app at `src/chronicler-react` (active, deployed). Consumes the API over HTTP. Built + served as the `chronicler-web` container in `docker-compose.yml` (nginx on :5161, proxies `/api`); ships on every server deploy. Shows a version badge + theme switcher bottom-right. (Old `src/Chronicler.Web` Blazor is abandoned.)
- **Legacy** — `src/Chronicler.Maui` (Blazor-in-WebView hybrid) retired now that natives exist; kept as fallback.

API contract lives in `src/Chronicler.Shared/Services/ApiClient.cs` (endpoints, DTOs, JWT). Base URL `https://chronicler.mckeeth.app`.

## iOS Swift app (`Chronicler/Chronicler.xcodeproj`)

Native SwiftUI port of the Blazor UI — same behavior, same steampunk look. Xcode 16 project
(objectVersion 77, **synchronized folders**: drop `.swift` files into `Chronicler/Chronicler/`
and they auto-compile, no pbxproj edits). Target iOS 26.5, bundle `blackbird.llc.Chronicler`.

Files: `Theme` (palette from `steampunk.css`), `Models` (Codable DTOs), `APIClient` (Swift port,
Bearer auth), `AuthStore` (token in UserDefaults), `AudioPlayerModel` (AVPlayer: skip±30, speed,
poll, save progress every 10s, advance on end), views `Login/Landing/Archive/BookPlayer`,
`CoverImage` (authed cover fetch + cache), startup sound.

### Build + run on Simulator (no code signing needed)
```bash
cd Chronicler
xcodebuild -project Chronicler.xcodeproj -scheme Chronicler \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build

xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
APP=build/Build/Products/Debug-iphonesimulator/Chronicler.app
xcrun simctl install booted "$APP"
xcrun simctl launch booted blackbird.llc.Chronicler
xcrun simctl io booted screenshot /tmp/shot.png   # verify
```
SourceKit may flag cross-file "cannot find type" / macOS-unavailable errors in the editor —
ignore them; the `iphonesimulator` build is the source of truth.

### Not yet ported (vs the Blazor app)
- Background-audio capability (needs `UIBackgroundModes: audio` in Info.plist; foreground + Now Playing work).
- Bundled Cinzel/Lora fonts (uses the CSS-declared Palatino/Georgia serif fallbacks).
- UpdateBanner (APK self-update — Android-only concern).

---

## Android Kotlin/Compose app (`android/`)

Native Kotlin + Jetpack Compose port — same behavior, same steampunk look. Plain Gradle
project (no Android Studio needed). Package `app.chronicler`, minSdk 26, compileSdk 35.

Stack: Compose (BOM 2024.12.01) + Navigation-Compose, OkHttp + kotlinx.serialization
(`ApiClient`), Media3/ExoPlayer (`AudioController`), SharedPreferences token (`AuthStore`).
Files mirror iOS: `Theme`, `Models`, `ApiClient`, `AuthStore`, `AudioController`,
`MainActivity` (NavHost), screens `LoginScreen/LandingScreen/ArchiveScreen/BookPlayerScreen`,
`Util` (CoverImage + startup sound).

Versions pinned for compatibility: **Gradle wrapper 8.11.1**, AGP 8.7.3, Kotlin 2.0.21.
SDK path comes from `android/local.properties` (`sdk.dir=...`) or `ANDROID_HOME`. On this Mac
the SDK is at `/opt/homebrew/share/android-commandlinetools`.

### Build APK + run on emulator
```bash
cd android
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools   # this Mac
./gradlew assembleDebug
# APK -> app/build/outputs/apk/debug/app-debug.apk

ADB="$ANDROID_HOME/platform-tools/adb"
"$ANDROID_HOME/emulator/emulator" -avd Pixel_Emulator -no-snapshot &   # AVD exists
"$ADB" wait-for-device
"$ADB" install -r app/build/outputs/apk/debug/app-debug.apk
"$ADB" shell am start -n app.chronicler/.MainActivity
"$ADB" exec-out screencap -p > /tmp/shot.png    # verify
```

### Deploy (server, via webhook → `deploy.sh`)
`deploy.sh` now builds the **Kotlin APK** (was MAUI): bumps `versionName`/`versionCode` in
`android/app/build.gradle.kts`, runs `./gradlew assembleDebug`, copies to `updates/`, then
`docker compose up`. The API serves it at `/api/update/version` + `/api/update/apk`; the app
self-updates (REQUEST_INSTALL_PACKAGES + FileProvider in the manifest). Server needs JDK 17+
and the Android SDK (`ANDROID_HOME`, default `/home/corbin/Android/Sdk`).

### Not yet ported (vs the Blazor app)
- Bundled Cinzel/Lora fonts (uses system defaults).


---

## Themes (nine, must stay in sync across all three frontends)

Tesla · Steampunk · Garden · Dark Academia (`academia`) · Blackletter Noir (`noir`) ·
Wild West (`west`) · Neon Sunset (`neon`) · Molten Forge (`forge`) · Ransom Note (`ransom`).

**Ransom Note is the only LIGHT theme** — `parchment` is ink, `ink` is paper. It exists partly
as a canary: it catches anything that assumes a dark ground. Two such bugs already surfaced —
`ContentView`'s hardcoded `.preferredColorScheme(.dark)` (system-drawn placeholders went
invisible on paper) and the glow modifiers (a bloom on a photocopy reads as a smudge, so
Ransom gets a hard ink offset instead). **Check Ransom whenever you touch shared chrome.**

Adding a theme touches, per frontend:
- **Web**: `styles.css` `:root[data-theme="x"]` token block + FX CSS + font `@import`;
  `App.jsx` `<option>` + an FX component rendered in `App()`; `main.jsx` `_validThemes`.
- **iOS** (`Chronicler/Chronicler/`): `Theme.swift` enum + `pick()` (now **nine** positional
  args) + font funcs + `glow` + `ElectricPanelStyle` branch; `ChroniclerApp.swift`
  `registerFonts()` for any new TTF; `LandingView.swift` picker `.tag`; `Electric.swift`
  `ThemedBackground` branch + FX structs; **`CoverImage.swift` `coverTreatment()`** — easy to
  miss, no compiler error, silently falls through to the Tesla branch.
- **Android**: `Theme.kt` enum + `byTheme()` (nine args) + fonts + `glowVerdigris` +
  `electricPanel`; `Electric.kt` `charged()` + a backdrop composable; `MainActivity.kt` backdrop
  wiring; `Util.kt` `coverColorFilter()` (exhaustive `when` — the compiler enforces this one);
  `LandingScreen.kt` `label()`. The dropdown iterates `ThemeMode.entries`, so no list to update.

Native fonts are bundled TTFs (`Chronicler/Chronicler/*.ttf`, `android/app/src/main/res/font/`).
Fetch them from Google Fonts with an **old** UA or you get woff2, which neither native app loads:
`curl -A "Mozilla/4.0" 'https://fonts.googleapis.com/css2?family=Rye'`.

Per-theme startup sounds are optional: `startup_<mode>.mp3`, falling back to `startup.mp3`.
Only tesla/steampunk/garden have bespoke ones.

### Verifying a theme in the simulator
The app reads its sandbox `Library/Preferences/<bundleid>.plist`. To force one headlessly:
**write the key first, then flush cfprefsd, then launch** — the other order loses the write.
```bash
xcrun simctl terminate booted blackbird.llc.Chronicler
C=$(xcrun simctl get_app_container booted blackbird.llc.Chronicler data)
/usr/libexec/PlistBuddy -c "Set :chronicler.theme forge" "$C/Library/Preferences/blackbird.llc.Chronicler.plist"
xcrun simctl spawn booted killall cfprefsd; sleep 2
xcrun simctl launch booted blackbird.llc.Chronicler
```
Synthetic clicks (`osascript ... click at`) are unreliable on small targets. To inspect a screen
that needs navigation, temporarily swap the root view in `ContentView.swift`, screenshot, revert.

---

## Offline downloads

Chapter audio plus a manifest, so the library is browsable and playable with the server down.
On disk beside the audio: `manifest.json` (book + chapter metadata), `cover-<bookId>.img`,
`progress.json` (position/duration/isListened/**dirty**). Progress saved while offline is marked
dirty and pushed on the next load that reaches the API.

Ways in: the **📥 Downloads chip** beside Books/Collections in the Archive (always), the landing
panel (**only** when the server is unreachable — it replaces "Enter the Archive" rather than
sitting beside it), the Archive error state, and the login screen.

Two traps worth remembering:
- **iOS files need a real extension.** Downloads were once saved as `<chapterId>.audio`;
  AVFoundation types a local asset by extension, so every offline chapter played *silence* with
  the timer frozen at 0:00 — online too, since a local file always wins over streaming. Files
  now use the extension implied by the served MIME type, and legacy `.audio` files are renamed
  on first launch. Android/ExoPlayer is unaffected (it takes an explicit mimeType).
- **iOS downloads live in Application Support, not Caches.** iOS evicts Caches under storage
  pressure — exactly when the offline copy matters. Existing files migrate on first access.

The **web has no offline capability** and its `/downloads` page says so; it streams only. That's
the one place the three-frontend parity rule can't be satisfied by mirroring.

---

## Versioning

One source of truth: the repo-root **`VERSION`** file holds `major.minor`; the patch is the git
**commit count**. Every deploy therefore ships a higher version with nothing to bump and nothing
to commit, and all three frontends report the *same* number. Cutting a feature release = editing
`VERSION`.

- `deploy.sh` derives `versionName` + `versionCode` (`major*1000000 + minor*10000 + patch` —
  it has to clear the `30259` that shipped under the old formula or Android refuses to install).
  Its `sed` into `build.gradle.kts` is deliberately left uncommitted; it's regenerated per build.
- `Chronicler/fastlane/Fastfile` passes `MARKETING_VERSION` **and** `CURRENT_PROJECT_VERSION` via
  `xcargs`, so the stale hardcoded `3.2.6` in `project.pbxproj` can't leak into a build.
- Web takes it as a Docker build arg (`docker-compose.yml` → `Dockerfile` → `vite.config.js`),
  because `src/chronicler-react` is the build context and has neither `.git` nor `VERSION` in it.

This replaced three drifting schemes (iOS hand-typed, Android inferred from a filename on the
server and never committed, web from `package.json`). The cost of the old way was real: three
testers all reporting "3.2.6" told us nothing, because builds 315/325/327 were all `3.2.6`.

---

## Legacy MAUI app (`net10.0-android;net10.0-ios`) — retired, kept as fallback

## Deploy MAUI app to a connected iPhone

### Prereqs
- **net10 SDK at `/usr/local/share/dotnet`** (NOT the homebrew `dotnet` on PATH, which is 9.x and will fail with `NETSDK1045: does not support targeting .NET 10.0`). Always run with:
  ```bash
  export PATH="/usr/local/share/dotnet:$PATH" DOTNET_ROOT="/usr/local/share/dotnet"
  ```
- **android workload** must be installed, or restore fails with `NETSDK1147: ... workloads must be installed: android` (because `TargetFrameworks` lists `net10.0-android`). Install once:
  ```bash
  sudo /usr/local/share/dotnet/dotnet workload install android
  ```
  Alternative without sudo: temporarily edit `src/Chronicler.Maui/Chronicler.Maui.csproj` line `<TargetFrameworks Condition="...osx...">` to `net10.0-ios` only, build, then revert. Do NOT use `-p:TargetFrameworks=net10.0-ios` — it propagates to `Chronicler.Shared` (which is `net10.0`) and breaks its restore.

### Find the device udid
```bash
xcrun devicectl list devices          # column "Identifier" / "connected"
xcrun xctrace list devices            # shows udid like 00008120-001C3D20216BC01E
```

### Build, install, launch
```bash
cd src/Chronicler.Maui
export PATH="/usr/local/share/dotnet:$PATH" DOTNET_ROOT="/usr/local/share/dotnet"

# 1. Build for device (ios-arm64, Release)
/usr/local/share/dotnet/dotnet build -f net10.0-ios -c Release -p:RuntimeIdentifier=ios-arm64

# 2. Install
xcrun devicectl device install app --device <UDID> \
  bin/Release/net10.0-ios/ios-arm64/Chronicler.Maui.app

# 3. Launch
xcrun devicectl device process launch --device <UDID> blackbird.llc.Chronicler
```

`dotnet build -t:Run -p:_DeviceName=<UDID>` also works but only after a separate build step (the Run target won't build first), and it routes launch through `mlaunch`.

### Trust the developer profile (REQUIRED first time / after expiry)
A fresh install with a dev cert shows the icon as **"Chronicler is no longer available"** and launch fails with:
```
profile has not been explicitly trusted by the user (FBSOpenApplicationServiceErrorDomain error 1)
```
Fix on the iPhone: **Settings → General → VPN & Device Management → Apple Development: <account> → Trust**. Then tap the app icon. The free/dev provisioning profile expires (~7 days), so this repeats periodically — rerun the build/install steps when it lapses.

- Bundle id: `blackbird.llc.Chronicler`
- Signing: `Apple Development: corbin.mckeeth@gmail.com`

## Deploying

**Android + web + API** — one webhook; there is no Android-only path, `deploy.sh` builds the APK
*and* brings the containers up. It deploys whatever is on `main`, so push first.
```bash
curl -X POST http://192.168.1.71:5162/deploy -H "X-Deploy-Secret: brass-and-steam-2026"
curl http://192.168.1.71:5162/deploy/status     # poll until "idle", ~45-75s
curl https://chronicler.mckeeth.app/api/update/version
```

**iOS → TestFlight** — `./deploy-ios.sh` from the repo root. Credentials come from the
gitignored `Chronicler/fastlane/.env`; nothing to export. Build number is the commit count, so
**you cannot re-deploy the same commit** — App Store Connect rejects a duplicate build number.

Two Apple agreements gate this and neither error names itself usefully. If `build_app` fails to
export ("Error packaging up the application" + only an *Apple Development* identity in
`security find-identity -v -p codesigning`), the **Program License Agreement** needs accepting at
developer.apple.com. If the upload fails with "A required agreement is missing or has expired",
it's the **Free Apps Agreement** under App Store Connect → Business. Both expire annually; the
current Free Apps Agreement runs to **2027-06-16**.

Don't pipe `deploy-ios.sh` through `tail` — fastlane prints an update changelog at the end, so
the tail is noise and the real error scrolls past. Redirect to a file instead.
