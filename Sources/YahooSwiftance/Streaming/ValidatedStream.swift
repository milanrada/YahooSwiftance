import Foundation

/// A validated stream of real-time quotes that also reports which symbols were invalid.
///
/// Created by ``YahooFinance/stream(symbols:)``, which validates each symbol before
/// opening the WebSocket. Conforms to ``QuoteAsyncSequence``, so you can chain
/// `.throttle()` and `.filter(minimumChange:)` exactly like a plain ``QuoteSequence``.
///
/// ```swift
/// let stream = try await yahoo.stream(symbols: ["AAPL", "AAZN", "GOOGL"])
/// if !stream.invalidSymbols.isEmpty {
///     print("Warning: \(stream.invalidSymbols) not found")
/// }
/// for try await quote in stream.throttle(.everySecond) {
///     print(quote.price)
/// }
/// ```
public struct ValidatedStream: QuoteAsyncSequence {
    public typealias Element = StreamQuote

    /// Symbols that could not be found on Yahoo Finance.
    public let invalidSymbols: [String]

    private let base: QuoteSequence

    init(base: QuoteSequence, invalidSymbols: [String]) {
        self.base = base
        self.invalidSymbols = invalidSymbols
    }

    public func makeAsyncIterator() -> QuoteSequence.AsyncIterator {
        base.makeAsyncIterator()
    }
}
