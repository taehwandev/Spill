import SwiftUI

/// A readable quota card. The caller owns selection, formatting and data;
/// this component owns layout, native button focus and hover feedback.
struct TokenMeteringDashboardLimitCard: View {
    struct Item: Identifiable {
        let snapshot: TokenUsageLimitSnapshot
        let title: String
        let value: String
        let reset: String?
        let age: String?
        let tooltip: String
        let dimmed: Bool
        var id: String { snapshot.limitKey }
    }

    let title: String
    let tint: Color
    let remainingCaption: String
    let items: [Item]
    let emptyText: String
    let extraText: String?
    let accessibilityText: String
    let onOpen: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 4)
                    if let extraText {
                        Text(extraText).font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(remainingCaption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                if items.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider().frame(height: 34) }
                            quotaWindow(item)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.065 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isFocused ? tint : Color.primary.opacity(0.09), lineWidth: isFocused ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityText)
    }

    private func quotaWindow(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                TokenUsageLimitRing(snapshot: item.snapshot, diameter: 12)
                Text(item.value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
            if let reset = item.reset {
                Text(reset)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let age = item.age {
                Text(age)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(item.tooltip)
        .opacity(item.dimmed ? 0.6 : 1)
    }
}
