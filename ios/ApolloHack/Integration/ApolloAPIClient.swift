import Foundation

/// Explicit local-backend transport. It never silently falls back to another portfolio.
@MainActor
final class ApolloAPIClient {
    let baseURL: URL
    private let session: URLSession
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    func request(_ method: String, _ path: String, body: [String: Any]? = nil, acceptedStatuses: Set<Int> = [], timeout: TimeInterval = 12) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: baseURL),
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else {
            throw ApolloAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        guard (1...90).contains(timeout) else { throw ApolloAPIError.invalidResponse }
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ApolloAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) || acceptedStatuses.contains(http.statusCode) else {
            let message: String
            if let error = value["error"] as? [String: Any] {
                message = error["message"] as? String ?? "The local paper service could not complete this request."
            } else {
                message = value["message"] as? String ?? "The local paper service could not complete this request (\(http.statusCode))."
            }
            throw ApolloAPIError.rejected(message)
        }
        return value
    }
}

enum ApolloAPIError: LocalizedError {
    case invalidResponse, rejected(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The local Apollo service returned an unreadable response. Your saved paper portfolio was not replaced."
        case .rejected(let message): return message
        }
    }
}
