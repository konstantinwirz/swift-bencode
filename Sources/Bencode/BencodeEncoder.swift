import Foundation

/// Responsible for bencode encoding
public class BencodeEncoder {

    private static let intBegin: UInt8 = UInt8(ascii: "i")
    private static let intEnd: UInt8 = UInt8(ascii: "e")
    private static let listBegin: UInt8 = UInt8(ascii: "l")
    private static let listEnd: UInt8 = intEnd
    private static let dictBegin: UInt8 = UInt8(ascii: "d")
    private static let dictEnd: UInt8 = intEnd
    private static let separator: UInt8 = UInt8(ascii: ":")

    /// Encode given value
    /// doesn't throw any erros
    public static func encode(_ value: BencodeValue) -> Data {
        return switch value {
        case .int(let n): Data(encodeInt(n))
        case .string(let s): Data(encodeString(s))
        case .list(let l): Data(encodeList(l))
        case .dict(let d): Data(encodeDict(d))
        }
    }

    @inline(__always)
    private static func encodeInt(_ n: Int) -> [UInt8] {
        [intBegin] + String(n).map { $0.asciiValue!/* cannot fail, must be a digit */ } + [intEnd]
    }

    @inline(__always)
    private static func encodeString(_ s: [UInt8]) -> [UInt8] {
        String(s.count).map { $0.asciiValue! /* cannot fail */ } + [separator] + s
    }

    @inline(__always)
    private static func encodeList(_ l: [BencodeValue]) -> [UInt8] {
        [listBegin] + l.map { Self.encode($0) }.reduce([], +) + [listEnd]
    }

    @inline(__always)
    private static func encodeDict(_ d: [[UInt8]: BencodeValue]) -> [UInt8] {
        [dictBegin]
            + d.sorted(by: { $0.key > $1.key }).map { encodeString($0) + encode($1) }.reduce([], +)
            + [dictEnd]
    }
}

/// used for dictionary sorting
/// bencode requires the keys to be sorted lexicographically
private func > (lhs: [UInt8], rhs: [UInt8]) -> Bool {
    for i in 0..<min(lhs.count, rhs.count) {
        if lhs[i] != rhs[i] {
            return lhs[i] > rhs[i]
        }
    }

    return lhs.count > rhs.count
}
