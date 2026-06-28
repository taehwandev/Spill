struct TokenMeteringAdapterConnectionStatus: Equatable, Sendable {
    let scriptInstalled: Bool
    let hookConfigured: Bool

    var isActive: Bool {
        scriptInstalled && hookConfigured
    }

    static let missing = TokenMeteringAdapterConnectionStatus(scriptInstalled: false, hookConfigured: false)
}
