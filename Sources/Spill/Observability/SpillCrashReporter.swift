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

    static func start(processRole: String) {
        guard ProcessInfo.processInfo.environment[disabledEnvironmentKey] != "1",
              ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] != "1",
              let configuration = Configuration.current
        else {
            return
        }

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
