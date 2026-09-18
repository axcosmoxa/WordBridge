import SwiftUI
import UIKit

@main
struct WordBridgeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.checkClipboard()
                }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var teacherMode = UserDefaults.standard.bool(forKey: "teacherMode")
    @Published var clipboardText: String?
    @Published var isOffline = false
    @Published var pendingShareText: String?

    func checkClipboard() async {
        guard UIPasteboard.general.hasStrings else { return }
        if let s = UIPasteboard.general.string?.trimmed, !s.isEmpty, s.count < 200 {
            // Only show if not too long and looks like word/sentence
            clipboardText = s
        }
    }

    func setTeacherMode(_ v: Bool) {
        teacherMode = v
        UserDefaults.standard.set(v, forKey: "teacherMode")
    }

    func consumeClipboard() -> String? {
        let t = clipboardText
        clipboardText = nil
        return t
    }
}
