import SwiftUI
import AppKit
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
            let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Safari")
            return (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
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

struct PermissionsPanel: View {
    @Binding var isShowing: Bool
    let permissions: [AppPermission]
    @State private var granted: Set<AppPermission.ID> = []

    var missing: [AppPermission] {
        permissions.filter { !granted.contains($0.id) }
    }

    var body: some View {
        if isShowing {
            HStack(spacing: 0) {
                Divider()
                VStack(spacing: 0) {
                    header
                    Divider()
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(missing) { permission in
                                permissionRow(permission)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(width: 220)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .transition(.move(edge: .trailing))
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            Text("Permissions")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isShowing = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func permissionRow(_ permission: AppPermission) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(permission.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: permission.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(permission.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(permission.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Not granted")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Text(permission.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NSWorkspace.shared.open(permission.settingsURL)
            } label: {
                Text("Open Settings")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
    }

    private func refresh() {
        granted = Set(permissions.filter(\.isGranted).map(\.id))
        if missing.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) { isShowing = false }
        }
    }
}
