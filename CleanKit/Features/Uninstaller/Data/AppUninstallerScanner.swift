import Foundation
import Observation
import CoreServices

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let appURL: URL
    var sizeBytes: Int64 = 0
    var leftovers: [LeftoverItem] = []
    var isScanning: Bool = false
    var isDeletable: Bool = true
    var isAppleApp: Bool = false
    /// SIP-protected macOS app (in /System, or not deletable): may refuse to
    /// remove or be restored by macOS. Xcode etc. in /Applications are NOT this.
    var isProtected: Bool = false
    var lastUsedDate: Date? = nil
}

/// Honest outcome of an uninstall — drives the result screen instead of always
/// claiming success.
struct UninstallResult {
    let removed: Bool      // was the .app itself actually deleted?
    let freed: Int64       // bytes that actually disappeared
    let cancelled: Bool    // user dismissed the password prompt
    let message: String?   // failure detail, if any
}

struct LeftoverItem: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    var sizeBytes: Int64
    var isSelected: Bool = true

    var isCacheType: Bool {
        ["Caches", "WebKit", "HTTP Storage"].contains(label)
    }
}

@Observable
@MainActor
final class AppUninstallerScanner {
    var apps: [AppInfo] = []
    var isScanning = false

    func scanApps() async {
        isScanning = true
        apps = []
        let found = await Task.detached(priority: .userInitiated) {
            var list = Self.findApps()
            // Pre-calculate sizes for the list view
            for i in list.indices {
                list[i].sizeBytes = Self.directorySize(list[i].appURL)
            }
            return list
        }.value
        apps = found
        isScanning = false
    }

    func scanLeftovers(for appID: UUID) async {
        guard let idx = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[idx].isScanning = true
        let appURL = apps[idx].appURL
        let name = apps[idx].name
        let bundleID = apps[idx].bundleID
        let (size, items) = await Task.detached(priority: .userInitiated) {
            (Self.directorySize(appURL), Self.findLeftovers(name: name, bundleID: bundleID))
        }.value
        guard let current = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[current].sizeBytes = size
        apps[current].leftovers = items
        apps[current].isScanning = false
    }

    func cleanCache(appID: UUID) async -> Int64 {
        guard let idx = apps.firstIndex(where: { $0.id == appID }) else { return 0 }
        let cacheItems = apps[idx].leftovers.filter(\.isCacheType)

        let freed = await Task.detached(priority: .userInitiated) { () -> Int64 in
            let fm = FileManager.default
            var gained: Int64 = 0
            for item in cacheItems {
                // Cache lives under ~/Library and is user-owned — a plain remove works.
                if (try? fm.removeItem(at: item.url)) != nil, !fm.fileExists(atPath: item.url.path) {
                    gained += item.sizeBytes
                }
            }
            return gained
        }.value

        // Drop only the cache items that actually disappeared.
        if let current = apps.firstIndex(where: { $0.id == appID }) {
            apps[current].leftovers.removeAll { $0.isCacheType && !FileManager.default.fileExists(atPath: $0.url.path) }
        }
        return freed
    }

    func uninstall(appID: UUID, leftoverIDs: Set<UUID>) async -> UninstallResult {
        guard let app = apps.first(where: { $0.id == appID }) else {
            return UninstallResult(removed: false, freed: 0, cancelled: false, message: "App not found")
        }
        let appURL = app.appURL
        let appSize = app.sizeBytes
        let selectedLeftovers = app.leftovers.filter { leftoverIDs.contains($0.id) }
        // (url, size) so we can verify per item and count only what really went.
        let targets: [(url: URL, size: Int64)] =
            [(appURL, appSize)] + selectedLeftovers.map { ($0.url, $0.sizeBytes) }

        let result = await Task.detached(priority: .userInitiated) { () -> UninstallResult in
            let fm = FileManager.default
            var failed: [URL] = []

            // 1. Try the user's own account first (Trash the .app so it's recoverable).
            do { try fm.trashItem(at: appURL, resultingItemURL: nil) }
            catch { failed.append(appURL) }
            for item in selectedLeftovers {
                if (try? fm.removeItem(at: item.url)) == nil { failed.append(item.url) }
            }

            // 2. One elevated pass for whatever needed admin (single password prompt).
            var cancelled = false
            if !failed.isEmpty {
                let rm = "rm -rf " + failed.map { "'\($0.path.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: " ")
                do {
                    try await MainActor.run { try ElevationHelper.runWithPrivileges(rm) }
                } catch ElevationError.userCancelled {
                    cancelled = true
                } catch {
                    // fall through to verification
                }
            }

            // 3. Verify: freed counts only items actually gone; removed = app is gone.
            var freed: Int64 = 0
            for t in targets where !fm.fileExists(atPath: t.url.path) { freed += t.size }
            let removed = !fm.fileExists(atPath: appURL.path)
            var message: String? = nil
            if !removed {
                message = cancelled
                    ? "Password cancelled. \(app.name) was not removed."
                    : "\(app.name) is protected by macOS and couldn't be removed."
            }
            return UninstallResult(removed: removed, freed: freed, cancelled: cancelled, message: message)
        }.value

        // Only drop it from the list if it actually got removed.
        if result.removed {
            apps.removeAll { $0.id == appID }
        } else if let idx = apps.firstIndex(where: { $0.id == appID }) {
            // Refresh leftovers/size so the UI reflects what survived.
            apps[idx].leftovers.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        }
        return result
    }

    private static nonisolated func findApps() -> [AppInfo] {
        let fm = FileManager.default
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications"),          // macOS system apps
            URL(fileURLWithPath: "/System/Applications/Utilities"),
        ]
        var result: [AppInfo] = []
        var seenPaths = Set<String>()
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where url.pathExtension == "app" {
                guard !seenPaths.contains(url.path), let info = makeAppInfo(at: url) else { continue }
                seenPaths.insert(url.path)
                result.append(info)
            }
        }
        return result
    }

    private static nonisolated func makeAppInfo(at url: URL) -> AppInfo? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plist) as? [String: Any] else { return nil }
        let name = dict["CFBundleDisplayName"] as? String
            ?? dict["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = dict["CFBundleIdentifier"] as? String ?? ""
        let version = dict["CFBundleShortVersionString"] as? String
            ?? dict["CFBundleVersion"] as? String
            ?? ""
        let isDeletable = FileManager.default.isDeletableFile(atPath: url.path)
        let isAppleApp = bundleID.hasPrefix("com.apple.")
        // Protected = a real macOS system app: lives under /System, or the OS
        // won't let us delete it. A user-downloaded Apple app like Xcode sits in
        // /Applications and IS deletable, so it is NOT treated as protected.
        let isProtected = url.path.hasPrefix("/System/") || !isDeletable
        let lastUsedDate: Date? = {
            guard let item = MDItemCreate(nil, url.path as CFString) else { return nil }
            return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
        }()
        return AppInfo(name: name, bundleID: bundleID, version: version, appURL: url,
                       isDeletable: isDeletable, isAppleApp: isAppleApp,
                       isProtected: isProtected, lastUsedDate: lastUsedDate)
    }

    private static nonisolated func findLeftovers(name: String, bundleID: String) -> [LeftoverItem] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var items: [LeftoverItem] = []
        var seen = Set<String>()

        let candidates: [(String, String)] = [
            ("~/Library/Application Support/\(name)", "App Support"),
            ("~/Library/Application Support/\(bundleID)", "App Support"),
            ("~/Library/Preferences/\(bundleID).plist", "Preferences"),
            ("~/Library/Caches/\(bundleID)", "Caches"),
            ("~/Library/Logs/\(name)", "Logs"),
            ("~/Library/Containers/\(bundleID)", "Containers"),
            ("~/Library/Saved Application State/\(bundleID).savedState", "Saved State"),
            ("~/Library/WebKit/\(bundleID)", "WebKit"),
            ("~/Library/HTTPStorages/\(bundleID)", "HTTP Storage"),
        ]

        for (path, label) in candidates {
            let expanded = path.replacingOccurrences(of: "~", with: home)
            guard !seen.contains(expanded), fm.fileExists(atPath: expanded) else { continue }
            seen.insert(expanded)
            let url = URL(fileURLWithPath: expanded)
            let size = isDirectory(url) ? directorySize(url) : fileSize(url)
            items.append(LeftoverItem(url: url, label: label, sizeBytes: size))
        }

        let groupDir = URL(fileURLWithPath: "\(home)/Library/Group Containers")
        if !bundleID.isEmpty, let entries = try? fm.contentsOfDirectory(at: groupDir, includingPropertiesForKeys: nil) {
            for entry in entries where entry.lastPathComponent.contains(bundleID) {
                items.append(LeftoverItem(url: entry, label: "Group Containers", sizeBytes: directorySize(entry)))
            }
        }

        return items
    }

    private static nonisolated func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    private static nonisolated func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
    }

    private static nonisolated func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
