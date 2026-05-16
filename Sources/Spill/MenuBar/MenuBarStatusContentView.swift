import AppKit

@MainActor
final class MenuBarStatusContentView: NSView {
    private static let sidePadding: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let chipWidth: CGFloat = 58
    private static let height: CGFloat = 22

    private let segments: [MenuBarStatusSegment]

    init(segments: [MenuBarStatusSegment]) {
        self.segments = segments
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        installChips()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.preferredWidth(for: segments), height: Self.height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    static func preferredWidth(for segments: [MenuBarStatusSegment]) -> CGFloat {
        guard !segments.isEmpty else {
            return 26
        }

        let chipTotal = CGFloat(segments.count) * chipWidth
        let gapTotal = CGFloat(max(segments.count - 1, 0)) * gap
        return sidePadding + chipTotal + gapTotal + sidePadding
    }

    private func installChips() {
        var previous: NSView?

        for segment in segments {
            let chip = MenuBarMetricChipView(segment: segment)
            addSubview(chip)

            var constraints = [
                chip.centerYAnchor.constraint(equalTo: centerYAnchor),
                chip.widthAnchor.constraint(equalToConstant: Self.chipWidth),
                chip.heightAnchor.constraint(equalToConstant: 18)
            ]

            if let previous {
                constraints.append(chip.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: Self.gap))
            } else {
                constraints.append(chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sidePadding))
            }

            NSLayoutConstraint.activate(constraints)
            previous = chip
        }

        if let previous {
            previous.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Self.sidePadding).isActive = true
        }
    }
}

@MainActor
private final class MenuBarMetricChipView: NSView {
    private static let barWidth: CGFloat = 46

    private let segment: MenuBarStatusSegment
    private let symbolView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let barTrack = NSView()
    private let barFill = NSView()
    private var fillWidthConstraint: NSLayoutConstraint?

    init(segment: MenuBarStatusSegment) {
        self.segment = segment
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 0.5

        configureSymbol()
        configureValue()
        configureBar()
        installSubviews()
        refreshColors()

        setAccessibilityLabel("\(segment.title) \(segment.value)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    private func configureSymbol() {
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
        let image = NSImage(
            systemSymbolName: segment.symbolName,
            accessibilityDescription: segment.title
        )?.withSymbolConfiguration(config)
        image?.isTemplate = true

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.image = image
        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.contentTintColor = statusColor
    }

    private func configureValue() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func configureBar() {
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.wantsLayer = true
        barTrack.layer?.cornerRadius = 1

        barFill.translatesAutoresizingMaskIntoConstraints = false
        barFill.wantsLayer = true
        barFill.layer?.cornerRadius = 1
    }

    private func installSubviews() {
        addSubview(symbolView)
        addSubview(valueLabel)
        addSubview(barTrack)
        barTrack.addSubview(barFill)

        let fillWidthConstraint = barFill.widthAnchor.constraint(equalToConstant: Self.barWidth * segment.usageRatio)
        self.fillWidthConstraint = fillWidthConstraint

        NSLayoutConstraint.activate([
            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            symbolView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            symbolView.widthAnchor.constraint(equalToConstant: 11),
            symbolView.heightAnchor.constraint(equalToConstant: 11),

            valueLabel.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 3),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            valueLabel.centerYAnchor.constraint(equalTo: symbolView.centerYAnchor),

            barTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            barTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            barTrack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            barTrack.heightAnchor.constraint(equalToConstant: 2),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            fillWidthConstraint
        ])
    }

    private func refreshColors() {
        let color = statusColor
        symbolView.contentTintColor = color
        valueLabel.textColor = segment.state == .unavailable ? .secondaryLabelColor : .labelColor
        layer?.backgroundColor = color.withAlphaComponent(backgroundAlpha).cgColor
        layer?.borderColor = color.withAlphaComponent(borderAlpha).cgColor
        barTrack.layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
        barFill.layer?.backgroundColor = color.withAlphaComponent(segment.state == .unavailable ? 0 : 0.9).cgColor
        fillWidthConstraint?.constant = Self.barWidth * segment.usageRatio
    }

    private var statusColor: NSColor {
        switch segment.state {
        case .normal:
            return .systemGreen
        case .active, .refreshing:
            return .controlAccentColor
        case .warning:
            return .systemOrange
        case .unavailable:
            return .tertiaryLabelColor
        }
    }

    private var backgroundAlpha: CGFloat {
        segment.state == .unavailable ? 0.09 : 0.14
    }

    private var borderAlpha: CGFloat {
        segment.state == .unavailable ? 0.18 : 0.32
    }
}
