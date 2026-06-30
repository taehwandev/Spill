import Foundation

extension ISO8601DateFormatter {
    static var tokenUsage: ISO8601DateFormatter {
        cachedTokenUsageFormatter(
            key: "app.spill.iso8601.tokenUsage.fractional",
            options: [.withInternetDateTime, .withFractionalSeconds]
        )
    }

    private static var tokenUsageWithoutFractionalSeconds: ISO8601DateFormatter {
        cachedTokenUsageFormatter(
            key: "app.spill.iso8601.tokenUsage.plain",
            options: [.withInternetDateTime]
        )
    }

    private static func cachedTokenUsageFormatter(
        key: String,
        options: ISO8601DateFormatter.Options
    ) -> ISO8601DateFormatter {
        if let formatter = Thread.current.threadDictionary[key] as? ISO8601DateFormatter {
            return formatter
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    static func parseTokenUsageDate(from string: String) -> Date? {
        fastTokenUsageDate(from: string)
            ?? tokenUsage.date(from: string)
            ?? tokenUsageWithoutFractionalSeconds.date(from: string)
    }

    private static func fastTokenUsageDate(from string: String) -> Date? {
        string.utf8.withContiguousStorageIfAvailable { bytes -> Date? in
            fastTokenUsageDate(from: bytes)
        } ?? fastTokenUsageDate(from: Array(string.utf8))
    }

    private static func fastTokenUsageDate(from bytes: [UInt8]) -> Date? {
        bytes.withUnsafeBufferPointer { buffer in
            fastTokenUsageDate(from: buffer)
        }
    }

    private static func fastTokenUsageDate(from bytes: UnsafeBufferPointer<UInt8>) -> Date? {
        guard bytes.count >= 20,
              bytes[4] == asciiDash,
              bytes[7] == asciiDash,
              bytes[10] == asciiT || bytes[10] == asciiLowercaseT,
              bytes[13] == asciiColon,
              bytes[16] == asciiColon
        else {
            return nil
        }

        guard let year = decimalValue(bytes, start: 0, count: 4),
              let month = decimalValue(bytes, start: 5, count: 2),
              let day = decimalValue(bytes, start: 8, count: 2),
              let hour = decimalValue(bytes, start: 11, count: 2),
              let minute = decimalValue(bytes, start: 14, count: 2),
              let second = decimalValue(bytes, start: 17, count: 2),
              (1...12).contains(month),
              (1...daysInMonth(year: year, month: month)).contains(day),
              (0...23).contains(hour),
              (0...59).contains(minute),
              (0...59).contains(second)
        else {
            return nil
        }

        var index = 19
        var fractionalSeconds = 0.0
        if index < bytes.count, bytes[index] == asciiPeriod {
            index += 1
            var value = 0
            var divisor = 1.0
            var parsedDigitCount = 0
            while index < bytes.count, let digit = decimalDigit(bytes[index]) {
                if parsedDigitCount < 9 {
                    value = (value * 10) + digit
                    divisor *= 10
                    parsedDigitCount += 1
                }
                index += 1
            }
            guard parsedDigitCount > 0 else {
                return nil
            }
            fractionalSeconds = Double(value) / divisor
        }

        let offsetSeconds: Int
        if index < bytes.count, bytes[index] == asciiZ || bytes[index] == asciiLowercaseZ {
            index += 1
            offsetSeconds = 0
        } else if index + 5 < bytes.count,
                  bytes[index] == asciiPlus || bytes[index] == asciiDash,
                  bytes[index + 3] == asciiColon,
                  let offsetHour = decimalValue(bytes, start: index + 1, count: 2),
                  let offsetMinute = decimalValue(bytes, start: index + 4, count: 2),
                  (0...23).contains(offsetHour),
                  (0...59).contains(offsetMinute) {
            let sign = bytes[index] == asciiPlus ? 1 : -1
            offsetSeconds = sign * ((offsetHour * 3_600) + (offsetMinute * 60))
            index += 6
        } else {
            return nil
        }

        guard index == bytes.count else {
            return nil
        }

        let days = daysSinceUnixEpoch(year: year, month: month, day: day)
        let wholeSeconds = (days * 86_400) + (hour * 3_600) + (minute * 60) + second - offsetSeconds
        return Date(timeIntervalSince1970: Double(wholeSeconds) + fractionalSeconds)
    }

    private static func decimalValue(
        _ bytes: UnsafeBufferPointer<UInt8>,
        start: Int,
        count: Int
    ) -> Int? {
        guard start >= 0, count > 0, start + count <= bytes.count else {
            return nil
        }

        var value = 0
        for index in start..<(start + count) {
            guard let digit = decimalDigit(bytes[index]) else {
                return nil
            }
            value = (value * 10) + digit
        }
        return value
    }

    private static func decimalDigit(_ byte: UInt8) -> Int? {
        guard byte >= asciiZero, byte <= asciiNine else {
            return nil
        }
        return Int(byte - asciiZero)
    }

    private static func daysSinceUnixEpoch(year: Int, month: Int, day: Int) -> Int {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - (era * 400)
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = ((153 * adjustedMonth) + 2) / 5 + day - 1
        let dayOfEra = (yearOfEra * 365) + (yearOfEra / 4) - (yearOfEra / 100) + dayOfYear
        return (era * 146_097) + dayOfEra - 719_468
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 4, 6, 9, 11:
            return 30
        case 2:
            return isLeapYear(year) ? 29 : 28
        default:
            return 0
        }
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        year.isMultiple(of: 400) || (year.isMultiple(of: 4) && !year.isMultiple(of: 100))
    }

    private static let asciiZero = UInt8(ascii: "0")
    private static let asciiNine = UInt8(ascii: "9")
    private static let asciiDash = UInt8(ascii: "-")
    private static let asciiColon = UInt8(ascii: ":")
    private static let asciiPeriod = UInt8(ascii: ".")
    private static let asciiPlus = UInt8(ascii: "+")
    private static let asciiT = UInt8(ascii: "T")
    private static let asciiLowercaseT = UInt8(ascii: "t")
    private static let asciiZ = UInt8(ascii: "Z")
    private static let asciiLowercaseZ = UInt8(ascii: "z")
}
