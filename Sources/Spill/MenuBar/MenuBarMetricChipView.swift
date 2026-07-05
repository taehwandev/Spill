import AppKit

@MainActor
final class MenuBarMetricChipView: NSView {
    let segment: MenuBarStatusSegment
    let textFontSize: CGFloat
    let textIsBold: Bool
    let iconView = NSImageView()
    let valueLabel = NSTextField(labelWithString: "")
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0

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
        startAnimationIfNeeded()

        setAccessibilityLabel(accessibilityText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    private func configureIcon() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        if case let .trigger(style) = segment.visualStyle,
           let image = MenuBarTriggerIconRenderer.image(
               style: style,
               tintColor: statusColor,
               usageRatio: segment.usageRatio,
               phase: animationPhase,
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

    private func startAnimationIfNeeded() {
        guard shouldAnimateTrigger else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceAnimationFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func advanceAnimationFrame() {
        animationPhase += animationStep
        if animationPhase >= 1 {
            animationPhase.formTruncatingRemainder(dividingBy: 1)
        }

        configureIcon()
    }

    private var animationStep: CGFloat {
        let loadBoost = CGFloat(segment.usageRatio.clamped(to: 0...1)) * 0.055
        switch segment.state {
        case .warning:
            return 0.105 + loadBoost
        case .active, .refreshing:
            return 0.075 + loadBoost
        case .normal:
            return 0.045 + loadBoost
        case .unavailable:
            return 0.03
        }
    }

    private var shouldAnimateTrigger: Bool {
        segment.animates && hasCustomTriggerIcon
    }

}
