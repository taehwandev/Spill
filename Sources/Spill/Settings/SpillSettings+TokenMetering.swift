import Foundation

// MARK: - Keys

extension SettingKey where Value == Bool {
    static var tokenUsageShowAdvancedTools: Self { .bool("tokenUsageShowAdvancedTools", default: false) }
    static var tokenUsageDashboardOnboardingPreviewEnabled: Self {
        .bool("tokenUsageDashboardOnboardingPreviewEnabled", default: false)
    }

    /// Upload consent is stored per environment so switching environments never carries consent over.
    static func privateUsageUploadEnabled(for environment: PrivateUsageUploadEnvironment) -> Self {
        .bool("privateUsageUploadEnabled.\(environment.rawValue)", default: false)
    }
}

extension SettingKey where Value == TokenUsageInputScope {
    static var tokenUsageInputScope: Self {
        .stringEnum("tokenUsageInputScope", normalize: TokenUsageInputScope.normalized(rawValue:))
    }
}

extension SettingKey where Value == [String: String] {
    /// Display names the user gave to work items; local only, never uploaded.
    static var tokenUsageLocalAliases: Self {
        Self("tokenUsageLocalAliases", decode: { $0 as? [String: String] ?? [:] }, encode: { $0 })
    }
}

extension SettingKey where Value == Set<TokenUsageAITool> {
    static var hiddenTokenUsageAITools: Self {
        Self(
            "hiddenTokenUsageAITools",
            decode: { rawValues in
                Set((rawValues as? [String])?.compactMap(TokenUsageAITool.init(rawValue:)).filter(\.isDashboardTool) ?? [])
            },
            encode: { $0.map(\.rawValue).sorted() }
        )
    }
}

extension SettingKey where Value == Set<LocalAIToolKind> {
    static var hiddenLocalAIToolKinds: Self {
        Self(
            "hiddenLocalAIToolKinds",
            decode: { Set(($0 as? [String])?.compactMap(LocalAIToolKind.init(rawValue:)) ?? []) },
            encode: { $0.map(\.rawValue).sorted() }
        )
    }
}

extension SettingKey where Value == PrivateUsageUploadEnvironment {
    static var privateUsageUploadEnvironment: Self {
        .stringEnum("privateUsageUploadEnvironment", default: .defaultValue)
    }
}

// MARK: - Reloading from another process

extension SpillSettings {
    func reloadTokenUsageDashboardOnboardingPreviewFromDefaults() {
        reload(\.tokenUsageDashboardOnboardingPreviewEnabled, from: .tokenUsageDashboardOnboardingPreviewEnabled)
    }

    func reloadTokenUsageInputScopeFromDefaults() {
        reload(\.tokenUsageInputScope, from: .tokenUsageInputScope)
    }
}

// MARK: - AI tool visibility

/// A tool can be hidden from the dashboard (`TokenUsageAITool`) and from the local status panel
/// (`LocalAIToolKind`). Both views describe one choice, so each set is completed from the other.
struct AIToolVisibility: Equatable {
    var hiddenTokenUsageAITools: Set<TokenUsageAITool>
    var hiddenLocalAIToolKinds: Set<LocalAIToolKind>

    init(persistedTokenUsageAITools: Set<TokenUsageAITool>, persistedLocalAIToolKinds: Set<LocalAIToolKind>) {
        hiddenTokenUsageAITools = persistedTokenUsageAITools.union(
            persistedLocalAIToolKinds.compactMap(\.tokenUsageDashboardTool)
        )
        hiddenLocalAIToolKinds = persistedLocalAIToolKinds.union(
            persistedTokenUsageAITools.compactMap(\.localAIToolKind)
        )
    }
}

extension SpillSettings {
    func isTokenUsageAIToolVisible(_ tool: TokenUsageAITool) -> Bool {
        !hiddenTokenUsageAITools.contains(tool)
    }

    func isLocalAIToolVisible(_ kind: LocalAIToolKind) -> Bool {
        !hiddenLocalAIToolKinds.contains(kind)
    }

    func setLocalAITool(_ kind: LocalAIToolKind, isVisible: Bool) {
        if isVisible {
            hiddenLocalAIToolKinds.remove(kind)
        } else {
            hiddenLocalAIToolKinds.insert(kind)
        }
        if let tool = kind.tokenUsageDashboardTool {
            if isVisible {
                hiddenTokenUsageAITools.remove(tool)
            } else {
                hiddenTokenUsageAITools.insert(tool)
            }
        }
        DistributedNotificationCenter.default().post(
            name: Self.aiToolVisibilityDidChangeNotification,
            object: nil
        )
    }

    func reloadAIToolVisibilityFromDefaults() {
        defaults.synchronize()
        let visibility = Self.persistedAIToolVisibility(from: defaults)
        if hiddenTokenUsageAITools != visibility.hiddenTokenUsageAITools {
            hiddenTokenUsageAITools = visibility.hiddenTokenUsageAITools
        }
        if hiddenLocalAIToolKinds != visibility.hiddenLocalAIToolKinds {
            hiddenLocalAIToolKinds = visibility.hiddenLocalAIToolKinds
        }
    }

    static func persistedAIToolVisibility(from defaults: UserDefaults) -> AIToolVisibility {
        AIToolVisibility(
            persistedTokenUsageAITools: defaults.value(for: .hiddenTokenUsageAITools),
            persistedLocalAIToolKinds: defaults.value(for: .hiddenLocalAIToolKinds)
        )
    }

    /// The loaded visibility, after dropping local tool kinds this build no longer knows from storage.
    static func loadAIToolVisibility(from defaults: UserDefaults) -> AIToolVisibility {
        let storedLocalKinds = (defaults.storedObject(for: .hiddenLocalAIToolKinds) as? [String]) ?? []
        let supportedLocalKinds = defaults.value(for: .hiddenLocalAIToolKinds)
        if storedLocalKinds.sorted() != supportedLocalKinds.map(\.rawValue).sorted() {
            defaults.store(supportedLocalKinds, for: .hiddenLocalAIToolKinds)
        }
        return persistedAIToolVisibility(from: defaults)
    }
}

// MARK: - Private usage upload

extension SpillSettings {
    /// A build or launch configuration decides the environment; the stored choice is the fallback.
    static func loadPrivateUsageUploadEnvironment(from defaults: UserDefaults) -> PrivateUsageUploadEnvironment {
        PrivateUsageUploadEnvironment.resolvedFromConfiguration()
            ?? defaults.value(for: .privateUsageUploadEnvironment)
    }
}
