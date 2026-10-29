import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    var storageInfo = StorageInfo.load()
    var isScanning = false
    
    let manager: CleanupManager
    
    init(manager: CleanupManager) {
        self.manager = manager
    }
    
    func refreshStorage() {
        storageInfo = StorageInfo.load()
    }
    
    func scanAll() async {
        isScanning = true
        await manager.scanAll()
        isScanning = false
    }
    
    var cleanerLabel: String {
        if manager.isScanning { return "Scanning…" }
        let total = CleanupManager.dedupedSize(manager.categories)
        return total > 0 ? total.formattedSize : "Scan Now"
    }
}
