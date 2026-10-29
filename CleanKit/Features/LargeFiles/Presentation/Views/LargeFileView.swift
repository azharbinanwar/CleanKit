import SwiftUI

struct LargeFileView: View {
    var scanner: LargeFileScanner
    var onPermissionMissing: ([AppPermission]) -> Void
    
    @State private var screen: Screen = .list
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmDeletion = false
    @State private var lastDeletedSize: Int64 = 0
    // Re-checked on appear and when the app becomes active, so the banner hides
    // as soon as the user grants Full Disk Access.
    @State private var fullDiskGranted = AppPermission.fullDiskAccess.isGranted
    // Shares the same key Settings writes, so the Settings default and the
    // in-view picker stay in sync.
    @AppStorage("largeFileDefaultMB") private var thresholdMB: Double = 100
    
    enum Screen { case list, result }
    
    var selectedFiles: [LargeFile] {
        scanner.files.filter { selectedIDs.contains($0.id) }
    }
    
    var totalSelectedSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .list:
                listView
            case .result:
                resultView
            }
        }
        .onAppear {
            scanner.thresholdBytes = Int64(thresholdMB * 1024 * 1024)
            fullDiskGranted = AppPermission.fullDiskAccess.isGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fullDiskGranted = AppPermission.fullDiskAccess.isGranted
        }
        .animation(.easeInOut(duration: 0.25), value: fullDiskGranted)
    }
    
    private var listView: some View {
        VStack(spacing: 16) {
            header
            
            if !fullDiskGranted {
                AppBanner(
                    icon: "lock.shield.fill",
                    message: "Full Disk Access is required to find all large files on your Mac.",
                    detail: AppPermission.staleGrantHint,
                    actionTitle: "Open Settings"
                ) {
                    NSWorkspace.shared.open(AppPermission.fullDiskAccess.settingsURL)
                }
            }
            
            // Middle Content Area - Now expands to push header/footer apart
            VStack {
                if scanner.isScanning {
                    scanningState
                } else if scanner.files.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Forces the middle to fill space
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            
            footer
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
        .overlay {
            if confirmDeletion {
                deletionConfirmDialog
            }
        }
    }
    
    private var header: some View {
        AppHeader(title: "Large File Finder", subtitle: "Find items taking up the most space") {
            HStack(spacing: 16) {
                // 1. Quick Target Row
                HStack(spacing: 8) {
                    quickTargetButton(title: "Home", icon: "house", path: NSHomeDirectory())
                    quickTargetButton(title: "Downloads", icon: "arrow.down.circle", path: "~/Downloads")
                    quickTargetButton(title: "Documents", icon: "doc.text", path: "~/Documents")
                }
                
                Divider().frame(height: 24).opacity(0.1)

                // 2. Size Threshold Picker & Scan Button Group
                HStack(spacing: 12) {
                    Menu {
                        ForEach(LargeFileScanner.allPresets, id: \.label) { preset in
                            Button(preset.label) {
                                withAnimation(.spring()) {
                                    thresholdMB = preset.mb
                                    scanner.thresholdBytes = preset.bytes
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            let label = LargeFileScanner.allPresets.first(where: { $0.mb == thresholdMB })?.label ?? "\(Int(thresholdMB)) MB"
                            Text(label)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(height: 36) // Standardized height with AppButton
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    AppButton(title: "Scan", icon: "magnifyingglass", style: .primary, isEnabled: !scanner.isScanning) {
                        selectedIDs = []
                        Task { await scanner.scan() }
                    }
                }
            }
        }
    }

    private func quickTargetButton(title: String, icon: String, path: String) -> some View {
        // Same style as the Duplicate Finder's preset buttons.
        AppButton(title: title, icon: icon, style: .glass, isEnabled: !scanner.isScanning) {
            selectedIDs = []
            let expanded = (path as NSString).expandingTildeInPath
            Task { await scanner.scan(in: URL(fileURLWithPath: expanded)) }
        }
    }
    
    private var scanningState: some View {
        VStack(spacing: 20) {
            AppLoading(size: 32, strokeWidth: 2)
            VStack(spacing: 4) {
                Text("Searching your Mac…")
                    .font(.system(size: 15, weight: .bold))
                Text("Filtering for files larger than \(Int(thresholdMB)) MB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.accentColor)
                .opacity(0.5)
            VStack(spacing: 4) {
                Text("No Large Files Found")
                    .font(.system(size: 18, weight: .bold))
                Text("Try reducing the size threshold in the header.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var fileList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(scanner.files) { file in
                    LargeFileRow(
                        file: file,
                        isSelected: selectedIDs.contains(file.id),
                        onTap: {
                            if selectedIDs.contains(file.id) {
                                selectedIDs.remove(file.id)
                            } else {
                                selectedIDs.insert(file.id)
                            }
                        }
                    )
                    Divider().padding(.leading, 48).opacity(0.1)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                
                HStack(spacing: 4) {
                    Text("Total:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                    RollingSizeView(value: scanner.files.reduce(0) { $0 + $1.size })
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            
            Spacer()
            
            if !selectedIDs.isEmpty {
                HStack(spacing: 16) {
                    Button("Deselect All") {
                        withAnimation(.spring()) { selectedIDs = [] }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    
                    Text("\(selectedIDs.count) selected")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    AppButton(title: "Move to Trash", style: .primary) {
                        confirmDeletion = true
                    }
                }
            } else {
                AppButton(title: "Select Files", style: .plain, isEnabled: false) { }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(height: 72)
    }
    
    private var deletionConfirmDialog: some View {
        AppDialog(
            title: "Move Files to Trash",
            subtitle: "These files will be moved to the Trash",
            onDismiss: { confirmDeletion = false }
        ) {
            VStack(spacing: 0) {
                ForEach(selectedFiles) { file in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.displayName).font(.system(size: 13, weight: .medium))
                            Text(file.displayPath).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(file.size.formattedSize).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    Divider().opacity(0.1)
                }
            }
        } actions: {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL SIZE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(totalSelectedSize.formattedSize).font(.system(size: 20, weight: .bold))
            }
            Spacer()
            AppButton(title: "Cancel", style: .glass) { confirmDeletion = false }
            AppButton(title: "Move to Trash", style: .primary) {
                let targets = selectedFiles
                let sizeToReport = totalSelectedSize
                Task {
                    await scanner.moveToTrash(targets)
                    lastDeletedSize = sizeToReport
                    confirmDeletion = false
                    withAnimation { screen = .result }
                }
            }
        }
    }
    
    private var resultView: some View {
        AppResultView(
            title: "Files Moved to Trash",
            subtitle: "Empty the Trash to free the space.",
            stats: [
                (label: "Moved to Trash", value: lastDeletedSize.formattedSize, icon: "doc.badge.checkmark")
            ]
        ) {
            AppButton(title: "Done", style: .primary) {
                selectedIDs = []
                lastDeletedSize = 0
                screen = .list
            }
        }
    }
}

struct LargeFileRow: View {
    let file: LargeFile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 1. Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
                    .font(.system(size: 16))
                    .frame(width: 16)
                
                Image(systemName: "doc") // Outline icon
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(file.displayPath)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                // 2. Size Value
                Text(file.size.formattedSize)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
