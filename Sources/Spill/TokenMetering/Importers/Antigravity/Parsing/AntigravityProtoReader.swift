struct ProtoReader {
    struct Field {
        let number: Int
        let value: Value
    }

    enum Value {
        case varint(UInt64)
        case bytes([UInt8])
        case fixed
    }

    private let bytes: [UInt8]
    private var index = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func nextField() -> Field? {
        guard let key = readVarint(), key > 0 else {
            return nil
        }
        let number = Int(key >> 3)
        let wireType = Int(key & 0x7)

        switch wireType {
        case 0:
            guard let value = readVarint() else {
                return nil
            }
            return Field(number: number, value: .varint(value))
        case 1:
            guard skip(byteCount: 8) else {
                return nil
            }
            return Field(number: number, value: .fixed)
        case 2:
            guard let length = readVarint(),
                  length <= UInt64(Int.max),
                  index + Int(length) <= bytes.count
            else {
                return nil
            }
            let start = index
            index += Int(length)
            return Field(number: number, value: .bytes(Array(bytes[start..<index])))
        case 5:
            guard skip(byteCount: 4) else {
                return nil
            }
            return Field(number: number, value: .fixed)
        default:
            return nil
        }
    }

    private mutating func readVarint() -> UInt64? {
        var shift: UInt64 = 0
        var value: UInt64 = 0
        var count = 0

        while index < bytes.count, count < 10 {
            let byte = bytes[index]
            index += 1
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
            count += 1
        }

        return nil
    }

    private mutating func skip(byteCount: Int) -> Bool {
        guard index + byteCount <= bytes.count else {
            return false
        }
        index += byteCount
        return true
    }
}
