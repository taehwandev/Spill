import AppKit

extension MenuBarMetricChipView {
    func configureValue() {
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.stringValue = segment.isBadge ? badgeText(for: segment.value) : segment.value
        if segment.isBadge {
            valueLabel.font = MenuBarStatusContentView.badgeTextFont(
                textFontSize: textFontSize,
                textIsBold: textIsBold
            )
        } else if segment.isValueOnly {
            valueLabel.font = MenuBarStatusContentView.compactIconValueFont(
                textFontSize: textFontSize,
                textIsBold: textIsBold
            )
        } else {
            valueLabel.font = MenuBarStatusContentView.textFont(
                textFontSize: textFontSize,
                textIsBold: textIsBold
            )
        }
        valueLabel.alignment = segment.isValueOnly || segment.isBadge ? .center : .right
        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    }
}

extension MenuBarMetricChipView {
    func installSubviews() {
        if segment.isValueOnly, !segment.value.isEmpty {
            addSubview(iconView)
            addSubview(valueLabel)

            NSLayoutConstraint.activate([
                iconView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.widthAnchor.constraint(equalToConstant: iconSize),
                iconView.heightAnchor.constraint(equalToConstant: iconSize),

                valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: -1),
                valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
                valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
                valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1)
            ])
            return
        }

        addSubview(iconView)

        if segment.isBadge, !segment.value.isEmpty {
            addSubview(valueLabel)

            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
                iconView.widthAnchor.constraint(equalToConstant: iconSize),
                iconView.heightAnchor.constraint(equalToConstant: iconSize),

                valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: -1),
                valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
                valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 0)
            ])
            return
        }

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
}

extension MenuBarMetricChipView {
    func refreshColors() {
        let color = statusColor
        valueLabel.textColor = segment.state == .unavailable ? .secondaryLabelColor : .labelColor
        if hasCustomTriggerIcon {
            configureIcon()
            iconView.contentTintColor = nil
        } else {
            iconView.contentTintColor = color.withAlphaComponent(segment.state == .unavailable ? 0.5 : 1.0)
        }
    }

    var statusColor: NSColor {
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

    var resolvedSymbolName: String {
        segment.symbolName
    }

    var iconSize: CGFloat {
        if segment.isValueOnly {
            return 8.5
        }
        return segment.kind == .trigger ? 18 : 13
    }

    var symbolPointSize: CGFloat {
        if segment.isValueOnly {
            return 8
        }
        return segment.kind == .trigger ? 15.5 : 10.5
    }

    var hasCustomTriggerIcon: Bool {
        switch segment.visualStyle {
        case .symbol, .valueOnly, .symbolBadge:
            return false
        case let .trigger(style):
            return style.usesCustomRenderer
        }
    }

    func badgeText(for value: String) -> String {
        MenuBarStatusContentView.compactBadgeText(for: value)
    }

    var accessibilityText: String {
        guard !segment.value.isEmpty else {
            return segment.title
        }

        return "\(segment.title) \(segment.value)"
    }
}
