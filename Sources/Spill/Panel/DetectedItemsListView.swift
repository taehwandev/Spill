import SwiftUI

struct DetectedItemsListView: View {
    let items: [MenuBarItemSnapshot]
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(AppL10n.text(.items, appLanguage: settings.appLanguage), systemImage: "list.bullet.rectangle")
                    .foregroundStyle(.secondary)

                Spacer()

                Text(selectionSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if !settings.selectedItemKeys.isEmpty {
                    Button {
                        settings.clearSelectedItems()
                    } label: {
                        Label(AppL10n.text(.clear, appLanguage: settings.appLanguage), systemImage: "xmark.circle")
                    }
                    .font(.caption)
                }
            }

            if items.isEmpty {
                Text(AppL10n.text(.noItemsDetected, appLanguage: settings.appLanguage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items.prefix(12)) { item in
                            DetectedItemRow(item: item, settings: settings)

                            if item.id != items.prefix(12).last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(minHeight: 80, maxHeight: 130)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var activeSelectedCount: Int {
        items.filter { settings.selectedItemKeys.contains($0.stableKey) }.count
    }

    private var staleSelectedCount: Int {
        max(0, settings.selectedItemKeys.count - activeSelectedCount)
    }

    private var activeHiddenCount: Int {
        items.filter { settings.hiddenItemKeys.contains($0.stableKey) }.count
    }

    private var selectionSummary: String {
        if activeHiddenCount > 0 {
            return AppL10n.selectedHiddenSummary(
                selected: activeSelectedCount,
                hidden: activeHiddenCount,
                appLanguage: settings.appLanguage
            )
        }

        if staleSelectedCount > 0 {
            return AppL10n.activeSavedSummary(
                active: activeSelectedCount,
                saved: staleSelectedCount,
                appLanguage: settings.appLanguage
            )
        }

        return AppL10n.selectedSummary(activeSelectedCount, appLanguage: settings.appLanguage)
    }
}

private struct DetectedItemRow: View {
    let item: MenuBarItemSnapshot
    @ObservedObject var settings: SpillSettings

    var body: some View {
        HStack(spacing: 8) {
            icon

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .font(.callout)
                    .lineLimit(1)

                Text(item.ownerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if isSelected {
                    settings.setItem(item, selected: false)
                } else {
                    settings.setItem(item, selected: true)
                }
            } label: {
                Image(systemName: pinIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pinColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(pinHelpText)
            .accessibilityLabel(pinHelpText)

            Button {
                if isHidden {
                    settings.showItem(item)
                } else {
                    settings.hideItem(item)
                }
            } label: {
                Image(systemName: visibilityIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(visibilityColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(visibilityHelpText)
            .accessibilityLabel(visibilityHelpText)

            if item.isNotchCandidate {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(Color.accentColor)
                    .help(AppL10n.text(.nearNotchEstimate, appLanguage: settings.appLanguage))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(isHidden ? 0.56 : 1)
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(.quaternary)

            if let image = item.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text(item.shortLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
        .frame(width: 24, height: 24)
    }

    private var isSelected: Bool {
        settings.selectionState(for: item) == .selected
    }

    private var isHidden: Bool {
        settings.isItemHidden(item)
    }

    private var pinIconName: String {
        isSelected ? "pin.fill" : "pin"
    }

    private var pinColor: Color {
        isSelected ? .teal : .secondary
    }

    private var pinHelpText: String {
        isSelected
            ? AppL10n.text(.unpinFromSpill, appLanguage: settings.appLanguage)
            : AppL10n.text(.pinInSpill, appLanguage: settings.appLanguage)
    }

    private var visibilityIconName: String {
        isHidden ? "eye.slash.fill" : "eye"
    }

    private var visibilityColor: Color {
        isHidden ? .orange : .secondary
    }

    private var visibilityHelpText: String {
        isHidden
            ? AppL10n.text(.showInSpill, appLanguage: settings.appLanguage)
            : AppL10n.text(.hideInSpill, appLanguage: settings.appLanguage)
    }
}
