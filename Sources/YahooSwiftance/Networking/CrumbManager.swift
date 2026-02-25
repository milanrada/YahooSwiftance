import Foundation

/// Manages Yahoo Finance cookie + crumb authentication.
///
/// Yahoo Finance requires a valid session cookie and crumb token on all REST API requests.
/// This actor handles the two-step authentication flow:
/// 1. Fetch session cookies from `fc.yahoo.com`
/// 2. Fetch the crumb token from the `getcrumb` endpoint using those cookies
///
/// Cookies are managed entirely by the URLSession's cookie storage — no manual Cookie
/// headers are set. This avoids conflicts with URLSession's automatic cookie handling.
///
/// Authentication is coalesced: if multiple callers request the crumb concurrently,
/// only one authentication flow runs; all callers await the same result.
actor CrumbManager {
    private let session: URLSession
    private var crumb: String?
    private var activeAuth: Task<String, Error>?

    init(session: URLSession) {
        self.session = session
    }

    /// Returns the cached crumb, authenticating first if needed.
    ///
    /// Concurrent callers share a single in-flight authentication to avoid
    /// cookie/crumb mismatches from overlapping auth flows.
    func getCrumb() async throws -> String {
        if let crumb {
            return crumb
        }

        // If an authentication is already in progress, piggyback on it.
        if let activeAuth {
            return try await activeAuth.value
        }

        let task = Task<String, Error> {
            try await self.performAuthentication()
        }
        activeAuth = task

        do {
            let result = try await task.value
            activeAuth = nil
            return result
        } catch {
            activeAuth = nil
            throw error
        }
    }

    /// Clears cached crumb so the next call re-authenticates.
    func invalidate() {
        crumb = nil
        activeAuth = nil
        // Clear cookies so a fresh session is established
        if let storage = session.configuration.httpCookieStorage {
            for cookie in storage.cookies ?? [] {
                storage.deleteCookie(cookie)
            }
        }
    }

    /// Two-step authentication flow:
    /// 1. GET fc.yahoo.com to obtain session cookies (stored automatically by URLSession)
    /// 2. GET getcrumb endpoint to obtain the crumb token (cookies sent automatically)
    private func performAuthentication() async throws -> String {
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"

        // Step 1: Fetch session cookies (URLSession stores them automatically)
        let cookieURL = URL(string: "https://fc.yahoo.com")!
        var cookieRequest = URLRequest(url: cookieURL)
        cookieRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (_, _) = try await session.data(for: cookieRequest)

        // Step 2: Fetch crumb (URLSession sends cookies automatically)
        let crumbURL = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
        var crumbRequest = URLRequest(url: crumbURL)
        crumbRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (crumbData, crumbResponse) = try await session.data(for: crumbRequest)

        guard let crumbHTTP = crumbResponse as? HTTPURLResponse,
              (200..<300).contains(crumbHTTP.statusCode) else {
            throw YahooFinanceError.unknown("Failed to fetch crumb")
        }

        guard let crumbValue = String(data: crumbData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !crumbValue.isEmpty else {
            throw YahooFinanceError.unknown("Empty crumb response")
        }

        self.crumb = crumbValue
        return crumbValue
    }
}
