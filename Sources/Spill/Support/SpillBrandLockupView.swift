import AppKit
import SwiftUI

struct SpillBrandLockupView: View {
    let subtitle: String?
    var iconSize: CGFloat = 34
    var titleFontSize: CGFloat = 13
    var titleWeight: Font.Weight = .semibold
    var titleDesign: Font.Design = .default
    var titleColor: Color = .primary
    var subtitleFontSize: CGFloat = 10
    var subtitleWeight: Font.Weight = .medium
    var subtitleDesign: Font.Design = .default
    var subtitleColor: Color = .secondary
    var spacing: CGFloat = 10
    var wordmarkHeightMultiplier: CGFloat = 1.35
    private let wordmarkAspectRatio: CGFloat = 3212.0 / 1588.0

    var body: some View {
        let wordmarkHeight = titleFontSize * wordmarkHeightMultiplier

        HStack(spacing: spacing) {
            SpillBrandIconView()
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                wordmark
                    .frame(width: wordmarkHeight * wordmarkAspectRatio, height: wordmarkHeight, alignment: .leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: subtitleFontSize, weight: subtitleWeight, design: subtitleDesign))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabelText))
    }

    @ViewBuilder
    private var wordmark: some View {
        if let image = Bundle.module.image(forResource: "spill-logo-wordmark") {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("Spill")
                .font(.system(size: titleFontSize, weight: titleWeight, design: titleDesign))
                .foregroundStyle(titleColor)
                .lineLimit(1)
        }
    }

    private var accessibilityLabelText: String {
        guard let subtitle, !subtitle.isEmpty else {
            return "Spill"
        }
        return "Spill, \(subtitle)"
    }
}
