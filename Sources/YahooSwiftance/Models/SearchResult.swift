import Foundation

/// A search result from the Yahoo Finance search API.
public struct SearchResult: Sendable, Equatable, Codable {
    public let symbol: String
    public let name: String?
    public let type: String?
    public let exchange: String?
    public let sector: String?
    public let industry: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case name = "shortname"
        case type = "quoteType"
        case exchange = "exchDisp"
        case sector
        case industry
    }
}

// MARK: - Internal Codable Wrapper

struct SearchResponse: Codable {
    let quotes: [SearchResult]?
}
