#!/usr/bin/env bash
set -euo pipefail

APP_CSPROJ="src/Chronicler.Maui/Chronicler.Maui.csproj"
API_UPDATES_DIR="updates"

# ── Version bump ──────────────────────────────────────────────────────────────

CURRENT_VER=$(grep '<ApplicationDisplayVersion>' "$APP_CSPROJ" | sed 's/.*>\(.*\)<.*/\1/' | head -n1)
MAJOR=$(echo "$CURRENT_VER" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VER" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VER" | cut -d. -f3)
NEW_PATCH=$((PATCH + 1))
NEW_VER="$MAJOR.$MINOR.$NEW_PATCH"

echo "Bumping $CURRENT_VER → $NEW_VER"
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
    -p:AndroidSdkDirectory=/home/corbin/Android/Sdk \
    -p:AcceptAndroidSDKLicenses=true

# ── Build MAUI Android APK ────────────────────────────────────────────────────

echo "Building Android APK..."
dotnet publish "$APP_CSPROJ" \
    -f net10.0-android \
    -c Release \
    -p:EmbedAssembliesIntoApk=true \
    -p:AndroidPackageFormat=apk

APK_PATH=$(find . -name "*.apk" -not -name "*Signed*" -newer "$APP_CSPROJ" | head -n1)

if [[ -z "$APK_PATH" ]]; then
    echo "Error: APK not found after build"
    exit 1
fi

# ── Copy APK to updates dir ───────────────────────────────────────────────────

mkdir -p "$API_UPDATES_DIR"
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
