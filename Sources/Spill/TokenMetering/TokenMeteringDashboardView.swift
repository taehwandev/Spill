import AppKit
import SwiftUI

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject private var settings: SpillSettings
    @State private var copiedTarget: String?
    @State private var isDiagnosticsExpanded = false
    @State private var hoveredFilterTitle: String? = nil
    private let titleDidChange: () -> Void

    static let showsClearAction = true

    init(
        store: TokenUsageDashboardStore,
        settings: SpillSettings = .shared,
        titleDidChange: @escaping () -> Void = {}
    ) {
        self.store = store
        _settings = ObservedObject(wrappedValue: settings)
        self.titleDidChange = titleDidChange
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(
            key,
            language: currentLanguage
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeader

            Divider()
                .background(Color.primary.opacity(0.05))

            HStack(alignment: .top, spacing: 16) {
                leftRail
                    .frame(width: 224)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        kpiStrip
                        analyticsGrid
                        sessionsTable
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                rightRail
                    .frame(width: 286)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(VisualEffectView(material: .windowBackground, blendingMode: .withinWindow))
        .frame(minWidth: 1060, minHeight: 640)
        .onAppear {
            titleDidChange()
            store.setLanguage(currentLanguage)
            store.refresh()
        }
        .onChange(of: settings.appLanguage) { _, _ in
            titleDidChange()
            store.setLanguage(currentLanguage)
        }
    }

    private var topHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.teal.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(t(.dashboardTitle))
                        .font(.system(size: 18, weight: .bold))
                    alphaBadge
                    localOnlyBadge
                }

                Text(t(.dashboardSubtitle))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            TokenMeteringInfoButton(
                title: t(.displayModeInfoTitle),
                detail: t(.displayModeInfoDetail)
            )

            Picker("", selection: Binding(
                get: { store.displayMode },
                set: { store.setDisplayMode($0) }
            )) {
                ForEach(TokenUsageDisplayMode.allCases) { mode in
                    Text(mode.localizedTitle(language: currentLanguage)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            HStack(spacing: 8) {
                Button {
                    store.refresh()
                } label: {
                    Label(t(.refresh), systemImage: "arrow.clockwise")
                }

                Button {
                    copyToClipboard(
                        TokenMeteringGlobalSetup.prompt(
                            allowsLocalDisplayNames: settings.tokenMeteringPromptAllowsLocalDisplayNames
                        ),
                        target: "prompt"
                    )
                } label: {
                    Label(copiedTarget == "prompt" ? t(.copied) : t(.copyPrompt), systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc")
                }

                if Self.showsClearAction {
                    Button(role: .destructive) {
                        store.clearLocalEvents()
                    } label: {
                        Label(t(.clear), systemImage: "trash")
                    }
                    .disabled(store.snapshot.eventCount == 0)
                }
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var leftRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                railPanel(title: t(.period)) {
                    VStack(spacing: 7) {
                        ForEach(store.snapshot.periodFilters) { filter in
                            railFilterButton(
                                title: filter.title,
                                detail: filter.detail,
                                isSelected: filter.isSelected
                            ) {
                                store.setSelectedPeriod(filter.period)
                            }
                        }
                    }
                }

                railPanel(title: t(.aiTool)) {
                    VStack(spacing: 7) {
                        ForEach(store.snapshot.toolFilters) { filter in
                            railFilterButton(
                                title: filter.title,
                                detail: filter.detail,
                                isSelected: filter.isSelected
                            ) {
                                store.setSelectedTool(filter.tool)
                            }
                        }
                    }
                }

                railPanel(title: t(.workflowFocus)) {
                    VStack(spacing: 8) {
                        compactSummaryRows(store.snapshot.taskRows.prefix(3), emptyText: t(.noTaskSplit))
                        Divider().opacity(0.35)
                        compactSummaryRows(store.snapshot.stageRows.prefix(3), emptyText: t(.noStageSplit))
                    }
                }

                railPanel(title: t(.receivers)) {
                    VStack(spacing: 8) {
                        receiverTile(title: t(.localQueue), state: t(.defaultState), systemImage: "tray.and.arrow.down", tint: .green)
                        receiverTile(title: t(.adapters), state: t(.onDemand), systemImage: "bolt.horizontal", tint: .teal)
                    }
                }

                diagnostics
            }
            .padding(.vertical, 18)
        }
    }

    private var kpiStrip: some View {
        HStack(spacing: 12) {
            ForEach(store.snapshot.kpis) { kpi in
                VStack(alignment: .leading, spacing: 7) {
                    Text(kpi.title.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                    Text(kpi.value)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(kpi.id == "total" ? .teal : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(kpi.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
            }
        }
    }

    private var analyticsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.aiToolDistribution),
                    subtitle: t(.aiToolDistributionSubtitle),
                    infoTitle: t(.aiToolInfoTitle),
                    infoDetail: t(.aiToolInfoDetail)
                ) {
                    barRows(store.snapshot.toolRows, emptyText: t(.noAIToolData))
                }

                dashboardPanel(
                    title: t(.workflowBreakdown),
                    subtitle: t(.workflowBreakdownSubtitle),
                    infoTitle: t(.workflowInfoTitle),
                    infoDetail: t(.workflowInfoDetail)
                ) {
                    barRows(store.snapshot.taskRows, emptyText: t(.noWorkflowData))
                }
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.stageBreakdown),
                    subtitle: t(.stageBreakdownSubtitle),
                    infoTitle: t(.stageInfoTitle),
                    infoDetail: t(.stageInfoDetail)
                ) {
                    barRows(store.snapshot.stageRows, emptyText: t(.noStageData))
                }

                dashboardPanel(
                    title: t(.sourceBreakdown),
                    subtitle: t(.sourceBreakdownSubtitle),
                    infoTitle: t(.sourceInfoTitle),
                    infoDetail: t(.sourceInfoDetail)
                ) {
                    barRows(store.snapshot.sourceRows, emptyText: t(.noSourceBreakdown))
                }
            }
        }
    }

    private var rightRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                detailPanel
                modelPanel
                sourcePanel
                privacyPanel
            }
            .padding(.vertical, 18)
        }
    }

    private var detailPanel: some View {
        railPanel(
            title: t(.selectedRun),
            infoTitle: t(.runsInfoTitle),
            infoDetail: t(.runsInfoDetail)
        ) {
            if let session = store.snapshot.selectedSession {
                VStack(alignment: .leading, spacing: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(2)
                        Text(session.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        metricPill(title: t(.total), value: session.value)
                        metricPill(title: t(.events), value: "\(session.eventCount)")
                    }
                }
            } else {
                emptyMessage(
                    title: t(.noRunSelected),
                    detail: t(.noRunSelectedDetail)
                )
            }
        }
    }

    private var modelPanel: some View {
        railPanel(
            title: t(.modelBreakdown),
            infoTitle: t(.modelInfoTitle),
            infoDetail: t(.modelInfoDetail)
        ) {
            VStack(spacing: 8) {
                compactSummaryRows(store.snapshot.modelRows.prefix(5), emptyText: t(.noModelData))
            }
        }
    }

    private var sourcePanel: some View {
        railPanel(
            title: t(.sourceDetail),
            infoTitle: t(.sourceInfoTitle),
            infoDetail: t(.sourceInfoDetail)
        ) {
            VStack(spacing: 8) {
                compactSummaryRows(store.snapshot.sourceRows.prefix(5), emptyText: t(.noSourceBuckets))
            }
        }
    }

    private var privacyPanel: some View {
        railPanel(title: t(.privacyBoundary)) {
            VStack(alignment: .leading, spacing: 9) {
                Text(t(.privacyBoundaryDetail))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowingTokenMeteringLabels(
                    labels: Array(TokenMeteringL10n.forbiddenContentLabels(language: currentLanguage).prefix(6))
                )
            }
        }
    }

    private var sessionsTable: some View {
        dashboardPanel(
            title: t(.runs),
            subtitle: t(.runsSubtitle),
            infoTitle: t(.runsInfoTitle),
            infoDetail: t(.runsInfoDetail)
        ) {
            if store.snapshot.sessions.isEmpty {
                emptyMessage(
                    title: t(.noLocalTokenEvents),
                    detail: t(.noLocalTokenEventsDetail)
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        tableHeader(t(.run))
                        tableHeader(t(.events))
                            .frame(width: 150, alignment: .leading)
                        tableHeader(t(.tokens))
                            .frame(width: 96, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    ForEach(store.snapshot.sessions.prefix(8)) { session in
                        let isSelected = store.snapshot.selectedSession?.id == session.id
                        Button {
                            store.selectSession(session.id)
                        } label: {
                            HStack(spacing: 12) {
                                Text(session.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                                Text(session.detail)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                                    .lineLimit(1)
                                    .frame(width: 150, alignment: .leading)
                                Text(session.value)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(width: 96, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background(
                                isSelected ? Color.teal : Color.primary.opacity(0.025),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.teal.opacity(0.35) : Color.primary.opacity(0.04), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private var diagnostics: some View {
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t(.diagnosticsDetail))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await store.runLocalQueueSelfTest()
                    }
                } label: {
                    Label(store.isRunningSelfTest ? t(.writing) : t(.queueTest), systemImage: store.isRunningSelfTest ? "hourglass" : "tray.and.arrow.down")
                }
                .disabled(store.isRunningSelfTest)

                if let selfTestMessage = store.selfTestMessage {
                    Text(selfTestMessage.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selfTestMessage.isSuccess ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let lastError = store.lastError {
                    Text(lastError)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(t(.diagnostics), systemImage: "stethoscope")
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func dashboardPanel<Content: View>(
        title: String,
        subtitle: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func railPanel<Content: View>(
        title: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func railFilterButton(
        title: String,
        detail: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredFilterTitle == title
        return Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(isSelected ? .white : (isHovered ? Color.teal : Color.primary.opacity(0.12)))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal, Color.teal.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.teal.opacity(0.25), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredFilterTitle = hovering ? title : nil
            }
        }
    }

    private func receiverTile(title: String, state: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.12))

                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(state)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func barRows(_ rows: [TokenUsageDashboardBarRow], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                emptyMessage(title: emptyText, detail: t(.waitingForEvents))
            } else {
                ForEach(rows.prefix(6)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(row.value)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.07))
                                Capsule(style: .continuous)
                                    .fill(Color.teal)
                                    .frame(width: max(6, geometry.size.width * row.ratio))
                            }
                        }
                        .frame(height: 7)
                    }
                }
            }
        }
    }

    private func compactSummaryRows<T: Collection>(
        _ rows: T,
        emptyText: String
    ) -> some View where T.Element == TokenUsageDashboardBarRow {
        let rowsArray = Array(rows)

        return VStack(alignment: .leading, spacing: 7) {
            if rowsArray.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rowsArray) { row in
                    HStack(spacing: 8) {
                        Text(row.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(row.value)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .black))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .black))
            .tracking(1.0)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyMessage(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
    }

    private var alphaBadge: some View {
        Text("ALPHA")
            .font(.system(size: 8.5, weight: .black))
            .tracking(0.9)
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .frame(height: 21)
            .background(Color.orange.opacity(0.11), in: Capsule(style: .continuous))
    }

    private var localOnlyBadge: some View {
        Text(t(.localOnly))
            .font(.system(size: 8.5, weight: .black))
            .tracking(0.9)
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .frame(height: 21)
            .background(Color.green.opacity(0.11), in: Capsule(style: .continuous))
    }

    private func copyToClipboard(_ text: String, target: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedTarget == target {
                copiedTarget = nil
            }
        }
    }

    private var dashboardCardBackground: some ShapeStyle {
        .regularMaterial
    }
}

private struct TokenMeteringInfoButton: View {
    let title: String
    let detail: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(detail)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 260, alignment: .leading)
        }
    }
}
