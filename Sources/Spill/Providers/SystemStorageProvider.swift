import Foundation

struct SystemStorageReading: Hashable, Sendable {
    let totalBytes: UInt64
    let availableBytes: UInt64

    var usedBytes: UInt64 {
        totalBytes >= availableBytes ? totalBytes - availableBytes : 0
    }
}

struct SystemStorageStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let usageRatio: Double
    let usedBytes: UInt64
    let availableBytes: UInt64
    let totalBytes: UInt64
    let state: SpillStatusState

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "storage",
            providerID: SystemStorageProvider.providerID,
            title: "Storage",
            value: value,
            subtitle: subtitle,
            symbolName: "internaldrive",
            state: state,
            sortPriority: 15
        )
    }
}

struct SystemStorageProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.storage"
    let title = "Storage"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status().statusItem]
    }

    static func status(volumeURL: URL = URL(fileURLWithPath: "/")) -> SystemStorageStatus {
        status(from: SystemStorageReader.current(volumeURL: volumeURL))
    }

    static func status(from reading: SystemStorageReading?) -> SystemStorageStatus {
        guard let reading, reading.totalBytes > 0 else {
            return unavailableStatus()
        }

        let ratio = (Double(reading.usedBytes) / Double(reading.totalBytes)).clamped(to: 0...1)
        return SystemStorageStatus(
            value: SystemCPUProvider.percentText(ratio),
            subtitle: "\(SystemMemoryProvider.formatBytes(reading.availableBytes)) available of \(SystemMemoryProvider.formatBytes(reading.totalBytes))",
            usageRatio: ratio,
            usedBytes: reading.usedBytes,
            availableBytes: reading.availableBytes,
            totalBytes: reading.totalBytes,
            state: state(for: ratio)
        )
    }

    private static func state(for usageRatio: Double) -> SpillStatusState {
        if usageRatio >= 0.92 {
            return .warning
        }

        if usageRatio >= 0.8 {
            return .active
        }

        return .normal
    }

    private static func unavailableStatus() -> SystemStorageStatus {
        SystemStorageStatus(
            value: "N/A",
            subtitle: nil,
            usageRatio: 0,
            usedBytes: 0,
            availableBytes: 0,
            totalBytes: 0,
            state: .unavailable
        )
    }
}

private enum SystemStorageReader {
    static func current(volumeURL: URL) -> SystemStorageReading? {
        let values = try? volumeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])

        guard let totalCapacity = values?.volumeTotalCapacity, totalCapacity > 0 else {
            return nil
        }

        let availableCapacity = values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
            ?? 0

        return SystemStorageReading(
            totalBytes: UInt64(totalCapacity),
            availableBytes: UInt64(max(availableCapacity, 0))
        )
    }
}
