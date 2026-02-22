import Foundation

// MARK: - Internal Codable Wrappers for Chart API

struct ChartResponse: Codable {
    let chart: ChartResultContainer
}

struct ChartResultContainer: Codable {
    let result: [ChartResult]?
    let error: ChartError?
}

struct ChartError: Codable {
    let code: String?
    let description: String?
}

struct ChartResult: Codable {
    let meta: ChartMeta?
    let timestamp: [Int]?
    let indicators: ChartIndicators?
}

struct ChartMeta: Codable {
    let currency: String?
    let symbol: String?
    let dataGranularity: String?
    let previousClose: Double?
    let chartPreviousClose: Double?
}

struct ChartIndicators: Codable {
    let quote: [ChartQuoteIndicator]?
    let adjclose: [ChartAdjCloseIndicator]?
}

struct ChartQuoteIndicator: Codable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Int64?]?
}

struct ChartAdjCloseIndicator: Codable {
    let adjclose: [Double?]?
}

extension ChartResult {
    func toChartData() -> ChartData {
        let symbol = meta?.symbol ?? ""
        let quote = indicators?.quote?.first
        let adjclose = indicators?.adjclose?.first?.adjclose

        let points: [ChartPoint] = (timestamp ?? []).enumerated().compactMap { index, ts in
            ChartPoint(
                date: Date(timeIntervalSince1970: TimeInterval(ts)),
                open: quote?.open?[safe: index] ?? nil,
                high: quote?.high?[safe: index] ?? nil,
                low: quote?.low?[safe: index] ?? nil,
                close: quote?.close?[safe: index] ?? nil,
                volume: quote?.volume?[safe: index] ?? nil,
                adjustedClose: adjclose?[safe: index] ?? nil
            )
        }

        return ChartData(
            symbol: symbol,
            currency: meta?.currency,
            interval: meta?.dataGranularity,
            points: points,
            previousClose: meta?.previousClose ?? meta?.chartPreviousClose
        )
    }
}
