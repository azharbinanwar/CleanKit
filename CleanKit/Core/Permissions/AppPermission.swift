import SwiftUI
import ApplicationServices

enum AppPermission: String, CaseIterable, Identifiable {
    case fullDiskAccess
    case accessibility

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fullDiskAccess: return "Full Disk Access"
        case .accessibility:  return "Accessibility"
        }
    }

    var icon: String {
        switch self {
        case .fullDiskAccess: return "internaldrive"
        case .accessibility:  return "hand.raised"
        }
    }

    var color: Color {
        switch self {
        case .fullDiskAccess: return .orange
        case .accessibility:  return .blue
        }
    }

    var reason: String {
        switch self {
        case .fullDiskAccess: return "Required to scan ~/Library and other protected folders"
        case .accessibility:  return "Required for Port Manager to kill processes"
        }
    }

    var isGranted: Bool {
        switch self {
        case .fullDiskAccess:
            // isReadableFile/access(2) only checks POSIX permissions — TCC blocks
            // at open time, so the only reliable test is actually listing an
            // FDA-protected directory. Try several canaries; success on any = granted.
            let home = NSHomeDirectory() as NSString
            let canaries = [
                "/Library/Application Support/com.apple.TCC",   // exists on every Mac
                home.appendingPathComponent("Library/Mail"),
                home.appendingPathComponent("Library/Safari"),
                home.appendingPathComponent("Library/Messages"),
                home.appendingPathComponent("Library/PersonalizationPortrait"),
            ]
            let fm = FileManager.default
            for path in canaries {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                if (try? fm.contentsOfDirectory(atPath: path)) != nil { return true }
            }
            return false
        case .accessibility:
            return AXIsProcessTrusted()
        }
    }

    var settingsURL: URL {
        switch self {
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}
