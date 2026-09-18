import Foundation

protocol DictionaryServiceProtocol: Sendable {
    func lookupEnglish(_ word: String) async throws -> WordEntry
}

actor DictionaryService: DictionaryServiceProtocol {
    static let shared = DictionaryService()
    private let client = APIClient.shared
    private let cache = CacheService.shared

    func lookupEnglish(_ word: String) async throws -> WordEntry {
        let q = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = await cache.cachedEntry(for: q), cached.language == .english {
            return cached
        }
        // Free Dictionary API
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(q.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? q)") else {
            throw APIError.network
        }
        let dtos: [DictionaryEntryDTO] = try await client.get(url, as: [DictionaryEntryDTO].self)
        guard let dto = dtos.first else { throw APIError.notFound }
        let entry = map(dto: dto, query: word)
        await cache.store(entry)
        return entry
    }

    private func map(dto: DictionaryEntryDTO, query: String) -> WordEntry {
        let phonetic = dto.phonetic ?? dto.phonetics?.first(where: { $0.text != nil })?.text
        let audio = dto.phonetics?.first(where: { $0.audio != nil && !($0.audio!.isEmpty) })?.audio
        let firstMeaning = dto.meanings?.first
        let def = firstMeaning?.definitions?.first?.definition
        let example = firstMeaning?.definitions?.first?.example
        var syns: [String] = []
        if let s = firstMeaning?.synonyms { syns.append(contentsOf: s) }
        if let s = firstMeaning?.definitions?.first?.synonyms { syns.append(contentsOf: s) }
        syns = Array(Set(syns)).prefix(5).map { $0 }
        let pos = firstMeaning?.partOfSpeech

        // Hindi translation via MyMemory will be filled later by callers if needed; do initial empty
        return WordEntry(
            query: query,
            language: .english,
            translation: nil,
            definition: def,
            simpleDefinition: def,
            partOfSpeech: pos,
            pronunciation: phonetic,
            phonetic: phonetic,
            audioURL: audio,
            example: example,
            exampleTranslation: nil,
            synonyms: syns,
            relatedWords: [],
            source: "dictionaryapi.dev"
        )
    }
}
