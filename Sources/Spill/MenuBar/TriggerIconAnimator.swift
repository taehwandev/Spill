import AppKit

/// Drives the menu bar trigger icon's animation phase independently of `MenuBarMetricChipView`.
/// That view gets torn down and rebuilt almost every refresh (its segment includes live CPU /
/// memory text, which changes on nearly every tick), so a timer/phase owned by the view itself
/// restarts constantly — read as flickering rather than smooth motion. Owning the timer here, in
/// an object `StatusItemController` starts once and keeps for the app's lifetime, keeps the
/// phase continuous across those rebuilds; views only ever read the current phase and register
/// to be notified of frames, never own timing themselves.
///
/// Animation runs in short "bursts" (one full phase cycle) separated by a randomized idle gap,
/// rather than looping forever — a menu bar icon in constant motion reads as busy/distracting.
/// A burst can also be triggered early, and run a bit faster, when the system's combined
/// CPU/memory/network load jumps by a meaningful amount between refreshes (see `noteUsageRatio`),
/// so the icon's motion loosely tracks real activity without being literally proportional to it.
/// Early bursts respect the same minimum gap as idle ones: every frame re-renders the whole
/// status item on every display, which itself moves CPU load, so an uncapped load trigger
/// can feed back into near-continuous animation.
///
/// Styles that loop continuously (the cat's tail) instead keep one frame timer running and
/// never pause. Load only changes how far the phase moves per frame, never the frame rate, so
/// faster motion costs no extra redraws and cannot feed back into the load it reads.
@MainActor
final class TriggerIconAnimator {
    static let shared = TriggerIconAnimator()

    private(set) var phase: CGFloat = 0
    var onFrame: (() -> Void)?

    private static let frameInterval: TimeInterval = 1.0 / 12.0
    private static let baseStepPerFrame: CGFloat = 0.05
    private static let idleDelayRange: ClosedRange<TimeInterval> = 7...18
    private static let usageChangeBurstThreshold: Double = 0.20
    private static let maximumBurstSpeedMultiplier: CGFloat = 1.6
    /// One loop is about 6.4s at rest; the cat sways its tail four times per loop.
    private static let loopStepPerFrame: CGFloat = 0.013
    private static let maximumLoopSpeedMultiplier: CGFloat = 3
    /// Combined load at or below the lower bound loops at rest speed, at or above the upper
    /// bound at full speed. Memory alone usually sits near the lower bound on macOS.
    private static let loopSpeedUsageRange: ClosedRange<Double> = 0.45...0.9
    /// Fraction of the remaining gap to the target speed closed each frame (~1s to settle).
    private static let loopSpeedEasing: CGFloat = 0.08

    private var frameTimer: Timer?
    private var idleTimer: Timer?
    private var isBursting = false
    private var burstSpeedMultiplier: CGFloat = 1
    private var loopSpeedMultiplier: CGFloat = 1
    private var targetLoopSpeedMultiplier: CGFloat = 1
    private var lastUsageRatio: Double?
    private var isRunning = false
    private var loopsContinuously = false
    private var lastBurstEndedAt: Date?
    private var areScreensAsleep = false
    private var isSessionInactive = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private let now: () -> Date

    private init(now: @escaping () -> Date = Date.init) {
        self.now = now
        observeWorkspaceVisibility()
    }

    /// Nobody can see the menu bar while the displays sleep or another user's session is in
    /// front, so the continuous loop pauses there instead of ticking 12 times a second.
    private var isLoopSuspended: Bool {
        areScreensAsleep || isSessionInactive
    }

    private func observeWorkspaceVisibility() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.noteWorkspaceVisibility(name)
                }
            }
        }
    }

    private func noteWorkspaceVisibility(_ name: Notification.Name) {
        switch name {
        case NSWorkspace.screensDidSleepNotification:
            areScreensAsleep = true
        case NSWorkspace.screensDidWakeNotification:
            areScreensAsleep = false
        case NSWorkspace.sessionDidResignActiveNotification:
            isSessionInactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification:
            isSessionInactive = false
        default:
            return
        }
        applyLoopSuspension()
    }

    private func applyLoopSuspension() {
        guard isRunning, loopsContinuously else { return }
        if isLoopSuspended {
            frameTimer?.invalidate()
            frameTimer = nil
        } else if frameTimer == nil {
            startFrameTimer()
        }
    }

    /// Idempotent — safe to call every refresh tick. Does nothing if already running in the
    /// same mode; switching between bursts and a continuous loop restarts from rest.
    func start(loopsContinuously: Bool = false) {
        if isRunning, self.loopsContinuously != loopsContinuously {
            stop()
        }
        guard !isRunning else { return }
        isRunning = true
        self.loopsContinuously = loopsContinuously
        lastUsageRatio = nil
        if loopsContinuously {
            loopSpeedMultiplier = 1
            targetLoopSpeedMultiplier = 1
            phase = 0
            applyLoopSuspension()
        } else {
            scheduleNextIdleBurst()
        }
    }

    /// Idempotent. Cancels any in-flight burst/wait and resets phase, so the icon renders at
    /// rest. Callers should stop this when animation is turned off (settings) or the trigger
    /// style doesn't animate, so a background timer doesn't tick forever for nothing.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        frameTimer?.invalidate()
        frameTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
        isBursting = false
        let shouldRedrawAtRest = phase != 0
        phase = 0
        lastUsageRatio = nil
        lastBurstEndedAt = nil
        if shouldRedrawAtRest {
            onFrame?()
        }
    }

    /// Feed the latest combined system load ratio (0...1) on every refresh. A large jump since
    /// the last reading interrupts the idle wait and starts an early, modestly faster burst.
    /// Safe to call whether or not the animator is running.
    func noteUsageRatio(_ ratio: Double) {
        defer { lastUsageRatio = ratio }
        guard isRunning else { return }
        if loopsContinuously {
            targetLoopSpeedMultiplier = Self.loopSpeedMultiplier(forUsageRatio: ratio)
            return
        }
        guard !isBursting else { return }
        guard let previousUsageRatio = lastUsageRatio else { return }
        let delta = abs(ratio - previousUsageRatio)
        guard delta >= Self.usageChangeBurstThreshold else { return }
        if let lastBurstEndedAt, now().timeIntervalSince(lastBurstEndedAt) < Self.idleDelayRange.lowerBound {
            return
        }
        let multiplier = 1 + min(Self.maximumBurstSpeedMultiplier - 1, delta)
        startBurst(speedMultiplier: multiplier)
    }

    private func scheduleNextIdleBurst() {
        idleTimer?.invalidate()
        let delay = TimeInterval.random(in: Self.idleDelayRange)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.startBurst(speedMultiplier: 1) }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func startBurst(speedMultiplier: CGFloat) {
        guard isRunning, !isBursting else { return }
        isBursting = true
        burstSpeedMultiplier = speedMultiplier
        phase = 0
        startFrameTimer()
    }

    private func startFrameTimer() {
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceFrame() }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    static func loopSpeedMultiplier(forUsageRatio ratio: Double) -> CGFloat {
        guard ratio.isFinite else { return 1 }
        let range = loopSpeedUsageRange
        let progress = ((ratio - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
        return 1 + (maximumLoopSpeedMultiplier - 1) * CGFloat(progress)
    }

    private func advanceFrame() {
        if loopsContinuously {
            loopSpeedMultiplier += (targetLoopSpeedMultiplier - loopSpeedMultiplier) * Self.loopSpeedEasing
            phase += Self.loopStepPerFrame * loopSpeedMultiplier
            if phase >= 1 {
                phase -= 1
            }
            onFrame?()
            return
        }
        phase += Self.baseStepPerFrame * burstSpeedMultiplier
        if phase >= 1 {
            phase = 0
            frameTimer?.invalidate()
            frameTimer = nil
            isBursting = false
            lastBurstEndedAt = now()
            onFrame?()
            scheduleNextIdleBurst()
            return
        }
        onFrame?()
    }
}

#if DEBUG
extension TriggerIconAnimator {
    static func makeForTesting(now: @escaping () -> Date = Date.init) -> TriggerIconAnimator {
        TriggerIconAnimator(now: now)
    }

    var isRunningForTesting: Bool {
        isRunning
    }

    var isBurstingForTesting: Bool {
        isBursting
    }

    var hasFrameTimerForTesting: Bool {
        frameTimer != nil
    }

    var hasIdleTimerForTesting: Bool {
        idleTimer != nil
    }

    var loopSpeedMultiplierForTesting: CGFloat {
        loopSpeedMultiplier
    }

    func startBurstForTesting(speedMultiplier: CGFloat = 1) {
        startBurst(speedMultiplier: speedMultiplier)
    }

    func advanceFrameForTesting() {
        advanceFrame()
    }

    func setScreensAsleepForTesting(_ asleep: Bool) {
        areScreensAsleep = asleep
        applyLoopSuspension()
    }
}
#endif
