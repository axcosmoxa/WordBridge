import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SearchViewModel()
    @StateObject private var speech = SpeechService()
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    SearchField(
                        text: $vm.query,
                        onSubmit: { vm.submit() },
                        onMic: { Task { await handleMic() } },
                        isRecording: speech.isRecording,
                        language: vm.detectedLanguage
                    )
                    .onChange(of: vm.query) { new in vm.onQueryChange(new) }

                    if speech.isRecording {
                        HStack(spacing: 8) {
                            ProgressView().tint(.red)
                            Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                                .font(.callout).foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: speech.transcript) { t in
                            if !t.isEmpty { vm.query = t }
                        }
                    }

                    // Clipboard banner - only on foreground, not continuously monitored
                    if let clip = appState.clipboardText, vm.query.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copied text detected").font(.caption.weight(.semibold)).foregroundColor(.secondary).textCase(.uppercase)
                                Text("\"\(clip)\"").font(.callout).lineLimit(2)
                            }
                            Spacer()
                            Button("Explain") {
                                vm.query = clip
                                Task { await vm.performSearch(clip) }
                                appState.clipboardText = nil
                                Haptics.light()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .accessibilityLabel("Explain copied text")
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
                    }

                    // Offline banner
                    if vm.isOfflineBanner {
                        Text("You’re offline — showing saved information.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("You are offline")
                    }

                    // Result states
                    switch vm.state {
                    case .idle:
                        recentHistory
                    case .loading:
                        HStack { ProgressView(); Text("Looking up…").font(.callout).foregroundColor(.secondary) }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    case .success(let entry), .offline(let entry):
                        ResultViewContainer(entry: entry)
                    case .failure(let msg):
                        VStack(spacing: 12) {
                            Text(msg).font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
                            Button("Retry") { vm.submit() }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Retry search")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    if case .idle = vm.state {
                        if vm.query.isEmpty {
                            EmptyStateView(title: "What would you like to understand?", subtitle: "Type English or हिंदी word, phrase or sentence.", systemImage: "text.magnifyingglass")
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("WordBridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: Binding(
                        get: { appState.teacherMode },
                        set: { appState.setTeacherMode($0) }
                    )) {
                        Text("Teacher Mode")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Teacher Mode")
                }
            }
            .onAppear {
                if let pending = appState.pendingShareText {
                    vm.query = pending
                    Task { await vm.performSearch(pending) }
                    appState.pendingShareText = nil
                }
                if appState.pendingListen {
                    appState.pendingListen = false
                    Task { await handleMic() }
                }
            }
            .onChange(of: appState.pendingListen) { v in
                if v {
                    appState.pendingListen = false
                    Task { await handleMic() }
                }
            }
            .onChange(of: appState.pendingShareText) { v in
                if let t = v {
                    vm.query = t
                    Task { await vm.performSearch(t) }
                    appState.pendingShareText = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await appState.checkClipboard() }
                if appState.pendingListen {
                    appState.pendingListen = false
                    Task { await handleMic() }
                }
                if let t = appState.pendingShareText {
                    vm.query = t
                    Task { await vm.performSearch(t) }
                    appState.pendingShareText = nil
                }
            }
            .onChange(of: speech.isRecording) { recording in
                if !recording, !speech.transcript.trimmed.isEmpty {
                    vm.query = speech.transcript
                    Task { await vm.performSearch(speech.transcript) }
                    Haptics.success()
                }
            }
            .onChange(of: speech.transcript) { t in
                if !speech.isRecording, !t.trimmed.isEmpty {
                    // widget hands-free: already handled above
                }
            }
        }
        .alert("Microphone Access", isPresented: $showPermissionAlert) {
            Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enable microphone and speech recognition to use voice search. You can still type.") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WordBridge").font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
            Text("English ↔ हिंदी").font(.subheadline).foregroundColor(.secondary)
            Text("Meaning · Examples · Vocabulary").font(.caption).foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var recentHistory: some View {
        HistoryInlineView { item in vm.loadHistoryEntry(item) }
    }

    @ViewBuilder
    func ResultViewContainer(entry: WordEntry) -> some View {
        ResultViewWithSave(entry: entry)
    }

    private func handleMic() async {
        if speech.isRecording {
            speech.stopRecording()
            if !speech.transcript.isEmpty {
                vm.query = speech.transcript
                await vm.performSearch(speech.transcript)
            }
            Haptics.success()
        } else {
            let ok = await speech.startRecording()
            if !ok { showPermissionAlert = true } else { Haptics.light() }
        }
    }
}

// Inline recent history to avoid navigation
struct HistoryInlineView: View {
    var onSelect: (HistoryItem) -> Void
    @State private var items: [HistoryItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !items.isEmpty {
                Text("Recent").font(.caption.weight(.semibold)).foregroundColor(.secondary).textCase(.uppercase)
                ForEach(items.prefix(5)) { item in
                    Button { onSelect(item) } label: {
                        HStack {
                            Text(item.query).font(.body).foregroundColor(.primary).lineLimit(1)
                            Spacer()
                            Text(item.language == .hindi ? "HI" : "EN").font(.caption2).foregroundColor(.secondary).padding(4).background(Color(.secondarySystemBackground)).clipShape(Capsule())
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(item.query)")
                    Divider()
                }
            }
        }
        .task { items = await HistoryService.shared.history() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { items = await HistoryService.shared.history() }
        }
    }
}

struct ResultViewWithSave: View {
    var entry: WordEntry
    @EnvironmentObject var appState: AppState
    @State private var isSaved = false
    @State private var showCopied = false

    var body: some View {
        ResultView(entry: entry, teacherMode: appState.teacherMode, isSaved: isSaved, onSave: {
            Task { isSaved = await HistoryService.shared.toggleSaved(entry) }
        }, onCopy: {
            UIPasteboard.general.string = "\(entry.query): \(entry.translation ?? entry.definition ?? "")"
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) { showCopied = false }
        })
        .overlay(alignment: .topTrailing) {
            if showCopied {
                Text("Copied").font(.caption).padding(6).background(Color(.secondarySystemBackground)).clipShape(Capsule()).padding(8)
            }
        }
        .task { isSaved = await HistoryService.shared.isSaved(query: entry.query) }
    }
}
