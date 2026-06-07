import Foundation

struct PrivateUsageRelayTransport: Sendable {
    var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let live = PrivateUsageRelayTransport { request in
        try await URLSession.shared.data(for: request)
    }
}

protocol PrivateUsageRelayClienting: Sendable {
    func exchangeDeviceGrant(
        grantCode: String,
        installID: String,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential

    func uploadBuckets(
        credential: PrivateUsageDeviceCredential,
        buckets: [PrivateUsageEncryptedBucket],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse
}

final class PrivateUsageRelayClient: PrivateUsageRelayClienting, @unchecked Sendable {
    static let defaultRelayURL = URL(
        string: "https://otggbleddlmzamgpqxjm.supabase.co/functions/v1/private-usage-relay"
    )!

    private let relayURL: URL
    private let transport: PrivateUsageRelayTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        relayURL: URL = PrivateUsageRelayClient.defaultRelayURL,
        transport: PrivateUsageRelayTransport = .live
    ) {
        self.relayURL = relayURL
        self.transport = transport
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func exchangeDeviceGrant(
        grantCode: String,
        installID: String,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential {
        let requestBody = PrivateUsageGrantExchangeRequest(
            grantCode: grantCode,
            installID: installID,
            deviceKeyFingerprint: deviceKeyFingerprint
        )
        var request = try makeJSONRequest(path: "exchange-device-grant")
        request.httpBody = try encoder.encode(requestBody)

        let response: PrivateUsageGrantExchangeResponse = try await send(request)
        return PrivateUsageDeviceCredential(
            deviceID: response.deviceID,
            credential: response.credential,
            tokenType: response.tokenType,
            createdAt: Date()
        )
    }

    func uploadBuckets(
        credential: PrivateUsageDeviceCredential,
        buckets: [PrivateUsageEncryptedBucket],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse {
        var request = try makeJSONRequest(path: "upload-buckets")
        request.setValue("Bearer \(credential.authorizationToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(
            PrivateUsageUploadBucketsRequest(
                keyEnvelopes: keyEnvelopes,
                buckets: buckets
            )
        )

        return try await send(request)
    }

    private func makeJSONRequest(path: String) throws -> URLRequest {
        let endpoint = relayURL.appendingPathComponent(path)
        guard endpoint.scheme == "https" || endpoint.host == "localhost" || endpoint.host == "127.0.0.1" else {
            throw PrivateUsageUploadError.invalidRelayURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await transport.data(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrivateUsageUploadError.invalidRelayResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PrivateUsageUploadError.relay(
                status: httpResponse.statusCode,
                reason: Self.safeErrorReason(from: data)
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw PrivateUsageUploadError.invalidRelayResponse
        }
    }

    private static func safeErrorReason(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reason = object["error"] as? String,
              reason.range(of: #"^[a-z][a-z0-9_]{1,80}$"#, options: .regularExpression) != nil
        else {
            return nil
        }

        return reason
    }
}
