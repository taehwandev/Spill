import Foundation
import IOKit

/// Reads optional Apple Silicon driver counters through the public IORegistry API.
/// Driver property names are best-effort; missing or malformed values stay absent.
enum SystemGPUPerformanceReader {
    struct Reading: Hashable, Sendable {
        let utilizationRatio: Double?
        let coreCount: Int?
    }

    private static let coreCountCache = CoreCountCache()

    static func current() -> Reading? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var utilizationRatio: Double?
        let cachedCoreCount = coreCountCache.value
        var coreCount = cachedCoreCount
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            if let properties = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any],
               let percent = properties["Device Utilization %"] as? NSNumber {
                let value = percent.doubleValue
                if value.isFinite, (0...100).contains(value) {
                    utilizationRatio = max(utilizationRatio ?? 0, value / 100)
                }
            }

            if cachedCoreCount == nil,
               let count = IORegistryEntrySearchCFProperty(
                   service,
                   kIOServicePlane,
                   "gpu-core-count" as CFString,
                   kCFAllocatorDefault,
                   IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively)
               ) as? NSNumber, count.intValue > 0 {
                coreCount = max(coreCount ?? 0, count.intValue)
            }
        }

        if cachedCoreCount == nil {
            coreCountCache.storeIfPresent(coreCount)
        }
        guard utilizationRatio != nil || coreCount != nil else {
            return nil
        }
        return Reading(utilizationRatio: utilizationRatio, coreCount: coreCount)
    }

    private final class CoreCountCache: @unchecked Sendable {
        private let lock = NSLock()
        private var storedValue: Int?

        var value: Int? {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }

        func storeIfPresent(_ count: Int?) {
            guard let count else { return }
            lock.lock()
            storedValue = max(storedValue ?? 0, count)
            lock.unlock()
        }
    }
}
