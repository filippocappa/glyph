import Foundation

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let date: Date
    let isBarcode: Bool
}

/// Keeps a capped, disk-persisted log of recent captures for the History
/// window. Backed by `UserDefaults` — capture volumes are low, so a small
/// JSON blob is simpler than standing up Core Data/SQLite for this.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private static let defaultsKey = "captureHistory"
    private static let maxEntries = 50

    @Published private(set) var entries: [HistoryEntry] = []

    private init() {
        load()
    }

    func add(_ result: RecognitionResult) {
        let entry = HistoryEntry(id: UUID(), text: result.value, date: Date(), isBarcode: result.isBarcode)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        save()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
