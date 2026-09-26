import Foundation

/// The sleep guard fields the menu bar renders; equal states need no status item refresh.
struct SleepGuardMenuBarState: Equatable {
    let isActive: Bool
    let remainingLabel: String
    let activeDuration: SleepGuardDuration?
    let keepsDisplayAwake: Bool
    let errorMessage: String?

    @MainActor
    init(_ sleepGuard: SleepGuardController) {
        isActive = sleepGuard.isActive
        remainingLabel = sleepGuard.remainingLabel
        activeDuration = sleepGuard.activeDuration
        keepsDisplayAwake = sleepGuard.keepsDisplayAwake
        errorMessage = sleepGuard.errorMessage
    }
}
