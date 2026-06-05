import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let openDashboardAction: () -> Void
    @State private var copiedTarget: String?
    @State private var setupInstalledPath: URL?
    @State private var setupInstallResult: String?
    @State private var advancedVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Local token metering")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Spill stores safe token counts on this Mac. Login, cloud sync, and server transfer are not active in this app slice.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                TokenMeteringOptionHeader(
                    title: "Install prompt + one-step setup",
                    state: "Recommended",
                    systemImage: "wand.and.stars",
                    tint: .teal
                )

                Text("Paste this into an AI with local shell access. It forces the AI to fetch the latest setup from spill.thdev.app, install Codex, Claude, and AGY hooks, then save only the runtime instruction.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Button {
                        copyToClipboard(TokenMeteringGlobalSetup.globalPrompt, target: "prompt")
                    } label: {
                        Label(
                            copiedTarget == "prompt" ? "Copied" : "Copy Install Prompt",
                            systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc"
                        )
                    }

                    Button {
                        copyToClipboard(TokenMeteringSetupInstaller.setupCommand(), target: "setup_command_primary")
                    } label: {
                        Label(
                            copiedTarget == "setup_command_primary" ? "Copied" : "Copy Web Setup",
                            systemImage: copiedTarget == "setup_command_primary" ? "checkmark" : "terminal"
                        )
                    }

                    Button {
                        openDashboardAction()
                    } label: {
                        Label("Dashboard", systemImage: "chart.bar.xaxis")
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 10, weight: .semibold))

                Text(TokenMeteringSetupInstaller.setupCommand())
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

            DisclosureGroup(isExpanded: $advancedVisible) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 9) {
                        TokenMeteringOptionHeader(
                            title: "Local event queue",
                            state: "Default",
                            systemImage: "tray.and.arrow.down",
                            tint: .green
                        )

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
                                Label(
                                    copiedTarget == "inbox" ? "Copied" : "Copy Path",
                                    systemImage: copiedTarget == "inbox" ? "checkmark" : "doc.on.doc"
                                )
                            }
                            .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .padding(10)
                    .background(tokenMeteringOptionBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Advanced install commands")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button {
                                let setupURL = setupInstalledPath ?? TokenMeteringSetupInstaller.defaultInstallURL()
                                copyToClipboard(TokenMeteringSetupInstaller.setupCommand(installedAt: setupURL), target: "setup_command")
                            } label: {
                                Label(
                                    copiedTarget == "setup_command" ? "Copied" : "Copy One-Step Command",
                                    systemImage: copiedTarget == "setup_command" ? "checkmark" : "terminal"
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 10, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adapter scripts")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

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
                }
                .padding(.top, 8)
            } label: {
                Label("Advanced details", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
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
