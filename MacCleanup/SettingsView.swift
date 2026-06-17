import SwiftUI

struct SettingsView: View {
    let categorySettings: CategorySettings
    @State private var selectedSection: SettingsSection = .appearance

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case cleaner     = "Mac Cleaner"
        case largeFiles  = "Large File Finder"
        case duplicates  = "Duplicate Finder"
        case about       = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: "paintbrush.fill"
            case .cleaner:    "trash.fill"
            case .largeFiles: "doc.text.magnifyingglass"
            case .duplicates: "doc.on.doc.fill"
            case .about:      "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .appearance: .blue
            case .cleaner:    .accentColor
            case .largeFiles: .orange
            case .duplicates: .purple
            case .about:      .gray
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolHeaderView(title: "Settings", subtitle: "Customize CleanKit")
            Divider()
            HStack(spacing: 0) {
                sectionList
                Divider()
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sectionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(SettingsSection.allCases.enumerated()), id: \.element.id) { idx, section in
                Button { selectedSection = section } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(section.color)
                                .frame(width: 28, height: 28)
                            Image(systemName: section.icon)
                                .foregroundColor(.white)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedSection == section ? .accentColor : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(selectedSection == section ? Color.accentColor.opacity(0.08) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < SettingsSection.allCases.count - 1 {
                    Divider().opacity(0.4)
                }
            }
            Spacer()
        }
        .frame(width: 200)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .appearance: AppearanceSettings()
        case .cleaner:    CleanerSettings(categorySettings: categorySettings)
        case .largeFiles: LargeFileSettings()
        case .duplicates: DuplicateSettings()
        case .about:      AboutSettings()
        }
    }

}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @AppStorage("appTheme") private var theme: String = "system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("Appearance").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme")
                            .font(.system(size: 13, weight: .medium))
                        Text("Choose the app appearance.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(["system", "light", "dark"], id: \.self) { option in
                            themeOption(option)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                Divider().opacity(0.4)
            }
        }
    }

    private func themeOption(_ value: String) -> some View {
        Button { theme = value } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeBackground(value))
                        .frame(width: 72, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme == value ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: theme == value ? 2 : 1)
                        )
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value == "dark" ? Color.white.opacity(0.15) : value == "light" ? Color.black.opacity(0.08) : Color.gray.opacity(0.45))
                            .frame(width: 18, height: 34)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value == "dark" ? Color.white.opacity(0.08) : value == "light" ? Color.black.opacity(0.04) : Color.gray.opacity(0.25))
                            .frame(width: 40, height: 34)
                    }
                }
                Text(value.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme == value ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func themeBackground(_ value: String) -> AnyShapeStyle {
        switch value {
        case "dark":  return AnyShapeStyle(Color.black)
        case "light": return AnyShapeStyle(Color.white)
        default:
            return AnyShapeStyle(LinearGradient(
                stops: [
                    .init(color: Color.black, location: 0.499),
                    .init(color: Color.white, location: 0.501)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
}

// MARK: - Mac Cleaner

private struct CleanerSettings: View {
    let categorySettings: CategorySettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("Mac Cleaner").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)

                ForEach(CleanerGroup.all) { group in
                    let cats = CleanupCategory.all.filter { group.categoryNames.contains($0.name) }

                    Text(group.name)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 6)

                    ForEach(Array(cats.enumerated()), id: \.element.id) { idx, cat in
                        Divider().opacity(0.4)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name)
                                    .font(.system(size: 13))
                                Text(cat.paths.first ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { categorySettings.isEnabled(cat.name) },
                                set: { _ in categorySettings.toggle(cat.name) }
                            ))
                            .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                    }
                }
                Divider().opacity(0.4)
            }
        }
    }
}

// MARK: - Large File Finder

private struct LargeFileSettings: View {
    @AppStorage("largeFileDefaultMB") private var defaultMB: Double = 100
    @AppStorage("largeFileHiddenPresets") private var hiddenPresetsRaw: String = ""

    private var hiddenPresets: Set<String> {
        Set(hiddenPresetsRaw.split(separator: ",").map(String.init))
    }

    private func toggleHidden(_ label: String) {
        var set = hiddenPresets
        if set.contains(label) { set.remove(label) } else { set.insert(label) }
        hiddenPresetsRaw = set.joined(separator: ",")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("Large File Finder").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)

                Text("File Size Presets")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                ForEach(LargeFileScanner.allPresets, id: \.label) { preset in
                    let isHidden = hiddenPresets.contains(preset.label)
                    let isDefault = defaultMB == preset.mb

                    Divider().opacity(0.4)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isHidden ? .secondary : .primary)
                            Text(isDefault ? "Default on open" : "Available in picker")
                                .font(.caption2)
                                .foregroundColor(isDefault ? .accentColor : .secondary)
                        }
                        Spacer()
                        if !isHidden {
                            Button {
                                defaultMB = preset.mb
                            } label: {
                                Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDefault ? .accentColor : .secondary.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        Toggle("", isOn: Binding(
                            get: { !isHidden },
                            set: { _ in
                                let enabledCount = LargeFileScanner.allPresets.filter { !hiddenPresets.contains($0.label) }.count
                                if !isHidden && enabledCount <= 1 { return }
                                if isDefault && !isHidden {
                                    let next = LargeFileScanner.allPresets.first { $0.label != preset.label && !hiddenPresets.contains($0.label) }
                                    if let next { defaultMB = next.mb }
                                }
                                toggleHidden(preset.label)
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Divider().opacity(0.4)
            }
        }
    }
}

// MARK: - Duplicate Finder

private struct DuplicateSettings: View {
    @AppStorage("duplicateWarnLimit") private var warnLimit: Double = 3000
    @AppStorage("duplicateBlockLimit") private var blockLimit: Double = 8000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("Duplicate Finder").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)
                limitRow(title: "Warning Threshold", subtitle: "Show a caution dialog above this file count.", value: $warnLimit, range: 1000...5000, step: 500)
                Divider().opacity(0.4)
                limitRow(title: "Block Threshold", subtitle: "Prevent scanning above this file count.", value: $blockLimit, range: 3000...20000, step: 1000)
                Divider().opacity(0.4)
            }
        }
    }

    private func limitRow(title: String, subtitle: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(Int(value.wrappedValue).formatted()) files")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 90, alignment: .trailing)
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }
            VStack(spacing: 4) {
                Text("CleanKit")
                    .font(.title2.bold())
                Text(version)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Shared Helpers

private func settingsHeader(_ title: String) -> some View {
    Text(title).font(.title2.bold())
}
