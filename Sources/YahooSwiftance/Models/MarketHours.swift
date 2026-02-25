import Foundation

/// Market hours state for a streaming quote.
public enum MarketHours: String, Sendable {
    case preMarket = "PRE"
    case regularMarket = "REGULAR"
    case postMarket = "POST"
    case closed = "CLOSED"

    /// Initialize from the protobuf varint enum value used in Yahoo's WebSocket messages.
    init?(protobufValue: UInt64) {
        switch protobufValue {
        case 8:  self = .preMarket
        case 0:  self = .regularMarket
        case 12: self = .postMarket
        case 16: self = .closed
        default: return nil
        }
    }
}
