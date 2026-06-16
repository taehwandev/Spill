import Foundation

struct TokenUsageDashboardWorkItemKey: Hashable {
    let projectID: String
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let dayBucket: String

    var id: String {
        [
            "work",
            projectID,
            taskType.rawValue,
            stage.rawValue,
            dayBucket
        ]
            .map(Self.safeIDPart)
            .joined(separator: "_")
    }

    private static func safeIDPart(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }
        return scalars.joined()
            .split(separator: "_")
            .joined(separator: "_")
    }
}

struct TokenUsageDashboardParsedEvent {
    let event: TokenUsageEvent
    let createdAt: Date?
    let dayBucket: String

    init(event: TokenUsageEvent, calendar: Calendar) {
        self.event = event
        let parsedDate = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt)
        self.createdAt = parsedDate
        self.dayBucket = parsedDate.map {
            TokenUsageDashboardSnapshot.dayID(for: $0, calendar: calendar)
        } ?? String(event.createdAt.prefix(10))
    }
}

struct TokenUsageDashboardSnapshotBuildContext {
    let dashboardEvents: [TokenUsageDashboardParsedEvent]

    init(
        events: [TokenUsageEvent],
        showAdvancedTools: Bool,
        calendar: Calendar
    ) {
        dashboardEvents = events.compactMap { event -> TokenUsageDashboardParsedEvent? in
            if showAdvancedTools {
                return TokenUsageDashboardParsedEvent(event: event, calendar: calendar)
            }

            return event.aiTool.isDashboardTool
                ? TokenUsageDashboardParsedEvent(event: event, calendar: calendar)
                : nil
        }
    }
}

extension NumberFormatter {
    static let tokenUsageFull: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let tokenUsageCompact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let tokenUsagePercentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
