import Darwin
import Foundation

struct SystemMemoryReading: Hashable, Sendable {
    let totalBytes: UInt64
    let freeBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64

    var usedBytes: UInt64 {
        activeBytes.saturatingAdd(wiredBytes).saturatingAdd(compressedBytes)
    }

    var availableBytes: UInt64 {
        freeBytes.saturatingAdd(inactiveBytes)
    }
}

struct SystemMemoryStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let usageRatio: Double
    let usedBytes: UInt64
    let availableBytes: UInt64
    let freeBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let totalBytes: UInt64
    let state: SpillStatusState

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "memory",
            providerID: SystemMemoryProvider.providerID,
            title: "Memory",
            value: value,
            subtitle: subtitle,
            symbolName: "memorychip",
            state: state,
            sortPriority: 10
        )
    }
}

struct SystemMemoryProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.memory"
    let title = "Memory"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status().statusItem]
    }

    static func status() -> SystemMemoryStatus {
        status(from: SystemMemoryReader.current())
    }

    static func status(from reading: SystemMemoryReading?) -> SystemMemoryStatus {
        guard let reading, reading.totalBytes > 0 else {
            return unavailableStatus()
        }

        let usedBytes = min(reading.usedBytes, reading.totalBytes)
        let availableBytes = min(reading.availableBytes, reading.totalBytes)
        let ratio = (Double(usedBytes) / Double(reading.totalBytes)).clamped(to: 0...1)
        let value = SystemCPUProvider.percentText(ratio)
        let subtitle = "\(formatBytes(availableBytes)) available of \(formatBytes(reading.totalBytes))"

        return SystemMemoryStatus(
            value: value,
            subtitle: subtitle,
            usageRatio: ratio,
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            freeBytes: reading.freeBytes,
            activeBytes: reading.activeBytes,
            inactiveBytes: reading.inactiveBytes,
            wiredBytes: reading.wiredBytes,
            compressedBytes: reading.compressedBytes,
            totalBytes: reading.totalBytes,
            state: state(for: ratio)
        )
    }

    private static func state(for usageRatio: Double) -> SpillStatusState {
        if usageRatio >= 0.9 {
            return .warning
        }

        if usageRatio >= 0.75 {
            return .active
        }

        return .normal
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let gibibytes = Double(bytes) / 1_073_741_824

        if gibibytes >= 10 {
            return "\(Int(gibibytes.rounded())) GB"
        }

        return String(format: "%.1f GB", gibibytes)
    }

    private static func unavailableStatus() -> SystemMemoryStatus {
        SystemMemoryStatus(
            value: "N/A",
            subtitle: nil,
            usageRatio: 0,
            usedBytes: 0,
            availableBytes: 0,
            freeBytes: 0,
            activeBytes: 0,
            inactiveBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            totalBytes: 0,
            state: .unavailable
        )
    }
}

private enum SystemMemoryReader {
    static func current() -> SystemMemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        let statsResult = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(host, HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard statsResult == KERN_SUCCESS else {
            return nil
        }

        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else {
            return nil
        }

        let pageBytes = UInt64(pageSize)

        return SystemMemoryReading(
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            freeBytes: UInt64(stats.free_count) * pageBytes,
            activeBytes: UInt64(stats.active_count) * pageBytes,
            inactiveBytes: UInt64(stats.inactive_count) * pageBytes,
            wiredBytes: UInt64(stats.wire_count) * pageBytes,
            compressedBytes: UInt64(stats.compressor_page_count) * pageBytes
        )
    }
}
