import SwiftUI

struct DetectedItemsListView: View {
    let items: [MenuBarItemSnapshot]
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Items", systemImage: "list.bullet.rectangle")
                    .foregroundStyle(.secondary)

                Spacer()

                Text(selectionSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if !settings.selectedItemKeys.isEmpty {
                    Button {
                        settings.clearSelectedItems()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .font(.caption)
                }
            }

            if items.isEmpty {
                Text("No items detected.")
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

    private var selectionSummary: String {
        if staleSelectedCount > 0 {
            return "\(activeSelectedCount) active, \(staleSelectedCount) saved"
        }

        return "\(activeSelectedCount) selected"
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
                let selected = settings.selectionState(for: item) == .selected
                settings.setItem(item, selected: !selected)
            } label: {
                Image(systemName: selectionIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectionColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(selectionHelpText)
            .accessibilityLabel(selectionHelpText)

            if item.isNotchCandidate {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(Color.accentColor)
                    .help("Near notch estimate")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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

    private var selectionIconName: String {
        isSelected ? "checkmark.circle.fill" : "plus.circle"
    }

    private var selectionColor: Color {
        isSelected ? .accentColor : .secondary
    }

    private var selectionHelpText: String {
        isSelected ? "Remove from Spill Bar" : "Add to Spill Bar"
    }
}
