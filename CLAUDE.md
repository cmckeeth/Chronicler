# Chronicler

MAUI app (`net10.0-android;net10.0-ios`) + ASP.NET API/Web + shared library.

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
xcrun devicectl device process launch --device <UDID> com.corbin.chronicler
```

`dotnet build -t:Run -p:_DeviceName=<UDID>` also works but only after a separate build step (the Run target won't build first), and it routes launch through `mlaunch`.

### Trust the developer profile (REQUIRED first time / after expiry)
A fresh install with a dev cert shows the icon as **"Chronicler is no longer available"** and launch fails with:
```
profile has not been explicitly trusted by the user (FBSOpenApplicationServiceErrorDomain error 1)
```
Fix on the iPhone: **Settings → General → VPN & Device Management → Apple Development: <account> → Trust**. Then tap the app icon. The free/dev provisioning profile expires (~7 days), so this repeats periodically — rerun the build/install steps when it lapses.

- Bundle id: `com.corbin.chronicler`
- Signing: `Apple Development: corbin.mckeeth@gmail.com`

## Server deploy
`webhook.py` / `deploy.sh` handle the API/Web server deploy (POST to the deploy webhook triggers git pull + redeploy).
