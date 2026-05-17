import Foundation

enum MenuBarStatusDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case labelAndPercent
    case percentOnly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .labelAndPercent:
            return "Label + %"
        case .percentOnly:
            return "% Only"
        }
    }

    func text(label: String, value: String) -> String {
        switch self {
        case .labelAndPercent:
            return "\(label) \(value)"
        case .percentOnly:
            return value
        }
    }
}

enum MenuBarStatusPrecision: Int, CaseIterable, Identifiable, Sendable {
    case whole = 0
    case tenths = 1

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .whole:
            return "0"
        case .tenths:
            return "0.0"
        }
    }

    func percentText(for ratio: Double) -> String {
        let clampedRatio = ratio.clamped(to: 0...1)
        guard clampedRatio > 0 else {
            switch self {
            case .whole:
                return "0%"
            case .tenths:
                return "0.0%"
            }
        }

        let percent = clampedRatio * 100

        switch self {
        case .whole:
            if percent < 1 {
                return "<1%"
            }
            return "\(Int(percent.rounded()))%"
        case .tenths:
            if percent < 0.1 {
                return "<0.1%"
            }
            return String(format: "%.1f%%", percent)
        }
    }
}

enum MenuBarStatusHighlightThreshold: Int, CaseIterable, Identifiable, Sendable {
    case seventy = 70
    case eighty = 80
    case ninety = 90

    var id: Int {
        rawValue
    }

    var title: String {
        "\(rawValue)%"
    }

    var ratio: Double {
        Double(rawValue) / 100
    }
}
