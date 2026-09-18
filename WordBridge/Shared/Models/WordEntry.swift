import Foundation

enum WordLanguage: String, Codable, Sendable {
    case english
    case hindi
    case unknown
}

enum QueryKind: String, Codable, Sendable {
    case singleWord
    case phrase
    case sentence
    case question
}

struct WordEntry: Identifiable, Codable, Equatable, Sendable {
    var id: String { query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + "_" + language.rawValue }
    var query: String
    var language: WordLanguage
    var translation: String?
    var definition: String?
    var simpleDefinition: String?
    var partOfSpeech: String?
    var pronunciation: String?
    var phonetic: String?
    var audioURL: String?
    var example: String?
    var exampleTranslation: String?
    var synonyms: [String]
    var relatedWords: [String]
    var source: String?
    var createdAt: Date
    var lastAccessedAt: Date
    var isSaved: Bool

    // Context / teacher fields
    var contextualMeaning: String?
    var contextualHindi: String?
    var explainSimplyEnglish: String?
    var explainSimplyHindi: String?
    var teacherExplanation: String?
    var teacherExplanationHindi: String?

    init(
        query: String,
        language: WordLanguage,
        translation: String? = nil,
        definition: String? = nil,
        simpleDefinition: String? = nil,
        partOfSpeech: String? = nil,
        pronunciation: String? = nil,
        phonetic: String? = nil,
        audioURL: String? = nil,
        example: String? = nil,
        exampleTranslation: String? = nil,
        synonyms: [String] = [],
        relatedWords: [String] = [],
        source: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isSaved: Bool = false,
        contextualMeaning: String? = nil,
        contextualHindi: String? = nil,
        explainSimplyEnglish: String? = nil,
        explainSimplyHindi: String? = nil,
        teacherExplanation: String? = nil,
        teacherExplanationHindi: String? = nil
    ) {
        self.query = query
        self.language = language
        self.translation = translation
        self.definition = definition
        self.simpleDefinition = simpleDefinition
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        self.phonetic = phonetic
        self.audioURL = audioURL
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.synonyms = synonyms
        self.relatedWords = relatedWords
        self.source = source
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isSaved = isSaved
        self.contextualMeaning = contextualMeaning
        self.contextualHindi = contextualHindi
        self.explainSimplyEnglish = explainSimplyEnglish
        self.explainSimplyHindi = explainSimplyHindi
        self.teacherExplanation = teacherExplanation
        self.teacherExplanationHindi = teacherExplanationHindi
    }
}

struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var query: String
    var language: WordLanguage
    var timestamp: Date
    var preview: String?
}

struct SavedWord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var query: String
    var language: WordLanguage
    var entry: WordEntry
    var savedAt: Date
}
