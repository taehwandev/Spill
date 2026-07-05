import AppKit
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
    private static let lifecycleMarkerRegistry = LifecycleMarkerRegistry()

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

        if lifecycleMarker.shouldReportPreviousUncleanExit(previousState) {
            capturePreviousUncleanExit(processRole: processRole)
        }
        lifecycleMarker.markRunning()
        rememberLifecycleMarker(lifecycleMarker)
    }

    static func markCleanShutdown(processRole: String) {
        guard isReportingEnabled else {
            return
        }

        if let lifecycleMarker = rememberedLifecycleMarker(processRole: processRole) {
            lifecycleMarker.markCleanShutdownIfCurrentRun()
        } else {
            LifecycleMarker(processRole: processRole).markCleanShutdown()
        }
    }

    static func markUncleanShutdownPending(processRole: String) {
        guard isReportingEnabled else {
            return
        }

        if let lifecycleMarker = rememberedLifecycleMarker(processRole: processRole) {
            lifecycleMarker.markRunning()
        } else {
            LifecycleMarker(processRole: processRole).markRunning()
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

    private static func capturePreviousUncleanExit(processRole: String) {
        SentrySDK.capture(message: "spill.previous_unclean_exit") { scope in
            scope.setTag(value: processRole, key: "process_role")
            scope.setTag(value: "previous_unclean_exit", key: "spill_lifecycle")
        }
    }

    private static func rememberLifecycleMarker(_ lifecycleMarker: LifecycleMarker) {
        lifecycleMarkerRegistry.remember(lifecycleMarker)
    }

    private static func rememberedLifecycleMarker(processRole: String) -> LifecycleMarker? {
        lifecycleMarkerRegistry.marker(processRole: processRole)
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

private final class LifecycleMarkerRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var markersByRole = [String: SpillCrashReporter.LifecycleMarker]()

    func remember(_ lifecycleMarker: SpillCrashReporter.LifecycleMarker) {
        lock.withLock {
            markersByRole[lifecycleMarker.processRole] = lifecycleMarker
        }
    }

    func marker(processRole: String) -> SpillCrashReporter.LifecycleMarker? {
        lock.withLock {
            markersByRole[processRole]
        }
    }
}

extension SpillCrashReporter {
    struct LifecycleState: Codable {
        let state: String
        let processRole: String
        let updatedAt: Date
        let launchID: String?
        let processID: Int32?
        let bundleIdentifier: String?

        enum CodingKeys: String, CodingKey {
            case state
            case processRole
            case updatedAt
            case launchID
            case processID
            case bundleIdentifier
        }

        init(
            state: String,
            processRole: String,
            updatedAt: Date,
            launchID: String? = nil,
            processID: Int32? = nil,
            bundleIdentifier: String? = nil
        ) {
            self.state = state
            self.processRole = processRole
            self.updatedAt = updatedAt
            self.launchID = launchID
            self.processID = processID
            self.bundleIdentifier = bundleIdentifier
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            state = try container.decode(String.self, forKey: .state)
            processRole = try container.decode(String.self, forKey: .processRole)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            launchID = try container.decodeIfPresent(String.self, forKey: .launchID)
            processID = try container.decodeIfPresent(Int32.self, forKey: .processID)
            bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        }

        static func running(
            processRole: String,
            launchID: String,
            processID: Int32,
            bundleIdentifier: String?
        ) -> Self {
            Self(
                state: "running",
                processRole: processRole,
                updatedAt: Date(),
                launchID: launchID,
                processID: processID,
                bundleIdentifier: bundleIdentifier
            )
        }

        static func cleanShutdown(
            processRole: String,
            launchID: String,
            processID: Int32,
            bundleIdentifier: String?
        ) -> Self {
            Self(
                state: "clean_shutdown",
                processRole: processRole,
                updatedAt: Date(),
                launchID: launchID,
                processID: processID,
                bundleIdentifier: bundleIdentifier
            )
        }
    }

    struct LifecycleMarker {
        let processRole: String
        let launchID: String
        let processID: Int32
        let bundleIdentifier: String?
        let markerURL: URL

        init(
            processRole: String,
            launchID: String = UUID().uuidString,
            processID: Int32 = Darwin.getpid(),
            bundleIdentifier: String? = Bundle.main.bundleIdentifier,
            markerURL: URL? = nil
        ) {
            self.processRole = processRole
            self.launchID = launchID
            self.processID = processID
            self.bundleIdentifier = bundleIdentifier
            self.markerURL = markerURL ?? Self.defaultMarkerURL(processRole: processRole)
        }

        func read() -> LifecycleState? {
            guard let data = try? Data(contentsOf: markerURL) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(LifecycleState.self, from: data)
        }

        func markRunning() {
            write(.running(
                processRole: processRole,
                launchID: launchID,
                processID: processID,
                bundleIdentifier: bundleIdentifier
            ))
        }

        func markCleanShutdown() {
            write(cleanShutdownState())
        }

        func markCleanShutdownIfCurrentRun() {
            guard read()?.launchID == launchID else {
                return
            }

            write(cleanShutdownState())
        }

        func shouldReportPreviousUncleanExit(_ previousState: LifecycleState?) -> Bool {
            guard previousState?.state == "running" else {
                return false
            }

            return !isRecordedProcessStillRunning(previousState)
        }

        private static func defaultMarkerURL(processRole: String) -> URL {
            AppDirectories.spillApplicationSupportDirectory()
                .appendingPathComponent("diagnostics", isDirectory: true)
                .appendingPathComponent("lifecycle-\(processRole).json")
        }

        private func cleanShutdownState() -> LifecycleState {
            .cleanShutdown(
                processRole: processRole,
                launchID: launchID,
                processID: processID,
                bundleIdentifier: bundleIdentifier
            )
        }

        private func isRecordedProcessStillRunning(_ state: LifecycleState?) -> Bool {
            guard let state,
                  let recordedProcessID = state.processID,
                  recordedProcessID > 0,
                  recordedProcessID != processID
            else {
                return false
            }

            errno = 0
            let recordedPID = pid_t(recordedProcessID)
            guard Darwin.kill(recordedPID, 0) == 0 || errno == EPERM else {
                return false
            }

            guard let recordedBundleIdentifier = state.bundleIdentifier,
                  !recordedBundleIdentifier.isEmpty
            else {
                return true
            }

            guard let runningApplication = NSRunningApplication(processIdentifier: recordedPID) else {
                return true
            }

            return runningApplication.bundleIdentifier == recordedBundleIdentifier
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
