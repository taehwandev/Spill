import Foundation
import XCTest
@testable import Spill

final class PrivateUsageWebConnectionTests: XCTestCase {
    func testConfiguredOriginUsesMoruWebRoutes() throws {
        let configuration = [PrivateUsageWebConnection.webURLInfoDictionaryKey: "https://getmoru.com/"]
        let connection = try XCTUnwrap(PrivateUsageWebConnection.connectDeviceURL(
            processEnvironment: [:], bundleInfo: configuration
        ))
        XCTAssertEqual(connection.path, "/connect-device")
        XCTAssertNil(connection.fragment)
        let query = try XCTUnwrap(URLComponents(url: connection, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "source" }?.value, "macos")
        XCTAssertEqual(query.first { $0.name == "callback_url" }?.value, "spill://private-usage/connect")
        XCTAssertEqual(PrivateUsageWebConnection.dashboardURL(
            processEnvironment: [:], bundleInfo: configuration
        )?.absoluteString, "https://getmoru.com/spill/dashboard")
    }

    func testLegacyProductionOriginMigratesAllConnectionSurfaces() {
        for oldURL in ["https://spill.thdev.app/", "https://spill.thdev.app/#/connect-device"] {
            let configuration = [PrivateUsageWebConnection.webURLInfoDictionaryKey: oldURL]
            XCTAssertEqual(PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [:], bundleInfo: configuration
            )?.host, "getmoru.com")
            XCTAssertEqual(PrivateUsageWebConnection.dashboardURL(
                processEnvironment: [:], bundleInfo: configuration
            )?.absoluteString, "https://getmoru.com/spill/dashboard")
            XCTAssertEqual(PrivateUsageRelayEndpoint.relayURL(
                environment: .production, processEnvironment: [:], bundleInfo: configuration
            )?.absoluteString, "https://getmoru.com/api/private-usage-relay")
        }
    }

    func testCustomOriginAndRuntimeOverrideRemainAuthoritative() {
        let overrides = [PrivateUsageWebConnection.webURLOverrideEnvironmentKey:
            "https://preview.example.test/#/connect-device?source=browser&callback_url=https://invalid.example"]
        let configuration = [PrivateUsageWebConnection.webURLInfoDictionaryKey: "https://spill.thdev.app/"]
        let connection = PrivateUsageWebConnection.connectDeviceURL(
            processEnvironment: overrides, bundleInfo: configuration
        )
        XCTAssertEqual(connection?.host, "preview.example.test")
        XCTAssertEqual(connection?.path, "/connect-device")
        XCTAssertNil(connection?.fragment)
        XCTAssertEqual(PrivateUsageRelayEndpoint.relayURL(
            environment: .production, processEnvironment: overrides, bundleInfo: configuration
        )?.absoluteString, "https://preview.example.test/api/private-usage-relay")
    }

    func testIPv4LoopbackUsesTheLocalWebAndRelay() {
        let overrides = [PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "http://127.0.0.1:5173/"]
        XCTAssertEqual(PrivateUsageWebConnection.connectDeviceURL(
            processEnvironment: overrides, bundleInfo: nil
        )?.path, "/connect-device")
        XCTAssertEqual(PrivateUsageRelayEndpoint.relayURL(
            environment: .development, processEnvironment: overrides, bundleInfo: nil
        )?.absoluteString, "http://127.0.0.1:5173/api/private-usage-relay")
    }

    func testLegacyMigrationDoesNotRewriteCustomPortsOrSimilarHosts() {
        for origin in ["https://spill.thdev.app:8443", "https://preview.spill.thdev.app", "https://spill.thdev.app.example.test"] {
            let overrides = [PrivateUsageWebConnection.webURLOverrideEnvironmentKey: origin]
            XCTAssertEqual(PrivateUsageRelayEndpoint.relayURL(
                environment: .production, processEnvironment: overrides, bundleInfo: nil
            )?.absoluteString, origin + "/api/private-usage-relay")
        }
    }

    func testMissingConfigurationDoesNotEnableProductionUpload() {
        XCTAssertNil(PrivateUsageWebConnection.connectDeviceURL(processEnvironment: [:], bundleInfo: nil))
        XCTAssertNil(PrivateUsageRelayEndpoint.relayURL(
            environment: .production, processEnvironment: [:], bundleInfo: nil
        ))
    }

    func testNativeUploadUsesMigratedOriginAndExistingCredential() async throws {
        let endpoint = try XCTUnwrap(PrivateUsageRelayEndpoint.relayURL(
            environment: .production, processEnvironment: [:],
            bundleInfo: [PrivateUsageWebConnection.webURLInfoDictionaryKey: "https://spill.thdev.app/"]
        ))
        let client = PrivateUsageRelayClient(relayURL: endpoint, transport: .init { request in
            XCTAssertEqual(request.url?.absoluteString, "https://getmoru.com/api/private-usage-relay/upload-buckets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer spill_device_v1_test_credential")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (Data(#"{"accepted":0,"uploaded_at":"2026-10-15T12:00:00Z"}"#.utf8), response)
        })
        let result = try await client.uploadBuckets(
            credential: PrivateUsageDeviceCredential(
                deviceID: "test_device", credential: "spill_device_v1_test_credential",
                tokenType: "spill_device_v1", createdAt: Date(timeIntervalSince1970: 0)
            ), buckets: [], sharedSummaries: [], keyEnvelopes: []
        )
        XCTAssertEqual(result.accepted, 0)
    }
}
