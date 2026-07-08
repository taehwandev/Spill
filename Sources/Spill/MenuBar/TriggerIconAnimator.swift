import Foundation

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

    private var frameTimer: Timer?
    private var idleTimer: Timer?
    private var isBursting = false
    private var burstSpeedMultiplier: CGFloat = 1
    private var lastUsageRatio: Double?
    private var isRunning = false

    private init() {}

    /// Idempotent — safe to call every refresh tick. Does nothing if already running.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastUsageRatio = nil
        scheduleNextIdleBurst()
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
        if shouldRedrawAtRest {
            onFrame?()
        }
    }

    /// Feed the latest combined system load ratio (0...1) on every refresh. A large jump since
    /// the last reading interrupts the idle wait and starts an early, modestly faster burst.
    /// Safe to call whether or not the animator is running.
    func noteUsageRatio(_ ratio: Double) {
        defer { lastUsageRatio = ratio }
        guard isRunning, !isBursting else { return }
        guard let previousUsageRatio = lastUsageRatio else { return }
        let delta = abs(ratio - previousUsageRatio)
        guard delta >= Self.usageChangeBurstThreshold else { return }
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
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceFrame() }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func advanceFrame() {
        phase += Self.baseStepPerFrame * burstSpeedMultiplier
        if phase >= 1 {
            phase = 0
            frameTimer?.invalidate()
            frameTimer = nil
            isBursting = false
            onFrame?()
            scheduleNextIdleBurst()
            return
        }
        onFrame?()
    }
}

#if DEBUG
extension TriggerIconAnimator {
    static func makeForTesting() -> TriggerIconAnimator {
        TriggerIconAnimator()
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

    func startBurstForTesting(speedMultiplier: CGFloat = 1) {
        startBurst(speedMultiplier: speedMultiplier)
    }

    func advanceFrameForTesting() {
        advanceFrame()
    }
}
#endif
