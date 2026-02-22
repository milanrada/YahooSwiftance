import Foundation

/// Market hours state for a streaming quote.
public enum MarketHours: String, Sendable {
    case preMarket = "PRE"
    case regularMarket = "REGULAR"
    case postMarket = "POST"
    case closed = "CLOSED"
}
