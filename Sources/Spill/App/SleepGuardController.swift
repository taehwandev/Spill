import Foundation
import IOKit.pwr_mgt
import SwiftUI

typealias SleepAssertionID = UInt32

enum SleepGuardDuration: Int, CaseIterable, Identifiable, Sendable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1_800
    case oneHour = 3_600
    case twoHours = 7_200

    var id: Int {
        rawValue
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    var menuTitle: String {
        switch self {
        case .fifteenMinutes:
            return "15 Minutes"
        case .thirtyMinutes:
            return "30 Minutes"
        case .oneHour:
            return "1 Hour"
        case .twoHours:
            return "2 Hours"
        }
    }
}

protocol SleepAssertionManaging: AnyObject {
    func createSystemAssertion(reason: String) -> SleepAssertionID?
    func createDisplayAssertion(reason: String) -> SleepAssertionID?
    func releaseAssertion(_ id: SleepAssertionID)
}

final class IOKitSleepAssertionManager: SleepAssertionManaging {
    func createSystemAssertion(reason: String) -> SleepAssertionID? {
        createAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, reason: reason)
    }

    func createDisplayAssertion(reason: String) -> SleepAssertionID? {
        createAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, reason: reason)
    }

    func releaseAssertion(_ id: SleepAssertionID) {
        IOPMAssertionRelease(IOPMAssertionID(id))
    }

    private func createAssertion(type: CFString, reason: String) -> SleepAssertionID? {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            return nil
        }

        return SleepAssertionID(assertionID)
    }
}

@MainActor
final class SleepGuardController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var activeDuration: SleepGuardDuration?
    @Published private(set) var keepsDisplayAwake = false
    @Published private(set) var errorMessage: String?

    private let assertionManager: SleepAssertionManaging
    private let now: () -> Date
    private let automaticallySchedulesTimer: Bool
    private var systemAssertionID: SleepAssertionID?
    private var displayAssertionID: SleepAssertionID?
    private var expirationDate: Date?
    private var timer: Timer?

    init(
        assertionManager: SleepAssertionManaging = IOKitSleepAssertionManager(),
        now: @escaping () -> Date = Date.init,
        automaticallySchedulesTimer: Bool = true
    ) {
        self.assertionManager = assertionManager
        self.now = now
        self.automaticallySchedulesTimer = automaticallySchedulesTimer
    }

    var remainingLabel: String {
        guard isActive else {
            return ""
        }

        let minutes = max(1, Int(ceil(Double(remainingSeconds) / 60.0)))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }

        return "\(minutes)m"
    }

    @discardableResult
    func start(duration: SleepGuardDuration, keepDisplayAwake: Bool) -> Bool {
        stop(clearError: true)

        let reason = "Spill Sleep Guard"
        guard let systemID = assertionManager.createSystemAssertion(reason: reason) else {
            errorMessage = "Could not start Sleep Guard."
            return false
        }

        var displayID: SleepAssertionID?
        if keepDisplayAwake {
            guard let createdDisplayID = assertionManager.createDisplayAssertion(reason: reason) else {
                assertionManager.releaseAssertion(systemID)
                errorMessage = "Could not keep the display awake."
                return false
            }

            displayID = createdDisplayID
        }

        systemAssertionID = systemID
        displayAssertionID = displayID
        activeDuration = duration
        keepsDisplayAwake = keepDisplayAwake
        expirationDate = now().addingTimeInterval(duration.seconds)
        remainingSeconds = Int(duration.seconds)
        isActive = true
        errorMessage = nil
        startTimerIfNeeded()

        return true
    }

    func stop() {
        stop(clearError: true)
    }

    func refreshRemaining() {
        guard isActive, let expirationDate else {
            return
        }

        let remaining = max(0, Int(ceil(expirationDate.timeIntervalSince(now()))))
        remainingSeconds = remaining

        if remaining == 0 {
            stop(clearError: false)
        }
    }

    private func stop(clearError: Bool) {
        timer?.invalidate()
        timer = nil

        if let systemAssertionID {
            assertionManager.releaseAssertion(systemAssertionID)
        }

        if let displayAssertionID {
            assertionManager.releaseAssertion(displayAssertionID)
        }

        systemAssertionID = nil
        displayAssertionID = nil
        expirationDate = nil
        activeDuration = nil
        keepsDisplayAwake = false
        remainingSeconds = 0
        isActive = false

        if clearError {
            errorMessage = nil
        }
    }

    private func startTimerIfNeeded() {
        guard automaticallySchedulesTimer else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRemaining()
            }
        }
    }
}
