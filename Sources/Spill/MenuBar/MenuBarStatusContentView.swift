import AppKit

@MainActor
final class MenuBarStatusContentView: NSView {
    private static let sidePadding: CGFloat = 2
    private static let gap: CGFloat = 4
    private static let height: CGFloat = 22
    private static let metricChipHeight: CGFloat = 17
    private static let triggerChipHeight: CGFloat = 20
    private static let iconOnlyChipWidth: CGFloat = 22
    private static let triggerChipWidth: CGFloat = 30
    private static let valueOnlyHorizontalPadding: CGFloat = 10
    private static let compactStackChipMinWidth: CGFloat = 30
    private static let compactStackHorizontalPadding: CGFloat = 8
    private static let verticalChipMinWidth: CGFloat = 33
    private static let verticalHorizontalPadding: CGFloat = 9
    private static let textFont = NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .light)
    fileprivate static let compactStackTextFont = NSFont.monospacedDigitSystemFont(ofSize: 8.2, weight: .medium)
    fileprivate static let verticalTitleFont = NSFont.systemFont(ofSize: 7.6, weight: .semibold)
    fileprivate static let verticalValueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.8, weight: .medium)

    private let segments: [MenuBarStatusSegment]
    private let layoutStyle: MenuBarStatusLayoutStyle

    private enum ChipDescriptor {
        case single(MenuBarStatusSegment)
        case compactStack([MenuBarStatusSegment])
        case vertical(MenuBarStatusSegment)
    }

    init(segments: [MenuBarStatusSegment], layoutStyle: MenuBarStatusLayoutStyle = .inline) {
        self.segments = segments
        self.layoutStyle = layoutStyle
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
        NSSize(width: Self.preferredWidth(for: segments, layoutStyle: layoutStyle), height: Self.height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    static func preferredWidth(
        for segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle = .inline
    ) -> CGFloat {
        guard !segments.isEmpty else {
            return 26
        }

        let chips = chipDescriptors(for: segments, layoutStyle: layoutStyle)
        let chipTotal = chips.reduce(CGFloat.zero) { partial, descriptor in
            partial + chipWidth(for: descriptor)
        }
        let gapTotal = CGFloat(max(chips.count - 1, 0)) * gap
        return sidePadding + chipTotal + gapTotal + sidePadding
    }

    static func segmentKind(
        at point: NSPoint,
        in segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle = .inline
    ) -> MenuBarStatusSegment.Kind? {
        var currentX = sidePadding

        for descriptor in chipDescriptors(for: segments, layoutStyle: layoutStyle) {
            let width = chipWidth(for: descriptor)
            let frame = NSRect(x: currentX, y: 0, width: width, height: height)
            if frame.contains(point) {
                return segmentKind(at: point, in: frame, descriptor: descriptor)
            }

            currentX += width + gap
        }

        return nil
    }

    private static func chipDescriptors(
        for segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle
    ) -> [ChipDescriptor] {
        if layoutStyle == .stacked {
            return segments.map { segment in
                isVerticalStatus(segment) ? .vertical(segment) : .single(segment)
            }
        }

        var descriptors: [ChipDescriptor] = []
        var index = 0

        while index < segments.count {
            let segment = segments[index]
            guard isStackableCompactStatus(segment) else {
                descriptors.append(.single(segment))
                index += 1
                continue
            }

            var stack = [segment]
            var nextIndex = index + 1
            while nextIndex < segments.count,
                  stack.count < 2,
                  isStackableCompactStatus(segments[nextIndex]) {
                stack.append(segments[nextIndex])
                nextIndex += 1
            }

            if stack.count > 1 {
                descriptors.append(.compactStack(stack))
                index = nextIndex
            } else {
                descriptors.append(.single(segment))
                index += 1
            }
        }

        return descriptors
    }

    private static func isVerticalStatus(_ segment: MenuBarStatusSegment) -> Bool {
        guard !segment.value.isEmpty else {
            return false
        }

        switch segment.kind {
        case .cpu, .memory:
            return true
        case .ai, .caffeine, .sleepGuard, .trigger:
            return false
        }
    }

    private static func isStackableCompactStatus(_ segment: MenuBarStatusSegment) -> Bool {
        guard segment.isValueOnly, !segment.value.isEmpty else {
            return false
        }

        switch segment.kind {
        case .cpu, .memory:
            return true
        case .ai, .caffeine, .sleepGuard, .trigger:
            return false
        }
    }

    private static func segmentKind(
        at point: NSPoint,
        in frame: NSRect,
        descriptor: ChipDescriptor
    ) -> MenuBarStatusSegment.Kind? {
        switch descriptor {
        case let .single(segment):
            return segment.kind
        case let .vertical(segment):
            return segment.kind
        case let .compactStack(segments):
            guard !segments.isEmpty else {
                return nil
            }

            let rowHeight = frame.height / CGFloat(segments.count)
            let rowFromBottom = min(max(Int((point.y - frame.minY) / rowHeight), 0), segments.count - 1)
            let index = segments.count - 1 - rowFromBottom
            return segments[index].kind
        }
    }

    private static func chipWidth(for descriptor: ChipDescriptor) -> CGFloat {
        switch descriptor {
        case let .single(segment):
            return chipWidth(for: segment)
        case let .compactStack(segments):
            return compactStackChipWidth(for: segments)
        case let .vertical(segment):
            return verticalChipWidth(for: segment)
        }
    }

    private static func chipHeight(for descriptor: ChipDescriptor) -> CGFloat {
        switch descriptor {
        case let .single(segment):
            return chipHeight(for: segment)
        case .compactStack, .vertical:
            return height
        }
    }

    private static func compactStackChipWidth(for segments: [MenuBarStatusSegment]) -> CGFloat {
        let maxTextWidth = segments.reduce(CGFloat.zero) { partial, segment in
            let textWidth = (segment.value as NSString).size(withAttributes: [.font: compactStackTextFont]).width
            return max(partial, ceil(textWidth))
        }

        return max(compactStackChipMinWidth, maxTextWidth + compactStackHorizontalPadding)
    }

    private static func verticalChipWidth(for segment: MenuBarStatusSegment) -> CGFloat {
        let titleWidth = (verticalTitle(for: segment) as NSString).size(
            withAttributes: [.font: verticalTitleFont]
        ).width
        let valueWidth = (segment.value as NSString).size(withAttributes: [.font: verticalValueFont]).width
        return max(verticalChipMinWidth, ceil(max(titleWidth, valueWidth)) + verticalHorizontalPadding)
    }

    fileprivate static func verticalTitle(for segment: MenuBarStatusSegment) -> String {
        switch segment.kind {
        case .memory:
            return "RAM"
        case .cpu:
            return "CPU"
        case .ai, .caffeine, .sleepGuard, .trigger:
            return segment.shortTitle
        }
    }

    private static func chipWidth(for segment: MenuBarStatusSegment) -> CGFloat {
        if segment.kind == .trigger {
            return triggerChipWidth
        }

        guard !segment.value.isEmpty else {
            return iconOnlyChipWidth
        }

        let textWidth = (segment.value as NSString).size(withAttributes: [.font: textFont]).width
        if segment.isValueOnly {
            return ceil(textWidth) + valueOnlyHorizontalPadding
        }

        return ceil(textWidth) + 29
    }

    private static func chipHeight(for segment: MenuBarStatusSegment) -> CGFloat {
        segment.kind == .trigger ? triggerChipHeight : metricChipHeight
    }

    private func installChips() {
        var previous: NSView?

        for descriptor in Self.chipDescriptors(for: segments, layoutStyle: layoutStyle) {
            let chip: NSView
            switch descriptor {
            case let .single(segment):
                chip = MenuBarMetricChipView(segment: segment)
            case let .compactStack(segments):
                chip = MenuBarCompactStackMetricChipView(segments: segments)
            case let .vertical(segment):
                chip = MenuBarVerticalMetricChipView(segment: segment)
            }

            addSubview(chip)

            var constraints = [
                chip.centerYAnchor.constraint(equalTo: centerYAnchor),
                chip.widthAnchor.constraint(equalToConstant: Self.chipWidth(for: descriptor)),
                chip.heightAnchor.constraint(equalToConstant: Self.chipHeight(for: descriptor))
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
private final class MenuBarCompactStackMetricChipView: NSView {
    private let segments: [MenuBarStatusSegment]
    private var segmentLabels: [(segment: MenuBarStatusSegment, label: NSTextField)] = []

    init(segments: [MenuBarStatusSegment]) {
        self.segments = segments
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        installLabels()
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

    private func installLabels() {
        let labels = segments.map(makeLabel(for:))
        segmentLabels = zip(segments, labels).map { (segment: $0.0, label: $0.1) }
        labels.forEach(addSubview)

        guard labels.count == 2 else {
            labels.first.map { label in
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
                    label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
                    label.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            }
            return
        }

        NSLayoutConstraint.activate([
            labels[0].topAnchor.constraint(equalTo: topAnchor, constant: 1),
            labels[0].leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            labels[0].trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),

            labels[1].bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            labels[1].leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            labels[1].trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3)
        ])
    }

    private func makeLabel(for segment: MenuBarStatusSegment) -> NSTextField {
        let label = NSTextField(labelWithString: segment.value)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = MenuBarStatusContentView.compactStackTextFont
        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.textColor = textColor(for: segment)
        return label
    }

    private func refreshColors() {
        segmentLabels.forEach { pair in
            pair.label.textColor = textColor(for: pair.segment)
        }
    }

    private func textColor(for segment: MenuBarStatusSegment) -> NSColor {
        switch segment.state {
        case .normal:
            return .labelColor
        case .active, .refreshing:
            return .systemTeal
        case .warning:
            return .systemOrange
        case .unavailable:
            return .secondaryLabelColor
        }
    }

    private var accessibilityText: String {
        segments
            .map { segment in
                guard !segment.value.isEmpty else {
                    return segment.title
                }

                return "\(segment.title) \(segment.value)"
            }
            .joined(separator: ", ")
    }
}

@MainActor
private final class MenuBarVerticalMetricChipView: NSView {
    private let segment: MenuBarStatusSegment
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")

    init(segment: MenuBarStatusSegment) {
        self.segment = segment
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        configureLabels()
        installLabels()
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

    private func configureLabels() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = MenuBarStatusContentView.verticalTitle(for: segment)
        titleLabel.font = MenuBarStatusContentView.verticalTitleFont
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byClipping
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.value
        valueLabel.font = MenuBarStatusContentView.verticalValueFont
        valueLabel.alignment = .center
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        refreshColors()
    }

    private func installLabels() {
        addSubview(titleLabel)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            titleLabel.heightAnchor.constraint(equalToConstant: 8),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -1),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3)
        ])
    }

    private func refreshColors() {
        titleLabel.textColor = .labelColor
        valueLabel.textColor = valueColor
    }

    private var valueColor: NSColor {
        switch segment.state {
        case .normal:
            return .labelColor
        case .active, .refreshing:
            return .systemTeal
        case .warning:
            return .systemOrange
        case .unavailable:
            return .secondaryLabelColor
        }
    }

    private var accessibilityText: String {
        "\(segment.title) \(segment.value)"
    }
}

@MainActor
private final class MenuBarMetricChipView: NSView {
    private let segment: MenuBarStatusSegment
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0

    init(segment: MenuBarStatusSegment) {
        self.segment = segment
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
        configureIcon()
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

        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: resolvedSymbolName, accessibilityDescription: segment.title)?
            .withSymbolConfiguration(config)
        iconView.symbolConfiguration = config
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

    private func configureValue() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13.5, weight: .light)
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func installSubviews() {
        if segment.isValueOnly, !segment.value.isEmpty {
            addSubview(valueLabel)

            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
                valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
                valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            return
        }

        addSubview(iconView)

        if segment.value.isEmpty {
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: iconSize),
                iconView.heightAnchor.constraint(equalToConstant: iconSize)
            ])
            return
        }

        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5.5),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),

            valueLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3.5),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5.5),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func refreshColors() {
        let color = statusColor
        valueLabel.textColor = segment.state == .unavailable ? .secondaryLabelColor : .labelColor
        if hasCustomTriggerIcon {
            iconView.contentTintColor = nil
        } else {
            iconView.contentTintColor = color.withAlphaComponent(segment.state == .unavailable ? 0.5 : 1.0)
        }
    }

    private var statusColor: NSColor {
        switch segment.state {
        case .normal:
            return .labelColor
        case .active, .refreshing:
            return .systemTeal
        case .warning:
            return .systemOrange
        case .unavailable:
            return .tertiaryLabelColor
        }
    }

    private var resolvedSymbolName: String {
        segment.symbolName
    }

    private var iconSize: CGFloat {
        segment.kind == .trigger ? 18 : 13
    }

    private var symbolPointSize: CGFloat {
        segment.kind == .trigger ? 15.5 : 10.5
    }

    private var hasCustomTriggerIcon: Bool {
        switch segment.visualStyle {
        case .symbol, .valueOnly:
            return false
        case .trigger:
            return false
        }
    }

    private var accessibilityText: String {
        guard !segment.value.isEmpty else {
            return segment.title
        }

        return "\(segment.title) \(segment.value)"
    }

}

private extension MenuBarStatusSegment {
    var isValueOnly: Bool {
        if case .valueOnly = visualStyle {
            return true
        }

        return false
    }
}
