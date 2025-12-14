import Foundation
import Testing
import Bencode

@Suite("Bencode Decoder Tests")
struct BencodeDecoderTests {
    @Test(
        "can handle valid integers",
        arguments: [
            (input: "i3e", expected: 3),
            (input: "i-3e", expected: -3),
            (input: "i0e", expected: 0),
            (input: "i256e", expected: 256),
            (input: "i-256e", expected: -256),
        ]
    ) func decodeValidInts(input: String, expected: Int) throws {
        let intValue = try #require(try BencodeDecoder.decode(Data(input.utf8)))
        if case .int(let n) = intValue, n != expected {
            Issue.record("Expected \(expected), but got \(n)")
        }
    }

    @Test(
        "can handle invalid integer input",
        arguments: [
            (
                input: "i-0e",
                expected: BencodeDecodeError.badInt(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                input: "i00e",
                expected: BencodeDecodeError.badInt(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                input: "i01e",
                expected: BencodeDecodeError.badInt(value: UInt8(ascii: "0"), pos: 2)
            ),
            (
                input: "i--1e",
                expected: BencodeDecodeError.badInt(value: UInt8(ascii: "-"), pos: 2)
            ),
            (
                input: "i-1Qe",
                expected: BencodeDecodeError.badInt(value: UInt8(ascii: "Q"), pos: 3)
            ),
            (input: "i12345", expected: BencodeDecodeError.badInt(value: 0, pos: 6)),
        ])
    func decodeInvalidInts(input: String, expected: BencodeDecodeError) {
        #expect(throws: expected) {
            try BencodeDecoder.decode(Data(input.utf8))
        }
    }

    @Test(
        "can handle valid strings",
        arguments: [
            (input: "4:abba", expected: "abba".ascii)
        ])
    func decodeValidStrings(input: String, expected: [UInt8]) throws {
        let stringValue = try #require(try BencodeDecoder.decode(Data(input.utf8)))
        if case .string(let bytes) = stringValue, bytes != expected {
            Issue.record("Expected \(expected), but got \(bytes)")
        }
    }

    @Test(
        "can handle invalid strings",
        arguments: [
            (
                input: "0:",
                expected: BencodeDecodeError.badString(value: "0".ascii.first!, pos: 0)
            ),
            (input: "10:abba", expected: BencodeDecodeError.badString(value: 0, pos: 6)),
            (input: "250:", expected: BencodeDecodeError.badString(value: 0, pos: 3)),
        ])
    func decodeInvalidStrings(input: String, expected: BencodeDecodeError) throws {
        #expect(throws: expected) {
            try BencodeDecoder.decode(Data(input.utf8))
        }
    }

    @Test(
        "can handle valid lists",
        arguments: [
            (input: "le", expected: [BencodeValue]()),
            (input: "l4:spame", expected: [BencodeValue.string("spam".ascii)]),
            (
                input: "l4:spam4:eggse",
                expected: [BencodeValue.string("spam".ascii), BencodeValue.string("eggs".ascii)]
            ),
            (
                input: "l4:spam4:eggsli13ei39eee",
                expected: [
                    BencodeValue.string("spam".ascii),
                    BencodeValue.string("eggs".ascii),
                    BencodeValue.list([BencodeValue.int(13), BencodeValue.int(39)]),
                ]
            ),
        ])
    func decodeValidLists(input: String, expected: [BencodeValue]) throws {
        let listValues = try #require(try BencodeDecoder.decode(Data(input.utf8)))
        if case .list(let values) = listValues, values != expected {
            Issue.record("Expected \(expected), but got \(values)")
        }
    }


    @Test(
        "can handle invalid lists",
        arguments: [
            (input: "l", expected: BencodeDecodeError.badList(value: 0, pos: 1)),
            (input: "l4:spam", expected: .badList(value: 0, pos: 7)),
            (
                input: "li-0ee",
                expected: .badInt(value: UInt8(ascii: "0"), pos: 3)
            ),
            (
                input: "l0:e",
                expected: .badString(value: UInt8(ascii: "0"), pos: 1)
            ),
        ])
    func decodeInvalidLists(input: String, expected: BencodeDecodeError) {
        #expect(throws: expected) {
            try BencodeDecoder.decode(Data(input.utf8))
        }
    }

    @Test(
        "can handle valid dictionaries",
        arguments: [
            (input: "de", expected: [[UInt8]: BencodeValue]()),
            (
                input: "d7:meaningi42e4:wiki7:bencodee",
                expected: ["meaning".ascii: 42.bencode, "wiki".ascii: "bencode".bencode]
            ),
        ])
    func decodeValidDicts(input: String, expected: [[UInt8]: BencodeValue]) throws {
        let dict = try #require(try BencodeDecoder.decode(Data(input.utf8)))
        if case .dict(let values) = dict, values != expected {
            Issue.record("Expected \(expected), but got \(values)")
        }
    }

    @Test(
        "can handle invalid dictionaries",
        arguments: [
            (input: "d", expected: BencodeDecodeError.badDictKey(pos: 1)),
            (input: "d1e", expected: BencodeDecodeError.badString(value: "e".ascii.first!, pos: 2)),
        ])
    func decodeInvalidDicts(input: String, expected: BencodeDecodeError) {
        #expect(throws: expected) {
            try BencodeDecoder.decode(Data(input.utf8))
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
