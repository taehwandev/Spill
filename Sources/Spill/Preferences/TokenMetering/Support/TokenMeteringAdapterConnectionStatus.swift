struct TokenMeteringAdapterConnectionStatus: Equatable {
    let scriptInstalled: Bool
    let hookConfigured: Bool

    var isActive: Bool {
        scriptInstalled && hookConfigured
    }

    static let missing = TokenMeteringAdapterConnectionStatus(scriptInstalled: false, hookConfigured: false)
}
