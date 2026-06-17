import SwiftUI

// MARK: - Tool

enum Tool: String, CaseIterable, Identifiable {
    case home         = "Dashboard"
    case cleaner      = "Mac Cleaner"
    case largeFinder  = "Large File Finder"
    case uninstaller  = "App Uninstaller"
    case duplicates   = "Duplicate Finder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:        "house.fill"
        case .cleaner:     "trash.fill"
        case .largeFinder: "doc.text.magnifyingglass"
        case .uninstaller: "minus.circle.fill"
        case .duplicates:  "doc.on.doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .home:        .blue
        case .cleaner:     .accentColor
        case .largeFinder: .orange
        case .uninstaller: .red
        case .duplicates:  .purple
        }
    }

    var subtitle: String {
        switch self {
        case .home:        "Overview & stats"
        case .cleaner:     "categories"
        case .largeFinder: "Find files over a size threshold"
        case .uninstaller: "Apps & leftovers"
        case .duplicates:  "Find identical files"
        }
    }

    var available: Bool { self == .cleaner || self == .home || self == .largeFinder || self == .uninstaller || self == .duplicates }
}

// MARK: - Root

struct ContentView: View {
    @State private var manager = CleanupManager()
    @State private var largeScanner = LargeFileScanner()
    @State private var appUninstallerScanner = AppUninstallerScanner()
    @State private var duplicateScanner = DuplicateScanner()
    @State private var screen: Screen = .scan
    @State private var selectedTool: Tool = .home
    @State private var categorySettings = CategorySettings()
    @State private var sidebarCompact = false
    @State private var showSettings = false
    @State private var showPermissions = false
    @State private var requiredPermissions: [AppPermission] = []
    @AppStorage("appTheme") private var appTheme: String = "system"

    enum Screen { case scan, cleanAll, done }

    private var resolvedColorScheme: ColorScheme {
        switch appTheme {
        case "dark":  return .dark
        case "light": return .light
        default:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTool: $selectedTool, isCompact: $sidebarCompact, showSettings: $showSettings, categorySettings: categorySettings)
            Divider()
            Group {
                if showSettings {
                    SettingsView(categorySettings: categorySettings)
                } else {
                    detailView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PermissionsPanel(isShowing: $showPermissions, permissions: requiredPermissions)
        }
        .frame(minWidth: 860, minHeight: 620)
        .preferredColorScheme(resolvedColorScheme)
        .animation(.easeInOut(duration: 0.2), value: showPermissions)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTool {
        case .home:        DashboardView(manager: manager, categorySettings: categorySettings, onSelectTool: { selectedTool = $0 })
        case .cleaner:     cleanerView
        case .largeFinder: LargeFileView(scanner: largeScanner, onPermissionMissing: { perms in
            requiredPermissions = perms
            withAnimation(.easeInOut(duration: 0.2)) { showPermissions = true }
        })
        case .uninstaller: AppUninstallerView(scanner: appUninstallerScanner)
        case .duplicates:  DuplicateFinderView(scanner: duplicateScanner)
        default:           ComingSoonView(tool: selectedTool)
        }
    }

    @ViewBuilder
    private var cleanerView: some View {
        switch screen {
        case .scan:
            MacCleanerView(manager: manager, categorySettings: categorySettings, onClean: { screen = .cleanAll })
        case .cleanAll:
            CleanAllView(manager: manager, onDone: { screen = .done })
        case .done:
            DoneView(
                manager: manager,
                onBack: {
                    selectedTool = .home
                    screen = .scan
                },
                onRescan: {
                    manager.totalFreedBytes = 0
                    manager.categories = categorySettings.enabledCategories
                    screen = .scan
                    Task { await manager.scanAll() }
                }
            )
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTool: Tool
    @Binding var isCompact: Bool
    @Binding var showSettings: Bool
    let categorySettings: CategorySettings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if !isCompact {
                    Text("CleanKit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    Spacer()
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isCompact.toggle() }
                } label: {
                    Image(systemName: isCompact ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, isCompact ? 0 : 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, 14)

            Divider()

            VStack(spacing: 2) {
                ForEach(Tool.allCases) { tool in
                    SidebarItem(tool: tool, isSelected: selectedTool == tool && !showSettings, isCompact: isCompact, enabledCategoryCount: categorySettings.enabledCount) {
                        showSettings = false
                        selectedTool = tool
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()

            Divider()

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: isCompact ? 16 : 14))
                        .foregroundColor(showSettings ? .accentColor : .secondary)
                        .frame(width: 24, height: 24)
                    if !isCompact {
                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(showSettings ? .accentColor : .secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, isCompact ? 0 : 8)
                .padding(.vertical, 10)
                .frame(maxWidth: isCompact ? .infinity : nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(width: isCompact ? 56 : 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct SidebarItem: View {
    let tool: Tool
    let isSelected: Bool
    let isCompact: Bool
    let onTap: () -> Void
    var enabledCategoryCount: Int = CleanupCategory.all.count

    var body: some View {
        Button(action: onTap) {
            if isCompact {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? tool.color.opacity(0.15) : Color.clear)
                        .frame(width: 40, height: 40)
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(tool.color.opacity(tool.available ? 1 : 0.35))
                            .frame(width: 28, height: 28)
                        Image(systemName: tool.icon)
                            .foregroundColor(.white)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            } else {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tool.color.opacity(tool.available ? 1 : 0.35))
                            .frame(width: 30, height: 30)
                        Image(systemName: tool.icon)
                            .foregroundColor(.white)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tool.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(tool.available ? .primary : .secondary)
                        Text(tool == .cleaner ? "\(enabledCategoryCount) categories" : tool.subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? Color.secondary.opacity(0.12) : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(!tool.available)
        .opacity(tool.available ? 1 : 0.45)
        .help(isCompact ? tool.rawValue : "")
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    var manager: CleanupManager
    let categorySettings: CategorySettings
    let onSelectTool: (Tool) -> Void
    @State private var storageInfo = StorageInfo.load()

    private var tools: [Tool] { Tool.allCases.filter { $0 != .home } }

    private var cleanerLabel: String {
        if manager.isScanning { return "Scanning..." }
        let total = manager.categories.reduce(0) { $0 + $1.sizeBytes }
        return total > 0 ? total.formattedSize : "Scan Now"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroHeader
                DiskHealthCard(info: storageInfo)
                toolsSection
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var heroHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CleanKit")
                    .font(.title.bold())
                Text("Developer toolkit for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tools").font(.title3.bold())
                Spacer()
                Text("\(tools.count) tools")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element) { idx, tool in
                    if idx > 0 { Divider().padding(.leading, 70) }
                    ToolRow(
                        tool: tool,
                        scanLabel: tool == .cleaner ? cleanerLabel : nil,
                        enabledCategoryCount: categorySettings.enabledCount,
                        onOpen: { onSelectTool(tool) },
                        onScan: tool == .cleaner ? { Task { await manager.scanAll() } } : nil
                    )
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

// MARK: - Disk Health Card

struct DiskHealthCard: View {
    let info: StorageInfo

    var statusColor: Color {
        info.usedFraction > 0.9 ? .red : info.usedFraction > 0.75 ? .orange : .green
    }
    var statusLabel: String {
        info.usedFraction > 0.9 ? "Critical" : info.usedFraction > 0.75 ? "Getting Full" : "Healthy"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text("Disk Health").font(.headline)
                    }
                    Text(statusLabel)
                        .font(.caption.weight(.medium))
                        .foregroundColor(statusColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(info.free.formattedSize)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                    Text("available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 28) {
                    diskStat("Used",  info.used.formattedSize,  statusColor)
                    diskStat("Free",  info.free.formattedSize,  Color.secondary.opacity(0.6))
                    diskStat("Total", info.total.formattedSize, Color.secondary.opacity(0.6))
                    Spacer()
                    Text("\(Int(info.usedFraction * 100))% used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 20)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(statusColor)
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: CGFloat(info.usedFraction), anchor: .leading)
                        .animation(.easeInOut(duration: 1.0), value: info.usedFraction)
                }

                HStack {
                    Text("Used · \(info.used.formattedSize)")
                    Spacer()
                    Text("Free · \(info.free.formattedSize)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(14)
    }

    private func diskStat(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption.bold())
        }
    }
}

// MARK: - Tool Row

struct ToolRow: View {
    let tool: Tool
    var scanLabel: String? = nil
    var enabledCategoryCount: Int = CleanupCategory.all.count
    let onOpen: () -> Void
    var onScan: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        Button {
            guard tool.available else { return }
            onOpen()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tool.color.opacity(tool.available ? 0.14 : 0.06))
                        .frame(width: 40, height: 40)
                    Image(systemName: tool.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(tool.available ? tool.color : tool.color.opacity(0.35))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tool.available ? .primary : .secondary)
                    Text(tool == .cleaner ? "\(enabledCategoryCount) categories" : tool.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if tool.available, let label = scanLabel {
                    pillView(label: label)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                } else if !tool.available {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.caption2)
                        Text("Coming Soon").font(.caption)
                    }
                    .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isHovered && tool.available ? Color.secondary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func pillView(label: String) -> some View {
        if label == "Scan Now", let scan = onScan {
            Button {
                scan()
            } label: {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        } else if label == "Scanning..." {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.09))
                .cornerRadius(6)
        } else {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// MARK: - Coming Soon

struct ComingSoonView: View {
    let tool: Tool
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(tool.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: tool.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(tool.color.opacity(0.6))
            }
            Text(tool.rawValue).font(.title2.bold())
            Text("Coming Soon").foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Screen 2: Clean with progress

struct CleanAllView: View {
    var manager: CleanupManager
    let onDone: () -> Void

    @State private var currentName = ""
    @State private var progress: Double = 0

    var toClean: [CleanupCategory] {
        if let ids = manager.selectedIDs {
            return manager.categories.filter { ids.contains($0.id) }
        }
        return manager.categories
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("Cleaning...")
                .font(.title2.bold())
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 320)
                Text(currentName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 20)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            let items = toClean
            for (i, cat) in items.enumerated() {
                currentName = cat.name
                progress = Double(i) / Double(items.count)
                await manager.clean(category: cat)
            }
            progress = 1.0
            onDone()
        }
    }
}

// MARK: - Screen 3: Done

struct DoneView: View {
    var manager: CleanupManager
    let onBack: () -> Void
    let onRescan: () -> Void

    var cleanedCategories: [CleanupCategory] {
        manager.categories.filter { $0.cleaned && $0.freedBytes > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.1)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 46))
                            .foregroundColor(.green)
                    }
                    Text("All Done!").font(.title.bold())
                    Text("Freed \(manager.totalFreedBytes.formattedSize) total")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 1) {
                    ForEach(CleanerGroup.all) { group in
                        let groupCats = cleanedCategories.filter { group.categoryNames.contains($0.name) }
                        if !groupCats.isEmpty {
                            let groupTotal = groupCats.reduce(0) { $0 + $1.freedBytes }
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(group.color).frame(width: 26, height: 26)
                                    Image(systemName: group.icon).foregroundColor(.white)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                Text(group.name).font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(groupTotal.formattedSize).font(.callout.bold()).foregroundColor(group.color)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color(nsColor: .controlBackgroundColor))

                            ForEach(groupCats) { cat in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green).font(.system(size: 15))
                                        Image(systemName: cat.icon)
                                            .foregroundColor(.secondary).frame(width: 16)
                                        Text(cat.name).font(.system(size: 13))
                                        Spacer()
                                        Text(cat.freedBytes.formattedSize)
                                            .font(.callout.monospacedDigit())
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    Button("Back") { onBack() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("Scan Again") { onRescan() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}
