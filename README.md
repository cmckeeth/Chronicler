# Chronicler

Personal audiobook library — ASP.NET Core API with three native frontends:
Swift/SwiftUI (iOS), Kotlin/Compose (Android), React/Vite (web).

Drop audio files in `Library/`, scan, play. Progress, bookmarks, and position sync across devices.

---

## Server

### Requirements

- Docker + Docker Compose
- Git

### First-time setup

```bash
git clone git@github.com:cmckeeth/Chronicler.git
cd Chronicler
./setup-server.sh
```

This will:
- Generate a `JWT_KEY` and write it to `.env` (back this up)
- Create `Library/` and `updates/` directories
- Build and start the API container

**Server runs on port `5160`.**

### Add audiobooks

Organize files in `Library/` like:

```
Library/
  Author Name - Book Title/
    audiobook.mp3      ← or .m4b, .m4a, .ogg, .flac
    cover.jpg          ← optional
```

Then trigger a scan:
```bash
curl -X POST http://localhost:5160/api/library/scan \
  -H "Authorization: Bearer <your-token>"
```

Or just restart the server — it scans on startup automatically.

### Update the server

```bash
git pull && docker compose up -d --build
```

---

## Android APK

### Build and serve

```bash
./deploy.sh
```

Builds the Kotlin APK, copies it to `updates/`, and brings the containers up (API + web).
The version is derived, not stored: the repo-root `VERSION` file supplies `major.minor`
and the git commit count supplies the patch, so every deploy ships a higher version with
nothing to bump. Edit `VERSION` to cut a feature release.

In practice you don't run this by hand — POST to the deploy webhook and the server does
`git pull && ./deploy.sh` itself:

```bash
curl -X POST http://192.168.1.71:5162/deploy -H "X-Deploy-Secret: <secret>"
curl http://192.168.1.71:5162/deploy/status        # poll until "idle"
```

### Install on device

1. On your Android device, open a browser and go to:
   ```
   http://<server-ip>:5160/install
   ```
2. Scan the QR code or tap **Download APK**
3. Enable **Install from unknown sources** if prompted
4. Install and open Chronicler

### Update the app

The app checks for updates every 60 seconds. When a new APK is available, a banner appears — tap it to download and install.

---

## Web

Open `http://<server-ip>:5161` — the React app, served by nginx in the `chronicler-web`
container (it proxies `/api` to the API on `:5160`). Same login as the mobile apps.

---

## iOS

The native Swift app lives at `Chronicler/Chronicler.xcodeproj` and ships through
**TestFlight** (paid Apple Developer Program, already enrolled):

```bash
./deploy-ios.sh          # archive, sign, upload — creds come from Chronicler/fastlane/.env
```

Build number is the git commit count, so it's unique and monotonic — but it also means you
can't re-deploy the same commit twice.

For local development, build to the Simulator (no signing needed):

```bash
cd Chronicler
xcodebuild -project Chronicler.xcodeproj -scheme Chronicler \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Chronicler.app
```

Cabled installs to your own device and the full TestFlight setup are documented in
[`docs/ios-distribution.md`](docs/ios-distribution.md).

---

## Deploying

| Target | Command | Ships |
|---|---|---|
| Android + web + API | POST to the deploy webhook | APK to `updates/`, both containers rebuilt |
| iOS | `./deploy-ios.sh` | TestFlight build |

The webhook deploys whatever is on `main`, so push before triggering it. There's no
Android-only path — `deploy.sh` rebuilds the web container too.

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_KEY` | dev key (insecure) | Secret for signing JWT tokens — **change in production** |
| `CHRONICLER_DB_PATH` | `/data/chronicler.db` | SQLite database path |
| `CHRONICLER_API_URL` | `http://localhost:5160` | API base URL |
| `APP_VERSION` | derived | Set by `deploy.sh` (VERSION + commit count); passed to the web image as a build arg |
