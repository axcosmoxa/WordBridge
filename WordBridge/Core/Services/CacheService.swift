import Foundation

protocol CacheServiceProtocol: Sendable {
    func cachedEntry(for query: String) async -> WordEntry?
    func store(_ entry: WordEntry) async
    func allCached() async -> [WordEntry]
}

actor CacheService: CacheServiceProtocol {
    static let shared = CacheService()
    private let file = "wordbridge_cache.json"
    private var cache: [String: WordEntry] = [:]
    private var loaded = false

    private func ensureLoaded() async {
        guard !loaded else { return }
        if let dict: [String: WordEntry] = await PersistenceStore.shared.load([String: WordEntry].self, from: file) {
            cache = dict
        }
        loaded = true
    }

    func cachedEntry(for query: String) async -> WordEntry? {
        await ensureLoaded()
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if var e = cache[key] {
            e.lastAccessedAt = Date()
            cache[key] = e
            await save()
            return e
        }
        return nil
    }

    func store(_ entry: WordEntry) async {
        await ensureLoaded()
        let key = entry.query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var e = entry
        e.lastAccessedAt = Date()
        cache[key] = e
        await save()
    }

    func allCached() async -> [WordEntry] {
        await ensureLoaded()
        return Array(cache.values).sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    private func save() async {
        await PersistenceStore.shared.save(cache, to: file)
        await PersistenceStore.shared.saveShared(cache, to: file)
    }
}
