import XCTest
@testable import YahooSwiftance

final class ModelDecodingTests: XCTestCase {

    func testSearchResultDecoding() throws {
        let json = """
        {
            "symbol": "AAPL",
            "shortname": "Apple Inc.",
            "quoteType": "EQUITY",
            "exchDisp": "NASDAQ",
            "sector": "Technology",
            "industry": "Consumer Electronics"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(SearchResult.self, from: json)
        XCTAssertEqual(result.symbol, "AAPL")
        XCTAssertEqual(result.name, "Apple Inc.")
        XCTAssertEqual(result.type, "EQUITY")
        XCTAssertEqual(result.exchange, "NASDAQ")
        XCTAssertEqual(result.sector, "Technology")
        XCTAssertEqual(result.industry, "Consumer Electronics")
    }

    func testSearchResultRoundTrip() throws {
        let original = SearchResult(
            symbol: "GOOGL",
            name: "Alphabet Inc.",
            type: "EQUITY",
            exchange: "NASDAQ",
            sector: nil,
            industry: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testQuoteDecoding() throws {
        let json = """
        {
            "symbol": "AAPL",
            "shortName": "Apple Inc.",
            "longName": "Apple Inc.",
            "currency": "USD",
            "exchange": "NMS",
            "quoteType": "EQUITY",
            "regularMarketPrice": 178.72,
            "regularMarketChange": 2.15,
            "regularMarketChangePercent": 0.0122,
            "regularMarketVolume": 55000000,
            "regularMarketDayHigh": 179.50,
            "regularMarketDayLow": 176.00,
            "regularMarketOpen": 177.00,
            "regularMarketPreviousClose": 176.57,
            "bid": 178.70,
            "ask": 178.75,
            "bidSize": 100,
            "askSize": 200,
            "marketCap": 2800000000000,
            "fiftyTwoWeekHigh": 199.62,
            "fiftyTwoWeekLow": 124.17,
            "fiftyDayAverage": 185.50,
            "twoHundredDayAverage": 170.30,
            "trailingPE": 28.5,
            "forwardPE": 25.0,
            "dividendYield": 0.0055
        }
        """.data(using: .utf8)!

        let quote = try JSONDecoder().decode(Quote.self, from: json)
        XCTAssertEqual(quote.symbol, "AAPL")
        XCTAssertEqual(quote.regularMarketPrice, 178.72)
        XCTAssertEqual(quote.marketCap, 2800000000000)
    }

    func testQuoteRoundTrip() throws {
        let original = Quote(
            symbol: "MSFT",
            shortName: "Microsoft",
            longName: "Microsoft Corporation",
            currency: "USD",
            exchange: "NMS",
            quoteType: "EQUITY",
            regularMarketPrice: 350.0,
            regularMarketChange: 5.0,
            regularMarketChangePercent: 0.014,
            regularMarketVolume: 20000000,
            regularMarketDayHigh: 352.0,
            regularMarketDayLow: 348.0,
            regularMarketOpen: 349.0,
            regularMarketPreviousClose: 345.0,
            bid: 350.0,
            ask: 350.1,
            bidSize: 100,
            askSize: 200,
            marketCap: 2600000000000,
            fiftyTwoWeekHigh: 380.0,
            fiftyTwoWeekLow: 280.0,
            fiftyDayAverage: 340.0,
            twoHundredDayAverage: 320.0,
            trailingPE: 35.0,
            forwardPE: 30.0,
            dividendYield: 0.008
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Quote.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testChartResponseDecoding() throws {
        let json = Fixtures.chartJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(ChartResponse.self, from: json)

        let result = response.chart.result?.first
        XCTAssertNotNil(result)

        let chartData = result!.toChartData()
        XCTAssertEqual(chartData.symbol, "AAPL")
        XCTAssertEqual(chartData.currency, "USD")
        XCTAssertEqual(chartData.interval, "1d")
        XCTAssertEqual(chartData.points.count, 2)
        XCTAssertEqual(chartData.points[0].close, 154.0)
        XCTAssertEqual(chartData.points[0].volume, 50000000)
        XCTAssertEqual(chartData.points[1].adjustedClose, 155.0)
        XCTAssertEqual(chartData.previousClose, 150.0)
    }

    func testChartDataSafeSubscript() {
        let empty: [Int] = []
        XCTAssertNil(empty[safe: 0])

        let arr = [1, 2, 3]
        XCTAssertEqual(arr[safe: 0], 1)
        XCTAssertEqual(arr[safe: 2], 3)
        XCTAssertNil(arr[safe: 3])
        XCTAssertNil(arr[safe: -1])
    }

    func testIntervalRawValues() {
        XCTAssertEqual(Interval.oneMinute.rawValue, "1m")
        XCTAssertEqual(Interval.fiveMinutes.rawValue, "5m")
        XCTAssertEqual(Interval.oneDay.rawValue, "1d")
        XCTAssertEqual(Interval.oneWeek.rawValue, "1wk")
        XCTAssertEqual(Interval.oneMonth.rawValue, "1mo")
    }

    func testSearchResponseDecoding() throws {
        let json = Fixtures.searchJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(SearchResponse.self, from: json)
        XCTAssertEqual(response.quotes?.count, 2)
        XCTAssertEqual(response.quotes?.first?.symbol, "AAPL")
    }

    func testQuoteSummaryResponseDecoding() throws {
        let json = Fixtures.quoteSummaryJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(QuoteSummaryResponse.self, from: json)

        let quote = response.quoteSummary.result?.first?.toQuote()
        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.symbol, "AAPL")
        XCTAssertEqual(quote?.shortName, "Apple Inc.")
        XCTAssertEqual(quote?.regularMarketPrice, 178.72)
        XCTAssertEqual(quote?.regularMarketChange, 2.15)
        XCTAssertEqual(quote?.bid, 178.70)
        XCTAssertEqual(quote?.ask, 178.75)
        XCTAssertEqual(quote?.fiftyTwoWeekHigh, 199.62)
        XCTAssertEqual(quote?.dividendYield, 0.0055)
    }
}
