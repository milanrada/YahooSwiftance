import Foundation

/// An `AsyncSequence` that wraps a `QuoteAsyncSequence` and throttles
/// emission on a per-symbol basis according to a `StreamFrequency`.
///
/// Quotes that arrive before the throttle window has elapsed for their symbol are dropped.
/// When the frequency is `.realtime`, all quotes pass through unmodified.
public struct ThrottledQuoteSequence<Base: QuoteAsyncSequence>: QuoteAsyncSequence {
    public typealias Element = StreamQuote

    private let base: Base
    private let frequency: StreamFrequency

    init(base: Base, frequency: StreamFrequency) {
        self.base = base
        self.frequency = frequency
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            base: base.makeAsyncIterator(),
            frequency: frequency
        )
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private let frequency: StreamFrequency
        private var lastEmitted: [String: Date] = [:]

        init(base: Base.AsyncIterator, frequency: StreamFrequency) {
            self.base = base
            self.frequency = frequency
        }

        public mutating func next() async throws -> StreamQuote? {
            guard let interval = frequency.interval else {
                // .realtime — pass through directly
                return try await base.next()
            }

            while let quote = try await base.next() {
                let now = Date()
                if let last = lastEmitted[quote.symbol],
                   now.timeIntervalSince(last) < interval {
                    continue // throttled — skip this quote
                }
                lastEmitted[quote.symbol] = now
                return quote
            }

            return nil
        }
    }
}
