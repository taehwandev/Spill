import AppKit
import SwiftUI

struct SpillBarView: View {
    @ObservedObject var panelStore: PanelStore
    @ObservedObject var settings: SpillSettings
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var tokenUsageDashboardStore: TokenUsageDashboardStore
    @ObservedObject var windowActionStore: WindowActionStore
    @ObservedObject var sleepGuard: SleepGuardController
    @ObservedObject var updateStore: UpdateCheckStore
    let dismissAction: () -> Void
    let settingsAction: () -> Void
    let tokenMeteringDetailAction: () -> Void
    @State private var pendingDismissWorkItem: DispatchWorkItem?
    @State private var hoveredStatusModule: SpillStatusModule? = nil
    @State private var didCopyUpdateInstallCommand = false
    @State private var showsServiceStatusDashboard = false

    private var panelState: PanelState {
        panelStore.state
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: settings.panelSectionSpacing) {
                header

                if updateStore.showsDashboardUpdateStatus {
                    updateBanner
                }

                if !panelState.visibleStatusModules.isEmpty {
                    Divider()
                        .background(Color.primary.opacity(0.04))
                    statusSection
                }

                Divider()
                    .background(Color.primary.opacity(0.04))
                aiSection

                Divider()
                    .background(Color.primary.opacity(0.04))
                actionSections

                Divider()
                    .background(Color.primary.opacity(0.04))
                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: panelState.pendingDismiss) { _, pendingDismiss in
            updatePendingDismiss(pendingDismiss)
        }
        .onDisappear {
            pendingDismissWorkItem?.cancel()
            pendingDismissWorkItem = nil
            panelStore.send(.dismissRequestHandled)
        }
    }

    private func updatePendingDismiss(_ pendingDismiss: Bool) {
        pendingDismissWorkItem?.cancel()
        pendingDismissWorkItem = nil

        guard pendingDismiss else {
            return
        }

        let workItem = DispatchWorkItem {
            guard panelStore.state.pendingDismiss else {
                return
            }

            panelStore.send(.dismissRequestHandled)
            dismissAction()
        }
        pendingDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private var updateBanner: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(updateBannerTint.opacity(0.14))

                Image(systemName: updateBannerSymbolName)
                    .foregroundStyle(updateBannerTint)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(updateBannerTitle)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)

                Text(updateBannerSubtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if updateStore.canOpenUpdate && updateStore.usesInAppUpdater {
                updateBannerButton(
                    symbolName: "arrow.down.circle.fill",
                    title: AppL10n.text(.updateNow, appLanguage: settings.appLanguage)
                ) {
                    updateStore.openUpdate(source: "panel_update_banner")
                }
            } else if updateStore.canOpenUpdate {
                updateBannerButton(
                    symbolName: didCopyUpdateInstallCommand ? "checkmark" : "doc.on.doc",
                    title: didCopyUpdateInstallCommand
                        ? AppL10n.text(.copied, appLanguage: settings.appLanguage)
                        : AppL10n.text(.copyInstallCommand, appLanguage: settings.appLanguage)
                ) {
                    copyUpdateInstallCommand()
                }

                updateBannerButton(symbolName: updateOpenButtonSymbolName, title: updateOpenButtonTitle) {
                    updateStore.openUpdate(source: "panel")
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(updateBannerTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(updateBannerTint.opacity(0.18), lineWidth: 0.8)
        )
    }

    private var updateBannerTitle: String {
        switch updateStore.state {
        case .checking:
            return AppL10n.text(.updateCheckingTitle, appLanguage: settings.appLanguage)
        case .upToDate:
            return AppL10n.text(.updateUpToDateTitle, appLanguage: settings.appLanguage)
        case .available(let update):
            return AppL10n.updateAvailableTitle(version: update.latestVersion, appLanguage: settings.appLanguage)
        case .unsupported:
            return AppL10n.text(.updateRequiresMacOSTitle, appLanguage: settings.appLanguage)
        case .idle, .failed:
            return AppL10n.text(.updateTitle, appLanguage: settings.appLanguage)
        }
    }

    private var updateBannerSymbolName: String {
        switch updateStore.state {
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .upToDate:
            return "checkmark.circle.fill"
        case .unsupported:
            return "exclamationmark.triangle.fill"
        case .available where updateStore.usesInAppUpdater:
            return "arrow.down.circle.fill"
        case .available:
            return updateStore.availableUpdate?.usesInstallerPackage == true ? "shippingbox.fill" : "terminal.fill"
        case .idle, .failed:
            return "arrow.clockwise"
        }
    }

    private var updateBannerSubtitle: String {
        switch updateStore.state {
        case .checking:
            return AppL10n.text(.lookingForLatestRelease, appLanguage: settings.appLanguage)
        case .upToDate(_, let latestVersion):
            return AppL10n.spillVersionCurrent(version: latestVersion, appLanguage: settings.appLanguage)
        case .available where updateStore.usesInAppUpdater:
            return AppL10n.text(.inAppUpdateReady, appLanguage: settings.appLanguage)
        case .available:
            return updateStore.availableUpdate?.usesInstallerPackage == true
                ? AppL10n.text(.signedInstallerPackage, appLanguage: settings.appLanguage)
                : AppL10n.text(.manualInstaller, appLanguage: settings.appLanguage)
        case .unsupported(let update, let currentMacOS):
            return AppL10n.versionNeedsMacOS(
                version: update.latestVersion,
                requirement: update.minimumMacOS ?? PreferencesL10n.newerThanVersion(currentMacOS),
                appLanguage: settings.appLanguage
            )
        case .idle, .failed:
            return AppL10n.text(.updateTitle, appLanguage: settings.appLanguage)
        }
    }

    private var updateBannerTint: Color {
        switch updateStore.state {
        case .upToDate:
            return .green
        case .unsupported:
            return .orange
        case .checking, .idle, .failed:
            return .secondary
        case .available:
            return .teal
        }
    }

    private var updateOpenButtonTitle: String {
        updateStore.availableUpdate?.usesInstallerPackage == true
            ? PreferencesL10n.text(.openInstaller, appLanguage: settings.appLanguage)
            : PreferencesL10n.text(.downloadDMG, appLanguage: settings.appLanguage)
    }

    private var updateOpenButtonSymbolName: String {
        updateStore.availableUpdate?.usesInstallerPackage == true
            ? "shippingbox.fill"
            : "arrow.down.circle"
    }

    private func updateBannerButton(
        symbolName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func copyUpdateInstallCommand() {
        updateStore.copyInstallCommand(source: "panel")
        didCopyUpdateInstallCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopyUpdateInstallCommand = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SpillBrandIconView()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Spill")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(panelState.actionFeedback?.tint ?? .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            statusDot
            headerCommand(symbolName: "gearshape.fill", title: AppL10n.text(.settings, appLanguage: settings.appLanguage), action: settingsAction)
            headerCommand(symbolName: "xmark", title: AppL10n.text(.close, appLanguage: settings.appLanguage), action: dismissAction)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spill")
    }

    private func headerCommand(symbolName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var statusDot: some View {
        Circle()
            .fill(panelState.readiness.tint)
            .frame(width: 8, height: 8)
            .shadow(color: panelState.readiness.tint.opacity(0.4), radius: 2, y: 1)
            .overlay {
                Circle()
                    .stroke(panelState.readiness.tint.opacity(0.22), lineWidth: 5)
            }
            .accessibilityLabel(panelState.readiness.accessibilityLabel)
    }

    private var headerSubtitle: String {
        if let actionFeedback = panelState.actionFeedback {
            return actionFeedback.message
        }

        return panelState.readiness.subtitle(
            count: panelState.itemCount,
            pinnedCount: panelState.pinnedItemCount
        )
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            sectionHeader(AppL10n.text(.status), symbolName: "waveform.path.ecg")

            VStack(spacing: 7) {
                ForEach(panelState.visibleStatusModules) { module in
                    statusMetricRow(for: module)
                }
            }
        }
    }

    private func statusMetricRow(for module: SpillStatusModule) -> some View {
        let status = statusStore.meterSnapshot(for: module)
        let title = AppL10n.statusModuleTitle(module, appLanguage: settings.appLanguage)
        let helpText = statusHelpText(title: title, value: status.value, subtitle: status.subtitle)

        return Button {
            panelStore.send(.setStatusDetailTarget(.system(module)))
        } label: {
            HStack(spacing: 10) {
                statusIconBadge(symbolName: module.symbolName, tint: status.state.panelTint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 11.5, weight: .semibold))

                        Text(status.value)
                            .font(.system(
                                size: settings.statusValueFontSize,
                                weight: settings.statusValueBold ? .bold : .regular,
                                design: settings.statusFontDesign.fontDesign
                            ))
                            .monospacedDigit()
                            .foregroundStyle(metricValueTint(for: module, state: status.state))
                    }

                    Text(subtitleText(status.subtitle))
                        .font(.system(size: 10, weight: .medium, design: settings.statusFontDesign.fontDesign))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(metricSubtitleTint(for: module))
                }

                Spacer(minLength: 8)

                metricChart(for: module, status: status)
                    .frame(width: 132, height: 44)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 64)
            .background(
                hoveredStatusModule == module ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(hoveredStatusModule == module ? 0.08 : 0.05), lineWidth: 0.5)
            }
            .animation(.easeOut(duration: 0.12), value: hoveredStatusModule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredStatusModule = isHovered ? module : nil
        }
        .popover(isPresented: detailBinding(for: .system(module)), arrowEdge: .top) {
            statusDetailPopover(for: .system(module))
        }
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private func sectionHeader(_ title: String, symbolName: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))

            Spacer()

            Image(systemName: symbolName)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var aiSection: some View {
        VStack(spacing: 7) {
            aiSectionHeader

            tokenMeteringSummary

            if !aiStatusStore.statuses.isEmpty {
                LazyVGrid(columns: aiToolColumns, alignment: .leading, spacing: 7) {
                    ForEach(aiStatusStore.statuses) { status in
                        let serviceStatus = serviceStatus(for: status.kind)
                        let helpText = aiToolHelpText(status, serviceStatus: serviceStatus)

                        Button {
                            panelStore.send(.setStatusDetailTarget(.ai(status.kind)))
                        } label: {
                            compactAIToolPill(status, serviceStatus: serviceStatus)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: detailBinding(for: .ai(status.kind)), arrowEdge: .top) {
                            statusDetailPopover(for: .ai(status.kind))
                        }
                        .help(helpText)
                        .accessibilityLabel(helpText)
                    }
                }
            }
        }
    }

    private var tokenMeteringSummary: some View {
        let snapshot = tokenUsageDashboardStore.unfilteredSnapshot
        let displayTotalTokens = snapshot.totalTokens
        let topTask = snapshot.taskRows.first
        let topSource = snapshot.sourceRows.first

        return Button {
            tokenMeteringDetailAction()
        } label: {
            HStack(spacing: 10) {
                statusIconBadge(symbolName: "chart.bar.xaxis", tint: .teal)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(AppL10n.text(.tokenMetering, appLanguage: settings.appLanguage))
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)

                        Text(AppL10n.text(.local, appLanguage: settings.appLanguage))
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 5)
                            .frame(height: 17)
                            .foregroundStyle(.teal)
                            .background(.teal.opacity(0.12), in: Capsule())
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(TokenUsageDashboardSnapshot.formatTokens(displayTotalTokens))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(AppL10n.text(.tokens, appLanguage: settings.appLanguage))
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(tokenMeteringSubtitle(topTask: topTask, topSource: topSource, eventCount: snapshot.eventCount))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Label(AppL10n.text(.details, appLanguage: settings.appLanguage), systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 74)
            .frame(maxWidth: .infinity)
            .background(.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.teal.opacity(0.10), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            tokenUsageDashboardStore.refresh()
        }
        .help(AppL10n.text(.openLocalTokenMeteringDetails, appLanguage: settings.appLanguage))
        .accessibilityLabel(
            AppL10n.tokenMeteringAccessibility(
                tokenCount: TokenUsageDashboardSnapshot.formatTokens(displayTotalTokens),
                appLanguage: settings.appLanguage
            )
        )
    }

    private func tokenMeteringSubtitle(
        topTask: TokenUsageDashboardBarRow?,
        topSource: TokenUsageDashboardBarRow?,
        eventCount: Int
    ) -> String {
        guard eventCount > 0 else {
            return AppL10n.text(.openSetupPrompt, appLanguage: settings.appLanguage)
        }

        let task = topTask.map { "\($0.title) \($0.value)" }
            ?? AppL10n.text(.noTaskSplit, appLanguage: settings.appLanguage)
        let source = topSource.map { "\($0.title) \($0.value)" }
            ?? AppL10n.text(.noSourceSplit, appLanguage: settings.appLanguage)
        return AppL10n.eventsSummary(eventCount: eventCount, task: task, source: source, appLanguage: settings.appLanguage)
    }

    private var aiToolColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 7),
            GridItem(.flexible(minimum: 0), spacing: 7)
        ]
    }

    private var aiSectionHeader: some View {
        HStack(spacing: 8) {
            Text("AI")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))

            Spacer()

            Button {
                showsServiceStatusDashboard = true
                cloudServiceStatusStore.refreshIfNeeded()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(serviceStatusTint)
                        .frame(width: 5, height: 5)

                    Image(systemName: serviceStatusSymbolName)

                    Text(serviceStatusButtonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: 9.5, weight: .bold))
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(serviceStatusTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(serviceStatusTint.opacity(0.12), lineWidth: 0.5)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsServiceStatusDashboard, arrowEdge: .top) {
                CloudServiceStatusDashboardView(store: cloudServiceStatusStore)
            }
            .help(serviceStatusHelpText)
            .accessibilityLabel(
                AppL10n.serviceStatusAccessibility(
                    status: serviceStatusButtonTitle,
                    appLanguage: settings.appLanguage
                )
            )

            Image(systemName: "sparkles")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }

    private var serviceStatusButtonTitle: String {
        if cloudServiceStatusStore.isLoading {
            return AppL10n.text(.checking, appLanguage: settings.appLanguage)
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return AppL10n.text(.serverStatus, appLanguage: settings.appLanguage)
        }

        return aggregateHealth.serverStatusHeaderTitle
    }

    private var serviceStatusHelpText: String {
        guard let snapshot = cloudServiceStatusStore.snapshot else {
            return AppL10n.text(.fetchOfficialServiceStatus, appLanguage: settings.appLanguage)
        }

        let aggregateHealth = CloudServiceStatusPresentation.aggregateHealth(for: snapshot.items)
        let issueCount = serviceStatusIssueItems.count
        let statusText = issueCount == 0
            ? String(
                format: AppL10n.text(.serverStatusNoIssues, appLanguage: settings.appLanguage),
                aggregateHealth.serverStatusHeaderTitle.lowercased()
            )
            : AppL10n.serverStatusWithIssues(
                status: aggregateHealth.serverStatusHeaderTitle.lowercased(),
                issueCount: issueCount,
                appLanguage: settings.appLanguage
            )
        return "\(statusText). \(AppL10n.lastChecked(fullServiceCheckTime(snapshot.fetchedAt), age: relativeServiceAge(from: snapshot.fetchedAt), appLanguage: settings.appLanguage)) \(AppL10n.text(.clickForPerServiceDetails, appLanguage: settings.appLanguage))"
    }

    private var serviceStatusSymbolName: String {
        if cloudServiceStatusStore.isLoading {
            return "arrow.triangle.2.circlepath"
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return "cloud.fill"
        }

        return aggregateHealth.serverStatusSymbolName
    }

    private var serviceStatusTint: Color {
        if cloudServiceStatusStore.isLoading {
            return .blue
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return .secondary
        }

        return aggregateHealth.serverStatusTint
    }

    private var serviceStatusIssueItems: [CloudServiceStatusItem] {
        cloudServiceStatusStore.snapshot?.items.filter { $0.health.isServerIssue } ?? []
    }

    private var aggregateServiceHealth: CloudServiceHealth? {
        cloudServiceStatusStore.snapshot.map {
            CloudServiceStatusPresentation.aggregateHealth(for: $0.items)
        }
    }

    private func serviceStatus(for kind: LocalAIToolKind) -> CloudServiceStatusItem? {
        CloudServiceStatusPresentation.serviceStatus(
            for: kind,
            in: cloudServiceStatusStore.snapshot
        )
    }

    private func fullServiceCheckTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current

        if Calendar.current.isDateInToday(date) {
            formatter.setLocalizedDateFormatFromTemplate("jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d, jm")
        }

        return formatter.string(from: date)
    }

    private func relativeServiceAge(from date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 {
            return AppL10n.text(.justNow, appLanguage: settings.appLanguage)
        }

        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return AppL10n.minutesAgo(minutes, appLanguage: settings.appLanguage)
        }

        return AppL10n.hoursAgo(max(1, minutes / 60), appLanguage: settings.appLanguage)
    }

    private func detailButton(
        target: SpillStatusDetailTarget,
        title: String,
        value: String,
        subtitle: String?,
        symbolName: String,
        tint: Color,
        detailRows: [SpillStatusDetailRow] = []
    ) -> some View {
        Button {
            panelStore.send(.setStatusDetailTarget(target))
        } label: {
            compactStatusPill(
                title: title,
                value: value,
                subtitle: subtitle,
                symbolName: symbolName,
                tint: tint,
                detailRows: detailRows
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: detailBinding(for: target), arrowEdge: .top) {
            statusDetailPopover(for: target)
        }
    }

    private func compactStatusPill(
        title: String,
        value: String,
        subtitle: String?,
        symbolName: String,
        tint: Color,
        detailRows: [SpillStatusDetailRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                statusIconBadge(symbolName: symbolName, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 2)

                        Text(value)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .monospacedDigit()
                    }

                    Text(subtitleText(subtitle))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .monospacedDigit()
                        .foregroundStyle(tint.opacity(0.72))
                }
            }

            if !detailRows.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(detailRows.prefix(3)) { row in
                        HStack(spacing: 4) {
                            Text(row.label)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text(row.value)
                                .monospacedDigit()
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: detailRows.isEmpty ? 60 : 92)
        .frame(maxWidth: .infinity)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactAIToolPill(
        _ status: LocalAIToolStatus,
        serviceStatus: CloudServiceStatusItem?
    ) -> some View {
        let tint = status.state.panelTint
        let isActive = status.state == .active
        let isUnavailable = status.state == .unavailable

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                aiToolIconBadge(symbolName: status.symbolName, tint: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.system(size: 10.5, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(isUnavailable ? .secondary : .primary)

                    Text(subtitleText(status.subtitle))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                aiStatusBadge(for: status, serviceStatus: serviceStatus)
            }

            Divider()
                .opacity(0.4)

            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(toolTokenValue(for: status.kind))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                    Text(AppL10n.text(.tokens, appLanguage: settings.appLanguage))
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                let ratio = toolTokenRatio(for: status.kind)
                let percentage = Int((ratio * 100).rounded())
                Text("\(percentage)%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 4)
                    .frame(height: 14)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(
            isActive ? tint.opacity(0.06) : Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? tint.opacity(0.12) : Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func toolTokenValue(for kind: LocalAIToolKind) -> String {
        let snapshot = tokenUsageDashboardStore.unfilteredSnapshot
        let rawValue: String
        switch kind {
        case .codex:
            rawValue = TokenUsageAITool.codex.rawValue
        case .claude:
            rawValue = TokenUsageAITool.claude.rawValue
        case .antigravity:
            rawValue = TokenUsageAITool.antigravity.rawValue
        case .openAI:
            rawValue = TokenUsageAITool.openAI.rawValue
        case .ollama:
            rawValue = "ollama"
        }

        if let row = snapshot.toolRows.first(where: { $0.id == rawValue }) {
            return row.value
        }
        return "0"
    }

    private func toolTokenRatio(for kind: LocalAIToolKind) -> Double {
        let snapshot = tokenUsageDashboardStore.unfilteredSnapshot
        let rawValue: String
        switch kind {
        case .codex:
            rawValue = TokenUsageAITool.codex.rawValue
        case .claude:
            rawValue = TokenUsageAITool.claude.rawValue
        case .antigravity:
            rawValue = TokenUsageAITool.antigravity.rawValue
        case .openAI:
            rawValue = TokenUsageAITool.openAI.rawValue
        case .ollama:
            rawValue = "ollama"
        }

        if let row = snapshot.toolRows.first(where: { $0.id == rawValue }) {
            return row.ratio
        }
        return 0.0
    }

    private func tokenPercentageBadge(for kind: LocalAIToolKind) -> some View {
        let snapshot = tokenUsageDashboardStore.unfilteredSnapshot
        let rawValue: String
        switch kind {
        case .codex:
            rawValue = TokenUsageAITool.codex.rawValue
        case .claude:
            rawValue = TokenUsageAITool.claude.rawValue
        case .antigravity:
            rawValue = TokenUsageAITool.antigravity.rawValue
        case .openAI:
            rawValue = TokenUsageAITool.openAI.rawValue
        case .ollama:
            rawValue = "ollama"
        }

        let ratio: Double
        if let row = snapshot.toolRows.first(where: { $0.id == rawValue }) {
            ratio = row.ratio
        } else {
            ratio = 0
        }

        let percentage = Int((ratio * 100).rounded())
        let tint = Color.teal

        return HStack(spacing: 4) {
            Text("\(percentage)%")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(tint)
        .background(
            tint.opacity(0.12),
            in: Capsule()
        )
    }

    private func aiToolIconBadge(symbolName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.14))

            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private func aiStatusBadge(
        for status: LocalAIToolStatus,
        serviceStatus: CloudServiceStatusItem?
    ) -> some View {
        if let serviceStatus {
            aiServerStatusBadge(serviceStatus)
        } else if CloudServiceStatusPresentation.serviceKinds(for: status.kind).isEmpty {
            aiLocalStatusBadge(status)
        } else {
            aiServerPendingBadge()
        }
    }

    private func aiLocalStatusBadge(_ status: LocalAIToolStatus) -> some View {
        let tint = status.state.panelTint
        let isRunning = status.state == .active
        let value = isRunning ? status.value : AppL10n.text(.local, appLanguage: settings.appLanguage)

        return HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)

            Text(value)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(isRunning ? tint : .secondary)
        .background(
            tint.opacity(isRunning ? 0.13 : 0.07),
            in: Capsule()
        )
    }

    private func aiServerPendingBadge() -> some View {
        let tint = cloudServiceStatusStore.isLoading ? Color.blue : Color.secondary
        let value = cloudServiceStatusStore.isLoading
            ? AppL10n.text(.checking, appLanguage: settings.appLanguage)
            : AppL10n.text(.server, appLanguage: settings.appLanguage)

        return HStack(spacing: 4) {
            Image(systemName: cloudServiceStatusStore.isLoading ? "arrow.triangle.2.circlepath" : "cloud.fill")
                .font(.system(size: 8, weight: .bold))

            Text(value)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
        .foregroundStyle(tint)
        .background(tint.opacity(0.10), in: Capsule())
        .help(AppL10n.text(.serverStatusPendingHelp, appLanguage: settings.appLanguage))
    }

    private func aiServerStatusBadge(_ item: CloudServiceStatusItem) -> some View {
        CloudServiceStatusBadge(item: item, appLanguage: settings.appLanguage)
    }

    private func statusIconBadge(symbolName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.14))

            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .bold))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 30, height: 30)
    }

    private func inlineRows(for module: SpillStatusModule) -> [SpillStatusDetailRow] {
        let rows = statusStore.detailRows(for: module)

        switch module {
        case .cpu:
            return rows.filter {
                [
                    AppL10n.text(.user, appLanguage: settings.appLanguage),
                    AppL10n.text(.system, appLanguage: settings.appLanguage),
                    AppL10n.text(.idleLabel, appLanguage: settings.appLanguage)
                ].contains($0.label)
            }
        case .memory:
            return rows.filter {
                [
                    AppL10n.text(.used, appLanguage: settings.appLanguage),
                    AppL10n.text(.wired, appLanguage: settings.appLanguage),
                    AppL10n.text(.compressed, appLanguage: settings.appLanguage)
                ].contains($0.label)
            }
        case .storage:
            return rows.filter {
                [
                    AppL10n.text(.used, appLanguage: settings.appLanguage),
                    AppL10n.text(.available, appLanguage: settings.appLanguage),
                    AppL10n.text(.total, appLanguage: settings.appLanguage)
                ].contains($0.label)
            }
        case .gpu:
            return rows.filter {
                [
                    AppL10n.text(.available, appLanguage: settings.appLanguage),
                    AppL10n.text(.budget, appLanguage: settings.appLanguage)
                ].contains($0.label)
            }
        case .network:
            return rows.filter {
                [
                    AppL10n.text(.receive, appLanguage: settings.appLanguage),
                    AppL10n.text(.upload, appLanguage: settings.appLanguage)
                ].contains($0.label)
            }
        }
    }

    private func sparklineSeries(for module: SpillStatusModule, tint: Color) -> [MetricSparklineSeries] {
        guard module == .network else {
            return [MetricSparklineSeries(values: statusStore.history(for: module), tint: tint)]
        }

        return [
            MetricSparklineSeries(values: statusStore.networkTrafficHistory.received, tint: .teal),
            MetricSparklineSeries(values: statusStore.networkTrafficHistory.sent, tint: .orange)
        ]
    }

    @ViewBuilder
    private func metricChart(for module: SpillStatusModule, status: SpillStatusMeterSnapshot) -> some View {
        switch module {
        case .cpu:
            let currentCoreValues = settings.showsCPUCoreChart
                ? statusStore.cpuCoreHistory.map { $0.last ?? 0 }
                : []
            ResourceLoadChartView(
                primaryTitle: "Active",
                secondaryTitle: "Idle",
                primaryRatio: statusStore.cpu.usageRatio,
                secondaryRatio: statusStore.cpu.availableRatio,
                peakRatio: peakUsageRatio(for: .cpu, currentRatio: statusStore.cpu.usageRatio),
                thresholdRatio: 0.9,
                history: statusStore.history(for: .cpu),
                tint: status.state.panelTint,
                barValues: currentCoreValues
            )
        case .memory:
            ResourceLoadChartView(
                primaryTitle: "Used",
                secondaryTitle: "Free",
                primaryRatio: statusStore.memory.usageRatio,
                secondaryRatio: max(0, 1 - statusStore.memory.usageRatio),
                peakRatio: peakUsageRatio(for: .memory, currentRatio: statusStore.memory.usageRatio),
                thresholdRatio: 0.9,
                history: statusStore.history(for: .memory),
                tint: status.state.panelTint
            )
        default:
            MetricSparklineView(
                series: sparklineSeries(for: module, tint: status.state.panelTint),
                normalizesToSeriesMaximum: module == .network
            )
        }
    }

    private func peakUsageRatio(for module: SpillStatusModule, currentRatio: Double) -> Double {
        let historyPeak = statusStore.history(for: module).max() ?? currentRatio
        return max(historyPeak, currentRatio).clamped(to: 0...1)
    }

    private func metricValueTint(for module: SpillStatusModule, state: SpillStatusState) -> Color {
        module == .network ? .teal : state.panelTint
    }

    private func metricSubtitleTint(for module: SpillStatusModule) -> Color {
        module == .network ? .orange : .secondary
    }

    @ViewBuilder
    private func statusDetailPopover(for target: SpillStatusDetailTarget) -> some View {
        switch target {
        case let .system(module):
            SpillStatusDetailPopover(
                title: AppL10n.statusModuleTitle(module, appLanguage: settings.appLanguage),
                symbolName: module.symbolName,
                tint: statusStore.state(for: module).panelTint,
                rows: statusStore.detailRows(for: module),
                showsInMenuBar: menuBarStatusBinding(for: module)
            )
        case let .ai(kind):
            let status = aiStatus(for: kind)
            SpillStatusDetailPopover(
                title: status.title,
                symbolName: status.symbolName,
                tint: status.state.panelTint,
                rows: SpillStatusDetailRows.rows(for: status),
                showsInMenuBar: nil
            )
        }
    }

    private func detailBinding(for target: SpillStatusDetailTarget) -> Binding<Bool> {
        Binding {
            panelState.statusDetailTarget == target
        } set: { isPresented in
            if isPresented {
                panelStore.send(.setStatusDetailTarget(target))
            } else if panelState.statusDetailTarget == target {
                panelStore.send(.setStatusDetailTarget(nil))
            }
        }
    }

    private func menuBarStatusBinding(for module: SpillStatusModule) -> Binding<Bool>? {
        guard let item = menuBarItem(for: module),
              SpillMenuBarStatusItem.glanceSupported.contains(item)
        else {
            return nil
        }

        return Binding {
            settings.isMenuBarStatusItemEnabled(item)
        } set: { isEnabled in
            settings.setMenuBarStatusItem(item, enabled: isEnabled)
        }
    }

    private func menuBarItem(for module: SpillStatusModule) -> SpillMenuBarStatusItem? {
        switch module {
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .storage:
            return nil
        case .gpu:
            return nil
        case .network:
            return nil
        }
    }

    private func aiStatus(for kind: LocalAIToolKind) -> LocalAIToolStatus {
        aiStatusStore.statuses.first { $0.kind == kind } ?? LocalAIToolStatus(
            kind: kind,
            value: "N/A",
            subtitle: nil,
            state: .unavailable
        )
    }

    private func subtitleText(_ subtitle: String?) -> String {
        guard let subtitle, !subtitle.isEmpty else {
            return AppL10n.text(.noDetail, appLanguage: settings.appLanguage)
        }

        return subtitle
    }

    private func performWindowAction(_ action: SpillAction) {
        panelStore.send(.performWindowAction(action))
    }

    private func windowHelpText(for action: SpillAction) -> String {
        var parts = [action.title]

        if let subtitle = action.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if let disabledReason = action.state.disabledReason {
            parts.append(disabledReason)
        }

        return parts.joined(separator: " - ")
    }

    private var emptyStateTitle: String {
        AppL10n.text(.noNotchCandidates, appLanguage: settings.appLanguage)
    }

    private var actionSections: some View {
        VStack(alignment: .leading, spacing: 7) {
            windowActionsSection
            menuBarActionsSection
        }
    }

    private var windowActionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader(AppL10n.text(.windows, appLanguage: settings.appLanguage), symbolName: "macwindow")

            if windowActionStore.actions.isEmpty {
                inlineState(symbolName: "macwindow", title: AppL10n.text(.noFocusedWindow, appLanguage: settings.appLanguage))
                    .frame(height: 50)
            } else {
                windowActionGrid
            }
        }
    }

    private var menuBarActionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader(AppL10n.text(.menuBar, appLanguage: settings.appLanguage), symbolName: "menubar.rectangle")

            Group {
                if panelState.readiness == .permissionRequired {
                    inlineState(symbolName: "lock.fill", title: AppL10n.text(.accessibilityRequired, appLanguage: settings.appLanguage))
                        .frame(height: 48)
                } else if panelState.readiness == .scanning && panelState.displayItems.isEmpty {
                    scanningState
                        .frame(height: 48)
                } else if panelState.actionItems.isEmpty {
                    inlineState(symbolName: "magnifyingglass", title: emptyStateTitle)
                        .frame(height: 48)
                } else {
                    menuBarActionGrid
                }
            }
        }
    }

    private var windowActionGrid: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Directional / Sizing Positions
            VStack(alignment: .center, spacing: 6) {
                Text(AppL10n.text(.positions, appLanguage: settings.appLanguage))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.leading, 1)

                VStack(spacing: 6) {
                    let positions: [[WindowActionKind]] = [
                        [.topLeft, .topHalf, .topRight],
                        [.leftHalf, .center, .rightHalf],
                        [.bottomLeft, .bottomHalf, .bottomRight]
                    ]

                    ForEach(0..<positions.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(positions[rowIndex], id: \.self) { kind in
                                if let action = action(for: kind) {
                                    WindowActionButton(
                                        action: action,
                                        shortcutKey: shortcutKey(for: action),
                                        appLanguage: settings.appLanguage
                                    ) {
                                        performWindowAction(action)
                                    }
                                    .help(windowHelpText(for: action))
                                    .accessibilityLabel(action.title)
                                }
                            }
                        }
                    }
                }
            }

            // Right Column: State & Utilities
            VStack(alignment: .center, spacing: 6) {
                Text(AppL10n.text(.utilities, appLanguage: settings.appLanguage))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.leading, 1)

                VStack(spacing: 6) {
                    let utilities: [[WindowActionKind]] = [
                        [.maximize, .restore],
                        [.previousDisplay, .nextDisplay]
                    ]

                    ForEach(0..<utilities.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(utilities[rowIndex], id: \.self) { kind in
                                if let action = action(for: kind) {
                                    WindowActionButton(
                                        action: action,
                                        shortcutKey: shortcutKey(for: action),
                                        appLanguage: settings.appLanguage
                                    ) {
                                        performWindowAction(action)
                                    }
                                    .help(windowHelpText(for: action))
                                    .accessibilityLabel(action.title)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 1)
    }

    private func action(for kind: WindowActionKind) -> SpillAction? {
        windowActionStore.actions.first { action in
            if case let .window(actionKind) = action.kind {
                return actionKind == kind
            }
            return false
        }
    }

    private var menuBarActionGrid: some View {
        LazyVGrid(columns: menuBarActionGridColumns, alignment: .leading, spacing: 6) {
            ForEach(panelState.actionItems) { item in
                SpillActionButton(
                    action: item.action,
                    isPinned: item.isPinned,
                    appLanguage: settings.appLanguage,
                    togglePinned: { panelStore.send(.togglePinned(item.sourceItem)) },
                    perform: { perform(item) }
                )
                .help(helpText(for: item))
                .accessibilityLabel(item.action.title)
            }
        }
        .padding(.horizontal, 1)
    }

    private var menuBarActionGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 48, maximum: 48),
                spacing: max(CGFloat(settings.iconSpacing), 7),
                alignment: .center
            )
        ]
    }

    private func shortcutKey(for action: SpillAction) -> WindowActionShortcutKey {
        guard case let .window(kind) = action.kind else {
            return .off
        }

        return settings.shortcutKey(for: kind)
    }

    private func perform(_ item: SpillDisplayedActionItem) {
        panelStore.send(.performMenuBarAction(item))
    }

    private var scanningState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.68)

            Text(AppL10n.text(.scanning, appLanguage: settings.appLanguage))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func inlineState(symbolName: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
    }

    private var footer: some View {
        SpillFooterView(
            isAccessibilityTrusted: panelState.readiness != .permissionRequired,
            isScanning: panelState.readiness == .scanning,
            sleepGuard: sleepGuard,
            sleepGuardDefaultDuration: settings.sleepGuardDefaultDuration,
            allowsIndefiniteDuration: settings.sleepGuardAllowsIndefinite,
            keepsDisplayAwake: settings.sleepGuardKeepsDisplayAwake,
            setSleepGuardDefaultDuration: { settings.sleepGuardDefaultDuration = $0 },
            showsPower: true,
            powerStatus: statusStore.power,
            showsCountBadge: true,
            itemCount: panelState.itemCount
        )
    }

    private func statusHelpText(title: String, value: String, subtitle: String?) -> String {
        var parts = [title, value]

        if let subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: " - ")
    }

    private func aiToolHelpText(_ status: LocalAIToolStatus, serviceStatus: CloudServiceStatusItem?) -> String {
        var text = statusHelpText(title: status.title, value: status.value, subtitle: status.subtitle)

        if let serviceStatus {
            text += " - \(AppL10n.text(.server, appLanguage: settings.appLanguage)) \(serviceStatus.health.serverStatusHeaderTitle)"
        }

        return text
    }

    private func helpText(for item: SpillDisplayedActionItem) -> String {
        var parts = [item.action.title]

        if let subtitle = item.action.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if item.sourceItem.isNotchCandidate {
            parts.append(AppL10n.text(.nearNotchEstimate, appLanguage: settings.appLanguage))
        }

        if let disabledReason = item.action.state.disabledReason {
            parts.append(disabledReason)
        }

        return parts.joined(separator: " - ")
    }

}

private struct MetricSparklineSeries {
    let values: [Double]
    let tint: Color
}

private struct ResourceLoadChartView: View {
    let primaryTitle: String
    let secondaryTitle: String
    let primaryRatio: Double
    let secondaryRatio: Double
    let peakRatio: Double
    let thresholdRatio: Double
    let history: [Double]
    let tint: Color
    var barValues: [Double] = []

    private var normalizedPrimaryRatio: Double {
        primaryRatio.clamped(to: 0...1)
    }

    private var normalizedSecondaryRatio: Double {
        secondaryRatio.clamped(to: 0...1)
    }

    private var normalizedPeakRatio: Double {
        peakRatio.clamped(to: 0...1)
    }

    private var normalizedThresholdRatio: Double {
        thresholdRatio.clamped(to: 0...1)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                legendDot(color: tint)

                Text(primaryTitle)
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(tint)

                Spacer(minLength: 4)

                Text("Pk \(Self.percentText(normalizedPeakRatio))")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(normalizedPeakRatio >= normalizedThresholdRatio ? Color.red : .secondary)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let markerX = max(0, min(width - 1, width * normalizedThresholdRatio))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.18))

                    Capsule()
                        .fill(tint.opacity(normalizedPrimaryRatio >= normalizedThresholdRatio ? 0.92 : 0.74))
                        .frame(width: max(2, width * normalizedPrimaryRatio))

                    Rectangle()
                        .fill(.primary.opacity(0.46))
                        .frame(width: 1, height: 9)
                        .offset(x: markerX)
                }
            }
            .frame(height: 8)

            Group {
                if barValues.isEmpty {
                    MetricSparklineView(
                        series: [MetricSparklineSeries(values: history, tint: tint)]
                    )
                } else {
                    CPUCoreBarChartView(coreValues: barValues, tint: tint)
                }
            }
            .frame(height: 14)

            HStack(spacing: 4) {
                Text("\(primaryTitle) \(Self.percentText(normalizedPrimaryRatio))")
                    .foregroundStyle(tint.opacity(0.9))

                Spacer(minLength: 4)

                Text("\(secondaryTitle) \(Self.percentText(normalizedSecondaryRatio))")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
        }
    }

    private func legendDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
    }

    private static func percentText(_ ratio: Double) -> String {
        "\(Int((ratio.clamped(to: 0...1) * 100).rounded()))%"
    }
}

private struct CPUCoreBarChartView: View {
    let coreValues: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let values = coreValues.map { $0.clamped(to: 0...1) }
            let coreCount = values.count

            guard coreCount > 0 else {
                drawFlatLine(in: &context, size: size)
                return
            }

            let topInset: CGFloat = 2
            let bottomInset: CGFloat = 2
            let availableHeight = max(size.height - topInset - bottomInset, 1)
            let slotWidth = size.width / CGFloat(coreCount)
            let gap = min(max(slotWidth * 0.24, 0.6), 1.8)
            let barWidth = max(slotWidth - gap, 1)
            let baselineY = size.height - bottomInset

            for (index, value) in values.enumerated() {
                let barHeight = max(availableHeight * CGFloat(value), value > 0 ? 1.2 : 0.8)
                let x = CGFloat(index) * slotWidth + (slotWidth - barWidth) * 0.5
                let rect = CGRect(
                    x: x,
                    y: baselineY - barHeight,
                    width: barWidth,
                    height: barHeight
                )
                let opacity = 0.28 + 0.68 * value
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(barWidth * 0.45, 1.8)),
                    with: .color(tint.opacity(opacity))
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func drawFlatLine(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let y = size.height * 0.5
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(path, with: .color(tint.opacity(0.42)), lineWidth: 1.3)
    }
}

private struct MetricSparklineView: View {
    let series: [MetricSparklineSeries]
    var normalizesToSeriesMaximum = false

    var body: some View {
        Canvas { context, size in
            let rawSeries = series.map { series in
                MetricSparklineSeries(
                    values: series.values.suffix(24).map { max($0, 0) },
                    tint: series.tint
                )
            }
            let scale = normalizesToSeriesMaximum
                ? rawSeries.flatMap(\.values).max() ?? 0
                : 1
            let normalizedSeries = rawSeries.map { series in
                MetricSparklineSeries(
                    values: series.values.map { value in
                        if normalizesToSeriesMaximum {
                            guard scale > 0 else {
                                return 0
                            }
                            return min(value / scale, 1)
                        }
                        return min(value, 1)
                    },
                    tint: series.tint
                )
            }

            guard normalizedSeries.contains(where: { $0.values.count >= 2 }),
                  (!normalizesToSeriesMaximum || scale > 0)
            else {
                drawFlatLine(in: &context, size: size)
                return
            }

            for (seriesIndex, series) in normalizedSeries.enumerated() where series.values.count >= 2 {
                let path = smoothedPath(for: series.values, size: size)

                // 1. Draw elegant vertical linear gradient area fill under the curve
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()

                let fillOpacity: Double = normalizedSeries.count > 1 ? 0.12 : 0.22
                let gradient = Gradient(colors: [series.tint.opacity(fillOpacity), series.tint.opacity(0.0)])
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. Draw high-end glowing stroked line
                var shadowContext = context
                shadowContext.addFilter(.shadow(color: series.tint.opacity(0.3), radius: 1.5, x: 0, y: 1))
                shadowContext.stroke(
                    path,
                    with: .color(series.tint.opacity(seriesIndex == 0 ? 0.95 : 0.8)),
                    lineWidth: seriesIndex == 0 ? 2.0 : 1.6
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func smoothedPath(for values: [Double], size: CGSize) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }

        let xStep = size.width / CGFloat(values.count - 1)
        var points: [CGPoint] = []

        for (index, value) in values.enumerated() {
            points.append(CGPoint(
                x: CGFloat(index) * xStep,
                y: size.height - CGFloat(value) * size.height
            ))
        }

        path.move(to: points[0])

        for i in 0..<points.count - 1 {
            let p0 = points[i]
            let p1 = points[i+1]
            let midPoint = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)

            if i == 0 {
                path.addLine(to: midPoint)
            } else {
                path.addQuadCurve(to: midPoint, control: p0)
            }

            if i == points.count - 2 {
                path.addLine(to: p1)
            }
        }

        return path
    }

    private func drawFlatLine(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let y = size.height * 0.5
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        let tint = series.first?.tint ?? .secondary
        context.stroke(path, with: .color(tint.opacity(0.42)), lineWidth: 1.3)
    }
}
