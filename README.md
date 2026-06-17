# CleanKit

A macOS developer toolkit to reclaim disk space — built with SwiftUI. Cleans developer caches, app caches, system junk, and logs with live per-row scan progress.

## Download

Download the latest `.dmg` from [Releases](https://github.com/azharbinanwar/MacCleanup/releases).

1. Open the `.dmg`
2. Drag `CleanKit.app` to your Applications folder
3. Right-click → Open (first launch only, to bypass Gatekeeper)

## Features

- Dashboard with live disk storage bar (used / free / total)
- Sidebar navigation between tools
- Scans 45+ locations across Developer, Apps, System, and Logs groups
- Live per-row scan progress with size and file count
- Sort by largest or smallest first
- Clean All or choose specific items with confirmation
- Tracks clean history per category — last cleaned date, times cleaned, space freed
- Done screen with full summary of what was freed per group
- Re-scan without restarting the app
- Custom accent color and app icon

## Screenshots

> Coming soon

## Categories Covered

### Developer
| Category | What it cleans |
|---|---|
| Xcode DerivedData | Build artifacts |
| Xcode Archives | App archives |
| Xcode iOS Device Support | Per-device debug symbols |
| Xcode Cache | Xcode and build system caches |
| Gradle Caches | Caches, daemon, wrapper dists |
| CocoaPods Cache | Local pod repos |
| Carthage Artifacts | Built Carthage frameworks |
| npm Cache | Node package cache |
| Yarn Cache | Yarn package cache |
| pnpm Store | pnpm content-addressable store |
| Flutter pub-cache | Dart/Flutter packages |
| FVM SDK Cache | Flutter version manager SDK caches (all versions) |
| nvm Cache | Node.js downloaded tarballs |
| sdkman Archives | Java/Kotlin SDK zip archives |
| asdf Downloads | Universal version manager downloads |
| pyenv Cache | Python source tarballs |
| Ruby Gems Cache | Gem installations |
| Python pip Cache | pip download cache |
| Maven Local Repo | Java Maven repository |
| Cargo Registry Cache | Rust crate registry cache |
| Go Module Cache | Go module download cache |
| Android AVD | Android emulator virtual devices |
| Android Cache | Android SDK cache |
| JetBrains Caches | IntelliJ/Android Studio caches |
| VS Code Cache | Editor cache and cached data |

### Apps
| Category | What it cleans |
|---|---|
| Chrome Cache | Browser cache |
| Slack Cache | App and service worker cache |
| Spotify Cache | Music app cache |
| Figma Cache | Offline files |
| Zoom Speech Cache | AI speech models |

### System
| Category | What it cleans |
|---|---|
| Library/Caches (All Apps) | All user app caches |
| Homebrew Cache | Downloaded bottles |
| QuickLook Thumbnails | Preview thumbnails |
| Mail Attachments Cache | Mail app attachments |
| iOS Backups | iPhone/iPad backups via Finder |
| Trash | ~/.Trash |
| Wallpaper Aerials | Apple TV aerial wallpapers |
| Safari Cache | Safari browser cache |
| Music Cache | Apple Music cache |
| App Store Cache | App Store download cache |
| Translation Cache | Translate app offline data |
| Game Center Cache | Game Center cache |

### Logs & Commands
| Category | What it cleans |
|---|---|
| All Logs | Google, JetBrains, CoreSimulator, DiagnosticReports |
| iOS Simulator (Unavailable) | `xcrun simctl delete unavailable` |
| Docker System Prune | `docker system prune -f` |

## Requirements

- macOS 15+
- Xcode 26+ (to build from source)

## Build from Source

```bash
git clone https://github.com/azharbinanwar/MacCleanup.git
cd CleanKit
open CleanKit.xcodeproj
```

Then in Xcode: select your Mac → `Cmd+R` to run.

> **Note:** App Sandbox is disabled so the app can access all system paths. Not distributed via the App Store.

## Create a Release Build

1. In Xcode: `Product → Archive`
2. `Distribute App → Custom → Copy App`
3. Save `CleanKit.app` to a folder
4. Create `.dmg`:

```bash
hdiutil create -volname "CleanKit" -srcfolder CleanKit.app -ov -format UDZO CleanKit.dmg
```

5. Upload `CleanKit.dmg` to a GitHub Release

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT — see [LICENSE](LICENSE)
