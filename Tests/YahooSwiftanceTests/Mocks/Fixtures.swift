import Foundation

/// Sample JSON and protobuf test data for unit tests.
enum Fixtures {

    // MARK: - Chart JSON

    static let chartJSON = """
    {
        "chart": {
            "result": [{
                "meta": {
                    "currency": "USD",
                    "symbol": "AAPL",
                    "dataGranularity": "1d",
                    "previousClose": 150.0
                },
                "timestamp": [1700000000, 1700086400],
                "indicators": {
                    "quote": [{
                        "open": [150.0, 151.0],
                        "high": [155.0, 156.0],
                        "low": [149.0, 150.0],
                        "close": [154.0, 155.0],
                        "volume": [50000000, 45000000]
                    }],
                    "adjclose": [{
                        "adjclose": [154.0, 155.0]
                    }]
                }
            }],
            "error": null
        }
    }
    """

    // MARK: - Search JSON

    static let searchJSON = """
    {
        "quotes": [
            {
                "symbol": "AAPL",
                "shortname": "Apple Inc.",
                "quoteType": "EQUITY",
                "exchDisp": "NASDAQ",
                "sector": "Technology",
                "industry": "Consumer Electronics"
            },
            {
                "symbol": "AAPL.MX",
                "shortname": "Apple Inc.",
                "quoteType": "EQUITY",
                "exchDisp": "Mexico",
                "sector": null,
                "industry": null
            }
        ]
    }
    """

    // MARK: - Quote Summary JSON

    static let quoteSummaryJSON = """
    {
        "quoteSummary": {
            "result": [{
                "price": {
                    "symbol": "AAPL",
                    "shortName": "Apple Inc.",
                    "longName": "Apple Inc.",
                    "currency": "USD",
                    "exchange": "NMS",
                    "quoteType": "EQUITY",
                    "regularMarketPrice": {"raw": 178.72, "fmt": "178.72"},
                    "regularMarketChange": {"raw": 2.15, "fmt": "2.15"},
                    "regularMarketChangePercent": {"raw": 0.0122, "fmt": "1.22%"},
                    "regularMarketVolume": {"raw": 55000000, "fmt": "55M"},
                    "regularMarketDayHigh": {"raw": 179.50, "fmt": "179.50"},
                    "regularMarketDayLow": {"raw": 176.00, "fmt": "176.00"},
                    "regularMarketOpen": {"raw": 177.00, "fmt": "177.00"},
                    "regularMarketPreviousClose": {"raw": 176.57, "fmt": "176.57"},
                    "marketCap": {"raw": 2800000000000, "fmt": "2.8T"}
                },
                "summaryDetail": {
                    "bid": {"raw": 178.70, "fmt": "178.70"},
                    "ask": {"raw": 178.75, "fmt": "178.75"},
                    "bidSize": {"raw": 100, "fmt": "100"},
                    "askSize": {"raw": 200, "fmt": "200"},
                    "fiftyTwoWeekHigh": {"raw": 199.62, "fmt": "199.62"},
                    "fiftyTwoWeekLow": {"raw": 124.17, "fmt": "124.17"},
                    "fiftyDayAverage": {"raw": 185.50, "fmt": "185.50"},
                    "twoHundredDayAverage": {"raw": 170.30, "fmt": "170.30"},
                    "trailingPE": {"raw": 28.5, "fmt": "28.50"},
                    "forwardPE": {"raw": 25.0, "fmt": "25.00"},
                    "dividendYield": {"raw": 0.0055, "fmt": "0.55%"}
                }
            }],
            "error": null
        }
    }
    """

    // MARK: - Protobuf Test Data

    /// Builds a minimal protobuf message for a StreamQuote with the given symbol and price.
    static func buildProtobufMessage(symbol: String, price: Float, timestamp: Int64 = 1700000000) -> Data {
        var data = Data()

        // Field 1: symbol (wire type 2 = LEN)
        data.append(contentsOf: makeTag(fieldNumber: 1, wireType: 2))
        let symbolBytes = Array(symbol.utf8)
        data.append(contentsOf: encodeVarint(UInt64(symbolBytes.count)))
        data.append(contentsOf: symbolBytes)

        // Field 2: price (wire type 5 = I32/float)
        data.append(contentsOf: makeTag(fieldNumber: 2, wireType: 5))
        var priceBits = price.bitPattern
        data.append(contentsOf: withUnsafeBytes(of: &priceBits) { Array($0) })

        // Field 3: timestamp (wire type 0 = VARINT, zigzag encoded)
        data.append(contentsOf: makeTag(fieldNumber: 3, wireType: 0))
        let zigzag = zigzagEncode(timestamp)
        data.append(contentsOf: encodeVarint(zigzag))

        return data
    }

    /// A base64-encoded protobuf for AAPL at $150.25
    static var sampleProtobufBase64: String {
        buildProtobufMessage(symbol: "AAPL", price: 150.25).base64EncodedString()
    }

    /// Protobuf with extra unknown field (field 99, varint) — tests forward compatibility.
    static func protobufWithUnknownField() -> Data {
        var data = buildProtobufMessage(symbol: "TEST", price: 100.0)
        // Unknown field 99, wire type 0 (varint)
        data.append(contentsOf: makeTag(fieldNumber: 99, wireType: 0))
        data.append(contentsOf: encodeVarint(42))
        return data
    }

    // MARK: - Protobuf Helpers

    static func makeTag(fieldNumber: Int, wireType: Int) -> [UInt8] {
        encodeVarint(UInt64((fieldNumber << 3) | wireType))
    }

    static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var result: [UInt8] = []
        var v = value
        while v > 127 {
            result.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        result.append(UInt8(v))
        return result
    }

    static func zigzagEncode(_ value: Int64) -> UInt64 {
        UInt64(bitPattern: (value << 1) ^ (value >> 63))
    }
}
