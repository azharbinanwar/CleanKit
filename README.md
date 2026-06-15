# MacCleanup

A macOS app to reclaim disk space by cleaning developer caches, logs, and system junk — built with SwiftUI.

## Download

Download the latest `.dmg` from [Releases](https://github.com/azharbinanwar/MacCleanup/releases).

1. Open the `.dmg`
2. Drag `MacCleanup.app` to your Applications folder
3. Right-click → Open (first launch only, to bypass Gatekeeper)

## Features

- Live storage bar showing used / free / total disk space
- Scans 27+ storage locations with live per-row progress
- Three groups: **Found** (sorted by size), **Commands** (shell-based cleanup), **Nothing to Clean**
- Sort by largest or smallest first
- **Clean All** or **Choose** specific items with confirmation sheet
- Tracks clean history per category — last cleaned date, times cleaned, space freed
- Refresh / re-scan without restarting the app
- Custom accent color and app icon

## Screenshots

> Coming soon

## Categories Covered

| Category | What it cleans |
|---|---|
| Xcode DerivedData | Build artifacts |
| Xcode Archives | App archives |
| Xcode iOS Device Support | Per-device debug symbols |
| iOS Simulator (Unavailable) | Deleted simulator devices |
| Gradle Caches | Caches, daemon, wrapper dists |
| CocoaPods Cache | Local pod repos |
| Carthage Artifacts | Built Carthage frameworks |
| npm Cache | Node package cache |
| Flutter pub-cache | Dart/Flutter packages |
| Ruby Gems Cache | Gem installations |
| Python pip Cache | pip download cache |
| JetBrains Caches | IntelliJ/Android Studio caches |
| VS Code Cache | Editor cache and cached data |
| Chrome Cache | Browser cache |
| Slack Cache | App and service worker cache |
| Spotify Cache | Music app cache |
| Figma Cache | Offline files |
| Zoom Speech Cache | AI speech models |
| Homebrew Cache | Downloaded bottles |
| QuickLook Thumbnails | Preview thumbnails |
| Mail Attachments Cache | Mail app attachments |
| iOS Backups | iPhone/iPad backups |
| Trash | ~/.Trash |
| All Logs | Google, JetBrains, CoreSimulator, DiagnosticReports |
| Docker System Prune | Unused images/containers |
| Wallpaper Aerials | Apple TV aerial wallpapers |

## Skipped Intentionally

- Android Studio SDK, AVD, NDK — manage these separately to avoid breaking your Android setup

## Requirements

- macOS 15+
- Xcode 26+ (to build from source)

## Build from Source

```bash
git clone https://github.com/azharbinanwar/MacCleanup.git
cd MacCleanup
open MacCleanup.xcodeproj
```

Then in Xcode: select your Mac → `Cmd+R` to run.

> **Note:** App Sandbox is disabled so the app can access all system paths. Not distributed via the App Store.

## Create a Release Build

1. In Xcode: `Product → Archive`
2. `Distribute App → Custom → Copy App`
3. Save `MacCleanup.app` to a folder
4. Create `.dmg`:

```bash
hdiutil create -volname "MacCleanup" -srcfolder MacCleanup.app -ov -format UDZO MacCleanup.dmg
```

5. Upload `MacCleanup.dmg` to a GitHub Release

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT — see [LICENSE](LICENSE)
