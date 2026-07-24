import Foundation

/// How risky a category is to clean — drives the badge colour and helps the
/// user decide. safe = regenerates locally at no cost; caution = will
/// re-download over the network next time; data = real user content, gone for good.
enum CategorySafety: String {
    case safe
    case caution
    case data

    var label: String {
        switch self {
        case .safe:    return "Safe"
        case .caution: return "Re-downloads"
        case .data:    return "Your data"
        }
    }
}

struct CleanupCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let paths: [String]
    let subpath: String?
    let shellCommand: String?
    var info: String = ""
    var safety: CategorySafety = .safe
    var sizeBytes: Int64 = 0
    var fileCount: Int = 0
    var freedBytes: Int64 = 0
    var cleaned: Bool = false
    var isAccessDenied: Bool = false
    var requiresElevation: Bool = false

    /// Auto-hide: only show a category when it's actually relevant to THIS Mac —
    /// a path that exists on disk, or a shell command whose tool is installed.
    var exists: Bool {
        if name == "Trash" || name == "Library/Caches (All Apps)" { return true }
        if paths.isEmpty, let cmd = shellCommand {
            return Self.toolAvailable(for: cmd)
        }
        let fm = FileManager.default
        for raw in paths {
            let base = (raw as NSString).expandingTildeInPath
            if let sub = subpath {
                let children = (try? fm.contentsOfDirectory(atPath: base)) ?? []
                for child in children where fm.fileExists(atPath: "\(base)/\(child)/\(sub)") {
                    return true
                }
            } else if fm.fileExists(atPath: base) {
                return true
            }
        }
        return false
    }

    /// Is the first word of `command` an executable we can find on PATH?
    static func toolAvailable(for command: String) -> Bool {
        let tool = command.split(whereSeparator: { $0 == " " }).first.map(String.init) ?? ""
        if tool == "empty-trash" { return true }
        let dirs = ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin", "/usr/sbin", "/sbin"]
        let fm = FileManager.default
        return dirs.contains { fm.isExecutableFile(atPath: "\($0)/\(tool)") }
    }

    static let all: [CleanupCategory] = [
        // MARK: Developer - Xcode
        CleanupCategory(name: "iOS Simulator (Unavailable)", icon: "iphone.slash", paths: [], subpath: nil, shellCommand: "xcrun simctl delete unavailable", info: "Deletes simulators macOS marked unavailable.", safety: .safe, requiresElevation: false),
        CleanupCategory(name: "Xcode DerivedData", icon: "hammer", paths: ["~/Library/Developer/Xcode/DerivedData"], subpath: nil, shellCommand: nil, info: "Build cache. Xcode rebuilds it on the next build.", safety: .safe),
        CleanupCategory(name: "Xcode Archives", icon: "archivebox", paths: ["~/Library/Developer/Xcode/Archives"], subpath: nil, shellCommand: nil, info: "Saved app archives for distribution. You may still need these.", safety: .data),
        CleanupCategory(name: "Xcode iOS Device Support", icon: "externaldrive", paths: ["~/Library/Developer/Xcode/iOS DeviceSupport"], subpath: nil, shellCommand: nil, info: "Debug symbols per iOS version. Re-downloads when you plug a device.", safety: .caution),
        CleanupCategory(name: "Xcode watchOS Device Support", icon: "applewatch", paths: ["~/Library/Developer/Xcode/watchOS DeviceSupport"], subpath: nil, shellCommand: nil, info: "Debug symbols per watchOS version. Re-downloads when needed.", safety: .caution),
        CleanupCategory(name: "Xcode tvOS Device Support", icon: "appletv", paths: ["~/Library/Developer/Xcode/tvOS DeviceSupport"], subpath: nil, shellCommand: nil, info: "Debug symbols per tvOS version. Re-downloads when needed.", safety: .caution),
        CleanupCategory(name: "Xcode Previews", icon: "eye", paths: ["~/Library/Developer/Xcode/UserData/Previews"], subpath: nil, shellCommand: nil, info: "SwiftUI preview cache. Rebuilds automatically.", safety: .safe),
        CleanupCategory(name: "Simulator Caches", icon: "iphone.gen3", paths: ["~/Library/Developer/CoreSimulator/Caches"], subpath: nil, shellCommand: nil, info: "Simulator runtime/dyld cache. Xcode rebuilds it.", safety: .safe),
        CleanupCategory(name: "Xcode Cache", icon: "hammer.circle", paths: ["~/Library/Caches/com.apple.dt.Xcode", "~/Library/Caches/com.apple.dt.xcodebuild", "~/Library/Caches/com.apple.dt.Xcode.ITunesSoftwareService"], subpath: nil, shellCommand: nil, info: "Xcode's own cache files. Safe to clear.", safety: .safe),

        // MARK: Developer - Build Tools
        CleanupCategory(name: "Gradle Caches", icon: "gearshape.2", paths: ["~/.gradle/caches", "~/.gradle/daemon", "~/.gradle/wrapper/dists"], subpath: nil, shellCommand: nil, info: "Android/Gradle build cache. Re-downloads dependencies.", safety: .caution),
        CleanupCategory(name: "CocoaPods Cache", icon: "shippingbox.fill", paths: ["~/.cocoapods/repos"], subpath: nil, shellCommand: nil, info: "Pod spec repos. Re-downloads on next pod install.", safety: .caution),
        CleanupCategory(name: "Carthage Artifacts", icon: "cart", paths: ["~/Library/Caches/org.carthage"], subpath: nil, shellCommand: nil, info: "Carthage build cache. Rebuilds on next run.", safety: .safe),

        // MARK: Developer - Package Managers
        CleanupCategory(name: "npm Cache", icon: "shippingbox", paths: ["~/.npm"], subpath: nil, shellCommand: nil, info: "npm package cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Yarn Cache", icon: "shippingbox.fill", paths: ["~/.yarn/cache"], subpath: nil, shellCommand: nil, info: "Yarn package cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "pnpm Store", icon: "shippingbox.and.arrow.backward.fill", paths: ["~/.pnpm-store", "~/Library/pnpm/store"], subpath: nil, shellCommand: nil, info: "pnpm package store. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Flutter pub-cache", icon: "wind", paths: ["~/.pub-cache"], subpath: nil, shellCommand: nil, info: "Flutter/Dart package cache. Re-downloads on pub get.", safety: .caution),
        CleanupCategory(name: "FVM SDK Cache", icon: "f.circle", paths: ["~/fvm/versions"], subpath: "bin/cache", shellCommand: nil, info: "Flutter SDK build caches per version. Rebuilds.", safety: .safe),
        CleanupCategory(name: "nvm Cache", icon: "n.circle", paths: ["~/.nvm/.cache"], subpath: nil, shellCommand: nil, info: "Node version cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "sdkman Archives", icon: "s.circle", paths: ["~/.sdkman/archives"], subpath: nil, shellCommand: nil, info: "Downloaded SDK archives. Re-downloads when needed.", safety: .caution),
        CleanupCategory(name: "asdf Downloads", icon: "arrow.down.circle", paths: ["~/.asdf/downloads"], subpath: nil, shellCommand: nil, info: "asdf tool downloads. Re-downloads when needed.", safety: .caution),
        CleanupCategory(name: "pyenv Cache", icon: "p.square", paths: ["~/.pyenv/cache"], subpath: nil, shellCommand: nil, info: "Python build cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Conda Packages", icon: "circle.grid.cross", paths: ["~/miniconda3/pkgs", "~/anaconda3/pkgs", "~/.conda/pkgs"], subpath: nil, shellCommand: nil, info: "Cached conda packages. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Ruby Gems Cache", icon: "r.circle", paths: ["~/.gem"], subpath: nil, shellCommand: nil, info: "Ruby gem cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Python pip Cache", icon: "p.circle", paths: ["~/Library/Caches/pip"], subpath: nil, shellCommand: nil, info: "pip package cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Maven Local Repo", icon: "m.circle", paths: ["~/.m2/repository"], subpath: nil, shellCommand: nil, info: "Downloaded Maven dependencies. Re-downloads on build.", safety: .caution),
        CleanupCategory(name: "Cargo Registry Cache", icon: "c.circle", paths: ["~/.cargo/registry/cache"], subpath: nil, shellCommand: nil, info: "Rust crate cache. Re-downloads on build.", safety: .caution),
        CleanupCategory(name: "Go Module Cache", icon: "g.circle", paths: ["~/go/pkg/mod/cache"], subpath: nil, shellCommand: nil, info: "Go module cache. Re-downloads on build.", safety: .caution),
        CleanupCategory(name: "Swift Package Manager", icon: "swift", paths: ["~/.swiftpm/cache", "~/Library/Caches/org.swift.swiftpm"], subpath: nil, shellCommand: nil, info: "SwiftPM dependency cache. Re-resolves on build.", safety: .caution),
        CleanupCategory(name: "Deno Cache", icon: "d.circle", paths: ["~/.deno/deps"], subpath: nil, shellCommand: nil, info: "Deno dependency cache. Re-downloads on run.", safety: .caution),
        CleanupCategory(name: "Bun Cache", icon: "b.circle", paths: ["~/.bun/cache"], subpath: nil, shellCommand: nil, info: "Bun package cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Composer Cache", icon: "c.square", paths: ["~/.composer/cache"], subpath: nil, shellCommand: nil, info: "PHP Composer cache. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Helm Cache", icon: "helm", paths: ["~/.cache/helm"], subpath: nil, shellCommand: nil, info: "Helm chart cache. Rebuilds on next use.", safety: .safe),
        CleanupCategory(name: "Terraform Plugin Cache", icon: "server.rack", paths: ["~/.terraform.d/plugin-cache"], subpath: nil, shellCommand: nil, info: "Terraform provider plugins. Re-downloads on init.", safety: .caution),
        CleanupCategory(name: "Playwright Browsers", icon: "theatermasks", paths: ["~/Library/Caches/ms-playwright"], subpath: nil, shellCommand: nil, info: "Downloaded test browsers. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "Android AVD", icon: "candybarphone", paths: ["~/.android/avd"], subpath: nil, shellCommand: nil, info: "Android emulator disk images. Real virtual devices.", safety: .data),
        CleanupCategory(name: "Android Cache", icon: "a.circle", paths: ["~/.android/cache"], subpath: nil, shellCommand: nil, info: "Android SDK cache. Safe to clear.", safety: .safe),

        // MARK: Developer - IDEs
        CleanupCategory(name: "JetBrains Caches", icon: "j.circle", paths: ["~/Library/Caches/JetBrains"], subpath: nil, shellCommand: nil, info: "IntelliJ/Android Studio caches. Rebuild on open.", safety: .safe),
        CleanupCategory(name: "VS Code Cache", icon: "chevron.left.forwardslash.chevron.right", paths: ["~/Library/Application Support/Code/Cache", "~/Library/Application Support/Code/CachedData"], subpath: nil, shellCommand: nil, info: "VS Code cache. Rebuilds on next launch.", safety: .safe),
        CleanupCategory(name: "VS Code Updater", icon: "arrow.triangle.2.circlepath", paths: ["~/Library/Caches/com.microsoft.VSCode.ShipIt"], subpath: nil, shellCommand: nil, info: "Old VS Code update installers. Safe to clear.", safety: .safe),
        CleanupCategory(name: "Cursor Cache", icon: "cursorarrow.rays", paths: ["~/Library/Application Support/Cursor/Cache", "~/Library/Application Support/Cursor/CachedData"], subpath: nil, shellCommand: nil, info: "Cursor editor cache. Rebuilds on next launch.", safety: .safe),

        // MARK: Browsers
        CleanupCategory(name: "Chrome Cache", icon: "globe", paths: ["~/Library/Caches/Google/Chrome", "~/Library/Application Support/Google/Chrome/Default/OptGuideOnDeviceModel"], subpath: nil, shellCommand: nil, info: "Browser cache + on-device AI model. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Edge Cache", icon: "globe.americas", paths: ["~/Library/Caches/com.microsoft.edgemac", "~/Library/Application Support/Microsoft Edge/Default/Cache", "~/Library/Application Support/Microsoft Edge/Default/Code Cache"], subpath: nil, shellCommand: nil, info: "Edge browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Arc Cache", icon: "arc.fill", paths: ["~/Library/Application Support/Arc/User Data/Default/Cache", "~/Library/Application Support/Arc/User Data/Default/Code Cache"], subpath: nil, shellCommand: nil, info: "Arc browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Brave Cache", icon: "shield", paths: ["~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache", "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Code Cache"], subpath: nil, shellCommand: nil, info: "Brave browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Firefox Cache", icon: "flame", paths: ["~/Library/Caches/Firefox"], subpath: nil, shellCommand: nil, info: "Firefox browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Opera Cache", icon: "o.circle", paths: ["~/Library/Caches/com.operasoftware.Opera", "~/Library/Application Support/com.operasoftware.Opera/Cache"], subpath: nil, shellCommand: nil, info: "Opera browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Vivaldi Cache", icon: "v.circle", paths: ["~/Library/Application Support/Vivaldi/Default/Cache", "~/Library/Application Support/Vivaldi/Default/Code Cache"], subpath: nil, shellCommand: nil, info: "Vivaldi browser cache. Logins and bookmarks kept.", safety: .safe),
        CleanupCategory(name: "Chromium Cache", icon: "globe.badge.chevron.backward", paths: ["~/Library/Caches/Chromium", "~/Library/Application Support/Chromium/Default/Cache"], subpath: nil, shellCommand: nil, info: "Chromium browser cache. Logins and bookmarks kept.", safety: .safe),

        // MARK: Desktop Apps
        CleanupCategory(name: "Claude Cache", icon: "sparkles", paths: ["~/Library/Application Support/Claude/Cache", "~/Library/Application Support/Claude/Code Cache"], subpath: nil, shellCommand: nil, info: "Claude app cache. Rebuilds on next launch.", safety: .safe),
        CleanupCategory(name: "Slack Cache", icon: "message", paths: ["~/Library/Application Support/Slack/Cache", "~/Library/Application Support/Slack/Service Worker/CacheStorage"], subpath: nil, shellCommand: nil, info: "Slack cache. Re-syncs on next launch.", safety: .safe),
        CleanupCategory(name: "Discord Cache", icon: "bubble.left.and.bubble.right", paths: ["~/Library/Application Support/discord/Cache", "~/Library/Application Support/discord/Code Cache"], subpath: nil, shellCommand: nil, info: "Discord cache. Re-syncs on next launch.", safety: .safe),
        CleanupCategory(name: "Microsoft Teams Cache", icon: "person.2", paths: ["~/Library/Application Support/Microsoft/Teams/Cache", "~/Library/Group Containers/UBF8T346G9.com.microsoft.teams/Library/Application Support/Microsoft/MSTeams/Cache"], subpath: nil, shellCommand: nil, info: "Teams cache. Re-syncs on next launch.", safety: .safe),
        CleanupCategory(name: "Notion Cache", icon: "note.text", paths: ["~/Library/Application Support/Notion/Cache", "~/Library/Application Support/Notion/GPUCache"], subpath: nil, shellCommand: nil, info: "Notion cache. Re-syncs on next launch.", safety: .safe),
        CleanupCategory(name: "Postman Cache", icon: "paperplane", paths: ["~/Library/Application Support/Postman/Cache", "~/Library/Application Support/Postman/Code Cache"], subpath: nil, shellCommand: nil, info: "Postman cache. Rebuilds on next launch.", safety: .safe),
        CleanupCategory(name: "Spotify Cache", icon: "music.note", paths: ["~/Library/Caches/com.spotify.client"], subpath: nil, shellCommand: nil, info: "Offline song cache. Re-streams as you listen.", safety: .safe),
        CleanupCategory(name: "Figma Cache", icon: "pencil.and.ruler", paths: ["~/Library/Application Support/Figma/OfflineFiles"], subpath: nil, shellCommand: nil, info: "Figma offline file cache. Re-syncs from cloud.", safety: .safe),
        CleanupCategory(name: "Dropbox Cache", icon: "cube.box", paths: ["~/.dropbox/cache"], subpath: nil, shellCommand: nil, info: "Dropbox deleted-file cache. Safe to clear.", safety: .safe),
        CleanupCategory(name: "Adobe Cache", icon: "a.square", paths: ["~/Library/Caches/Adobe", "~/Library/Application Support/Adobe/Common/Media Cache Files"], subpath: nil, shellCommand: nil, info: "Adobe media/preview cache. Rebuilds on use.", safety: .safe),
        CleanupCategory(name: "Zoom Speech Cache", icon: "mic", paths: ["~/Library/Application Support/zoom.us/SpeechLibrary"], subpath: nil, shellCommand: nil, info: "Zoom speech cache. Rebuilds on use.", safety: .safe),

        // MARK: AI Tools
        CleanupCategory(name: "HuggingFace Cache", icon: "brain", paths: ["~/.cache/huggingface"], subpath: nil, shellCommand: nil, info: "Downloaded ML models and datasets. Large, re-downloads.", safety: .caution),
        CleanupCategory(name: "PyTorch Cache", icon: "flame.circle", paths: ["~/.cache/torch"], subpath: nil, shellCommand: nil, info: "Cached PyTorch models. Re-downloads when needed.", safety: .caution),
        CleanupCategory(name: "Ollama Models", icon: "cpu", paths: ["~/.ollama/models"], subpath: nil, shellCommand: nil, info: "Your downloaded LLMs. Real data, re-download to use again.", safety: .data),

        // MARK: Gaming
        CleanupCategory(name: "Steam Cache", icon: "gamecontroller.fill", paths: ["~/Library/Application Support/Steam/appcache", "~/Library/Application Support/Steam/logs"], subpath: nil, shellCommand: nil, info: "Steam app cache and logs. Rebuilds on launch.", safety: .safe),
        CleanupCategory(name: "Minecraft Logs", icon: "cube", paths: ["~/Library/Application Support/minecraft/logs"], subpath: nil, shellCommand: nil, info: "Minecraft log files. Safe to clear.", safety: .safe),

        // MARK: System
        CleanupCategory(name: "Library/Caches (All Apps)", icon: "internaldrive", paths: ["~/Library/Caches"], subpath: nil, shellCommand: nil, info: "Every app cache in your Library. Apps rebuild them.", safety: .safe),
        CleanupCategory(name: "Homebrew Cache", icon: "cup.and.saucer", paths: ["~/Library/Caches/Homebrew"], subpath: nil, shellCommand: nil, info: "Downloaded Homebrew bottles. Re-downloads on install.", safety: .caution),
        CleanupCategory(name: "QuickLook Thumbnails", icon: "photo.on.rectangle", paths: ["~/Library/Caches/com.apple.QuickLook.thumbnailcache"], subpath: nil, shellCommand: nil, info: "Preview thumbnails. Regenerate when you browse files.", safety: .safe),
        CleanupCategory(name: "Saved App State", icon: "macwindow.on.rectangle", paths: ["~/Library/Saved Application State"], subpath: nil, shellCommand: nil, info: "Reopened-window state. Apps just start fresh.", safety: .safe),
        CleanupCategory(name: "Siri TTS Cache", icon: "waveform", paths: ["~/Library/Caches/SiriTTS"], subpath: nil, shellCommand: nil, info: "Siri voice cache. Re-downloads voices as needed.", safety: .safe),
        CleanupCategory(name: "System Icon Cache", icon: "app.badge", paths: ["/Library/Caches/com.apple.iconservices.store"], subpath: nil, shellCommand: nil, info: "System icon store. Rebuilds automatically (needs admin).", safety: .safe),
        CleanupCategory(name: "Mail Attachments Cache", icon: "envelope", paths: ["~/Library/Mail/V10/Attachments"], subpath: nil, shellCommand: nil, info: "Downloaded Mail attachments. Re-download from server.", safety: .caution),
        CleanupCategory(name: "iOS Backups", icon: "iphone", paths: ["~/Library/Application Support/MobileSync/Backup"], subpath: nil, shellCommand: nil, info: "Full iPhone/iPad backups. Real data, cannot be undone.", safety: .data),
        CleanupCategory(name: "Wallpaper Aerials", icon: "photo", paths: ["~/Library/Application Support/com.apple.wallpaper/Store/Originals"], subpath: nil, shellCommand: nil, info: "Downloaded aerial screensavers. Re-download when set.", safety: .safe),

        // MARK: System - Apple App Caches
        CleanupCategory(name: "Safari Cache", icon: "safari", paths: ["~/Library/Caches/com.apple.Safari", "~/Library/Caches/com.apple.Safari.SafeBrowsing"], subpath: nil, shellCommand: nil, info: "Safari browsing cache. Rebuilds. History kept.", safety: .safe),
        CleanupCategory(name: "Music Cache", icon: "music.note", paths: ["~/Library/Caches/com.apple.Music", "~/Library/Caches/com.apple.AMPLibraryAgent"], subpath: nil, shellCommand: nil, info: "Apple Music cache. Rebuilds as you play.", safety: .safe),
        CleanupCategory(name: "App Store Cache", icon: "bag", paths: ["~/Library/Caches/com.apple.appstore", "~/Library/Caches/com.apple.appstoreagent", "~/Library/Caches/com.apple.appstorecomponentsd"], subpath: nil, shellCommand: nil, info: "App Store cache. Rebuilds on next visit.", safety: .safe),
        CleanupCategory(name: "Translation Cache", icon: "character.bubble", paths: ["~/Library/Caches/com.apple.translationd"], subpath: nil, shellCommand: nil, info: "Translation cache. Re-downloads languages as needed.", safety: .safe),
        CleanupCategory(name: "Game Center Cache", icon: "gamecontroller", paths: ["~/Library/Caches/com.apple.games", "~/Library/Caches/com.apple.gamed"], subpath: nil, shellCommand: nil, info: "Game Center cache. Rebuilds on use.", safety: .safe),

        // MARK: Logs
        CleanupCategory(name: "User Logs", icon: "doc.text.below.ecg", paths: ["~/Library/Logs"], subpath: nil, shellCommand: nil, info: "App diagnostic logs. Safe to clear.", safety: .safe),
        CleanupCategory(name: "All Logs", icon: "doc.text", paths: ["~/Library/Logs/Google", "~/Library/Logs/JetBrains", "~/Library/Logs/CoreSimulator", "~/Library/Logs/DiagnosticReports"], subpath: nil, shellCommand: nil, info: "Dev-tool logs (Xcode, JetBrains, etc.). Safe to clear.", safety: .safe),

        // MARK: Trash
        CleanupCategory(name: "Trash", icon: "trash", paths: [], subpath: nil, shellCommand: "empty-trash", info: "Permanently empties your Bin. Cannot be undone.", safety: .data, requiresElevation: false),

        // MARK: Commands
        CleanupCategory(name: "Docker System Prune", icon: "shippingbox.and.arrow.backward", paths: [], subpath: nil, shellCommand: "docker system prune -f", info: "Removes unused Docker images and stopped containers.", safety: .caution),
        CleanupCategory(name: "Ruby Gem Cleanup", icon: "diamond", paths: [], subpath: nil, shellCommand: "gem cleanup", info: "Removes old versions of installed gems.", safety: .safe),
        CleanupCategory(name: "Font Cache Reset", icon: "textformat", paths: [], subpath: nil, shellCommand: "atsutil databases -removeUser", info: "Rebuilds font caches. Fixes font display glitches.", safety: .safe),
        CleanupCategory(name: "Flush DNS Cache", icon: "network", paths: [], subpath: nil, shellCommand: "dscacheutil -flushcache; killall -HUP mDNSResponder", info: "Clears DNS lookups. Fixes stale site errors (needs admin).", safety: .safe, requiresElevation: true),
        CleanupCategory(name: "Time Machine Snapshots", icon: "clock.arrow.circlepath", paths: [], subpath: nil, shellCommand: "tmutil thinlocalsnapshots / 999999999999 4", info: "Thins local Time Machine snapshots. Frees hidden space (admin).", safety: .safe, requiresElevation: true),
    ]
}
