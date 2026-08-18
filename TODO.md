# TODO

## CI/CD
- [ ] Revisit GitHub Actions workflow — decide if auto-deploy on push is wanted or if the deploy webhook is sufficient
- [ ] If keeping workflow, figure out cmckeeth token/workflow scope so it can be pushed normally

## Features
- [ ] Upload UI for adding audiobooks via the web app (admin)
- [ ] Re-add auth when needed (currently removed — app is open access)
- [ ] Book duration auto-detection on library scan (read audio file metadata)
- [ ] Chapter support for M4B files

## Build
- [ ] Generate a release keystore and configure signing so APK can be built in Release mode
- [ ] Swift 6 readiness: `CoverCache` calls `Downloads.entry/saveCover/coverData` across an actor
      boundary. Warnings today, hard errors under the Swift 6 language mode
- [ ] `pick()` / `byTheme()` are nine positional args. A tenth theme should force a refactor to
      per-theme palette structs

## Offline / parity
- [ ] Web has no offline capability at all — would need a service worker + IndexedDB to match
      the native Local Downloads
- [ ] Verify the iOS `.audio` → `.mp3` download migration on a real device (only exercised in
      the simulator)
- [ ] Per-theme startup sounds for Dark Academia, Blackletter Noir, Wild West, Neon Sunset,
      Molten Forge and Ransom Note — the `startup_<mode>.mp3` hook exists, the files don't

## Polish
- [ ] Update ApiConfig.cs base URLs (Plex, PhotoPrism, Chronicler) when server IP changes
