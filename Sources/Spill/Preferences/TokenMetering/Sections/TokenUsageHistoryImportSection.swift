import SwiftUI

struct TokenUsageHistoryImportSection: View {
    let snapshot: TokenUsageHistoryImportSnapshot
    let availableTools: [TokenUsageHistoryImportTool]
    let language: TokenMeteringLanguage
    let startAllAction: () -> Void
    let cancelAction: () -> Void
    let startToolAction: (TokenUsageHistoryImportTool) -> Void

    var body: some View {
        let tint = snapshot.isRunning ? Color.blue : Color.teal
        let stateText = snapshot.isRunning ? t(.historyImportRunning) : t(.historyImportReady)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                TokenMeteringOptionHeader(
                    title: t(.historyImportTitle),
                    state: stateText,
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: tint
                )

                Text(t(.historyImportExperimental))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(Color.orange.opacity(0.12)))

                Spacer(minLength: 8)

                Button {
                    if snapshot.isRunning {
                        cancelAction()
                    } else {
                        startAllAction()
                    }
                } label: {
                    Label(
                        snapshot.isRunning ? t(.historyImportCancel) : t(.historyImportAllStart),
                        systemImage: snapshot.isRunning ? "xmark.circle" : "arrow.down.doc"
                    )
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .semibold))
                .disabled(
                    availableTools.isEmpty
                        || (snapshot.isRunning && availableSnapshots.allSatisfy(\.state.isFinished))
                )
            }

            Text(t(.historyImportDetail))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Label(t(.historyImportFullScanWarning), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                if availableSnapshots.isEmpty {
                    Text(TokenMeteringSetupL10n.text(.historyImportNoInstalledTools, language: language))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                } else {
                    ForEach(availableSnapshots) { toolSnapshot in
                        TokenUsageHistoryImportToolRow(
                            snapshot: toolSnapshot,
                            language: language,
                            firstModeText: t(.historyImportFirstMode),
                            incrementalModeText: t(.historyImportIncrementalMode),
                            waitingText: t(.historyImportStateWaiting),
                            scanningText: t(.historyImportStateScanning),
                            doneText: t(.historyImportStateDone),
                            noSourceText: t(.historyImportStateNoSource),
                            failedText: t(.historyImportStateFailed),
                            cancelledText: t(.historyImportStateCancelled),
                            sourcesText: t(.historyImportMetricSources),
                            newText: t(.historyImportMetricNew),
                            duplicatesText: t(.historyImportMetricDuplicates),
                            unsupportedText: t(.historyImportMetricUnsupported),
                            syncText: t(.historyImportToolStart),
                            isImportRunning: snapshot.isRunning,
                            lastRunText: TokenUsageHistoryImportLastRunText.text(
                                for: toolSnapshot.lastRun,
                                language: language
                            ),
                            syncAction: {
                                startToolAction(toolSnapshot.tool)
                            }
                        )
                    }
                }
            }

            if let finishedAt = snapshot.finishedAt {
                Label(
                    "\(t(.historyImportLastFinished)) \(formatUploadDate(finishedAt))",
                    systemImage: "clock"
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }
}

private extension TokenUsageHistoryImportSection {
    func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private var availableSnapshots: [TokenUsageHistoryImportToolSnapshot] {
        let availableSet = Set(availableTools)
        return snapshot.tools.filter { availableSet.contains($0.tool) }
    }

    private func formatUploadDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
