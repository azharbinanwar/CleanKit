import Foundation

struct StorageInfo {
    let total: Int64
    let free: Int64
    var used: Int64 { total - free }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func load() -> StorageInfo {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total = (attrs?[.systemSize] as? Int64) ?? 0
        let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
        return StorageInfo(total: total, free: free)
    }
}
