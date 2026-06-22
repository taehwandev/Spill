import Foundation

extension TokenUsageAntigravityImporter {
    static func firstLengthDelimitedField(_ number: Int, in bytes: [UInt8]) -> [UInt8]? {
        var reader = ProtoReader(bytes)
        while let field = reader.nextField() {
            if field.number == number, case .bytes(let value) = field.value {
                return value
            }
        }
        return nil
    }

    static func firstUTF8Field(_ number: Int, in bytes: [UInt8]) -> String? {
        guard let value = firstLengthDelimitedField(number, in: bytes),
              let string = String(bytes: value, encoding: .utf8)
        else {
            return nil
        }
        return string.range(of: #"^[A-Za-z0-9_.:-]{2,80}$"#, options: .regularExpression) != nil ? string : nil
    }

    static func firstVarintField(_ number: Int, in bytes: [UInt8]) -> UInt64? {
        var reader = ProtoReader(bytes)
        while let field = reader.nextField() {
            if field.number == number, case .varint(let value) = field.value {
                return value
            }
        }
        return nil
    }

    static func varintFieldTotals(in bytes: [UInt8]) -> [Int: UInt64] {
        var reader = ProtoReader(bytes)
        var fields = [Int: UInt64]()
        while let field = reader.nextField() {
            if case .varint(let value) = field.value {
                let current = fields[field.number] ?? 0
                let sum = current.addingReportingOverflow(value)
                fields[field.number] = sum.overflow ? UInt64.max : sum.partialValue
            }
        }
        return fields
    }

    static func safeToken(_ value: UInt64?) -> Int {
        guard let value else {
            return 0
        }
        return value > UInt64(Int.max) ? Int.max : Int(value)
    }

    static func safeAdd(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }
}
