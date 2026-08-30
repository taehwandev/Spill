import Foundation

extension TokenUsageAntigravityImporter {
    @discardableResult
    func importRecentEvents(
        into store: TokenUsageStore,
        since startDate: Date,
        shouldCancel: () -> Bool = { false }
    ) -> TokenUsageAntigravityImportSummary {
        let sources = discoverConversationDatabases(modifiedSince: startDate)
        let labelTimeline = readLabelTimeline()
        var importState = readImportState()
        var scannedRows = 0
        var parsedEvents = 0
        var unsupportedRecords = 0
        var candidateEvents = [TokenUsageEvent]()
        var skippedDuplicates = 0
        var splitOutputFallbackEvents = 0
        var cursorAdvancedDatabases = Set<String>()
        var scannedDatabases = 0
        var scannedModificationDates = [String: Date]()

        for source in sources {
            guard !shouldCancel() else {
                break
            }

            let sourceKey = Self.sourceStateKey(for: source)
            if lastScannedModificationDateBySource[sourceKey] == source.modifiedAt {
                continue
            }
            let previousMaxIndex = importState.maxGenerationIndexBySource[sourceKey]
            let readResult = readGenerationRecords(from: source, after: previousMaxIndex)
            scannedDatabases += 1
            scannedRows += readResult.scannedRowCount
            unsupportedRecords += readResult.unsupportedRecordCount
            var cancelledDuringSource = false
            var maxEventIndex: Int?

            for record in readResult.records {
                guard !shouldCancel() else {
                    cancelledDuringSource = true
                    break
                }

                if record.usage.usedSplitOutputFallback {
                    splitOutputFallbackEvents += 1
                }
                guard let event = event(from: record, source: source, labelTimeline: labelTimeline) else {
                    unsupportedRecords += 1
                    continue
                }
                parsedEvents += 1
                candidateEvents.append(event)
                maxEventIndex = max(maxEventIndex ?? record.index, record.index)
            }

            if cancelledDuringSource {
                break
            }

            if readResult.didReadDatabase {
                scannedModificationDates[sourceKey] = source.modifiedAt
            }

            if let maxEventIndex,
               maxEventIndex != previousMaxIndex,
               maxEventIndex >= 0 {
                importState.maxGenerationIndexBySource[sourceKey] = maxEventIndex
                cursorAdvancedDatabases.insert(sourceKey)
            }
        }

        guard !shouldCancel() else {
            let summary = TokenUsageAntigravityImportSummary(
                scannedDatabases: scannedDatabases,
                scannedGenerationRows: scannedRows,
                parsedUsageEvents: parsedEvents,
                importedEvents: 0,
                skippedDuplicateEvents: skippedDuplicates,
                unsupportedRecords: unsupportedRecords,
                splitOutputFallbackEvents: splitOutputFallbackEvents,
                cursorAdvancedDatabases: 0,
                failedToWriteEvents: false
            )
            writeDiagnostic(summary)
            return summary
        }

        let importedEvents: Int
        var persistedCursorAdvancedDatabases = 0
        var failedToWriteEvents = false
        do {
            importedEvents = try store.appendEventsWithoutLoading(candidateEvents)
            skippedDuplicates += candidateEvents.count - importedEvents
            writeImportState(importState)
            lastScannedModificationDateBySource.merge(scannedModificationDates) { _, latest in latest }
            persistedCursorAdvancedDatabases = cursorAdvancedDatabases.count
        } catch {
            importedEvents = 0
            failedToWriteEvents = true
        }

        let summary = TokenUsageAntigravityImportSummary(
            scannedDatabases: scannedDatabases,
            scannedGenerationRows: scannedRows,
            parsedUsageEvents: parsedEvents,
            importedEvents: importedEvents,
            skippedDuplicateEvents: skippedDuplicates,
            unsupportedRecords: unsupportedRecords,
            splitOutputFallbackEvents: splitOutputFallbackEvents,
            cursorAdvancedDatabases: persistedCursorAdvancedDatabases,
            failedToWriteEvents: failedToWriteEvents
        )
        writeDiagnostic(summary)
        return summary
    }
}
