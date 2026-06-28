import SwiftUI

struct TokenMeteringDashboardDetailPanel: View {
    let session: TokenUsageDashboardSessionRow
    let snapshot: TokenUsageDashboardSnapshot
    @Binding var aliasText: String
    let language: TokenMeteringLanguage
    let liveUpdateMarker: TokenUsageLiveUpdateMarker
    let isLiveUpdated: (String) -> Bool
    let clearSelection: () -> Void
    let updateAlias: (String, String) -> Void

    private var detailSession: TokenUsageDashboardSessionRow {
        snapshot.selectedSession ?? session
    }

    private var kpisByID: [String: TokenUsageDashboardKPI] {
        Dictionary(uniqueKeysWithValues: snapshot.kpis.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                detailPanelHeader(detailSession)
                Divider()
                detailAliasSection(for: session)
                detailMetricsSection(detailSession: detailSession)
                detailBreakdownSections(snapshot: snapshot)
                detailDiagnosticsSection(session: session)
            }
            .padding(.vertical, 18)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailPanelHeader(_ detailSession: TokenUsageDashboardSessionRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t(.selectedWorkItemHeader))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(detailSession.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text(detailSession.projectTitle)
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                Text(detailSession.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func detailAliasSection(for session: TokenUsageDashboardSessionRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t(.localAlias))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(
                    t(.localAliasPlaceholder),
                    text: $aliasText
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .onSubmit {
                    updateAlias(session.id, aliasText)
                }

                Button(t(.applyAlias)) {
                    updateAlias(session.id, aliasText)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .font(.system(size: 10, weight: .bold))

                if !aliasText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(t(.clearAlias)) {
                        aliasText = ""
                        updateAlias(session.id, "")
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 10, weight: .medium))
                }
            }

            Text(t(.localAliasDetail))
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func detailMetricsSection(detailSession: TokenUsageDashboardSessionRow) -> some View {
        VStack(spacing: 8) {
            HStack {
                metricPill(
                    title: t(.total),
                    value: kpisByID["total"]?.value ?? detailSession.value,
                    liveUpdateID: "session:\(detailSession.id)"
                )
                metricPill(
                    title: t(.events),
                    value: TokenUsageDashboardSnapshot.formatCount(detailSession.eventCount),
                    liveUpdateID: "session:\(detailSession.id)"
                )
            }
            HStack {
                metricPill(
                    title: t(.input),
                    value: kpisByID["input"]?.value ?? "-"
                )
                metricPill(
                    title: t(.output),
                    value: kpisByID["output"]?.value ?? "-"
                )
            }
        }
    }

    @ViewBuilder
    private func detailBreakdownSections(snapshot detailSnapshot: TokenUsageDashboardSnapshot) -> some View {
        workItemPopoverSection(
            title: t(.aiTool),
            rows: detailSnapshot.toolRows.prefix(4),
            emptyText: t(.noAIToolData),
            idPrefix: "tool"
        )

        workItemPopoverSection(
            title: t(.modelBreakdown),
            rows: detailSnapshot.modelRows.prefix(4),
            emptyText: t(.noModelData),
            idPrefix: "model"
        )

        workItemPopoverSection(
            title: t(.workflowBreakdown),
            rows: detailSnapshot.taskRows.prefix(4),
            emptyText: t(.noWorkflowData),
            idPrefix: "task"
        )

        workItemPopoverSection(
            title: t(.stageBreakdown),
            rows: detailSnapshot.stageRows.prefix(4),
            emptyText: t(.noStageData),
            idPrefix: "stage"
        )
    }

    private func detailDiagnosticsSection(session: TokenUsageDashboardSessionRow) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t(.diagnosticsSessionID)): \(session.id)")
                Text("\(t(.diagnosticsRunID)): \(session.runID)")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        } label: {
            Text(t(.diagnosticsCodes))
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(10)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
    }

    private func workItemPopoverSection<Rows: Collection>(
        title: String,
        rows: Rows,
        emptyText: String,
        idPrefix: String
    ) -> some View where Rows.Element == TokenUsageDashboardBarRow {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            compactSummaryRows(rows, emptyText: emptyText, idPrefix: idPrefix)
        }
        .padding(10)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func metricPill(
        title: String,
        value: String,
        liveUpdateID: String? = nil
    ) -> some View {
        TokenMeteringDashboardMetricPill(
            title: title,
            value: value,
            isLiveUpdated: liveUpdateID.map(isLiveUpdated) ?? false,
            marker: liveUpdateMarker
        )
    }

    private func compactSummaryRows<Rows: Collection>(
        _ rows: Rows,
        emptyText: String,
        idPrefix: String? = nil
    ) -> some View where Rows.Element == TokenUsageDashboardBarRow {
        TokenMeteringDashboardCompactSummaryRows(
            rows: rows,
            emptyText: emptyText,
            idPrefix: idPrefix,
            marker: liveUpdateMarker,
            isLiveUpdated: isLiveUpdated
        )
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
