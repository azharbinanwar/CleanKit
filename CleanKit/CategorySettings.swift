import Foundation
import Observation

@Observable
@MainActor
class CategorySettings {
    private let key = "disabledCategoryNames"

    var disabledNames: Set<String> {
        didSet { save() }
    }

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: "disabledCategoryNames") ?? []
        disabledNames = Set(stored)
    }

    var enabledCategories: [CleanupCategory] {
        CleanupCategory.all.filter { !disabledNames.contains($0.name) }
    }

    var enabledCount: Int { enabledCategories.count }

    func isEnabled(_ name: String) -> Bool {
        !disabledNames.contains(name)
    }

    func toggle(_ name: String) {
        if disabledNames.contains(name) {
            disabledNames.remove(name)
        } else {
            disabledNames.insert(name)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(disabledNames), forKey: key)
    }
}
