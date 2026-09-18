import Foundation
import Network
import WidgetKit

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var state: SearchState = .idle
    @Published var detectedLanguage: WordLanguage = .unknown
    @Published var isOfflineBanner = false
    @Published var recentEntry: WordEntry?

    private var debounceTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private let monitor = NWPathMonitor()
    private var isOffline = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            DispatchQueue.main.async { [weak self] in
                self?.isOffline = offline
                self?.isOfflineBanner = offline
            }
        }
        monitor.start(queue: DispatchQueue.main)
    }

    deinit { monitor.cancel() }

    func onQueryChange(_ new: String) {
        detectedLanguage = LanguageDetector.detect(new)
        debounceTask?.cancel()
        guard !new.trimmed.isEmpty else { state = .idle; return }
        // debounce 320ms, but not for empty
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(new, isDebounced: true)
        }
    }

    func submit() {
        debounceTask?.cancel()
        Task { await performSearch(query, isDebounced: false) }
    }

    func performSearch(_ text: String, isDebounced: Bool = false) async {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { state = .idle; return }
        // For debounce, only auto-search if length >2 to avoid spamming single char
        if isDebounced && trimmed.count < 3 { return }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            let parsed = QueryParser.parse(trimmed)
            self.detectedLanguage = parsed.detectedLanguage

            // Cache-first
            var cached: WordEntry? = await CacheService.shared.cachedEntry(for: parsed.targetWord)
            if cached == nil {
                cached = await CacheService.shared.cachedEntry(for: trimmed)
            }
            if let cached = cached {
                // Determine if we need to enrich cache with translation still missing?
                self.state = .success(cached)
                self.recentEntry = cached
                // Also add to history
                await HistoryService.shared.add(cached)
                // If offline, show offline state but still success
                if self.isOffline { self.state = .offline(cached) }
                // If cached entry already has translation, return. Otherwise try network if online
                if !self.isOffline && cached.translation == nil && parsed.detectedLanguage == .english {
                    await self.fetchAndUpdate(parsed: parsed, cached: cached)
                }
                return
            }
            // Try network even if monitor says offline — let URLSession report real error
            await self.fetchAndUpdate(parsed: parsed, cached: nil)
        }
        await searchTask?.value
    }

    private func fetchAndUpdate(parsed: ParsedQuery, cached: WordEntry?) async {
        do {
            let entry: WordEntry
            switch parsed.detectedLanguage {
            case .english:
                // English word or phrase: use dictionary + translate to Hindi
                let baseWord = parsed.targetWord.isEmpty ? parsed.cleaned : parsed.targetWord
                var e: WordEntry
                do {
                    e = try await DictionaryService.shared.lookupEnglish(baseWord)
                } catch let err as APIError where err == .notFound || err == .network {
                    // Fallback: create minimal entry from translation so user still gets Hindi even if dictionary is down
                    let hi = await TranslationService.shared.englishToHindi(baseWord)
                    if let hi = hi {
                        e = WordEntry(query: baseWord, language: .english, translation: hi, definition: hi, simpleDefinition: hi, synonyms: [], source: "mymemory-fallback")
                    } else {
                        throw err
                    }
                }
                // If phrase/sentence, keep original query
                if parsed.kind == .sentence || parsed.kind == .phrase {
                    e.query = parsed.original.trimmed
                    // Context
                    if let kw = QueryParser.extractKeyword(from: parsed.cleaned) {
                        if let ctx = await ContextService.shared.contextualMeaning(for: kw, in: parsed.cleaned) {
                            e.contextualMeaning = ctx.english
                            e.contextualHindi = ctx.hindi
                        }
                    }
                    let simple = await ContextService.shared.explainSimply(parsed.cleaned, language: .english)
                    e.explainSimplyEnglish = simple.english
                    e.explainSimplyHindi = simple.hindi
                    let teacher = await ContextService.shared.teacherExplanation(for: parsed.targetWord, hindi: nil)
                    e.teacherExplanation = teacher.en
                    e.teacherExplanationHindi = teacher.hi
                } else {
                    e.query = baseWord
                }
                // Fast path: show definition immediately, enrich Hindi concurrently
                var fastEntry = e
                if fastEntry.simpleDefinition == nil { fastEntry.simpleDefinition = fastEntry.definition }
                // Show immediately for perceived speed
                self.state = .success(fastEntry)
                self.recentEntry = fastEntry
                // Concurrent translation (much faster than sequential) — capture copies for Swift 6
                let queryCopy = e.query
                let defCopy = e.definition
                let exCopy = e.example
                async let hiQuery = TranslationService.shared.englishToHindi(queryCopy)
                async let hiDef: String? = {
                    if let def = defCopy { return await TranslationService.shared.englishToHindi(def) } else { return nil }
                }()
                async let hiExample: String? = {
                    if let ex = exCopy { return await TranslationService.shared.englishToHindi(ex) } else { return nil }
                }()
                let (hq, hd, he) = await (hiQuery, hiDef, hiExample)
                if let hi = hq {
                    e.translation = hi
                } else if let hd = hd {
                    e.translation = hd
                }
                e.exampleTranslation = he
                // Fill simpleDefinition if missing
                if e.simpleDefinition == nil { e.simpleDefinition = e.definition }
                entry = e
            case .hindi:
                // Hindi -> English
                let translations = await TranslationService.shared.hindiToEnglish(parsed.cleaned)
                let def = translations.first ?? parsed.cleaned
                let entryH = WordEntry(
                    query: parsed.cleaned,
                    language: .hindi,
                    translation: translations.joined(separator: " · "),
                    definition: def,
                    simpleDefinition: def,
                    partOfSpeech: nil,
                    pronunciation: nil,
                    synonyms: Array(translations.dropFirst().prefix(4)),
                    source: "mymemory"
                )
                var e = entryH
                let teacher = await ContextService.shared.teacherExplanation(for: parsed.cleaned, hindi: entryH.translation)
                e.teacherExplanation = teacher.en
                e.teacherExplanationHindi = teacher.hi
                entry = e
            case .unknown:
                // fallback english
                var e: WordEntry
                do {
                    e = try await DictionaryService.shared.lookupEnglish(parsed.cleaned)
                } catch {
                    let hi = await TranslationService.shared.englishToHindi(parsed.cleaned)
                    e = WordEntry(query: parsed.cleaned, language: .english, translation: hi, definition: hi ?? parsed.cleaned, synonyms: [], source: "fallback")
                }
                e.translation = await TranslationService.shared.englishToHindi(parsed.cleaned) ?? e.translation
                entry = e
            }
            await CacheService.shared.store(entry)
            await HistoryService.shared.add(entry)
            state = .success(entry)
            recentEntry = entry
            // Update widget (App Group) for mic widget
            if let d = UserDefaults(suiteName: "group.com.wordbridge.app") {
                d.set(entry.query, forKey: "widget_lastQuery")
                d.set(entry.translation ?? entry.definition, forKey: "widget_lastTranslation")
            }
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wordbridge.app")?.appendingPathComponent("WidgetCache.json") {
                let dict = ["q": entry.query, "t": entry.translation ?? entry.definition ?? ""]
                if let data = try? JSONEncoder().encode(dict) {
                    try? data.write(to: url)
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch let err as APIError {
            // Prefer cached fallback
            if let c = cached {
                state = .offline(c)
            } else {
                state = .failure(err.userMessage)
            }
        } catch {
            state = .failure(APIError.network.userMessage)
        }
    }

    func loadHistoryEntry(_ item: HistoryItem) {
        query = item.query
        Task { await performSearch(item.query) }
    }

    func loadSaved(_ w: SavedWord) {
        query = w.query
        state = .success(w.entry)
        detectedLanguage = w.language
    }
}
