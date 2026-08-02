struct SpillGlanceRotationIdentity: Equatable {
    /// Surface configuration only. A change here means the user reconfigured
    /// Glance, so both the rolling epoch and the reactive change queue restart.
    struct Configuration: Equatable {
        let orderedModules: [SpillGlanceModule]
        let workRotationEnabled: Bool
        let reactiveRotationEnabled: Bool
        let displayStyle: SpillGlanceDisplayStyle
        let surfaceEnabled: Bool
    }

    let configuration: Configuration
    /// Usage-driven order. It restarts the rolling epoch, but must not clear the
    /// reactive queue: a reordering is exactly the signal reactive mode renders.
    let orderedWorkIDs: [String]
}
