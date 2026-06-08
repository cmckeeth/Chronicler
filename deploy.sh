#!/usr/bin/env bash
set -euo pipefail

# Build the native Kotlin/Compose Android app and deploy it through the same
# endpoint pipeline as before: bump version, drop the APK in updates/, redeploy API.
ANDROID_DIR="android"
GRADLE_BUILD="$ANDROID_DIR/app/build.gradle.kts"
API_UPDATES_DIR="updates"
export ANDROID_HOME="${ANDROID_HOME:-/home/corbin/Android/Sdk}"

# ── Version bump ──────────────────────────────────────────────────────────────
# Auto-increment patch from the last built APK. To jump major/minor, just set a
# higher versionName in build.gradle.kts — the manual value wins when it's ahead.

LAST_VER=$(ls "$API_UPDATES_DIR"/Chronicler-v*.apk 2>/dev/null \
    | sed 's/.*Chronicler-v\(.*\)\.apk/\1/' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -n1) || true

GRADLE_VER=$(grep 'versionName' "$GRADLE_BUILD" | sed 's/.*"\(.*\)".*/\1/' | head -n1)

if [[ -z "$LAST_VER" ]]; then
    NEW_VER="$GRADLE_VER"
else
    # Candidate from auto patch-bump of the last APK...
    PMAJOR=$(echo "$LAST_VER" | cut -d. -f1)
    PMINOR=$(echo "$LAST_VER" | cut -d. -f2)
    PPATCH=$(echo "$LAST_VER" | cut -d. -f3)
    CANDIDATE="$PMAJOR.$PMINOR.$((PPATCH + 1))"
    # ...but a manually-set higher versionName wins (major/minor bumps).
    NEW_VER=$(printf '%s\n%s\n' "$CANDIDATE" "$GRADLE_VER" | sort -V | tail -n1)
fi

MAJOR=$(echo "$NEW_VER" | cut -d. -f1)
MINOR=$(echo "$NEW_VER" | cut -d. -f2)
PATCH=$(echo "$NEW_VER" | cut -d. -f3)
NEW_CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))

echo "Bumping $LAST_VER → $NEW_VER (versionCode $NEW_CODE)"
sed -i "s|versionName = \".*\"|versionName = \"$NEW_VER\"|" "$GRADLE_BUILD"
sed -i "s|versionCode = .*|versionCode = $NEW_CODE|" "$GRADLE_BUILD"

# ── Build Android APK (debug-signed, mirrors prior pipeline) ─────────────────

echo "Building Android APK with Gradle..."
( cd "$ANDROID_DIR" && ./gradlew assembleDebug --no-daemon )

APK_PATH="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$APK_PATH" ]]; then
    echo "Error: APK not found after build"
    exit 1
fi

# ── Copy APK to updates dir ───────────────────────────────────────────────────

mkdir -p "$API_UPDATES_DIR"
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
