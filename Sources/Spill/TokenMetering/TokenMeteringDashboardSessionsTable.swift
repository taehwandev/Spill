import SwiftUI

struct TokenMeteringDashboardSessionsTable: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let selectedControlAccent: Color
    let showsPlaceholder: Bool
    let requestClear: (TokenUsageClearScope) -> Void
    @State private var hoveredSessionID: String? = nil

    var body: some View {
        TokenMeteringDashboardPanel(
            title: t(.runs),
            subtitle: t(.runsSubtitle),
            infoTitle: t(.runsInfoTitle),
            infoDetail: t(.runsInfoDetail)
        ) {
            if showsPlaceholder {
                TokenMeteringDashboardLoadingSessionRows(
                    runTitle: t(.run),
                    eventsTitle: t(.events),
                    tokensTitle: t(.tokens)
                )
            } else if store.snapshot.sessions.isEmpty {
                TokenMeteringDashboardEmptyMessage(
                    title: t(.noLocalTokenEvents),
                    detail: t(.noLocalTokenEventsDetail)
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    projectFilterBar
                        .padding(.bottom, 10)

                    HStack(spacing: 12) {
                        TokenMeteringDashboardTableHeader(t(.run))
                        TokenMeteringDashboardTableHeader(t(.events))
                            .frame(width: 150, alignment: .leading)
                        TokenMeteringDashboardTableHeader(t(.tokens))
                            .frame(width: 96, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    ForEach(store.snapshot.sessions.prefix(8)) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var projectFilterBar: some View {
        if store.snapshot.projectFilters.count > 2 {
            VStack(alignment: .leading, spacing: 5) {
                Text(t(.folderFilterHeader))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(store.snapshot.projectFilters) { filter in
                            projectFilterPill(filter)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func projectFilterPill(_ filter: TokenUsageDashboardProjectFilter) -> some View {
        Button {
            store.setSelectedProjectID(filter.projectID)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.projectID == nil ? "folder" : "folder.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(filter.title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                Text(filter.detail)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(filter.isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(filter.isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                filter.isSelected ? selectedControlAccent : Color.primary.opacity(0.035),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(filter.isSelected ? selectedControlAccent.opacity(0.32) : Color.primary.opacity(0.05), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func sessionRow(_ session: TokenUsageDashboardSessionRow) -> some View {
        let isSelected = store.selectedSessionID == session.id
        let liveUpdateID = "session:\(session.id)"
        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
        let isHovered = hoveredSessionID == session.id

        return Button {
            if isSelected {
                store.clearWorkItemSelection()
            } else {
                store.selectSession(session.id)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                        Text(session.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "folder.fill" : "folder")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text(session.projectTitle)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(session.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
                Text(session.value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 96, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: session.value)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : .primary)
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .offset(y: isHovered ? -0.5 : 0)
            .background(
                ZStack {
                    if isSelected {
                        selectedControlAccent.opacity(isHovered ? 0.9 : 0.8)
                    } else {
                        if isHovered {
                            Color.primary.opacity(0.04)
                        } else {
                            Color.clear
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isSelected
                            ? selectedControlAccent.opacity(0.15)
                            : Color.primary.opacity(isHovered ? 0.06 : 0.03),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: (isSelected ? selectedControlAccent : Color.black).opacity(isHovered ? 0.03 : 0),
                radius: isHovered ? 3 : 0,
                y: isHovered ? 1.5 : 0
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hoveredSessionID)
            .onHover { hovering in
                hoveredSessionID = hovering ? session.id : nil
            }
            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isSelected && !isHovered, marker: store.liveUpdateMarker, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .contextMenu {
            if SpillBuildOptions.developerOptionsEnabled {
                Button(role: .destructive) {
                    requestClear(.workItem(session.id))
                    if store.selectedSessionID == session.id {
                        store.clearWorkItemSelection()
                    }
                } label: {
                    Label(t(.clearSelectedWorkItem), systemImage: "trash")
                }
            }
        }
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
