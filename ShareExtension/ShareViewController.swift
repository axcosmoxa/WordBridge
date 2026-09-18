import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    private var sharedText: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WordBridge"
        // Extract text immediately
        extractText { [weak self] text in
            self?.sharedText = text
            DispatchQueue.main.async {
                self?.textView.text = text
                self?.placeholder = "Word to explain…"
            }
        }
    }

    override func isContentValid() -> Bool { !(sharedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }

    override func didSelectPost() {
        guard let text = sharedText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        // Save to app group for main app to pick up
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wordbridge.app") {
            let dir = groupURL.appendingPathComponent("WordBridge", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("pending_share.json")
            let payload = ["text": text, "date": ISO8601DateFormatter().string(from: Date())] as [String: String]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                try? data.write(to: file)
            }
        }
        // Also try open app via custom URL
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "wordbridge://lookup?text=\(encoded)") {
            // Use extensionContext openURL
            extensionContext?.open(url, completionHandler: { _ in
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
        } else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! { [] }

    private func extractText(completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { completion(nil); return }
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                        if let s = data as? String { completion(s); return }
                        if let url = data as? URL { completion(url.absoluteString); return }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        if let s = data as? String { completion(s); return }
                        if let u = data as? URL { completion(u.absoluteString); return }
                    }
                    return
                }
            }
        }
        completion(nil)
    }
}
