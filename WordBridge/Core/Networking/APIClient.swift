import Foundation

enum APIError: LocalizedError, Equatable {
    case notFound
    case network
    case decoding
    case unknown

    var userMessage: String {
        switch self {
        case .notFound: return "Couldn’t find that right now. Check the spelling and try again."
        case .network: return "Couldn’t find that right now. Check your connection and try again."
        case .decoding: return "Couldn’t find that right now. Try another word."
        case .unknown: return "Couldn’t find that right now. Check your connection and try again."
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let session: URLSession

    init(session: URLSession = .shared) {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.network }
            if http.statusCode == 404 { throw APIError.notFound }
            guard (200...299).contains(http.statusCode) else { throw APIError.network }
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let e as APIError {
            throw e
        } catch is DecodingError {
            throw APIError.decoding
        } catch {
            // URLError etc
            throw APIError.network
        }
    }

    func getData(from url: URL) async throws -> Data {
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.network
        }
        return data
    }
}
