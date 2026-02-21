import XCTest
@testable import YahooSwiftance

final class ProtobufDecoderTests: XCTestCase {

    func testDecodeValidMessage() throws {
        let data = Fixtures.buildProtobufMessage(symbol: "AAPL", price: 150.25, timestamp: 1700000000)
        let quote = try ProtobufDecoder.decode(data: data)

        XCTAssertEqual(quote.symbol, "AAPL")
        XCTAssertEqual(quote.price, Double(Float(150.25)), accuracy: 0.01)
        XCTAssertEqual(quote.timestamp, Date(timeIntervalSince1970: 1700000000))
    }

    func testDecodeBase64() throws {
        let base64 = Fixtures.sampleProtobufBase64
        let quote = try ProtobufDecoder.decode(base64String: base64)

        XCTAssertEqual(quote.symbol, "AAPL")
        XCTAssertEqual(quote.price, Double(Float(150.25)), accuracy: 0.01)
    }

    func testDecodeMinimalMessage() throws {
        // Only symbol and price (minimum required fields)
        var data = Data()
        // Field 1: symbol
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 1, wireType: 2))
        let sym = Array("X".utf8)
        data.append(contentsOf: Fixtures.encodeVarint(UInt64(sym.count)))
        data.append(contentsOf: sym)
        // Field 2: price
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 2, wireType: 5))
        var price: Float = 1.0
        data.append(contentsOf: withUnsafeBytes(of: &price) { Array($0) })

        let quote = try ProtobufDecoder.decode(data: data)
        XCTAssertEqual(quote.symbol, "X")
        XCTAssertEqual(quote.price, 1.0, accuracy: 0.001)
    }

    func testInvalidBase64Throws() {
        XCTAssertThrowsError(try ProtobufDecoder.decode(base64String: "!!!invalid!!!")) { error in
            guard case YahooFinanceError.protobufDecodingError = error else {
                XCTFail("Expected protobufDecodingError, got \(error)")
                return
            }
        }
    }

    func testTruncatedDataThrows() {
        // Just a tag with no following data
        let data = Data([0x0A]) // field 1, wire type 2 (LEN) — but no length or bytes
        XCTAssertThrowsError(try ProtobufDecoder.decode(data: data))
    }

    func testMissingSymbolThrows() {
        // Only a price field, no symbol
        var data = Data()
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 2, wireType: 5))
        var price: Float = 100.0
        data.append(contentsOf: withUnsafeBytes(of: &price) { Array($0) })

        XCTAssertThrowsError(try ProtobufDecoder.decode(data: data)) { error in
            guard case YahooFinanceError.protobufDecodingError(let msg) = error else {
                XCTFail("Expected protobufDecodingError, got \(error)")
                return
            }
            XCTAssert(msg.contains("symbol"))
        }
    }

    func testUnknownFieldIsSkipped() throws {
        let data = Fixtures.protobufWithUnknownField()
        let quote = try ProtobufDecoder.decode(data: data)
        XCTAssertEqual(quote.symbol, "TEST")
        XCTAssertEqual(quote.price, Double(Float(100.0)), accuracy: 0.01)
    }

    func testZigzagDecode() {
        XCTAssertEqual(ProtobufDecoder.zigzagDecode(0), 0)
        XCTAssertEqual(ProtobufDecoder.zigzagDecode(1), -1)
        XCTAssertEqual(ProtobufDecoder.zigzagDecode(2), 1)
        XCTAssertEqual(ProtobufDecoder.zigzagDecode(3), -2)
        XCTAssertEqual(ProtobufDecoder.zigzagDecode(4294967294), 2147483647)
    }
}
