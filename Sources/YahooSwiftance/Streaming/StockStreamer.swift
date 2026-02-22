import Foundation

/// Actor managing the Yahoo Finance WebSocket streaming lifecycle.
public actor StockStreamer {
    private let session: URLSession
    private let webSocketURL = URL(string: "wss://streamer.finance.yahoo.com/")!

    private var webSocketTask: URLSessionWebSocketTask?
    private var subscribedSymbols: Set<String> = []
    private var heartbeatTask: Task<Void, Never>?
    private var isConnected: Bool { webSocketTask?.state == .running }

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Stream real-time quotes for the given symbols.
    ///
    /// Returns a `QuoteSequence` that yields `StreamQuote` values as they arrive.
    /// The stream is terminated when `disconnect()` is called or the WebSocket drops.
    ///
    /// Use `.throttle(_:)` on the returned sequence to control emission rate:
    /// ```swift
    /// for try await quote in streamer.stream(symbols: ["AAPL"]).throttle(.everySecond) { ... }
    /// ```
    ///
    /// - Parameter symbols: Ticker symbols to stream (e.g., `["AAPL", "GOOGL"]`).
    public func stream(symbols: [String]) throws -> QuoteSequence {
        // Tear down any existing connection before opening a new one
        disconnect()

        let task = createWebSocketTask()
        self.webSocketTask = task

        let quoteStream = WebSocketStream.quotes(from: task)

        // Subscribe after the task is resumed (handled inside WebSocketStream)
        Task { [weak self] in
            guard let self else { return }
            await self.sendSubscribe(symbols: symbols)
            await self.startHeartbeat()
        }

        return try QuoteSequence(base: quoteStream)
    }

    /// Subscribe to additional symbols on the existing connection.
    public func subscribe(symbols: [String]) async {
        let newSymbols = symbols.filter { !subscribedSymbols.contains($0) }
        guard !newSymbols.isEmpty else { return }
        await sendSubscribe(symbols: newSymbols)
    }

    /// Unsubscribe from symbols on the existing connection.
    public func unsubscribe(symbols: [String]) async {
        let toRemove = symbols.filter { subscribedSymbols.contains($0) }
        guard !toRemove.isEmpty else { return }
        subscribedSymbols.subtract(toRemove)
        await sendUnsubscribe(symbols: toRemove)
    }

    /// Disconnect the WebSocket and stop streaming.
    public func disconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        subscribedSymbols.removeAll()
    }

    // MARK: - Internal

    private func createWebSocketTask() -> URLSessionWebSocketTask {
        var request = URLRequest(url: webSocketURL)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        return session.webSocketTask(with: request)
    }

    private func sendSubscribe(symbols: [String]) async {
        subscribedSymbols.formUnion(symbols)
        let message: [String: [String]] = ["subscribe": symbols]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await webSocketTask?.send(.string(json))
    }

    private func sendUnsubscribe(symbols: [String]) async {
        let message: [String: [String]] = ["unsubscribe": symbols]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await webSocketTask?.send(.string(json))
    }

    private func sendKeepAlive() async {
        guard !subscribedSymbols.isEmpty else { return }
        let message: [String: [String]] = ["subscribe": Array(subscribedSymbols)]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else { return }
        try? await webSocketTask?.send(.string(json))
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await self.sendKeepAlive()
            }
        }
    }
}
