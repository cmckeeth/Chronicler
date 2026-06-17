# Chronicler — Project Context

Personal audiobook library app. Built by Corbin McKeeth with Claude Code.

## Stack

| Layer | Tech |
|-------|------|
| API | ASP.NET Core minimal API (.NET 10), SQLite via EF Core, ASP.NET Identity, JWT auth |
| Mobile | .NET MAUI Blazor Hybrid (Android + iOS) |
| Web | React + Vite (separate app in `src/chronicler-react/`) |
| Shared UI | Blazor Razor components (`Chronicler.Shared`) used by MAUI only |
| Hosting | Docker Compose on home server (192.168.1.71) |

## Projects

```
src/
  Chronicler.Api/          — ASP.NET Core API + EF Core + migrations
  Chronicler.Shared/       — Blazor components, services, CSS (used by MAUI)
  Chronicler.Maui/         — MAUI shell (Android + iOS)
  chronicler-react/        — React web app (Vite, served by nginx in Docker)
```

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
- MAUI: stored in `SecureStorage` with key `chronicler_token`
- Web (React): stored in `localStorage`
- Password requirements: 6+ chars, no special character requirements

## Audio

### Android
- `NativeAudioPlayerService` using `Android.Media.MediaPlayer`
- `MediaPlaybackRequiresUserGesture = false` set on WebView via `ChroniclerWebViewHandler`
- Checks for local downloads before streaming; uses local file path if available

### iOS
- `iOSAudioPlayerService` using `AVFoundation.AVPlayer`
- `AVAudioSession.CategoryPlayback` configured on first play (plays through speaker, ignores mute switch)
- Also checks local downloads first

### Web (HTML5 fallback)
- Used when no `IAudioPlayerService` is registered (browser)
- `chronicler.js` handles play/pause/seek/rate/events
- `timeupdate` throttled to 250ms to avoid bridge flooding

### Service registration (MauiProgram.cs)
```csharp
#if ANDROID
    AddSingleton<IAudioPlayerService, NativeAudioPlayerService>()
#elif IOS
    AddSingleton<IAudioPlayerService, iOSAudioPlayerService>()
#endif
```

## Downloads (offline)

- `IDownloadService` / `MauiDownloadService` — MAUI only (not on web)
- Files stored in `FileSystem.AppDataDirectory/downloads/`
- JSON manifest tracks chapter → local file path mapping
- Download page at `/downloads` (MAUI only)

## Library Scanner

- Books discovered from `/app/Library` (mounted from host: `/mnt/media/4tb-media/AudioBooks`)
- Background scan every 20 minutes (`LibraryScanService`)
- Manual scan trigger via API: `POST /api/library/scan`
- `meta.json` in book directories read only on first discovery (not overwritten on rescan)
- Cover images stored as byte blobs in DB

## Versioning & OTA Updates

### Android
- Deploy script on server auto-increments patch version based on highest APK in `updates/`
- `deploy.sh` on server: bumps version, builds APK, restarts Docker
- Webhook (`webhook.py`) triggers `git pull && ./deploy.sh` on POST to `:5162/deploy`
- APK served at `/api/update/apk`, version at `/api/update/version`
- MAUI app checks version on startup, shows update banner if newer available
- Update banner only shown on Android (`DeviceInfo.Platform == Android`)

### iOS
- Manual USB build+deploy — use `/update-chronicler-ios` skill
- Version synced from server at build time via `-p:ApplicationDisplayVersion=$VER`
- Free Apple Developer account: app expires every 7 days, re-run skill to renew
- Device UDID: `00008120-001C3D20216BC01E` (Hannah's iPhone)
- Signing: `Apple Development: corbin.mckeeth@gmail.com (RXQYCD389C)`
- Provisioning: `iOS Team Provisioning Profile: blackbird.llc.Chronicler`
- .NET 10 SDK at `/usr/local/share/dotnet/dotnet` (not homebrew `dotnet`)

## Styling

- Steampunk aesthetic: brass/copper/parchment palette + electric lime green accents
- Main CSS: `src/Chronicler.Shared/wwwroot/steampunk.css`
- MAUI-specific overrides: `src/Chronicler.Maui/wwwroot/css/app.css`
- Fonts: Cinzel Decorative (titles), Cinzel (UI), Lora (body)
- Playing state: slow green pulse animation on transmission controls box

## Key Design Decisions

- **MAUI over native Android/iOS**: single C# codebase preference
- **Blazor for MAUI, React for web**: Blazor components reused in MAUI; separate React app for browser (switched from Blazor web due to circuit connection issues)
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
- Diagnostic messages: `POST /api/diag` (used by MAUI for debug logging)
