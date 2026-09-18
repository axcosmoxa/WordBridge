import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("teacherMode") private var teacherModeStorage = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Preferences")) {
                    Toggle("Teacher Mode", isOn: Binding(get: { appState.teacherMode }, set: { appState.setTeacherMode($0) }))
                        .accessibilityLabel("Teacher Mode toggle")
                    Text("Shows child-friendly explanations.").font(.caption).foregroundColor(.secondary)
                }
                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WordBridge").font(.headline)
                        Text("Instant English ↔ हिंदी word explainer for study time.").font(.caption).foregroundColor(.secondary)
                        Text("No account. No tracking. All history stays on your device.").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section(header: Text("Data")) {
                    Button("Clear Cache") {
                        // cache clear is file delete; simplified
                        Task { await ClearHelper.clearCache() }
                    }
                    .foregroundColor(.red)
                }
                Section(header: Text("Privacy")) {
                    Text("Searches are not sent to our servers. Dictionary lookups use public APIs (dictionaryapi.dev, MyMemory) without personal data. Clipboard is checked only when you open the app.").font(.caption).foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }
}

enum ClearHelper {
    static func clearCache() async {
        // Keep implementation simple: overwrite with empty
        await PersistenceStore.shared.save([String: WordEntry](), to: "wordbridge_cache.json")
    }
}
