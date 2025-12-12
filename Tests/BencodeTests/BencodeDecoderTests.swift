import Foundation
import Testing
import Bencode

@Suite("Bencode Decoder Tests")
struct BencodeDecoderTests {
    @Test(
        "can handle valid integers",
        arguments: [
            (actual: "i3e", expected: 3),
            (actual: "i-3e", expected: -3),
            (actual: "i0e", expected: 0),
            (actual: "i256e", expected: 256),
            (actual: "i-256e", expected: -256),
        ]
    ) func decodeValidInts(actual: String, expected: Int) throws {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        let intValue = try #require(try decoder.nextValue())
        if case .int(let n) = intValue, n != expected {
            Issue.record("Expected \(expected), but got \(n)")
        }
    }

    @Test(
        "can handle invalid integer input",
        arguments: [
            (
                actual: "i-0e",
                expected: BencodeDecodeError.badIntValue(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                actual: "i00e",
                expected: BencodeDecodeError.badIntValue(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                actual: "i01e",
                expected: BencodeDecodeError.badIntValue(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                actual: "i--1e",
                expected: BencodeDecodeError.badIntValue(value: UInt8(ascii: "-"), pos: 2)
            ),
            (
                actual: "i-1Qe",
                expected: BencodeDecodeError.badIntValue(value: UInt8(ascii: "Q"), pos: 3)
            ),
            (actual: "i12345", expected: BencodeDecodeError.badIntValue(value: 0, pos: 6)),
        ])
    func decodeInvalidInts(actual: String, expected: BencodeDecodeError) {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        #expect(throws: expected) {
            try decoder.nextValue()
        }
    }

    @Test(
        "can handle valid strings",
        arguments: [
            (actual: "4:abba", expected: "abba".ascii)
        ])
    func decodeValidStrings(actual: String, expected: [UInt8]) throws {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        let stringValue = try #require(try decoder.nextValue())
        if case .string(let bytes) = stringValue, bytes != expected {
            Issue.record("Expected \(expected), but got \(bytes)")
        }
    }

    @Test(
        "can handle invalid strings",
        arguments: [
            (
                actual: "0:",
                expected: BencodeDecodeError.badStringValue(value: "0".ascii.first!, pos: 0)
            ),
            (actual: "10:abba", expected: BencodeDecodeError.badStringValue(value: 0, pos: 6)),
            (actual: "250:", expected: BencodeDecodeError.badStringValue(value: 0, pos: 3)),
        ])
    func decodeInvalidStrings(actual: String, expected: BencodeDecodeError) throws {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        #expect(throws: expected) {
            try decoder.nextValue()
        }
    }

    @Test(
        "can handle valid lists",
        arguments: [
            (actual: "le", expected: [BencodeValue]()),
            (actual: "l4:spame", expected: [BencodeValue.string("spam".ascii)]),
            (
                actual: "l4:spam4:eggse",
                expected: [BencodeValue.string("spam".ascii), BencodeValue.string("eggs".ascii)]
            ),
            (
                actual: "l4:spam4:eggsli13ei39eee",
                expected: [
                    BencodeValue.string("spam".ascii),
                    BencodeValue.string("eggs".ascii),
                    BencodeValue.list([BencodeValue.int(13), BencodeValue.int(39)]),
                ]
            ),
        ])
    func decodeValidLists(actual: String, expected: [BencodeValue]) throws {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        let listValues = try #require(try decoder.nextValue())
        if case .list(let values) = listValues, values != expected {
            Issue.record("Expected \(expected), but got \(values)")
        }
    }


    @Test(
        "can handle invalid lists",
        arguments: [
            (actual: "l", expected: BencodeDecodeError.badListValue(value: 0, pos: 1)),
            (actual: "l4:spam", expected: .badListValue(value: 0, pos: 7)),
            (
                actual: "li-0ee",
                expected: .badIntValue(value: UInt8(ascii: "0"), pos: 3)
            ),
            (
                actual: "l0:e",
                expected: .badStringValue(value: UInt8(ascii: "0"), pos: 1)
            ),
        ])
    func decodeInvalidLists(actual: String, expected: BencodeDecodeError) {
        let decoder = BencodeDecoder(source: Data(actual.utf8))
        #expect(throws: expected) {
            try decoder.nextValue()
        }
    }

    @Test(
        "can handle valid dictionaries",
        arguments: [
            (source: "de", expected: [[UInt8]: BencodeValue]()),
            (
                source: "d7:meaningi42e4:wiki7:bencodee",
                expected: ["meaning".ascii: 42.bencode, "wiki".ascii: "bencode".bencode]
            ),
        ])
    func decodeValidDicts(source: String, expected: [[UInt8]: BencodeValue]) throws {
        let decoder = BencodeDecoder(source: Data(source.utf8))
        let dict = try #require(try decoder.nextValue())
        if case .dict(let values) = dict, values != expected {
            Issue.record("Expected \(expected), but got \(values)")
        }
    }

    @Test(
        "can handle invalid dictionaries",
        arguments: [
            (aource: "d", expected: BencodeDecodeError.badDictKey(pos: 1)),
            (aource: "d1e", expected: BencodeDecodeError.badStringValue(value: "e".ascii.first!, pos: 2)),
        ])
    func decodeInvalidDicts(source: String, expected: BencodeDecodeError) {
        let decoder = BencodeDecoder(source: Data(source.utf8))
        #expect(throws: expected) {
            try decoder.nextValue()
        }
    }
}

extension String {
    var ascii: [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(self.count)
        for c in self {
            buf.append(c.asciiValue!)
        }
        return buf
    }

    var bencode: BencodeValue {
        .string(self.ascii)
    }
}

extension Int {
    var bencode: BencodeValue {
        .int(self)
    }
}
