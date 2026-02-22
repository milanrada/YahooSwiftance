import Foundation

/// An `AsyncSequence` of `StreamQuote` values from a Yahoo Finance WebSocket.
///
/// Use `.throttle(_:)` to limit how often quotes are emitted per symbol.
///
/// ```swift
/// for try await quote in await yahoo.stream(symbols: ["AAPL"]).throttle(.everySecond) {
///     print(quote.price)
/// }
/// ```
public struct QuoteSequence: QuoteAsyncSequence {
    public typealias Element = StreamQuote

    private let base: AsyncThrowingStream<StreamQuote, Error>

    init(base: AsyncThrowingStream<StreamQuote, Error>) {
        self.base = base
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: AsyncThrowingStream<StreamQuote, Error>.AsyncIterator

        init(base: AsyncThrowingStream<StreamQuote, Error>.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> StreamQuote? {
            try await base.next()
        }
    }
}
