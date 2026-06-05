import Foundation
import XCTest
@testable import Spill

final class CloudServiceStatusProviderTests: XCTestCase {
    func testProviderMapsOfficialStatusSources() async {
        let provider = CloudServiceStatusProvider { url in
            switch url {
            case CloudServiceStatusProvider.openAIStatusURL:
                return Data(Self.openAIStatusJSON.utf8)
            case CloudServiceStatusProvider.claudeStatusURL:
                return Data(Self.claudeStatusJSON.utf8)
            case CloudServiceStatusProvider.googleCloudIncidentsURL:
                return Data(Self.googleIncidentsJSON.utf8)
            default:
                throw CloudServiceStatusError.invalidHTTPStatus(404)
            }
        }

        let snapshot = await provider.snapshot(now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(snapshot.items.first { $0.kind == .codex }?.health, .degraded)
        XCTAssertEqual(snapshot.items.first { $0.kind == .openAI }?.health, .operational)
        XCTAssertEqual(snapshot.items.first { $0.kind == .claudeCode }?.health, .operational)
        XCTAssertEqual(snapshot.items.first { $0.kind == .claudeAPI }?.health, .outage)
        XCTAssertEqual(snapshot.items.first { $0.kind == .geminiAPI }?.health, .degraded)
        XCTAssertEqual(snapshot.items.first { $0.kind == .antigravity }?.health, .degraded)
        XCTAssertEqual(snapshot.items.first { $0.kind == .antigravity }?.source, "Google Cloud Status")
        XCTAssertTrue(snapshot.items.first { $0.kind == .antigravity }?.detail.contains("Gemini API") == true)
    }

    func testProviderReturnsUnknownItemsWhenStatusSourceFails() async {
        let provider = CloudServiceStatusProvider { _ in
            throw CloudServiceStatusError.invalidHTTPStatus(503)
        }

        let snapshot = await provider.snapshot(now: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(snapshot.items.first { $0.kind == .codex }?.health, .unknown)
        XCTAssertEqual(snapshot.items.first { $0.kind == .claudeCode }?.health, .unknown)
        XCTAssertEqual(snapshot.items.first { $0.kind == .geminiAPI }?.health, .unknown)
        XCTAssertEqual(snapshot.items.first { $0.kind == .antigravity }?.health, .unknown)
    }

    private static let openAIStatusJSON = """
    {
      "status": { "description": "Partial System Degradation", "indicator": "minor" },
      "components": [
        { "name": "Responses", "status": "operational" },
        { "name": "CLI", "status": "degraded_performance" },
        { "name": "Codex API", "status": "operational" },
        { "name": "VS Code extension", "status": "operational" }
      ]
    }
    """

    private static let claudeStatusJSON = """
    {
      "status": { "description": "Partial System Outage", "indicator": "major" },
      "components": [
        { "name": "Claude Code", "status": "operational" },
        { "name": "Claude API", "status": "partial_outage" }
      ]
    }
    """

    private static let googleIncidentsJSON = """
    [
      {
        "external_desc": "Vertex AI Gemini API customers experienced increased error rates.",
        "status_impact": "SERVICE_DISRUPTION",
        "severity": "low",
        "end": null,
        "affected_products": [
          { "title": "Vertex Gemini API" }
        ]
      }
    ]
    """
}
