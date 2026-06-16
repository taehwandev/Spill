import Foundation

enum TokenUsageDisplayMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case percentage = "Share %"

    var id: String { rawValue }

    var localizedTitle: String {
        localizedTitle(language: .current())
    }

    func localizedTitle(language: TokenMeteringLanguage) -> String {
        switch self {
        case .tokens:
            return TokenMeteringL10n.text(.displayModeTokens, language: language)
        case .percentage:
            return TokenMeteringL10n.text(.displayModeShare, language: language)
        }
    }
}

struct TokenMeteringModeStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let state: String
    let detail: String
    let isActive: Bool
}

struct TokenUsageDashboardKPI: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct TokenUsageDashboardBarRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let ratio: Double
}

struct TokenUsageDashboardWorkflowUsage: Equatable {
    let rows: [TokenUsageDashboardBarRow]
}

struct TokenUsageDashboardSessionRow: Identifiable, Equatable {
    let id: String
    let runID: String
    let projectID: String
    let projectTitle: String
    let title: String
    let value: String
    let detail: String
    let eventCount: Int
}

struct TokenUsageDashboardCalendarDay: Identifiable, Equatable {
    let id: String
    let day: Int
    let title: String
    let detail: String
    let ratio: Double
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let isPlaceholder: Bool
    let isToday: Bool
    let isSelected: Bool
}

struct TokenUsageDashboardToolFilter: Identifiable, Equatable {
    let tool: TokenUsageAITool?
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        tool?.rawValue ?? "all"
    }
}

struct TokenUsageDashboardProjectFilter: Identifiable, Equatable {
    let projectID: String?
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        projectID ?? "all"
    }
}

enum TokenUsageDashboardPeriod: String, CaseIterable, Equatable {
    case today
    case sevenDays
    case thirtyDays
    case all

    var title: String {
        title(language: .current())
    }

    func title(language: TokenMeteringLanguage) -> String {
        switch self {
        case .today:
            return TokenMeteringL10n.text(.periodToday, language: language)
        case .sevenDays:
            return TokenMeteringL10n.text(.periodSevenDays, language: language)
        case .thirtyDays:
            return TokenMeteringL10n.text(.periodThirtyDays, language: language)
        case .all:
            return TokenMeteringL10n.text(.periodAll, language: language)
        }
    }
}

struct TokenUsageDashboardPeriodFilter: Identifiable, Equatable {
    let period: TokenUsageDashboardPeriod
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        period.rawValue
    }
}

struct TokenUsageSelfTestMessage: Equatable {
    let text: String
    let isSuccess: Bool
}

struct TokenUsageDashboardSnapshotPair {
    let filtered: TokenUsageDashboardSnapshot
    let unfiltered: TokenUsageDashboardSnapshot
    let calendarMonthStart: Date
}
