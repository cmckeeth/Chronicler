#!/usr/bin/env bash
# Ship a new iOS build to TestFlight (mirror of deploy.sh for Android).
#
#   ./deploy-ios.sh
#
# That's it — credentials are read from Chronicler/fastlane/.env (gitignored).
# Build number = git commit count (monotonic), so no version edits are needed.
#
# Prereqs (one-time, already done on this machine):
#   - Apple Developer Program membership (active)
#   - fastlane installed:  brew install fastlane
#   - App record in App Store Connect for blackbird.llc.Chronicler
#   - Chronicler/fastlane/.env populated with:
#       APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH  (+ the AuthKey_*.p8)
set -euo pipefail
cd "$(dirname "$0")/Chronicler"

# Load credentials from the gitignored .env (also auto-loaded by fastlane, but we
# source it here too so the guards below pass and the values are exported to gym).
if [ -f fastlane/.env ]; then
  set -a; . fastlane/.env; set +a
fi

: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID (in Chronicler/fastlane/.env)}"
: "${ASC_KEY_ID:?set ASC_KEY_ID (in Chronicler/fastlane/.env)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (in Chronicler/fastlane/.env)}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH — path to AuthKey_XXXX.p8 (in Chronicler/fastlane/.env)}"

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo "ASC_KEY_PATH points to a missing file: $ASC_KEY_PATH" >&2
  exit 1
fi

# Version = VERSION file (major.minor) + commit count (patch), matching deploy.sh.
# The Fastfile computes the same thing and passes it to xcodebuild.
echo "Deploying iOS $(tr -d '[:space:]' < ../VERSION).$(git rev-list --count HEAD)" \
     "(build $(git rev-list --count HEAD)) to TestFlight (team $APPLE_TEAM_ID)…"
if command -v bundle >/dev/null 2>&1 && [ -f Gemfile.lock ]; then
  bundle exec fastlane beta
else
  fastlane beta
fi
