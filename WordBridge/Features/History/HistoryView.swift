import SwiftUI

struct HistoryView: View {
    @State private var items: [HistoryItem] = []
    @State private var searchState: SearchState = .idle
    @State private var selectedEntry: WordEntry?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(title: "No words yet.", subtitle: "Words you look up will appear here.", systemImage: "clock")
                } else {
                    List {
                        ForEach(groupedKeys, id: \.self) { key in
                            Section(header: Text(key).font(.caption.weight(.semibold)).foregroundColor(.secondary)) {
                                ForEach(itemsForKey(key)) { item in
                                    Button { Task { await open(item) } } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.query).font(.body).foregroundColor(.primary)
                                            if let p = item.preview { Text(p).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                                        }
                                    }
                                    .swipeActions { Button(role: .destructive) { Task { await delete(item) } } label: { Label("Delete", systemImage: "trash") } }
                                    .accessibilityLabel(item.query)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { Task { await clear() } }.accessibilityLabel("Clear history")
                    }
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in Task { await load() } }
            .sheet(item: $selectedEntry) { entry in
                NavigationStack {
                    ScrollView { ResultViewWithSave(entry: entry).padding() }
                        .navigationTitle(entry.query).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { selectedEntry = nil } } }
                }
            }
        }
    }

    // Grouping by Today/Yesterday
    var groupedKeys: [String] {
        var keys: [String] = []
        for item in items {
            let k = dayKey(for: item.timestamp)
            if !keys.contains(k) { keys.append(k) }
        }
        return keys
    }
    func itemsForKey(_ key: String) -> [HistoryItem] { items.filter { dayKey(for: $0.timestamp) == key } }
    func dayKey(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
    func load() async { items = await HistoryService.shared.history() }
    func delete(_ item: HistoryItem) async { await HistoryService.shared.delete(id: item.id); await load() }
    func clear() async { await HistoryService.shared.clear(); await load() }
    func open(_ item: HistoryItem) async {
        if let cached = await CacheService.shared.cachedEntry(for: item.query) {
            selectedEntry = cached
        } else {
            // fallback create minimal entry
            selectedEntry = WordEntry(query: item.query, language: item.language, definition: item.preview, synonyms: [])
        }
    }
}

extension WordEntry {
    static var dummy: WordEntry { WordEntry(query: "", language: .english, synonyms: []) }
}
extension WordEntry: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(query); hasher.combine(language) }
}
