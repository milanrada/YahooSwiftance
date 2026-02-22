import Foundation

/// Yahoo wraps numeric values in `{"raw": 123.45, "fmt": "123.45"}`.
struct YahooValue: Codable {
    let raw: Double?
    let fmt: String?
}
