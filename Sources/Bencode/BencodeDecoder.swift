import Foundation

public enum BencodeValue: CustomStringConvertible, Equatable, Sendable {
    case int(Int)
    case string([UInt8])
    case list([BencodeValue])
    case dict([[UInt8]: BencodeValue])

    public static func ~= (pattern: Int, value: BencodeValue) -> Bool {
        return switch value {
        case .int(let n): pattern == n
        default: false
        }
    }

    public static func ~= (pattern: String, value: BencodeValue) -> Bool {
        switch value {
        case .string(let bytes):
            if case .some(let s) = String(bytes: bytes, encoding: .utf8) {
                pattern == s
            } else {
                false
            }
        default: false
        }
    }

    public var description: String {
        switch self {
        case .int(let n): String(n)
        case .string(let bytes): String(bytes: bytes, encoding: .utf8) ?? "<invalid UTF-8>"
        case .list(let values): "[ " + values.map { $0.description }.joined(separator: ", ") + " ]"
        case .dict(let values):
            "{ "
                + values.map { key, value in
                    (String(bytes: key, encoding: .utf8) ?? "<invalid UTF-8>") + " : "
                        + value.description
                }.joined(separator: ", ") + " }"
        }
    }
}

public enum BencodeDecodeError: Error, Equatable {
    case unexpectedValue(value: UInt8, pos: UInt)
    case badIntValue(value: UInt8, pos: UInt)
    case badStringValue(value: UInt8, pos: UInt)
    case badListValue(value: UInt8, pos: UInt)
    case badDictKey(pos: UInt)
    case badDictValue(pos: UInt)
}

extension UInt8 {
    var isAsciiDigit: Bool {
        self >= 48 && self <= 57
    }
}

public final class BencodeDecoder {
    private var start: UInt
    private var current: UInt
    private let source: Data

    private static let intBegin: UInt8 = UInt8(ascii: "i")
    private static let intEnd: UInt8 = UInt8(ascii: "e")
    private static let separator: UInt8 = UInt8(ascii: ":")
    private static let listBegin: UInt8 = UInt8(ascii: "l")
    private static let listEnd: UInt8 = intEnd
    private static let dictBegin: UInt8 = UInt8(ascii: "d")
    private static let dictEnd: UInt8 = intEnd
    private static let minusSign: UInt8 = UInt8(ascii: "-")
    private static let ascii0: UInt8 = UInt8(ascii: "0")
    private static let ascii1: UInt8 = UInt8(ascii: "1")
    private static let ascii2: UInt8 = UInt8(ascii: "2")
    private static let ascii3: UInt8 = UInt8(ascii: "3")
    private static let ascii4: UInt8 = UInt8(ascii: "4")
    private static let ascii5: UInt8 = UInt8(ascii: "5")
    private static let ascii6: UInt8 = UInt8(ascii: "6")
    private static let ascii7: UInt8 = UInt8(ascii: "7")
    private static let ascii8: UInt8 = UInt8(ascii: "8")
    private static let ascii9: UInt8 = UInt8(ascii: "9")

    public init(source: Data) {
        self.start = 0
        self.current = 0
        self.source = source
    }

    public func nextValue() throws(BencodeDecodeError) -> BencodeValue? {
        guard !isFinished() else {
            return nil
        }

        start = current

        return switch advance() {
        case Self.intBegin: .int(try decodeInt())
        case let n where n.isAsciiDigit: .string(try decodeString())
        case Self.listBegin: .list(try decodeList())
        case Self.dictBegin: .dict(try decodeDict())
        case let c: throw .unexpectedValue(value: c, pos: current)
        }
    }

    func decodeInt() throws(BencodeDecodeError) -> Int {
        var sign = 1
        // at first check the sign
        if peek() == Self.minusSign {
            sign = -1
            assert(advance() == Self.minusSign)
        }

        // negative zero is not allowed
        if sign == -1 && peek() == Self.ascii0 {
            throw .badIntValue(value: peek()!, pos: current)
        }

        var n: Int = 0
        while let digit = peek(), digit != Self.intEnd {
            // leading zero are not allowed
            if n == 0 && digit == Self.ascii0 && peekNext()?.isAsciiDigit ?? false {
                throw .badIntValue(value: digit, pos: current + 1)
            }
            guard digit.isAsciiDigit else {
                throw .badIntValue(value: digit, pos: current)
            }
            n = n * 10 + (Int(digit) - 48)

            assert(advance().isAsciiDigit)
        }

        // now we expect an 'e' which means end of the int value
        if peek() != Self.intEnd {
            throw .badIntValue(value: peek() ?? 0, pos: current)
        }

        // consume 'e' if we are not at end
        if peek() != nil {
            assert(advance() == Self.intEnd)
        }

        return n * sign
    }

    func decodeString() throws(BencodeDecodeError) -> [UInt8] {
        // at first we need to get the length of the string
        assert(peekPrevious() != nil, "previous character must be there")
        let first = peekPrevious()!
        assert(first.isAsciiDigit, "previous character must be a digit")
        // cannot start with 0
        if first == Self.ascii0 {
            throw .badStringValue(value: first, pos: current - 1)
        }

        var length: UInt = UInt(first) - 48

        // now read the length until :
        while let digit = peek(), digit != Self.separator {
            if !digit.isAsciiDigit {
                throw .badStringValue(value: digit, pos: current)
            }
            length = length * 10 + UInt(digit - 48)

            assert(advance().isAsciiDigit)
        }

        // we expect :
        if peek() != Self.separator {
            throw .badIntValue(value: peek() ?? 0, pos: current)
        }
        // consume it
        assert(advance() == Self.separator)

        var buf = [UInt8]()
        buf.reserveCapacity(Int(length))
        // consume the next length bytes
        for _ in 0..<length {
            if isFinished() {
                throw .badStringValue(value: 0, pos: current - 1)
            }

            buf.append(advance())
        }

        return buf
    }

    func decodeList() throws(BencodeDecodeError) -> [BencodeValue] {
        // l is already consumed, just check it
        assert(peekPrevious() == Self.listBegin)

        if isFinished() {
            throw .badListValue(value: 0, pos: current)
        }

        // is it empty list?
        if peek() == Self.listEnd {
            return []
        }

        var values: [BencodeValue] = []
        while let value = try nextValue() {
            values.append(value)

            if peek() == Self.listEnd {
                break
            }
        }

        // we expect list end character
        guard let c = peek() else {
            throw .badListValue(value: 0, pos: current)
        }

        guard c == Self.listEnd else {
            throw .badListValue(value: c, pos: current)
        }

        assert(advance() == Self.listEnd)

        return values
    }

    func decodeDict() throws(BencodeDecodeError) -> [[UInt8]: BencodeValue] {
        // d is already consumed
        assert(peekPrevious() == Self.dictBegin)

        if isFinished() {
            throw .badDictKey(pos: current)
        }

        // is it empty dictionary?
        if peek() == Self.dictEnd {
            return [:]
        }

        var dict: [[UInt8]: BencodeValue] = [:]
        // iterate through the keys
        while let bencodeValue: BencodeValue = try nextValue() {
            // key must be a string
            let keyPos = current
            guard case BencodeValue.string(let key) = bencodeValue else {
                throw .badDictKey(pos: keyPos)
            }

            // now read the value
            let valuePos = current
            guard let value = try nextValue() else {
                throw .badDictValue(pos: valuePos)
            }

            dict[key] = value

            if peek() == Self.dictEnd {
                assert(advance() == Self.dictEnd)
                break
            }
        }

        return dict
    }

    func advance() -> UInt8 {
        assert(!isFinished(), "never call advance on finished data")

        let idx = source.index(source.startIndex, offsetBy: Int(current))
        let byte = source[idx]
        current += 1
        return byte
    }

    func peek() -> UInt8? {
        if isFinished() {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current))
        return source[idx]
    }

    func peekNext() -> UInt8? {
        if isFinished() {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current + 1))
        return source[idx]
    }

    func peekPrevious() -> UInt8? {
        if current == 0 {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current) - 1)
        return source[idx]
    }

    func isFinished() -> Bool {
        self.current >= self.source.count
    }

}
