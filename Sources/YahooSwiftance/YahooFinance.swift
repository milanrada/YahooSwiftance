import Foundation
import Synchronization

/// The current semantic version of the YahooSwiftance library.
public let version = "0.6.0"

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
    private let validSymbolCache = Mutex<Set<String>>([])

    /// Creates a new `YahooFinance` instance.
    ///
    /// - Parameter session: The `URLSession` to use for networking.
    ///   Defaults to a session with cookie storage enabled for Yahoo Finance authentication.
    public init(session: URLSession? = nil) {
        let resolvedSession: URLSession
        if let session {
            resolvedSession = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieAcceptPolicy = .always
            resolvedSession = URLSession(configuration: config)
        }

        let crumbManager = CrumbManager(session: resolvedSession)
        self.httpClient = HTTPClient(session: resolvedSession, crumbManager: crumbManager)
        self.streamer = StockStreamer(session: resolvedSession)
    }

    // MARK: - Streaming

    /// Stream real-time quotes for the given symbols via WebSocket.
    ///
    /// Each symbol is validated against the Yahoo Finance API before the WebSocket
    /// connection is opened. Invalid symbols are reported via ``ValidatedStream/invalidSymbols``
    /// rather than silently producing no quotes.
    ///
    /// - If **all** symbols are invalid, throws ``YahooFinanceError/invalidSymbols(_:)``.
    /// - If **some** are invalid, streams the valid ones and populates `invalidSymbols`.
    /// - If **all** are valid, `invalidSymbols` is empty.
    ///
    /// ```swift
    /// let stream = try await yahoo.stream(symbols: ["AAPL", "AAZN", "GOOGL"])
    /// if !stream.invalidSymbols.isEmpty {
    ///     print("Warning: \(stream.invalidSymbols) not found")
    /// }
    /// for try await quote in stream.throttle(.everySecond) { ... }
    /// ```
    ///
    /// - Parameter symbols: Ticker symbols to stream (e.g., `["AAPL", "GOOGL"]`).
    /// - Returns: A ``ValidatedStream`` that yields `StreamQuote` values.
    public func stream(symbols: [String]) async throws -> ValidatedStream {
        let (valid, invalid) = await validateSymbols(symbols)

        guard !valid.isEmpty else {
            throw YahooFinanceError.invalidSymbols(invalid)
        }

        let sequence = try await streamer.stream(symbols: valid)
        return ValidatedStream(base: sequence, invalidSymbols: invalid)
    }

    /// Subscribe to additional symbols on the existing WebSocket connection.
    ///
    /// Each symbol is validated before being sent to the WebSocket.
    /// Already-validated symbols are served from an in-memory cache.
    ///
    /// - Parameter symbols: Ticker symbols to subscribe to.
    /// - Returns: Symbols that could not be found on Yahoo Finance. Empty when all are valid.
    /// - Throws: ``YahooFinanceError/invalidSymbols(_:)`` if **all** symbols are invalid.
    @discardableResult
    public func subscribe(symbols: [String]) async throws -> [String] {
        let (valid, invalid) = await validateSymbols(symbols)

        guard !valid.isEmpty else {
            throw YahooFinanceError.invalidSymbols(invalid)
        }

        await streamer.subscribe(symbols: valid)
        return invalid
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

    // MARK: - Validation

    private func validateSymbols(_ symbols: [String]) async -> (valid: [String], invalid: [String]) {
        let cached = validSymbolCache.withLock { $0 }
        let unchecked = symbols.filter { !cached.contains($0) }

        var valid = symbols.filter { cached.contains($0) }
        var invalid: [String] = []

        if !unchecked.isEmpty {
            await withTaskGroup(of: (String, Bool).self) { group in
                for symbol in unchecked {
                    group.addTask {
                        do {
                            _ = try await self.quote(for: symbol)
                            return (symbol, true)
                        } catch {
                            return (symbol, false)
                        }
                    }
                }

                for await (symbol, isValid) in group {
                    if isValid { valid.append(symbol) }
                    else { invalid.append(symbol) }
                }
            }

            if !valid.isEmpty {
                validSymbolCache.withLock { $0.formUnion(valid) }
            }
        }

        return (valid, invalid)
    }
}
