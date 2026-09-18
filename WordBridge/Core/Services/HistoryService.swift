import Foundation

protocol HistoryServiceProtocol: Sendable {
    func add(_ entry: WordEntry) async
    func history() async -> [HistoryItem]
    func delete(id: UUID) async
    func clear() async
    func isSaved(query: String) async -> Bool
    func savedEntries() async -> [SavedWord]
    func toggleSaved(_ entry: WordEntry) async -> Bool
    func unsave(query: String) async
}

actor HistoryService: HistoryServiceProtocol {
    static let shared = HistoryService()
    private let historyFile = "history.json"
    private let savedFile = "saved.json"
    private var history: [HistoryItem] = []
    private var saved: [SavedWord] = []
    private var loaded = false

    private func ensureLoaded() async {
        guard !loaded else { return }
        if let h: [HistoryItem] = await PersistenceStore.shared.load([HistoryItem].self, from: historyFile) {
            history = h
        }
        if let s: [SavedWord] = await PersistenceStore.shared.load([SavedWord].self, from: savedFile) {
            saved = s
        }
        loaded = true
    }

    func add(_ entry: WordEntry) async {
        await ensureLoaded()
        // remove duplicate query at top
        history.removeAll { $0.query.lowercased() == entry.query.lowercased() }
        let item = HistoryItem(query: entry.query, language: entry.language, timestamp: Date(), preview: entry.translation ?? entry.definition)
        history.insert(item, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        await PersistenceStore.shared.save(history, to: historyFile)
    }

    func history() async -> [HistoryItem] {
        await ensureLoaded()
        return history
    }

    func delete(id: UUID) async {
        await ensureLoaded()
        history.removeAll { $0.id == id }
        await PersistenceStore.shared.save(history, to: historyFile)
    }

    func clear() async {
        await ensureLoaded()
        history.removeAll()
        await PersistenceStore.shared.save(history, to: historyFile)
    }

    func isSaved(query: String) async -> Bool {
        await ensureLoaded()
        return saved.contains { $0.query.lowercased() == query.lowercased() }
    }

    func savedEntries() async -> [SavedWord] {
        await ensureLoaded()
        return saved.sorted { $0.savedAt > $1.savedAt }
    }

    @discardableResult
    func toggleSaved(_ entry: WordEntry) async -> Bool {
        await ensureLoaded()
        if let idx = saved.firstIndex(where: { $0.query.lowercased() == entry.query.lowercased() }) {
            saved.remove(at: idx)
            await PersistenceStore.shared.save(saved, to: savedFile)
            await PersistenceStore.shared.saveShared(saved, to: savedFile)
            return false
        } else {
            let s = SavedWord(query: entry.query, language: entry.language, entry: entry, savedAt: Date())
            saved.insert(s, at: 0)
            await PersistenceStore.shared.save(saved, to: savedFile)
            await PersistenceStore.shared.saveShared(saved, to: savedFile)
            return true
        }
    }

    func unsave(query: String) async {
        await ensureLoaded()
        saved.removeAll { $0.query.lowercased() == query.lowercased() }
        await PersistenceStore.shared.save(saved, to: savedFile)
        await PersistenceStore.shared.saveShared(saved, to: savedFile)
    }
}
