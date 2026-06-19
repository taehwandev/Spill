import SwiftUI

struct TokenUsageHistoryImportToolRow: View {
    let snapshot: TokenUsageHistoryImportToolSnapshot
    let language: TokenMeteringLanguage
    let firstModeText: String
    let incrementalModeText: String
    let waitingText: String
    let scanningText: String
    let doneText: String
    let noSourceText: String
    let failedText: String
    let cancelledText: String
    let sourcesText: String
    let newText: String
    let duplicatesText: String
    let unsupportedText: String
    let syncText: String
    let isImportRunning: Bool
    let lastRunText: String?
    let syncAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            statusIcon

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(snapshot.tool.aiTool.dashboardLabel(language: language))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(modeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint.opacity(0.12)))

                    Spacer(minLength: 0)

                    Button(action: syncAction) {
                        Label(syncText, systemImage: "arrow.down.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 10, weight: .bold))
                    .disabled(isImportRunning)

                    Text(stateText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(stateColor)
                }

                Text(detailText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let lastRunText {
                    Label(lastRunText, systemImage: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.13), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if snapshot.state == .running {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(stateColor)
                .frame(width: 16, height: 16)
        }
    }

    private var tint: Color {
        snapshot.tool.aiTool.dashboardTint
    }

    private var modeText: String {
        switch snapshot.mode {
        case .firstImport:
            return firstModeText
        case .incremental:
            return incrementalModeText
        }
    }

    private var stateText: String {
        switch snapshot.state {
        case .pending:
            return waitingText
        case .running:
            return scanningText
        case .completed:
            return doneText
        case .unavailable:
            return noSourceText
        case .failed:
            return failedText
        case .cancelled:
            return cancelledText
        }
    }

    private var systemImage: String {
        switch snapshot.state {
        case .pending:
            return "clock"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .unavailable:
            return "minus.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var stateColor: Color {
        switch snapshot.state {
        case .completed:
            return .green
        case .running:
            return tint
        case .failed:
            return .red
        case .unavailable, .cancelled:
            return .orange
        case .pending:
            return .secondary
        }
    }

    private var detailText: String {
        if snapshot.state == .running {
            return snapshot.message ?? scanningText
        }

        if let message = snapshot.message, snapshot.scannedSources == 0 {
            return message
        }

        let parts = [
            "\(sourcesText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.scannedSources))",
            "\(newText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.importedEvents))",
            "\(duplicatesText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.skippedDuplicates))",
            "\(unsupportedText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.unsupportedRecords))"
        ]
        return parts.joined(separator: " / ")
    }
}
