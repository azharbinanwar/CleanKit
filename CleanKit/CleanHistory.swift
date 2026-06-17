import Foundation

struct CleanRecord: Codable {
    var lastCleaned: Date
    var lastFreedBytes: Int64
    var totalCleanCount: Int
}

class CleanHistory {
    static let shared = CleanHistory()
    private let key = "clean_history"

    private var records: [String: CleanRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: CleanRecord].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func record(for name: String) -> CleanRecord? {
        records[name]
    }

    func save(name: String, freed: Int64) {
        var all = records
        let existing = all[name]
        all[name] = CleanRecord(
            lastCleaned: Date(),
            lastFreedBytes: freed,
            totalCleanCount: (existing?.totalCleanCount ?? 0) + 1
        )
        records = all
    }
}

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
