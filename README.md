# CleanKit

A free, open-source Mac cleaner and developer toolkit for macOS.

![Dashboard](screenshots/dashboard.png)

CleanKit helps you reclaim disk space and keep your Mac clean. It scans developer caches, system junk, large files, duplicate files, and leftover app data — all in one place.

---

## Features

### Mac Cleaner
Scan and clean 55 categories across Developer tools, Apps, System, Logs, and Commands.

![Mac Cleaner](screenshots/mac-cleaner.png)

### Large File Finder
Find files taking up the most space. Filter by type, sort by size, and delete with one click.

![Large File Finder](screenshots/large-file-finder.png)

### Duplicate Finder
3-pass content hashing to find exact duplicates. Choose what to keep — rest gets deleted.

![Duplicate Finder](screenshots/duplicate-finder.png)

### App Uninstaller
Remove apps along with their leftover preference files, caches, and support data.

![App Uninstaller](screenshots/app-uninstaller.png)

### Settings
Control which categories appear, set large file thresholds, configure duplicate scan limits, and switch between Light, Dark, or System theme.

![Settings](screenshots/settings.png)

---

## Install

1. Download `CleanKit.dmg` from [Releases](https://github.com/azharbinanwar/CleanKit/releases)
2. Open the DMG and drag **CleanKit** to your Applications folder
3. Launch CleanKit from Applications

> **Note:** CleanKit is not notarized. On first launch, right-click the app and choose **Open** to bypass Gatekeeper.

---

## Build from Source

```bash
git clone https://github.com/azharbinanwar/CleanKit.git
cd CleanKit
open CleanKit.xcodeproj
```

Requires Xcode 16+ and macOS 15.0+.

---

## License

MIT — see [LICENSE](LICENSE)
