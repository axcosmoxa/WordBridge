import Foundation
import NaturalLanguage

enum QueryParser {
    static func parse(_ input: String) -> ParsedQuery {
        let original = input
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove common question wrappers for voice input
        let lower = cleaned.lowercased()
        let wrappers = [
            "what does ", "what is the meaning of ", "what is ", "meaning of ",
            "define ", "explain ", "what do you mean by ", "tell me about "
        ]
        for w in wrappers {
            if lower.hasPrefix(w) {
                let start = cleaned.index(cleaned.startIndex, offsetBy: w.count, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
                cleaned = String(cleaned[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?.,!\"'"))
                break
            }
        }
        // Strip trailing ?
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?.,!"))
        if cleaned.isEmpty { cleaned = original.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Detect question vs sentence vs phrase vs single
        let kind: QueryKind
        let words = cleaned.split(separator: " ")
        let isQuestion = original.contains("?") || lower.hasPrefix("what") || lower.hasPrefix("how") || lower.hasPrefix("why")
        let isComparison = lower.contains("difference between") || (lower.contains(" vs ") || lower.contains(" versus "))
        if isComparison {
            // extract the two words around difference between ... and ...
            kind = .question
        } else if words.count == 1 && !cleaned.contains(" ") {
            kind = .singleWord
        } else if words.count <= 4 && !cleaned.contains(".") && !isQuestion {
            // phrase like "take for granted"
            kind = .phrase
        } else if isQuestion || cleaned.count > 40 || cleaned.contains(".") {
            kind = .sentence
        } else if words.count > 1 {
            kind = .phrase
        } else {
            kind = .singleWord
        }

        // Target word extraction
        let targetWord: String
        if kind == .singleWord {
            targetWord = cleaned
        } else if kind == .sentence || kind == .question {
            targetWord = extractKeyword(from: cleaned) ?? cleaned
        } else {
            targetWord = cleaned
        }

        let language = LanguageDetector.detect(cleaned)
        let keywords = extractKeywords(from: cleaned)

        return ParsedQuery(
            original: original,
            cleaned: cleaned,
            kind: kind,
            detectedLanguage: language,
            targetWord: targetWord,
            isComparison: isComparison,
            keywords: keywords
        )
    }

    static func extractKeyword(from sentence: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var candidates: [(String, NLTag)] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag {
                let word = String(sentence[range]).lowercased()
                if word.count > 2 && !stopwords.contains(word) {
                    candidates.append((word, tag))
                }
            }
            return true
        }
        // Prefer nouns/verbs/adjectives
        let preferred = candidates.filter { $0.1 == .noun || $0.1 == .verb || $0.1 == .adjective }
        if let first = preferred.first?.0 { return first }
        return candidates.first?.0
    }

    static func extractKeywords(from sentence: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var words: [String] = []
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let w = String(sentence[range])
            if w.count > 2 && !stopwords.contains(w.lowercased()) {
                words.append(w.lowercased())
            }
            return true
        }
        // Dedupe preserve order
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    private static let stopwords: Set<String> = [
        "the","is","a","an","are","was","were","be","been","being","to","of","in","on","at","for","with","by","from","about","into","through","during","before","after","above","below","up","down","and","or","but","if","then","so","very","can","will","just","should","could","what","does","do","did","mean","means","meaning","explain","define"
    ]
}
