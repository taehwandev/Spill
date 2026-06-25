import Foundation
import Sentry

enum SpillCrashReporter {
    private static let dsnEnvironmentKey = "SPILL_SENTRY_DSN"
    private static let dsnInfoKey = "SPILLSentryDSN"
    private static let environmentEnvironmentKey = "SPILL_SENTRY_ENVIRONMENT"
    private static let environmentInfoKey = "SPILLSentryEnvironment"
    private static let releaseEnvironmentKey = "SPILL_SENTRY_RELEASE"
    private static let releaseInfoKey = "SPILLSentryRelease"
    private static let distEnvironmentKey = "SPILL_SENTRY_DIST"
    private static let distInfoKey = "SPILLSentryDist"
    private static let gitShaInfoKey = "SPILLGitCommitSHA"
    private static let disabledEnvironmentKey = "SPILL_SENTRY_DISABLED"

    static var isReportingEnabled: Bool {
        ProcessInfo.processInfo.environment[disabledEnvironmentKey] != "1"
            && ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] != "1"
    }

    static func start(processRole: String) {
        guard isReportingEnabled,
              let configuration = Configuration.current
        else {
            return
        }

        let lifecycleMarker = LifecycleMarker(processRole: processRole)
        let previousState = lifecycleMarker.read()

        SentrySDK.start { options in
            options.dsn = configuration.dsn
            options.debug = false
            options.diagnosticLevel = .error
            options.sendDefaultPii = false
            options.releaseName = configuration.releaseName
            options.dist = configuration.dist
            options.environment = configuration.environment
            options.tracesSampleRate = 0
            options.enableAppHangTracking = true
            options.enableMetricKit = false
            options.enableMetricKitRawPayload = false
            options.enableAutoSessionTracking = false
            options.enableAutoBreadcrumbTracking = false
            options.beforeSend = { event in
                event.breadcrumbs = []
                event.tags = sanitizedTags(
                    existingTags: event.tags,
                    processRole: processRole,
                    gitCommitSHA: configuration.gitCommitSHA
                )
                event.extra = nil
                return event
            }
        }

        if previousState?.state == "running" {
            capturePreviousUncleanExit(processRole: processRole)
        }
        lifecycleMarker.markRunning()
    }

    static func markCleanShutdown(processRole: String) {
        guard isReportingEnabled else {
            return
        }

        LifecycleMarker(processRole: processRole).markCleanShutdown()
    }

    static func markUncleanShutdownPending(processRole: String) {
        guard isReportingEnabled else {
            return
        }

        LifecycleMarker(processRole: processRole).markRunning()
    }

    private static func sanitizedTags(
        existingTags: [String: String]?,
        processRole: String,
        gitCommitSHA: String?
    ) -> [String: String] {
        var tags = existingTags ?? [:]
        tags["process_role"] = processRole
        if let gitCommitSHA {
            tags["git_commit_sha"] = gitCommitSHA
        }
        return tags
    }

    private static func capturePreviousUncleanExit(processRole: String) {
        SentrySDK.capture(message: "spill.previous_unclean_exit") { scope in
            scope.setTag(value: processRole, key: "process_role")
            scope.setTag(value: "previous_unclean_exit", key: "spill_lifecycle")
        }
    }

}

private extension SpillCrashReporter {
    struct Configuration {
        let dsn: String
        let environment: String
        let releaseName: String
        let dist: String?
        let gitCommitSHA: String?

        static var current: Self? {
            guard let dsn = configuredValue(environmentKey: dsnEnvironmentKey, infoKey: dsnInfoKey),
                  dsn.hasPrefix("https://")
            else {
                return nil
            }

            return Self(
                dsn: dsn,
                environment: configuredValue(
                    environmentKey: environmentEnvironmentKey,
                    infoKey: environmentInfoKey
                ) ?? "development",
                releaseName: configuredValue(
                    environmentKey: releaseEnvironmentKey,
                    infoKey: releaseInfoKey
                ) ?? defaultReleaseName(),
                dist: configuredValue(environmentKey: distEnvironmentKey, infoKey: distInfoKey),
                gitCommitSHA: normalizedOptional(Bundle.main.object(forInfoDictionaryKey: gitShaInfoKey) as? String)
            )
        }

        private static func defaultReleaseName() -> String {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? version
            return "spill@\(version)+\(build)"
        }

        private static func configuredValue(environmentKey: String, infoKey: String) -> String? {
            if let value = normalizedOptional(ProcessInfo.processInfo.environment[environmentKey]) {
                return value
            }
            return normalizedOptional(Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)
        }

        private static func normalizedOptional(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("__") else {
                return nil
            }
            return trimmed
        }
    }
}

private extension SpillCrashReporter {
    struct LifecycleState: Codable {
        let state: String
        let processRole: String
        let updatedAt: Date

        static func running(processRole: String) -> Self {
            Self(state: "running", processRole: processRole, updatedAt: Date())
        }

        static func cleanShutdown(processRole: String) -> Self {
            Self(state: "clean_shutdown", processRole: processRole, updatedAt: Date())
        }
    }

    struct LifecycleMarker {
        let processRole: String

        func read() -> LifecycleState? {
            guard let data = try? Data(contentsOf: markerURL) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(LifecycleState.self, from: data)
        }

        func markRunning() {
            write(.running(processRole: processRole))
        }

        func markCleanShutdown() {
            write(.cleanShutdown(processRole: processRole))
        }

        private var markerURL: URL {
            AppDirectories.spillApplicationSupportDirectory()
                .appendingPathComponent("diagnostics", isDirectory: true)
                .appendingPathComponent("lifecycle-\(processRole).json")
        }

        private func write(_ state: LifecycleState) {
            do {
                try FileManager.default.createDirectory(
                    at: markerURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                try data.write(to: markerURL, options: [.atomic])
            } catch {
                return
            }
        }
    }
}
