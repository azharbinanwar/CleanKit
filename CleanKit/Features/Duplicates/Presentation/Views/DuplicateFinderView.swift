import SwiftUI
import AppKit
import QuickLookThumbnailing

// MARK: - Scan Presets

private enum ScanPreset: String, CaseIterable, Identifiable {
    case home      = "Home"
    case downloads = "Downloads"
    case desktop   = "Desktop"
    case documents = "Documents"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home:      return "house"
        case .downloads: return "arrow.down.circle"
        case .desktop:   return "desktopcomputer"
        case .documents: return "doc"
        }
    }

    var url: URL {
        switch self {
        case .home:      return URL(fileURLWithPath: NSHomeDirectory())
        case .downloads: return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        case .desktop:   return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        case .documents: return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }
}

// MARK: - Payloads

private struct ScanWarning: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let count: Int
    let isBlocked: Bool
}

private struct DeleteConfirm: Identifiable {
    let id = UUID()
    let group: DuplicateGroup
    let keepURL: URL
}

// MARK: - Main View

struct DuplicateFinderView: View {
    var scanner: DuplicateScanner

    @State private var selectedGroupID: UUID? = nil
    @State private var keepURLs: [UUID: URL] = [:]
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var hasScanned = false
    @State private var confirm: DeleteConfirm? = nil
    @State private var bulkConfirm: Bool = false
    @State private var scanWarning: ScanWarning? = nil
    @State private var scanRootName = ""
    // Re-checked on appear and on app activation, so the banner clears the moment
    // Full Disk Access is granted.
    @State private var fullDiskGranted = AppPermission.fullDiskAccess.isGranted

    enum Screen { case main, result }
    @State private var currentScreen: Screen = .main
    @State private var lastFreedSize: Int64 = 0

    @AppStorage("duplicateWarnLimit") private var warnLimit: Double = 3000
    @AppStorage("duplicateBlockLimit") private var blockLimit: Double = 8000

    var selectedGroupData: DuplicateGroup? {
        guard let id = selectedGroupID else { return nil }
        return scanner.groups.first { $0.id == id }
    }

    var totalWasted: Int64 { scanner.groups.reduce(0) { $0 + $1.wastedBytes } }
    var totalSelectedWasted: Int64 {
        scanner.groups.filter { selectedGroupIDs.contains($0.id) }.reduce(0) { $0 + $1.wastedBytes }
    }

    var body: some View {
        ZStack {
            if currentScreen == .main {
                mainContent
            } else {
                resultView
            }
        }
        .onAppear { fullDiskGranted = AppPermission.fullDiskAccess.isGranted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fullDiskGranted = AppPermission.fullDiskAccess.isGranted
        }
        .animation(.easeInOut(duration: 0.25), value: fullDiskGranted)
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            header
            
            if !fullDiskGranted {
                AppBanner(
                    icon: "lock.shield",
                    message: "Full Disk Access is required to find duplicates in all system folders.",
                    actionTitle: "Open Settings"
                ) {
                    NSWorkspace.shared.open(AppPermission.fullDiskAccess.settingsURL)
                }
            }
            
            HStack(spacing: 16) {
                // 1. Sidebar: Duplicate Groups (Only shown when results are ready)
                if hasScanned && !scanner.groups.isEmpty && !scanner.isScanning && !scanner.isCounting {
                    resultsSidebar
                }
                
                // 2. Main Panel: Empty / Scanning / Detail
                VStack(spacing: 0) {
                    if let group = selectedGroupData {
                        GroupDetailPanel(
                            group: group,
                            keepURL: keepURLs[group.id] ?? group.files.first?.url,
                            onKeep: { url in keepURLs[group.id] = url },
                            onDelete: {
                                if let url = keepURLs[group.id] ?? group.files.first?.url {
                                    confirm = DeleteConfirm(group: group, keepURL: url)
                                }
                            }
                        )
                    } else if scanner.isScanning || scanner.isCounting {
                        scanningState
                    } else if !hasScanned {
                        emptyState
                    } else if scanner.groups.isEmpty {
                        noResultsState
                    } else {
                        noGroupSelectionState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
            
            // 3. Persistent Footer: Shown whenever we have data
            if hasScanned && !scanner.groups.isEmpty {
                footer
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: (confirm != nil || bulkConfirm || scanWarning != nil) ? 10 : 0)
        .overlay {
            if let payload = confirm {
                singleDeleteConfirmDialog(payload)
            }
            if bulkConfirm {
                bulkDeleteConfirmDialog
            }
            if let warning = scanWarning {
                scanWarningDialog(warning)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        AppHeader(title: "Duplicate Finder", subtitle: "Reclaim space from identical files") {
            HStack(spacing: 12) {
                // Presets Row
                HStack(spacing: 6) {
                    ForEach(ScanPreset.allCases) { preset in
                        AppButton(
                            title: preset.rawValue,
                            icon: preset.icon,
                            style: .glass,
                            isEnabled: !scanner.isScanning && !scanner.isCounting
                        ) {
                            triggerScan(url: preset.url, name: preset.rawValue)
                        }
                    }
                }
                
                Divider().frame(height: 24).opacity(0.1)
                
                AppButton(
                    title: "Scan Folder…",
                    icon: "folder",
                    style: .glass,
                    isEnabled: !scanner.isScanning && !scanner.isCounting
                ) {
                    pickFolder()
                }
            }
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Found Wasted:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                RollingSizeView(value: totalWasted).font(.system(size: 13, weight: .bold))
            }
            
            Spacer()
            
            if !selectedGroupIDs.isEmpty {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(selectedGroupIDs.count) selected ·").font(.system(size: 13)).foregroundColor(.secondary)
                        RollingSizeView(value: totalSelectedWasted).font(.system(size: 13, weight: .bold))
                    }
                    
                    AppButton(title: "Delete All", style: .primary) { bulkConfirm = true }
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16).frame(height: 72)
    }

    private var resultsSidebar: some View {
        VStack(spacing: 0) {
            // "Select All" Toggle in Sidebar Header
            HStack {
                Button {
                    withAnimation(.spring()) {
                        if selectedGroupIDs.count == scanner.groups.count {
                            selectedGroupIDs = []
                        } else {
                            selectedGroupIDs = Set(scanner.groups.map(\.id))
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedGroupIDs.count == scanner.groups.count ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedGroupIDs.count == scanner.groups.count ? .accentColor : .secondary.opacity(0.3))
                            .font(.system(size: 16))
                        Text("Select All").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(scanner.groups.count)").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(scanner.groups) { group in
                        DuplicateGroupRow(
                            group: group,
                            isSelected: selectedGroupID == group.id,
                            isMultiSelected: selectedGroupIDs.contains(group.id),
                            onSelect: { withAnimation(.spring()) { selectedGroupID = group.id } },
                            onToggleCheck: {
                                if selectedGroupIDs.contains(group.id) {
                                    selectedGroupIDs.remove(group.id)
                                } else {
                                    selectedGroupIDs.insert(group.id)
                                }
                            }
                        )
                        Divider().padding(.leading, 48).opacity(0.05)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }

    // MARK: - Dialogs

    private func singleDeleteConfirmDialog(_ payload: DeleteConfirm) -> some View {
        let deleteCount = payload.group.files.count - 1
        return AppDialog(
            title: "Delete Group Copies",
            subtitle: "Permanently remove \(deleteCount) identical copies?",
            onDismiss: { confirm = nil }
        ) {
            VStack(spacing: 20) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "trash")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                }
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Keeping").font(.system(size: 10, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary)
                            Text(payload.keepURL.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total to Free").font(.system(size: 10, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary)
                            Text(payload.group.wastedBytes.formattedSize).font(.system(size: 18, weight: .bold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
        } actions: {
            Spacer()
            AppButton(title: "Cancel", style: .glass) { confirm = nil }
            AppButton(title: "Delete Now", style: .primary) {
                let groupID = payload.group.id
                let keepURL = payload.keepURL
                let size = payload.group.wastedBytes
                confirm = nil
                selectedGroupID = nil
                Task {
                    await scanner.delete(keeping: keepURL, in: groupID)
                    lastFreedSize = size
                    withAnimation { currentScreen = .result }
                }
            }
        }
    }

    private var bulkDeleteConfirmDialog: some View {
        AppDialog(
            title: "Delete All",
            subtitle: "Process \(selectedGroupIDs.count) duplicate groups",
            onDismiss: { bulkConfirm = false }
        ) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.accentColor)
                    
                    Text("Choose a strategy for deletion.")
                        .font(.headline)
                    
                    Text("Duplicates will be permanently removed. This will free up \(totalSelectedWasted.formattedSize).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 12) {
                    strategyButton(
                        title: "Keep Oldest Copy",
                        description: "Recommended for original files",
                        icon: "clock.arrow.circlepath"
                    ) {
                        performBulkDelete(keepStrategy: .oldest)
                    }
                    
                    strategyButton(
                        title: "Keep Newest Copy",
                        description: "Keeps your most recent edits",
                        icon: "clock.arrow.2.circlepath"
                    ) {
                        performBulkDelete(keepStrategy: .newest)
                    }
                }
            }
        } actions: {
            Spacer()
            AppButton(title: "Cancel", style: .plain) { bulkConfirm = false }
        }
    }

    private func strategyButton(title: String, description: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(description).font(.system(size: 11)).foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func scanWarningDialog(_ warning: ScanWarning) -> some View {
        AppDialog(
            title: warning.isBlocked ? "Folder Too Large" : "Large Folder",
            subtitle: "\(warning.count.formatted()) files in \(warning.name)",
            onDismiss: { scanWarning = nil }
        ) {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: warning.isBlocked ? "exclamationmark.octagon" : "exclamationmark.triangle")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(warning.isBlocked ? .red : .orange)

                    Text(warning.isBlocked ? "Scanning Blocked" : "Scan Warning")
                        .font(.title2.bold())

                    Text(warning.isBlocked 
                        ? "This folder exceeds the safety limit. Scanning it may freeze your Mac."
                        : "This folder is very large and will take several minutes to process.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Threshold Info Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("SCANNER LIMITS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("Warning at: \(Int(warnLimit).formatted()) files", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Label("Block at: \(Int(blockLimit).formatted()) files", systemImage: "xmark.octagon")
                    }
                    .font(.system(size: 10, weight: .medium))
                    
                    Divider().opacity(0.1)
                    
                    Text("You can increase these limits in Settings if you have a fast SSD.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .italic()
                }
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(10)
            }
        } actions: {
            AppButton(title: "Cancel", style: .glass) { scanWarning = nil }
            
            AppButton(title: "Pick Subfolder", icon: "folder", style: .glass) {
                scanWarning = nil
                pickSubfolder(in: warning.url, parentName: warning.name)
            }
            
            if !warning.isBlocked {
                AppButton(title: "Scan Anyway", style: .primary) {
                    scanWarning = nil
                    startScan(url: warning.url, name: warning.name)
                }
            }
        }
    }

    private var resultView: some View {
        AppResultView(
            title: "Duplicates Removed",
            subtitle: "Your disk is now cleaner.",
            stats: [(label: "Recovered", value: lastFreedSize.formattedSize, icon: "doc.on.doc")]
        ) {
            AppButton(title: "Done", style: .primary) { 
                selectedGroupIDs = []
                currentScreen = .main 
            }
        }
    }

    // MARK: - States

    private var scanningState: some View {
        VStack(spacing: 20) {
            AppLoading(size: 32)
            VStack(spacing: 4) {
                Text(scanner.isCounting ? "Counting..." : "Searching...")
                    .font(.system(size: 15, weight: .bold))
                Text(scanner.scanPhase.isEmpty ? "Preparing..." : scanner.scanPhase)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.accentColor.opacity(0.3))
            Text("Ready to Scan").font(.title2.bold())
            Text("Choose a folder from the header to find identical files.").font(.subheadline).foregroundColor(.secondary)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle").font(.system(size: 48, weight: .thin)).foregroundColor(.accentColor)
            Text("No Duplicates Found").font(.headline)
            Text("All files in \(scanRootName) appear to be unique.").font(.subheadline).foregroundColor(.secondary)
        }
    }

    private var noGroupSelectionState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc").font(.system(size: 48, weight: .thin)).foregroundColor(.accentColor.opacity(0.1))
            Text("Select a Group").font(.headline)
            Text("Choose a duplicate group from the sidebar to see individual file copies.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    // MARK: - Logic Helpers

    private func triggerScan(url: URL, name: String) {
        Task {
            let count = await scanner.countFiles(in: url)
            switch ScanGate.check(count, warn: Int(warnLimit), block: Int(blockLimit)) {
            case .clear: startScan(url: url, name: name)
            case .warning(let n): scanWarning = ScanWarning(url: url, name: name, count: n, isBlocked: false)
            case .blocked(let n): scanWarning = ScanWarning(url: url, name: name, count: n, isBlocked: true)
            }
        }
    }

    private func startScan(url: URL, name: String) {
        scanRootName = name
        selectedGroupID = nil
        selectedGroupIDs = []
        keepURLs = [:]
        hasScanned = true
        Task { await scanner.scan(in: url) }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            triggerScan(url: url, name: url.lastPathComponent)
        }
    }

    private func pickSubfolder(in parentURL: URL, parentName: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = parentURL
        if panel.runModal() == .OK, let url = panel.url {
            triggerScan(url: url, name: url.lastPathComponent)
        }
    }

    private func performBulkDelete(keepStrategy: KeepStrategy) {
        let groupsToDelete = scanner.groups.filter { selectedGroupIDs.contains($0.id) }
        let totalToFree = groupsToDelete.reduce(0) { $0 + $1.wastedBytes }
        selectedGroupIDs = []
        selectedGroupID = nil
        bulkConfirm = false
        Task {
            for group in groupsToDelete {
                let sorted = group.files.sorted {
                    let d0 = (try? $0.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let d1 = (try? $1.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return keepStrategy == .oldest ? d0 < d1 : d0 > d1
                }
                if let keep = sorted.first?.url {
                    await scanner.delete(keeping: keep, in: group.id)
                }
            }
            lastFreedSize = totalToFree
            withAnimation { currentScreen = .result }
        }
    }
    
    private enum KeepStrategy { case oldest, newest }

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv", "m4v":           return "film"
        case "mp3", "m4a", "wav", "flac", "aac":          return "music.note"
        case "pdf":                                        return "doc.richtext"
        case "zip", "tar", "gz", "rar", "7z":             return "archivebox"
        case "doc", "docx":                                return "doc"
        case "xls", "xlsx":                                return "tablecells"
        case "dmg", "iso":                                 return "opticaldisc"
        default:                                           return "doc"
        }
    }

    private func isPreviewable(_ ext: String) -> Bool {
        let previewable = ["jpg","jpeg","png","gif","heic","heif","webp","tiff","bmp",
                           "mp4","mov","avi","mkv","m4v","pdf","key","pages","numbers"]
        return previewable.contains(ext.lowercased())
    }
}

// MARK: - Components

struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let isSelected: Bool
    let isMultiSelected: Bool
    let onSelect: () -> Void
    let onToggleCheck: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Button(action: onToggleCheck) {
                    Image(systemName: isMultiSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isMultiSelected ? .accentColor : .secondary.opacity(0.3))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain).frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.files.first?.displayName ?? "Unknown").font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text("\(group.files.count) copies").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Text(group.wastedBytes.formattedSize).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.2))
            }
            .padding(.horizontal, 16).padding(.vertical, 12).background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GroupDetailPanel: View {
    let group: DuplicateGroup
    let keepURL: URL?
    let onKeep: (URL) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)).frame(width: 48, height: 48)
                    Image(systemName: "doc.on.doc").font(.system(size: 20)).foregroundColor(.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.files.first?.displayName ?? "Unknown").font(.title3.bold())
                    Text("\(group.files.count) identical copies · \(group.fileSize.formattedSize) each").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(group.wastedBytes.formattedSize).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.accentColor)
                    Text("Wasted").font(.system(size: 8, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary)
                }
            }
            .padding(24)
            
            Divider().opacity(0.1)
            
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Copies").font(.system(size: 10, weight: .bold)).textCase(.uppercase).foregroundColor(.secondary)
                        Spacer()
                        Text("Select one to keep").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24).padding(.top, 16)
                    
                    ForEach(group.files) { file in
                        let isKeeping = (keepURL ?? group.files.first?.url) == file.url
                        Button(action: { withAnimation { onKeep(file.url) } }) {
                            HStack(spacing: 12) {
                                Image(systemName: isKeeping ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isKeeping ? .green : .secondary.opacity(0.3))
                                    .font(.system(size: 16))
                                    .frame(width: 16)
                                
                                ThumbnailView(url: file.url, size: 40)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 6) {
                                        Text(file.displayName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        if isKeeping {
                                            Text("KEEP").font(.system(size: 8, weight: .bold)).foregroundColor(.green).padding(.horizontal, 4).padding(.vertical, 1).background(Capsule().fill(Color.green.opacity(0.1)))
                                        }
                                    }
                                    Text(file.displayPath).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }) {
                                    Image(systemName: "folder").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Text(file.size.formattedSize).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24).padding(.vertical, 8)
                            .background(isKeeping ? Color.green.opacity(0.04) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 56).opacity(0.05)
                    }
                }
            }
            
            Divider().opacity(0.1)
            
            HStack {
                Spacer()
                AppButton(title: "Delete Group Copies", icon: "trash", style: .primary, action: onDelete)
            }
            .padding(24)
        }
    }
}

// MARK: - Thumbnail

private struct ThumbnailView: View {
    let url: URL
    let size: CGFloat
    @State private var image: NSImage? = nil
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: size, height: size).clipped().cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)).frame(width: size, height: size).overlay(AppLoading(size: 12, strokeWidth: 1))
            }
        }
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size * 2, height: size * 2), scale: 2.0, representationTypes: .thumbnail)
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
    }
}
