import Foundation

struct SpillProviderID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct SpillStatusItem: Identifiable, Hashable, Sendable {
    let id: String
    let providerID: SpillProviderID
    let stableKey: String
    let title: String
    let value: String
    let subtitle: String?
    let ownerName: String?
    let bundleIdentifier: String?
    let symbolName: String?
    let imageData: Data?
    let badgeText: String?
    let state: SpillStatusState
    let sortPriority: Int
    let actions: [SpillAction]

    init(
        id: String,
        providerID: SpillProviderID,
        stableKey: String? = nil,
        title: String,
        value: String,
        subtitle: String? = nil,
        ownerName: String? = nil,
        bundleIdentifier: String? = nil,
        symbolName: String? = nil,
        imageData: Data? = nil,
        badgeText: String? = nil,
        state: SpillStatusState = .normal,
        sortPriority: Int = 0,
        actions: [SpillAction] = []
    ) {
        self.id = id
        self.providerID = providerID
        self.stableKey = stableKey ?? "\(providerID.rawValue):\(id)"
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.symbolName = symbolName
        self.imageData = imageData
        self.badgeText = badgeText
        self.state = state
        self.sortPriority = sortPriority
        self.actions = actions
    }
}

enum SpillStatusState: Hashable, Sendable {
    case normal
    case active
    case warning
    case unavailable
    case refreshing
}

protocol SpillStatusProvider: Sendable {
    var id: String { get }
    var title: String { get }

    func snapshot() async -> [SpillStatusItem]
}
