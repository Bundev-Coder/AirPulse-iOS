import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.airpulse.client", category: "VideoFrameHeader")

// MARK: - Video Frame Header Extension (Swift)
// Nằm trong Protocol/ để tái dụng cho cả Video decoder và File channel

public extension VideoFrameHeader {
    /// Parse từ raw Data nhận được từ Video Channel
    static func parse(from data: Data) throws -> (header: VideoFrameHeader, nalData: Data) {
        guard data.count >= VideoFrameHeader.size else {
            throw ProtocolError.bufferTooSmall
        }
        let header = try VideoFrameHeader.from(data: data)
        let nalData = data.dropFirst(VideoFrameHeader.size)
        return (header, nalData)
    }
}

// MARK: - Error Code Constants (Swift mirror)

public enum AirPulseErrorCode: Int32 {
    // Connection 1xx
    case connectionTimeout  = 100
    case tlsHandshakeFailed = 101
    case versionMismatch    = 102

    // Auth 2xx
    case authRejected       = 200
    case pinIncorrect       = 201
    case pinLocked          = 202
    case tokenExpired       = 203
    case deviceRevoked      = 204

    // Session 3xx
    case displayNotFound    = 300
    case captureFailed      = 301
    case encodeFailed       = 302

    // File 4xx
    case fileTooLarge       = 400
    case diskFull           = 401
    case hashMismatch       = 402
    case transferCancelled  = 403

    // System 5xx
    case internalError      = 500
    case resourceExhausted  = 501
}

// MARK: - Trusted Device Model

public struct TrustedDevice: Codable, Identifiable {
    public let id: String          // UUID
    public let deviceId: String
    public let deviceName: String
    public let platform: String    // "ios"
    public let certFingerprint: String
    public let pairedAt: Date
    public var lastSeen: Date
    public var isRevoked: Bool

    public init(
        deviceId: String,
        deviceName: String,
        platform: String,
        certFingerprint: String
    ) {
        self.id               = UUID().uuidString
        self.deviceId         = deviceId
        self.deviceName       = deviceName
        self.platform         = platform
        self.certFingerprint  = certFingerprint
        self.pairedAt         = Date()
        self.lastSeen         = Date()
        self.isRevoked        = false
    }
}
