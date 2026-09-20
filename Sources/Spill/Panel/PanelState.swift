import Foundation

struct PanelState: Equatable {
    let visibleStatusModules: [SpillStatusModule]
    var actionFeedback: SpillActionFeedback? = nil
    var statusDetailTarget: SpillStatusDetailTarget? = nil
}
