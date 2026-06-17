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
    var lastUsedDate: Date? = nil
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
class AppUninstallerScanner {
    var apps: [AppInfo] = []
    var isScanning = false

    func scanApps() async {
        isScanning = true
        apps = []
        let found = await Task.detached(priority: .userInitiated) {
            Self.findApps()
        }.value
        apps = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        let cacheURLs = cacheItems.map(\.url)
        let freed = cacheItems.reduce(0) { $0 + $1.sizeBytes }
        await Task.detached(priority: .userInitiated) {
            for url in cacheURLs { try? FileManager.default.removeItem(at: url) }
        }.value
        guard let current = apps.firstIndex(where: { $0.id == appID }) else { return freed }
        apps[current].leftovers.removeAll(where: \.isCacheType)
        return freed
    }

    func uninstall(appID: UUID, leftoverIDs: Set<UUID>) async -> Int64 {
        guard let app = apps.first(where: { $0.id == appID }) else { return 0 }
        let appURL = app.appURL
        let selectedLeftovers = app.leftovers.filter { leftoverIDs.contains($0.id) }
        let leftoverURLs = selectedLeftovers.map(\.url)
        let freed = app.sizeBytes + selectedLeftovers.reduce(0) { $0 + $1.sizeBytes }
        await Task.detached(priority: .userInitiated) {
            try? FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
            for url in leftoverURLs { try? FileManager.default.removeItem(at: url) }
        }.value
        apps.removeAll { $0.id == appID }
        return freed
    }

    private static nonisolated func findApps() -> [AppInfo] {
        let fm = FileManager.default
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]
        var result: [AppInfo] = []
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where url.pathExtension == "app" {
                guard let info = makeAppInfo(at: url) else { continue }
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
        let lastUsedDate: Date? = {
            guard let item = MDItemCreate(nil, url.path as CFString) else { return nil }
            return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
        }()
        return AppInfo(name: name, bundleID: bundleID, version: version, appURL: url,
                       isDeletable: isDeletable, isAppleApp: isAppleApp, lastUsedDate: lastUsedDate)
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
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let vals = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  vals.isRegularFile == true else { continue }
            total += Int64(vals.fileSize ?? 0)
        }
        return total
    }

    private static nonisolated func fileSize(_ url: URL) -> Int64 {
        guard let vals = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = vals.fileSize else { return 0 }
        return Int64(size)
    }

    private static nonisolated func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
