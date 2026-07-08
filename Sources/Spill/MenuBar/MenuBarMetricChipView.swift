import AppKit

@MainActor
final class MenuBarMetricChipView: NSView {
    let segment: MenuBarStatusSegment
    let textFontSize: CGFloat
    let textIsBold: Bool
    let iconView = NSImageView()
    let valueLabel = NSTextField(labelWithString: "")

    init(segment: MenuBarStatusSegment, textFontSize: CGFloat, textIsBold: Bool) {
        self.segment = segment
        self.textFontSize = textFontSize
        self.textIsBold = textIsBold
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        configureIcon()
        configureValue()
        installSubviews()
        refreshColors()
        registerForAnimationFramesIfNeeded()

        setAccessibilityLabel(accessibilityText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    func configureIcon() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        if case let .trigger(style) = segment.visualStyle,
           let image = MenuBarTriggerIconRenderer.image(
               style: style,
               phase: TriggerIconAnimator.shared.phase,
               size: iconSize
           )
        {
            iconView.image = image
            iconView.symbolConfiguration = nil
            return
        }

        iconView.image = MenuBarSymbolImageCache.image(
            named: resolvedSymbolName,
            accessibilityDescription: segment.title,
            pointSize: symbolPointSize
        )
        iconView.symbolConfiguration = nil
    }

    /// This view is torn down and rebuilt almost every refresh, so it must not own the
    /// animation timer itself (see `TriggerIconAnimator`). It only re-registers to redraw on
    /// each frame the shared, persistent animator produces — whichever chip view was created
    /// most recently "wins" this registration, and stale closures targeting a deallocated
    /// prior view are harmless no-ops via `[weak self]`. Starting/stopping the shared animator
    /// is `StatusItemController`'s job, tied to settings, not this view's lifecycle.
    private func registerForAnimationFramesIfNeeded() {
        guard shouldAnimateTrigger else {
            return
        }

        TriggerIconAnimator.shared.onFrame = { [weak self] in
            self?.configureIcon()
        }
    }

    private var shouldAnimateTrigger: Bool {
        segment.animates && hasCustomTriggerIcon
    }

}
