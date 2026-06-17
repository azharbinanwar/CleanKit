import SwiftUI
import AppKit

private enum AppSort: String, CaseIterable {
    case name      = "Name"
    case leastUsed = "Least Used"
    case mostUsed  = "Most Recent"
}

private struct UninstallConfirm: Identifiable {
    let id = UUID()
    let app: AppInfo
    let leftoverIDs: Set<UUID>
}

private struct CacheCleanConfirm: Identifiable {
    let id = UUID()
    let app: AppInfo
}

struct AppUninstallerView: View {
    var scanner: AppUninstallerScanner

    @State private var selectedAppID: UUID? = nil
    @State private var searchText = ""
    @State private var sortOrder: AppSort = .leastUsed
    @State private var confirm: UninstallConfirm? = nil
    @State private var cacheConfirm: CacheCleanConfirm? = nil
    @State private var hoveredAppID: UUID? = nil
    @State private var hoveredLeftoverID: UUID? = nil

    var filteredApps: [AppInfo] {
        let base = searchText.isEmpty ? scanner.apps : scanner.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOrder {
        case .name:      return base
        case .leastUsed: return base.sorted { ($0.lastUsedDate ?? .distantPast) < ($1.lastUsedDate ?? .distantPast) }
        case .mostUsed:  return base.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
        }
    }

    var selectedApp: AppInfo? {
        guard let id = selectedAppID else { return nil }
        return scanner.apps.first { $0.id == id }
    }

    var body: some View {
        let _ = scanner.apps
        let _ = scanner.isScanning

        VStack(spacing: 0) {
            toolbar
            Divider()
            if scanner.isScanning {
                scanningView
            } else if scanner.apps.isEmpty {
                emptyView
            } else {
                HStack(spacing: 0) {
                    leftPanel
                    Divider()
                    rightPanel
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $confirm) { payload in
            UninstallConfirmSheet(app: payload.app, initialLeftoverIDs: payload.leftoverIDs) {
                confirm = nil
            } onConfirm: { selectedIDs in
                let appID = payload.app.id
                confirm = nil
                selectedAppID = nil
                Task { await scanner.uninstall(appID: appID, leftoverIDs: selectedIDs) }
            }
        }
        .sheet(item: $cacheConfirm) { payload in
            CacheCleanConfirmSheet(app: payload.app) {
                cacheConfirm = nil
            } onConfirm: {
                let appID = payload.app.id
                cacheConfirm = nil
                Task { await scanner.cleanCache(appID: appID) }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("App Uninstaller")
                    .font(.title2.bold())
                Text("Remove apps and their leftover files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                selectedAppID = nil
                Task { await scanner.scanApps() }
            } label: {
                Label(scanner.apps.isEmpty ? "Scan" : "Re-scan", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanner.isScanning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack(spacing: 6) {
                ForEach(AppSort.allCases, id: \.self) { sort in
                    Button { sortOrder = sort } label: {
                        Text(sort.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(sortOrder == sort ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundColor(sortOrder == sort ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                        Divider().padding(.leading, 52)
                    }
                }
            }

            Divider()
            Text("\(filteredApps.count) app\(filteredApps.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        }
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: selectedAppID, initial: false) { _, newID in
            guard let id = newID,
                  let app = scanner.apps.first(where: { $0.id == id }),
                  app.leftovers.isEmpty, !app.isScanning
            else { return }
            Task { await scanner.scanLeftovers(for: id) }
        }
    }

    private func appRow(_ app: AppInfo) -> some View {
        let selected = selectedAppID == app.id
        let hovered = hoveredAppID == app.id
        return Button { selectedAppID = app.id } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(app.lastUsedDate.map { $0.relativeString } ?? "Never used")
                        .font(.caption2)
                        .foregroundColor(app.lastUsedDate == nil ? .orange.opacity(0.8) : .secondary)
                }
                Spacer()
                if !app.isDeletable || app.isAppleApp {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor.opacity(0.12) : hovered ? Color.secondary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredAppID = $0 ? app.id : nil }
    }

    // MARK: - Right panel

    @ViewBuilder
    private var rightPanel: some View {
        if let app = selectedApp {
            VStack(spacing: 0) {
                appDetailHeader(app)
                Divider()
                if app.isScanning {
                    leftoverScanningView
                } else if app.leftovers.isEmpty {
                    noLeftoversView(app)
                } else {
                    leftoverList(app)
                    Divider()
                    bottomBar(app)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            noSelectionView
        }
    }

    private func appDetailHeader(_ app: AppInfo) -> some View {
        HStack(spacing: 16) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                .resizable()
                .frame(width: 52, height: 52)
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title3.bold())
                if !app.version.isEmpty {
                    Text("Version \(app.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(app.appURL.deletingLastPathComponent().path
                    .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if app.sizeBytes > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.sizeBytes.formattedSize)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("app size").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func leftoverList(_ app: AppInfo) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                selectAllRow(app)
                Divider()
                ForEach(app.leftovers) { item in
                    leftoverRow(app: app, item: item)
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private func selectAllRow(_ app: AppInfo) -> some View {
        let allSelected = app.leftovers.allSatisfy(\.isSelected)
        let totalSize = app.leftovers.reduce(0) { $0 + $1.sizeBytes }
        return HStack {
            Button {
                guard let aIdx = scanner.apps.firstIndex(where: { $0.id == app.id }) else { return }
                for i in scanner.apps[aIdx].leftovers.indices {
                    scanner.apps[aIdx].leftovers[i].isSelected = !allSelected
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(allSelected ? .accentColor : .secondary)
                    Text("Select All").font(.caption).foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(app.leftovers.count) items · \(totalSize.formattedSize)")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func leftoverRow(app: AppInfo, item: LeftoverItem) -> some View {
        let hovered = hoveredLeftoverID == item.id
        return Button {
            guard let aIdx = scanner.apps.firstIndex(where: { $0.id == app.id }),
                  let iIdx = scanner.apps[aIdx].leftovers.firstIndex(where: { $0.id == item.id })
            else { return }
            scanner.apps[aIdx].leftovers[iIdx].isSelected.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isSelected ? .accentColor : Color.secondary.opacity(0.4))
                    .font(.system(size: 18))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 13, weight: .medium))
                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if hovered {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                            Text("Show")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Text(item.sizeBytes.formattedSize)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(hovered ? Color.secondary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredLeftoverID = $0 ? item.id : nil }
    }

    private func bottomBar(_ app: AppInfo) -> some View {
        let selectedLeftovers = app.leftovers.filter(\.isSelected)
        let leftoverSize = selectedLeftovers.reduce(0) { $0 + $1.sizeBytes }
        let total = app.sizeBytes + leftoverSize
        let hasCacheItems = app.leftovers.contains(where: \.isCacheType)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total to free: \(total.formattedSize)")
                    .font(.caption.weight(.medium))
                Text("App + \(selectedLeftovers.count) leftover\(selectedLeftovers.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if hasCacheItems {
                Button {
                    cacheConfirm = CacheCleanConfirm(app: app)
                } label: {
                    Label("Clean Cache", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
            if app.isDeletable {
                Button {
                    let ids = Set(selectedLeftovers.map(\.id))
                    confirm = UninstallConfirm(app: app, leftoverIDs: ids)
                } label: {
                    Label("Uninstall + Clean", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill").font(.caption)
                    Text("System App").font(.caption.weight(.medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - States

    private var emptyView: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
            }
            Text("App Uninstaller").font(.title2.bold())
            Text("Scan to find installed apps and clean up their leftover files.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button {
                Task { await scanner.scanApps() }
            } label: {
                Label("Scan Apps", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Scanning Applications...").font(.title3.bold())
            Text("Reading app bundles in /Applications")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leftoverScanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Finding leftovers...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSelectionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select an app")
                .font(.title3)
                .foregroundColor(.secondary.opacity(0.6))
            Text("Choose an app from the list to inspect its leftovers")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func noLeftoversView(_ app: AppInfo) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.green.opacity(0.7))
            }
            Text("No Leftovers Found")
                .font(.headline)
            Text("Only the app bundle will be moved to Trash.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button {
                confirm = UninstallConfirm(app: app, leftoverIDs: [])
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Uninstall confirm sheet

private struct UninstallConfirmSheet: View {
    let app: AppInfo
    let initialLeftoverIDs: Set<UUID>
    let onCancel: () -> Void
    let onConfirm: (Set<UUID>) -> Void

    @State private var selectedIDs: Set<UUID>

    init(app: AppInfo, initialLeftoverIDs: Set<UUID>, onCancel: @escaping () -> Void, onConfirm: @escaping (Set<UUID>) -> Void) {
        self.app = app
        self.initialLeftoverIDs = initialLeftoverIDs
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedIDs = State(initialValue: initialLeftoverIDs)
    }

    var selectedSize: Int64 { app.leftovers.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes } }
    var total: Int64 { app.sizeBytes + selectedSize }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red)
                Text("Uninstall \(app.name)?")
                    .font(.title3.bold())
                if app.isAppleApp {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 14))
                        Text("macOS may restore this app automatically.")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.red).font(.system(size: 16)).frame(width: 20)
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                            .resizable().frame(width: 20, height: 20).cornerRadius(4)
                        Text(app.name).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(app.sizeBytes.formattedSize)
                            .font(.system(size: 12).monospacedDigit()).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.red.opacity(0.04))

                    if !app.leftovers.isEmpty {
                        Divider()
                        HStack {
                            Text("Leftovers").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(selectedIDs.count) of \(app.leftovers.count) selected")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))

                        ForEach(app.leftovers) { item in
                            let checked = selectedIDs.contains(item.id)
                            Button {
                                if checked { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(checked ? .accentColor : Color.secondary.opacity(0.4))
                                        .font(.system(size: 16)).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(checked ? .primary : .secondary)
                                        Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                            .font(.caption2).foregroundColor(.secondary)
                                            .lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(item.sizeBytes.formattedSize)
                                        .font(.system(size: 12).monospacedDigit())
                                        .foregroundColor(checked ? .secondary : .secondary.opacity(0.4))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(checked ? Color.accentColor.opacity(0.04) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .frame(maxHeight: 240)

            Divider()

            HStack {
                Text("Frees up \(total.formattedSize)").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.bordered).controlSize(.large)
                Button("Uninstall") { onConfirm(selectedIDs) }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Cache clean confirm sheet

private struct CacheCleanConfirmSheet: View {
    let app: AppInfo
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var cacheItems: [LeftoverItem] { app.leftovers.filter(\.isCacheType) }
    var otherItems: [LeftoverItem] { app.leftovers.filter { !$0.isCacheType } }
    var totalSize: Int64 { cacheItems.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                Text("Clean Cache for \(app.name)?")
                    .font(.title3.bold())
                Text("The app stays installed. Only cache files will be deleted.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 320)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Will be deleted").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))

                    ForEach(cacheItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue).font(.system(size: 16)).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label).font(.system(size: 12, weight: .medium))
                                Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.caption2).foregroundColor(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Text(item.sizeBytes.formattedSize)
                                .font(.system(size: 12).monospacedDigit()).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        Divider().padding(.leading, 52)
                    }

                    if !otherItems.isEmpty {
                        HStack {
                            Text("Not touched — requires uninstall")
                                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))

                        ForEach(otherItems) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                                    .font(.system(size: 16)).frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                        .font(.caption2).foregroundColor(.secondary.opacity(0.6))
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Text(item.sizeBytes.formattedSize)
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            Divider()

            HStack {
                Text("Frees up \(totalSize.formattedSize)").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.bordered).controlSize(.large)
                Button("Clean Cache") { onConfirm() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
