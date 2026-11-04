# TODO

## CI/CD
- [ ] Revisit GitHub Actions workflow — decide if auto-deploy on push is wanted or if the deploy webhook is sufficient
- [ ] If keeping workflow, figure out cmckeeth token/workflow scope so it can be pushed normally

## Features
- [ ] Upload UI for adding audiobooks via the web app (admin)
- [ ] Book duration auto-detection on library scan (read audio file metadata)
- [ ] Chapter support for M4B files

## Authentication and sessions
- [x] Remember logins and passwords securely using platform credential storage (2026-11-04,
      3.3.338: iOS Passwords app, Android Credential Manager, browser password manager; the app
      itself never stores the password)
- [ ] Try the password save/fill prompts on a real iPhone and Android phone (untested on devices)
- [ ] Evaluate enabling single sign-on (SSO)
- [ ] Force logout after app updates and prompt the user to sign in again
- [ ] Handle expired or invalid logins by prompting for sign-in instead of showing an empty archive.
      Logins expire after 90 days. Android turns the server's 401 into an empty list ("The archive
      lies empty, traveller."); iOS shows "pneumatic tubes have failed: unreachable". Web already
      sends you to the login page
- [ ] Log why the server rejected a login (expired vs. bad token), so `/api/logs` shows the reason

## Build
- [ ] Generate a release keystore and configure signing so APK can be built in Release mode
- [ ] Swift 6 readiness: `CoverCache` calls `Downloads.entry/saveCover/coverData` across an actor
      boundary. Warnings today, hard errors under the Swift 6 language mode
- [ ] `pick()` / `byTheme()` are now eleven positional args. Overdue for a refactor to per-theme
      palette structs

## Offline / parity
- [ ] Web has no offline capability at all — would need a service worker + IndexedDB to match
      the native Local Downloads
- [ ] Verify the iOS `.audio` → `.mp3` download migration on a real device (only exercised in
      the simulator)
- [ ] Per-theme startup sounds for Dark Academia, Blackletter Noir, Wild West, Neon Sunset,
      Molten Forge, Ransom Note, Abyss and Arcade — the `startup_<mode>.mp3` hook exists, the files don't

## Archive
- [x] Keep the tab, filters and search when coming back to the Archive (2026-11-04, 3.3.339)
- [x] Favorites tab with starred books and collections together, opened by default (2026-11-04, 3.3.340)
- [ ] Keep the scroll position when coming back from a book (still jumps to the top)
- [ ] Consider showing the Favorites / Books / Collections tabs without opening "Filters" first

## Bugs found, not fixed
- [ ] A slow position read (over 10s) is treated as "never started", so the player opens at 0:00
      and the next save can overwrite the real spot
- [ ] Migrations `AddBookIsFavorite` and `PerUserFavorites` have no `[Migration]`/`[DbContext]`
      attributes, so a brand-new database never gets `UserBookFavorites` and `/api/books` returns
      500. Prod is fine; fixing it needs care so prod doesn't re-run them

## Polish
- [ ] Update ApiConfig.cs base URLs (Plex, PhotoPrism, Chronicler) when server IP changes
