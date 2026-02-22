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

    // MARK: - StreamFrequency

    func testStreamFrequencyIntervalRealtime() {
        XCTAssertNil(StreamFrequency.realtime.interval)
    }

    func testStreamFrequencyIntervalMillis() {
        XCTAssertEqual(StreamFrequency.millis(500).interval!, 0.5, accuracy: 0.001)
        XCTAssertEqual(StreamFrequency.millis(100).interval!, 0.1, accuracy: 0.001)
        XCTAssertEqual(StreamFrequency.millis(1000).interval!, 1.0, accuracy: 0.001)
    }

    func testStreamFrequencyIntervalSeconds() {
        XCTAssertEqual(StreamFrequency.seconds(2.5).interval!, 2.5, accuracy: 0.001)
        XCTAssertEqual(StreamFrequency.seconds(0.1).interval!, 0.1, accuracy: 0.001)
    }

    func testStreamFrequencyIntervalConvenience() {
        XCTAssertEqual(StreamFrequency.everySecond.interval!, 1.0, accuracy: 0.001)
        XCTAssertEqual(StreamFrequency.everyFiveSeconds.interval!, 5.0, accuracy: 0.001)
    }

    // MARK: - ThrottledQuoteSequence

    func testThrottleRealtimePassesAllQuotes() async throws {
        let quotes = [
            StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()),
            StreamQuote(symbol: "AAPL", price: 151.0, timestamp: Date()),
            StreamQuote(symbol: "AAPL", price: 152.0, timestamp: Date()),
        ]

        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            for q in quotes { continuation.yield(q) }
            continuation.finish()
        }

        let sequence = QuoteSequence(base: stream)
        var received: [StreamQuote] = []
        for try await quote in sequence {
            received.append(quote)
        }

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received.map(\.price), [150.0, 151.0, 152.0])
    }

    func testThrottleFiltersRapidQuotes() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            // Emit 5 quotes for AAPL with no delay — only the first should pass
            for i in 0..<5 {
                let q = StreamQuote(symbol: "AAPL", price: Double(150 + i), timestamp: Date())
                continuation.yield(q)
            }
            continuation.finish()
        }

        let throttled = QuoteSequence(base: stream).throttle(.seconds(10))
        var received: [StreamQuote] = []
        for try await quote in throttled {
            received.append(quote)
        }

        // With a 10-second throttle and instant emission, only the first should pass
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.price, 150.0)
    }

    func testThrottlePerSymbol() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            // Alternate between two symbols — each symbol's first quote should pass
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "GOOGL", price: 140.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 151.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "GOOGL", price: 141.0, timestamp: Date()))
            continuation.finish()
        }

        let throttled = QuoteSequence(base: stream).throttle(.seconds(10))
        var received: [StreamQuote] = []
        for try await quote in throttled {
            received.append(quote)
        }

        // Only the first quote per symbol should pass through
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[0].symbol, "AAPL")
        XCTAssertEqual(received[0].price, 150.0)
        XCTAssertEqual(received[1].symbol, "GOOGL")
        XCTAssertEqual(received[1].price, 140.0)
    }

    // MARK: - PriceFilteredQuoteSequence

    func testPriceFilterAbsolutePassesFirstQuote() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()))
            continuation.finish()
        }

        let filtered = QuoteSequence(base: stream).filter(minimumChange: .absolute(1.0))
        var received: [StreamQuote] = []
        for try await quote in filtered {
            received.append(quote)
        }

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.price, 150.0)
    }

    func testPriceFilterAbsoluteSkipsSmallMoves() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.3, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.5, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 152.0, timestamp: Date()))
            continuation.finish()
        }

        let filtered = QuoteSequence(base: stream).filter(minimumChange: .absolute(1.0))
        var received: [StreamQuote] = []
        for try await quote in filtered {
            received.append(quote)
        }

        // First (150.0) always passes, 150.3 and 150.5 are within $1, 152.0 exceeds $1
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.map(\.price), [150.0, 152.0])
    }

    func testPriceFilterPercentSkipsSmallMoves() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.4, timestamp: Date())) // 0.4%
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.9, timestamp: Date())) // 0.9%
            continuation.yield(StreamQuote(symbol: "AAPL", price: 102.0, timestamp: Date())) // 2.0%
            continuation.finish()
        }

        let filtered = QuoteSequence(base: stream).filter(minimumChange: .percent(1.0))
        var received: [StreamQuote] = []
        for try await quote in filtered {
            received.append(quote)
        }

        // First (100.0) always passes, 100.4 and 100.9 are within 1%, 102.0 exceeds 1%
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.map(\.price), [100.0, 102.0])
    }

    func testPriceFilterPerSymbol() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "GOOGL", price: 140.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.3, timestamp: Date())) // skip
            continuation.yield(StreamQuote(symbol: "GOOGL", price: 145.0, timestamp: Date())) // pass
            continuation.finish()
        }

        let filtered = QuoteSequence(base: stream).filter(minimumChange: .absolute(1.0))
        var received: [StreamQuote] = []
        for try await quote in filtered {
            received.append(quote)
        }

        // AAPL: 150.0 passes, 150.3 skipped (within $1)
        // GOOGL: 140.0 passes, 145.0 passes (exceeds $1)
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received.map(\.symbol), ["AAPL", "GOOGL", "GOOGL"])
        XCTAssertEqual(received.map(\.price), [150.0, 140.0, 145.0])
    }

    func testPriceFilterComparesAgainstLastEmitted() async throws {
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.3, timestamp: Date())) // skip (vs 100.0)
            continuation.yield(StreamQuote(symbol: "AAPL", price: 100.8, timestamp: Date())) // skip (vs 100.0)
            continuation.yield(StreamQuote(symbol: "AAPL", price: 101.5, timestamp: Date())) // pass (vs 100.0)
            continuation.yield(StreamQuote(symbol: "AAPL", price: 101.8, timestamp: Date())) // skip (vs 101.5)
            continuation.finish()
        }

        let filtered = QuoteSequence(base: stream).filter(minimumChange: .absolute(1.0))
        var received: [StreamQuote] = []
        for try await quote in filtered {
            received.append(quote)
        }

        // Comparison is always against last *emitted* price, not last seen price
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.map(\.price), [100.0, 101.5])
    }

    func testPriceFilterChainedWithThrottle() async throws {
        // Verify chaining compiles and works: throttle then filter
        let stream = AsyncThrowingStream<StreamQuote, Error> { continuation in
            continuation.yield(StreamQuote(symbol: "AAPL", price: 150.0, timestamp: Date()))
            continuation.yield(StreamQuote(symbol: "AAPL", price: 155.0, timestamp: Date()))
            continuation.finish()
        }

        let chained = QuoteSequence(base: stream)
            .filter(minimumChange: .absolute(1.0))
            .throttle(.realtime)
        var received: [StreamQuote] = []
        for try await quote in chained {
            received.append(quote)
        }

        XCTAssertEqual(received.count, 2)
    }

    // MARK: - PriceThreshold

    func testPriceThresholdAbsolute() {
        let threshold = PriceThreshold.absolute(1.0)
        XCTAssertFalse(threshold.isExceeded(previous: 100.0, current: 100.5))
        XCTAssertFalse(threshold.isExceeded(previous: 100.0, current: 101.0))
        XCTAssertTrue(threshold.isExceeded(previous: 100.0, current: 101.5))
        XCTAssertTrue(threshold.isExceeded(previous: 100.0, current: 98.5))
    }

    func testPriceThresholdPercent() {
        let threshold = PriceThreshold.percent(1.0)
        XCTAssertFalse(threshold.isExceeded(previous: 100.0, current: 100.5))
        XCTAssertFalse(threshold.isExceeded(previous: 100.0, current: 101.0))
        XCTAssertTrue(threshold.isExceeded(previous: 100.0, current: 101.5))
        XCTAssertTrue(threshold.isExceeded(previous: 100.0, current: 98.0))
    }

    func testPriceThresholdPercentZeroPrevious() {
        let threshold = PriceThreshold.percent(1.0)
        // When previous is 0, any move should exceed
        XCTAssertTrue(threshold.isExceeded(previous: 0.0, current: 1.0))
    }

    // MARK: - Protobuf (all fields)

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
