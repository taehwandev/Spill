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

    private static func chipWidth(for segment: MenuBarStatusSegment) -> CGFloat {
        let textWidth = (segment.displayText as NSString).size(withAttributes: [.font: textFont]).width
        return ceil(textWidth) + 17
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
    private let stateDot = NSView()
    private let valueLabel = NSTextField(labelWithString: "")

    init(segment: MenuBarStatusSegment) {
        self.segment = segment
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 4

        configureStateDot()
        configureValue()
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

    private func configureStateDot() {
        stateDot.translatesAutoresizingMaskIntoConstraints = false
        stateDot.wantsLayer = true
        stateDot.layer?.cornerRadius = 2
    }

    private func configureValue() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.displayText
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func installSubviews() {
        addSubview(stateDot)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            stateDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stateDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            stateDot.widthAnchor.constraint(equalToConstant: 4),
            stateDot.heightAnchor.constraint(equalToConstant: 4),

            valueLabel.leadingAnchor.constraint(equalTo: stateDot.trailingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func refreshColors() {
        let color = statusColor
        valueLabel.textColor = segment.state == .unavailable ? .secondaryLabelColor : .labelColor
        layer?.backgroundColor = color.withAlphaComponent(backgroundAlpha).cgColor
        stateDot.layer?.backgroundColor = color.withAlphaComponent(dotAlpha).cgColor
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
        segment.state == .unavailable ? 0.04 : 0.08
    }

    private var dotAlpha: CGFloat {
        segment.state == .unavailable ? 0.35 : 0.95
    }
}
