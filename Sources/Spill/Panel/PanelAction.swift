import Foundation

enum PanelAction: Equatable {
    case refreshDerivedState
    case setStatusDetailTarget(SpillStatusDetailTarget?)
    case performWindowAction(SpillAction)
}
