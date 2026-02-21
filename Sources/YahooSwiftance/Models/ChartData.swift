import Foundation

/// A single data point in a historical chart.
public struct ChartPoint: Sendable, Equatable {
    public let date: Date
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let close: Double?
    public let volume: Int64?
    public let adjustedClose: Double?
}

/// Historical chart data for a symbol.
public struct ChartData: Sendable, Equatable {
    public let symbol: String
    public let currency: String?
    public let interval: String?
    public let points: [ChartPoint]
    public let previousClose: Double?
}

// MARK: - Internal Codable Wrappers

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

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
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
