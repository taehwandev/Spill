import Foundation

extension TokenUsageAntigravityImporter {
    static func generationCreatedAt(from data: Data) -> Date? {
        let envelope = [UInt8](data)
        guard let generation = firstLengthDelimitedField(1, in: envelope),
              let timestampContainer = firstLengthDelimitedField(9, in: generation),
              let timestampMessage = firstLengthDelimitedField(4, in: timestampContainer),
              let seconds = firstVarintField(1, in: timestampMessage)
        else {
            return nil
        }

        let minimumSeconds: UInt64 = 946_684_800
        let maximumSeconds: UInt64 = 4_102_444_800
        guard seconds >= minimumSeconds, seconds < maximumSeconds else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    static func usageRecord(from data: Data) -> UsageRecord? {
        let envelope = [UInt8](data)
        guard let generation = firstLengthDelimitedField(1, in: envelope),
              let usage = firstLengthDelimitedField(4, in: generation)
        else {
            return nil
        }

        let usageFields = varintFieldTotals(in: usage)
        // Observed AGY gen_metadata usage fields: 2 = uncached input,
        // 5 = cached input, 3 = aggregate output. Some records also expose
        // split output components in 9/10; use those only when aggregate
        // output is absent so known aggregate totals remain the source of truth.
        let uncachedInput = safeToken(usageFields[2])
        let cachedInput = safeToken(usageFields[5])
        let aggregateOutput = safeToken(usageFields[3])
        guard let splitOutput = safeAdd(safeToken(usageFields[9]), safeToken(usageFields[10])) else {
            return nil
        }
        let output = aggregateOutput > 0 ? aggregateOutput : splitOutput
        let usedSplitOutputFallback = aggregateOutput == 0 && splitOutput > 0
        guard let input = safeAdd(uncachedInput, cachedInput) else {
            return nil
        }
        guard input > 0 || output > 0 else {
            return nil
        }

        let request = firstLengthDelimitedField(3, in: envelope)
        // Observed AGY model fields: generation.19 is preferred, request.28 is
        // a fallback when the generation envelope omits the model string.
        let model = firstUTF8Field(19, in: generation)
            ?? request.flatMap { firstUTF8Field(28, in: $0) }
            ?? "antigravity-unknown"
        return UsageRecord(
            inputTokens: input,
            outputTokens: output,
            model: model,
            usedSplitOutputFallback: usedSplitOutputFallback
        )
    }
}
