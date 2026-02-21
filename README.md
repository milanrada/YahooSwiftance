# YahooSwiftance

A Swift Package for streaming real-time Yahoo Finance stock data and accessing REST market data endpoints.

## Features

- **Real-time WebSocket streaming** — live quotes via `AsyncThrowingStream`
- **REST API** — quote snapshots, symbol search, historical chart data
- **Zero dependencies** — hand-rolled protobuf decoder for Yahoo's streaming format
- **Modern Swift concurrency** — async/await, actors, structured concurrency
- **Lightweight** — minimal surface area, easy to integrate

## Requirements

- iOS 16+ / macOS 13+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/YahooSwiftance.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Quick Start

### Stream Real-Time Quotes

```swift
import YahooSwiftance

let yahoo = YahooFinance()

for try await quote in await yahoo.stream(symbols: ["AAPL", "GOOGL", "MSFT"]) {
    print("\(quote.symbol): $\(quote.price) (\(quote.changePercent ?? 0)%)")
}
```

### Fetch a Quote Snapshot

```swift
let quote = try await yahoo.quote(for: "AAPL")
print("\(quote.symbol): $\(quote.regularMarketPrice ?? 0)")
```

### Search Symbols

```swift
let results = try await yahoo.search(query: "Apple")
for result in results {
    print("\(result.symbol) — \(result.name ?? "")")
}
```

### Historical Chart Data

```swift
let chart = try await yahoo.chart(
    symbol: "AAPL",
    interval: .oneDay,
    from: Date.now.addingTimeInterval(-30 * 86400)
)
for point in chart.points {
    print("\(point.date): O=\(point.open ?? 0) H=\(point.high ?? 0) L=\(point.low ?? 0) C=\(point.close ?? 0)")
}
```

## API Overview

### `YahooFinance`

| Method | Description |
|--------|-------------|
| `stream(symbols:)` | Stream real-time quotes via WebSocket |
| `subscribe(symbols:)` | Add symbols to an active stream |
| `unsubscribe(symbols:)` | Remove symbols from an active stream |
| `disconnect()` | Close the WebSocket connection |
| `quote(for:)` | Fetch a REST quote snapshot |
| `search(query:count:)` | Search for symbols |
| `chart(symbol:interval:from:to:)` | Fetch historical chart data |

### Models

| Type | Description |
|------|-------------|
| `StreamQuote` | Real-time quote from WebSocket (symbol, price, timestamp, change, volume, etc.) |
| `Quote` | REST quote snapshot with full market data |
| `SearchResult` | Symbol search result (symbol, name, type, exchange) |
| `ChartData` | Historical data with array of `ChartPoint` values |
| `Interval` | Chart time intervals (1m, 5m, 1h, 1d, 1wk, 1mo, etc.) |

## License

MIT — see [LICENSE](LICENSE) for details.
