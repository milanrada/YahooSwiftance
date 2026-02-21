import Foundation
import YahooSwiftance

let yahoo = YahooFinance()

// 1. Search for symbols
print("=== Symbol Search: \"Tesla\" ===\n")

let results = try await yahoo.search(query: "Tesla", count: 5)

for result in results {
    let exchange = result.exchange ?? "—"
    let type = result.type ?? "—"
    print("  \(result.symbol)  \(result.name ?? "")  [\(type), \(exchange)]")
}

// 2. Fetch a quote snapshot
print("\n=== Quote: AAPL ===\n")
let quote = try await yahoo.quote(for: "AAPL")
print("  Symbol:    \(quote.symbol)")
print("  Name:      \(quote.shortName ?? "—")")
print("  Price:     $\(quote.regularMarketPrice.map { String(format: "%.2f", $0) } ?? "—")")
print("  Change:    \(quote.regularMarketChange.map { String(format: "%+.2f", $0) } ?? "—")")
print("  Change %:  \(quote.regularMarketChangePercent.map { String(format: "%+.4f", $0) } ?? "—")")
print("  Volume:    \(quote.regularMarketVolume.map { "\($0)" } ?? "—")")
print("  Day High:  $\(quote.regularMarketDayHigh.map { String(format: "%.2f", $0) } ?? "—")")
print("  Day Low:   $\(quote.regularMarketDayLow.map { String(format: "%.2f", $0) } ?? "—")")
print("  52W High:  $\(quote.fiftyTwoWeekHigh.map { String(format: "%.2f", $0) } ?? "—")")
print("  52W Low:   $\(quote.fiftyTwoWeekLow.map { String(format: "%.2f", $0) } ?? "—")")

// 3. Fetch historical chart data (last 7 days, daily)
print("\n=== Chart: AAPL (7 days, daily) ===\n")
let sevenDaysAgo = Date.now.addingTimeInterval(-7 * 86400)
let chart = try await yahoo.chart(symbol: "AAPL", interval: .oneDay, from: sevenDaysAgo)

let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .short
dateFormatter.timeStyle = .none

print("  Date        Open      High      Low       Close     Volume")
print("  " + String(repeating: "—", count: 65))
for point in chart.points {
    let date = dateFormatter.string(from: point.date)
    let open = point.open.map { String(format: "%8.2f", $0) } ?? "     N/A"
    let high = point.high.map { String(format: "%8.2f", $0) } ?? "     N/A"
    let low = point.low.map { String(format: "%8.2f", $0) } ?? "     N/A"
    let close = point.close.map { String(format: "%8.2f", $0) } ?? "     N/A"
    let vol = point.volume.map { String(format: "%10d", $0) } ?? "       N/A"
    print("  \(date)  \(open)  \(high)  \(low)  \(close)  \(vol)")
}

print("\n  Previous Close: $\(chart.previousClose.map { String(format: "%.2f", $0) } ?? "—")")
print("  Currency:       \(chart.currency ?? "—")")
print("  Data Points:    \(chart.points.count)")

print("\nDone.")
