import SwiftUI

struct SpillGlanceView: View {
    @ObservedObject var store: SpillGlanceStore
    let openDashboardAction: () -> Void
    let openSettingsAction: () -> Void
    let dragAction: (SpillGlanceDragPhase) -> Void

    @State private var isDragging = false

    @ViewBuilder
    var body: some View {
        if let workRotationEpoch {
            TimelineView(
                .periodic(
                    from: workRotationEpoch,
                    by: SpillGlanceItem.rotationInterval
                )
            ) { context in
                content(at: context.date)
            }
        } else {
            content(at: .distantPast)
        }
    }

    private func content(at date: Date) -> some View {
        SpillGlanceSurface(items: store.presentation.items, date: date)
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard isDragging || isDrag(value.translation) else {
                            return
                        }
                        isDragging = true
                        dragAction(.changed(value.translation))
                    }
                    .onEnded { value in
                        let didDrag = isDragging || isDrag(value.translation)
                        isDragging = false
                        if didDrag {
                            dragAction(.ended(value.translation))
                        } else if isSettingsLocation(value.location) {
                            openSettingsAction()
                        } else {
                            openDashboardAction()
                        }
                    }
            )
            .help("Open AI Token Dashboard · Drag to move")
            .accessibilityLabel(accessibilityLabel(at: date))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                openDashboardAction()
            }
            .accessibilityAction(named: Text("Open Spill Glance Settings")) {
                openSettingsAction()
            }
    }

    private var workRotationEpoch: Date? {
        guard let workItem = store.presentation.items.first(where: {
            $0.module == .workType && $0.displayValues.count > 1
        }) else {
            return nil
        }
        return workItem.rotationEpoch
    }

    private func accessibilityLabel(at date: Date) -> String {
        let summary = store.presentation.items
            .map { "\($0.title), \($0.displayValue(at: date))" }
            .joined(separator: "; ")
        return summary.isEmpty ? "Spill Glance" : "Spill Glance: \(summary)"
    }

    private func isSettingsLocation(_ location: CGPoint) -> Bool {
        let totalWidth = SpillGlanceLayout.contentSize(
            modules: store.presentation.items.map(\.module)
        ).width
        return location.x >= totalWidth - SpillGlanceLayout.settingsControlWidth
    }

    private func isDrag(_ translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) >= 3
    }
}

private struct SpillGlanceSurface: View {
    let items: [SpillGlanceItem]
    let date: Date

    var body: some View {
        groupedSurface
            .clipShape(Capsule(style: .continuous))
    }

    @ViewBuilder
    private var groupedSurface: some View {
        if #available(macOS 26.0, *) {
            groupedContent
                .glassEffect(
                    .regular.interactive(),
                    in: Capsule(style: .continuous)
                )
        } else {
            groupedContent
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
    }

    private var groupedContent: some View {
        HStack(spacing: SpillGlanceLayout.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    separator
                }

                SpillGlanceModuleContent(item: item, date: date)
                    .frame(
                        width: SpillGlanceLayout.itemWidth(for: item.module),
                        height: SpillGlanceLayout.contentHeight
                    )
            }

            separator

            SpillGlanceSettingsContent()
                .frame(
                    width: SpillGlanceLayout.settingsControlWidth,
                    height: SpillGlanceLayout.contentHeight
                )
        }
        .frame(
            width: SpillGlanceLayout.contentSize(
                modules: items.map(\.module)
            ).width,
            height: SpillGlanceLayout.contentHeight
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(
                width: SpillGlanceLayout.separatorWidth,
                height: 14
            )
    }
}

private struct SpillGlanceModuleContent: View {
    let item: SpillGlanceItem
    let date: Date

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: item.symbolName)
                .font(.system(size: 8.5, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.tint.color)
                .frame(width: 10)

            if !item.module.isTool {
                Text(item.title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            valueText(item.displayValue(at: date))
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .contentTransition(.interpolate)
            .animation(.easeInOut(duration: 0.18), value: value)
    }
}

private struct SpillGlanceSettingsContent: View {
    var body: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 10, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}
