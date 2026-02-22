import Foundation

// MARK: - Internal Codable Wrappers for Quote Summary API

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
