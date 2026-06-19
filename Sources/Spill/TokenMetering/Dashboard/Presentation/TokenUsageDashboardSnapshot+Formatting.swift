import Foundation

extension TokenUsageDashboardSnapshot {
    static func formatTokens(_ value: Int) -> String {
        let absoluteValue = Swift.abs(Double(value))
        let units: [(threshold: Double, divisor: Double, suffix: String)] = [
            (1_000_000_000_000, 1_000_000_000_000, "T"),
            (1_000_000_000, 1_000_000_000, "B"),
            (1_000_000, 1_000_000, "M"),
            (10_000, 1_000, "K")
        ]

        guard let unit = units.first(where: { absoluteValue >= $0.threshold }) else {
            return NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let scaledValue = Double(value) / unit.divisor
        let formattedValue = NumberFormatter.tokenUsageCompact.string(from: NSNumber(value: scaledValue))
            ?? String(format: "%.2f", scaledValue)
        return "\(formattedValue)\(unit.suffix)"
    }

    static func formatCount(_ value: Int) -> String {
        NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formatPercentage(_ value: Double) -> String {
        if value > 0, value < 0.1 {
            return "<0.1%"
        }

        let number = NumberFormatter.tokenUsagePercentage.string(from: NSNumber(value: value))
            ?? String(format: "%.1f", value)
        return "\(number)%"
    }

    static func cachedFixedDateFormatter(
        dateFormat: String,
        locale: Locale,
        timeZone: TimeZone
    ) -> DateFormatter {
        let key = "Spill.FixedFormatter.\(dateFormat).\(locale.identifier).\(timeZone.identifier)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = locale
        formatter.timeZone = timeZone
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static func cachedLocalizedDateFormatter(
        template: String,
        locale: Locale,
        timeZone: TimeZone
    ) -> DateFormatter {
        let key = "Spill.LocalizedFormatter.\(template).\(locale.identifier).\(timeZone.identifier)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static func formatLocalTimestamp(
        _ date: Date,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.setLocalizedDateFormatFromTemplate("jm")
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.setLocalizedDateFormatFromTemplate("MMM d jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("y MMM d jm")
        }

        return formatter.string(from: date)
    }

    static func formatCalendarDayID(
        _ dayID: String,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String? {
        date(forDayID: dayID, calendar: calendar).map {
            formatCalendarDayTitle($0, locale: locale, timeZone: timeZone)
        }
    }

    static func formatCalendarDayTitle(
        _ date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    static func formatCalendarMonth(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    static func weekdayTitles(locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
    }

    static func projectTitle(_ projectID: String, language: TokenMeteringLanguage = .current()) -> String {
        guard projectID != "project_global" else {
            return TokenMeteringL10n.text(.folderUnassigned, language: language)
        }

        let rawID = projectID.hasPrefix("project_")
            ? String(projectID.dropFirst("project_".count))
            : projectID
        let shortID = String(rawID.prefix(8))
        guard !shortID.isEmpty else {
            return TokenMeteringL10n.text(.folderUnassigned, language: language)
        }
        return TokenMeteringL10n.folderTitle(shortID, language: language)
    }

    static func workItemTitle(
        key: TokenUsageDashboardWorkItemKey,
        language: TokenMeteringLanguage
    ) -> String {
        [
            key.taskType.dashboardLabel(language: language),
            key.stage.dashboardLabel(language: language)
        ].joined(separator: " - ")
    }

    static func modelKey(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if trimmed.isEmpty || lowered == "unknown" || lowered == "unknown_model" || lowered == "model_unknown" || lowered == "unavailable" {
            return "model_unavailable"
        }
        return trimmed
    }

    static func modelLabel(_ key: String, language: TokenMeteringLanguage) -> String {
        key == "model_unavailable"
            ? TokenMeteringL10n.text(.modelUnavailable, language: language)
            : key
    }

    static func percentageDetail(value: Int, total: Int, language: TokenMeteringLanguage) -> String {
        let percent = total > 0 ? (Double(value) / Double(total) * 100.0) : 0.0
        return TokenMeteringL10n.percentStringOfTotal(Self.formatPercentage(percent), language: language)
    }
}
