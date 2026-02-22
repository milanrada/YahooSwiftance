import Foundation

/// A protocol for `AsyncSequence` types that emit `StreamQuote` elements.
///
/// Conforming types automatically gain chainable operators like `.throttle(_:)`.
public protocol QuoteAsyncSequence: AsyncSequence, Sendable where Element == StreamQuote {}

extension QuoteAsyncSequence {
    /// Returns a throttled sequence that emits at most one quote per symbol
    /// within the given frequency window.
    ///
    /// Operators are chainable — e.g., `.throttle(.everySecond).throttle(.everyFiveSeconds)`.
    ///
    /// - Parameter frequency: The minimum interval between emitted quotes per symbol.
    /// - Returns: A `ThrottledQuoteSequence` that drops quotes arriving too quickly.
    public func throttle(_ frequency: StreamFrequency) -> ThrottledQuoteSequence<Self> {
        ThrottledQuoteSequence(base: self, frequency: frequency)
    }

    /// Returns a filtered sequence that only emits quotes whose price has moved
    /// enough from the last emitted price for that symbol.
    ///
    /// The first quote per symbol always passes through. Subsequent quotes are
    /// skipped unless the price difference exceeds the given threshold.
    ///
    /// ```swift
    /// // Only emit when price moves by at least $0.50
    /// stream.filter(minimumChange: .absolute(0.50))
    ///
    /// // Only emit when price moves by at least 1%
    /// stream.filter(minimumChange: .percent(1.0))
    /// ```
    ///
    /// - Parameter threshold: The minimum price movement required to emit a quote.
    /// - Returns: A `PriceFilteredQuoteSequence` that suppresses minor price changes.
    public func filter(minimumChange threshold: PriceThreshold) -> PriceFilteredQuoteSequence<Self> {
        PriceFilteredQuoteSequence(base: self, threshold: threshold)
    }
}
