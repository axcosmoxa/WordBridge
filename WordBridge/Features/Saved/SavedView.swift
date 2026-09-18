import SwiftUI

struct SavedView: View {
    @State private var saved: [SavedWord] = []
    @State private var selected: WordEntry?

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty {
                    EmptyStateView(title: "No saved words yet.", subtitle: "Tap ☆ on a word to save it.", systemImage: "star")
                } else {
                    List {
                        ForEach(saved) { w in
                            Button { selected = w.entry } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(w.query).font(.body).foregroundColor(.primary)
                                    if let t = w.entry.translation { Text(t).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                                    else if let d = w.entry.definition { Text(d).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                                }
                            }
                            .swipeActions { Button(role: .destructive) { Task { await unsave(w) } } label: { Label("Unsave", systemImage: "trash") } }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in Task { await load() } }
            .sheet(item: $selected) { entry in
                NavigationStack {
                    ScrollView { ResultViewWithSave(entry: entry).padding() }
                        .navigationTitle(entry.query).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { selected = nil } } }
                }
            }
        }
    }

    func load() async { saved = await HistoryService.shared.savedEntries() }
    func unsave(_ w: SavedWord) async { await HistoryService.shared.unsave(query: w.query); await load() }
}
