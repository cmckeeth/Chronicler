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

## 2026-11-02 — Offline / car fixes (uncommitted)
- Server: progress save no longer returns 500 when two saves for a new chapter race (seen in logs 03:14:48 UTC, chapter 1533). It now updates the row the other request made.
- Android Auto: lists downloaded books when offline, plays chapters from disk, keeps progress in progress.json (dirty when the server didn't get it), and never hands the player an item with no audio (likely crash).
- Android phone: tapping a chapter before positions load no longer crashes. A failed progress save now counts as offline and is kept for later; the offline push keeps entries that fail.
- iOS: same failed-save handling as Android; API calls give up after 15s instead of 60s.
- Not done: no device crash logs were available (no phone connected, no SSH to server, /api/logs only serves today). Web has no offline mode.
- Android casting: a downloaded chapter was handed to the Nest as a file:// on the phone, which it can't read, so nothing played. AudioController now always gives the cast device the stream URL. Player errors now go to /api/diag ("ANDROID vX: PLAYER ERROR ...") so the next cast failure shows up in /api/logs. Unverified on a real speaker.
- Tested 2026-11-02 on the emulator against a local server (test library, test user): server race, phone offline save + resync, early chapter tap, Android Auto offline library/playback/resync all pass. Old Auto code did NOT crash on an undownloaded book offline, so the Auto crash cause is still unknown. iOS and casting untested.
- Found, not fixed: (1) a failed position read (slow signal, >10s) is treated as "never started", so the player opens at 0:00 and the next save can overwrite the real spot. (2) Migrations AddBookIsFavorite + PerUserFavorites have no [Migration]/[DbContext] attributes, so a brand-new database never gets UserBookFavorites and /api/books 500s. Prod is fine; fixing it needs care so prod doesn't re-run them.

## 2026-11-02: Abyss + Arcade themes
- Added two themes to all three apps (now eleven). Web+Android in c5e8dc6 (deployed 3.3.335), iOS in b59d080 (TestFlight build 336).
- Abyss: deep sea, jellyfish, marine snow, lure, giant amber eyes every 14s. Arcade: 8-bit invaders, starfield, INSERT COIN, square yellow panels.
- Untested by eye: archive/player screens on iOS and web in the new themes.

## 2026-11-04: "The archive lies empty" on some devices (investigated, not fixed)
- /api/logs shows the failing devices get 401 (not logged in) on /api/books and /api/collections (18:07, 18:10, 19:17, 19:35 UTC). Working devices get 200.
- Android `ApiClient.kt` turns any non-200 into an empty list, so a rejected login shows "The archive lies empty, traveller." instead of the login screen. Landing "Connected" only checks /api/update/version, which needs no login.
- JWT key unchanged since the first commit, so a restart isn't it. Likely cause: tokens expire after 90 days (`Program.cs` CreateToken) and no app notices. iOS shows "pneumatic tubes have failed: unreachable" on 401; web logs out properly.

## 2026-11-04: Save logins in the phone's password manager (uncommitted)
- TODO "Remember logins and passwords securely". Corbin chose password-manager only: the app never stores the password itself.
- iOS: email/password fields tagged username/password (newPassword when registering). New `Chronicler/Chronicler.entitlements` with `webcredentials:chronicler.mckeeth.app`, wired into both build configs.
- API: serves `/.well-known/apple-app-site-association` (team ZSTUXP8336 + bundle id), so iOS trusts the link between site and app. The public domain goes to the API, not nginx.
- Android: Credential Manager (`androidx.credentials` 1.3.0). The login screen offers a saved login when it opens (picking one signs in), and offers to save after a typed sign-in.
- Web: `autocomplete` username / current-password / new-password on the form.
- Verified: all four build; local API returns the AASA JSON; the iOS sim build carries the entitlement. NOT verified on a real phone. The first TestFlight build may need the Associated Domains capability turned on for the App ID (automatic signing should do it).
- Deployed 2026-11-04: commit 67e4c51 pushed; server deploy 3.3.338 (API + web + Android); AASA live at https://chronicler.mckeeth.app/.well-known/apple-app-site-association. TestFlight upload started from the same commit.

## 2026-11-04: Archive forgets tab / filters / search on back (commit 9d5b471, not pushed)
- Cause: state lived in the screen, which is rebuilt after opening a book (Android `remember`, web unmount) or leaving to Landing / theme switch (iOS).
- Fix: `ArchiveFilters` holder (Kotlin object, Swift enum with statics, module-level object in Library.jsx) lasting for the app session. Not kept across a full restart or page reload.
- Builds on all three; not clicked through on a device. Scroll position is still not kept.
- Shipped 9d5b471: server deploy 3.3.339 (web + Android); TestFlight build 339 uploading.

## 2026-11-04: Favorites tab (commit after 9d5b471, not pushed)
- Collections can be starred: `UserCollectionFavorites` table (migration 20261104210127, generated by dotnet-ef, only creates the table), `POST /api/collections/{id}/favorite`, `isFavorite` on collection list + detail.
- Archive tabs are now ★ Favorites / Books / Collections on all three apps. Favorites = starred collections + starred books together, and is the default tab. The old Books-tab favorites chip is gone.
- Starring a collection: long-press on iOS/Android (same as books), the ★ button on web.
- Tested: local API toggle + list on a fresh DB; all four build. Not clicked through on a device.
- Shipped 728ff10: server deploy 3.3.340 (API + web + Android); TestFlight build 340 uploading.

## 2026-11-05: Recently Listened in the Archive (commit f74fe57, pushed, deployed as 3.3.342)

- API: `GET /api/books/recent` returns the book whose chapter progress this user saved last
  (newest `ChapterProgress.UpdatedAt`), or 204 if none. Tested against a throwaway server.
- Web, iOS, Android: a "Recently Listened" heading plus one wide book card at the top of the
  Archive, on every tab, hidden while searching. All three build.
- Found, not fixed: `Migrations/20260522210000_PerUserFavorites.cs` has no Designer file, so EF
  never runs it and a brand-new database has no `UserBookFavorites` table. Production is fine.
- Committed only the feature's lines. Left uncommitted: the iOS `baseURL` pointing at (since reverted to the public URL)
  `127.0.0.1:5199`, the iOS long-press `contextMenu` fix, and the password-manager login work.
- iOS was shipped from a clean worktree of HEAD so the local `baseURL` could not leak into TestFlight.
- Later the same day: pushed 8e75f46 (iOS press-and-hold favorites via contextMenu) and 038072e
  (iOS PasswordKeeper: save + offer login through the Passwords app). Not yet on TestFlight.
  Removed the uncommitted Info.plist `NSAllowsLocalNetworking` setting (only served the old local test server).

## 2026-11-06: Startup sounds for the 8 themes that had none (f737a6d, shipped as 3.3.345)

Before: only tesla (generic `startup.mp3`), steampunk, garden had sounds; the other 8 themes fell
back to the Tesla sound. Added `startup_<theme>.mp3` to `Chronicler/Chronicler/` and
`android/app/src/main/res/raw/`. No code change: both apps already look up `startup_<theme>`.
Web has no sounds, by Corbin's choice. All CC0 from Freesound except neon (made with sox):
academia 840192 page turn · noir 237391 match strike · west 213925 pistol ricochet ·
forge 270589 anvil hit · ransom 397609 scissors cutting paper · abyss 808185 sonar ping ·
arcade 647977 8-bit coin/power-up · neon = synthesized A-minor saw chord swell.
Levelled to about -18 LUFS (noir -26: one sharp strike plus a quiet tail).
