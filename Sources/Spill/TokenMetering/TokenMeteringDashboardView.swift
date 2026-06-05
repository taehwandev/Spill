import AppKit
import SwiftUI

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @State private var copiedTarget: String?
    @State private var isDiagnosticsExpanded = false
    @State private var hoveredFilterTitle: String? = nil

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
            store.refresh()
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
                    Text("Local Token Metering")
                        .font(.system(size: 18, weight: .bold))
                    localOnlyBadge
                }

                Text("Local queue first. Adapters write event files; Spill imports them into the app-owned store.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    copyToClipboard(TokenMeteringGlobalSetup.globalPrompt, target: "prompt")
                } label: {
                    Label(copiedTarget == "prompt" ? "Copied" : "Copy Prompt", systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc")
                }

                Button(role: .destructive) {
                    store.clearLocalEvents()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(store.snapshot.eventCount == 0)
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
                railPanel(title: "Period") {
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

                railPanel(title: "AI Tool") {
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

                railPanel(title: "Workflow Focus") {
                    VStack(spacing: 8) {
                        compactSummaryRows(store.snapshot.taskRows.prefix(3), emptyText: "No task split")
                        Divider().opacity(0.35)
                        compactSummaryRows(store.snapshot.stageRows.prefix(3), emptyText: "No stage split")
                    }
                }

                railPanel(title: "Receivers") {
                    VStack(spacing: 8) {
                        receiverTile(title: "Local Queue", state: "Default", systemImage: "tray.and.arrow.down", tint: .green)
                        receiverTile(title: "Adapters", state: "On demand", systemImage: "bolt.horizontal", tint: .teal)
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
                dashboardPanel(title: "AI Tool Distribution", subtitle: "Combined and per-tool local usage") {
                    barRows(store.snapshot.toolRows, emptyText: "No AI tool data yet.")
                }

                dashboardPanel(title: "Workflow Breakdown", subtitle: "Task categories from safe slugs") {
                    barRows(store.snapshot.taskRows, emptyText: "No workflow data yet.")
                }
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(title: "Stage Breakdown", subtitle: "Plan, implement, verify, and custom phases") {
                    barRows(store.snapshot.stageRows, emptyText: "No stage data yet.")
                }

                dashboardPanel(title: "Source Breakdown", subtitle: "Numeric buckets only") {
                    barRows(store.snapshot.sourceRows, emptyText: "No source breakdown yet.")
                }
            }
        }
    }

    private var rightRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                detailPanel
                sourcePanel
                privacyPanel
            }
            .padding(.vertical, 18)
        }
    }

    private var detailPanel: some View {
        railPanel(title: "Selected Run") {
            if let session = store.snapshot.sessions.first {
                VStack(alignment: .leading, spacing: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.runID)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .lineLimit(2)
                        Text(session.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        metricPill(title: "Total", value: session.value)
                        metricPill(title: "Events", value: "\(store.snapshot.eventCount)")
                    }
                }
            } else {
                emptyMessage(
                    title: "No run selected",
                    detail: "Events will appear here after a local runtime or adapter records exact token counts."
                )
            }
        }
    }

    private var sourcePanel: some View {
        railPanel(title: "Source Detail") {
            VStack(spacing: 8) {
                compactSummaryRows(store.snapshot.sourceRows.prefix(5), emptyText: "No source buckets")
            }
        }
    }

    private var privacyPanel: some View {
        railPanel(title: "Privacy Boundary") {
            VStack(alignment: .leading, spacing: 9) {
                Text("No prompts, commands, files, logs, diffs, source content, environment values, or secrets.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowingTokenMeteringLabels(labels: Array(TokenMeteringPreferencesModel.forbiddenContentLabels.prefix(6)))
            }
        }
    }

    private var sessionsTable: some View {
        dashboardPanel(title: "Runs", subtitle: "Opaque local run groups and spans") {
            if store.snapshot.sessions.isEmpty {
                emptyMessage(
                    title: "No local token events yet",
                    detail: "This is expected until an agent runtime or adapter exposes exact token counts."
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        tableHeader("Run")
                        tableHeader("Spans")
                            .frame(width: 150, alignment: .leading)
                        tableHeader("Tokens")
                            .frame(width: 96, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    ForEach(store.snapshot.sessions.prefix(8)) { session in
                        HStack(spacing: 12) {
                            Text(session.runID)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                            Text(session.detail)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 150, alignment: .leading)
                            Text(session.value)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .frame(width: 96, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private var diagnostics: some View {
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Writes one synthetic event through the local queue and imports it into the app-owned store.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await store.runLocalQueueSelfTest()
                    }
                } label: {
                    Label(store.isRunningSelfTest ? "Writing" : "Queue Test", systemImage: store.isRunningSelfTest ? "hourglass" : "tray.and.arrow.down")
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
            Label("Diagnostics", systemImage: "stethoscope")
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .tracking(1.0)
                .foregroundStyle(.secondary)

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
                emptyMessage(title: emptyText, detail: "Waiting for safe local usage events.")
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

    private var localOnlyBadge: some View {
        Text("LOCAL ONLY")
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
