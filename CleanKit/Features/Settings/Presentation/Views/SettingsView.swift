import SwiftUI

struct SettingsView: View {
    let categorySettings: CategorySettings
    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general     = "General"
        case cleaner     = "Mac Cleaner"
        case largeFiles  = "Large File Finder"
        case duplicates  = "Duplicate Finder"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general:    "gearshape"
            case .cleaner:    "trash"
            case .largeFiles: "doc.text.magnifyingglass"
            case .duplicates: "doc.on.doc"
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            AppHeader(title: "Settings", subtitle: "Customize CleanKit") { EmptyView() }

            HStack(spacing: 16) {
                sectionList
                    .frame(width: 220)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionList: some View {
        VStack(spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                AppTile(
                    title: section.rawValue,
                    icon: section.icon,
                    isSelected: selectedSection == section,
                    action: { selectedSection = section }
                )
            }
            Spacer()
        }
        .padding(8)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:    GeneralSettings()
        case .cleaner:    CleanerSettings(categorySettings: categorySettings)
        case .largeFiles: LargeFileSettings()
        case .duplicates: DuplicateSettings()
        }
    }
}


// MARK: - Reusable settings row (icon tile · title/subtitle · trailing control)

private struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = .accentColor
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(tint)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - General (Appearance · Software Update · About)

private struct GeneralSettings: View {
    @AppStorage("appTheme") private var theme: String = "system"
    @State private var checker = UpdateChecker.shared
    @AppStorage("updates.autoCheck") private var autoCheck = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("General").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)

                // Appearance
                groupLabel("Appearance")
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme").font(.system(size: 13, weight: .medium))
                        Text("Choose the app appearance.").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(["system", "light", "dark"], id: \.self) { themeOption($0) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                Divider().opacity(0.4)

                // Software Update
                groupLabel("Software Update")
                SettingRow(title: "Software Updates", subtitle: statusText, icon: "arrow.down.circle") {
                    updateControl
                }
                if case .available(let v) = checker.phase {
                    SettingRow(title: "Version \(v) is available",
                               subtitle: "Downloads, verifies with SHA-256, and installs automatically. CleanKit relaunches when done.",
                               icon: "sparkles", tint: .accentColor) {
                        AppButton(title: "Install", icon: "arrow.down.circle", style: .primary) {
                            Task { await checker.downloadAndInstall() }
                        }
                    }
                }
                if case .downloading(let p) = checker.phase {
                    HStack(spacing: 10) {
                        ProgressView(value: p).frame(maxWidth: 240)
                        Text("\(Int(p * 100))%").font(.system(size: 11).monospacedDigit()).foregroundColor(.secondary)
                    }
                    .padding(.leading, 44).padding(.trailing, 16).padding(.bottom, 12)
                }
                SettingRow(title: "Check automatically",
                           subtitle: "Look for new versions once a day, on launch.",
                           icon: "clock.arrow.circlepath") {
                    Toggle("", isOn: $autoCheck).toggleStyle(.switch).labelsHidden()
                }
                Divider().opacity(0.4)

                // About
                groupLabel("About")
                SettingRow(title: "CleanKit", subtitle: "The open-source Mac cleanup toolkit.", icon: "sparkles") {
                    Text("v\(checker.currentVersion)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Button { checker.openReleasesPage() } label: {
                    SettingRow(title: "GitHub", subtitle: "github.com/azharbinanwar/CleanKit",
                               icon: "chevron.left.forwardslash.chevron.right") {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .task { await checker.checkIfDue() }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundColor(.secondary).textCase(.uppercase)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 6)
    }

    private var statusText: String {
        switch checker.phase {
        case .idle:
            if let last = checker.lastChecked { return "Last checked \(last.relativeString)." }
            return "See if a newer version is available."
        case .checking:            return "Checking for updates…"
        case .upToDate:            return "You're up to date. \(checker.currentVersion) is the latest."
        case .available(let v):    return "Version \(v) is ready to install."
        case .downloading:         return "Downloading CleanKit.dmg…"
        case .installing:          return "Installing. CleanKit will relaunch in a moment…"
        case .downloaded(let v):   return "Drag CleanKit \(v) from the opened window into Applications."
        case .failed(let m):       return m
        }
    }

    @ViewBuilder
    private var updateControl: some View {
        switch checker.phase {
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        case .upToDate:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
                AppButton(title: "Check Again", style: .glass) { Task { await checker.check() } }
            }
        case .available:
            EmptyView()
        default:
            AppButton(title: "Check", style: .glass) { Task { await checker.check() } }
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
                    // Mini app window: sidebar + content, so the swatch reads as CleanKit.
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(value, strong: true))
                            .frame(width: 16, height: 34)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(value, strong: false))
                            .frame(width: 38, height: 34)
                    }
                }
                Text(value.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme == value ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func barColor(_ value: String, strong: Bool) -> Color {
        switch value {
        case "dark":  return Color.white.opacity(strong ? 0.16 : 0.08)
        case "light": return Color.black.opacity(strong ? 0.10 : 0.05)
        default:      return Color.gray.opacity(strong ? 0.45 : 0.25)
        }
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

private struct CleanerSettings: View {
    let categorySettings: CategorySettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader("Mac Cleaner").padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                Divider().opacity(0.4)
                ForEach(CleanerGroup.all) { group in
                    let cats = CleanupCategory.all.filter { group.categoryNames.contains($0.name) }
                    Text(group.name).font(.caption.weight(.semibold)).foregroundColor(.secondary).textCase(.uppercase).padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 6)
                    ForEach(cats) { cat in
                        Divider().opacity(0.4)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(cat.name).font(.system(size: 13))
                                    SafetyBadge(safety: cat.safety)
                                }
                                Text(cat.info).font(.caption2).foregroundColor(.secondary).lineLimit(1).truncationMode(.tail)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { categorySettings.isEnabled(cat.name) }, set: { _ in categorySettings.setEnabled(cat.name, enabled: !categorySettings.isEnabled(cat.name)) }))
                                .toggleStyle(.switch).controlSize(.mini)
                        }.padding(.horizontal, 16).padding(.vertical, 9)
                    }
                }
                Divider().opacity(0.4)
            }
        }
    }
}

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


private func settingsHeader(_ title: String) -> some View {
    Text(title).font(.title2.bold())
}
