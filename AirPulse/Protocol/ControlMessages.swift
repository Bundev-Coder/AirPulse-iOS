import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.airpulse.client", category: "FrameReader")

// MARK: - Frame Reader (async stream over NWConnection)

/// Đọc frame liên tục từ NWConnection, xử lý replay protection
public actor FrameReaderActor {
    private let connection: NWConnection
    private var lastSequence: UInt32 = 0
    private var receiveBuffer = Data()

    public init(connection: NWConnection) {
        self.connection = connection
    }

    /// Đọc frame tiếp theo. Returns nil khi connection đóng.
    public func readFrame() async throws -> (header: FrameHeader, payload: Data)? {
        // Đọc đủ 12 byte header
        let headerData = try await receiveExact(count: FrameHeader.size)
        guard let headerData else { return nil }

        let header = try FrameHeader.from(data: headerData)

        // Validate payload size
        guard header.payloadLength >= 0,
              header.payloadLength <= FrameHeader.maxPayload else {
            throw ProtocolError.payloadTooLarge(header.payloadLength)
        }

        // Replay protection
        if header.sequence > 0 {
            let isWrap = lastSequence > UInt32.max - 1000 && header.sequence < 1000
            if header.sequence <= lastSequence && !isWrap {
                throw ProtocolError.replayDetected(header.sequence, lastSequence)
            }
        }
        lastSequence = header.sequence

        // Đọc payload
        var payload = Data()
        if header.payloadLength > 0 {
            guard let p = try await receiveExact(count: Int(header.payloadLength)) else {
                return nil
            }
            payload = p
        }

        return (header, payload)
    }

    // MARK: - Private

    private func receiveExact(count: Int) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if isComplete && (data == nil || data!.count < count) {
                    continuation.resume(returning: nil)
                    return
                }
                guard let data, data.count >= count else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: data.prefix(count))
            }
        }
    }
}

// MARK: - Message Sender (thread-safe via actor)

public actor MessageSenderActor {
    private let connection: NWConnection
    private var sendSequence: UInt32 = 0

    public init(connection: NWConnection) {
        self.connection = connection
    }

    /// Gửi Protobuf message với header đúng format
    public func send(
        messageType: MessageType,
        payload: Data
    ) async throws {
        sendSequence &+= 1
        let header = FrameHeader(
            messageType: messageType.rawValue,
            sequence: sendSequence,
            payloadLength: Int32(payload.count)
        )

        var frame = header.toData()
        frame.append(payload)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Gửi raw bytes (Video frame header + NAL data)
    public func sendRaw(data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
