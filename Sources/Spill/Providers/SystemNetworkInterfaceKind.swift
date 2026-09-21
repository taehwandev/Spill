import Foundation
import Network

enum SystemNetworkInterfaceKind: String, Hashable, Sendable {
    case wifi
    case ethernet
    case other

    static func current() -> Self? {
        NetworkPathObserver.shared.currentKind()
    }

    var label: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .ethernet: "Ethernet"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .other: "network"
        }
    }
}

/// A path-change callback caches the preferred interface without polling.
private final class NetworkPathObserver: @unchecked Sendable {
    static let shared = NetworkPathObserver()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var kind: SystemNetworkInterfaceKind?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let nextKind: SystemNetworkInterfaceKind?
            if path.status == .satisfied,
               let preferred = path.availableInterfaces.first(where: { path.usesInterfaceType($0.type) }) {
                switch preferred.type {
                case .wifi: nextKind = .wifi
                case .wiredEthernet: nextKind = .ethernet
                default: nextKind = .other
                }
            } else {
                nextKind = nil
            }
            self?.setKind(nextKind)
        }
        monitor.start(queue: DispatchQueue(label: "Spill.NetworkPath"))
    }

    deinit {
        monitor.cancel()
    }

    func currentKind() -> SystemNetworkInterfaceKind? {
        lock.lock()
        defer { lock.unlock() }
        return kind
    }

    private func setKind(_ value: SystemNetworkInterfaceKind?) {
        lock.lock()
        kind = value
        lock.unlock()
    }
}
