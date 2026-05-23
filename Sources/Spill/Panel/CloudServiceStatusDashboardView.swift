import AppKit
import SwiftUI

struct CloudServiceStatusDashboardView: View {
    @ObservedObject var store: CloudServiceStatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 7) {
                ForEach(items) { item in
                    serviceRow(item)
                }
            }

            Text(footerText)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 292)
        .onAppear {
            store.refreshIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Service Status", systemImage: "cloud.fill")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                store.refreshIfNeeded(force: NSEvent.modifierFlags.contains(.option))
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .help("Refresh")
        }
    }

    private var items: [CloudServiceStatusItem] {
        store.snapshot?.items ?? CloudServiceKind.allCases.map { kind in
            CloudServiceStatusItem(
                kind: kind,
                health: .unknown,
                detail: "Open dashboard to fetch official status",
                source: "Not fetched"
            )
        }
    }

    private func serviceRow(_ item: CloudServiceStatusItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.health.panelTint.opacity(0.14))

                Image(systemName: item.symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.health.panelTint)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(item.health.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(item.health.panelTint)
                        .lineLimit(1)
                }

                Text(item.detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var footerText: String {
        guard let snapshot = store.snapshot else {
            return "Official status is fetched only when this dashboard opens."
        }

        return "Last checked \(formattedCheckTime(snapshot.fetchedAt)) (\(relativeAge(from: snapshot.fetchedAt)))."
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
            return "just now"
        }

        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        return "\(max(1, minutes / 60))h ago"
    }
}

private extension CloudServiceHealth {
    var panelTint: Color {
        switch self {
        case .operational:
            return .green
        case .degraded:
            return .orange
        case .outage:
            return .red
        case .maintenance:
            return .blue
        case .unknown:
            return .secondary
        }
    }
}
