import SwiftUI

enum CloudServiceStatusPresentation {
    static func aggregateHealth(for items: [CloudServiceStatusItem]) -> CloudServiceHealth {
        let rankedItems = items.filter { item in
            item.kind != .antigravity || item.health != .unknown
        }
        let scopedItems = rankedItems.isEmpty ? items : rankedItems
        return scopedItems.max { lhs, rhs in
            lhs.health.serverStatusRank < rhs.health.serverStatusRank
        }?.health ?? .unknown
    }
}

extension CloudServiceHealth {
    var isServerIssue: Bool {
        switch self {
        case .degraded, .outage, .maintenance:
            return true
        case .operational, .unknown:
            return false
        }
    }

    var serverStatusRank: Int {
        switch self {
        case .outage:
            return 5
        case .degraded:
            return 4
        case .maintenance:
            return 3
        case .unknown:
            return 2
        case .operational:
            return 1
        }
    }

    var serverStatusHeaderTitle: String {
        switch self {
        case .operational:
            return "Operational"
        case .degraded:
            return "Degraded"
        case .outage:
            return "Outage"
        case .maintenance:
            return "Maintenance"
        case .unknown:
            return "Unknown"
        }
    }

    var serverStatusBadgeTitle: String {
        switch self {
        case .operational:
            return "Server OK"
        case .degraded:
            return "Degraded"
        case .outage:
            return "Outage"
        case .maintenance:
            return "Maint"
        case .unknown:
            return "Unknown"
        }
    }

    var serverStatusSymbolName: String {
        switch self {
        case .outage:
            return "exclamationmark.triangle.fill"
        case .degraded:
            return "exclamationmark.circle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .operational:
            return "checkmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var serverStatusTint: Color {
        switch self {
        case .outage:
            return .red
        case .degraded:
            return .orange
        case .maintenance:
            return .blue
        case .operational:
            return .green
        case .unknown:
            return .secondary
        }
    }
}
