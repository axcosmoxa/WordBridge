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
                // English word or phrase: use dictionary + translate to Hindi concurrently
                let baseWord = parsed.targetWord.isEmpty ? parsed.cleaned : parsed.targetWord
                let queryCopyForTrans = parsed.kind == .sentence || parsed.kind == .phrase ? parsed.original.trimmed : baseWord

                async let dictTask = try? DictionaryService.shared.lookupEnglish(baseWord)
                async let hiQueryTask = TranslationService.shared.englishToHindi(queryCopyForTrans)

                let (dictOpt, hiQueryOpt) = await (dictTask, hiQueryTask)

                var e: WordEntry
                if let dict = dictOpt {
                    e = dict
                    if let h = hiQueryOpt { e.translation = h }
                } else if let h = hiQueryOpt {
                    let syns = await DictionaryService.shared.lookupSynonyms(baseWord)
                    e = WordEntry(query: baseWord, language: .english, translation: h, definition: h, simpleDefinition: h, synonyms: syns, source: "mymemory-fallback")
                } else {
                    throw APIError.notFound
                }

                // If phrase/sentence, keep original query
                if parsed.kind == .sentence || parsed.kind == .phrase {
                    e.query = queryCopyForTrans
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

                if e.simpleDefinition == nil { e.simpleDefinition = e.definition }
                // Show immediately for perceived speed
                self.state = .success(e)
                self.recentEntry = e

                // Concurrent secondary translations (definition, example)
                let defCopy = e.definition
                let exCopy = e.example
                async let hiDef: String? = {
                    if let def = defCopy { return await TranslationService.shared.englishToHindi(def) } else { return nil }
                }()
                async let hiExample: String? = {
                    if let ex = exCopy { return await TranslationService.shared.englishToHindi(ex) } else { return nil }
                }()

                let (hd, he) = await (hiDef, hiExample)
                if e.translation == nil, let hd = hd {
                    e.translation = hd
                }
                e.exampleTranslation = he
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
                async let dictTask = try? DictionaryService.shared.lookupEnglish(parsed.cleaned)
                async let hiTask = TranslationService.shared.englishToHindi(parsed.cleaned)

                let (dictOpt, hiOpt) = await (dictTask, hiTask)

                var e: WordEntry
                if let dict = dictOpt {
                    e = dict
                    if let h = hiOpt { e.translation = h }
                } else {
                    let syns = await DictionaryService.shared.lookupSynonyms(parsed.cleaned)
                    e = WordEntry(query: parsed.cleaned, language: .english, translation: hiOpt, definition: hiOpt ?? parsed.cleaned, synonyms: syns, source: "fallback")
                }
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
