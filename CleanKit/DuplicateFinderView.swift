import SwiftUI
import AppKit
import QuickLookThumbnailing

private enum ScanPreset: String, CaseIterable {
    case downloads = "Downloads"
    case desktop   = "Desktop"
    case documents = "Documents"
    case movies    = "Movies"

    var icon: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .desktop:   return "desktopcomputer"
        case .documents: return "doc.text"
        case .movies:    return "film"
        }
    }

    var url: URL {
        let dir: FileManager.SearchPathDirectory
        switch self {
        case .downloads: dir = .downloadsDirectory
        case .desktop:   dir = .desktopDirectory
        case .documents: dir = .documentDirectory
        case .movies:    dir = .moviesDirectory
        }
        return FileManager.default.urls(for: dir, in: .userDomainMask).first!
    }
}

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

struct DuplicateFinderView: View {
    var scanner: DuplicateScanner

    @State private var selectedGroupID: UUID? = nil
    @State private var keepURLs: [UUID: URL] = [:]
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var hasScanned = false
    @State private var confirm: DeleteConfirm? = nil
    @State private var bulkConfirm: Bool = false
    @State private var scanWarning: ScanWarning? = nil
    @State private var blockedCount: Int? = nil
    @State private var hoveredGroupID: UUID? = nil
    @State private var hoveredFileID: UUID? = nil
    @State private var scanRootName = "Downloads"
    @AppStorage("duplicateWarnLimit") private var warnLimit: Double = 3000
    @AppStorage("duplicateBlockLimit") private var blockLimit: Double = 8000

    var selectedGroup: DuplicateGroup? {
        guard let id = selectedGroupID else { return nil }
        return scanner.groups.first { $0.id == id }
    }

    var totalWasted: Int64 { scanner.groups.reduce(0) { $0 + $1.wastedBytes } }

    var body: some View {
        let _ = scanner.groups
        let _ = scanner.isScanning
        let _ = scanner.isCounting
        let _ = scanner.scanPhase

        VStack(spacing: 0) {
            toolbar
            Divider()
            if scanner.isScanning || scanner.isCounting {
                scanningView
            } else if !hasScanned {
                emptyView
            } else if scanner.groups.isEmpty {
                noResultsView
            } else {
                HStack(spacing: 0) {
                    leftPanel
                    Divider()
                    rightPanel
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $confirm) { confirmSheet($0) }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ToolHeaderView(title: "Duplicate Finder", subtitle: "Find and remove duplicate files") {
            HStack(spacing: 6) {
                ForEach(ScanPreset.allCases, id: \.self) { preset in
                    Button {
                        triggerScan(url: preset.url, name: preset.rawValue)
                    } label: {
                        Label(preset.rawValue, systemImage: preset.icon)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(scanner.isScanning || scanner.isCounting)
                }
                Button { pickFolder() } label: {
                    Label("Choose Folder", systemImage: "folder.badge.plus")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanning || scanner.isCounting)
            }
        }
        .sheet(item: $scanWarning) { warning in
            warningSheet(warning)
        }
        .confirmationDialog(
            "Delete duplicates in \(selectedGroupIDs.count) group\(selectedGroupIDs.count == 1 ? "" : "s")?",
            isPresented: $bulkConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete — Keep Oldest Copy", role: .destructive) {
                performBulkDelete(keepStrategy: .oldest)
            }
            Button("Delete — Keep Newest Copy", role: .destructive) {
                performBulkDelete(keepStrategy: .newest)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let wasted = scanner.groups
                .filter { selectedGroupIDs.contains($0.id) }
                .reduce(0) { $0 + $1.wastedBytes }
            Text("Duplicates will be permanently deleted. Frees up \(wasted.formattedSize).")
        }
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if selectedGroupIDs.count == scanner.groups.count {
                        selectedGroupIDs = []
                    } else {
                        selectedGroupIDs = Set(scanner.groups.map(\.id))
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedGroupIDs.count == scanner.groups.count ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedGroupIDs.count == scanner.groups.count ? .accentColor : .secondary)
                        Text("Select All").font(.caption).foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(totalWasted.formattedSize) wasted")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(scanner.groups) { group in
                        groupRow(group)
                        Divider()
                    }
                }
            }

            if !selectedGroupIDs.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    let bulkWasted = scanner.groups
                        .filter { selectedGroupIDs.contains($0.id) }
                        .reduce(0) { $0 + $1.wastedBytes }
                    Text("\(selectedGroupIDs.count) selected · \(bulkWasted.formattedSize)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        bulkConfirm = true
                    } label: {
                        Text("Delete All")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func groupRow(_ group: DuplicateGroup) -> some View {
        let selected = selectedGroupID == group.id
        let hovered = hoveredGroupID == group.id
        let bulkSelected = selectedGroupIDs.contains(group.id)
        let ext = group.files.first?.url.pathExtension ?? ""
        return Button { selectedGroupID = group.id } label: {
            HStack(spacing: 10) {
                Button {
                    if bulkSelected { selectedGroupIDs.remove(group.id) }
                    else { selectedGroupIDs.insert(group.id) }
                } label: {
                    Image(systemName: bulkSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(bulkSelected ? .accentColor : Color.secondary.opacity(0.3))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                if isPreviewable(ext), let first = group.files.first {
                    ThumbnailView(url: first.url, size: 36)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: fileIcon(for: ext))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.files.first?.displayName ?? "Unknown")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text("\(group.files.count) copies · \(group.wastedBytes.formattedSize) wasted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor.opacity(0.12) : hovered ? Color.secondary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredGroupID = $0 ? group.id : nil }
    }

    // MARK: - Right panel

    @ViewBuilder
    private var rightPanel: some View {
        if let group = selectedGroup {
            VStack(spacing: 0) {
                groupDetailHeader(group)
                Divider()
                fileList(group)
                Divider()
                bottomBar(group)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            noSelectionView
        }
    }

    private func groupDetailHeader(_ group: DuplicateGroup) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: fileIcon(for: group.files.first?.url.pathExtension ?? ""))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(group.files.first?.displayName ?? "Unknown")
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("\(group.files.count) identical copies · \(group.fileSize.formattedSize) each")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(group.wastedBytes.formattedSize)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                Text("wasted").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func fileList(_ group: DuplicateGroup) -> some View {
        let keepURL = keepURLs[group.id] ?? group.files.first?.url

        return ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("Select one to keep — the rest will be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider()

                ForEach(group.files) { file in
                    let isKeeping = keepURL == file.url
                    let preview = isPreviewable(file.url.pathExtension)
                    Button { keepURLs[group.id] = file.url } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isKeeping ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isKeeping ? .green : Color.secondary.opacity(0.4))
                                .font(.system(size: 18))
                                .frame(width: 20)

                            if preview {
                                ThumbnailView(url: file.url, size: 56)
                            } else {
                                Image(systemName: fileIcon(for: file.url.pathExtension))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.purple.opacity(0.6))
                                    .frame(width: 56, height: 56)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(file.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    if isKeeping {
                                        Text("KEEP")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.12))
                                            .cornerRadius(4)
                                    }
                                }
                                Text(file.displayPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            if hoveredFileID == file.id {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                } label: {
                                    Image(systemName: "folder.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(file.size.formattedSize)
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(isKeeping ? Color.green.opacity(0.04) : Color.clear)
                        .contentShape(Rectangle())
                        .onHover { hoveredFileID = $0 ? file.id : nil }
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private func bottomBar(_ group: DuplicateGroup) -> some View {
        let keepURL = keepURLs[group.id] ?? group.files.first?.url
        let deleteCount = group.files.count - 1
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Frees up \(group.wastedBytes.formattedSize)")
                    .font(.caption.weight(.medium))
                Text("Deletes \(deleteCount) duplicate\(deleteCount == 1 ? "" : "s"), keeps 1")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if let url = keepURL {
                    confirm = DeleteConfirm(group: group, keepURL: url)
                }
            } label: {
                Label("Delete Duplicates", systemImage: "trash")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - States

    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.purple.opacity(0.8))
            }
            Text("Duplicate Finder").font(.title2.bold())
            Text("Choose a folder to scan for identical files.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let blocked = blockedCount {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill").foregroundColor(.red)
                    Text("Too many files (\(blocked.formatted())) — choose a smaller folder like Downloads or Documents.")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
                .frame(maxWidth: 360)
            }

            HStack(spacing: 12) {
                ForEach(ScanPreset.allCases, id: \.self) { preset in
                    presetCard(preset)
                }
                customFolderCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
            }
            Text("No Duplicates Found").font(.title2.bold())
            Text("No duplicate files were found in \(scanRootName).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presetCard(_ preset: ScanPreset) -> some View {
        Button { triggerScan(url: preset.url, name: preset.rawValue) } label: {
            VStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: preset.url.path))
                    .resizable()
                    .frame(width: 48, height: 48)
                Text(preset.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 90, height: 84)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(scanner.isScanning || scanner.isCounting)
    }

    private var customFolderCard: some View {
        Button { pickFolder() } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("Choose Folder")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 90, height: 84)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(scanner.isScanning || scanner.isCounting)
    }

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text(scanner.isCounting ? "Counting Files..." : "Scanning for Duplicates...")
                .font(.title3.bold())
            Text(scanner.isCounting
                 ? "Checking folder size before scan"
                 : scanner.scanPhase.isEmpty ? "Starting scan in \(scanRootName)..." : scanner.scanPhase)
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
            Text("Select a group")
                .font(.title3)
                .foregroundColor(.secondary.opacity(0.6))
            Text("Choose a duplicate group to see all copies and pick which to keep")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Confirm sheet

    private func confirmSheet(_ payload: DeleteConfirm) -> some View {
        let deleteCount = payload.group.files.count - 1
        return VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Delete \(deleteCount) duplicate\(deleteCount == 1 ? "" : "s")?")
                .font(.title3.bold())
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Keeping: \(payload.keepURL.lastPathComponent)")
                        .lineLimit(1)
                }
                .font(.subheadline)
                Text("\(deleteCount) file\(deleteCount == 1 ? "" : "s") will be permanently deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Frees up \(payload.group.wastedBytes.formattedSize)")
                    .font(.subheadline.weight(.semibold))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            HStack(spacing: 12) {
                Button("Cancel") { confirm = nil }
                    .buttonStyle(.bordered).controlSize(.large)
                Button("Delete") {
                    let groupID = payload.group.id
                    let keepURL = payload.keepURL
                    confirm = nil
                    selectedGroupID = nil
                    Task { await scanner.delete(keeping: keepURL, in: groupID) }
                }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    // MARK: - Helpers

    private enum KeepStrategy { case oldest, newest }

    private func performBulkDelete(keepStrategy: KeepStrategy) {
        let groupsToDelete = scanner.groups.filter { selectedGroupIDs.contains($0.id) }
        selectedGroupIDs = []
        selectedGroupID = nil
        Task {
            for group in groupsToDelete {
                let keepURL = group.files
                    .sorted {
                        let d0 = (try? $0.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        let d1 = (try? $1.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        return keepStrategy == .oldest ? d0 < d1 : d0 > d1
                    }
                    .first?.url
                if let url = keepURL {
                    await scanner.delete(keeping: url, in: group.id)
                }
            }
        }
    }

    private func triggerScan(url: URL, name: String) {
        blockedCount = nil
        Task {
            let count = await scanner.countFiles(in: url)
            switch ScanGate.check(count, warn: Int(warnLimit), block: Int(blockLimit)) {
            case .clear:
                startScan(url: url, name: name)
            case .warning(let n):
                scanWarning = ScanWarning(url: url, name: name, count: n, isBlocked: false)
            case .blocked(let n):
                scanWarning = ScanWarning(url: url, name: name, count: n, isBlocked: true)
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
        panel.prompt = "Scan"
        panel.message = "Choose a folder to scan for duplicate files"
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
        panel.prompt = "Scan This Subfolder"
        panel.message = "Choose a subfolder inside \"\(parentName)\" to scan"
        if panel.runModal() == .OK, let url = panel.url {
            triggerScan(url: url, name: url.lastPathComponent)
        }
    }

    private func warningSheet(_ warning: ScanWarning) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(systemName: warning.isBlocked ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(warning.isBlocked ? .red : .orange)

                Text(warning.isBlocked ? "Folder Too Large to Scan" : "Large Folder Detected")
                    .font(.title3.bold())

                VStack(spacing: 8) {
                    Text("\"\(warning.name)\" contains \(warning.count.formatted()) files.")
                        .font(.subheadline.weight(.medium))

                    if warning.isBlocked {
                        Text("Scanning this many files at once may cause the app to crash or freeze. Pick a specific subfolder instead — like a project folder or a specific year inside \(warning.name).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Scanning this folder may take several minutes. You can scan anyway or pick a smaller subfolder to finish faster.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                        Text("Warn limit: \(Int(warnLimit).formatted()) files · Block limit: \(Int(blockLimit).formatted()) files · Adjust in Settings")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            }
            .padding(28)

            Divider()

            HStack(spacing: 10) {
                Button("Cancel") { scanWarning = nil }
                    .buttonStyle(.bordered).controlSize(.large)

                Button {
                    scanWarning = nil
                    pickSubfolder(in: warning.url, parentName: warning.name)
                } label: {
                    Label("Pick Subfolder in \(warning.name)", systemImage: "folder.badge.plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(warning.isBlocked ? .red : .orange)
                .controlSize(.large)

                if !warning.isBlocked {
                    Button("Scan Anyway") {
                        scanWarning = nil
                        startScan(url: warning.url, name: warning.name)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                }
            }
            .padding(20)
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func isPreviewable(_ ext: String) -> Bool {
        let previewable = ["jpg","jpeg","png","gif","heic","heif","webp","tiff","bmp",
                           "mp4","mov","avi","mkv","m4v","pdf","key","pages","numbers"]
        return previewable.contains(ext.lowercased())
    }

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
        default:                                           return "doc.on.doc"
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
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView().scaleEffect(0.6)
                    )
            }
        }
        .task(id: url) {
            guard let thumb = await generateThumbnail() else { return }
            image = thumb
        }
    }

    private func generateThumbnail() async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size * 2, height: size * 2),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
