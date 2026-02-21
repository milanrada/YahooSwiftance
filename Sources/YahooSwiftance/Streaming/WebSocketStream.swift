import Foundation

/// Bridges `URLSessionWebSocketTask` to `AsyncThrowingStream<StreamQuote, Error>`.
enum WebSocketStream {
    /// Creates an `AsyncThrowingStream` that receives and decodes WebSocket messages.
    static func quotes(
        from task: URLSessionWebSocketTask
    ) -> AsyncThrowingStream<StreamQuote, Error> {
        AsyncThrowingStream { continuation in
            let receiver = WebSocketReceiver(task: task, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                task.cancel(with: .goingAway, reason: nil)
            }
            task.resume()
            Task { await receiver.startReceiving() }
        }
    }
}

/// Manages the recursive receive loop for a WebSocket task.
private actor WebSocketReceiver {
    let task: URLSessionWebSocketTask
    let continuation: AsyncThrowingStream<StreamQuote, Error>.Continuation

    init(task: URLSessionWebSocketTask, continuation: AsyncThrowingStream<StreamQuote, Error>.Continuation) {
        self.task = task
        self.continuation = continuation
    }

    func startReceiving() async {
        while task.state == .running {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    // Base64-encoded protobuf message
                    do {
                        let quote = try ProtobufDecoder.decode(base64String: text)
                        continuation.yield(quote)
                    } catch {
                        // Skip bad individual messages — don't kill the stream
                        continue
                    }
                case .data(let data):
                    // Raw protobuf data
                    do {
                        let quote = try ProtobufDecoder.decode(data: data)
                        continuation.yield(quote)
                    } catch {
                        continue
                    }
                @unknown default:
                    continue
                }
            } catch {
                continuation.finish(throwing: YahooFinanceError.webSocketDisconnected)
                return
            }
        }
        continuation.finish()
    }
}
