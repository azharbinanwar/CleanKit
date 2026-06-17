import Foundation
import Observation
import CryptoKit

struct DuplicateFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64

    var displayName: String { url.lastPathComponent }
    var displayPath: String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    var files: [DuplicateFile]

    var wastedBytes: Int64 { Int64(files.count - 1) * (files.first?.size ?? 0) }
    var fileSize: Int64 { files.first?.size ?? 0 }
}

enum ScanGate {
    case clear
    case warning(Int)
    case blocked(Int)

    static func check(_ count: Int, warn: Int = 3000, block: Int = 8000) -> ScanGate {
        if count > block { return .blocked(count) }
        if count > warn  { return .warning(count) }
        return .clear
    }
}

@Observable
@MainActor
class DuplicateScanner {
    var groups: [DuplicateGroup] = []
    var isScanning = false
    var isCounting = false
    var scanPhase: String = ""

    func countFiles(in root: URL) async -> Int {
        isCounting = true
        let count = await Task.detached(priority: .userInitiated) {
            Self.quickCount(in: root)
        }.value
        isCounting = false
        return count
    }

    func scan(in root: URL) async {
        isScanning = true
        groups = []
        scanPhase = "Pass 1 of 3 — Indexing files"
        let bySize = await Task.detached(priority: .userInitiated) {
            Self.groupBySize(in: root)
        }.value

        let candidateCount = bySize.values.filter { $0.count > 1 }.flatMap { $0 }.count
        scanPhase = "Pass 2 of 3 — Quick hash on \(candidateCount.formatted()) candidates"
        let byPartial = await Task.detached(priority: .userInitiated) {
            Self.filterByPartialHash(bySize)
        }.value

        let deepCount = byPartial.values.filter { $0.urls.count > 1 }.flatMap { $0.urls }.count
        scanPhase = "Pass 3 of 3 — Deep comparison of \(deepCount.formatted()) files"
        let found = await Task.detached(priority: .userInitiated) {
            Self.buildGroups(byPartial)
        }.value

        groups = found.sorted { $0.wastedBytes > $1.wastedBytes }
        isScanning = false
        scanPhase = ""
    }

    func delete(keeping keepURL: URL, in groupID: UUID) async -> Int64 {
        guard let group = groups.first(where: { $0.id == groupID }) else { return 0 }
        let toDelete = group.files.filter { $0.url != keepURL }.map(\.url)
        let freed = group.fileSize * Int64(toDelete.count)
        await Task.detached(priority: .userInitiated) {
            for url in toDelete { try? FileManager.default.removeItem(at: url) }
        }.value
        groups.removeAll { $0.id == groupID }
        return freed
    }

    private static nonisolated func quickCount(in root: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var count = 0
        for case let url as URL in enumerator {
            guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  vals.isRegularFile == true else { continue }
            count += 1
        }
        return count
    }

    private static nonisolated func groupBySize(in root: URL) -> [Int64: [URL]] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [:] }
        var bySize: [Int64: [URL]] = [:]
        for case let url as URL in enumerator {
            guard let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  vals.isRegularFile == true,
                  let size = vals.fileSize, size > 1024 else { continue }
            bySize[Int64(size), default: []].append(url)
        }
        return bySize
    }

    private static nonisolated func filterByPartialHash(_ bySize: [Int64: [URL]]) -> [String: (size: Int64, urls: [URL])] {
        var byQuickHash: [String: (size: Int64, urls: [URL])] = [:]
        for (size, urls) in bySize where urls.count > 1 {
            for url in urls {
                guard let qHash = partialHash(url) else { continue }
                let key = "\(size)_\(qHash)"
                byQuickHash[key, default: (size, [])].urls.append(url)
            }
        }
        return byQuickHash
    }

    private static nonisolated func buildGroups(_ byPartial: [String: (size: Int64, urls: [URL])]) -> [DuplicateGroup] {
        var byFullHash: [String: [DuplicateFile]] = [:]
        for (_, entry) in byPartial where entry.urls.count > 1 {
            for url in entry.urls {
                guard let hash = sha256(url) else { continue }
                let file = DuplicateFile(url: url, size: entry.size)
                byFullHash[hash, default: []].append(file)
            }
        }
        return byFullHash
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(hash: $0.key, files: $0.value) }
    }

    private static nonisolated func partialHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        guard !data.isEmpty else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static nonisolated func sha256(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = (try? handle.read(upToCount: 65536)) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
