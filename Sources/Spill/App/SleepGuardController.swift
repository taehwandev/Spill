import Foundation
import IOKit.pwr_mgt
import SwiftUI

typealias SleepAssertionID = UInt32

enum SleepGuardDuration: Int, CaseIterable, Identifiable, Sendable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1_800
    case fortyFiveMinutes = 2_700
    case oneHour = 3_600
    case twoHours = 7_200
    case fourHours = 14_400
    case eightHours = 28_800
    case indefinitely = -1

    var id: Int {
        rawValue
    }

    var seconds: TimeInterval? {
        guard rawValue > 0 else {
            return nil
        }

        return TimeInterval(rawValue)
    }

    var isIndefinite: Bool {
        self == .indefinitely
    }

    var menuTitle: String {
        switch self {
        case .fiveMinutes:
            return "5 Minutes"
        case .tenMinutes:
            return "10 Minutes"
        case .fifteenMinutes:
            return "15 Minutes"
        case .thirtyMinutes:
            return "30 Minutes"
        case .fortyFiveMinutes:
            return "45 Minutes"
        case .oneHour:
            return "1 Hour"
        case .twoHours:
            return "2 Hours"
        case .fourHours:
            return "4 Hours"
        case .eightHours:
            return "8 Hours"
        case .indefinitely:
            return "Never"
        }
    }

    static func availableDurations(allowsIndefinite: Bool) -> [SleepGuardDuration] {
        allCases.filter { allowsIndefinite || !$0.isIndefinite }
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

        guard activeDuration?.isIndefinite != true else {
            return "∞"
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

        let reason = "Spill Caffeine"
        guard let systemID = assertionManager.createSystemAssertion(reason: reason) else {
            errorMessage = AppL10n.text(.couldNotStartCaffeine)
            return false
        }

        var displayID: SleepAssertionID?
        if keepDisplayAwake {
            guard let createdDisplayID = assertionManager.createDisplayAssertion(reason: reason) else {
                assertionManager.releaseAssertion(systemID)
                errorMessage = AppL10n.text(.couldNotKeepDisplayAwake)
                return false
            }

            displayID = createdDisplayID
        }

        systemAssertionID = systemID
        displayAssertionID = displayID
        activeDuration = duration
        keepsDisplayAwake = keepDisplayAwake
        expirationDate = duration.seconds.map { now().addingTimeInterval($0) }
        remainingSeconds = duration.seconds.map(Int.init) ?? 0
        isActive = true
        errorMessage = nil
        startTimerIfNeeded()

        return true
    }

    @discardableResult
    func toggle(duration: SleepGuardDuration, keepDisplayAwake: Bool) -> Bool {
        if isActive {
            stop()
            return true
        }

        return start(duration: duration, keepDisplayAwake: keepDisplayAwake)
    }

    func stop() {
        stop(clearError: true)
    }

    func refreshRemaining() {
        guard isActive else {
            return
        }

        guard let expirationDate else {
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
