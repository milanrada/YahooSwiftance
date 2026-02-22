import Foundation

/// Historical chart data for a symbol.
public struct ChartData: Sendable, Equatable {
    public let symbol: String
    public let currency: String?
    public let interval: String?
    public let points: [ChartPoint]
    public let previousClose: Double?
}
