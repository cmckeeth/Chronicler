# Chronicler

ASP.NET C# API/data layer + multiple frontends consuming it over HTTP REST.

## Architecture direction (in progress)

Moving off the single MAUI/Blazor-hybrid frontend toward **separation of concerns**: the
C# backend stays authoritative, frontends are independent per platform.

- **Backend** — `src/Chronicler.Api` (.NET REST, JWT auth). Stays C#. Source of truth.
- **iOS** — **native Swift/SwiftUI** app at repo-root `Chronicler/`. Consumes the API over HTTP. Deploys to the **Simulator**.
- **Android** — **native Kotlin/Compose** app at `android/`. Consumes the API over HTTP. Built to an APK and shipped through the existing endpoint pipeline (`deploy.sh` → `updates/` → `/api/update/apk`, in-app self-update). Same deploy *mechanism* as before, native Kotlin app instead of MAUI.
- **Web** — scrapped for now (`src/Chronicler.Web` Blazor + `src/chronicler-react` left untouched, not built).
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
- Offline downloads (streaming-only; Blazor also hides download UI when no download service).
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
- Offline downloads (streaming-only, matches iOS).
- Bundled Cinzel/Lora fonts (uses system defaults).

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

## Server deploy
`webhook.py` / `deploy.sh` handle the API/Web server deploy (POST to the deploy webhook triggers git pull + redeploy).
