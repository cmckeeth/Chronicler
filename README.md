# Chronicler

Personal audiobook library — MAUI (iOS/Android) + Blazor Web + ASP.NET Core API.

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

This bumps the patch version, builds the APK, copies it to `updates/`, and restarts the API.

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

Open `http://<server-ip>:5160` in any browser. Same login as the mobile app.

---

## iOS

Sideloading from a URL is not supported on iOS. Options:

| Method | Cost | Notes |
|--------|------|-------|
| Xcode direct install | Free | Dev machine required, for personal use |
| AltStore | Free | Needs refresh every 7 days via your Mac |
| TestFlight | $99/yr Apple dev account | Best for sharing with others |

For dev/personal use, run from Xcode:
```bash
dotnet build src/Chronicler.Maui/Chronicler.Maui.csproj -f net9.0-ios -c Debug
# Then open in Xcode and run on device
```

---

## CI/CD

Push to `main` → GitHub Actions builds the APK and deploys the API via `docker compose` on the self-hosted runner.

Set the `JWT_KEY` secret in **GitHub → Settings → Secrets → Actions**:
```
JWT_KEY = <same value as your .env file>
```

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_KEY` | dev key (insecure) | Secret for signing JWT tokens — **change in production** |
| `CHRONICLER_DB_PATH` | `/data/chronicler.db` | SQLite database path |
| `CHRONICLER_API_URL` | `http://localhost:5160` | API base URL (used by Blazor Web) |
