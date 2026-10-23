import Foundation

// MARK: - Wire Framing Constants

public enum AirPulseWire {
    public static let magic0: UInt8 = 0x41 // 'A'
    public static let magic1: UInt8 = 0x50 // 'P'
    public static let currentVersion: UInt8 = 0x01
    public static let headerSize: Int = 12
    public static let videoHeaderSize: Int = 21
    public static let defaultControlPort: UInt16 = 7001
    public static let defaultVideoPort: UInt16 = 7002
    public static let defaultFilePort: UInt16 = 7003
}

// MARK: - Frame Header (12 Bytes)
// [Magic0:1][Magic1:1][Version:1][MsgType:1][Sequence:4 (BE)][PayloadLen:4 (BE)]

public struct FrameHeader {
    public let magic0: UInt8
    public let magic1: UInt8
    public let version: UInt8
    public let messageType: UInt8
    public let sequence: UInt32
    public let payloadLength: Int32

    public var isValid: Bool {
        magic0 == AirPulseWire.magic0 &&
        magic1 == AirPulseWire.magic1 &&
        version == AirPulseWire.currentVersion
    }

    public init(messageType: UInt8, sequence: UInt32, payloadLength: Int32) {
        self.magic0 = AirPulseWire.magic0
        self.magic1 = AirPulseWire.magic1
        self.version = AirPulseWire.currentVersion
        self.messageType = messageType
        self.sequence = sequence
        self.payloadLength = payloadLength
    }

    public init?(from data: Data) {
        guard data.count >= AirPulseWire.headerSize else { return nil }
        self.magic0 = data[0]
        self.magic1 = data[1]
        self.version = data[2]
        self.messageType = data[3]
        
        let seq = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        self.sequence = UInt32(bigEndian: seq)
        
        let pLen = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: Int32.self) }
        self.payloadLength = Int32(bigEndian: pLen)
    }

    public func encode() -> Data {
        var data = Data(count: AirPulseWire.headerSize)
        data[0] = magic0
        data[1] = magic1
        data[2] = version
        data[3] = messageType
        
        var seqBE = sequence.bigEndian
        withUnsafeBytes(of: &seqBE) { data.replaceSubrange(4..<8, with: $0) }
        
        var pLenBE = payloadLength.bigEndian
        withUnsafeBytes(of: &pLenBE) { data.replaceSubrange(8..<12, with: $0) }
        
        return data
    }
}

// MARK: - Video Frame Header (21 Bytes)
// [FrameType:1][TimestampUs:8 (BE)][FrameIndex:4 (BE)][Width:2 (BE)][Height:2 (BE)][DataLen:4 (BE)]

public enum VideoFrameType: UInt8 {
    case idr = 0x01
    case pFrame = 0x02
    case bFrame = 0x03
}

public struct VideoFrameHeader {
    public let frameType: VideoFrameType
    public let timestampUs: Int64
    public let frameIndex: UInt32
    public let width: UInt16
    public let height: UInt16
    public let dataLength: Int32

    public var isKeyframe: Bool {
        frameType == .idr
    }

    public init?(from data: Data) {
        guard data.count >= AirPulseWire.videoHeaderSize else { return nil }
        guard let fType = VideoFrameType(rawValue: data[0]) else { return nil }
        self.frameType = fType
        
        let ts = data.subdata(in: 1..<9).withUnsafeBytes { $0.load(as: Int64.self) }
        self.timestampUs = Int64(bigEndian: ts)
        
        let idx = data.subdata(in: 9..<13).withUnsafeBytes { $0.load(as: UInt32.self) }
        self.frameIndex = UInt32(bigEndian: idx)
        
        let w = data.subdata(in: 13..<15).withUnsafeBytes { $0.load(as: UInt16.self) }
        self.width = UInt16(bigEndian: w)
        
        let h = data.subdata(in: 15..<17).withUnsafeBytes { $0.load(as: UInt16.self) }
        self.height = UInt16(bigEndian: h)
        
        let dLen = data.subdata(in: 17..<21).withUnsafeBytes { $0.load(as: Int32.self) }
        self.dataLength = Int32(bigEndian: dLen)
    }
}

// MARK: - Message Types Enum

public enum MessageType {
    // Handshake
    public static let hello: UInt8           = 0x01
    public static let helloAck: UInt8        = 0x02
    public static let pairingRequest: UInt8  = 0x03
    public static let pairingResponse: UInt8 = 0x04
    public static let authChallenge: UInt8   = 0x05
    public static let authResponse: UInt8    = 0x06

    // Session
    public static let sessionStart: UInt8    = 0x10
    public static let sessionStop: UInt8     = 0x11
    public static let qualityAdjust: UInt8   = 0x12

    // Input Events
    public static let mouseMove: UInt8       = 0x20
    public static let mouseButton: UInt8     = 0x21
    public static let mouseScroll: UInt8     = 0x22
    public static let keyEvent: UInt8        = 0x23
    public static let textInput: UInt8       = 0x24

    // Clipboard
    public static let clipboardText: UInt8   = 0x30

    // Display
    public static let displayList: UInt8     = 0x40
    public static let displaySelect: UInt8   = 0x41

    // System
    public static let ping: UInt8            = 0x50
    public static let pong: UInt8            = 0x51
    public static let disconnect: UInt8      = 0x52
    public static let error: UInt8           = 0x53

    // File Transfer
    public static let fileSendRequest: UInt8 = 0x60
    public static let fileSendAccept: UInt8  = 0x61
    public static let fileSendReject: UInt8  = 0x62
    public static let fileChunk: UInt8       = 0x63
    public static let fileChunkAck: UInt8    = 0x64
    public static let fileComplete: UInt8    = 0x65
    public static let fileCompleteAck: UInt8 = 0x66
    public static let fileCancel: UInt8      = 0x67
    public static let filePause: UInt8       = 0x68
    public static let fileResume: UInt8      = 0x69
    public static let fileProgress: UInt8    = 0x6A
}
