import Foundation

actor ContextService {
    static let shared = ContextService()

    // Minimal contextual glosses for demo/offline. In production would use LLM or local model.
    private let contextMap: [String: [String: (en: String, hi: String)]] = [
        "bank": [
            "river": ("the land beside a river.", "नदी का किनारा"),
            "money": ("a place where money is kept.", "बैंक जहाँ पैसे रखे जाते हैं"),
            "default": ("a bank (financial or river side).", "किनारा / बैंक")
        ],
        "bat": [
            "ball": ("a piece of wood to hit the ball.", "बल्ला"),
            "night": ("a flying mammal active at night.", "चमगादड़"),
            "default": ("bat - animal or sports bat.", "चमगादड़ / बल्ला")
        ],
        "light": [
            "sun": ("sunlight or brightness.", "प्रकाश"),
            "weight": ("not heavy.", "हल्का"),
            "default": ("light.", "प्रकाश / हल्का")
        ]
    ]

    func contextualMeaning(for word: String, in sentence: String) -> (english: String, hindi: String)? {
        let w = word.lowercased()
        let s = sentence.lowercased()
        guard let variants = contextMap[w] else { return nil }
        for (key, val) in variants where key != "default" {
            if s.contains(key) { return (val.en, val.hi) }
        }
        if let d = variants["default"] { return (d.en, d.hi) }
        return nil
    }

    func explainSimply(_ sentence: String, language: WordLanguage) -> (english: String, hindi: String) {
        // Very light simplification: use local heuristics, not pretending to be AI.
        // For MVP, provide fallback simplifications for known textbook sentences.
        let lower = sentence.lowercased()
        if lower.contains("photosynthesis") {
            return (
                "Plants use sunlight to make their food.",
                "पौधे सूर्य के प्रकाश की मदद से अपना भोजन बनाते हैं।"
            )
        }
        if lower.contains("adapt") {
            return (
                "To change so you can live or work well in a new place or situation.",
                "नई जगह या स्थिति के अनुसार खुद को बदलना।"
            )
        }
        // Generic fallback: return trimmed sentence + hint
        let simpleEN = "In simple words: \(sentence)"
        let simpleHI = "सरल शब्दों में: \(sentence)"
        return (simpleEN, simpleHI)
    }

    func teacherExplanation(for word: String, hindi: String?) -> (en: String, hi: String) {
        // Child-friendly short
        let w = word.lowercased()
        switch w {
        case "adapt":
            return ("Adapt means changing yourself so you can live or work well in a new situation.", "अनुकूल होना यानी नई परिस्थिति के अनुसार अपने आप को ढालना।")
        case "resilient":
            return ("Resilient means you can bounce back after something hard happens.", "मज़बूत — मुश्किल के बाद भी फिर से खड़े होना।")
        case "photosynthesis":
            return ("Photosynthesis is how plants make food using sunlight.", "प्रकाश संश्लेषण वह प्रक्रिया है जिससे पौधे धूप से खाना बनाते हैं।")
        default:
            let en = "\(word) — think of it as something you can picture in everyday life."
            let hi = "\(word) — इसे रोज़मर्रा की ज़िंदगी की तरह समझो।"
            return (en, hi)
        }
    }
}
