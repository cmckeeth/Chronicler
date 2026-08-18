# Chronicler — Project Context

Personal audiobook library app. Built by Corbin McKeeth with Claude Code.

## Stack

| Layer | Tech |
|-------|------|
| API | ASP.NET Core minimal API (.NET 10), SQLite via EF Core, ASP.NET Identity, JWT auth |
| iOS | Native Swift/SwiftUI (`Chronicler/Chronicler.xcodeproj`) |
| Android | Native Kotlin/Compose (`android/`) |
| Web | React + Vite (`src/chronicler-react/`) |
| Legacy | .NET MAUI Blazor Hybrid (`src/Chronicler.Maui`) — retired, kept as fallback |
| Hosting | Docker Compose on home server (192.168.1.71) |

## Projects

```
Chronicler/                — native iOS app (Swift/SwiftUI) + fastlane
android/                   — native Android app (Kotlin/Compose)
src/
  Chronicler.Api/          — ASP.NET Core API + EF Core + migrations
  Chronicler.Shared/       — ApiClient (the API contract) + legacy Blazor components
  Chronicler.Maui/         — retired MAUI shell
  chronicler-react/        — React web app (Vite, served by nginx in Docker)
VERSION                    — major.minor; patch comes from the git commit count
deploy.sh / deploy-ios.sh  — Android+web+API, and iOS→TestFlight
```

All three frontends are independent clients of the same REST API. **Feature parity is
mandatory** — see CLAUDE.md.

## Key URLs / Ports

- API: `http://192.168.1.71:5160`
- Web: `http://192.168.1.71:5161`
- Deploy webhook: `http://192.168.1.71:5162/deploy` (secret: `brass-and-steam-2026`)
- Install page (Android QR): `http://192.168.1.71:5160/install`

## Database

- SQLite at `/data/chronicler.db` in Docker (volume: `chronicler_chronicler-data`)
- Docker volume path on host: `/var/lib/docker/volumes/chronicler_chronicler-data/_data/chronicler.db`
- WAL mode enabled, 32MB cache
- EF Core migrations run automatically on startup

### Models

- `Book` — audiobook metadata, unique FilePath index
- `Chapter` — tracks within a book, FilePath indexed
- `ChapterProgress` — per-user per-chapter position + listened flag (unique: UserId+ChapterId)
- `UserBookFavorite` — per-user favorites (composite PK: UserId+BookId)
- `AppUser` — ASP.NET Identity user

## Auth

- JWT tokens, 90-day expiry
- iOS: `UserDefaults` key `chronicler.token` (`AuthStore.swift`)
- Android: `SharedPreferences` (`AuthStore.kt`)
- Web: `localStorage` key `chronicler_token`
- Password requirements: 6+ chars, no special character requirements

## Audio

### iOS — `AudioPlayerModel.swift`
- `AVPlayer`; `AVAudioSession.playback` + `.spokenAudio`, so it ignores the mute switch
- Skip ±30, speed, MPRemoteCommandCenter lock-screen controls, AirPlay route picker
- Volume boost (~12 dB) via an `MTAudioProcessingTap` on the item's audio mix
- Prefers a local download over streaming

### Android — `AudioController.kt`
- Media3/ExoPlayer, or `CastPlayer` when a Chromecast session connects (both are `Player`)
- `MediaSessionCompat` for notification/lock-screen controls; `LoudnessEnhancer` for boost
- Prefers a local download over streaming

### Web
- Plain HTML5 `<audio>` in the React player; streaming only

## Downloads (offline) — native only

- iOS `Downloads.swift`, Android `Downloads.kt`; **web has none** (streams only)
- Audio + `manifest.json` (book/chapter metadata) + `cover-<bookId>.img` + `progress.json`
- iOS: `Application Support/downloads/` — **not** Caches, which iOS evicts under pressure
- iOS filenames carry a real extension from the served MIME type; a generic `.audio` made
  AVFoundation play silence with the timer stuck at 0:00
- Offline progress is flagged `dirty` and pushed on the next load that reaches the API
- Reachable from the Downloads chip in the Archive, and (when the server is down) from the
  landing panel, the Archive error state, and the login screen

## Library Scanner

- Books discovered from `/app/Library` (mounted from host: `/mnt/media/4tb-media/AudioBooks`)
- Background scan every 20 minutes (`LibraryScanService`)
- Manual scan trigger via API: `POST /api/library/scan`
- `meta.json` in book directories read only on first discovery (not overwritten on rescan)
- Cover images stored as byte blobs in DB

## Versioning & OTA Updates

**One source of truth:** repo-root `VERSION` holds `major.minor`; the patch is the git commit
count. Derived at build time, never stored, so all three frontends report the same number and
nothing needs bumping or committing. Edit `VERSION` to cut a feature release.

This replaced three drifting schemes (iOS hand-typed in `project.pbxproj`, Android inferred
from the newest APK filename on the server and never committed, web from `package.json`).
The cost was real: three testers all on "3.2.6" carried no information, because builds
315/325/327 all shipped as 3.2.6.

### Android
- `deploy.sh` derives `versionName`/`versionCode`, builds the APK, brings containers up
- `versionCode = major*1000000 + minor*10000 + patch` — must exceed the 30259 that shipped
  under the old formula or Android refuses the update
- Webhook (`webhook.py`) runs `git pull && ./deploy.sh` on POST to `:5162/deploy`
- APK at `/api/update/apk`, version at `/api/update/version`; the app self-updates

### iOS
- `./deploy-ios.sh` → fastlane `beta` lane → TestFlight. Creds in gitignored
  `Chronicler/fastlane/.env`; `.p8` key alongside it
- Team ID `ZSTUXP8336`, App Store Connect app id `6781088096`
- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` both passed via `xcargs`, so the stale
  hardcoded value in `project.pbxproj` can't leak into a build
- Build number = commit count, so the same commit can't be deployed twice
- Two Apple agreements gate this (PLA for signing, Free Apps Agreement for upload) and expire
  annually — see `docs/ios-distribution.md`

## Styling

**Nine runtime themes**, identical across all three frontends: Tesla, Steampunk, Garden,
Dark Academia, Blackletter Noir, Wild West, Neon Sunset, Molten Forge, Ransom Note.

- Each theme is a palette (~19 tokens), a font trio, a panel style, an animated backdrop and
  a cover filter. Token names are historical — `brass` is "the metal", `verdigris` is "the
  accent", regardless of theme.
- Web: `src/chronicler-react/src/styles.css` (`:root[data-theme="x"]`).
  iOS: `Theme.swift` + `Electric.swift`. Android: `Theme.kt` + `Electric.kt`.
- **Ransom Note is the only light theme** and doubles as a canary for anything that assumes a
  dark ground.
- Native fonts are bundled TTFs; the web pulls the same faces from Google Fonts.

## Key Design Decisions

- **Native over MAUI**: the MAUI/Blazor hybrid was replaced by three native frontends over one
  shared REST API. The C# backend stays authoritative; the shared-UI idea did not survive
- **Parity is enforced by convention, not code**: every user-facing change ships to web, iOS and
  Android or it isn't done
- **No bookmark feature**: was built, then removed by user request
- **Per-user favorites**: stored in `UserBookFavorite` join table (not on Book model)
- **Covers as DB blobs**: loaded as base64 data URIs to avoid cross-origin WebView issues
- **Admin-curated library**: no user uploads; anything in the Library folder appears automatically
- **Progress tracking**: per-chapter, saved every 10s during playback and immediately on pause
- **IsListened threshold**: chapter marked listened when > 90% complete

## Server Setup

- Machine: `blackbird-mini` (corbin@192.168.1.71)
- Repo path: `~/Servers/chronicler-server/Chronicler`
- Docker Compose manages: `chronicler-api` + `chronicler-web` containers
- Logs: `./logs/` directory, also accessible via `GET /api/logs`
- Diagnostic messages: `POST /api/diag` (used by the native apps for debug logging)
