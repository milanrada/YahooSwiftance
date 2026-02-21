import Foundation

/// Time intervals for historical chart data requests.
public enum Interval: String, Sendable, CaseIterable {
    case oneMinute = "1m"
    case twoMinutes = "2m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case sixtyMinutes = "60m"
    case oneHour = "1h"
    case oneDay = "1d"
    case fiveDay = "5d"
    case oneWeek = "1wk"
    case oneMonth = "1mo"
    case threeMonth = "3mo"
}
