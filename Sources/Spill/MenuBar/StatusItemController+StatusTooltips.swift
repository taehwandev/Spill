import AppKit

extension StatusItemController {
    func installStatusContentView(
        on button: NSStatusBarButton,
        contentView: inout MenuBarStatusContentView?,
        segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle,
        textFontSize: CGFloat,
        textIsBold: Bool,
        groupsMainCaffeine: Bool,
        rebuildsContentView: Bool
    ) {
        guard rebuildsContentView || contentView == nil else {
            return
        }

        removeStatusContentView(&contentView)

        let nextContentView = MenuBarStatusContentView(
            segments: segments,
            layoutStyle: layoutStyle,
            textFontSize: textFontSize,
            textIsBold: textIsBold,
            groupsMainCaffeine: groupsMainCaffeine
        )
        button.addSubview(nextContentView)
        NSLayoutConstraint.activate([
            nextContentView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            nextContentView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            nextContentView.topAnchor.constraint(equalTo: button.topAnchor),
            nextContentView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        contentView = nextContentView
    }

    func removeStatusContentView(_ contentView: inout MenuBarStatusContentView?) {
        contentView?.removeFromSuperview()
        contentView = nil
    }

    func attributedTitle(_ title: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }
}
