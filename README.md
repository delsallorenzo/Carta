# Carta

Carta is a minimal macOS notes app with a Terminal-inspired reading and editing experience.

## Features

- Always-on-top floating window
- Persistent rich-text notes
- Terminal-like line snapping and column/row window sizing
- Up to 5 notes managed from the menu bar
- Keyboard shortcuts for bold, italic, underline, strikethrough, and text size
- Light mode and dark mode support

## Run Locally

```bash
swift run
```

If your local Swift cache is polluted by another project, use:

```bash
CLANG_MODULE_CACHE_PATH=/tmp/carta-module-cache swift run --build-path /tmp/carta-build
```

## Build a Standalone App

Create a local `.app` bundle and `.dmg`:

```bash
./Scripts/package_macos.sh
```

Artifacts are written to:

- `dist/Carta.app`
- `dist/Carta.dmg`

## GitHub Releases

This repository includes a GitHub Actions workflow that builds a macOS release artifact and uploads a `.dmg` to GitHub Releases.

The app icon source is stored at `Assets/icon.png`.

To publish a release manually:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or create a release directly with the GitHub CLI after building locally.

## Notes

- The distributed app can be packaged without notarization, but macOS may still show a Gatekeeper warning on first launch unless it is signed and notarized with an Apple Developer account.
- `Carta` remains a Swift Package project; the release pipeline assembles the `.app` bundle during packaging.
