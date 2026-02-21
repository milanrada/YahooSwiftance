import Foundation

/// The current semantic version of the YahooSwiftance library.
public let version = "0.1.0"

/// The main entry point for the YahooSwiftance library.
///
/// Provides both real-time WebSocket streaming and REST API access to Yahoo Finance data.
///
/// ```swift
/// let yahoo = YahooFinance()
///
/// // Stream real-time quotes
/// for try await quote in yahoo.stream(symbols: ["AAPL", "GOOGL"]) {
///     print("\(quote.symbol): $\(quote.price)")
/// }
///
/// // Fetch a single quote
/// let quote = try await yahoo.quote(for: "AAPL")
/// ```
public final class YahooFinance: Sendable {
    private let httpClient: HTTPClient
    private let streamer: StockStreamer

    /// Creates a new `YahooFinance` instance.
    ///
    /// - Parameter session: The `URLSession` to use for networking. Defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.httpClient = HTTPClient(session: session)
        self.streamer = StockStreamer(session: session)
    }

    // MARK: - Streaming

    /// Stream real-time quotes for the given symbols via WebSocket.
    ///
    /// - Parameter symbols: Ticker symbols to stream (e.g., `["AAPL", "GOOGL"]`).
    /// - Returns: An `AsyncThrowingStream` that yields `StreamQuote` values.
    public func stream(symbols: [String]) async -> AsyncThrowingStream<StreamQuote, Error> {
        await streamer.stream(symbols: symbols)
    }

    /// Subscribe to additional symbols on the existing WebSocket connection.
    public func subscribe(symbols: [String]) async {
        await streamer.subscribe(symbols: symbols)
    }

    /// Unsubscribe from symbols on the existing WebSocket connection.
    public func unsubscribe(symbols: [String]) async {
        await streamer.unsubscribe(symbols: symbols)
    }

    /// Disconnect the WebSocket and stop all streaming.
    public func disconnect() async {
        await streamer.disconnect()
    }

    // MARK: - REST API

    /// Fetch a quote snapshot for a symbol.
    ///
    /// - Parameter symbol: Ticker symbol (e.g., `"AAPL"`).
    /// - Returns: A `Quote` with current market data.
    public func quote(for symbol: String) async throws -> Quote {
        let response = try await httpClient.fetch(
            QuoteSummaryResponse.self,
            from: .quoteSummary(symbol: symbol)
        )

        if let error = response.quoteSummary.error {
            throw YahooFinanceError.symbolNotFound(error.description ?? symbol)
        }

        guard let module = response.quoteSummary.result?.first,
              let quote = module.toQuote() else {
            throw YahooFinanceError.symbolNotFound(symbol)
        }

        return quote
    }

    /// Search for symbols matching a query.
    ///
    /// - Parameters:
    ///   - query: Search text (e.g., `"Apple"`).
    ///   - count: Maximum number of results. Defaults to 10.
    /// - Returns: An array of `SearchResult` values.
    public func search(query: String, count: Int = 10) async throws -> [SearchResult] {
        let response = try await httpClient.fetch(
            SearchResponse.self,
            from: .search(query: query, count: count)
        )
        return response.quotes ?? []
    }

    /// Fetch historical chart data for a symbol.
    ///
    /// - Parameters:
    ///   - symbol: Ticker symbol (e.g., `"AAPL"`).
    ///   - interval: The time interval between data points. Defaults to `.oneDay`.
    ///   - from: Start date. Defaults to `nil` (Yahoo decides).
    ///   - to: End date. Defaults to `nil` (now).
    /// - Returns: A `ChartData` value with historical price points.
    public func chart(
        symbol: String,
        interval: Interval = .oneDay,
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> ChartData {
        let response = try await httpClient.fetch(
            ChartResponse.self,
            from: .chart(symbol: symbol, interval: interval, from: from, to: to)
        )

        if let error = response.chart.error {
            throw YahooFinanceError.symbolNotFound(error.description ?? symbol)
        }

        guard let result = response.chart.result?.first else {
            throw YahooFinanceError.symbolNotFound(symbol)
        }

        return result.toChartData()
    }
}
