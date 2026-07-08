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
        var candidateEvents = [TokenUsageEvent]()
        var updatedCursorKeys = Set<String>()

        for sessionFile in sessionFiles {
            guard !shouldCancel() else { break }

            let stateKey = Self.sourceStateKey(for: sessionFile.sessionID)
            let priorOffset = importState.byteOffsetBySource[stateKey] ?? 0
            let startingTurnIndex = importState.nextTurnIndexBySource[stateKey] ?? 0

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
                candidateEvents.append(event)
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
            writeImportState(importState)
        } catch {
            importedEvents = 0
            failedToWriteEvents = true
        }

        let skippedDuplicates = failedToWriteEvents ? 0 : candidateEvents.count - importedEvents
        let cursorAdvancedFiles = failedToWriteEvents ? 0 : updatedCursorKeys.count
        return TokenUsageClaudeCodeImportSummary(
            scannedFiles: scannedFiles,
            parsedTurns: parsedTurns,
            importedEvents: importedEvents,
            skippedDuplicateEvents: skippedDuplicates,
            cursorAdvancedFiles: cursorAdvancedFiles,
            failedToWriteEvents: failedToWriteEvents
        )
    }
}
