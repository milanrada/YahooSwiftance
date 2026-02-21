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

// MARK: - Internal Codable Wrappers

struct QuoteSummaryResponse: Codable {
    let quoteSummary: QuoteSummaryResult
}

struct QuoteSummaryResult: Codable {
    let result: [QuoteSummaryModule]?
    let error: QuoteSummaryError?
}

struct QuoteSummaryError: Codable {
    let code: String?
    let description: String?
}

struct QuoteSummaryModule: Codable {
    let price: PriceModule?
    let summaryDetail: SummaryDetailModule?
}

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

struct SummaryDetailModule: Codable {
    let bid: YahooValue?
    let ask: YahooValue?
    let bidSize: YahooValue?
    let askSize: YahooValue?
    let fiftyTwoWeekHigh: YahooValue?
    let fiftyTwoWeekLow: YahooValue?
    let fiftyDayAverage: YahooValue?
    let twoHundredDayAverage: YahooValue?
    let trailingPE: YahooValue?
    let forwardPE: YahooValue?
    let dividendYield: YahooValue?
}

/// Yahoo wraps numeric values in `{"raw": 123.45, "fmt": "123.45"}`.
struct YahooValue: Codable {
    let raw: Double?
    let fmt: String?
}

extension QuoteSummaryModule {
    func toQuote() -> Quote? {
        guard let price = price, let symbol = price.symbol else { return nil }
        return Quote(
            symbol: symbol,
            shortName: price.shortName,
            longName: price.longName,
            currency: price.currency,
            exchange: price.exchange,
            quoteType: price.quoteType,
            regularMarketPrice: price.regularMarketPrice?.raw,
            regularMarketChange: price.regularMarketChange?.raw,
            regularMarketChangePercent: price.regularMarketChangePercent?.raw,
            regularMarketVolume: price.regularMarketVolume?.raw.flatMap { Int64($0) },
            regularMarketDayHigh: price.regularMarketDayHigh?.raw,
            regularMarketDayLow: price.regularMarketDayLow?.raw,
            regularMarketOpen: price.regularMarketOpen?.raw,
            regularMarketPreviousClose: price.regularMarketPreviousClose?.raw,
            bid: summaryDetail?.bid?.raw,
            ask: summaryDetail?.ask?.raw,
            bidSize: summaryDetail?.bidSize?.raw.flatMap { Int64($0) },
            askSize: summaryDetail?.askSize?.raw.flatMap { Int64($0) },
            marketCap: price.marketCap?.raw.flatMap { Int64($0) },
            fiftyTwoWeekHigh: summaryDetail?.fiftyTwoWeekHigh?.raw,
            fiftyTwoWeekLow: summaryDetail?.fiftyTwoWeekLow?.raw,
            fiftyDayAverage: summaryDetail?.fiftyDayAverage?.raw,
            twoHundredDayAverage: summaryDetail?.twoHundredDayAverage?.raw,
            trailingPE: summaryDetail?.trailingPE?.raw,
            forwardPE: summaryDetail?.forwardPE?.raw,
            dividendYield: summaryDetail?.dividendYield?.raw
        )
    }
}
