import SwiftUI

@main
struct CleanKitApp: App {
    init() {
        setupDI()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await UpdateChecker.shared.checkIfDue() } // daily auto-check
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 760)
    }
    
    private func setupDI() {
        let locator = ServiceLocator.shared
        
        // Managers & Scanners
        let cleanupManager = CleanupManager()
        locator.register(cleanupManager)
        
        let largeScanner = LargeFileScanner()
        locator.register(largeScanner)
        
        let appScanner = AppUninstallerScanner()
        locator.register(appScanner)
        
        let duplicateScanner = DuplicateScanner()
        locator.register(duplicateScanner)
        
        // ViewModels
        let dashboardVM = DashboardViewModel(manager: cleanupManager)
        locator.register(dashboardVM)
    }
}
