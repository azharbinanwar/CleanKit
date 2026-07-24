import SwiftUI

/// Full-screen onboarding gate shown until Full Disk Access is granted.
/// This is the same pattern paid cleaners use: without FDA, macOS silently
/// blocks deletion in protected locations and results look "wrong" to users.
struct FullDiskAccessGate: View {
    /// Re-checked automatically whenever the app becomes active
    /// (i.e. the user returns from System Settings).
    @Binding var isGranted: Bool

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                Image(systemName: "internaldrive")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(.orange)
            }
            .onAppear { pulse = true }

            VStack(spacing: 10) {
                Text("Full Disk Access Required")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Without it, macOS silently blocks CleanKit from most caches —\nscans look big but cleaning frees only a fraction.\nGrant it once and CleanKit cleans everything it shows.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, text: "Click **Open System Settings** below")
                stepRow(number: 2, text: "Find **CleanKit** in the list (drag it in if missing)")
                stepRow(number: 3, text: "Turn the toggle **on**")
                stepRow(number: 4, text: "Click **Restart CleanKit** — macOS applies the permission on relaunch")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.04))
            )

            VStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.open(AppPermission.fullDiskAccess.settingsURL)
                } label: {
                    Label("Open System Settings", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    restartApp()
                } label: {
                    Label("Restart CleanKit", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 220)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    refresh()
                } label: {
                    Text("I've granted it — re-check")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()

            Text("CleanKit never uploads anything. Full Disk Access is used only to scan and delete the junk you approve.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        // Some grants do land without a relaunch — poll so the gate unlocks by itself.
        .task {
            while !isGranted {
                try? await Task.sleep(for: .seconds(2))
                refresh()
            }
        }
    }

    /// FDA is applied per-process at launch — relaunch cleanly so the grant takes effect.
    private func restartApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(.init(text))
                .font(.system(size: 12.5))
        }
    }

    private func refresh() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isGranted = AppPermission.fullDiskAccess.isGranted
        }
    }
}

#Preview {
    FullDiskAccessGate(isGranted: .constant(false))
        .frame(width: 700, height: 600)
}
