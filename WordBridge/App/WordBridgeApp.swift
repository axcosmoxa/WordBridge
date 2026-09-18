import SwiftUI
import UIKit
import WidgetKit

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
                .onOpenURL { url in
                    if url.scheme == "wordbridge" {
                        if url.host == "listen" {
                            appState.pendingListen = true
                        } else if url.host == "open" {
                            // no-op
                        } else if url.host == "lookup", let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                                  let text = comps.queryItems?.first(where: { $0.name == "text" })?.value {
                            appState.pendingShareText = text
                        }
                    }
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
    @Published var pendingListen = false

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

    func updateWidget(lastQuery: String, translation: String?) {
        // App Group defaults
        if let d = UserDefaults(suiteName: "group.com.wordbridge.app") {
            d.set(lastQuery, forKey: "widget_lastQuery")
            d.set(translation, forKey: "widget_lastTranslation")
        }
        // File fallback for widget
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wordbridge.app")?.appendingPathComponent("WidgetCache.json") {
            let dict = ["q": lastQuery, "t": translation ?? ""]
            if let data = try? JSONEncoder().encode(dict) {
                try? data.write(to: url)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
