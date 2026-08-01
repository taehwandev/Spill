import SwiftUI

struct SpillGlanceView: View {
    @ObservedObject var store: SpillGlanceStore
    let openDashboardAction: () -> Void
    let openSettingsAction: () -> Void
    let dragAction: (SpillGlanceDragPhase) -> Void

    @State private var isDragging = false

    @ViewBuilder
    var body: some View {
        if let rotationSchedule {
            TimelineView(rotationSchedule) { context in
                content(at: context.date)
            }
        } else {
            content(at: .distantPast)
        }
    }

    private var rotationSchedule: SpillGlanceRotationTimelineSchedule? {
        let rotation = store.presentation.rotationSchedule
        guard rotation != .none else {
            return nil
        }
        return SpillGlanceRotationTimelineSchedule(rotation: rotation)
    }

    private func content(at date: Date) -> some View {
        let items = store.presentation.visibleItems(at: date)
        return SpillGlanceSurface(
            items: items,
            displayStyle: store.presentation.displayStyle,
            date: date
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: SpillGlanceLayout.cornerRadius,
                style: .continuous
            )
        )
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

    /// Always reads every module, not just the slot currently on screen: in
    /// ticker styles the other values would otherwise be unreachable.
    private func accessibilityLabel(at date: Date) -> String {
        let summary = store.presentation.items
            .map { "\($0.title), \($0.displayValue(at: date))" }
            .joined(separator: "; ")
        return summary.isEmpty ? "Spill Glance" : "Spill Glance: \(summary)"
    }

    private func isSettingsLocation(_ location: CGPoint) -> Bool {
        let contentSize = SpillGlanceLayout.contentSize(
            modules: store.presentation.items.map(\.module),
            displayStyle: store.presentation.displayStyle
        )
        return location.x >= contentSize.width - SpillGlanceLayout.settingsControlWidth
    }

    private func isDrag(_ translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) >= 3
    }
}

private struct SpillGlanceSurface: View {
    let items: [SpillGlanceItem]
    let displayStyle: SpillGlanceDisplayStyle
    let date: Date

    var body: some View {
        groupedSurface
            .clipShape(surfaceShape)
    }

    @ViewBuilder
    private var groupedSurface: some View {
        if #available(macOS 26.0, *) {
            groupedContent
                .glassEffect(
                    .regular.interactive(),
                    in: surfaceShape
                )
        } else {
            groupedContent
                .background(.ultraThinMaterial, in: surfaceShape)
        }
    }

    @ViewBuilder
    private var groupedContent: some View {
        switch displayStyle {
        case .all:
            allContent
        case .ticker:
            tickerContent
        }
    }

    private var allContent: some View {
        HStack(spacing: SpillGlanceLayout.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    separator
                }

                SpillGlanceModuleContent(item: item, date: date, labelStyle: .compact)
                    .frame(
                        width: SpillGlanceLayout.itemWidth(for: item.module),
                        height: SpillGlanceLayout.contentHeight
                    )
            }

            separator
            settingsContent
        }
        .frame(
            width: SpillGlanceLayout.contentSize(
                modules: items.map(\.module),
                displayStyle: .all
            ).width,
            height: SpillGlanceLayout.contentHeight
        )
    }

    private var tickerContent: some View {
        HStack(spacing: SpillGlanceLayout.itemSpacing) {
            ZStack {
                if let item = items.first {
                    SpillGlanceModuleContent(item: item, date: date, labelStyle: .full)
                        .id(item.renderID)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                }
            }
            .frame(
                width: SpillGlanceLayout.tickerItemWidth,
                height: SpillGlanceLayout.contentHeight
            )
            .clipped()
            .animation(.easeInOut(duration: 0.30), value: items.first?.renderID)

            separator
            settingsContent
        }
        .frame(
            width: SpillGlanceLayout.contentSize(
                modules: items.map(\.module),
                displayStyle: .ticker
            ).width,
            height: SpillGlanceLayout.contentHeight
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(
                width: SpillGlanceLayout.separatorWidth,
                height: 18
            )
    }

    private var settingsContent: some View {
        SpillGlanceSettingsContent()
            .frame(
                width: SpillGlanceLayout.settingsControlWidth,
                height: SpillGlanceLayout.contentHeight
            )
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: SpillGlanceLayout.cornerRadius,
            style: .continuous
        )
    }
}

private enum SpillGlanceLabelStyle {
    case compact
    case full
}

private struct SpillGlanceModuleContent: View {
    let item: SpillGlanceItem
    let date: Date
    let labelStyle: SpillGlanceLabelStyle

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.symbolName)
                .font(.system(size: 8.5, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.tint.color)
                .frame(width: 14, height: 14)
                .background(item.tint.color.opacity(0.14), in: Circle())

            Text(displayTitle)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            valueText(item.displayValue(at: date))
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        guard labelStyle == .compact else {
            return item.title
        }
        return item.module.compactTitle ?? item.title
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
