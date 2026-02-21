import Foundation
import YahooSwiftance

func formatNumber(_ n: Int64) -> String {
    switch abs(n) {
    case 1_000_000_000...:
        return String(format: "%.2fB", Double(n) / 1_000_000_000)
    case 1_000_000...:
        return String(format: "%.2fM", Double(n) / 1_000_000)
    case 1_000...:
        return String(format: "%.1fK", Double(n) / 1_000)
    default:
        return "\(n)"
    }
}

let yahoo = YahooFinance()
let symbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA"]

print("Streaming real-time quotes for: \(symbols.joined(separator: ", "))")
print("Press Ctrl+C to stop.\n")

for try await quote in await yahoo.stream(symbols: symbols) {
    let change = quote.changePercent.map { String(format: "%+.2f%%", $0) } ?? "N/A"
    let volume = quote.dayVolume.map { formatNumber($0) } ?? "N/A"
    let hours = quote.marketHours?.rawValue ?? "—"

    print("[\(hours)] \(quote.symbol): $\(String(format: "%.2f", quote.price))  \(change)  vol: \(volume)")
}
