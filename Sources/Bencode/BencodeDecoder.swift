import Foundation

/// Represents a bencode decoding error
public enum BencodeDecodeError: Error, Equatable {
    case unexpectedValue(value: UInt8, pos: UInt)
    case badInt(value: UInt8, pos: UInt)
    case badString(value: UInt8, pos: UInt)
    case badList(value: UInt8, pos: UInt)
    case badDictKey(pos: UInt)
    case badDictValue(pos: UInt)
}

extension UInt8 {
    /// returns true if this symbols is a ascii digit
    var isAsciiDigit: Bool {
        self >= 48 && self <= 57
    }
}

/// Responsible for decoding of bencode encoded value
public final class BencodeDecoder {
    private var current: UInt
    private let source: Data

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

    private init(source: Data) {
        self.current = 0
        self.source = source
    }

    
    /// Decodes bencode-encoded data into a `BencodeValue`.
    ///
    /// This method parses the provided data according to the Bencode specification and returns
    /// the corresponding `BencodeValue` representation. Bencode supports integers, byte strings,
    /// lists, and dictionaries.
    ///
    /// - Parameter source: The bencode-encoded data to decode.
    /// - Returns: A `BencodeValue` representing the decoded data, or `nil` if the input is empty.
    /// - Throws: `BencodeDecodeError` if the data is malformed or cannot be decoded according to
    ///   the Bencode specification.    ///
    public static func decode(_ source: Data) throws(BencodeDecodeError) -> BencodeValue? {
        let decoder = Self(source: source)
        let value = try decoder.nextValue()

        guard decoder.isFinished() else {
            throw .unexpectedValue(value: decoder.peek()!, pos: decoder.current)
        }

        return value
    }

    private func nextValue() throws(BencodeDecodeError) -> BencodeValue? {
        guard !isFinished() else {
            return nil
        }

        return switch advance() {
        case Bencode.intBegin: .int(try decodeInt())
        case let n where n.isAsciiDigit: .string(try decodeString())
        case Bencode.listBegin: .list(try decodeList())
        case Bencode.dictBegin: .dict(try decodeDict())
        case let c: throw .unexpectedValue(value: c, pos: current)
        }
    }

    private func decodeInt() throws(BencodeDecodeError) -> Int {
        var sign = 1
        // at first check the sign
        if peek() == Self.minusSign {
            sign = -1
            assert(advance() == Self.minusSign)
        }

        // negative zero is not allowed
        if sign == -1 && peek() == Self.ascii0 {
            throw .badInt(value: peek()!, pos: current)
        }

        var n: Int = 0
        while let digit = peek(), digit != Bencode.intEnd {
            // leading zero are not allowed
            if n == 0 && digit == Self.ascii0 && peekNext()?.isAsciiDigit ?? false {
                throw .badInt(value: digit, pos: current + 1)
            }
            guard digit.isAsciiDigit else {
                throw .badInt(value: digit, pos: current)
            }
            n = n * 10 + (Int(digit) - 48)

            assert(advance().isAsciiDigit)
        }

        // now we expect an 'e' which means end of the int value
        if peek() != Bencode.intEnd {
            throw .badInt(value: peek() ?? 0, pos: current)
        }

        // consume 'e' if we are not at end
        if peek() != nil {
            assert(advance() == Bencode.intEnd)
        }

        return n * sign
    }

    private func decodeString() throws(BencodeDecodeError) -> [UInt8] {
        // at first we need to get the length of the string
        assert(peekPrevious() != nil, "previous character must be there")
        let first = peekPrevious()!
        assert(first.isAsciiDigit, "previous character must be a digit")
        // cannot start with 0
        if first == Self.ascii0 {
            throw .badString(value: first, pos: current - 1)
        }

        var length: UInt = UInt(first) - 48

        // now read the length until :
        while let digit = peek(), digit != Bencode.separator {
            if !digit.isAsciiDigit {
                throw .badString(value: digit, pos: current)
            }
            length = length * 10 + UInt(digit - 48)

            assert(advance().isAsciiDigit)
        }

        // we expect :
        if peek() != Bencode.separator {
            throw .badInt(value: peek() ?? 0, pos: current)
        }
        // consume it
        assert(advance() == Bencode.separator)

        var buf = [UInt8]()
        buf.reserveCapacity(Int(length))
        // consume the next length bytes
        for _ in 0..<length {
            if isFinished() {
                throw .badString(value: 0, pos: current - 1)
            }

            buf.append(advance())
        }

        return buf
    }

    private func decodeList() throws(BencodeDecodeError) -> [BencodeValue] {
        // l is already consumed, just check it
        assert(peekPrevious() == Bencode.listBegin)

        if isFinished() {
            throw .badList(value: 0, pos: current)
        }

        var values: [BencodeValue] = []
        if peek() != Bencode.listEnd {
            while let value = try nextValue() {
                values.append(value)

                if peek() == Bencode.listEnd {
                    break
                }
            }
        }

        // we expect at least one character (list end)
        guard let c = peek() else {
            throw .badList(value: 0, pos: current)
        }

        guard c == Bencode.listEnd else {
            throw .badList(value: c, pos: current)
        }

        assert(advance() == Bencode.listEnd)

        return values
    }

    private func decodeDict() throws(BencodeDecodeError) -> [[UInt8]: BencodeValue] {
        // d is already consumed
        assert(peekPrevious() == Bencode.dictBegin)

        if isFinished() {
            throw .badDictKey(pos: current)
        }

        var dict: [[UInt8]: BencodeValue] = [:]
        if peek() != Bencode.dictEnd {
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

                if peek() == Bencode.dictEnd {
                    break
                }
            }
        }

        assert(advance() == Bencode.dictEnd)

        return dict
    }

    private func advance() -> UInt8 {
        assert(!isFinished(), "never call advance on finished data")

        let idx = source.index(source.startIndex, offsetBy: Int(current))
        let byte = source[idx]
        current += 1
        return byte
    }

    private func peek() -> UInt8? {
        if isFinished() {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current))
        return source[idx]
    }

    private func peekNext() -> UInt8? {
        if isFinished() {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current + 1))
        return source[idx]
    }

    private func peekPrevious() -> UInt8? {
        if current == 0 {
            return nil
        }

        let idx = source.index(source.startIndex, offsetBy: Int(current) - 1)
        return source[idx]
    }

    private func isFinished() -> Bool {
        self.current >= self.source.count
    }

}
