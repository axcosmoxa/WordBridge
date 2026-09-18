import Foundation

protocol TranslationServiceProtocol: Sendable {
    func translate(_ text: String, from: String, to: String) async throws -> String
    func englishToHindi(_ word: String) async -> String?
    func hindiToEnglish(_ word: String) async -> [String]
}

actor TranslationService: TranslationServiceProtocol {
    static let shared = TranslationService()
    private let client = APIClient.shared

    func translate(_ text: String, from: String, to: String) async throws -> String {
        let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlStr = "https://api.mymemory.translated.net/get?q=\(q)&langpair=\(from)|\(to)"
        guard let url = URL(string: urlStr) else { throw APIError.network }
        let resp: MyMemoryResponse = try await client.get(url, as: MyMemoryResponse.self)
        if let t = resp.responseData?.translatedText, !t.isEmpty {
            return t
        }
        throw APIError.notFound
    }

    func englishToHindi(_ word: String) async -> String? {
        // Check cache first? translation cache is part of WordEntry cache
        do {
            let t = try await translate(word, from: "en", to: "hi")
            // MyMemory may return same word if not found; heuristically check
            if t.lowercased() == word.lowercased() { return nil }
            return t
        } catch {
            return nil
        }
    }

    func hindiToEnglish(_ word: String) async -> [String] {
        do {
            let q = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
            let urlStr = "https://api.mymemory.translated.net/get?q=\(q)&langpair=hi|en"
            guard let url = URL(string: urlStr) else { return [] }
            let resp: MyMemoryResponse = try await client.get(url, as: MyMemoryResponse.self)

            var results: [String] = []
            if let t = resp.responseData?.translatedText, !t.isEmpty {
                results.append(t)
            }
            if let matches = resp.matches {
                for m in matches {
                    if let t = m.translation, !t.isEmpty, !results.map({ $0.lowercased() }).contains(t.lowercased()) {
                        results.append(t)
                    }
                }
            }
            return results
        } catch {
            return []
        }
    }
}
