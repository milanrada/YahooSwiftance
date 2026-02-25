import Foundation

/// An actor wrapping URLSession with rate limiting for Yahoo Finance REST API calls.
actor HTTPClient {
    private let session: URLSession
    private let crumbManager: CrumbManager
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"

    // Token bucket rate limiter: ~2 requests/sec with burst up to 6.
    // Yahoo Finance's unofficial API enforces ~360 requests/hour (~6/min).
    // We allow short bursts but sustain well under that ceiling.
    private let maxTokens: Double = 6
    private let refillRate: Double = 2 // tokens per second
    private var tokens: Double = 6
    private var lastRefill: Date = Date()

    init(session: URLSession, crumbManager: CrumbManager) {
        self.session = session
        self.crumbManager = crumbManager
    }

    func fetch<T: Decodable>(_ type: T.Type, from endpoint: Endpoint) async throws -> T {
        try await waitForToken()

        let crumb = try await crumbManager.getCrumb()

        var request = URLRequest(url: endpoint.url(crumb: crumb))
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceError.unknown("Invalid response type")
        }

        // On auth-related errors, invalidate crumb and retry once
        if [401, 403, 404].contains(httpResponse.statusCode) {
            return try await retryWithFreshCrumb(type, endpoint: endpoint)
        }

        if httpResponse.statusCode == 429 {
            throw YahooFinanceError.rateLimited
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            throw YahooFinanceError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YahooFinanceError.decodingError(underlying: error)
        }
    }

    private func retryWithFreshCrumb<T: Decodable>(_ type: T.Type, endpoint: Endpoint) async throws -> T {
        await crumbManager.invalidate()

        let crumb = try await crumbManager.getCrumb()

        var request = URLRequest(url: endpoint.url(crumb: crumb))
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceError.unknown("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 404:
            throw YahooFinanceError.symbolNotFound(endpoint.url(crumb: crumb).path)
        case 429:
            throw YahooFinanceError.rateLimited
        default:
            throw YahooFinanceError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YahooFinanceError.decodingError(underlying: error)
        }
    }

    private func waitForToken() async throws {
        refillTokens()
        if tokens < 1 {
            let waitTime = (1 - tokens) / refillRate
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            refillTokens()
        }
        tokens -= 1
    }

    private func refillTokens() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        tokens = min(maxTokens, tokens + elapsed * refillRate)
        lastRefill = now
    }
}
