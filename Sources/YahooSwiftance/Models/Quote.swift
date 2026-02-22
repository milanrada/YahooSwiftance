import Foundation

/// A quote snapshot from the Yahoo Finance REST API.
public struct Quote: Sendable, Equatable, Codable {
    public let symbol: String
    public let shortName: String?
    public let longName: String?
    public let currency: String?
    public let exchange: String?
    public let quoteType: String?
    public let regularMarketPrice: Double?
    public let regularMarketChange: Double?
    public let regularMarketChangePercent: Double?
    public let regularMarketVolume: Int64?
    public let regularMarketDayHigh: Double?
    public let regularMarketDayLow: Double?
    public let regularMarketOpen: Double?
    public let regularMarketPreviousClose: Double?
    public let bid: Double?
    public let ask: Double?
    public let bidSize: Int64?
    public let askSize: Int64?
    public let marketCap: Int64?
    public let fiftyTwoWeekHigh: Double?
    public let fiftyTwoWeekLow: Double?
    public let fiftyDayAverage: Double?
    public let twoHundredDayAverage: Double?
    public let trailingPE: Double?
    public let forwardPE: Double?
    public let dividendYield: Double?
}
