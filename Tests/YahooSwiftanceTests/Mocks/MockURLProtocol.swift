import Foundation

/// A URLProtocol subclass for injecting mock responses in tests.
final class MockURLProtocol: URLProtocol {
    /// Map of URL path → (data, response, error) to return.
    nonisolated(unsafe) static var mockResponses: [String: (Data?, URLResponse?, Error?)] = [:]

    /// Convenience to set a JSON response for a given URL path.
    static func setResponse(
        for pathContaining: String,
        statusCode: Int = 200,
        json: String
    ) {
        let data = json.data(using: .utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockResponses[pathContaining] = (data, response, nil)
    }

    static func setResponse(
        for pathContaining: String,
        statusCode: Int,
        data: Data? = nil
    ) {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockResponses[pathContaining] = (data, response, nil)
    }

    static func reset() {
        mockResponses.removeAll()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let urlString = request.url?.absoluteString ?? ""

        var matched: (Data?, URLResponse?, Error?)?
        for (pathKey, response) in MockURLProtocol.mockResponses {
            if urlString.contains(pathKey) {
                matched = response
                break
            }
        }

        if let (data, response, error) = matched {
            if let response = response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let error = error {
                client?.urlProtocol(self, didFailWithError: error)
            }
        } else {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    /// Create a URLSession that routes through MockURLProtocol.
    static func mock() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
