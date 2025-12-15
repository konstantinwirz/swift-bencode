import Bencode
import Foundation
import Testing

@Suite("BencodeEncoder Tests")
struct BencodeEncoderTests {

    @Test(
        "should encode",
        arguments: [
            (input: BencodeValue.int(42), expected: "i42e".ascii),
            (input: BencodeValue.int(0), expected: "i0e".ascii),
            (input: BencodeValue.int(-42), expected: "i-42e".ascii),
            (input: BencodeValue.string("".ascii), expected: "0:".ascii),
            (input: BencodeValue.string("foobar".ascii), expected: "6:foobar".ascii),
            (
                input: BencodeValue.list([
                    BencodeValue.string("spam".ascii), BencodeValue.string("eggs".ascii),
                ]), expected: "l4:spam4:eggse".ascii
            ),
            (
                input: .dict(["meaning".ascii: 42.bencode, "wiki".ascii: "bencode".bencode]),
                expected: "d4:wiki7:bencode7:meaningi42ee".ascii
            ),
        ])
    func encodeInts(input: BencodeValue, expected: [UInt8]) async throws {
        #expect(BencodeEncoder.encode(input) == Data(expected))
    }

}
