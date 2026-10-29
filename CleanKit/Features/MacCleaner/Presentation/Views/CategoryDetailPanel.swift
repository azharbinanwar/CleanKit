import SwiftUI

/// Replaces the category list (like the uninstaller's AppDetailPanel) to list
/// an expandable category's sub-items (projects, runtimes, backups…) so the
/// user can untick the ones to keep.
struct CategoryDetailPanel: View {
    var manager: CleanupManager
    let category: CleanupCategory
    @Binding var selectedIDs: Set<UUID>
    let onBack: () -> Void

    @State private var items: [CleanupManager.CategoryEntry]?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.1)

            if let items {
                if items.isEmpty {
                    Text("Nothing to choose here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    selectionBar(items)
                    Divider().opacity(0.1)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                itemRow(item, in: items)
                                Divider().padding(.leading, 44).opacity(0.1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                ProgressView("Measuring…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: category.id) { items = await manager.entries(of: category) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Back to the list")
            Image(systemName: category.icon)
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(category.name).font(.title3.bold())
                    SafetyBadge(safety: category.safety)
                    if category.isLargeDownload { LargeDownloadBadge(bytes: category.cleanableBytes) }
                }
                Text(category.info)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(category.cleanableBytes.formattedSize)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                Text("To Clean")
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }

    private func selectionBar(_ items: [CleanupManager.CategoryEntry]) -> some View {
        let chosen = items.filter { !category.excludedItems.contains($0.id) }
        return HStack {
            Text("\(chosen.count) of \(items.count) · \(chosen.reduce(0) { $0 + $1.size }.formattedSize)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
            Button("Select All") { setExcluded([], in: items) }
            Button("Select None") { setExcluded(Set(items.map(\.id)), in: items) }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.accentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func itemRow(_ item: CleanupManager.CategoryEntry, in items: [CleanupManager.CategoryEntry]) -> some View {
        let isOn = !category.excludedItems.contains(item.id)
        return Button {
            var next = category.excludedItems
            if isOn { next.insert(item.id) } else { next.remove(item.id) }
            setExcluded(next, in: items)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? .accentColor : .secondary.opacity(0.4))
                    .font(.system(size: 15))
                Text(item.name)
                    .font(.system(size: 12))
                    .foregroundColor(isOn ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(item.size.formattedSize)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.id)
    }

    /// Unticking everything deselects the category; ticking anything selects it.
    private func setExcluded(_ ids: Set<String>, in items: [CleanupManager.CategoryEntry]) {
        let bytes = items.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.size }
        manager.setExcluded(ids, bytes: bytes, for: category.id)
        if ids.count == items.count { selectedIDs.remove(category.id) } else { selectedIDs.insert(category.id) }
    }
}
