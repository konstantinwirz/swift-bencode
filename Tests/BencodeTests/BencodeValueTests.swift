import Bencode
import Testing

@Suite("BecnodeValue Tests")
struct name {
    @Test func testPositiveIntPatternMatching() {
        let result =
            switch BencodeValue.int(42) {
            case 42: true
            default: false
            }
        #expect(result, "pattern matching for BencodeValue.int doesn't work")
    }

    @Test func testNegativeIntPatternMatching() {
        let result =
            switch BencodeValue.int(42) {
            case 100: false
            default: true
            }
        #expect(result, "pattern matching for BencodeValue.int doesn't work")
    }

    @Test func testPositiveStringPatternMatching() {
        let fortyTwo: [UInt8] = [102, 111, 114, 116, 121, 116, 119, 111]  // "fortytwo" in ASCII

        let result =
            switch BencodeValue.string(fortyTwo) {
            case "fortytwo": true
            default: false
            }
        #expect(result, "pattern matching for BencodeValue.string doesn't work")
    }

    @Test func testNegativeStringPatternMatching() {
        let fortyTwo: [UInt8] = [102, 111, 114, 116, 121, 116, 119, 111]  // "fortytwo" in ASCII

        let result = switch BencodeValue.string(fortyTwo) {
            case "fortysixandtwo": false
            default: true
            }
        #expect(result, "pattern matching for BencodeValue.string doesn't work")
    }
}
