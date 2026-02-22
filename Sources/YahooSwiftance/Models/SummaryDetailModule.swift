import Foundation

struct SummaryDetailModule: Codable {
    let bid: YahooValue?
    let ask: YahooValue?
    let bidSize: YahooValue?
    let askSize: YahooValue?
    let fiftyTwoWeekHigh: YahooValue?
    let fiftyTwoWeekLow: YahooValue?
    let fiftyDayAverage: YahooValue?
    let twoHundredDayAverage: YahooValue?
    let trailingPE: YahooValue?
    let forwardPE: YahooValue?
    let dividendYield: YahooValue?
}
