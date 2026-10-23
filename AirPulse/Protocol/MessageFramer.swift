import Foundation

// MARK: - Frame Header (12 bytes, Big-Endian)
// [Magic:2][Version:1][MsgType:1][Sequence:4][PayloadLen:4]

/// AirPulse wire frame header — mirror của C# FrameHeader
public struct FrameHeader {
    public static let size: Int = 12
    public static let magic0: UInt8 = 0x41  // 'A'
    public static let magic1: UInt8 = 0x50  // 'P'
    public static let currentVersion: UInt8 = 0x01
    public static let maxPayload: Int = 64 * 1024 * 1024  // 64MB

    public let magic0: UInt8
    public let magic1: UInt8
    public let version: UInt8
    public let messageType: UInt8
    public let sequence: UInt32
    public let payloadLength: Int32

    public init(messageType: UInt8, sequence: UInt32, payloadLength: Int32) {
        self.magic0        = FrameHeader.magic0
        self.magic1        = FrameHeader.magic1
        self.version       = FrameHeader.currentVersion
        self.messageType   = messageType
        self.sequence      = sequence
        self.payloadLength = payloadLength
    }

    // MARK: Serialization

    /// Serialize thành 12-byte Data (Big-Endian)
    public func toData() -> Data {
        var data = Data(capacity: FrameHeader.size)
        data.append(magic0)
        data.append(magic1)
        data.append(version)
        data.append(messageType)
        data.appendBigEndian(sequence)
        data.appendBigEndian(UInt32(bitPattern: payloadLength))
        return data
    }

    /// Parse từ Data (Big-Endian). Throws ProtocolError nếu invalid.
    public static func from(data: Data) throws -> FrameHeader {
        guard data.count >= FrameHeader.size else {
            throw ProtocolError.bufferTooSmall
        }
        let b = data

        guard b[0] == FrameHeader.magic0, b[1] == FrameHeader.magic1 else {
            throw ProtocolError.invalidMagic(b[0], b[1])
        }
        guard b[2] == FrameHeader.currentVersion else {
            throw ProtocolError.unsupportedVersion(b[2])
        }

        let msgType = b[3]
        let seq     = b.readBigEndianUInt32(at: 4)
        let payLen  = Int32(bitPattern: b.readBigEndianUInt32(at: 8))

        return FrameHeader(messageType: msgType, sequence: seq, payloadLength: payLen)
    }

    public var isValid: Bool {
        magic0 == FrameHeader.magic0 &&
        magic1 == FrameHeader.magic1 &&
        version == FrameHeader.currentVersion
    }
}

// MARK: - Video Frame Header (21 bytes, Big-Endian)
// [FrameType:1][Timestamp:8][FrameIndex:4][Width:2][Height:2][DataLen:4]

public struct VideoFrameHeader {
    public static let size: Int = 21

    public let frameType:   VideoFrameType
    public let timestampUs: Int64
    public let frameIndex:  UInt32
    public let width:       UInt16
    public let height:      UInt16
    public let dataLength:  Int32

    public var isKeyFrame: Bool { frameType == .idr }

    public func toData() -> Data {
        var data = Data(capacity: VideoFrameHeader.size)
        data.append(frameType.rawValue)
        data.appendBigEndian(UInt64(bitPattern: timestampUs))
        data.appendBigEndian(frameIndex)
        data.appendBigEndian(width)
        data.appendBigEndian(height)
        data.appendBigEndian(UInt32(bitPattern: dataLength))
        return data
    }

    public static func from(data: Data) throws -> VideoFrameHeader {
        guard data.count >= VideoFrameHeader.size else {
            throw ProtocolError.bufferTooSmall
        }
        let ft = VideoFrameType(rawValue: data[0]) ?? .pFrame
        let ts = Int64(bitPattern: data.readBigEndianUInt64(at: 1))
        let fi = data.readBigEndianUInt32(at: 9)
        let w  = data.readBigEndianUInt16(at: 13)
        let h  = data.readBigEndianUInt16(at: 15)
        let dl = Int32(bitPattern: data.readBigEndianUInt32(at: 17))
        return VideoFrameHeader(
            frameType: ft, timestampUs: ts,
            frameIndex: fi, width: w, height: h, dataLength: dl
        )
    }
}

public enum VideoFrameType: UInt8 {
    case idr    = 0x01
    case pFrame = 0x02
    case bFrame = 0x03
}

// MARK: - Message Types

public enum MessageType: UInt8 {
    // Handshake
    case hello          = 0x01
    case helloAck       = 0x02
    case pairingRequest = 0x03
    case pairingResponse = 0x04
    case authChallenge  = 0x05
    case authResponse   = 0x06

    // Session
    case sessionStart   = 0x10
    case sessionStop    = 0x11
    case sessionPause   = 0x12
    case sessionResume  = 0x13
    case qualityAdjust  = 0x14

    // Input
    case mouseMove      = 0x20
    case mouseButton    = 0x21
    case mouseScroll    = 0x22
    case keyEvent       = 0x23
    case textInput      = 0x24

    // Clipboard
    case clipboardText  = 0x30

    // Display
    case displayList    = 0x40
    case displaySelect  = 0x41

    // System
    case ping           = 0x50
    case pong           = 0x51
    case disconnect     = 0x52
    case error          = 0x53

    // File
    case fileSendRequest  = 0x60
    case fileSendAccept   = 0x61
    case fileSendReject   = 0x62
    case fileChunk        = 0x63
    case fileChunkAck     = 0x64
    case fileComplete     = 0x65
    case fileCompleteAck  = 0x66
    case fileCancel       = 0x67
    case filePause        = 0x68
    case fileResume       = 0x69
    case fileProgress     = 0x6A
}

// MARK: - Protocol Errors

public enum ProtocolError: Error, LocalizedError {
    case bufferTooSmall
    case invalidMagic(UInt8, UInt8)
    case unsupportedVersion(UInt8)
    case replayDetected(UInt32, UInt32)
    case payloadTooLarge(Int32)
    case unknownMessageType(UInt8)
    case decodeFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .bufferTooSmall:
            return "Buffer quá nhỏ để đọc header"
        case .invalidMagic(let b0, let b1):
            return "Magic bytes không hợp lệ: 0x\(String(b0, radix: 16)) 0x\(String(b1, radix: 16))"
        case .unsupportedVersion(let v):
            return "Phiên bản giao thức không hỗ trợ: \(v)"
        case .replayDetected(let seq, let last):
            return "Phát hiện replay attack: seq=\(seq), last=\(last)"
        case .payloadTooLarge(let len):
            return "Payload quá lớn: \(len) bytes"
        case .unknownMessageType(let t):
            return "Message type không xác định: 0x\(String(t, radix: 16))"
        case .decodeFailed(let e):
            return "Giải mã Protobuf thất bại: \(e)"
        }
    }
}

// MARK: - Data Extensions (Big-Endian helpers)

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }

    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8)  & 0xFF))
        append(UInt8( value        & 0xFF))
    }

    mutating func appendBigEndian(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> shift) & 0xFF))
        }
    }

    func readBigEndianUInt16(at offset: Int) -> UInt16 {
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    func readBigEndianUInt32(at offset: Int) -> UInt32 {
        return UInt32(self[offset])     << 24
             | UInt32(self[offset + 1]) << 16
             | UInt32(self[offset + 2]) << 8
             | UInt32(self[offset + 3])
    }

    func readBigEndianUInt64(at offset: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0..<8 {
            result = (result << 8) | UInt64(self[offset + i])
        }
        return result
    }
}
