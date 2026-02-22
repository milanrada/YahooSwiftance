import Foundation

/// An `AsyncSequence` that suppresses quotes whose price hasn't moved enough
/// from the last emitted price for that symbol.
///
/// The first quote for each symbol always passes through. Subsequent quotes
/// are only emitted when the price difference from the last emitted quote
/// exceeds the configured `PriceThreshold`.
public struct PriceFilteredQuoteSequence<Base: QuoteAsyncSequence>: QuoteAsyncSequence {
    public typealias Element = StreamQuote

    private let base: Base
    private let threshold: PriceThreshold

    init(base: Base, threshold: PriceThreshold) {
        self.base = base
        self.threshold = threshold
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            base: base.makeAsyncIterator(),
            threshold: threshold
        )
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private let threshold: PriceThreshold
        private var lastEmittedPrice: [String: Double] = [:]

        init(base: Base.AsyncIterator, threshold: PriceThreshold) {
            self.base = base
            self.threshold = threshold
        }

        public mutating func next() async throws -> StreamQuote? {
            while let quote = try await base.next() {
                guard let previous = lastEmittedPrice[quote.symbol] else {
                    // First quote for this symbol — always emit
                    lastEmittedPrice[quote.symbol] = quote.price
                    return quote
                }

                if threshold.isExceeded(previous: previous, current: quote.price) {
                    lastEmittedPrice[quote.symbol] = quote.price
                    return quote
                }
                // Price hasn't moved enough — skip
            }

            return nil
        }
    }
}
