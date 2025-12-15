import Foundation

/// Responsible for bencode encoding
public class BencodeEncoder {

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
        [Bencode.intBegin] + String(n).map { $0.asciiValue!/* cannot fail, must be a digit */ } + [Bencode.intEnd]
    }

    @inline(__always)
    private static func encodeString(_ s: [UInt8]) -> [UInt8] {
        String(s.count).map { $0.asciiValue! /* cannot fail */ } + [Bencode.separator] + s
    }

    @inline(__always)
    private static func encodeList(_ l: [BencodeValue]) -> [UInt8] {
        [Bencode.listBegin] + l.map { Self.encode($0) }.reduce([], +) + [Bencode.listEnd]
    }

    @inline(__always)
    private static func encodeDict(_ d: [[UInt8]: BencodeValue]) -> [UInt8] {
        [Bencode.dictBegin]
            + d.sorted(by: { $0.key > $1.key }).map { encodeString($0) + encode($1) }.reduce([], +)
            + [Bencode.dictEnd]
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
