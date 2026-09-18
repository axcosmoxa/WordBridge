# AGENTS.md — WordBridge

## Role
Senior native iOS engineer — Swift 6, SwiftUI, accessibility, Apple system frameworks.
Build native iOS only. No React Native / Flutter / web wrapper.

## Product Overview
Instant English ↔ Hindi word explainer for parents/teachers/students.
Core loop: **See word → 1 action → understand it**. No multi-screen dictionary maze.
- English → Hindi and Hindi → English, auto-detected
- Single word, phrase, sentence, question all handled intelligently
- Context-aware (bank river vs bank money), Explain Simply, Teacher Mode (child-friendly)
- Voice input, TTS pronunciation, Share Extension, clipboard-detected paste
- Offline-first via local cache, history, saved words — no account, no backend

## Deployment
- **iOS 16.0** minimum (iPhone 13/mini/Pro/Max, 14/15/16 families)
- Swift 6, SwiftUI, async/await, Codable
- No iOS 17/18-only APIs without availability check + fallback
- Zero mandatory third-party dependencies

## Architecture
```
SearchView → SearchViewModel → DictionaryService / TranslationService / ContextService
                                     ↓
                              API / Local Cache
HistoryService, CacheService, SpeechService isolated behind protocols.
SwiftUI Views contain NO networking. ViewModels own tasks, cancellation, debounce.
```
Services:
- `DictionaryService` — Free Dictionary API (api.dictionaryapi.dev) + fallback
- `TranslationService` — MyMemory (api.mymemory.translated.net) for en↔hi
- `ContextService` — sentence keyword extraction + contextual gloss
- `SpeechService` — Speech framework wrapper
- `CacheService` — file + UserDefaults, offline-first
- `HistoryService` — local history & saved

Project layout:
```
WordBridge/App/ Core/{Networking,Persistence,Services,Utilities}
           Features/{Home,Search,History,Saved,Settings}
           Shared/{Components,Models} Resources/ Extensions/
ShareExtension/  (text share)
```

## UI Rules
- Minimal, calm, native utility; typography first, whitespace, separators, SF Symbols, semantic colors
- No gradients/cards/illustrations/dashboards/gamification
- Colors: systemBackground, secondarySystemBackground, label, secondaryLabel, tertiaryLabel, separator, systemBlue accent only
- Typography: Dynamic Type throughout; Word largeTitle/title, pron subheadline, meaning title3, body/callout/caption
- Animations: subtle fade only; no bounce
- Haptics: save/copy/voice success only
- Navigation: Home (search+result inline) → History, Saved, Settings lightweight
- Minimum taps: Open → Type → Result. Never force language picker, dictionary picker, result list before meaning.

## Networking Rules
- Use URLSession + async/await, Codable
- Abstraction: UI never knows provider; DictionaryService hide endpoint details
- Free sources: dictionaryapi.dev (English), MyMemory/Wiktionary for en↔hi; verify terms, rate limits, Hindi coverage before use
- Debounce (~300ms), cache-first, cancel obsolete tasks, loading only when needed
- Friendly errors: “Couldn’t find that right now. Check your connection.” + Retry. Prefer cached result over failure. Never show raw HTTP/JSON errors.
- No private API keys embedded. No backend proxy for MVP. No search history sent to server.

## Persistence Rules
- iOS 16: NO SwiftData. Use FileManager JSON + UserDefaults. Keep DTOs separate from storage models.
- Models: `WordEntry` { id, query, language, translation, definition, simpleDefinition, partOfSpeech, pronunciation, phonetic, audioURL, example, exampleTranslation, synonyms, relatedWords, source, createdAt, lastAccessedAt, isSaved }
- History & Saved & Cache stored locally, file `wordbridge_cache.json`, `history.json`, `saved.json` in Application Support.
- Offline: cached entries remain readable, subtle “You’re offline — showing saved information.”

## Privacy Rules
- No login, no account, no cloud sync in MVP
- Do not collect name/email/contacts/location/IDFA
- History/saved/cache stay on device. Do not log queries. Clipboard inspected only on app foreground, not continuously.

## Accessibility Rules
- Dynamic Type, VoiceOver labels/hints, 44pt hit targets, sufficient contrast
- Respect Reduce Motion; no color-only state
- All interactive controls have accessibilityLabel

## Dependency Rules
- Zero unnecessary externals. Apple frameworks only: NaturalLanguage, Speech, AVFoundation/AVFAudio, UniformTypeIdentifiers.
- No ads, analytics, subscriptions.

## Testing Rules
- Verify build after each phase (`xcodebuild` if available, else swift syntax check)
- Phase 1: project + Home + search field builds
- Phase 2: language detection + English lookup + result UI
- Phase 3: Hindi en↔hi + caching
- Phase 4: history + saved
- Phase 5: voice + TTS
- Phase 6: Share Extension on device
- Phase 7: context/sentence, Explain Simply, Teacher Mode
- Phase 8: polish (a11y, dark mode, error, offline)
- Phase 9: Final UX Test 8 scenarios on iPhone 13+

## Feature Workflow (strict)
1. Read AGENTS.md
2. Implement ONE feature only
3. Keep existing UI intact
4. No unnecessary deps
5. Build
6. Test new + regression
7. Report changed files + limitations
8. Next feature only after verification
