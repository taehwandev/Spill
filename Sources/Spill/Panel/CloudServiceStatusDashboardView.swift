import AppKit
import SwiftUI

struct CloudServiceStatusDashboardView: View {
    @ObservedObject var store: CloudServiceStatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    serviceRow(item)
                }
            }

            Divider()
                .background(Color.primary.opacity(0.06))
                .padding(.vertical, 2)

            Text(footerText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 310)
        .background {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.04),
                        Color.blue.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear {
            store.refreshIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Label(AppL10n.text(.statusDetails), systemImage: "server.rack")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(headerSubtitle)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.refreshIfNeeded(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .help(AppL10n.text(.refreshForceHelp))
        }
        .padding(.bottom, 4)
    }

    private var headerSubtitle: String {
        if store.isLoading {
            return AppL10n.text(.checkingOfficialSources)
        }

        guard let snapshot = store.snapshot else {
            return AppL10n.text(.fetchedWhenOpen)
        }

        return AppL10n.servicesFromOfficialSources(snapshot.items.count)
    }

    private var items: [CloudServiceStatusItem] {
        store.snapshot?.items ?? CloudServiceKind.allCases.map { kind in
            CloudServiceStatusItem(
                kind: kind,
                health: .unknown,
                detail: AppL10n.text(.openDashboardToFetchStatus),
                source: AppL10n.text(.notFetched)
            )
        }
    }

    private func serviceRow(_ item: CloudServiceStatusItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.health.serverStatusTint.opacity(0.12))

                Image(systemName: item.symbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.health.serverStatusTint)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(item.health.serverStatusHeaderTitle)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(item.health.serverStatusTint)
                        .lineLimit(1)
                }

                Text(item.detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            statusPageButton(item)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func statusPageButton(_ item: CloudServiceStatusItem) -> some View {
        Button {
            NSWorkspace.shared.open(item.statusPageURL)
        } label: {
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(AppL10n.openStatusPage(item.title))
        .accessibilityLabel(AppL10n.openStatusPage(item.title))
    }

    private var footerText: String {
        guard let snapshot = store.snapshot else {
            return AppL10n.text(.officialStatusFetchedOnOpen)
        }

        return AppL10n.lastChecked(formattedCheckTime(snapshot.fetchedAt), age: relativeAge(from: snapshot.fetchedAt))
    }

    private func formattedCheckTime(_ date: Date) -> String {
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

    private func relativeAge(from date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))

        if elapsed < 60 {
            return AppL10n.text(.justNow)
        }

        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return AppL10n.minutesAgo(minutes)
        }

        return AppL10n.hoursAgo(max(1, minutes / 60))
    }
}
