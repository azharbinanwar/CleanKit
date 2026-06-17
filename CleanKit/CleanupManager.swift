import Foundation
import Observation

@Observable
@MainActor
class CleanupManager {
    var categories: [CleanupCategory] = CleanupCategory.all
    var isScanning = false
    var scanningIndex: Int? = nil
    var totalFreedBytes: Int64 = 0
    var selectedIDs: Set<UUID>? = nil

    func scanAll() async {
        isScanning = true
        for i in categories.indices {
            scanningIndex = i
            let cat = categories[i]
            let result = await Task.detached(priority: .userInitiated) {
                Self.calculateSize(for: cat)
            }.value
            categories[i].sizeBytes = result.0
            categories[i].fileCount = result.1
        }
        scanningIndex = nil
        isScanning = false
    }

    private static nonisolated func resolvedPaths(for category: CleanupCategory) -> [String] {
        let fm = FileManager.default
        var result: [String] = []
        for rawPath in category.paths {
            let base = (rawPath as NSString).expandingTildeInPath
            if let sub = category.subpath {
                let children = (try? fm.contentsOfDirectory(atPath: base)) ?? []
                for child in children {
                    result.append(URL(fileURLWithPath: base).appendingPathComponent(child).appendingPathComponent(sub).path)
                }
            } else {
                result.append(base)
            }
        }
        return result
    }

    private static nonisolated func calculateSize(for category: CleanupCategory) -> (Int64, Int) {
        var total: Int64 = 0
        var count: Int = 0
        let fm = FileManager.default
        for path in resolvedPaths(for: category) {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                total += Int64(vals?.fileSize ?? 0)
                if vals?.isRegularFile == true { count += 1 }
            }
        }
        return (total, count)
    }

    func clean(category: CleanupCategory) async -> Int64 {
        let freed = await Task.detached(priority: .userInitiated) {
            Self.performClean(category: category)
        }.value
        totalFreedBytes += freed
        if let i = categories.firstIndex(where: { $0.id == category.id }) {
            categories[i].cleaned = true
            categories[i].freedBytes = freed
            categories[i].sizeBytes = 0
            categories[i].fileCount = 0
        }
        CleanHistory.shared.save(name: category.name, freed: freed)
        return freed
    }

    private static nonisolated func performClean(category: CleanupCategory) -> Int64 {
        var freed: Int64 = 0
        let fm = FileManager.default

        if let cmd = category.shellCommand {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", cmd]
            try? proc.run()
            proc.waitUntilExit()
        }

        for path in resolvedPaths(for: category) {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else { continue }
            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    freed += Int64(size)
                }
            }
            try? fm.removeItem(at: url)
        }
        return freed
    }
}

extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
