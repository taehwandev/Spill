import AppKit
import SwiftUI

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @State private var copiedTarget: String?
    @State private var isDiagnosticsExpanded = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                header
                kpiGrid
                contentGrid
                privacyContract
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            store.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.teal.opacity(0.16))

                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.teal)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Token Dashboard")
                        .font(.system(size: 24, weight: .bold))
                    Text("Spill is ready to receive safe local events. A prompt alone cannot read token counts; automatic reporting requires an agent runtime or adapter with exact usage metadata.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                statusBadge
            }

            HStack(spacing: 10) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    copyToClipboard(TokenMeteringGlobalSetup.globalPrompt, target: "prompt")
                } label: {
                    Label(copiedTarget == "prompt" ? "Copied Prompt" : "Copy Agent Prompt", systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc")
                }

                Button(role: .destructive) {
                    store.clearLocalEvents()
                } label: {
                    Label("Clear Local Data", systemImage: "trash")
                }
                .disabled(store.snapshot.eventCount == 0)
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))

            if let selfTestMessage = store.selfTestMessage {
                Text(selfTestMessage.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selfTestMessage.isSuccess ? .green : .red)
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
            }

            periodFilterBar
            toolFilterBar

            diagnostics
        }
        .padding(18)
        .background(dashboardCardBackground)
    }

    private var periodFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Period")
                .font(.system(size: 10, weight: .black))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(store.snapshot.periodFilters) { filter in
                    Button {
                        store.setSelectedPeriod(filter.period)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(filter.title)
                                .font(.system(size: 10.5, weight: .bold))
                            Text(filter.detail)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(filter.isSelected ? .white.opacity(0.82) : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 42)
                        .frame(minWidth: 78, alignment: .leading)
                        .foregroundStyle(filter.isSelected ? .white : .primary)
                        .background(
                            filter.isSelected ? Color.teal : Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var toolFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Tool")
                .font(.system(size: 10, weight: .black))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.snapshot.toolFilters) { filter in
                        Button {
                            store.setSelectedTool(filter.tool)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(filter.title)
                                    .font(.system(size: 10.5, weight: .bold))
                                Text(filter.detail)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(filter.isSelected ? .white.opacity(0.82) : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 42)
                            .frame(minWidth: 86, alignment: .leading)
                            .foregroundStyle(filter.isSelected ? .white : .primary)
                            .background(
                                filter.isSelected ? Color.teal : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var diagnostics: some View {
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This only sends one synthetic local-only event to confirm the optional loopback HTTP bridge is reachable. It is not required for normal metering.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await store.runLocalBridgeSelfTest()
                    }
                } label: {
                    Label(store.isRunningSelfTest ? "Sending Bridge Test" : "Send Bridge Test", systemImage: store.isRunningSelfTest ? "hourglass" : "paperplane")
                }
                .disabled(store.isRunningSelfTest)
            }
            .padding(.top, 8)
        } label: {
            Label("Diagnostics", systemImage: "stethoscope")
                .font(.system(size: 11, weight: .semibold))
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.top, 2)
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

    private var statusBadge: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("LOCAL ONLY")
                .font(.system(size: 9, weight: .black))
                .tracking(1.2)
                .foregroundStyle(.green)
            Text("No cloud transfer")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.green.opacity(0.11))
        )
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(store.snapshot.kpis) { kpi in
                VStack(alignment: .leading, spacing: 8) {
                    Text(kpi.title.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text(kpi.value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(kpi.id == "total" ? .teal : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(kpi.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(dashboardCardBackground)
            }
        }
    }

    private var contentGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            dashboardPanel(title: "AI Tools", subtitle: "Combined and filtered usage") {
                barRows(store.snapshot.toolRows, emptyText: "No AI tool data yet.")
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(title: "Task Breakdown", subtitle: "Where local tokens went") {
                    barRows(store.snapshot.taskRows, emptyText: "No local task data yet.")
                }

                dashboardPanel(title: "Stage Breakdown", subtitle: "Plan, implement, verify") {
                    barRows(store.snapshot.stageRows, emptyText: "No local stage data yet.")
                }
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(title: "Token Sources", subtitle: "Numeric source buckets only") {
                    barRows(store.snapshot.sourceRows, emptyText: "No source breakdown yet.")
                }

                dashboardPanel(title: "Sessions", subtitle: "Recent local spans") {
                    sessionRows
                }
            }
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(dashboardCardBackground)
    }

    private func barRows(_ rows: [TokenUsageDashboardBarRow], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.title)
                                .font(.system(size: 11, weight: .semibold))
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

    private var privacyContract: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Privacy Boundary")
                        .font(.system(size: 15, weight: .bold))
                    Text("Opaque run ids only. No prompts, commands, files, logs, or source content.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.snapshot.eventCount) events")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            FlowingTokenMeteringLabels(labels: TokenMeteringPreferencesModel.forbiddenContentLabels)
        }
        .padding(16)
        .background(dashboardCardBackground)
    }

    private var sessionRows: some View {
        Group {
            if store.snapshot.sessions.isEmpty {
                emptyLocalState
            } else {
                VStack(spacing: 8) {
                    ForEach(store.snapshot.sessions.prefix(8)) { session in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.runID)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                                Text(session.detail)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(session.value)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .padding(11)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var emptyLocalState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No local token events yet.")
                .font(.system(size: 12, weight: .bold))
            Text("This is expected until an agent runtime or adapter exposes exact token counts and sends the safe local event contract.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var dashboardCardBackground: some ShapeStyle {
        .regularMaterial
    }
}
