import XCTest
@testable import YahooSwiftance

final class HTTPClientTests: XCTestCase {
    var session: URLSession!
    var client: HTTPClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        session = .mock()
        client = HTTPClient(session: session)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testDecodeChartResponse() async throws {
        MockURLProtocol.setResponse(for: "chart", json: Fixtures.chartJSON)

        let response = try await client.fetch(
            ChartResponse.self,
            from: .chart(symbol: "AAPL", interval: .oneDay, from: nil, to: nil)
        )

        let result = response.chart.result?.first
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meta?.symbol, "AAPL")
        XCTAssertEqual(result?.timestamp?.count, 2)

        let chartData = result!.toChartData()
        XCTAssertEqual(chartData.symbol, "AAPL")
        XCTAssertEqual(chartData.points.count, 2)
        XCTAssertEqual(chartData.points[0].open, 150.0)
        XCTAssertEqual(chartData.previousClose, 150.0)
    }

    func testDecodeSearchResponse() async throws {
        MockURLProtocol.setResponse(for: "search", json: Fixtures.searchJSON)

        let response = try await client.fetch(
            SearchResponse.self,
            from: .search(query: "Apple", count: 10)
        )

        XCTAssertEqual(response.quotes?.count, 2)
        XCTAssertEqual(response.quotes?.first?.symbol, "AAPL")
        XCTAssertEqual(response.quotes?.first?.name, "Apple Inc.")
        XCTAssertEqual(response.quotes?.first?.exchange, "NASDAQ")
    }

    func testDecodeQuoteSummaryResponse() async throws {
        MockURLProtocol.setResponse(for: "quoteSummary", json: Fixtures.quoteSummaryJSON)

        let response = try await client.fetch(
            QuoteSummaryResponse.self,
            from: .quoteSummary(symbol: "AAPL")
        )

        let quote = response.quoteSummary.result?.first?.toQuote()
        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.symbol, "AAPL")
        XCTAssertEqual(quote?.regularMarketPrice, 178.72)
        XCTAssertEqual(quote?.bid, 178.70)
        XCTAssertEqual(quote?.fiftyTwoWeekHigh, 199.62)
    }

    func testHTTP429ThrowsRateLimited() async {
        MockURLProtocol.setResponse(for: "chart", statusCode: 429)

        do {
            _ = try await client.fetch(
                ChartResponse.self,
                from: .chart(symbol: "AAPL", interval: .oneDay, from: nil, to: nil)
            )
            XCTFail("Expected rateLimited error")
        } catch {
            guard case YahooFinanceError.rateLimited = error else {
                XCTFail("Expected rateLimited, got \(error)")
                return
            }
        }
    }

    func testHTTP404ThrowsSymbolNotFound() async {
        MockURLProtocol.setResponse(for: "chart", statusCode: 404)

        do {
            _ = try await client.fetch(
                ChartResponse.self,
                from: .chart(symbol: "INVALID", interval: .oneDay, from: nil, to: nil)
            )
            XCTFail("Expected symbolNotFound error")
        } catch {
            guard case YahooFinanceError.symbolNotFound = error else {
                XCTFail("Expected symbolNotFound, got \(error)")
                return
            }
        }
    }

    func testInvalidJSONThrowsDecodingError() async {
        MockURLProtocol.setResponse(for: "chart", json: "{ invalid json }")

        do {
            _ = try await client.fetch(
                ChartResponse.self,
                from: .chart(symbol: "AAPL", interval: .oneDay, from: nil, to: nil)
            )
            XCTFail("Expected decodingError")
        } catch {
            guard case YahooFinanceError.decodingError = error else {
                XCTFail("Expected decodingError, got \(error)")
                return
            }
        }
    }
}
