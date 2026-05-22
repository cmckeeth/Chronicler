#!/usr/bin/env bash
set -euo pipefail

APP_CSPROJ="src/Chronicler.Maui/Chronicler.Maui.csproj"
API_UPDATES_DIR="updates"

# ── Version bump (based on last built APK, not csproj) ───────────────────────

# Read highest version from updates/ dir so git pull doesn't reset it
LAST_VER=$(ls "$API_UPDATES_DIR"/Chronicler-v*.apk 2>/dev/null \
    | sed 's/.*Chronicler-v\(.*\)\.apk/\1/' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -n1) || true

if [[ -z "$LAST_VER" ]]; then
    LAST_VER=$(grep '<ApplicationDisplayVersion>' "$APP_CSPROJ" | sed 's/.*>\(.*\)<.*/\1/' | head -n1)
fi

MAJOR=$(echo "$LAST_VER" | cut -d. -f1)
MINOR=$(echo "$LAST_VER" | cut -d. -f2)
PATCH=$(echo "$LAST_VER" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
NEW_VER="$MAJOR.$MINOR.$NEW_PATCH"

echo "Bumping $LAST_VER → $NEW_VER"
sed -i "s|<ApplicationDisplayVersion>.*</ApplicationDisplayVersion>|<ApplicationDisplayVersion>$NEW_VER</ApplicationDisplayVersion>|" "$APP_CSPROJ"
sed -i "s|<ApplicationVersion>.*</ApplicationVersion>|<ApplicationVersion>$((PATCH + 1))</ApplicationVersion>|" "$APP_CSPROJ"

# ── Ensure Android workload ───────────────────────────────────────────────────

echo "Installing MAUI Android workload..."
dotnet workload install maui-android

# ── Install Android SDK dependencies ─────────────────────────────────────────

echo "Installing Android SDK dependencies..."
dotnet build "$APP_CSPROJ" \
    -t:InstallAndroidDependencies \
    -f net10.0-android \
    -c Debug \
    -p:AndroidSdkDirectory=/home/corbin/Android/Sdk \
    -p:AcceptAndroidSDKLicenses=true

# ── Build MAUI Android APK ────────────────────────────────────────────────────

echo "Building Android APK..."
dotnet publish "$APP_CSPROJ" \
    -f net10.0-android \
    -c Debug \
    -p:EmbedAssembliesIntoApk=true \
    -p:AndroidPackageFormat=apk

# Prefer the debug-signed APK; fall back to any APK if not found
APK_PATH=$(find . -name "*-Signed.apk" -newer "$APP_CSPROJ" | head -n1)
if [[ -z "$APK_PATH" ]]; then
    APK_PATH=$(find . -name "*.apk" -newer "$APP_CSPROJ" | head -n1)
fi

if [[ -z "$APK_PATH" ]]; then
    echo "Error: APK not found after build"
    exit 1
fi

# ── Copy APK to updates dir ───────────────────────────────────────────────────

mkdir -p "$API_UPDATES_DIR"

# Remove old versioned APKs, keep only the new one
rm -f "$API_UPDATES_DIR"/Chronicler-v*.apk

cp "$APK_PATH" "$API_UPDATES_DIR/Chronicler-v$NEW_VER.apk"
cp "$APK_PATH" "$API_UPDATES_DIR/Chronicler.apk"
echo "APK saved: $API_UPDATES_DIR/Chronicler-v$NEW_VER.apk"

# ── Deploy via docker compose ─────────────────────────────────────────────────

echo "Deploying API..."
docker compose up -d --build

echo "Waiting for health check..."
sleep 3
curl -fsS "http://localhost:5160/api/health" && echo " — healthy" || echo " — health check failed"

echo "Deploy complete: v$NEW_VER"
