
/// Contains some constants needed for encoding/decoding
internal struct Bencode {
    internal static let intBegin: UInt8 = UInt8(ascii: "i")
    internal static let intEnd: UInt8 = UInt8(ascii: "e")
    internal static let listBegin: UInt8 = UInt8(ascii: "l")
    internal static let listEnd: UInt8 = intEnd
    internal static let dictBegin: UInt8 = UInt8(ascii: "d")
    internal static let dictEnd: UInt8 = intEnd
    internal static let separator: UInt8 = UInt8(ascii: ":")
}