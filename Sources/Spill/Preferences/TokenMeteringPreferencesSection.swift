import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let openDashboardAction: () -> Void
    @State private var copiedTarget: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current device is local-only.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Spill aggregates token counts in the local app dashboard. Login and hosted sync are not configured in this app slice, so no server transfer is active.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                TokenMeteringOptionHeader(
                    title: "Local file inbox",
                    state: "Default",
                    systemImage: "internaldrive",
                    tint: .green
                )

                Text("Hooks and adapters can append safe JSONL events here without opening a local port. Spill reads this local store when the panel or dashboard refreshes.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(TokenUsageStore.defaultInboxURL().path)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer(minLength: 8)

                    Button {
                        copyToClipboard(TokenUsageStore.defaultInboxURL().path, target: "inbox")
                    } label: {
                        Label(copiedTarget == "inbox" ? "Copied" : "Copy Path", systemImage: copiedTarget == "inbox" ? "checkmark" : "doc.on.doc")
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 10) {
                    TokenMeteringOptionHeader(
                        title: "Loopback HTTP bridge",
                        state: settings.tokenUsageBridgeEnabled ? "Enabled" : "Optional",
                        systemImage: "network",
                        tint: settings.tokenUsageBridgeEnabled ? .green : .secondary
                    )

                    Spacer(minLength: 8)

                    Toggle("", isOn: $settings.tokenUsageBridgeEnabled)
                        .labelsHidden()
                }

                Text("Use only for tools that can POST to 127.0.0.1:\(TokenUsageBridgeServer.defaultPort). The bridge is disabled by default; local file storage does not need it.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            VStack(alignment: .leading, spacing: 9) {
                TokenMeteringOptionHeader(
                    title: "On-demand adapters",
                    state: "No polling",
                    systemImage: "bolt.horizontal",
                    tint: .teal
                )

                Text("Codex, Claude, Antigravity, and Ollama adapters should write one exact usage event when their runtime exposes final token counts. Continuous polling is not required for normal metering.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            VStack(spacing: 8) {
                ForEach(TokenMeteringPreferencesModel.modes) { mode in
                    TokenMeteringModeRow(mode: mode)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Never collected or uploaded")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                FlowingTokenMeteringLabels(labels: TokenMeteringPreferencesModel.forbiddenContentLabels)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Global setup")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Use this prompt once in your global agent instructions. It sets the safety contract; actual automatic reporting still requires an agent runtime or adapter that exposes exact token counts.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        copyToClipboard(TokenMeteringGlobalSetup.globalPrompt, target: "prompt")
                    } label: {
                        Label(copiedTarget == "prompt" ? "Copied Prompt" : "Copy Agent Prompt", systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc")
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .semibold))
            }

            HStack(spacing: 8) {
                Button {
                    openDashboardAction()
                } label: {
                    Label("Open Local Dashboard", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.borderedProminent)

                Text("Detailed categories require exact usage metadata from the sending runtime or adapter. The dashboard is for viewing local events and optional diagnostics.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11, weight: .semibold))

            Text("The web dashboard is the future signed-in cloud surface. Local review happens here in the app.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
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
}

private struct TokenMeteringOptionHeader: View {
    let title: String
    let state: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            Text(state)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }
}

private struct TokenMeteringModeRow: View {
    let mode: TokenMeteringModeStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.isActive ? "checkmark.circle.fill" : "lock.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode.isActive ? .green : .secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mode.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(mode.state)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(mode.isActive ? .green : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(mode.isActive ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                        )
                }

                Text(mode.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct FlowingTokenMeteringLabels: View {
    let labels: [String]

    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 84), spacing: 6, alignment: .leading)
        ]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
        }
    }
}
