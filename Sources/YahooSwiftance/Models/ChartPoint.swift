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
