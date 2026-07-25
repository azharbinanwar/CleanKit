import SwiftUI

// MARK: - Groups

struct CleanerGroup: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let categoryNames: [String]

    static let all: [CleanerGroup] = [
        CleanerGroup(
            id: "developer", name: "Developer", icon: "hammer", color: .accentColor,
            categoryNames: [
                "Xcode DerivedData", "Xcode Archives", "Xcode iOS Device Support",
                "Xcode watchOS Device Support", "Xcode tvOS Device Support",
                "Xcode Previews", "Simulator Caches", "Xcode Cache",
                "Gradle Caches", "CocoaPods Cache", "Carthage Artifacts",
                "npm Cache", "Yarn Cache", "pnpm Store",
                "Flutter pub-cache", "FVM SDK Cache",
                "nvm Cache", "sdkman Archives", "asdf Downloads", "pyenv Cache", "Conda Packages",
                "Ruby Gems Cache", "Python pip Cache",
                "Maven Local Repo", "Cargo Registry Cache", "Go Module Cache",
                "Swift Package Manager", "Deno Cache", "Bun Cache",
                "Composer Cache", "Helm Cache", "Terraform Plugin Cache", "Playwright Browsers",
                "Android AVD", "Android Cache",
                "JetBrains Caches", "VS Code Cache", "VS Code Updater", "Cursor Cache"
            ]
        ),
        CleanerGroup(
            id: "browsers", name: "Browsers", icon: "globe", color: .accentColor,
            categoryNames: [
                "Chrome Cache", "Edge Cache", "Arc Cache", "Brave Cache",
                "Firefox Cache", "Opera Cache", "Vivaldi Cache", "Chromium Cache"
            ]
        ),
        CleanerGroup(
            id: "apps", name: "Apps", icon: "square.grid.2x2", color: .accentColor,
            categoryNames: [
                "Claude Cache", "Slack Cache", "Discord Cache", "Microsoft Teams Cache",
                "Notion Cache", "Postman Cache", "Spotify Cache", "Figma Cache",
                "Dropbox Cache", "Adobe Cache", "Zoom Speech Cache"
            ]
        ),
        CleanerGroup(
            id: "ai", name: "AI Tools", icon: "brain", color: .accentColor,
            categoryNames: ["HuggingFace Cache", "PyTorch Cache", "Ollama Models"]
        ),
        CleanerGroup(
            id: "gaming", name: "Gaming", icon: "gamecontroller", color: .accentColor,
            categoryNames: ["Steam Cache", "Minecraft Logs"]
        ),
        CleanerGroup(
            id: "system", name: "System", icon: "gearshape", color: .accentColor,
            categoryNames: [
                "Library/Caches (All Apps)", "Homebrew Cache", "QuickLook Thumbnails",
                "Saved App State", "Siri TTS Cache", "System Icon Cache",
                "Mail Attachments Cache", "iOS Backups", "Wallpaper Aerials",
                "Safari Cache", "Music Cache", "App Store Cache",
                "Translation Cache", "Game Center Cache"
            ]
        ),
        CleanerGroup(
            id: "logs", name: "Logs", icon: "doc.text", color: .accentColor,
            categoryNames: ["User Logs", "All Logs"]
        ),
        CleanerGroup(
            id: "commands", name: "Commands", icon: "terminal", color: .accentColor,
            categoryNames: [
                "iOS Simulator (Unavailable)", "Docker System Prune", "Ruby Gem Cleanup",
                "Font Cache Reset", "Flush DNS Cache", "Time Machine Snapshots"
            ]
        ),
        CleanerGroup(
            id: "trash", name: "Trash", icon: "trash", color: .accentColor,
            categoryNames: ["Trash"]
        )
    ]
}

// MARK: - Mac Cleaner View

struct MacCleanerView: View {
    var manager: CleanupManager
    let categorySettings: CategorySettings
    let onClean: () -> Void

    @State private var selectedGroup: CleanerGroup = CleanerGroup.all[0]
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmPayload: ConfirmPayload? = nil
    // Re-checked on appear and when the app becomes active, so the banner hides
    // as soon as the user grants Full Disk Access in System Settings.
    @State private var fullDiskGranted = AppPermission.fullDiskAccess.isGranted

    var allGroupsTotal: Int64 {
        CleanupManager.dedupedSize(manager.categories)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header

                if !fullDiskGranted {
                    AppBanner(
                        icon: "lock.shield.fill",
                        message: "Cleaning may be incomplete. Full Disk Access is required for system cleanup.",
                        actionTitle: "Open Settings"
                    ) {
                        NSWorkspace.shared.open(AppPermission.fullDiskAccess.settingsURL)
                    }
                    .padding(.horizontal, 2) // Match the gap feel
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 16) {
                    GroupPanel(
                        manager: manager,
                        categorySettings: categorySettings,
                        selectedGroup: $selectedGroup,
                        allGroupsTotal: allGroupsTotal
                    )
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                    CategoryPanel(
                        manager: manager,
                        group: selectedGroup,
                        selectedIDs: $selectedIDs
                    )
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                }

                bottomBar
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
            .blur(radius: confirmPayload != nil ? 10 : 0)
            .disabled(confirmPayload != nil)

            // MAGIC OVERLAY
            if let payload = confirmPayload {
                ConfirmSheet(items: payload.items, onCancel: {
                    withAnimation(.spring()) { confirmPayload = nil }
                }, onConfirm: {
                    let ids = Set(payload.items.map { $0.id })
                    withAnimation(.spring()) { confirmPayload = nil }
                    manager.selectedIDs = ids
                    onClean()
                })
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            fullDiskGranted = AppPermission.fullDiskAccess.isGranted
            // Don't rescan on tab re-entry: skip if a scan is running or results
            // already exist. Just restore the default selection in that case.
            if manager.isScanning || manager.hasScanned {
                selectedIDs = Set(autoSelectableIDs())
                return
            }
            manager.categories = categorySettings.enabledCategories
            Task {
                await manager.scanAll()
                withAnimation(.spring()) { selectedIDs = Set(autoSelectableIDs()) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Cheap re-check on return from System Settings: the banner clears the
            // moment Full Disk Access is granted, no re-scan needed.
            fullDiskGranted = AppPermission.fullDiskAccess.isGranted
        }
        .animation(.easeInOut(duration: 0.25), value: fullDiskGranted)
    }

    private func autoSelectableIDs() -> [UUID] {
        manager.categories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }.map { $0.id }
    }

    private var header: some View {
        AppHeader(title: "Mac Cleaner", subtitle: "\(categorySettings.enabledCount) categories enabled") {
            AppButton(title: "Scan", icon: "magnifyingglass", style: .primary, isEnabled: !manager.isScanning) {
                selectedIDs = []
                manager.categories = categorySettings.enabledCategories
                Task {
                    await manager.scanAll()
                    // Select all items that have data by default
                    let autoSelect = manager.categories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
                    withAnimation(.spring()) {
                        selectedIDs = Set(autoSelect.map { $0.id })
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1) // Thin divider above the footer

            HStack(spacing: 12) {
                // 1. Status & Counter (Left)
                HStack(spacing: 12) {
                    if manager.isScanning {
                        AppLoading(size: 14, strokeWidth: 1.5)
                        Text("Scanning…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }

                    HStack(spacing: 4) {
                        Text("Found:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                        RollingSizeView(value: allGroupsTotal)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }

                Spacer()

                // 2. Actions (Right)
                if selectedIDs.isEmpty {
                    AppButton(title: "Clean All", style: .primary, isEnabled: allGroupsTotal > 0 && !manager.isScanning) {
                        let items = manager.categories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
                        confirmPayload = ConfirmPayload(items: items)
                    }
                } else {
                    HStack(spacing: 16) {
                        Button(action: { withAnimation(.spring()) { selectedIDs = [] } }) {
                            Text("Deselect All")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("\(selectedIDs.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        AppButton(title: "Clean Selected", style: .primary) {
                            let items = manager.categories.filter { selectedIDs.contains($0.id) }
                            confirmPayload = ConfirmPayload(items: items)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(height: 72) // Fixed height to prevent jumping
    }
}

// MARK: - Subviews

struct GroupPanel: View {
    var manager: CleanupManager
    let categorySettings: CategorySettings
    @Binding var selectedGroup: CleanerGroup
    let allGroupsTotal: Int64

    var body: some View {
        VStack(spacing: 0) {
            ForEach(CleanerGroup.all) { group in
                let groupCategories = manager.categories.filter { group.categoryNames.contains($0.name) }
                let groupTotal = groupCategories.reduce(0) { $0 + $1.sizeBytes }
                let fraction = allGroupsTotal > 0 ? Double(groupTotal) / Double(allGroupsTotal) : 0

                let isScanning = group.categoryNames.contains { name in
                    if let idx = manager.scanningIndex, idx < manager.categories.count {
                        return manager.categories[idx].name == name
                    }
                    return false
                }

                AppTile(
                    title: group.name,
                    icon: group.icon,
                    isSelected: selectedGroup.id == group.id,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedGroup = group
                        }
                    }
                ) {
                    GroupRing(color: group.color, fraction: fraction, isSpinning: isScanning)
                }
                .padding(.horizontal, 8)
            }
            Spacer()
        }
        .frame(width: 220)
        .padding(.vertical, 12)
    }
}

struct CategoryPanel: View {
    var manager: CleanupManager
    let group: CleanerGroup
    @Binding var selectedIDs: Set<UUID>
    @State private var sortLargest = true

    var groupCategories: [CleanupCategory] {
        let items = manager.categories.filter { group.categoryNames.contains($0.name) }
        return items.sorted { sortLargest ? $0.sizeBytes > $1.sizeBytes : $0.sizeBytes < $1.sizeBytes }
    }

    var foundCategories: [CleanupCategory] {
        groupCategories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
    }

    var emptyCategories: [CleanupCategory] {
        groupCategories.filter { $0.sizeBytes == 0 && $0.shellCommand == nil }
    }

    var maxGroupSize: Int64 {
        groupCategories.map(\.sizeBytes).max() ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-header for sorting
            HStack {
                Text(group.name).font(.system(size: 14, weight: .bold))
                Spacer()
                if !groupCategories.isEmpty {
                    Button(action: { withAnimation(.spring()) { sortLargest.toggle() } }) {
                        Label(sortLargest ? "Largest First" : "Smallest First", systemImage: sortLargest ? "arrow.down" : "arrow.up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider().opacity(0.1)

            ZStack {
                if groupCategories.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: group.icon)
                            .font(.system(size: 56, weight: .thin))
                            .foregroundStyle(LinearGradient(colors: [group.color, group.color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .opacity(0.8)

                        VStack(spacing: 4) {
                            Text(group.name)
                                .font(.system(size: 18, weight: .bold))
                            Text("No items require attention in this category.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !foundCategories.isEmpty {
                                sectionHeader("Ready to Clean (\(foundCategories.count))")
                                ForEach(foundCategories) { cat in
                                    CategoryRow(
                                        cat: cat,
                                        isScanning: manager.scanningIndex == manager.categories.firstIndex(where: { $0.id == cat.id }),
                                        isSelected: selectedIDs.contains(cat.id),
                                        relativeWidth: maxGroupSize > 0 ? CGFloat(cat.sizeBytes) / CGFloat(maxGroupSize) : 0,
                                        onTap: {
                                            if selectedIDs.contains(cat.id) {
                                                selectedIDs.remove(cat.id)
                                            } else {
                                                selectedIDs.insert(cat.id)
                                            }
                                        }
                                    )
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                                    Divider().padding(.leading, 48).opacity(0.1)
                                }
                            }

                            if !emptyCategories.isEmpty {
                                sectionHeader("Nothing Found (\(emptyCategories.count))")
                                ForEach(emptyCategories) { cat in
                                    CategoryRow(
                                        cat: cat,
                                        isScanning: manager.scanningIndex == manager.categories.firstIndex(where: { $0.id == cat.id }),
                                        isSelected: selectedIDs.contains(cat.id),
                                        relativeWidth: 0,
                                        onTap: {
                                            if selectedIDs.contains(cat.id) {
                                                selectedIDs.remove(cat.id)
                                            } else {
                                                selectedIDs.insert(cat.id)
                                            }
                                        }
                                    )
                                    .transition(.opacity)
                                    Divider().padding(.leading, 48).opacity(0.1)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: foundCategories.count)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.secondary.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

extension CategorySafety {
    var color: Color {
        switch self {
        case .safe:    return .green
        case .caution: return .yellow
        case .data:    return .orange
        }
    }
}

/// Small colored pill showing how risky a category is to clean.
struct SafetyBadge: View {
    let safety: CategorySafety
    var body: some View {
        Text(safety.label)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(safety.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(safety.color.opacity(0.15)))
    }
}

struct CategoryRow: View {
    let cat: CleanupCategory
    let isScanning: Bool
    let isSelected: Bool
    let relativeWidth: CGFloat
    let onTap: () -> Void

    var isSelectable: Bool {
        !isScanning && !cat.isAccessDenied && (cat.sizeBytes > 0 || cat.shellCommand != nil)
    }

    var body: some View {
        Button(action: { if isSelectable { onTap() } }) {
            ZStack(alignment: .leading) {
                // 1. Progress Bar Background
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: geo.size.width * relativeWidth)
                }

                HStack(spacing: 12) {
                    // 2. Selection Indicator
                    ZStack {
                        if isSelectable {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
                                .font(.system(size: 16))
                        } else if cat.isAccessDenied {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                    }
                    .frame(width: 16)

                    Image(systemName: cat.icon)
                        .font(.system(size: 14))
                        .foregroundColor(cat.isAccessDenied ? .orange : (isSelectable ? .accentColor : .secondary.opacity(0.4)))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(cat.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(cat.isAccessDenied ? .orange : (isSelectable ? .primary : .secondary.opacity(0.6)))
                            SafetyBadge(safety: cat.safety)
                        }

                        if cat.isAccessDenied {
                            HStack(spacing: 4) {
                                Text("Permission Denied")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)

                                Button {
                                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Text("· Open Settings")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(cat.info)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(height: 34, alignment: .leading) // uniform 2-line rows

                    Spacer()

                    // 3. Loading or Data (Circular Progress)
                    HStack(spacing: 12) {
                        if !isScanning && !cat.isAccessDenied {
                            Text(cat.sizeBytes > 0 ? cat.sizeBytes.formattedSize : "0 KB")
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundColor(cat.sizeBytes > 0 ? .primary : .secondary)
                        }

                        if !cat.isAccessDenied {
                            GroupRing(
                                color: .accentColor,
                                fraction: Double(relativeWidth),
                                isSpinning: isScanning,
                                size: 14,
                                strokeWidth: 1.5
                            )
                        }
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable && !cat.isAccessDenied)
    }
}

struct ConfirmPayload: Identifiable {
    let id = UUID()
    let items: [CleanupCategory]
}

struct ConfirmSheet: View {
    let items: [CleanupCategory]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var totalSize: Int64 { CleanupManager.dedupedSize(items) }

    var body: some View {
        AppDialog(
            title: "Confirm Cleanup",
            subtitle: "Verify items to be permanently deleted",
            onDismiss: onCancel
        ) {
            VStack(spacing: 0) {
                ForEach(items) { cat in
                    HStack(spacing: 12) {
                        Image(systemName: cat.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(cat.name)
                                    .font(.system(size: 13, weight: .medium))
                                SafetyBadge(safety: cat.safety)
                            }
                            Text(cat.info)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                        Text(cat.sizeBytes.formattedSize)
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 36).opacity(0.1)
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL TO FREE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(totalSize.formattedSize).font(.system(size: 20, weight: .bold))
            }
            Spacer()
            AppButton(title: "Cancel", style: .glass, action: onCancel)
            AppButton(title: "Delete Now", style: .primary, action: onConfirm)
        }
    }
}

// MARK: - Clean All View

struct CleanAllView: View {
    var manager: CleanupManager
    let onDone: () -> Void
    @State private var currentName = ""
    @State private var progress: Double = 0
    var body: some View {
        VStack(spacing: 32) {
            Text("Cleaning...").font(.title2.bold())
            ProgressView(value: progress).frame(width: 300)
            Text(currentName).font(.subheadline)
        }
        .task {
            manager.beginCleanRun()
            let items = manager.categories.filter { manager.selectedIDs?.contains($0.id) ?? true }
            for (i, cat) in items.enumerated() {
                currentName = cat.name
                progress = Double(i) / Double(items.count)
                await manager.clean(category: cat)
            }
            currentName = "Finishing up…"
            progress = 1
            await manager.endCleanRun()
            onDone()
        }
    }
}

// MARK: - Done View

struct DoneView: View {
    var manager: CleanupManager
    let onBack: () -> Void
    let onRescan: () -> Void

    var body: some View {
        AppResultView(
            title: "Mission Accomplished",
            subtitle: "Your Mac is feeling much lighter now.",
            stats: [
                (label: "Freed", value: manager.totalFreedBytes.formattedSize, icon: "externaldrive.badge.checkmark"),
                (label: "Recovered", value: manager.diskActuallyFreed.formattedSize, icon: "arrow.down.left.circle")
            ]
        ) {
            AppButton(title: "Done", style: .primary, action: onBack)
            AppButton(title: "Scan", icon: "magnifyingglass", style: .primary, action: onRescan)
        }
    }
}
