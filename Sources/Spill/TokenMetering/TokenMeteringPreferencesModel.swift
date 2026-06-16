import Foundation

enum TokenMeteringPreferencesModel {
    static var modes: [TokenMeteringModeStatus] {
        [
            TokenMeteringModeStatus(
                id: "local_only",
                title: TokenMeteringL10n.text(.modeLocalOnlyTitle),
                state: TokenMeteringL10n.text(.modeLocalOnlyState),
                detail: TokenMeteringL10n.text(.modeLocalOnlyDetail),
                isActive: true
            ),
            TokenMeteringModeStatus(
                id: "cloud_aggregate",
                title: TokenMeteringL10n.text(.modeCloudAggregateTitle),
                state: TokenMeteringL10n.text(.modeCloudAggregateState),
                detail: TokenMeteringL10n.text(.modeCloudAggregateDetail),
                isActive: false
            ),
            TokenMeteringModeStatus(
                id: "cloud_detailed",
                title: TokenMeteringL10n.text(.modeCloudDetailedTitle),
                state: TokenMeteringL10n.text(.modeCloudDetailedState),
                detail: TokenMeteringL10n.text(.modeCloudDetailedDetail),
                isActive: false
            )
        ]
    }

    static var forbiddenContentLabels: [String] {
        TokenMeteringL10n.forbiddenContentLabels()
    }
}
