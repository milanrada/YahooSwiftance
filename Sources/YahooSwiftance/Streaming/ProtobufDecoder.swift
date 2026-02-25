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

    /// Yahoo Finance streaming protobuf field numbers (reverse-engineered schema).
    ///
    /// The decoder is wire-type aware: each field is matched by *both* field number
    /// and wire type so schema changes (e.g. string → varint) don't corrupt the parse.
    ///
    ///  1: symbol (LEN/string)
    ///  2: price (I32/float)
    ///  3: timestamp (VARINT — zigzag, milliseconds since epoch)
    ///  4: currency (LEN/string)
    ///  5: exchange (LEN/string)
    ///  6: market hours (VARINT — enum)
    ///  8: change percent (I32/float)
    ///  9: day volume (VARINT — zigzag)
    /// 10: day high (I32/float)
    /// 11: day low (I32/float)
    /// 12: change (I32/float)
    /// 15: previous close (I32/float)
    /// 30: short name (LEN/string)
    /// 33: market cap (I64/double)
    mutating func decodeStreamQuote() throws -> StreamQuote {
        var symbol: String?
        var price: Float?
        var timestampMs: Int64?
        var currency: String?
        var exchange: String?
        var marketHoursRaw: UInt64?
        var changePercent: Float?
        var dayVolume: Int64?
        var dayHigh: Float?
        var dayLow: Float?
        var change: Float?
        var shortName: String?
        var previousClose: Float?
        var marketCap: Double?

        while !isAtEnd {
            let (fieldNumber, wireType) = try readTag()

            // Match on (field, wireType) to handle schema evolution safely.
            switch (fieldNumber, wireType) {
            case (1, 2):  // symbol (string)
                symbol = try readString()
            case (2, 5):  // price (float)
                price = try readFloat()
            case (3, 0):  // timestamp (varint, zigzag, milliseconds)
                timestampMs = try readSInt64()
            case (4, 2):  // currency (string)
                currency = try readString()
            case (5, 2):  // exchange (string)
                exchange = try readString()
            case (6, 0):  // market hours (varint enum)
                marketHoursRaw = try readVarint()
            case (8, 5):  // change percent (float)
                changePercent = try readFloat()
            case (9, 0):  // day volume (varint, zigzag)
                dayVolume = try readSInt64()
            case (10, 5): // day high (float)
                dayHigh = try readFloat()
            case (11, 5): // day low (float)
                dayLow = try readFloat()
            case (12, 5): // change (float)
                change = try readFloat()
            case (15, 5): // previous close (float)
                previousClose = try readFloat()
            case (30, 2): // short name (string)
                shortName = try readString()
            case (33, 1): // market cap (double)
                marketCap = try readDouble()
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
        if let ms = timestampMs {
            ts = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        } else {
            ts = Date()
        }

        let hours: MarketHours? = marketHoursRaw.flatMap { MarketHours(protobufValue: $0) }

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
            bid: nil,
            ask: nil,
            bidSize: nil,
            askSize: nil,
            marketCap: marketCap.map { Int64($0) },
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
