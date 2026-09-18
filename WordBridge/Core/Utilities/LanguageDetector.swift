import Foundation
import NaturalLanguage

enum LanguageDetector {
    static func detect(_ text: String) -> WordLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        // Devanagari range check - fast path for Hindi
        let hasDevanagari = trimmed.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
        if hasDevanagari { return .hindi }
        // Use NLLanguageRecognizer for script detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            switch lang {
            case .hindi: return .hindi
            case .english: return .english
            default:
                // fallback: if latin script assume english
                return .english
            }
        }
        // Heuristic: contains only latin + common punctuation => english
        return .english
    }
}
