import Foundation

struct CleanRecord: Codable, Identifiable {
    let id = UUID()
    let name: String
    let freedBytes: Int64
    let date: Date
}

struct CategoryStats {
    let totalCleanCount: Int
    let lastCleaned: Date
    let lastFreedBytes: Int64
}

final class CleanHistory {
    static let shared = CleanHistory()
    private let key = "clean_history"
    
    private init() {}
    
    func save(name: String, freed: Int64) {
        var history = load()
        let record = CleanRecord(name: name, freedBytes: freed, date: Date())
        history.insert(record, at: 0)
        if history.count > 500 { history.removeLast() }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func load() -> [CleanRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([CleanRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    func stats(for name: String) -> CategoryStats? {
        let matches = load().filter { $0.name == name }
        guard let last = matches.first else { return nil }
        
        return CategoryStats(
            totalCleanCount: matches.count,
            lastCleaned: last.date,
            lastFreedBytes: last.freedBytes
        )
    }
}
