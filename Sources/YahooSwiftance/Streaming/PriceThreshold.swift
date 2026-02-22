import Foundation

/// Defines the minimum price movement required to emit a quote.
///
/// Used with `.filter(minimumChange:)` on any `QuoteAsyncSequence` to suppress
/// quotes that haven't moved enough from the last emitted price for that symbol.
///
/// ```swift
/// // Only emit when price moves by at least $0.50
/// stream.filter(minimumChange: .absolute(0.50))
///
/// // Only emit when price moves by at least 1%
/// stream.filter(minimumChange: .percent(1.0))
/// ```
public enum PriceThreshold: Sendable {
    /// Emit only when the absolute price difference exceeds the given amount.
    case absolute(Double)
    /// Emit only when the percentage price change exceeds the given value.
    /// For example, `.percent(0.5)` means a 0.5% move is required.
    case percent(Double)

    /// Returns `true` if the move from `previous` to `current` exceeds the threshold.
    func isExceeded(previous: Double, current: Double) -> Bool {
        switch self {
        case .absolute(let amount):
            return abs(current - previous) > amount
        case .percent(let pct):
            guard previous != 0 else { return true }
            return abs((current - previous) / previous) * 100 > pct
        }
    }
}
