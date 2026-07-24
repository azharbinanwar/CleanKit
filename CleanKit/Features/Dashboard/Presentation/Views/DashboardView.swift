import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel
    let categorySettings: CategorySettings
    let onSelectTool: (Tool) -> Void

    private var tools: [Tool] { Tool.allCases.filter { $0 != .home } }

    var body: some View {
        ZStack {
            // Background Ambient Glow - Disabled hit testing to prevent blocking sidebar
            Circle()
                .fill(Color.accentColor.opacity(0.04))
                .blur(radius: 120)
                .offset(x: -300, y: -200)
                .allowsHitTesting(false)
            
            VStack(spacing: 24) {
                if viewModel.manager.hasMissingPermissions {
                    AppBanner(
                        icon: "lock.shield.fill",
                        message: "Some system folders are protected. Grant Full Disk Access to clean everything.",
                        actionTitle: "Fix Now"
                    ) {
                        NSWorkspace.shared.open(AppPermission.fullDiskAccess.settingsURL)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 1. Full Width Top Card
                StorageGauge(
                    title: "Macintosh HD",
                    subtitle: "Disk health is optimal",
                    usedFraction: viewModel.storageInfo.usedFraction,
                    details: [
                        (label: "Available", value: viewModel.storageInfo.free.formattedSize),
                        (label: "Used", value: viewModel.storageInfo.used.formattedSize),
                        (label: "Capacity", value: viewModel.storageInfo.total.formattedSize)
                    ],
                    onRefresh: { viewModel.refreshStorage() },
                    onAction: { Task { await viewModel.scanAll() } }
                )
                
                // 2. 2x2 Grid at Bottom
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 20) {
                    ForEach(tools) { tool in
                        ToolCard(
                            toolName: tool.rawValue,
                            subtitle: tool.subtitle,
                            icon: tool.icon,
                            color: Color.accentColor,
                            status: tool == .cleaner ? viewModel.cleanerLabel : nil,
                            categoryCount: tool == .cleaner ? categorySettings.enabledCount : nil,
                            onOpen: { onSelectTool(tool) },
                            onScan: tool == .cleaner ? { Task { await viewModel.scanAll() } } : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
    }
}
