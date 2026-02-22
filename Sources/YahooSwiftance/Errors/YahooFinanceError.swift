import Foundation

/// All errors thrown by the YahooSwiftance library.
public enum YahooFinanceError: Error, Sendable, LocalizedError {
    case httpError(statusCode: Int, data: Data?)
    case rateLimited
    case decodingError(underlying: Error)
    case protobufDecodingError(String)
    case webSocketError(underlying: Error)
    case webSocketDisconnected
    case symbolNotFound(String)
    case cancelled
    case invalidSymbols([String])
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)"
        case .rateLimited:
            return "Rate limited by Yahoo Finance API"
        case .decodingError(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        case .protobufDecodingError(let message):
            return "Protobuf decoding error: \(message)"
        case .webSocketError(let underlying):
            return "WebSocket error: \(underlying.localizedDescription)"
        case .webSocketDisconnected:
            return "WebSocket disconnected"
        case .symbolNotFound(let symbol):
            return "Symbol not found: \(symbol)"
        case .invalidSymbols(let symbols):
            return "Invalid symbols: \(symbols.joined(separator: ", "))"
        case .cancelled:
            return "Operation was cancelled"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
