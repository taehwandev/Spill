import CryptoKit
import Foundation

extension PrivateUsageDailyBucketBuilder {
    func localDayID(for date: Date) -> String {
        Self.localDayID(for: date, timeZone: timeZone)
    }

    func localDayInterval(for dayID: String) -> DateInterval? {
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: dayID),
              let end = gregorianCalendar.date(byAdding: .day, value: 1, to: start)
        else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    // Full resyncs call these once per stored event, so formatters come from the per-thread cache.
    static func localDayID(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        TokenUsageDashboardSnapshot.cachedFixedDateFormatter(
            dateFormat: "yyyy-MM-dd",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        ).string(from: date)
    }

    static func localTimestamp(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        TokenUsageDashboardSnapshot.cachedFixedDateFormatter(
            dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        ).string(from: date)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
