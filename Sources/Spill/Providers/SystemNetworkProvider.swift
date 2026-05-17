import Darwin
import Foundation

struct SystemNetworkReading: Hashable, Sendable {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: TimeInterval
    let activeInterfaceCount: Int
}

struct SystemNetworkStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let activityRatio: Double
    let receivedActivityRatio: Double
    let sentActivityRatio: Double
    let receivedBytesPerSecond: Double
    let sentBytesPerSecond: Double
    let totalBytesPerSecond: Double
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64
    let activeInterfaceCount: Int
    let sampleInterval: TimeInterval
    let state: SpillStatusState
    let symbolName: String

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "network",
            providerID: SystemNetworkProvider.providerID,
            title: "Network",
            value: value,
            subtitle: subtitle,
            symbolName: symbolName,
            state: state,
            sortPriority: 15
        )
    }
}

struct SystemNetworkProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    private static let fullScaleBytesPerSecond = 10_000_000.0
    private static let activeBytesPerSecond = 1_000.0

    let id = "system.network"
    let title = "Network"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status(previous: nil, current: Self.currentReading()).statusItem]
    }

    static func status() -> SystemNetworkStatus {
        status(previous: nil, current: currentReading())
    }

    static func status(previous: SystemNetworkReading?, current: SystemNetworkReading?) -> SystemNetworkStatus {
        guard let current else {
            return unavailableStatus()
        }

        guard let previous, current.timestamp > previous.timestamp else {
            return samplingStatus(from: current)
        }

        let sampleInterval = current.timestamp - previous.timestamp
        let receivedDelta = byteDelta(current.receivedBytes, previous.receivedBytes)
        let sentDelta = byteDelta(current.sentBytes, previous.sentBytes)
        let receivedBytesPerSecond = Double(receivedDelta) / sampleInterval
        let sentBytesPerSecond = Double(sentDelta) / sampleInterval
        let totalBytesPerSecond = receivedBytesPerSecond + sentBytesPerSecond

        return SystemNetworkStatus(
            value: "↓ \(formatRate(receivedBytesPerSecond))",
            subtitle: "↑ \(formatRate(sentBytesPerSecond))",
            activityRatio: activityRatio(for: totalBytesPerSecond),
            receivedActivityRatio: activityRatio(for: receivedBytesPerSecond),
            sentActivityRatio: activityRatio(for: sentBytesPerSecond),
            receivedBytesPerSecond: receivedBytesPerSecond,
            sentBytesPerSecond: sentBytesPerSecond,
            totalBytesPerSecond: totalBytesPerSecond,
            totalReceivedBytes: current.receivedBytes,
            totalSentBytes: current.sentBytes,
            activeInterfaceCount: current.activeInterfaceCount,
            sampleInterval: sampleInterval,
            state: state(for: totalBytesPerSecond),
            symbolName: "network"
        )
    }

    static func currentReading() -> SystemNetworkReading? {
        SystemNetworkReader.current()
    }

    static func formatRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "N/A"
        }

        if bytesPerSecond < 1_000 {
            return "\(Int(bytesPerSecond.rounded())) B/s"
        }

        if bytesPerSecond < 1_000_000 {
            return compactRate(bytesPerSecond / 1_000, unit: "KB/s")
        }

        if bytesPerSecond < 1_000_000_000 {
            return compactRate(bytesPerSecond / 1_000_000, unit: "MB/s")
        }

        return compactRate(bytesPerSecond / 1_000_000_000, unit: "GB/s")
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1_000 {
            return "\(bytes) B"
        }

        if bytes < 1_000_000 {
            return compactRate(Double(bytes) / 1_000, unit: "KB")
        }

        if bytes < 1_000_000_000 {
            return compactRate(Double(bytes) / 1_000_000, unit: "MB")
        }

        return compactRate(Double(bytes) / 1_000_000_000, unit: "GB")
    }

    private static func samplingStatus(from current: SystemNetworkReading) -> SystemNetworkStatus {
        SystemNetworkStatus(
            value: "Sampling",
            subtitle: "Waiting for second sample",
            activityRatio: 0,
            receivedActivityRatio: 0,
            sentActivityRatio: 0,
            receivedBytesPerSecond: 0,
            sentBytesPerSecond: 0,
            totalBytesPerSecond: 0,
            totalReceivedBytes: current.receivedBytes,
            totalSentBytes: current.sentBytes,
            activeInterfaceCount: current.activeInterfaceCount,
            sampleInterval: 0,
            state: .refreshing,
            symbolName: "network"
        )
    }

    private static func unavailableStatus() -> SystemNetworkStatus {
        SystemNetworkStatus(
            value: "N/A",
            subtitle: nil,
            activityRatio: 0,
            receivedActivityRatio: 0,
            sentActivityRatio: 0,
            receivedBytesPerSecond: 0,
            sentBytesPerSecond: 0,
            totalBytesPerSecond: 0,
            totalReceivedBytes: 0,
            totalSentBytes: 0,
            activeInterfaceCount: 0,
            sampleInterval: 0,
            state: .unavailable,
            symbolName: "network"
        )
    }

    private static func state(for totalBytesPerSecond: Double) -> SpillStatusState {
        totalBytesPerSecond >= activeBytesPerSecond ? .active : .normal
    }

    private static func activityRatio(for totalBytesPerSecond: Double) -> Double {
        (totalBytesPerSecond / fullScaleBytesPerSecond).clamped(to: 0...1)
    }

    private static func byteDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : current
    }

    private static func compactRate(_ value: Double, unit: String) -> String {
        if value >= 10 {
            return "\(Int(value.rounded())) \(unit)"
        }

        return String(format: "%.1f %@", value, unit)
    }
}

private enum SystemNetworkReader {
    static func current() -> SystemNetworkReading? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer {
            freeifaddrs(interfaces)
        }

        var seenInterfaces = Set<String>()
        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var activeInterfaceCount = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interfacePointer = cursor {
            let interface = interfacePointer.pointee
            cursor = interface.ifa_next

            guard let address = interface.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  let interfaceName = interface.ifa_name,
                  let interfaceData = interface.ifa_data
            else {
                continue
            }

            let flags = interface.ifa_flags
            guard flags & UInt32(IFF_UP) != 0,
                  flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }

            let name = String(cString: interfaceName)
            guard !seenInterfaces.contains(name) else {
                continue
            }

            let data = interfaceData.assumingMemoryBound(to: if_data.self).pointee
            receivedBytes = receivedBytes.saturatingAdd(UInt64(data.ifi_ibytes))
            sentBytes = sentBytes.saturatingAdd(UInt64(data.ifi_obytes))
            activeInterfaceCount += 1
            seenInterfaces.insert(name)
        }

        guard activeInterfaceCount > 0 else {
            return nil
        }

        return SystemNetworkReading(
            receivedBytes: receivedBytes,
            sentBytes: sentBytes,
            timestamp: ProcessInfo.processInfo.systemUptime,
            activeInterfaceCount: activeInterfaceCount
        )
    }
}
