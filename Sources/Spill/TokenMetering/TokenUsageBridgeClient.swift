import Foundation

struct TokenUsageBridgeClient: Sendable {
    let postEvent: @Sendable (TokenUsageEvent) async throws -> Void

    static let live = loopback()

    static func loopback(port: UInt16 = TokenUsageBridgeServer.defaultPort) -> TokenUsageBridgeClient {
        TokenUsageBridgeClient { event in
            guard let url = URL(string: "http://127.0.0.1:\(port)/v1/usage/events") else {
                throw TokenUsageBridgeClientError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try TokenUsageSanitizer.eventData(event)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TokenUsageBridgeClientError.invalidResponse(-1)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TokenUsageBridgeClientError.invalidResponse(httpResponse.statusCode)
            }
        }
    }
}

enum TokenUsageBridgeClientError: Error, Equatable {
    case invalidURL
    case invalidResponse(Int)
}
