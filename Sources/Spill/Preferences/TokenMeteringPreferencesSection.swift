import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let openDashboardAction: () -> Void
    @State private var copiedTarget: String?
    @State private var setupInstalledPath: URL?
    @State private var setupInstallResult: String?

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
                    title: "Local event queue",
                    state: "Default",
                    systemImage: "tray.and.arrow.down",
                    tint: .green
                )

                Text("Hooks and adapters enqueue one safe JSON event file per completed response. Spill imports complete .json files into the local store and ignores partial .tmp files.")
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
                TokenMeteringOptionHeader(
                    title: "On-demand adapters",
                    state: "No polling",
                    systemImage: "bolt.horizontal",
                    tint: .teal
                )

                Text("Codex, Claude, Antigravity, and direct OpenAI adapters should write one exact usage event when their runtime exposes final token counts. Continuous polling is not required for normal metering.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            VStack(alignment: .leading, spacing: 9) {
                TokenMeteringOptionHeader(
                    title: "One-step setup",
                    state: "Recommended",
                    systemImage: "wand.and.stars",
                    tint: .teal
                )

                Text("Install the setup tool once, then run a single command to detect Codex, Claude, Antigravity, and OpenAI support. Hook config files are changed only when the copied command is run with --apply.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                let setupURL = setupInstalledPath ?? TokenMeteringSetupInstaller.defaultInstallURL()
                HStack(spacing: 6) {
                    Button {
                        installSetupTool()
                    } label: {
                        Label(
                            copiedTarget == "setup_install" ? "Installed" : "Install Setup Tool",
                            systemImage: copiedTarget == "setup_install" ? "checkmark" : "arrow.down.circle"
                        )
                    }

                    Button {
                        copyToClipboard(TokenMeteringSetupInstaller.setupCommand(installedAt: setupURL), target: "setup_command")
                    } label: {
                        Label(
                            copiedTarget == "setup_command" ? "Copied" : "Copy Setup Command",
                            systemImage: copiedTarget == "setup_command" ? "checkmark" : "terminal"
                        )
                    }

                    Button {
                        copyToClipboard(TokenMeteringSetupInstaller.workflowSetupCommand(installedAt: setupURL), target: "workflow_command")
                    } label: {
                        Label(
                            copiedTarget == "workflow_command" ? "Copied" : "Workflow Command",
                            systemImage: copiedTarget == "workflow_command" ? "checkmark" : "point.3.connected.trianglepath.dotted"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10, weight: .semibold))

                Text(setupURL.path)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if let setupInstallResult {
                    Text(setupInstallResult)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(setupInstallResult.hasPrefix("Installed") ? .green : .red)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            VStack(alignment: .leading, spacing: 6) {
                Text("Adapter scripts")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Each script captures exact token counts from its runtime and enqueues one event file. No polling; events are written only when the runtime finishes a response.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(TokenMeteringAdapterKit.all) { adapter in
                    TokenMeteringAdapterRow(
                        adapter: adapter,
                        copiedTarget: $copiedTarget,
                        onCopy: copyToClipboard
                    )
                }
            }

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

    private func installSetupTool() {
        let destination = TokenMeteringSetupInstaller.defaultInstallURL()
        do {
            try TokenMeteringSetupInstaller.install(to: destination)
            setupInstalledPath = destination
            setupInstallResult = "Installed setup tool and adapter scripts."
            copiedTarget = "setup_install"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if copiedTarget == "setup_install" { copiedTarget = nil }
            }
        } catch {
            setupInstallResult = "Install failed: \(error.localizedDescription)"
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

private struct TokenMeteringAdapterRow: View {
    let adapter: TokenMeteringAdapter
    @Binding var copiedTarget: String?
    let onCopy: (String, String) -> Void
    @State private var installedPath: URL?
    @State private var installResult: String?

    private var copyScriptKey: String { "script_\(adapter.id)" }
    private var copyHookKey: String { "hook_\(adapter.id)" }
    private var installKey: String { "install_\(adapter.id)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(adapter.title)
                        .font(.system(size: 11, weight: .bold))
                    Text(adapter.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Button {
                        if let content = adapter.scriptContent {
                            onCopy(content, copyScriptKey)
                        }
                    } label: {
                        Label(
                            copiedTarget == copyScriptKey ? "Copied" : "Copy Script",
                            systemImage: copiedTarget == copyScriptKey ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .disabled(adapter.scriptContent == nil)

                    Button {
                        installAdapter()
                    } label: {
                        Label(
                            copiedTarget == installKey ? "Installed" : "Install",
                            systemImage: copiedTarget == installKey ? "checkmark" : "arrow.down.circle"
                        )
                    }
                    .disabled(adapter.scriptURL == nil)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10, weight: .semibold))
            }

            if let result = installResult {
                Text(result)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(result.hasPrefix("Installed") ? .green : .red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if adapter.hookConfigTemplate != nil {
                let path = installedPath ?? TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
                let config = adapter.hookConfig(installedAt: path) ?? ""
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let target = adapter.hookConfigTarget {
                            Text("Hook config → \(target)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Text(config)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        onCopy(config, copyHookKey)
                    } label: {
                        Label(
                            copiedTarget == copyHookKey ? "Copied" : "Copy",
                            systemImage: copiedTarget == copyHookKey ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 10, weight: .semibold))
                }
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }
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

    private func installAdapter() {
        let destination = TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
        do {
            try adapter.install(to: destination)
            installedPath = destination
            installResult = "Installed → \(destination.path)"
            copiedTarget = installKey
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if copiedTarget == installKey { copiedTarget = nil }
            }
        } catch {
            installResult = "Install failed: \(error.localizedDescription)"
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
