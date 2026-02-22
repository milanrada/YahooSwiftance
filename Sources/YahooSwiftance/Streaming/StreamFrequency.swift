import Foundation

/// Controls how often quotes are emitted from the stream on a per-symbol basis.
///
/// Yahoo Finance's WebSocket can send multiple updates per second per symbol.
/// Use `StreamFrequency` to throttle the output so consumers aren't overwhelmed.
///
/// ```swift
/// // Only receive one update per symbol per second
/// for try await quote in await yahoo.stream(symbols: ["AAPL"], frequency: .everySecond) {
///     print(quote.price)
/// }
/// ```
public enum StreamFrequency: Sendable {
    /// No throttle — every quote is emitted as it arrives.
    case realtime
    /// Throttle to at most one quote per `ms` milliseconds per symbol.
    case millis(Int)
    /// Throttle to at most one quote per `s` seconds per symbol.
    case seconds(Double)
    /// Convenience for `.seconds(1)`.
    case everySecond
    /// Convenience for `.seconds(5)`.
    case everyFiveSeconds

    /// The minimum interval between emitted quotes for a given symbol,
    /// or `nil` for `.realtime` (no throttle).
    var interval: TimeInterval? {
        switch self {
        case .realtime: return nil
        case .millis(let ms): return TimeInterval(ms) / 1000.0
        case .seconds(let s): return s
        case .everySecond: return 1.0
        case .everyFiveSeconds: return 5.0
        }
    }
}
