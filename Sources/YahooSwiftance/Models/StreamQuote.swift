import Foundation

/// Market hours state for a streaming quote.
public enum MarketHours: String, Sendable {
    case preMarket = "PRE"
    case regularMarket = "REGULAR"
    case postMarket = "POST"
    case closed = "CLOSED"
}

/// A real-time streaming quote decoded from Yahoo Finance's WebSocket protobuf messages.
public struct StreamQuote: Sendable, Equatable {
    public let symbol: String
    public let price: Double
    public let timestamp: Date
    public let marketHours: MarketHours?
    public let currency: String?
    public let exchange: String?
    public let changePercent: Double?
    public let dayVolume: Int64?
    public let dayHigh: Double?
    public let dayLow: Double?
    public let change: Double?
    public let previousClose: Double?
    public let bid: Double?
    public let ask: Double?
    public let bidSize: Int64?
    public let askSize: Int64?
    public let marketCap: Int64?
    public let shortName: String?

    public init(
        symbol: String,
        price: Double,
        timestamp: Date,
        marketHours: MarketHours? = nil,
        currency: String? = nil,
        exchange: String? = nil,
        changePercent: Double? = nil,
        dayVolume: Int64? = nil,
        dayHigh: Double? = nil,
        dayLow: Double? = nil,
        change: Double? = nil,
        previousClose: Double? = nil,
        bid: Double? = nil,
        ask: Double? = nil,
        bidSize: Int64? = nil,
        askSize: Int64? = nil,
        marketCap: Int64? = nil,
        shortName: String? = nil
    ) {
        self.symbol = symbol
        self.price = price
        self.timestamp = timestamp
        self.marketHours = marketHours
        self.currency = currency
        self.exchange = exchange
        self.changePercent = changePercent
        self.dayVolume = dayVolume
        self.dayHigh = dayHigh
        self.dayLow = dayLow
        self.change = change
        self.previousClose = previousClose
        self.bid = bid
        self.ask = ask
        self.bidSize = bidSize
        self.askSize = askSize
        self.marketCap = marketCap
        self.shortName = shortName
    }
}
