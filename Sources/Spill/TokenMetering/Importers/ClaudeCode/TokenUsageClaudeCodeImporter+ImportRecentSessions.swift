import Foundation

extension TokenUsageClaudeCodeImporter {
    @discardableResult
    func importRecentSessions(
        into store: TokenUsageStore,
        shouldCancel: () -> Bool = { false }
    ) -> TokenUsageClaudeCodeImportSummary {
        let sessionFiles = discoverSessionFiles()
        let labelTimeline = readLabelTimeline()
        var importState = readImportState()

        var scannedFiles = 0
        var parsedTurns = 0
        var invalidEvents = 0
        var candidateEvents = [TokenUsageEvent]()
        var updatedCursorKeys = Set<String>()
        var prunedRequestIDs = false
        let currentDate = now()

        for sessionFile in sessionFiles {
            guard !shouldCancel() else { break }

            let stateKey = Self.sourceStateKey(for: sessionFile.sessionID)
            let priorOffset = importState.byteOffsetBySource[stateKey] ?? 0
            let startingTurnIndex = importState.nextTurnIndexBySource[stateKey] ?? 0

            // A transcript already read to its end needs only a stat, not an open and read. Once
            // it has been idle for a day no duplicate requestId can straddle a batch boundary, so
            // its dedup set is dropped while the byte cursor and turn index are kept.
            // FileManager attributes, not URL resource values: discovery reuses URL instances for
            // up to a minute and URLs cache resource values, which would report a stale size.
            let attributes = try? fileManager.attributesOfItem(atPath: sessionFile.url.path)
            let fileSize = (attributes?[.size] as? NSNumber)?.intValue
            if priorOffset > 0, fileSize == priorOffset {
                scannedFiles += 1
                if let modifiedAt = attributes?[.modificationDate] as? Date,
                   currentDate.timeIntervalSince(modifiedAt) > Self.emittedRequestIDRetention,
                   importState.emittedRequestIDsBySource.removeValue(forKey: stateKey) != nil {
                    prunedRequestIDs = true
                }
                continue
            }

            let (turns, newOffset, nextTurnIndex) = parseTurns(
                from: sessionFile.url,
                after: priorOffset,
                sourceSessionID: sessionFile.sessionID,
                startingTurnIndex: startingTurnIndex
            )
            scannedFiles += 1
            parsedTurns += turns.count

            for turn in turns {
                guard !shouldCancel() else { break }
                // Cross-batch Bug #2 dedup: skip requestIds already emitted for this session.
                // Claude Code writes the same requestId 2-3x with slightly different timestamps,
                // causing different span_ids across incremental read batches.
                if !turn.requestId.isEmpty,
                   importState.emittedRequestIDsBySource[stateKey]?.contains(turn.requestId) == true {
                    continue
                }
                guard let event = event(from: turn, labelTimeline: labelTimeline) else { continue }
                // The store validates the whole batch up front and rejects all of
                // it on the first bad event, which would also skip the state write
                // and re-fail forever. Drop invalid events here, one at a time.
                if (try? event.validate()) == nil {
                    invalidEvents += 1
                } else {
                    candidateEvents.append(event)
                }
                if !turn.requestId.isEmpty {
                    importState.emittedRequestIDsBySource[stateKey, default: []].insert(turn.requestId)
                }
            }

            if newOffset > priorOffset {
                importState.byteOffsetBySource[stateKey] = newOffset
                importState.nextTurnIndexBySource[stateKey] = nextTurnIndex
                updatedCursorKeys.insert(stateKey)
            }
        }

        guard !shouldCancel() else {
            return TokenUsageClaudeCodeImportSummary(
                scannedFiles: scannedFiles,
                parsedTurns: parsedTurns,
                importedEvents: 0,
                skippedDuplicateEvents: 0,
                cursorAdvancedFiles: 0,
                failedToWriteEvents: false
            )
        }

        let importedEvents: Int
        var failedToWriteEvents = false
        do {
            importedEvents = try store.appendEventsWithoutLoading(candidateEvents)
            if !updatedCursorKeys.isEmpty || prunedRequestIDs {
                writeImportState(importState)
            }
        } catch {
            importedEvents = 0
            failedToWriteEvents = true
        }

        let skippedDuplicates = failedToWriteEvents ? 0 : candidateEvents.count - importedEvents
        let cursorAdvancedFiles = failedToWriteEvents ? 0 : updatedCursorKeys.count
        let summary = TokenUsageClaudeCodeImportSummary(
            scannedFiles: scannedFiles,
            parsedTurns: parsedTurns,
            importedEvents: importedEvents,
            skippedDuplicateEvents: skippedDuplicates,
            cursorAdvancedFiles: cursorAdvancedFiles,
            failedToWriteEvents: failedToWriteEvents,
            invalidEvents: invalidEvents
        )
        writeDiagnostic(summary)
        return summary
    }

    static let emittedRequestIDRetention: TimeInterval = 24 * 60 * 60
}
