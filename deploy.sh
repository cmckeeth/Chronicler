#!/usr/bin/env bash
set -euo pipefail

# Build the native Kotlin/Compose Android app and deploy it through the same
# endpoint pipeline as before: bump version, drop the APK in updates/, redeploy API.
ANDROID_DIR="android"
GRADLE_BUILD="$ANDROID_DIR/app/build.gradle.kts"
API_UPDATES_DIR="updates"
export ANDROID_HOME="${ANDROID_HOME:-/home/corbin/Android/Sdk}"

# ── Version ───────────────────────────────────────────────────────────────────
# Derived, never stored: major.minor comes from the repo-root VERSION file, the
# patch is the git commit count. Every deploy therefore ships a higher version
# with nothing to bump or commit, and all three frontends (iOS via the fastlane
# Fastfile, web via the APP_VERSION build arg below) compute the SAME number.
# To cut a feature release, edit VERSION — that's the only manual step.
#
# The old scheme inferred the next version from the newest APK filename in
# updates/ and sed'd it into build.gradle.kts without ever committing, so the
# repo said 3.2.0 while the server served 3.2.59. Nothing is written now.

BASE_VER=$(tr -d '[:space:]' < VERSION)
BUILD_NUM=$(git rev-list --count HEAD)
NEW_VER="$BASE_VER.$BUILD_NUM"

MAJOR=$(echo "$BASE_VER" | cut -d. -f1)
MINOR=$(echo "$BASE_VER" | cut -d. -f2)
# versionCode must only ever increase or Android refuses the update. This scheme
# leaves 4 digits for the patch and clears the 30259 that shipped under the old
# major*10000+minor*100+patch formula.
NEW_CODE=$((MAJOR * 1000000 + MINOR * 10000 + BUILD_NUM))

echo "Version $NEW_VER (versionCode $NEW_CODE)"
sed -i "s|versionName = \".*\"|versionName = \"$NEW_VER\"|" "$GRADLE_BUILD"
sed -i "s|versionCode = .*|versionCode = $NEW_CODE|" "$GRADLE_BUILD"
# The edits above are deliberately left uncommitted — they're regenerated from
# VERSION + commit count on every build, so the server's working copy drifting
# from the repo no longer matters.

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
# The web image builds from src/chronicler-react, which has neither .git nor the
# repo-root VERSION in its build context — so the version is passed in as a build
# arg (see docker-compose.yml + the Dockerfile) rather than read from disk.
export APP_VERSION="$NEW_VER"
docker compose up -d --build

echo "Waiting for health check..."
sleep 3
curl -fsS "http://localhost:5160/api/health" && echo " — healthy" || echo " — health check failed"

echo "Deploy complete: v$NEW_VER"
