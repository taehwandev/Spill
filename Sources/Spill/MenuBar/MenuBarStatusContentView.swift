import AppKit

@MainActor
final class MenuBarStatusContentView: NSView {
    private static let sidePadding: CGFloat = 0
    private static let gap: CGFloat = 2
    private static let height: CGFloat = 22
    private static let metricChipHeight: CGFloat = 17
    private static let triggerChipHeight: CGFloat = 20
    private static let iconOnlyChipWidth: CGFloat = 20
    private static let triggerChipWidth: CGFloat = 24
    private static let mainWithCaffeineChipWidth: CGFloat = 42
    private static let compactStackChipMinWidth: CGFloat = 32
    private static let compactStackHorizontalPadding: CGFloat = 12
    fileprivate static let compactStackIconSize: CGFloat = 7
    private static let verticalChipMinWidth: CGFloat = 31
    private static let verticalHorizontalPadding: CGFloat = 7
    private static let compactIconValueMinWidth: CGFloat = 22
    private static let compactIconValueHorizontalPadding: CGFloat = 5
    static let defaultTextFontSize: CGFloat = 13.5
    static let minimumTextFontSize: CGFloat = 10
    static let maximumTextFontSize: CGFloat = 15

    private let segments: [MenuBarStatusSegment]
    private let layoutStyle: MenuBarStatusLayoutStyle
    private let textFontSize: CGFloat
    private let textIsBold: Bool
    private let groupsMainCaffeine: Bool

    private enum ChipDescriptor {
        case main(trigger: MenuBarStatusSegment, caffeine: MenuBarStatusSegment?)
        case single(MenuBarStatusSegment)
        case compactStack([MenuBarStatusSegment])
        case vertical(MenuBarStatusSegment)
    }

    init(
        segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle = .inline,
        textFontSize: CGFloat = MenuBarStatusContentView.defaultTextFontSize,
        textIsBold: Bool = false,
        groupsMainCaffeine: Bool = false
    ) {
        self.segments = segments
        self.layoutStyle = layoutStyle
        self.textFontSize = Self.normalizedTextFontSize(textFontSize)
        self.textIsBold = textIsBold
        self.groupsMainCaffeine = groupsMainCaffeine
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
        NSSize(
            width: Self.preferredWidth(
                for: segments,
                layoutStyle: layoutStyle,
                textFontSize: textFontSize,
                textIsBold: textIsBold,
                groupsMainCaffeine: groupsMainCaffeine
            ),
            height: Self.height
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    static func preferredWidth(
        for segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle = .inline,
        textFontSize: CGFloat = MenuBarStatusContentView.defaultTextFontSize,
        textIsBold: Bool = false,
        groupsMainCaffeine: Bool = false
    ) -> CGFloat {
        guard !segments.isEmpty else {
            return 26
        }

        let normalizedFontSize = Self.normalizedTextFontSize(textFontSize)
        let chips = chipDescriptors(
            for: segments,
            layoutStyle: layoutStyle,
            groupsMainCaffeine: groupsMainCaffeine
        )
        let chipTotal = chips.reduce(CGFloat.zero) { partial, descriptor in
            partial + chipWidth(
                for: descriptor,
                textFontSize: normalizedFontSize,
                textIsBold: textIsBold
            )
        }
        let gapTotal = CGFloat(max(chips.count - 1, 0)) * gap
        return sidePadding + chipTotal + gapTotal + sidePadding
    }

    static func segmentKind(
        at point: NSPoint,
        in segments: [MenuBarStatusSegment],
        layoutStyle: MenuBarStatusLayoutStyle = .inline,
        textFontSize: CGFloat = MenuBarStatusContentView.defaultTextFontSize,
        textIsBold: Bool = false,
        groupsMainCaffeine: Bool = false
    ) -> MenuBarStatusSegment.Kind? {
        let normalizedFontSize = Self.normalizedTextFontSize(textFontSize)
        var currentX = sidePadding

        for descriptor in chipDescriptors(
            for: segments,
            layoutStyle: layoutStyle,
            groupsMainCaffeine: groupsMainCaffeine
        ) {
            let width = chipWidth(
                for: descriptor,
                textFontSize: normalizedFontSize,
                textIsBold: textIsBold
            )
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
        layoutStyle: MenuBarStatusLayoutStyle,
        groupsMainCaffeine: Bool
    ) -> [ChipDescriptor] {
        var descriptors: [ChipDescriptor] = []
        var index = 0

        while index < segments.count {
            let segment = segments[index]
            if groupsMainCaffeine,
               segment.kind == .caffeine,
               index + 1 < segments.count,
               segments[index + 1].kind == .trigger {
                descriptors.append(.main(trigger: segments[index + 1], caffeine: segment))
                index += 2
                continue
            }

            if groupsMainCaffeine, segment.kind == .trigger {
                descriptors.append(.main(trigger: segment, caffeine: nil))
                index += 1
                continue
            }

            if layoutStyle == .stacked {
                descriptors.append(isVerticalStatus(segment) ? .vertical(segment) : .single(segment))
                index += 1
                continue
            }

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
        case .cpu, .memory, .ai:
            return true
        case .caffeine, .sleepGuard, .trigger:
            return false
        }
    }

    private static func isStackableCompactStatus(_ segment: MenuBarStatusSegment) -> Bool {
        guard segment.isValueOnly, !segment.value.isEmpty else {
            return false
        }

        switch segment.kind {
        case .cpu, .memory, .ai:
            return true
        case .caffeine, .sleepGuard, .trigger:
            return false
        }
    }

    private static func segmentKind(
        at point: NSPoint,
        in frame: NSRect,
        descriptor: ChipDescriptor
    ) -> MenuBarStatusSegment.Kind? {
        switch descriptor {
        case let .main(_, caffeine):
            if caffeine != nil, point.x >= frame.midX {
                return .caffeine
            }
            return .trigger
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

    static func normalizedTextFontSize(_ textFontSize: CGFloat) -> CGFloat {
        guard textFontSize.isFinite else {
            return defaultTextFontSize
        }

        return textFontSize.clamped(to: minimumTextFontSize...maximumTextFontSize)
    }

    static func textFont(textFontSize: CGFloat, textIsBold: Bool) -> NSFont {
        NSFont.monospacedDigitSystemFont(
            ofSize: normalizedTextFontSize(textFontSize),
            weight: textIsBold ? .semibold : .light
        )
    }

    fileprivate static func compactStackTextFont(textFontSize: CGFloat, textIsBold: Bool) -> NSFont {
        let size = (normalizedTextFontSize(textFontSize) * 0.61).clamped(to: 7.6...9.4)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: textIsBold ? .semibold : .medium)
    }

    static func compactIconValueFont(textFontSize: CGFloat, textIsBold: Bool) -> NSFont {
        let size = (normalizedTextFontSize(textFontSize) * 0.65).clamped(to: 8.0...9.6)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: textIsBold ? .semibold : .medium)
    }

    static func badgeTextFont(textFontSize: CGFloat, textIsBold: Bool) -> NSFont {
        let size = (normalizedTextFontSize(textFontSize) * 0.58).clamped(to: 7.2...8.8)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: textIsBold ? .bold : .semibold)
    }

    fileprivate static func verticalTitleFont(textFontSize: CGFloat) -> NSFont {
        let size = (normalizedTextFontSize(textFontSize) * 0.56).clamped(to: 7.2...8.8)
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    fileprivate static func verticalValueFont(textFontSize: CGFloat, textIsBold: Bool) -> NSFont {
        let size = (normalizedTextFontSize(textFontSize) * 0.80).clamped(to: 9.8...12.2)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: textIsBold ? .semibold : .medium)
    }

    private static func chipWidth(
        for descriptor: ChipDescriptor,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> CGFloat {
        switch descriptor {
        case let .single(segment):
            return chipWidth(for: segment, textFontSize: textFontSize, textIsBold: textIsBold)
        case let .main(_, caffeine):
            return caffeine == nil ? triggerChipWidth : mainWithCaffeineChipWidth
        case let .compactStack(segments):
            return compactStackChipWidth(for: segments, textFontSize: textFontSize, textIsBold: textIsBold)
        case let .vertical(segment):
            return verticalChipWidth(for: segment, textFontSize: textFontSize, textIsBold: textIsBold)
        }
    }

    private static func chipHeight(for descriptor: ChipDescriptor) -> CGFloat {
        switch descriptor {
        case .main:
            return triggerChipHeight
        case let .single(segment):
            return chipHeight(for: segment)
        case .compactStack, .vertical:
            return height
        }
    }

    private static func compactStackChipWidth(
        for segments: [MenuBarStatusSegment],
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> CGFloat {
        let font = compactStackTextFont(textFontSize: textFontSize, textIsBold: textIsBold)
        let maxTextWidth = segments.reduce(CGFloat.zero) { partial, segment in
            let textWidth = (segment.value as NSString).size(withAttributes: [.font: font]).width
            return max(partial, ceil(textWidth))
        }

        return max(compactStackChipMinWidth, maxTextWidth + compactStackHorizontalPadding)
    }

    private static func verticalChipWidth(
        for segment: MenuBarStatusSegment,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> CGFloat {
        let titleWidth = (verticalTitle(for: segment) as NSString).size(
            withAttributes: [.font: verticalTitleFont(textFontSize: textFontSize)]
        ).width
        let valueWidth = (segment.value as NSString).size(
            withAttributes: [.font: verticalValueFont(textFontSize: textFontSize, textIsBold: textIsBold)]
        ).width
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

    static func compactBadgeText(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        if trimmed == "∞" {
            return trimmed
        }

        if let hoursRange = trimmed.range(of: #"^\d+h"#, options: .regularExpression) {
            return String(trimmed[hoursRange])
        }

        if let minutesRange = trimmed.range(of: #"^\d+"#, options: .regularExpression) {
            return String(trimmed[minutesRange])
        }

        return String(trimmed.prefix(2))
    }

    fileprivate static func mainCaffeineBadgeText(for caffeine: MenuBarStatusSegment?) -> String {
        guard let caffeine else {
            return ""
        }

        let text = compactBadgeText(for: caffeine.value)
        if !text.isEmpty {
            return text
        }

        switch caffeine.state {
        case .active, .refreshing:
            return "•"
        case .normal, .warning, .unavailable:
            return ""
        }
    }

    private static func chipWidth(
        for segment: MenuBarStatusSegment,
        textFontSize: CGFloat,
        textIsBold: Bool
    ) -> CGFloat {
        if segment.kind == .trigger {
            return triggerChipWidth
        }

        guard !segment.value.isEmpty else {
            return iconOnlyChipWidth
        }
        if segment.isBadge {
            return iconOnlyChipWidth
        }

        if segment.isValueOnly {
            let textWidth = (segment.value as NSString).size(
                withAttributes: [.font: compactIconValueFont(textFontSize: textFontSize, textIsBold: textIsBold)]
            ).width
            return max(compactIconValueMinWidth, ceil(textWidth) + compactIconValueHorizontalPadding)
        }

        let textWidth = (segment.value as NSString).size(
            withAttributes: [.font: textFont(textFontSize: textFontSize, textIsBold: textIsBold)]
        ).width
        return ceil(textWidth) + 29
    }

    private static func chipHeight(for segment: MenuBarStatusSegment) -> CGFloat {
        if segment.isValueOnly || segment.isBadge {
            return height
        }
        return segment.kind == .trigger ? triggerChipHeight : metricChipHeight
    }

    private func installChips() {
        var previous: NSView?

        for descriptor in Self.chipDescriptors(
            for: segments,
            layoutStyle: layoutStyle,
            groupsMainCaffeine: groupsMainCaffeine
        ) {
            let chip: NSView
            switch descriptor {
            case let .main(trigger, caffeine):
                chip = MenuBarMainTriggerChipView(trigger: trigger, caffeine: caffeine)
            case let .single(segment):
                chip = MenuBarMetricChipView(
                    segment: segment,
                    textFontSize: textFontSize,
                    textIsBold: textIsBold
                )
            case let .compactStack(segments):
                chip = MenuBarCompactStackMetricChipView(
                    segments: segments,
                    textFontSize: textFontSize,
                    textIsBold: textIsBold
                )
            case let .vertical(segment):
                chip = MenuBarVerticalMetricChipView(
                    segment: segment,
                    textFontSize: textFontSize,
                    textIsBold: textIsBold
                )
            }

            addSubview(chip)

            var constraints = [
                chip.centerYAnchor.constraint(equalTo: centerYAnchor),
                chip.widthAnchor.constraint(equalToConstant: Self.chipWidth(
                    for: descriptor,
                    textFontSize: textFontSize,
                    textIsBold: textIsBold
                )),
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
private final class MenuBarMainTriggerChipView: NSView {
    private let trigger: MenuBarStatusSegment
    private let caffeine: MenuBarStatusSegment?
    private let triggerIconView = NSImageView()
    private let caffeineIconView = NSImageView()
    private let badgeLabel = NSTextField(labelWithString: "")

    init(trigger: MenuBarStatusSegment, caffeine: MenuBarStatusSegment?) {
        self.trigger = trigger
        self.caffeine = caffeine
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        configureIcon()
        configureBadge()
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
        triggerIconView.translatesAutoresizingMaskIntoConstraints = false
        triggerIconView.imageScaling = .scaleProportionallyDown
        triggerIconView.image = MenuBarSymbolImageCache.image(
            named: trigger.symbolName,
            accessibilityDescription: trigger.title,
            pointSize: 15.5
        )
        triggerIconView.symbolConfiguration = nil

        guard let caffeine else {
            return
        }

        caffeineIconView.translatesAutoresizingMaskIntoConstraints = false
        caffeineIconView.imageScaling = .scaleProportionallyDown
        caffeineIconView.image = MenuBarSymbolImageCache.image(
            named: caffeine.symbolName,
            accessibilityDescription: caffeine.title,
            pointSize: 13.5
        )
        caffeineIconView.symbolConfiguration = nil
    }

    private func configureBadge() {
        let badgeText = MenuBarStatusContentView.mainCaffeineBadgeText(for: caffeine)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.stringValue = badgeText
        badgeLabel.font = MenuBarStatusContentView.badgeTextFont(
            textFontSize: MenuBarStatusContentView.defaultTextFontSize,
            textIsBold: true
        )
        badgeLabel.alignment = .center
        badgeLabel.lineBreakMode = .byClipping
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func installSubviews() {
        addSubview(triggerIconView)

        if caffeine == nil {
            NSLayoutConstraint.activate([
                triggerIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                triggerIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                triggerIconView.widthAnchor.constraint(equalToConstant: 18),
                triggerIconView.heightAnchor.constraint(equalToConstant: 18)
            ])
            return
        }

        addSubview(caffeineIconView)
        NSLayoutConstraint.activate([
            triggerIconView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            triggerIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            triggerIconView.widthAnchor.constraint(equalToConstant: 18),
            triggerIconView.heightAnchor.constraint(equalToConstant: 18),

            caffeineIconView.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            caffeineIconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0.5),
            caffeineIconView.widthAnchor.constraint(equalToConstant: 16),
            caffeineIconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        guard !badgeLabel.stringValue.isEmpty else {
            return
        }

        addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: -1),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 1),
            badgeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: caffeineIconView.centerXAnchor, constant: -2)
        ])
    }

    private func refreshColors() {
        triggerIconView.contentTintColor = triggerColor
        caffeineIconView.contentTintColor = caffeineColor
        badgeLabel.textColor = caffeineColor
    }

    private var triggerColor: NSColor {
        switch trigger.state {
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

    private var caffeineColor: NSColor {
        switch caffeine?.state {
        case .active, .refreshing:
            return .systemTeal
        case .warning:
            return .systemOrange
        case .normal, .unavailable, .none:
            return .labelColor
        }
    }

    private var accessibilityText: String {
        guard let caffeine else {
            return trigger.title
        }

        guard !MenuBarStatusContentView.mainCaffeineBadgeText(for: caffeine).isEmpty else {
            return "\(trigger.title), \(caffeine.title) off"
        }

        if caffeine.value.isEmpty {
            return "\(trigger.title), \(caffeine.title) active"
        }

        return "\(trigger.title), \(caffeine.title) \(caffeine.value)"
    }
}

@MainActor
private final class MenuBarCompactStackMetricChipView: NSView {
    private let segments: [MenuBarStatusSegment]
    private let textFontSize: CGFloat
    private let textIsBold: Bool
    private var segmentLabels: [(segment: MenuBarStatusSegment, label: NSTextField)] = []

    init(segments: [MenuBarStatusSegment], textFontSize: CGFloat, textIsBold: Bool) {
        self.segments = segments
        self.textFontSize = textFontSize
        self.textIsBold = textIsBold
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
        let icons = segments.map(makeIcon(for:))
        segmentLabels = zip(segments, labels).map { (segment: $0.0, label: $0.1) }
        zip(icons, labels).forEach { icon, label in
            addSubview(icon)
            addSubview(label)
        }

        guard labels.count == 2 else {
            guard let icon = icons.first, let label = labels.first else { return }
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),
                icon.heightAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),

                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 1),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            return
        }

        NSLayoutConstraint.activate([
            icons[0].leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            icons[0].topAnchor.constraint(equalTo: topAnchor, constant: 2),
            icons[0].widthAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),
            icons[0].heightAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),

            labels[0].leadingAnchor.constraint(equalTo: icons[0].trailingAnchor, constant: 1),
            labels[0].trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            labels[0].centerYAnchor.constraint(equalTo: icons[0].centerYAnchor),

            icons[1].leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            icons[1].bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            icons[1].widthAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),
            icons[1].heightAnchor.constraint(equalToConstant: MenuBarStatusContentView.compactStackIconSize),

            labels[1].leadingAnchor.constraint(equalTo: icons[1].trailingAnchor, constant: 1),
            labels[1].trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            labels[1].centerYAnchor.constraint(equalTo: icons[1].centerYAnchor)
        ])
    }

    private func makeIcon(for segment: MenuBarStatusSegment) -> NSImageView {
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyDown
        icon.image = MenuBarSymbolImageCache.image(
            named: segment.symbolName,
            accessibilityDescription: segment.title,
            pointSize: 6.8
        )
        icon.symbolConfiguration = nil
        icon.contentTintColor = textColor(for: segment).withAlphaComponent(segment.state == .unavailable ? 0.5 : 0.95)
        return icon
    }

    private func makeLabel(for segment: MenuBarStatusSegment) -> NSTextField {
        let label = NSTextField(labelWithString: segment.value)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = MenuBarStatusContentView.compactStackTextFont(
            textFontSize: textFontSize,
            textIsBold: textIsBold
        )
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
    private let textFontSize: CGFloat
    private let textIsBold: Bool
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")

    init(segment: MenuBarStatusSegment, textFontSize: CGFloat, textIsBold: Bool) {
        self.segment = segment
        self.textFontSize = textFontSize
        self.textIsBold = textIsBold
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
        titleLabel.font = MenuBarStatusContentView.verticalTitleFont(textFontSize: textFontSize)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byClipping
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.value
        valueLabel.font = MenuBarStatusContentView.verticalValueFont(
            textFontSize: textFontSize,
            textIsBold: textIsBold
        )
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

extension MenuBarStatusSegment {
    var isValueOnly: Bool {
        if case .valueOnly = visualStyle {
            return true
        }

        return false
    }

    var isBadge: Bool {
        if case .symbolBadge = visualStyle {
            return true
        }

        return false
    }
}
