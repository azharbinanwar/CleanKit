import SwiftUI

// MARK: - Uninstaller Groups

struct UninstallerGroup: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    var isLocked: Bool = false
    
    static let all: [UninstallerGroup] = [
        UninstallerGroup(id: "all", name: "All Apps", icon: "app", color: .accentColor),
        UninstallerGroup(id: "user", name: "User Apps", icon: "person", color: .accentColor),
        UninstallerGroup(id: "system", name: "System Apps", icon: "lock", color: .accentColor, isLocked: true),
        UninstallerGroup(id: "large", name: "Large Apps", icon: "scalemass", color: .accentColor),
        UninstallerGroup(id: "unused", name: "Unused Apps", icon: "clock", color: .accentColor)
    ]
}

// MARK: - Main View

struct AppUninstallerView: View {
    var scanner: AppUninstallerScanner
    
    @State private var selectedGroup: UninstallerGroup = UninstallerGroup.all[0]
    @State private var selectedAppID: UUID? = nil
    @State private var sortBy: SortOption = .size
    @State private var lastFreedSize: Int64 = 0
    @State private var searchText = ""
    @State private var pendingLeftovers: Set<UUID>? = nil   // set → show uninstall confirm
    @State private var pendingCacheClean: UUID? = nil       // set → show cache confirm
    @State private var lastResult: UninstallResult? = nil

    enum SortOption { case name, size, date }
    enum Screen { case main, result }
    @State private var currentScreen: Screen = .main

    /// Always read the LIVE app from the scanner so leftovers/size update as the
    /// background scan completes — not a stale snapshot taken at selection time.
    var selectedApp: AppInfo? {
        guard let id = selectedAppID else { return nil }
        return scanner.apps.first { $0.id == id }
    }
    
    /// How many apps fall into a group (ignores the search box, so the sidebar
    /// counts stay stable while searching).
    func count(for group: UninstallerGroup) -> Int {
        switch group.id {
        case "user":   return scanner.apps.filter { !$0.isProtected }.count
        case "system": return scanner.apps.filter { $0.isProtected }.count
        case "large":  return scanner.apps.filter { $0.sizeBytes > 500 * 1024 * 1024 }.count
        case "unused":
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            return scanner.apps.filter { ($0.lastUsedDate ?? Date()) < thirtyDaysAgo }.count
        default:       return scanner.apps.count
        }
    }

    var filteredApps: [AppInfo] {
        var list = scanner.apps

        switch selectedGroup.id {
        case "user":   list = list.filter { !$0.isProtected }
        case "system": list = list.filter { $0.isProtected }
        case "large":  list = list.filter { $0.sizeBytes > 500 * 1024 * 1024 }
        case "unused": 
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            list = list.filter { ($0.lastUsedDate ?? Date()) < thirtyDaysAgo }
        default: break
        }
        
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return list.sorted { 
            switch sortBy {
            case .name: return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            case .size: return $0.sizeBytes > $1.sizeBytes
            case .date: return ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast)
            }
        }
    }
    
    var body: some View {
        ZStack {
            if currentScreen == .main {
                mainContent
                    .blur(radius: pendingLeftovers != nil ? 10 : 0)
                    .disabled(pendingLeftovers != nil)
            } else {
                resultView
            }

            if let leftoverIDs = pendingLeftovers, let app = selectedApp {
                uninstallConfirmDialog(app: app, leftoverIDs: leftoverIDs)
                    .transition(.opacity)
                    .zIndex(100)
            }

            if let id = pendingCacheClean, let app = scanner.apps.first(where: { $0.id == id }) {
                cacheCleanConfirmDialog(app: app)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            if scanner.apps.isEmpty { Task { await scanner.scanApps() } }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 16) {
            header

            HStack(spacing: 16) {
                // 1. Sidebar: Groups
                VStack(spacing: 0) {
                    ForEach(UninstallerGroup.all) { group in
                        AppTile(
                            title: group.name,
                            icon: group.icon,
                            isSelected: selectedGroup.id == group.id,
                            action: { 
                                withAnimation(.spring()) {
                                    selectedAppID = nil
                                    selectedGroup = group 
                                }
                            }
                        ) {
                            Text("\(count(for: group))")
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundColor(selectedGroup.id == group.id ? .accentColor : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                        .padding(.horizontal, 8)
                    }
                    Spacer()
                }
                .frame(width: 220)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                
                // 2. Main Area: App List OR Details
                VStack(spacing: 0) {
                    if let id = selectedAppID {
                        AppDetailPanel(
                            appID: id,
                            scanner: scanner,
                            onBack: { withAnimation(.spring()) { selectedAppID = nil } },
                            onRequestUninstall: { leftoverIDs in
                                withAnimation(.spring()) { pendingLeftovers = leftoverIDs }
                            },
                            onRequestCleanCache: {
                                withAnimation(.spring()) { pendingCacheClean = id }
                            }
                        )
                        .id(id)
                    } else {
                        appListView
                    }
                }
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var appListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedGroup.name).font(.system(size: 14, weight: .bold))
                Spacer()
                HStack(spacing: 12) {
                    sortButton("Size", option: .size)
                    sortButton("Name", option: .name)
                    sortButton("Date", option: .date)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider().opacity(0.1)
            
            if scanner.isScanning {
                VStack(spacing: 20) {
                    Spacer()
                    AppLoading(size: 32, strokeWidth: 2)
                    Text("Analyzing your Applications folder…").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
            } else if filteredApps.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: selectedGroup.icon)
                        .font(.system(size: 48, weight: .thin))
                        .foregroundColor(.accentColor.opacity(0.5))
                    Text("No \(selectedGroup.name.lowercased()) found.").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppListRow(
                                app: app,
                                onSelect: {
                                    // The detail panel scans leftovers on appear and
                                    // selects them all; don't scan here too (racing
                                    // scans rebuild items with new IDs and break the
                                    // default selection).
                                    withAnimation(.spring()) { selectedAppID = app.id }
                                }
                            )
                            Divider().padding(.leading, 48).opacity(0.1)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var header: some View {
        AppHeader(title: "App Uninstaller", subtitle: "Remove applications and hidden leftovers") {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search apps…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .frame(width: 200, height: 32)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)

                Divider().frame(height: 24).opacity(0.1)

                AppButton(title: "Scan", icon: "magnifyingglass", style: .primary, isEnabled: !scanner.isScanning) {
                    Task { await scanner.scanApps() }
                }
            }
        }
    }
    

    private func uninstallConfirmDialog(app: AppInfo, leftoverIDs: Set<UUID>) -> some View {
        let leftovers = app.leftovers.filter { leftoverIDs.contains($0.id) }
        let total = app.sizeBytes + leftovers.reduce(0) { $0 + $1.sizeBytes }
        return AppDialog(
            title: "Uninstall \(app.name)?",
            subtitle: app.isProtected
                ? "This is a macOS system app. It may not fully remove."
                : "The app and the selected files below will be removed.",
            icon: "trash",
            tint: .red,
            onDismiss: { withAnimation(.spring()) { pendingLeftovers = nil } }
        ) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path)).resizable().frame(width: 28, height: 28).cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(.system(size: 13, weight: .semibold))
                        Text("Application").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(app.sizeBytes.formattedSize).font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                ForEach(leftovers) { item in
                    Divider().opacity(0.08)
                    HStack(spacing: 12) {
                        Image(systemName: "doc").foregroundColor(.secondary).frame(width: 28)
                        Text(item.label).font(.system(size: 12))
                        Spacer()
                        Text(item.sizeBytes.formattedSize).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL TO FREE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(total.formattedSize).font(.system(size: 20, weight: .bold))
            }
            Spacer()
            AppButton(title: "Cancel", style: .glass) { withAnimation(.spring()) { pendingLeftovers = nil } }
            AppButton(title: "Uninstall", style: .destructive) {
                withAnimation(.spring()) { pendingLeftovers = nil }
                Task {
                    let res = await scanner.uninstall(appID: app.id, leftoverIDs: leftoverIDs)
                    // Password cancelled = user aborted. Just stay on the detail
                    // view; no result screen.
                    if res.cancelled { return }
                    lastResult = res
                    lastFreedSize = res.freed
                    selectedAppID = nil
                    withAnimation { currentScreen = .result }
                }
            }
        }
    }

    private func cacheCleanConfirmDialog(app: AppInfo) -> some View {
        let cache = app.leftovers.filter(\.isCacheType)
        let total = cache.reduce(0) { $0 + $1.sizeBytes }
        return AppDialog(
            title: "Clean \(app.name) Cache?",
            subtitle: "These regenerate automatically. The app keeps working.",
            icon: "sparkles",
            onDismiss: { withAnimation(.spring()) { pendingCacheClean = nil } }
        ) {
            VStack(spacing: 0) {
                ForEach(cache) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive").foregroundColor(.secondary).frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label).font(.system(size: 12, weight: .medium))
                            Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(item.sizeBytes.formattedSize).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    Divider().opacity(0.08)
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL TO FREE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(total.formattedSize).font(.system(size: 20, weight: .bold))
            }
            Spacer()
            AppButton(title: "Cancel", style: .glass) { withAnimation(.spring()) { pendingCacheClean = nil } }
            AppButton(title: "Clean Cache", style: .primary) {
                let id = app.id
                withAnimation(.spring()) { pendingCacheClean = nil }
                Task {
                    let freed = await scanner.cleanCache(appID: id)
                    lastResult = UninstallResult(removed: false, freed: freed, cancelled: false, message: nil)
                    lastFreedSize = freed
                    withAnimation { currentScreen = .result }
                }
            }
        }
    }

    private var resultView: some View {
        let ok = lastResult?.removed ?? true
        let cacheOnly = lastResult?.removed == false && (lastResult?.message == nil)
        return AppResultView(
            title: cacheOnly ? "Cache Cleared" : (ok ? "Uninstalled Successfully" : "Not Removed"),
            subtitle: lastResult?.message ?? (cacheOnly ? "Cache files removed." : "The app and related files were removed."),
            stats: [(label: "Recovered", value: lastFreedSize.formattedSize, icon: "trash")]
        ) {
            AppButton(title: "Done", style: .primary) { lastResult = nil; currentScreen = .main }
        }
    }
    
    private func sortButton(_ title: String, option: SortOption) -> some View {
        Button(action: { withAnimation { sortBy = option } }) {
            Text(title).font(.system(size: 11, weight: sortBy == option ? .bold : .medium)).foregroundColor(sortBy == option ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Components

struct AppListRow: View {
    let app: AppInfo
    let onSelect: () -> Void
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path)).resizable().frame(width: 32, height: 32).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(app.lastUsedDate?.relativeString ?? "Never used").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                if app.isAppleApp { Image(systemName: "lock").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.4)) }
                Text(app.sizeBytes.formattedSize).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.2))
            }
            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AppDetailPanel: View {
    let appID: UUID
    var scanner: AppUninstallerScanner
    let onBack: () -> Void
    let onRequestUninstall: (Set<UUID>) -> Void
    let onRequestCleanCache: () -> Void
    @State private var selectedLeftoverIDs: Set<UUID> = []

    // Live app from the scanner (updates as the leftover scan finishes).
    private var app: AppInfo? { scanner.apps.first { $0.id == appID } }

    var body: some View {
        Group {
            if let app { content(app) } else { Color.clear.onAppear(perform: onBack) }
        }
        .onAppear {
            Task {
                await scanner.scanLeftovers(for: appID)
                // Everything checked by default, so uninstall leaves nothing behind.
                selectedLeftoverIDs = Set(otherItems.map { $0.id })
            }
        }
    }

    private var cacheItems: [LeftoverItem] { (app?.leftovers ?? []).filter(\.isCacheType) }
    private var otherItems: [LeftoverItem] { (app?.leftovers ?? []).filter { !$0.isCacheType } }

    @ViewBuilder
    private func content(_ app: AppInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onBack) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundColor(.secondary).frame(width: 32, height: 32).background(Color.primary.opacity(0.05)).clipShape(Circle()) }.buttonStyle(.plain)
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path)).resizable().frame(width: 48, height: 48).cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) { Text(app.name).font(.title3.bold()); Text("Version \(app.version)").font(.caption).foregroundColor(.secondary) }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) { Text(app.sizeBytes.formattedSize).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.accentColor); Text("App Size").font(.system(size: 8, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary) }
            }
            .padding(24)

            if app.isProtected {
                AppBanner(
                    icon: "exclamationmark.shield.fill",
                    message: "This is a macOS system app. macOS may not let you remove it."
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Divider().opacity(0.1)
            if app.isScanning {
                VStack { Spacer(); AppLoading(size: 32); Text("Finding related files…").font(.subheadline).foregroundColor(.secondary); Spacer() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // SECTION 1 — Cache
                        section(title: "Cache", count: cacheItems.count)
                        if cacheItems.isEmpty {
                            emptyRow("No cache files.")
                        } else {
                            ForEach(cacheItems) { item in leftoverRow(item, selectable: false) }
                        }

                        // SECTION 2 — App & other storage
                        section(title: "App & Other Storage", count: otherItems.count)
                        ForEach(otherItems) { item in leftoverRow(item, selectable: true) }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                Divider().opacity(0.1)
                footer(app)
            }
        }
    }

    private func section(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary)
            Spacer()
            Text("\(count) item\(count == 1 ? "" : "s")").font(.system(size: 10)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
    }

    private func emptyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle").foregroundColor(.secondary.opacity(0.4)).font(.system(size: 14))
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 6)
    }

    private func leftoverRow(_ item: LeftoverItem, selectable: Bool) -> some View {
        Button(action: {
            guard selectable else { return }
            if selectedLeftoverIDs.contains(item.id) { selectedLeftoverIDs.remove(item.id) } else { selectedLeftoverIDs.insert(item.id) }
        }) {
            HStack(spacing: 12) {
                if selectable {
                    Image(systemName: selectedLeftoverIDs.contains(item.id) ? "checkmark.circle.fill" : "circle").foregroundColor(selectedLeftoverIDs.contains(item.id) ? .accentColor : .secondary.opacity(0.3)).font(.system(size: 16))
                } else {
                    Image(systemName: "internaldrive").foregroundColor(.secondary.opacity(0.5)).font(.system(size: 14)).frame(width: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label).font(.system(size: 12, weight: .medium))
                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(item.sizeBytes.formattedSize).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func footer(_ app: AppInfo) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                let total = app.sizeBytes + otherItems.filter { selectedLeftoverIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
                Text("Total to free: \(total.formattedSize)").font(.system(size: 13, weight: .bold))
                Text("App + \(selectedLeftoverIDs.count) selected").font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            if !cacheItems.isEmpty {
                AppButton(title: "Clean Cache", icon: "sparkles", style: .glass) { onRequestCleanCache() }
            }
            // Uninstall removes the app + selected storage + ALL its cache.
            AppButton(title: "Uninstall", icon: "trash", style: .primary) {
                onRequestUninstall(selectedLeftoverIDs.union(cacheItems.map { $0.id }))
            }
        }
        .padding(24)
    }
}
