import Foundation

/// URL construction for Yahoo Finance REST API endpoints.
enum Endpoint {
    case chart(symbol: String, interval: Interval, from: Date?, to: Date?)
    case search(query: String, count: Int)
    case quoteSummary(symbol: String)

    var url: URL {
        switch self {
        case .chart(let symbol, let interval, let from, let to):
            var components = URLComponents(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(symbol)")!
            var items = [
                URLQueryItem(name: "interval", value: interval.rawValue),
                URLQueryItem(name: "includePrePost", value: "true"),
                URLQueryItem(name: "events", value: "history")
            ]
            if let from = from {
                items.append(URLQueryItem(name: "period1", value: String(Int(from.timeIntervalSince1970))))
            }
            if let to = to {
                items.append(URLQueryItem(name: "period2", value: String(Int(to.timeIntervalSince1970))))
            }
            components.queryItems = items
            return components.url!

        case .search(let query, let count):
            var components = URLComponents(string: "https://query2.finance.yahoo.com/v1/finance/search")!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "quotesCount", value: String(count)),
                URLQueryItem(name: "newsCount", value: "0"),
                URLQueryItem(name: "listsCount", value: "0"),
                URLQueryItem(name: "enableFuzzyQuery", value: "false")
            ]
            return components.url!

        case .quoteSummary(let symbol):
            var components = URLComponents(string: "https://query1.finance.yahoo.com/v11/finance/quoteSummary/\(symbol)")!
            components.queryItems = [
                URLQueryItem(name: "modules", value: "price,summaryDetail")
            ]
            return components.url!
        }
    }
}
