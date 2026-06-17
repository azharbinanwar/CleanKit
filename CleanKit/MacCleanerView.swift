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
            id: "developer", name: "Developer", icon: "hammer.fill", color: .blue,
            categoryNames: [
                "Xcode DerivedData", "Xcode Archives", "Xcode iOS Device Support", "Xcode Cache",
                "Gradle Caches", "CocoaPods Cache", "Carthage Artifacts",
                "npm Cache", "Yarn Cache", "pnpm Store",
                "Flutter pub-cache", "FVM SDK Cache",
                "nvm Cache", "sdkman Archives", "asdf Downloads", "pyenv Cache",
                "Ruby Gems Cache", "Python pip Cache",
                "Maven Local Repo", "Cargo Registry Cache", "Go Module Cache",
                "Swift Package Manager", "Deno Cache", "Bun Cache",
                "Composer Cache", "Helm Cache", "Terraform Plugin Cache",
                "Android AVD", "Android Cache",
                "JetBrains Caches", "VS Code Cache"
            ]
        ),
        CleanerGroup(
            id: "apps", name: "Apps", icon: "square.grid.2x2.fill", color: .purple,
            categoryNames: [
                "Chrome Cache", "Arc Cache", "Brave Cache", "Firefox Cache",
                "Slack Cache", "Discord Cache", "Spotify Cache", "Figma Cache", "Zoom Speech Cache"
            ]
        ),
        CleanerGroup(
            id: "system", name: "System", icon: "gearshape.fill", color: .orange,
            categoryNames: [
                "Library/Caches (All Apps)", "Homebrew Cache", "QuickLook Thumbnails",
                "Mail Attachments Cache", "iOS Backups", "Trash", "Wallpaper Aerials",
                "Safari Cache", "Music Cache", "App Store Cache",
                "Translation Cache", "Game Center Cache"
            ]
        ),
        CleanerGroup(
            id: "logs", name: "Logs", icon: "doc.text.fill", color: .green,
            categoryNames: ["All Logs"]
        ),
        CleanerGroup(
            id: "commands", name: "Commands", icon: "terminal.fill", color: .teal,
            categoryNames: ["iOS Simulator (Unavailable)", "Docker System Prune"]
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

    var allGroupsTotal: Int64 {
        manager.categories.reduce(0) { $0 + $1.sizeBytes }
    }

    var allGroupsFileCount: Int {
        manager.categories.reduce(0) { $0 + $1.fileCount }
    }

    var selectedTotal: Int64 {
        manager.categories.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedFileCount: Int {
        manager.categories.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.fileCount }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                GroupPanel(
                    manager: manager,
                    categorySettings: categorySettings,
                    selectedGroup: $selectedGroup,
                    allGroupsTotal: allGroupsTotal
                )
                Divider()
                CategoryPanel(
                    manager: manager,
                    group: selectedGroup,
                    selectedIDs: $selectedIDs
                )
            }
            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            manager.categories = manager.categories.filter { categorySettings.isEnabled($0.name) }
            let hasData = manager.categories.contains { $0.sizeBytes > 0 }
            guard !hasData && !manager.isScanning else { return }
            manager.categories = categorySettings.enabledCategories
            Task { await manager.scanAll() }
        }
        .sheet(item: $confirmPayload) { payload in
            ConfirmSheet(items: payload.items, onCancel: {
                confirmPayload = nil
            }, onConfirm: {
                confirmPayload = nil
                manager.selectedIDs = Set(payload.items.map { $0.id })
                onClean()
            })
        }
    }

    private var header: some View {
        ToolHeaderView(title: "Mac Cleaner", subtitle: "\(categorySettings.enabledCount) categories enabled") {
            Button {
                selectedIDs = []
                manager.categories = categorySettings.enabledCategories
                Task { await manager.scanAll() }
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .disabled(manager.isScanning)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if manager.isScanning {
                Text("Scanning…").foregroundColor(.secondary).font(.subheadline)
                ProgressView().scaleEffect(0.7)
                Spacer()
            } else if selectedIDs.isEmpty {
                Text("Found: **\(allGroupsTotal.formattedSize)** · \(allGroupsFileCount.formatted()) files").font(.subheadline)
                Spacer()
                Button("Select All") {
                    let ids = manager.categories
                        .filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
                        .map { $0.id }
                    selectedIDs = Set(ids)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(allGroupsTotal == 0)
                Button("Clean All") {
                    let items = manager.categories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
                    confirmPayload = ConfirmPayload(items: items)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(allGroupsTotal == 0)
            } else {
                Button("Deselect All") { selectedIDs = [] }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(selectedIDs.count) selected · \(selectedTotal.formattedSize) · \(selectedFileCount.formatted()) files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clean Selected") {
                    let items = manager.categories.filter { selectedIDs.contains($0.id) }
                    confirmPayload = ConfirmPayload(items: items)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Group Panel

struct GroupPanel: View {
    var manager: CleanupManager
    let categorySettings: CategorySettings
    @Binding var selectedGroup: CleanerGroup
    let allGroupsTotal: Int64

    private var visibleGroups: [CleanerGroup] {
        CleanerGroup.all.filter { group in
            group.categoryNames.contains { categorySettings.isEnabled($0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(visibleGroups) { group in
                GroupRow(
                    group: group,
                    manager: manager,
                    allGroupsTotal: allGroupsTotal,
                    isSelected: selectedGroup.id == group.id
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedGroup = group }
                Divider().opacity(0.4)
            }
            Spacer()
        }
        .frame(width: 200)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
}

struct GroupRow: View {
    let group: CleanerGroup
    var manager: CleanupManager
    let allGroupsTotal: Int64
    let isSelected: Bool

    var groupTotal: Int64 {
        manager.categories
            .filter { group.categoryNames.contains($0.name) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var groupFileCount: Int {
        manager.categories
            .filter { group.categoryNames.contains($0.name) }
            .reduce(0) { $0 + $1.fileCount }
    }

    var fraction: Double {
        guard allGroupsTotal > 0 else { return 0 }
        return min(1.0, Double(groupTotal) / Double(allGroupsTotal))
    }

    var isGroupScanning: Bool {
        guard let idx = manager.scanningIndex, idx < manager.categories.count else { return false }
        return group.categoryNames.contains(manager.categories[idx].name)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(group.color)
                    .frame(width: 28, height: 28)
                Image(systemName: group.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if groupTotal > 0 {
                    Text(groupTotal.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(groupFileCount.formatted()) files")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                } else {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            GroupRing(color: group.color, fraction: fraction, isSpinning: isGroupScanning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(isSelected ? group.color.opacity(0.1) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Group Ring

struct GroupRing: View {
    let color: Color
    let fraction: Double
    let isSpinning: Bool

    @State private var spinDegrees: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 3)

            if isSpinning {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(spinDegrees - 90))
                    .onAppear {
                        spinDegrees = 0
                        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                            spinDegrees = 360
                        }
                    }
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat(min(fraction, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)
            }
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Category Panel

struct CategoryPanel: View {
    var manager: CleanupManager
    let group: CleanerGroup
    @Binding var selectedIDs: Set<UUID>
    @State private var sortLargest = true

    var categories: [CleanupCategory] {
        group.categoryNames.compactMap { name in
            manager.categories.first { $0.name == name }
        }
    }

    var groupMax: Int64 {
        categories.map { $0.sizeBytes }.max() ?? 1
    }

    var foundCategories: [CleanupCategory] {
        let items = categories.filter { $0.sizeBytes > 0 || $0.shellCommand != nil }
        return items.sorted { sortLargest ? $0.sizeBytes > $1.sizeBytes : $0.sizeBytes < $1.sizeBytes }
    }

    var emptyCategories: [CleanupCategory] {
        categories.filter { $0.sizeBytes == 0 && $0.shellCommand == nil }
    }

    var body: some View {
        let _ = manager.categories
        let _ = manager.isScanning
        return VStack(spacing: 0) {
            panelHeader
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if manager.isScanning {
                        ForEach(categories) { cat in
                            categoryRow(cat)
                            Divider().padding(.leading, 52)
                        }
                    } else {
                        if !foundCategories.isEmpty {
                            sectionHeader("Ready to Clean — \(foundCategories.count) items")
                            ForEach(foundCategories) { cat in
                                categoryRow(cat)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                Divider().padding(.leading, 52)
                            }
                        }
                        if !emptyCategories.isEmpty {
                            sectionHeader("Nothing Found — \(emptyCategories.count) items")
                            ForEach(emptyCategories) { cat in
                                categoryRow(cat)
                                    .transition(.opacity)
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: foundCategories.map { $0.id })
                .animation(.easeInOut(duration: 0.2), value: sortLargest)
            }
        }
    }

    private var panelHeader: some View {
        HStack {
            Text(group.name).font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { sortLargest.toggle() }
            } label: {
                Label(sortLargest ? "Largest" : "Smallest", systemImage: sortLargest ? "arrow.down" : "arrow.up")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            Menu {
                Button {
                    selectedIDs.formUnion(foundCategories.map { $0.id })
                } label: {
                    Label("Select All", systemImage: "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) {
                    categories.forEach { selectedIDs.remove($0.id) }
                } label: {
                    Label("Deselect All", systemImage: "xmark.circle")
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Select")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func categoryRow(_ cat: CleanupCategory) -> some View {
        let isScanning = manager.scanningIndex == manager.categories.firstIndex(where: { $0.id == cat.id })
        let isSelected = selectedIDs.contains(cat.id)
        let isCleanable = cat.sizeBytes > 0 || cat.shellCommand != nil
        let fraction = groupMax > 0 ? Double(cat.sizeBytes) / Double(groupMax) : 0.0
        let history = CleanHistory.shared.record(for: cat.name)

        return Button {
            guard isCleanable && !isScanning else { return }
            if isSelected { selectedIDs.remove(cat.id) } else { selectedIDs.insert(cat.id) }
        } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.065))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: CGFloat(fraction), anchor: .leading)
                    .animation(.easeOut(duration: 0.4), value: fraction)

                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
                        .font(.system(size: 18))
                        .animation(.easeInOut(duration: 0.15), value: isSelected)

                    Image(systemName: cat.icon)
                        .frame(width: 18)
                        .foregroundColor(isCleanable ? .accentColor : .secondary.opacity(0.3))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.name)
                            .font(.system(size: 13))
                            .foregroundColor(isCleanable ? .primary : .secondary)
                        if let h = history {
                            Text("Cleaned \(h.totalCleanCount)x · \(h.lastCleaned.relativeString) · freed \(h.lastFreedBytes.formattedSize)")
                                .font(.caption2)
                                .foregroundColor(.accentColor.opacity(0.7))
                        }
                    }

                    Spacer()

                    if isScanning {
                        ProgressView().scaleEffect(0.65).frame(width: 64)
                    } else {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(cat.sizeBytes > 0
                                 ? cat.sizeBytes.formattedSize
                                 : cat.shellCommand != nil ? "cmd" : "—")
                                .foregroundColor(
                                    cat.sizeBytes > 0 ? .primary
                                    : cat.shellCommand != nil ? .accentColor.opacity(0.8)
                                    : .secondary.opacity(0.3)
                                )
                                .font(cat.shellCommand != nil && cat.sizeBytes == 0
                                      ? .caption.bold()
                                      : .callout.monospacedDigit())
                            if cat.fileCount > 0 {
                                Text("\(cat.fileCount.formatted()) files")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .frame(width: 64, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Confirm Payload

struct ConfirmPayload: Identifiable {
    let id = UUID()
    let items: [CleanupCategory]
}

// MARK: - Confirm Sheet

struct ConfirmSheet: View {
    let items: [CleanupCategory]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "trash.fill").foregroundColor(.red)
                Text("Confirm Cleanup").font(.title3.bold())
                Spacer()
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { cat in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cat.name).font(.system(size: 13))
                                if cat.fileCount > 0 {
                                    Text("\(cat.fileCount.formatted()) files")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(cat.sizeBytes > 0 ? cat.sizeBytes.formattedSize : "—")
                                .font(.callout.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 64)
                    }
                }
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total to free").font(.caption).foregroundColor(.secondary)
                    Text(totalSize.formattedSize).font(.headline)
                }
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.bordered).controlSize(.large)
                Button("Delete Now") { onConfirm() }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 480, height: 400)
    }
}
