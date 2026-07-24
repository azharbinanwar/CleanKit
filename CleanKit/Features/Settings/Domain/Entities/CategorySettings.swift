import Foundation
import Observation

@Observable
final class CategorySettings {
    /// Categories to actually scan/clean: user hasn't disabled them AND they
    /// exist on this Mac (auto-hide). Settings still lists every category.
    var enabledCategories: [CleanupCategory] {
        CleanupCategory.all.filter { isEnabled($0.name) && $0.exists }
    }
    
    var enabledCount: Int {
        enabledCategories.count
    }
    
    private var disabledNames: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "disabled_categories") ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "disabled_categories")
        }
    }
    
    func isEnabled(_ name: String) -> Bool {
        !disabledNames.contains(name)
    }
    
    func setEnabled(_ name: String, enabled: Bool) {
        if enabled {
            disabledNames.remove(name)
        } else {
            disabledNames.insert(name)
        }
    }
}
