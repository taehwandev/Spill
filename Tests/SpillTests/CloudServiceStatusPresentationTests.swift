import XCTest
@testable import Spill

final class CloudServiceStatusPresentationTests: XCTestCase {
    func testAggregateHealthIgnoresAntigravityUnknownWhenOfficialSourcesAreHealthy() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .operational),
            item(kind: .claudeCode, health: .operational),
            item(kind: .antigravity, health: .unknown)
        ])

        XCTAssertEqual(health, .operational)
    }

    func testAggregateHealthKeepsUnknownForOfficialStatusFailures() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .unknown),
            item(kind: .claudeCode, health: .operational),
            item(kind: .antigravity, health: .unknown)
        ])

        XCTAssertEqual(health, .unknown)
    }

    func testAggregateHealthPrioritizesServerIssuesOverUnknowns() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .unknown),
            item(kind: .claudeAPI, health: .degraded),
            item(kind: .geminiAPI, health: .operational)
        ])

        XCTAssertEqual(health, .degraded)
    }

    func testServerStatusBadgeTitlesExposeHealthDirectly() {
        XCTAssertEqual(CloudServiceHealth.operational.serverStatusBadgeTitle, "Server OK")
        XCTAssertEqual(CloudServiceHealth.degraded.serverStatusBadgeTitle, "Degraded")
        XCTAssertEqual(CloudServiceHealth.outage.serverStatusBadgeTitle, "Outage")
        XCTAssertEqual(CloudServiceHealth.maintenance.serverStatusBadgeTitle, "Maint")
        XCTAssertEqual(CloudServiceHealth.unknown.serverStatusBadgeTitle, "Unknown")
    }

    func testOnlyActionableHealthStatesCountAsServerIssues() {
        XCTAssertFalse(CloudServiceHealth.operational.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.degraded.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.outage.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.maintenance.isServerIssue)
        XCTAssertFalse(CloudServiceHealth.unknown.isServerIssue)
    }

    private func item(kind: CloudServiceKind, health: CloudServiceHealth) -> CloudServiceStatusItem {
        CloudServiceStatusItem(
            kind: kind,
            health: health,
            detail: "test",
            source: "test"
        )
    }
}
