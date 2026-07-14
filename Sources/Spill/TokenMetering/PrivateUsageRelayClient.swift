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
        deviceName: String?,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential

    func uploadBuckets(
        credential: PrivateUsageDeviceCredential,
        buckets: [PrivateUsageEncryptedBucket],
        sharedSummaries: [PrivateUsageSharedSummary],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse

    func checkDeviceConnection(
        credential: PrivateUsageDeviceCredential
    ) async throws
}

struct PrivateUsageUnavailableRelayClient: PrivateUsageRelayClienting {
    func exchangeDeviceGrant(
        grantCode: String,
        installID: String,
        deviceName: String?,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential {
        throw PrivateUsageUploadError.invalidRelayURL
    }

    func uploadBuckets(
        credential: PrivateUsageDeviceCredential,
        buckets: [PrivateUsageEncryptedBucket],
        sharedSummaries: [PrivateUsageSharedSummary],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse {
        throw PrivateUsageUploadError.invalidRelayURL
    }

    func checkDeviceConnection(
        credential: PrivateUsageDeviceCredential
    ) async throws {
        throw PrivateUsageUploadError.invalidRelayURL
    }
}

final class PrivateUsageRelayClient: PrivateUsageRelayClienting, @unchecked Sendable {
    private let relayURL: URL
    private let transport: PrivateUsageRelayTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        relayURL: URL,
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
        deviceName: String?,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential {
        let requestBody = PrivateUsageGrantExchangeRequest(
            grantCode: grantCode,
            installID: installID,
            deviceName: deviceName,
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
        sharedSummaries: [PrivateUsageSharedSummary],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse {
        var request = try makeJSONRequest(path: "upload-buckets")
        request.setValue("Bearer \(credential.authorizationToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(
            PrivateUsageUploadBucketsRequest(
                keyEnvelopes: keyEnvelopes,
                buckets: buckets,
                sharedSummaries: sharedSummaries
            )
        )

        return try await send(request)
    }

    func checkDeviceConnection(
        credential: PrivateUsageDeviceCredential
    ) async throws {
        var request = try makeJSONRequest(path: "check-device")
        request.setValue("Bearer \(credential.authorizationToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode([String: String]())

        let _: PrivateUsageDeviceCheckResponse = try await send(request)
    }

}

private extension PrivateUsageRelayClient {
    private func makeJSONRequest(path: String) throws -> URLRequest {
        let endpoint = relayURL.appendingPathComponent(path)
        guard PrivateUsageRelayEndpoint.isSafeRelayURL(endpoint) else {
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
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.relayTransportFailed
        }

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
