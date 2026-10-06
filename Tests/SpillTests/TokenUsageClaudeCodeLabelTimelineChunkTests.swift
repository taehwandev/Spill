import XCTest
@testable import Spill

final class TokenUsageClaudeCodeLabelTimelineChunkTests: XCTestCase {
    func testTimelineLargerThanOneChunkKeepsEveryLineIntactAcrossChunkBoundaries() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let timelineURL = rootURL.appendingPathComponent("claude-timeline.jsonl")

        // Distinct one-minute windows, enough bytes to span several chunks so lines straddle them.
        let lineCount = (TokenUsageClaudeCodeImporter.labelTimelineChunkSize * 3) / 180
        let start = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-26T00:00:00.000Z"))
        var data = Data()
        for index in 0..<lineCount {
            let updatedAt = start.addingTimeInterval(TimeInterval(index) * 60)
            let expiresAt = updatedAt.addingTimeInterval(59)
            let taskType = index.isMultiple(of: 2) ? "debugging" : "testing"
            let line = #"{"ai_tool":"claude","task_type":"\#(taskType)","stage":"implement","project_id":"project_shared","updated_at":"\#(ISO8601DateFormatter.tokenUsage.string(from: updatedAt))","expires_at":"\#(ISO8601DateFormatter.tokenUsage.string(from: expiresAt))"}"# + "\n"
            data.append(Data(line.utf8))
        }
        try data.write(to: timelineURL)
        XCTAssertGreaterThan(data.count, TokenUsageClaudeCodeImporter.labelTimelineChunkSize * 2)

        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: rootURL,
            labelTimelineURL: timelineURL,
            stateURL: nil,
            diagnosticsURL: nil
        )
        let timeline = importer.readLabelTimeline()

        XCTAssertEqual(timeline.entries.count, lineCount)
        XCTAssertEqual(importer.labelTimelineBytesRead, data.count)
        for index in stride(from: 0, to: lineCount, by: max(1, lineCount / 97)) {
            let label = timeline.label(for: start.addingTimeInterval(TimeInterval(index) * 60 + 30))
            XCTAssertEqual(label.taskType, index.isMultiple(of: 2) ? .debugging : .testing, "line \(index)")
            XCTAssertEqual(label.projectID, "project_shared")
        }

        // A second read finds nothing new and does not rescan the history.
        _ = importer.readLabelTimeline()
        XCTAssertEqual(importer.labelTimelineBytesRead, data.count)
    }
}
