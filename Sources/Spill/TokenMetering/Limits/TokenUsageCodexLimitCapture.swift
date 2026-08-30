import Foundation

/// Reads the newest Codex `rate_limits` snapshots from the session files
/// Codex itself writes on every turn. Codex is the one tool whose remaining
/// percentages are server-authoritative and already on disk, so no adapter
/// change or network call is needed — the capture rides the existing
/// collection cycle and reads only the tails of the most recent files.
///
/// The set of gauges is data-driven: one entry per named limit found
/// (`limit_id` + window), so a new account limit appears without a code
/// change. Each newest `limit_id` payload replaces only its own complete
/// group, so an explicit null retires a sibling without erasing other named
/// pools.
struct TokenUsageCodexLimitCapture {
    let sessionsDirectory: URL
    let fileManager: FileManager
    /// Only the newest few files can contain the newest snapshot; the tail
    /// bound keeps a capture pass to a handful of small reads even on
    /// installs with hundreds of session files.
    let scannedFileLimit: Int
    let tailByteLimit: Int

    init(
        sessionsDirectory: URL = TokenUsageCodexLimitCapture.defaultSessionsDirectory(),
        fileManager: FileManager = .default,
        scannedFileLimit: Int = 5,
        tailByteLimit: Int = 262_144
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.fileManager = fileManager
        self.scannedFileLimit = scannedFileLimit
        self.tailByteLimit = tailByteLimit
    }

    static func defaultSessionsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    /// Scans the newest session-file tails and writes the freshest snapshot
    /// per named limit into the store. Missing directories, unreadable files,
    /// or absent rate-limit lines simply capture nothing.
    ///
    /// One `rate_limits` payload is complete for its own `limit_id`: a plan
    /// with no five-hour window sends `secondary: null`. Replacing that small
    /// group retires the absent sibling while independent named pools remain.
    func captureLatestSnapshots(into store: TokenUsageLimitSnapshotStore) {
        var newestByKey: [String: (timestamp: Date, snapshots: [TokenUsageLimitSnapshot])] = [:]

        for fileURL in newestSessionFiles() {
            for line in rateLimitLines(in: fileURL) {
                guard let parsed = Self.parseRateLimitLine(line) else {
                    continue
                }
                let existing = newestByKey[parsed.groupKey]
                if existing == nil || parsed.timestamp > existing!.timestamp {
                    newestByKey[parsed.groupKey] = (parsed.timestamp, parsed.snapshots)
                }
            }
        }

        guard !newestByKey.isEmpty else {
            return
        }
        let groups = newestByKey.keys.sorted().compactMap { groupKey in
            newestByKey[groupKey].map {
                TokenUsageLimitSnapshotStore.CompleteGroup(
                    keyPrefix: "\(groupKey):",
                    capturedAt: $0.timestamp,
                    snapshots: $0.snapshots
                )
            }
        }
        store.replaceCompleteGroups(for: .codex, with: groups)
    }
}

extension TokenUsageCodexLimitCapture {
    struct ParsedRateLimits {
        /// One rate_limits payload covers one limit group (`limit_id`).
        let groupKey: String
        let timestamp: Date
        let snapshots: [TokenUsageLimitSnapshot]
    }

    /// Parses one session JSONL line shaped as
    /// `{timestamp, payload: {type: "token_count", rate_limits: {...}}}`.
    /// Only numeric limit fields, safe identifiers, and timestamps are read.
    ///
    /// `capturedAt` is the line's own timestamp — the moment the reading was
    /// true — not the moment Spill happened to scan the file. Stamping the
    /// scan time made every Codex gauge look permanently fresh no matter how
    /// long ago Codex last ran, which is precisely what the as-of display
    /// exists to prevent.
    static func parseRateLimitLine(_ line: String) -> ParsedRateLimits? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestampValue = object["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter.parseTokenUsageDate(from: timestampValue),
              let payload = object["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any]
        else {
            return nil
        }

        let capturedAt = timestamp
        let limitID = (rateLimits["limit_id"] as? String) ?? "codex"
        let limitName = rateLimits["limit_name"] as? String
        var snapshots: [TokenUsageLimitSnapshot] = []

        for windowField in ["primary", "secondary"] {
            guard let window = rateLimits[windowField] as? [String: Any],
                  let usedPercent = Self.doubleValue(window["used_percent"])
            else {
                continue
            }
            let windowMinutes = Self.intValue(window["window_minutes"])
            let resetsAt = Self.doubleValue(window["resets_at"]).map(Date.init(timeIntervalSince1970:))
            snapshots.append(
                TokenUsageLimitSnapshot(
                    aiTool: .codex,
                    limitKey: "\(limitID):\(windowField)",
                    label: Self.displayLabel(
                        limitID: limitID,
                        limitName: limitName,
                        windowMinutes: windowMinutes
                    ),
                    usedPercent: max(0, min(100, usedPercent)),
                    remainingCredits: nil,
                    windowMinutes: windowMinutes,
                    resetsAt: resetsAt,
                    capturedAt: capturedAt,
                    source: .serverExact
                )
            )
        }

        // Credits stay a detail reading (tooltip-level per the PRD), captured
        // only when the account actually has a balance to show.
        if let credits = rateLimits["credits"] as? [String: Any],
           credits["unlimited"] as? Bool != true,
           let balance = Self.intValue(credits["balance"]),
           credits["has_credits"] as? Bool == true || balance > 0 {
            snapshots.append(
                TokenUsageLimitSnapshot(
                    aiTool: .codex,
                    limitKey: "\(limitID):credits",
                    label: "Credits",
                    usedPercent: nil,
                    remainingCredits: balance,
                    windowMinutes: nil,
                    resetsAt: nil,
                    capturedAt: capturedAt,
                    source: .serverExact
                )
            )
        }

        guard !snapshots.isEmpty else {
            return nil
        }
        return ParsedRateLimits(groupKey: limitID, timestamp: timestamp, snapshots: snapshots)
    }

    /// "Weekly" / "5-hour" for the overall Codex pool; named pools use only
    /// their server name or humanized identifier. The chip adds the compact
    /// window suffix, keeping pool identity and time basis separate.
    static func displayLabel(limitID: String, limitName: String?, windowMinutes: Int?) -> String {
        if let limitName, !limitName.isEmpty {
            return limitName
        }

        let windowLabel: String
        if let windowMinutes {
            switch windowMinutes {
            case 10_080:
                windowLabel = "Weekly"
            case 300:
                windowLabel = "5-hour"
            case let minutes where minutes % 1_440 == 0:
                windowLabel = "\(minutes / 1_440)-day"
            case let minutes where minutes % 60 == 0:
                windowLabel = "\(minutes / 60)-hour"
            default:
                windowLabel = "\(windowMinutes)-minute"
            }
        } else {
            windowLabel = "Limit"
        }

        guard limitID != "codex" else {
            return windowLabel
        }
        let humanizedID = limitID
            .split(separator: "-")
            .map { $0.count <= 3 ? $0.uppercased() : $0.capitalized }
            .joined(separator: " ")
        return humanizedID
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return (value as? String).flatMap(Double.init)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return (value as? String).flatMap(Int.init)
    }
}

private extension TokenUsageCodexLimitCapture {
    func newestSessionFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [(url: URL, modified: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else {
                continue
            }
            candidates.append((url, values?.contentModificationDate ?? .distantPast))
        }
        return candidates
            .sorted { $0.modified > $1.modified }
            .prefix(scannedFileLimit)
            .map(\.url)
    }

    /// Tail-reads one file and returns only the lines that can carry a
    /// rate-limit snapshot, newest last.
    func rateLimitLines(in fileURL: URL) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return []
        }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > UInt64(tailByteLimit) ? size - UInt64(tailByteLimit) : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8)
        else {
            return []
        }

        // A mid-line tail start is fine: the partial first line fails JSON
        // parsing and is skipped.
        return text.split(separator: "\n").compactMap { line in
            line.contains("\"rate_limits\"") ? String(line) : nil
        }
    }
}
