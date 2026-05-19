# TODO

## CI/CD
- [ ] Revisit GitHub Actions workflow — decide if auto-deploy on push is wanted or if deploy.sh is sufficient
- [ ] If keeping workflow, figure out cmckeeth token/workflow scope so it can be pushed normally

## Features
- [ ] Upload UI for adding audiobooks via the web app (admin)
- [ ] Persist auth token across app restarts (currently lost on reload)
- [ ] Book duration auto-detection on library scan (read audio file metadata)
- [ ] Chapter support for M4B files

## Build
- [ ] Generate a release keystore and configure signing so APK can be built in Release mode

## Polish
- [ ] Update ApiConfig.cs base URLs (Plex, PhotoPrism, Chronicler) when server IP changes
