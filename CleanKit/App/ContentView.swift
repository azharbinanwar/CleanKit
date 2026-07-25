import SwiftUI

// MARK: - Tool

enum Tool: String, CaseIterable, Identifiable {
    case home         = "Dashboard"
    case cleaner      = "Mac Cleaner"
    case largeFinder  = "Large File Finder"
    case uninstaller  = "App Uninstaller"
    case duplicates   = "Duplicate Finder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:        "house"
        case .cleaner:     "trash"
        case .largeFinder: "doc.text.magnifyingglass"
        case .uninstaller: "minus.circle"
        case .duplicates:  "doc.on.doc"
        }
    }

    var subtitle: String {
        switch self {
        case .home:        "Overview & stats"
        case .cleaner:     "categories"
        case .largeFinder: "Find large files"
        case .uninstaller: "Apps & leftovers"
        case .duplicates:  "Find identical files"
        }
    }

    var available: Bool { true }
}

// MARK: - Root

struct ContentView: View {
    @State private var screen: Screen = .scan
    @State private var selectedTool: Tool = .home
    @State private var categorySettings = CategorySettings()
    @State private var sidebarCompact = false
    @State private var showSettings = false
    @State private var showPermissions = false
    @State private var requiredPermissions: [AppPermission] = []
    @AppStorage("appTheme") private var appTheme: String = "system"

    enum Screen { case scan, cleanAll, done }

    private var resolvedColorScheme: ColorScheme {
        switch appTheme {
        case "dark":  return .dark
        case "light": return .light
        default:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }

    var body: some View {
        // No hard gate: the app opens directly. In-app banners warn when a
        // feature needs Full Disk Access, instead of locking the whole app.
        mainContent
        .overlay(alignment: .top) { appBar }
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                // Main Ambient Background Glow
                Circle()
                    .fill(Color.accentColor.opacity(0.05))
                    .blur(radius: 150)
                    .offset(x: -400, y: -200)
            }
        )
        .frame(minWidth: 1180, minHeight: 720)
        .preferredColorScheme(resolvedColorScheme)
        .animation(.easeInOut(duration: 0.2), value: showPermissions)
        .ignoresSafeArea()
        .focusEffectDisabled() // no odd default focus ring on launch
    }

    // Plain centered app name in the title-bar band, with a divider under it.
    private var appBar: some View {
        VStack(spacing: 0) {
            Text("CleanKit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 9)
            Divider().opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var mainContent: some View {
        HStack(spacing: 16) { // Increased spacing between sidebar and content
            // Floating Sidebar Container
            SidebarView(selectedTool: $selectedTool, isCompact: $sidebarCompact, showSettings: $showSettings)
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .padding(.top, 48) // Below the traffic lights + appbar (original position)

            Group {
                if showSettings {
                    SettingsView(categorySettings: categorySettings)
                } else {
                    detailView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            .padding(.top, 48) // Align with sidebar
            
            PermissionsPanel(isShowing: $showPermissions, permissions: requiredPermissions)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTool {
        case .home:
            DashboardView(
                viewModel: ServiceLocator.shared.resolve(),
                categorySettings: categorySettings,
                onSelectTool: { selectedTool = $0 }
            )
        case .cleaner:     cleanerView
        case .largeFinder: LargeFileView(scanner: ServiceLocator.shared.resolve(), onPermissionMissing: { perms in
            requiredPermissions = perms
            withAnimation(.easeInOut(duration: 0.2)) { showPermissions = true }
        })
        case .uninstaller: AppUninstallerView(scanner: ServiceLocator.shared.resolve())
        case .duplicates:  DuplicateFinderView(scanner: ServiceLocator.shared.resolve())
        }
    }

    @ViewBuilder
    private var cleanerView: some View {
        let manager: CleanupManager = ServiceLocator.shared.resolve()
        switch screen {
        case .scan:
            MacCleanerView(manager: manager, categorySettings: categorySettings, onClean: { screen = .cleanAll })
        case .cleanAll:
            CleanAllView(manager: manager, onDone: { screen = .done })
        case .done:
            DoneView(
                manager: manager,
                onBack: {
                    selectedTool = .home
                    screen = .scan
                },
                onRescan: {
                    manager.totalFreedBytes = 0
                    manager.categories = categorySettings.enabledCategories
                    screen = .scan
                    Task { await manager.scanAll() }
                }
            )
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTool: Tool
    @Binding var isCompact: Bool
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(Tool.allCases) { tool in
                    AppTile(
                        title: isCompact ? "" : tool.rawValue,
                        icon: tool.icon,
                        isSelected: selectedTool == tool && !showSettings,
                        isEnabled: tool.available,
                        action: {
                            showSettings = false
                            selectedTool = tool
                        }
                    )
                    .help(isCompact ? tool.rawValue : "")
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)

            Spacer()

            AppTile(
                title: isCompact ? "" : "Settings",
                icon: "gearshape",
                isSelected: showSettings,
                action: { showSettings = true }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .frame(width: isCompact ? 56 : 220)
        .background(.ultraThinMaterial)
        .cornerRadius(10) // Half of previous radius to match window better
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
