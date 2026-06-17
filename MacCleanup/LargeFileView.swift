import SwiftUI
import AppKit

enum LargeFileType: String, CaseIterable {
    case all = "All"
    case video = "Video"
    case archive = "Archive"
    case diskImage = "Disk Image"
    case document = "Document"
    case other = "Other"

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2"
        case .video:     return "film"
        case .archive:   return "archivebox"
        case .diskImage: return "opticaldisc"
        case .document:  return "doc.richtext"
        case .other:     return "doc"
        }
    }

    var extensions: [String] {
        switch self {
        case .all:       return []
        case .video:     return ["mp4", "mov", "avi", "mkv", "m4v"]
        case .archive:   return ["zip", "tar", "gz", "rar", "7z", "bz2"]
        case .diskImage: return ["dmg", "iso"]
        case .document:  return ["pdf", "doc", "docx", "key", "ppt", "pptx"]
        case .other:     return []
        }
    }
}

private struct DeleteConfirm: Identifiable {
    let id = UUID()
    let files: [LargeFile]
}

struct LargeFileView: View {
    var scanner: LargeFileScanner
    var onPermissionMissing: (([AppPermission]) -> Void)? = nil

    @State private var selectedIDs: Set<UUID> = []
    @State private var filterType: LargeFileType = .all
    @State private var confirm: DeleteConfirm? = nil
    @State private var hoveredID: UUID? = nil
    @State private var scanRootName: String = "Home"

    private let thresholds: [(String, Int64)] = [
        ("50 MB",  50  * 1024 * 1024),
        ("100 MB", 100 * 1024 * 1024),
        ("500 MB", 500 * 1024 * 1024),
        ("1 GB",   1024 * 1024 * 1024)
    ]

    var filteredFiles: [LargeFile] {
        switch filterType {
        case .all:
            return scanner.files
        case .other:
            let known = LargeFileType.allCases.flatMap(\.extensions)
            return scanner.files.filter { !known.contains($0.fileExtension) }
        default:
            return scanner.files.filter { filterType.extensions.contains($0.fileExtension) }
        }
    }

    var selectedFiles: [LargeFile]  { filteredFiles.filter { selectedIDs.contains($0.id) } }
    var totalSize: Int64             { scanner.files.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64          { selectedFiles.reduce(0) { $0 + $1.size } }

    var body: some View {
        let _ = scanner.files
        let _ = scanner.isScanning

        VStack(spacing: 0) {
            toolbar
            Divider()
            if scanner.isScanning {
                scanningView
            } else if scanner.files.isEmpty {
                emptyView
            } else {
                filterChips
                Divider()
                if filteredFiles.isEmpty {
                    emptyFilterView
                } else {
                    fileList
                    Divider()
                    bottomBar
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $confirm) { payload in
            confirmSheet(payload)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Large File Finder")
                    .font(.title2.bold())
                Text("Find files taking up the most space")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                ForEach(thresholds, id: \.0) { label, bytes in
                    Button {
                        scanner.threshold = bytes
                    } label: {
                        HStack {
                            Text("Over \(label)")
                            if scanner.threshold == bytes {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Over \(thresholds.first { $0.1 == scanner.threshold }?.0 ?? "100 MB")")
                        .font(.subheadline)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                pickFolder()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(scanRootName)
                        .font(.subheadline)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(scanner.isScanning)
            .help("Choose a folder to scan")

            Button {
                guard checkPermissions() else { return }
                scanRootName = "Home"
                selectedIDs = []
                Task { await scanner.scan(in: URL(fileURLWithPath: NSHomeDirectory())) }
            } label: {
                Label(scanner.files.isEmpty ? "Scan" : "Re-scan", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanner.isScanning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LargeFileType.allCases, id: \.self) { type in
                    let count = chipCount(for: type)
                    Button {
                        filterType = type
                        selectedIDs = []
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.rawValue).font(.caption.weight(.medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundColor(filterType == type ? .white.opacity(0.8) : .secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(filterType == type ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundColor(filterType == type ? .white : .primary)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func chipCount(for type: LargeFileType) -> Int {
        switch type {
        case .all:   return scanner.files.count
        case .other:
            let known = LargeFileType.allCases.flatMap(\.extensions)
            return scanner.files.filter { !known.contains($0.fileExtension) }.count
        default:
            return scanner.files.filter { type.extensions.contains($0.fileExtension) }.count
        }
    }

    // MARK: - File list

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 0) {
                selectAllRow
                Divider()
                ForEach(filteredFiles) { file in
                    fileRow(file)
                    Divider().padding(.leading, 60)
                }
            }
        }
    }

    private var selectAllRow: some View {
        HStack {
            Button {
                if selectedIDs.count == filteredFiles.count, !filteredFiles.isEmpty {
                    selectedIDs = []
                } else {
                    selectedIDs = Set(filteredFiles.map(\.id))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedIDs.count == filteredFiles.count && !filteredFiles.isEmpty
                          ? "checkmark.square.fill" : "square")
                        .foregroundColor(selectedIDs.count == filteredFiles.count && !filteredFiles.isEmpty
                                         ? .accentColor : .secondary)
                    Text("Select All").font(.caption).foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(filteredFiles.count) files · \(totalSize.formattedSize)")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func fileRow(_ file: LargeFile) -> some View {
        let selected = selectedIDs.contains(file.id)
        let hovered = hoveredID == file.id
        return Button {
            if selected { selectedIDs.remove(file.id) } else { selectedIDs.insert(file.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .accentColor : Color.secondary.opacity(0.4))
                    .font(.system(size: 18))
                    .frame(width: 20)

                Image(systemName: fileIcon(for: file.fileExtension))
                    .foregroundColor(fileColor(for: file.fileExtension))
                    .font(.system(size: 20))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(file.displayPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if hovered {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
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

                Text(file.size.formattedSize)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(selected ? Color.accentColor.opacity(0.05) : hovered ? Color.secondary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? file.id : nil }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("\(scanner.files.count) files · \(totalSize.formattedSize) found")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if !selectedIDs.isEmpty {
                Text("\(selectedIDs.count) selected · \(selectedSize.formattedSize)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                Button("Delete Selected") {
                    confirm = DeleteConfirm(files: selectedFiles)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty / Scanning

    private var emptyView: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.orange.opacity(0.8))
            }
            Text("Find Large Files").font(.title2.bold())
            Text("Choose a folder and scan to find files taking up the most space.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            HStack(spacing: 10) {
                Button { pickFolder() } label: {
                    Label("Choose Folder", systemImage: "folder")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button {
                    guard checkPermissions() else { return }
                    scanRootName = "Home"
                    Task { await scanner.scan(in: URL(fileURLWithPath: NSHomeDirectory())) }
                } label: {
                    Label("Scan Home", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFilterView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: filterType.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text("No \(filterType.rawValue) Files Found")
                .font(.headline)
                .foregroundColor(.primary)
            Text("No files of this type are over \(thresholds.first { $0.1 == scanner.threshold }?.0 ?? "100 MB").")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Scanning \(scanRootName)...").font(.title3.bold())
            Text("Looking for files over \(thresholds.first { $0.1 == scanner.threshold }?.0 ?? "100 MB")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickFolder() {
        guard checkPermissions() else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder to scan for large files"
        if panel.runModal() == .OK, let url = panel.url {
            scanRootName = url.lastPathComponent
            selectedIDs = []
            Task { await scanner.scan(in: url) }
        }
    }

    @discardableResult
    private func checkPermissions() -> Bool {
        let missing = [AppPermission.fullDiskAccess].filter { !$0.isGranted }
        if missing.isEmpty { return true }
        onPermissionMissing?(missing)
        return false
    }

    // MARK: - Confirm sheet

    private func confirmSheet(_ payload: DeleteConfirm) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Delete \(payload.files.count) file\(payload.files.count == 1 ? "" : "s")?")
                .font(.title3.bold())
            Text("This will permanently delete \(selectedSize.formattedSize). This cannot be undone.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            HStack(spacing: 12) {
                Button("Cancel") { confirm = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Delete") {
                    let targets = payload.files
                    confirm = nil
                    selectedIDs = []
                    Task { await scanner.delete(targets) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 380)
    }

    // MARK: - Helpers

    private func fileIcon(for ext: String) -> String {
        switch ext {
        case "mp4", "mov", "avi", "mkv", "m4v":   return "film"
        case "zip", "tar", "gz", "rar", "7z", "bz2": return "archivebox"
        case "dmg", "iso":                          return "opticaldisc"
        case "pdf":                                 return "doc.richtext"
        case "doc", "docx":                         return "doc"
        case "key":                                 return "rectangle.on.rectangle"
        case "ppt", "pptx":                         return "chart.bar.doc.horizontal"
        default:                                    return "doc"
        }
    }

    private func fileColor(for ext: String) -> Color {
        switch ext {
        case "mp4", "mov", "avi", "mkv", "m4v":      return .purple
        case "zip", "tar", "gz", "rar", "7z", "bz2": return .yellow
        case "dmg", "iso":                            return .blue
        case "pdf":                                   return .red
        case "doc", "docx":                           return .blue
        case "key", "ppt", "pptx":                    return .orange
        default:                                      return .secondary
        }
    }
}
