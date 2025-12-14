import Foundation

/// Represents a value which can be encoded/decode with bencode
public enum BencodeValue: CustomStringConvertible, Equatable, Sendable {
    /// represents a single integer
    case int(Int)
    /// represents a bay array, must not be an UTF-8 string
    case string([UInt8])
    /// represents a list of bencode values
    case list([BencodeValue])
    /// represents a bencode dictionary
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