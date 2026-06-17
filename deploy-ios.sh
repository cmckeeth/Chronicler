#!/usr/bin/env bash
# Ship a new iOS build to TestFlight (mirror of deploy.sh for Android).
# Prereqs:
#   - Apple Developer Program membership (active)
#   - fastlane installed:  (cd Chronicler && bundle install)   or   brew install fastlane
#   - App record created in App Store Connect for blackbird.llc.Chronicler
#   - These env vars set (see Chronicler/fastlane/Fastfile):
#       APPLE_TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
set -euo pipefail
cd "$(dirname "$0")/Chronicler"

: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH (path to AuthKey_XXXX.p8)}"

if command -v bundle >/dev/null 2>&1 && [ -f Gemfile.lock ]; then
  bundle exec fastlane beta
else
  fastlane beta
fi
