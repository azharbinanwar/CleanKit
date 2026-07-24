import Foundation
import Observation

@Observable
@MainActor
final class CleanupManager {
    // Auto-hide from the start: only categories relevant to this Mac.
    var categories: [CleanupCategory] = CleanupCategory.all.filter { $0.exists }
    var isScanning = false
    /// True once a scan has completed, so re-opening the tab doesn't rescan.
    var hasScanned = false
    var scanningIndex: Int? = nil
    var totalFreedBytes: Int64 = 0
    var cleanErrors: [String] = []
    /// Volume free space captured at the start of a clean run.
    private var diskFreeBeforeClean: Int64 = 0
    /// Real free-space gain on the volume across the whole run (APFS may keep
    /// this below the per-category sum until purgeable space is reclaimed).
    var diskActuallyFreed: Int64 = 0

    static nonisolated func volumeFreeBytes() -> Int64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// Elevated work collected during a run so the whole run needs at most
    /// ONE admin password prompt (flushed in `endCleanRun`).
    struct ElevatedWork {
        var commands: [String] = []
        var failedItems: [(url: URL, size: Int64)] = []
        var isEmpty: Bool { commands.isEmpty && failedItems.isEmpty }
    }
    private var pendingElevated = ElevatedWork()
    private var pendingElevatedCategories: Set<UUID> = []
    private var inBatchRun = false
    /// True when the user dismissed the password prompt during the last run.
    var elevationCancelled = false

    func beginCleanRun() {
        totalFreedBytes = 0
        cleanErrors = []
        diskActuallyFreed = 0
        elevationCancelled = false
        pendingElevated = ElevatedWork()
        pendingElevatedCategories = []
        inBatchRun = true
        diskFreeBeforeClean = Self.volumeFreeBytes()
    }

    func endCleanRun() async {
        inBatchRun = false
        if !pendingElevated.isEmpty {
            // Single password prompt for everything queued across the run.
            let result = await Self.runElevated(pendingElevated)
            if result.cancelled {
                elevationCancelled = true
                cleanErrors.append("Password prompt cancelled — items needing admin access were skipped")
            } else if let err = result.error {
                cleanErrors.append(err)
            }
            // Re-measure affected categories so freed reflects what the
            // elevated batch actually deleted.
            for id in pendingElevatedCategories {
                guard let i = categories.firstIndex(where: { $0.id == id }) else { continue }
                let cat = categories[i]
                let after = await Task.detached(priority: .userInitiated) {
                    Self.calculateSize(for: cat)
                }.value
                let extra = max(0, categories[i].sizeBytes - after.0)
                totalFreedBytes += extra
                categories[i].freedBytes += extra
                categories[i].sizeBytes = after.0
                categories[i].fileCount = after.1
            }
            pendingElevated = ElevatedWork()
            pendingElevatedCategories = []
        }
        diskActuallyFreed = max(0, Self.volumeFreeBytes() - diskFreeBeforeClean)
    }

    /// Runs all queued elevated work behind ONE password prompt and reports
    /// how much of the queued file batch actually disappeared.
    static func runElevated(_ work: ElevatedWork) async -> (freed: Int64, error: String?, cancelled: Bool) {
        var parts = work.commands
        if !work.failedItems.isEmpty {
            parts.append("rm -rf " + work.failedItems.map {
                "'\($0.url.path.replacingOccurrences(of: "'", with: "'\\''"))'"
            }.joined(separator: " "))
        }
        var cancelled = false
        var errorMessage: String? = nil
        do {
            try await MainActor.run {
                try ElevationHelper.runWithPrivileges(parts.joined(separator: " ; "))
            }
        } catch ElevationError.userCancelled {
            cancelled = true
        } catch {
            errorMessage = error.localizedDescription
        }
        var freed: Int64 = 0
        let fm = FileManager.default
        for item in work.failedItems where !fm.fileExists(atPath: item.url.path) {
            freed += item.size
        }
        let remaining = work.failedItems.filter { fm.fileExists(atPath: $0.url.path) }.count
        if remaining > 0 && errorMessage == nil && !cancelled {
            errorMessage = "\(remaining) item(s) blocked — grant Full Disk Access in System Settings → Privacy & Security"
        }
        return (freed, errorMessage, cancelled)
    }
    var selectedIDs: Set<UUID>? = nil
    var hasMissingPermissions: Bool = false

    func scanAll() async {
        isScanning = true
        var foundMissing = false
        for i in categories.indices {
            scanningIndex = i
            let cat = categories[i]
            let result = await Task.detached(priority: .userInitiated) {
                Self.calculateSize(for: cat)
            }.value
            categories[i].sizeBytes = result.0
            categories[i].fileCount = result.1
            categories[i].isAccessDenied = result.2
            if result.2 { foundMissing = true }
        }
        hasMissingPermissions = foundMissing
        scanningIndex = nil
        isScanning = false
        hasScanned = true
    }

    /// Freeable bytes across `cats`, counting overlapping paths once. A category
    /// whose every path is nested inside another category's path (e.g. the
    /// Library/Caches umbrella swallowing the per-app cache categories) is not
    /// added twice — so the shown total matches what actually frees.
    static nonisolated func dedupedSize(_ cats: [CleanupCategory]) -> Int64 {
        let resolved = cats.map { (cat: $0, paths: resolvedPaths(for: $0)) }
        func nested(_ p: String, in q: String) -> Bool {
            p != q && p.hasPrefix(q.hasSuffix("/") ? q : q + "/")
        }
        var total: Int64 = 0
        for entry in resolved {
            let covered = !entry.paths.isEmpty && entry.paths.allSatisfy { p in
                resolved.contains { $0.cat.id != entry.cat.id && $0.paths.contains { nested(p, in: $0) } }
            }
            if !covered { total += entry.cat.sizeBytes }
        }
        return total
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

    private static nonisolated func calculateSize(for category: CleanupCategory) -> (Int64, Int, Bool) {
        if category.name == "Trash" {
            return calculateTotalTrashSize()
        }
        
        var total: Int64 = 0
        var count: Int = 0
        var denied = false
        let fm = FileManager.default
        for path in resolvedPaths(for: category) {
            guard fm.fileExists(atPath: path) else { continue }
            
            // Check if directory is readable
            if (try? fm.contentsOfDirectory(atPath: path)) == nil {
                denied = true
                continue
            }

            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                denied = true
                continue
            }

            for case let url as URL in enumerator {
                if let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]) {
                    total += Int64(vals.totalFileAllocatedSize ?? 0)
                    if vals.isRegularFile == true { count += 1 }
                }
            }
        }
        return (total, count, denied)
    }

    /// Every trash folder we can reach: the home Trash plus each mounted
    /// volume's per-user trash.
    private static nonisolated func trashDirectories() -> Set<URL> {
        let fm = FileManager.default
        let localTrash = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
        var trashURLs: Set<URL> = [localTrash]
        let volumeURLs = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsInternalKey], options: .skipHiddenVolumes) ?? []
        for volumeURL in volumeURLs {
            if let trashURL = try? fm.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: volumeURL, create: false) {
                trashURLs.insert(trashURL)
            }
        }
        return trashURLs
    }

    /// Clear the user-immutable (locked) flag on a URL and everything under it,
    /// so `removeItem` won't be blocked by locked files.
    private static nonisolated func unlockRecursively(_ url: URL) {
        let fm = FileManager.default
        func clear(_ u: URL) {
            var mutable = u
            var values = URLResourceValues()
            values.isUserImmutable = false
            try? mutable.setResourceValues(values)
        }
        clear(url)
        if let e = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let child as URL in e { clear(child) }
        }
    }

    /// Recursive size of a file or directory, in bytes.
    private static nonisolated func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            return Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: []) {
            for case let f as URL in e {
                total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    /// Delete an item; if it fails (usually a locked file), clear the lock flag
    /// and try once more. Returns whether the item is gone.
    private static nonisolated func removeUnlocking(_ url: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.removeItem(at: url)
            return true
        } catch {
            unlockRecursively(url)
            return (try? fm.removeItem(at: url)) != nil
        }
    }

    private static nonisolated func calculateTotalTrashSize() -> (Int64, Int, Bool) {
        let fm = FileManager.default
        var total: Int64 = 0
        var count: Int = 0
        var denied = false

        for url in trashDirectories() {
            guard fm.fileExists(atPath: url.path) else { continue }
            
            // Check readability
            if (try? fm.contentsOfDirectory(atPath: url.path)) == nil {
                denied = true
            }

            let resourceKeys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            
            for case let fileURL as URL in enumerator {
                if let vals = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) {
                    total += Int64(vals.totalFileAllocatedSize ?? 0)
                    if vals.isRegularFile == true { count += 1 }
                }
            }
        }

        return (total, count, denied)
    }

    func clean(category: CleanupCategory) async -> Int64 {
        let before = category.sizeBytes
        let result = await Self.performClean(category: category, deferElevated: inBatchRun)
        if let work = result.elevated {
            pendingElevated.commands += work.commands
            pendingElevated.failedItems += work.failedItems
            pendingElevatedCategories.insert(category.id)
        }
        if let err = result.error {
            cleanErrors.append("\(category.name): \(err)")
        }

        // Never trust the pre-scan number or per-item sums: re-measure the
        // category on disk after cleaning. freed = what actually disappeared,
        // and the leftover size shown is measured, not derived.
        let after = await Task.detached(priority: .userInitiated) {
            Self.calculateSize(for: category)
        }.value
        let freed = max(0, before - after.0)

        totalFreedBytes += freed
        if let i = categories.firstIndex(where: { $0.id == category.id }) {
            categories[i].cleaned = true
            categories[i].freedBytes = freed
            categories[i].sizeBytes = after.0
            categories[i].fileCount = after.1
        }
        CleanHistory.shared.save(name: category.name, freed: freed)
        return freed
    }

    // nonisolated so the heavy file-deletion loop runs OFF the main thread —
    // otherwise deleting a folder with tens of thousands of files (pub-cache,
    // node_modules) freezes the UI until it finishes. The one main-thread bit,
    // the password prompt, still hops back via MainActor.run inside runElevated.
    private nonisolated static func performClean(category: CleanupCategory, deferElevated: Bool) async -> (freed: Int64, error: String?, elevated: ElevatedWork?) {
        var freed: Int64 = 0
        var errors: [String] = []
        var elevated = ElevatedWork()
        let fm = FileManager.default
        let home = NSHomeDirectory()

        // Trash: delete the contents of every trash folder directly. Clears the
        // locked (uchg) flag first so locked items go too. No Finder Apple Events,
        // no admin. `freed` is measured before/after by the caller.
        if category.name == "Trash" {
            var stuck = 0
            for url in trashDirectories() {
                let items = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                for item in items where !removeUnlocking(item) { stuck += 1 }
            }
            return (0, stuck == 0 ? nil : "\(stuck) item(s) still in use — close the app that owns them and retry", nil)
        }

        // 1. Handle Shell Commands
        if let cmd = category.shellCommand {
            // Under `with administrator privileges` the shell runs as root,
            // so `~` would expand to /var/root — expand it to the real home first.
            let expanded = cmd.replacingOccurrences(of: "~/", with: "\(home)/")
            if category.requiresElevation {
                // Queued — runs later behind the run's single password prompt.
                elevated.commands.append(expanded)
            } else {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-c", expanded]
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus != 0 {
                        errors.append("command exited with status \(proc.terminationStatus)")
                    }
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
        }

        // 2. Delete file paths. For a directory, delete its *contents* one item at
        // a time (keeping the folder apps expect to exist) so a single locked or
        // in-use file only blocks itself instead of forfeiting the whole category.
        var failed: [(url: URL, size: Int64)] = []
        for path in resolvedPaths(for: category) {
            let root = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }

            let targets = isDir.boolValue
                ? ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [])) ?? [])
                : [root]

            for target in targets {
                let itemSize = size(of: target)
                if removeUnlocking(target) {
                    freed += itemSize
                } else {
                    failed.append((target, itemSize))
                }
            }
        }

        // 3. Whatever the user's own account couldn't delete is root-owned or
        // TCC-protected — queue it for the elevated batch.
        if !failed.isEmpty {
            elevated.failedItems = failed
        }

        // Batch run: hand elevated work back to the manager, which flushes it
        // behind a single password prompt at the end of the run.
        if deferElevated {
            return (freed,
                    errors.isEmpty ? nil : errors.joined(separator: "; "),
                    elevated.isEmpty ? nil : elevated)
        }

        // Single-category clean: run all elevated work in one combined call so
        // the user still sees at most one password prompt.
        if !elevated.isEmpty {
            let result = await runElevated(elevated)
            freed += result.freed
            if result.cancelled {
                errors.append("password prompt cancelled — items needing admin access were skipped")
            } else if let err = result.error {
                errors.append(err)
            }
        }

        return (freed, errors.isEmpty ? nil : errors.joined(separator: "; "), nil)
    }
}
