import Foundation
import Observation

struct LargeFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64

    var displayName: String { url.lastPathComponent }
    var displayPath: String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
    var fileExtension: String { url.pathExtension.lowercased() }
}

@Observable
@MainActor
class LargeFileScanner {
    var files: [LargeFile] = []
    var isScanning = false
    var scannedCount = 0
    var threshold: Int64 = 100 * 1024 * 1024

    func scan(in root: URL) async {
        isScanning = true
        files = []
        scannedCount = 0
        let t = threshold
        let found = await Task.detached(priority: .userInitiated) {
            Self.findFiles(in: root, threshold: t)
        }.value
        files = found.sorted { $0.size > $1.size }
        isScanning = false
    }

    func delete(_ targets: [LargeFile]) async {
        let urls = targets.map(\.url)
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            for url in urls { try? fm.removeItem(at: url) }
        }.value
        let ids = Set(targets.map(\.id))
        files.removeAll { ids.contains($0.id) }
    }

    private static nonisolated func findFiles(in root: URL, threshold: Int64) -> [LargeFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [LargeFile] = []
        for case let url as URL in enumerator {
            guard let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
                  vals.isSymbolicLink != true,
                  vals.isRegularFile == true else { continue }
            let size = Int64(vals.fileSize ?? 0)
            if size >= threshold {
                result.append(LargeFile(url: url, size: size))
            }
        }
        return result
    }
}
