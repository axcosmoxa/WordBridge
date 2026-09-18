import Foundation

// https://api.dictionaryapi.dev/api/v2/entries/en/<word>
struct DictionaryEntryDTO: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [PhoneticDTO]?
    let meanings: [MeaningDTO]?
}

struct PhoneticDTO: Codable {
    let text: String?
    let audio: String?
}

struct MeaningDTO: Codable {
    let partOfSpeech: String?
    let definitions: [DefinitionDTO]?
    let synonyms: [String]?
    let antonyms: [String]?
}

struct DefinitionDTO: Codable {
    let definition: String?
    let example: String?
    let synonyms: [String]?
}

// MyMemory translation
struct MyMemoryResponse: Codable {
    let responseData: MyMemoryData?
    let matches: [MyMemoryMatch]?

    struct MyMemoryData: Codable {
        let translatedText: String?
    }
    struct MyMemoryMatch: Codable {
        let translation: String?
        let quality: Int?
    }
}
