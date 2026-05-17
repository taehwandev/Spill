import AppKit

@MainActor
final class MenuBarStatusContentView: NSView {
    private static let sidePadding: CGFloat = 2
    private static let gap: CGFloat = 4
    private static let height: CGFloat = 22
    private static let textFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)

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

        let chipTotal = segments.reduce(CGFloat.zero) { partial, segment in
            partial + chipWidth(for: segment)
        }
        let gapTotal = CGFloat(max(segments.count - 1, 0)) * gap
        return sidePadding + chipTotal + gapTotal + sidePadding
    }

    static func segmentKind(at point: NSPoint, in segments: [MenuBarStatusSegment]) -> MenuBarStatusSegment.Kind? {
        var currentX = sidePadding

        for segment in segments {
            let width = chipWidth(for: segment)
            let frame = NSRect(x: currentX, y: 0, width: width, height: height)
            if frame.contains(point) {
                return segment.kind
            }

            currentX += width + gap
        }

        return nil
    }

    private static func chipWidth(for segment: MenuBarStatusSegment) -> CGFloat {
        guard !segment.value.isEmpty else {
            return 22
        }

        let textWidth = (segment.value as NSString).size(withAttributes: [.font: textFont]).width
        return ceil(textWidth) + 29
    }

    private func installChips() {
        var previous: NSView?

        for segment in segments {
            let chip = MenuBarMetricChipView(segment: segment)
            addSubview(chip)

            var constraints = [
                chip.centerYAnchor.constraint(equalTo: centerYAnchor),
                chip.widthAnchor.constraint(equalToConstant: Self.chipWidth(for: segment)),
                chip.heightAnchor.constraint(equalToConstant: 17)
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
    private let segment: MenuBarStatusSegment
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")

    init(segment: MenuBarStatusSegment) {
        self.segment = segment
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6

        configureIcon()
        configureValue()
        installSubviews()
        refreshColors()

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

    private func configureIcon() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
        iconView.image = NSImage(
            systemSymbolName: resolvedSymbolName,
            accessibilityDescription: segment.title
        )?.withSymbolConfiguration(config)
        iconView.symbolConfiguration = config
    }

    private func configureValue() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func installSubviews() {
        addSubview(iconView)

        if segment.value.isEmpty {
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 13),
                iconView.heightAnchor.constraint(equalToConstant: 13)
            ])
            return
        }

        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5.5),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13),

            valueLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3.5),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5.5),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func refreshColors() {
        let color = statusColor
        valueLabel.textColor = segment.state == .unavailable ? .secondaryLabelColor : .labelColor
        iconView.contentTintColor = color.withAlphaComponent(segment.state == .unavailable ? 0.5 : 1.0)
        layer?.backgroundColor = color.withAlphaComponent(backgroundAlpha).cgColor
    }

    private var statusColor: NSColor {
        switch segment.state {
        case .normal:
            if segment.kind == .trigger {
                return .systemTeal
            }
            return .systemMint
        case .active, .refreshing:
            return .systemBlue
        case .warning:
            return .systemOrange
        case .unavailable:
            return .tertiaryLabelColor
        }
    }

    private var backgroundAlpha: CGFloat {
        segment.state == .unavailable ? 0.04 : 0.1
    }

    private var resolvedSymbolName: String {
        segment.symbolName
    }

    private var accessibilityText: String {
        guard !segment.value.isEmpty else {
            return segment.title
        }

        return "\(segment.title) \(segment.value)"
    }

}
