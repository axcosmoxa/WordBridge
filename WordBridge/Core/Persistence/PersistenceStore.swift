import Foundation

actor PersistenceStore {
    static let shared = PersistenceStore()

    private var baseURL: URL {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WordBridge", isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func fileURL(_ name: String) -> URL { baseURL.appendingPathComponent(name) }

    func save<T: Codable>(_ value: T, to file: String) {
        let url = fileURL(file)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load<T: Codable>(_ type: T.Type, from file: String) -> T? {
        let url = fileURL(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // App Group variant for Share Extension
    private var sharedBaseURL: URL? {
        // Use app group if available, fallback to baseURL
        if let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wordbridge.app") {
            let u = g.appendingPathComponent("WordBridge", isDirectory: true)
            try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
            return u
        }
        return nil
    }

    func saveShared<T: Codable>(_ value: T, to file: String) {
        let url = (sharedBaseURL ?? baseURL).appendingPathComponent(file)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
        // also save to main
        save(value, to: file)
    }
}
