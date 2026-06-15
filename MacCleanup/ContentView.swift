import SwiftUI

struct ContentView: View {
    @State private var manager = CleanupManager()
    @State private var screen: Screen = .scan

    enum Screen { case scan, cleanAll, done }

    var body: some View {
        switch screen {
        case .scan:
            ScanView(manager: manager, onClean: { screen = .cleanAll })
        case .cleanAll:
            CleanAllView(manager: manager, onDone: { screen = .done })
        case .done:
            DoneView(manager: manager, onRestart: {
                manager.totalFreedBytes = 0
                manager.categories = CleanupCategory.all
                screen = .scan
            })
        }
    }
}

// MARK: - Screen 1: Scan + Choose

struct ScanView: View {
    var manager: CleanupManager
    let onClean: () -> Void

    @State private var storageInfo = StorageInfo.load()
    @State private var chooseMode = false
    @State private var selected: Set<UUID> = []
    @State private var confirmPayload: ConfirmPayload? = nil
    @State private var sortAscending = false

    var body: some View {
        VStack(spacing: 0) {
            header
            StorageBarView(info: storageInfo)
            Divider()
            listView
        }
        .frame(width: 560, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task { await manager.scanAll() }
        }
        .sheet(item: $confirmPayload) { payload in
            ConfirmSheet(items: payload.items, onCancel: {
                confirmPayload = nil
            }, onConfirm: {
                confirmPayload = nil
                manager.selectedIDs = Set(payload.items.map { $0.id })
                onClean()
                storageInfo = StorageInfo.load()
            })
        }
    }

    var header: some View {
        HStack {
            Image(systemName: "trash.circle.fill")
                .font(.title)
                .foregroundColor(.accentColor)
            Text("Mac Cleanup")
                .font(.title2.bold())
            Spacer()
            Button {
                manager.categories = CleanupCategory.all
                chooseMode = false
                selected = []
                Task { await manager.scanAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(manager.isScanning)
            .help("Re-scan")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var listView: some View {
        VStack(spacing: 0) {
            // toolbar: select-all (choose mode) or sort button
            HStack {
                if chooseMode {
                    let allSelected = selected.count == nonEmpty.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        selected = allSelected ? [] : Set(nonEmpty.map { $0.id })
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    Spacer()
                    Text("\(selected.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Spacer()
                    Button {
                        sortAscending.toggle()
                    } label: {
                        Label(sortAscending ? "Smallest First" : "Largest First",
                              systemImage: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(manager.isScanning)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            Divider()

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    if manager.isScanning {
                        ForEach(manager.categories) { cat in
                            categoryRow(cat)
                            Divider().padding(.leading, 56)
                        }
                    } else {
                        // Group 1: Found — sorted, real sizes only
                        if !nonEmpty.isEmpty {
                            Section {
                                ForEach(nonEmpty) { cat in
                                    categoryRow(cat)
                                    Divider().padding(.leading, 56)
                                }
                            } header: {
                                sectionHeader("Found — \(nonEmpty.count) items")
                            }
                        }
                        // Group 2: Commands
                        if !commandOnly.isEmpty {
                            Section {
                                ForEach(commandOnly) { cat in
                                    categoryRow(cat)
                                    Divider().padding(.leading, 56)
                                }
                            } header: {
                                sectionHeader("Commands — size unknown until cleaned")
                            }
                        }
                        // Group 3: Nothing to Clean
                        if !emptyCategories.isEmpty {
                            Section {
                                ForEach(emptyCategories) { cat in
                                    categoryRow(cat)
                                    Divider().padding(.leading, 56)
                                }
                            } header: {
                                sectionHeader("Nothing to Clean — \(emptyCategories.count) items")
                            }
                        }
                    }
                }
                .id("\(sortAscending)-\(manager.isScanning)")
            }

            Divider()
            HStack {
                if manager.isScanning {
                    Text("Total:").font(.headline)
                    ProgressView().scaleEffect(0.7)
                } else {
                    let total = nonEmpty.reduce(0) { $0 + $1.sizeBytes }
                    Text("Total: **\(total.formattedSize)**").font(.headline)
                }
                Spacer()
                if chooseMode {
                    Button("Cancel") { chooseMode = false; selected = [] }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("Clean Selected (\(selected.count))") {
                        confirmPayload = ConfirmPayload(items: nonEmpty.filter { selected.contains($0.id) })
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selected.isEmpty)
                } else {
                    Button("Choose") {
                        chooseMode = true
                        selected = []
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(manager.isScanning)
                    Button("Clean All") {
                        confirmPayload = ConfirmPayload(items: nonEmpty + commandOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(manager.isScanning || nonEmpty.isEmpty)
                }
            }
            .padding(20)
        }
    }

    func categoryRow(_ cat: CleanupCategory) -> some View {
        let isScanning = manager.scanningIndex == manager.categories.firstIndex(where: { $0.id == cat.id })
        let isEmpty = cat.sizeBytes == 0 && !isScanning
        let history = CleanHistory.shared.record(for: cat.name)

        return HStack(spacing: 12) {
            if chooseMode {
                if cat.sizeBytes > 0 {
                    Image(systemName: selected.contains(cat.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selected.contains(cat.id) ? .accentColor : .secondary)
                        .font(.title3)
                } else {
                    Spacer().frame(width: 22)
                }
            }
            Image(systemName: cat.icon)
                .frame(width: 22)
                .foregroundColor(isEmpty ? .secondary.opacity(0.4) : .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name)
                    .foregroundColor(isEmpty ? .secondary : .primary)
                if let h = history {
                    Text("Last cleaned \(h.lastCleaned.relativeString) · \(h.totalCleanCount)x · freed \(h.lastFreedBytes.formattedSize)")
                        .font(.caption2)
                        .foregroundColor(.accentColor.opacity(0.8))
                }
            }
            Spacer()
            if isScanning {
                ProgressView().scaleEffect(0.7).frame(width: 60)
            } else {
                Text(cat.sizeBytes > 0 ? cat.sizeBytes.formattedSize : cat.shellCommand != nil ? "cmd" : "—")
                    .foregroundColor(cat.sizeBytes > 0 ? .primary : cat.shellCommand != nil ? .accentColor : .secondary.opacity(0.4))
                    .font(cat.shellCommand != nil && cat.sizeBytes == 0 ? .caption.bold() : .body)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { if chooseMode && cat.sizeBytes > 0 { toggle(cat.id) } }
    }

    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var nonEmpty: [CleanupCategory] {
        let items = manager.categories.filter { $0.sizeBytes > 0 }
        return sortAscending ? items.sorted { $0.sizeBytes < $1.sizeBytes } : items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    var commandOnly: [CleanupCategory] {
        manager.categories.filter { $0.shellCommand != nil && $0.sizeBytes == 0 }
    }

    var emptyCategories: [CleanupCategory] {
        manager.categories.filter { $0.sizeBytes == 0 && $0.shellCommand == nil }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}

struct ConfirmPayload: Identifiable {
    let id = UUID()
    let items: [CleanupCategory]
}

// MARK: - Confirmation Sheet

struct ConfirmSheet: View {
    let items: [CleanupCategory]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var totalSize: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                Text("Confirm Cleanup")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { cat in
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .frame(width: 22)
                                .foregroundColor(.accentColor)
                            Text(cat.name)
                            Spacer()
                            Text(cat.sizeBytes > 0 ? cat.sizeBytes.formattedSize : "—")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        Divider().padding(.leading, 54)
                    }
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total to free")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalSize.formattedSize)
                        .font(.headline)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Delete Now") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 480, height: 400)
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
        .frame(width: 560, height: 520)
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
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            VStack(spacing: 8) {
                Text("All Done!")
                    .font(.largeTitle.bold())
                Text("You freed up")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(manager.totalFreedBytes.formattedSize)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }
            Button("Scan Again") { onRestart() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Spacer()
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}
