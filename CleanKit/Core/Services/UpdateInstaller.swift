//
//  UpdateInstaller.swift
//  CleanKit
//
//  Installs a verified update DMG with no user interaction:
//  silent mount → stage → strip quarantine → atomic bundle swap
//  (with rollback) → detach → self-relaunch.
//

import AppKit
import Foundation

enum UpdateInstallError: LocalizedError {
    case mountFailed
    case appNotFoundInDMG
    case stagingFailed
    case swapFailed(String)

    var errorDescription: String? {
        switch self {
        case .mountFailed: "The update image couldn't be mounted."
        case .appNotFoundInDMG: "The update image doesn't contain an app."
        case .stagingFailed: "The update couldn't be copied out of the image."
        case .swapFailed(let reason): "The app couldn't be replaced: \(reason)"
        }
    }
}

enum UpdateInstaller {
    /// Installs the app found inside `dmg` over the current install.
    static func install(dmg: URL) async throws -> URL {
        let fm = FileManager.default
        let mountPoint = fm.temporaryDirectory
            .appendingPathComponent("cleankit-update-\(UUID().uuidString.prefix(8))", isDirectory: true)

        guard await run("/usr/bin/hdiutil",
                        "attach", dmg.path,
                        "-nobrowse", "-noautoopen",
                        "-mountpoint", mountPoint.path) == 0 else {
            throw UpdateInstallError.mountFailed
        }

        do {
            let installed = try await installFromVolume(mountPoint)
            await detach(mountPoint)
            return installed
        } catch {
            await detach(mountPoint)
            throw error
        }
    }

    /// Waits for this process to exit, then launches the given app.
    static func relaunch(_ appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; \
        /usr/bin/open "\(appURL.path)"
        """
        let watcher = Process()
        watcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        watcher.arguments = ["-c", script]
        try? watcher.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Steps

    private static func installFromVolume(_ volume: URL) async throws -> URL {
        let fm = FileManager.default

        guard let sourceApp = try fm.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw UpdateInstallError.appNotFoundInDMG
        }

        let dest = destinationURL()
        let destDir = dest.deletingLastPathComponent()

        // Stage next to the destination so the final swap is a same-volume
        // atomic rename, never a slow cross-volume copy.
        let staging = destDir.appendingPathComponent(".cleankit-update-staging.app")
        let backup = destDir.appendingPathComponent(".cleankit-update-backup.app")
        try? fm.removeItem(at: staging)
        try? fm.removeItem(at: backup)

        // ditto preserves symlinks, permissions, and code-signing metadata.
        guard await run("/usr/bin/ditto", sourceApp.path, staging.path) == 0 else {
            throw UpdateInstallError.stagingFailed
        }

        // Strip quarantine so Gatekeeper doesn't block the relaunch. Safe only
        // because UpdateChecker already verified the DMG's SHA-256 first.
        _ = await run("/usr/bin/xattr", "-dr", "com.apple.quarantine", staging.path)

        // Swap with rollback.
        let hadExisting = fm.fileExists(atPath: dest.path)
        if hadExisting {
            do { try fm.moveItem(at: dest, to: backup) } catch {
                try? fm.removeItem(at: staging)
                throw UpdateInstallError.swapFailed(error.localizedDescription)
            }
        }
        do {
            try fm.moveItem(at: staging, to: dest)
        } catch {
            if hadExisting { try? fm.moveItem(at: backup, to: dest) } // roll back
            try? fm.removeItem(at: staging)
            throw UpdateInstallError.swapFailed(error.localizedDescription)
        }
        try? fm.removeItem(at: backup)
        return dest
    }

    /// Replace in place when running from /Applications; otherwise install to
    /// /Applications/CleanKit.app.
    private static func destinationURL() -> URL {
        let current = Bundle.main.bundleURL
        if current.path.hasPrefix("/Applications/") { return current }
        return URL(fileURLWithPath: "/Applications/CleanKit.app")
    }

    private static func detach(_ mountPoint: URL) async {
        _ = await run("/usr/bin/hdiutil", "detach", mountPoint.path, "-force")
    }

    @discardableResult
    private static func run(_ tool: String, _ args: String...) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}
