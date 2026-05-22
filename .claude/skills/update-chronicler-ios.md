# /update-chronicler-ios

Build and deploy the Chronicler iOS app to Hannah's iPhone over USB.
Version is automatically synced from the server before building — no manual bumping needed.

## Prerequisites
- iPhone plugged in via USB
- Signing cert: `Apple Development: corbin.mckeeth@gmail.com (RXQYCD389C)`
- Provisioning profile: `iOS Team Provisioning Profile: com.corbin.chronicler`
- Device UDID: `00008120-001C3D20216BC01E`

## Steps

Run from repo root (`/Users/Corbin.McKeeth/code/Chronicler`):

**1. Fetch version from server:**
```bash
VER=$(curl -sf http://192.168.1.71:5160/api/update/version | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
APP_VER=$(echo $VER | awk -F. '{print $1*100 + $2*10 + $3}')
echo "Building v$VER ($APP_VER)"
```

**2. Restore:**
```bash
/usr/local/share/dotnet/dotnet restore src/Chronicler.Shared/Chronicler.Shared.csproj
/usr/local/share/dotnet/dotnet restore src/Chronicler.Maui/Chronicler.Maui.csproj \
  -p:TargetFrameworks=net10.0-ios -r ios-arm64 --no-dependencies
```

**3. Build (version injected via -p: flags):**
```bash
/usr/local/share/dotnet/dotnet build src/Chronicler.Maui/Chronicler.Maui.csproj \
  -f net10.0-ios -r ios-arm64 \
  -p:TargetFrameworks=net10.0-ios \
  -p:ApplicationDisplayVersion=$VER \
  -p:ApplicationVersion=$APP_VER \
  -p:CodesignKey="Apple Development: corbin.mckeeth@gmail.com (RXQYCD389C)" \
  -p:CodesignProvision="iOS Team Provisioning Profile: com.corbin.chronicler" \
  --no-restore
```

**4. Install:**
```bash
xcrun devicectl device install app \
  --device 00008120-001C3D20216BC01E \
  src/Chronicler.Maui/bin/Debug/net10.0-ios/ios-arm64/Chronicler.Maui.app
```

## Notes
- Uses .NET 10 SDK at `/usr/local/share/dotnet/dotnet` (not homebrew `dotnet`)
- App expires on device after 7 days (free Apple ID) — just re-run to renew
- Android updates are OTA; iOS always requires USB + this skill
- The csproj version value is a fallback only — actual version always comes from server at build time
