import XCTest
@testable import Spill

@MainActor
final class SystemStatusRefreshCoordinatorTests: XCTestCase {
    func testCadenceDependsOnVisibleConsumers() {
        XCTAssertEqual(interval(panel: true, items: false), 3)
        XCTAssertEqual(interval(panel: false, items: true), 15)
        XCTAssertEqual(interval(panel: false, items: true, preferred: 30), 30)
        XCTAssertEqual(interval(panel: false, items: true, preferred: 2), 3)
        XCTAssertEqual(interval(panel: false, items: true, preferred: .nan), 15)
        XCTAssertNil(interval(panel: false, items: false))
        XCTAssertEqual(SystemStatusRefreshCoordinator.interval(
            isPanelVisible: false, hasMenuBarItems: false,
            usesPerformanceEffect: true, preferredInterval: 15
        ), 15)
    }

    func testDisabledLoopDoesNotReadOrSleep() async {
        var reads = 0
        var sleeps = 0
        let coordinator = SystemStatusRefreshCoordinator(
            interval: { nil }, refresh: { reads += 1 },
            sleep: { _ in sleeps += 1; throw CancellationError() }
        )
        coordinator.restart()
        await drainTasks()
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(sleeps, 0)
    }

    func testImmediateRefreshReadsCurrentIntervalAfterWork() async {
        var delay = 15.0
        var sleeps = [Double]()
        let coordinator = SystemStatusRefreshCoordinator(
            interval: { delay }, refresh: { delay = 3 },
            sleep: { sleeps.append($0); throw CancellationError() }
        )
        coordinator.restart()
        await eventually { !sleeps.isEmpty }
        XCTAssertEqual(sleeps, [3])
    }

    func testDeferredRefreshWaitsBeforeReading() async {
        let sleeper = Suspension()
        var reads = 0
        let coordinator = SystemStatusRefreshCoordinator(
            interval: { 3 }, refresh: { reads += 1 },
            sleep: { _ in await sleeper.wait(); try Task.checkCancellation() }
        )
        coordinator.restart(startsImmediately: false)
        await eventually { sleeper.isWaiting }
        XCTAssertEqual(reads, 0)
        sleeper.resume()
        await eventually { reads == 1 && sleeper.isWaiting }
        coordinator.stop()
        sleeper.resume()
        await drainTasks()
        XCTAssertEqual(reads, 1)
    }

    func testStopWhileSleepingPreventsAnotherRead() async {
        let sleeper = Suspension()
        var reads = 0
        let coordinator = SystemStatusRefreshCoordinator(
            interval: { 3 }, refresh: { reads += 1 },
            sleep: { _ in await sleeper.wait() }
        )
        coordinator.restart()
        await eventually { sleeper.isWaiting }
        coordinator.stop()
        sleeper.resume()
        await drainTasks()
        XCTAssertEqual(reads, 1)
    }

    func testRestartAndManualRefreshShareAnInFlightRead() async {
        let reader = Suspension()
        var reads = 0
        var sleeps = 0
        let coordinator = SystemStatusRefreshCoordinator(
            interval: { 3 },
            refresh: { reads += 1; await reader.wait() },
            sleep: { _ in sleeps += 1; throw CancellationError() }
        )
        coordinator.restart()
        await eventually { reader.isWaiting }
        coordinator.restart()
        let manualRefresh = Task { await coordinator.refreshNow() }
        await drainTasks()
        XCTAssertEqual(reads, 1)
        reader.resume()
        await manualRefresh.value
        await eventually { sleeps == 1 }
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(sleeps, 1, "Only the replacement loop may schedule another tick")
    }

    func testSleepingLoopDoesNotRetainItsOwner() async {
        let sleeper = Suspension()
        var coordinator: SystemStatusRefreshCoordinator? = SystemStatusRefreshCoordinator(
            interval: { 3 }, refresh: {},
            sleep: { _ in await sleeper.wait() }
        )
        weak var weakCoordinator = coordinator
        coordinator?.restart()
        await eventually { sleeper.isWaiting }
        coordinator = nil
        XCTAssertNil(weakCoordinator)
        sleeper.resume()
    }

    private func interval(panel: Bool, items: Bool, preferred: Double = 15) -> Double? {
        SystemStatusRefreshCoordinator.interval(
            isPanelVisible: panel, hasMenuBarItems: items,
            usesPerformanceEffect: false, preferredInterval: preferred
        )
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Expected scheduler transition did not occur", file: file, line: line)
    }

    private func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }
}

@MainActor
private final class Suspension {
    private var continuation: CheckedContinuation<Void, Never>?
    var isWaiting: Bool { continuation != nil }

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
