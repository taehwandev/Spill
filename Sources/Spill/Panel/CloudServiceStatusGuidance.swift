import Foundation

struct CloudServiceStatusGuidance: Equatable {
    let title: String
    let detail: String
    let symbolName: String
    let health: CloudServiceHealth?

    static func make(
        snapshot: CloudServiceStatusSnapshot?,
        isLoading: Bool,
        appLanguage: SpillAppLanguage
    ) -> Self {
        if isLoading {
            return Self(
                title: AppL10n.text(.serviceGuidanceCheckingTitle, appLanguage: appLanguage),
                detail: AppL10n.text(.serviceGuidanceCheckingDetail, appLanguage: appLanguage),
                symbolName: "arrow.triangle.2.circlepath",
                health: nil
            )
        }

        guard let snapshot else {
            return Self(
                title: AppL10n.text(.serviceGuidanceNotFetchedTitle, appLanguage: appLanguage),
                detail: AppL10n.text(.serviceGuidanceNotFetchedDetail, appLanguage: appLanguage),
                symbolName: "cloud.fill",
                health: nil
            )
        }

        let issueCount = snapshot.items.filter { $0.health.isServerIssue }.count
        let health = CloudServiceStatusPresentation.aggregateHealth(for: snapshot.items)
        if issueCount > 0 {
            return Self(
                title: AppL10n.serviceGuidanceIssueTitle(issueCount, appLanguage: appLanguage),
                detail: AppL10n.text(.serviceGuidanceIssueDetail, appLanguage: appLanguage),
                symbolName: health.serverStatusSymbolName,
                health: health
            )
        }

        if health == .operational {
            return Self(
                title: AppL10n.text(.serviceGuidanceHealthyTitle, appLanguage: appLanguage),
                detail: AppL10n.text(.serviceGuidanceHealthyDetail, appLanguage: appLanguage),
                symbolName: health.serverStatusSymbolName,
                health: health
            )
        }

        return Self(
            title: AppL10n.text(.serviceGuidanceUnavailableTitle, appLanguage: appLanguage),
            detail: AppL10n.text(.serviceGuidanceUnavailableDetail, appLanguage: appLanguage),
            symbolName: CloudServiceHealth.unknown.serverStatusSymbolName,
            health: .unknown
        )
    }
}
