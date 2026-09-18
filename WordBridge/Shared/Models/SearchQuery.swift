import Foundation

struct ParsedQuery: Sendable, Equatable {
    var original: String
    var cleaned: String
    var kind: QueryKind
    var detectedLanguage: WordLanguage
    var targetWord: String
    var isComparison: Bool
    var keywords: [String]
}

enum SearchState: Equatable, Sendable {
    case idle
    case loading
    case success(WordEntry)
    case failure(String)
    case offline(WordEntry)
}
