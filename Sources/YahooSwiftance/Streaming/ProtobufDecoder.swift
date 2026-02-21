import Foundation

/// A minimal protobuf wire-format decoder for Yahoo Finance's streaming quote messages.
///
/// Yahoo's WebSocket sends base64-encoded protobuf messages. This decoder handles
/// the four wire types used in the schema: VARINT, I64, LEN, and I32.
struct ProtobufDecoder {
    private var data: Data
    private var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    var isAtEnd: Bool { offset >= data.count }

    // MARK: - Primitive Readers

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift >= 64 {
                throw YahooFinanceError.protobufDecodingError("Varint too long")
            }
        }
        throw YahooFinanceError.protobufDecodingError("Truncated varint")
    }

    mutating func readFixed32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw YahooFinanceError.protobufDecodingError("Truncated fixed32")
        }
        let value = data[offset..<offset+4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        offset += 4
        return UInt32(littleEndian: value)
    }

    mutating func readFixed64() throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw YahooFinanceError.protobufDecodingError("Truncated fixed64")
        }
        let value = data[offset..<offset+8].withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        offset += 8
        return UInt64(littleEndian: value)
    }

    mutating func readFloat() throws -> Float {
        let bits = try readFixed32()
        return Float(bitPattern: bits)
    }

    mutating func readDouble() throws -> Double {
        let bits = try readFixed64()
        return Double(bitPattern: bits)
    }

    mutating func readBytes(count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw YahooFinanceError.protobufDecodingError("Truncated bytes field")
        }
        let bytes = data[offset..<offset+count]
        offset += count
        return Data(bytes)
    }

    mutating func readString() throws -> String {
        let length = Int(try readVarint())
        let bytes = try readBytes(count: length)
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw YahooFinanceError.protobufDecodingError("Invalid UTF-8 string")
        }
        return string
    }

    mutating func readSInt64() throws -> Int64 {
        let raw = try readVarint()
        return zigzagDecode(raw)
    }

    static func zigzagDecode(_ value: UInt64) -> Int64 {
        Int64(bitPattern: (value >> 1)) ^ -Int64(bitPattern: value & 1)
    }

    func zigzagDecode(_ value: UInt64) -> Int64 {
        Self.zigzagDecode(value)
    }

    // MARK: - Field Reading

    mutating func readTag() throws -> (fieldNumber: Int, wireType: Int) {
        let tag = try readVarint()
        let wireType = Int(tag & 0x07)
        let fieldNumber = Int(tag >> 3)
        return (fieldNumber, wireType)
    }

    mutating func skipField(wireType: Int) throws {
        switch wireType {
        case 0: // VARINT
            _ = try readVarint()
        case 1: // I64
            offset += 8
            guard offset <= data.count else {
                throw YahooFinanceError.protobufDecodingError("Truncated I64 skip")
            }
        case 2: // LEN
            let length = Int(try readVarint())
            offset += length
            guard offset <= data.count else {
                throw YahooFinanceError.protobufDecodingError("Truncated LEN skip")
            }
        case 5: // I32
            offset += 4
            guard offset <= data.count else {
                throw YahooFinanceError.protobufDecodingError("Truncated I32 skip")
            }
        default:
            throw YahooFinanceError.protobufDecodingError("Unknown wire type \(wireType)")
        }
    }

    // MARK: - Yahoo Finance Quote Decoding

    /// Yahoo Finance streaming protobuf field numbers (reverse-engineered schema):
    ///  1: symbol (string)
    ///  2: price (float)
    ///  3: timestamp (sint64 — seconds since epoch)
    ///  4: currency (string)
    ///  5: exchange (string)
    ///  6: market hours (string: "PRE", "REGULAR", "POST", "CLOSED")
    ///  7: change percent (float)
    ///  8: day volume (sint64)
    ///  9: day high (float)
    /// 10: day low (float)
    /// 11: change (float)
    /// 12: short name (string)
    /// 13: previous close (float)
    /// 14: bid (float)
    /// 15: ask (float)
    /// 16: bid size (sint64)
    /// 17: ask size (sint64)
    /// 18: market cap (sint64)
    mutating func decodeStreamQuote() throws -> StreamQuote {
        var symbol: String?
        var price: Float?
        var timestamp: Int64?
        var currency: String?
        var exchange: String?
        var marketHoursStr: String?
        var changePercent: Float?
        var dayVolume: Int64?
        var dayHigh: Float?
        var dayLow: Float?
        var change: Float?
        var shortName: String?
        var previousClose: Float?
        var bid: Float?
        var ask: Float?
        var bidSize: Int64?
        var askSize: Int64?
        var marketCap: Int64?

        while !isAtEnd {
            let (fieldNumber, wireType) = try readTag()

            switch fieldNumber {
            case 1:
                symbol = try readString()
            case 2:
                price = try readFloat()
            case 3:
                timestamp = try readSInt64()
            case 4:
                currency = try readString()
            case 5:
                exchange = try readString()
            case 6:
                marketHoursStr = try readString()
            case 7:
                changePercent = try readFloat()
            case 8:
                dayVolume = try readSInt64()
            case 9:
                dayHigh = try readFloat()
            case 10:
                dayLow = try readFloat()
            case 11:
                change = try readFloat()
            case 12:
                shortName = try readString()
            case 13:
                previousClose = try readFloat()
            case 14:
                bid = try readFloat()
            case 15:
                ask = try readFloat()
            case 16:
                bidSize = try readSInt64()
            case 17:
                askSize = try readSInt64()
            case 18:
                marketCap = try readSInt64()
            default:
                try skipField(wireType: wireType)
            }
        }

        guard let sym = symbol else {
            throw YahooFinanceError.protobufDecodingError("Missing symbol field")
        }
        guard let p = price else {
            throw YahooFinanceError.protobufDecodingError("Missing price field")
        }

        let ts: Date
        if let t = timestamp {
            ts = Date(timeIntervalSince1970: TimeInterval(t))
        } else {
            ts = Date()
        }

        let hours: MarketHours? = marketHoursStr.flatMap { MarketHours(rawValue: $0) }

        return StreamQuote(
            symbol: sym,
            price: Double(p),
            timestamp: ts,
            marketHours: hours,
            currency: currency,
            exchange: exchange,
            changePercent: changePercent.map { Double($0) },
            dayVolume: dayVolume,
            dayHigh: dayHigh.map { Double($0) },
            dayLow: dayLow.map { Double($0) },
            change: change.map { Double($0) },
            previousClose: previousClose.map { Double($0) },
            bid: bid.map { Double($0) },
            ask: ask.map { Double($0) },
            bidSize: bidSize,
            askSize: askSize,
            marketCap: marketCap,
            shortName: shortName
        )
    }

    // MARK: - Public Entry Point

    /// Decode a base64-encoded protobuf message into a `StreamQuote`.
    static func decode(base64String: String) throws -> StreamQuote {
        guard let data = Data(base64Encoded: base64String) else {
            throw YahooFinanceError.protobufDecodingError("Invalid base64 string")
        }
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeStreamQuote()
    }

    /// Decode raw protobuf data into a `StreamQuote`.
    static func decode(data: Data) throws -> StreamQuote {
        var decoder = ProtobufDecoder(data: data)
        return try decoder.decodeStreamQuote()
    }
}
