import Foundation

struct PriceModule: Codable {
    let symbol: String?
    let shortName: String?
    let longName: String?
    let currency: String?
    let exchange: String?
    let quoteType: String?
    let regularMarketPrice: YahooValue?
    let regularMarketChange: YahooValue?
    let regularMarketChangePercent: YahooValue?
    let regularMarketVolume: YahooValue?
    let regularMarketDayHigh: YahooValue?
    let regularMarketDayLow: YahooValue?
    let regularMarketOpen: YahooValue?
    let regularMarketPreviousClose: YahooValue?
    let marketCap: YahooValue?
}
