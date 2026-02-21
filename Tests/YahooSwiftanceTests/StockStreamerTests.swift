import XCTest
@testable import YahooSwiftance

final class StockStreamerTests: XCTestCase {

    func testProtobufDecodeFromBase64() throws {
        let data = Fixtures.buildProtobufMessage(symbol: "AAPL", price: 150.25, timestamp: 1700000000)
        let base64 = data.base64EncodedString()
        let quote = try ProtobufDecoder.decode(base64String: base64)

        XCTAssertEqual(quote.symbol, "AAPL")
        XCTAssertEqual(quote.price, Double(Float(150.25)), accuracy: 0.01)
    }

    func testProtobufDecodeMultipleSymbols() throws {
        let symbols = ["AAPL", "GOOGL", "MSFT", "AMZN"]
        let prices: [Float] = [150.0, 140.0, 350.0, 175.0]

        for (symbol, price) in zip(symbols, prices) {
            let data = Fixtures.buildProtobufMessage(symbol: symbol, price: price)
            let quote = try ProtobufDecoder.decode(data: data)
            XCTAssertEqual(quote.symbol, symbol)
            XCTAssertEqual(quote.price, Double(price), accuracy: 0.01)
        }
    }

    func testStreamQuoteEquatable() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let q1 = StreamQuote(symbol: "AAPL", price: 150.0, timestamp: date)
        let q2 = StreamQuote(symbol: "AAPL", price: 150.0, timestamp: date)
        let q3 = StreamQuote(symbol: "GOOGL", price: 140.0, timestamp: date)

        XCTAssertEqual(q1, q2)
        XCTAssertNotEqual(q1, q3)
    }

    func testStreamQuoteMarketHours() {
        XCTAssertEqual(MarketHours(rawValue: "PRE"), .preMarket)
        XCTAssertEqual(MarketHours(rawValue: "REGULAR"), .regularMarket)
        XCTAssertEqual(MarketHours(rawValue: "POST"), .postMarket)
        XCTAssertEqual(MarketHours(rawValue: "CLOSED"), .closed)
        XCTAssertNil(MarketHours(rawValue: "UNKNOWN"))
    }

    func testProtobufWithAllFields() throws {
        var data = Data()

        // Field 1: symbol
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 1, wireType: 2))
        let sym = Array("TSLA".utf8)
        data.append(contentsOf: Fixtures.encodeVarint(UInt64(sym.count)))
        data.append(contentsOf: sym)

        // Field 2: price
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 2, wireType: 5))
        var price: Float = 250.50
        data.append(contentsOf: withUnsafeBytes(of: &price) { Array($0) })

        // Field 3: timestamp (zigzag)
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 3, wireType: 0))
        data.append(contentsOf: Fixtures.encodeVarint(Fixtures.zigzagEncode(1700000000)))

        // Field 4: currency
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 4, wireType: 2))
        let cur = Array("USD".utf8)
        data.append(contentsOf: Fixtures.encodeVarint(UInt64(cur.count)))
        data.append(contentsOf: cur)

        // Field 5: exchange
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 5, wireType: 2))
        let exch = Array("NMS".utf8)
        data.append(contentsOf: Fixtures.encodeVarint(UInt64(exch.count)))
        data.append(contentsOf: exch)

        // Field 6: market hours
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 6, wireType: 2))
        let hours = Array("REGULAR".utf8)
        data.append(contentsOf: Fixtures.encodeVarint(UInt64(hours.count)))
        data.append(contentsOf: hours)

        // Field 7: changePercent
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 7, wireType: 5))
        var changePct: Float = 1.5
        data.append(contentsOf: withUnsafeBytes(of: &changePct) { Array($0) })

        // Field 11: change
        data.append(contentsOf: Fixtures.makeTag(fieldNumber: 11, wireType: 5))
        var change: Float = 3.75
        data.append(contentsOf: withUnsafeBytes(of: &change) { Array($0) })

        let quote = try ProtobufDecoder.decode(data: data)
        XCTAssertEqual(quote.symbol, "TSLA")
        XCTAssertEqual(quote.price, Double(Float(250.50)), accuracy: 0.01)
        XCTAssertEqual(quote.currency, "USD")
        XCTAssertEqual(quote.exchange, "NMS")
        XCTAssertEqual(quote.marketHours, .regularMarket)
        XCTAssertEqual(quote.changePercent!, Double(Float(1.5)), accuracy: 0.01)
        XCTAssertEqual(quote.change!, Double(Float(3.75)), accuracy: 0.01)
    }
}
