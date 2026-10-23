import Foundation
import Network
import CryptoKit
import Security

public enum TlsClientError: Error, LocalizedError {
    case connectionFailed(String)
    case certificateMismatch(expected: String, got: String)
    case disconnected
    case protocolViolation(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Lỗi kết nối TLS: \(msg)"
        case .certificateMismatch(let exp, let got): return "Chứng chỉ không khớp (kỳ vọng \(exp), thực tế \(got))"
        case .disconnected: return "Kết nối đã ngắt"
        case .protocolViolation(let msg): return "Vi phạm giao thức: \(msg)"
        }
    }
}

public final class TlsClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.airpulse.tls", qos: .userInteractive)
    private var sendSequence: UInt32 = 0
    private var isConnected: Bool = false
    private var pinnedFingerprint: String?

    public init() {}

    public func connect(host: String, port: UInt16, expectedFingerprint: String? = nil) async throws {
        self.pinnedFingerprint = expectedFingerprint
        
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port) ?? 7001

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)

        // Custom TLS Verification for self-signed host certificate pinning (safe check)
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { [weak self] (_, secTrust, completionHandler) in
            if let unmanaged = sec_trust_copy_ref(secTrust) {
                let serverTrust = unmanaged.takeRetainedValue()
                if let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
                   let leafCert = certChain.first {
                    let certData = SecCertificateCopyData(leafCert) as Data
                    let hash = SHA256.hash(data: certData)
                    let certHex = hash.map { String(format: "%02x", $0) }.joined()

                    if let pinned = self?.pinnedFingerprint, !pinned.isEmpty {
                        let cleanPinned = pinned.lowercased().replacingOccurrences(of: ":", with: "")
                        if !certHex.lowercased().hasPrefix(cleanPinned) && !cleanPinned.hasPrefix(certHex.lowercased()) {
                            completionHandler(false)
                            return
                        }
                    }
                }
            }

            // Trust local host self-signed cert on LAN
            completionHandler(true)
        }, queue)

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 5

        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        parameters.includePeerToPeer = true

        let conn = NWConnection(host: nwHost, port: nwPort, using: parameters)
        self.connection = conn

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnected = true
                    if !resumed {
                        resumed = true
                        continuation.resume()
                    }
                case .failed(let err):
                    self?.isConnected = false
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: TlsClientError.connectionFailed(err.localizedDescription))
                    }
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }

            conn.start(queue: self.queue)
        }
    }

    public func sendRaw(data: Data) async throws {
        guard let conn = connection, isConnected else {
            throw TlsClientError.disconnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            conn.send(content: data, completion: .contentProcessed { error in
                if let err = error {
                    continuation.resume(throwing: err)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func sendFrame(type: UInt8, payload: Data) async throws {
        sendSequence &+= 1
        let header = FrameHeader(messageType: type, sequence: sendSequence, payloadLength: Int32(payload.count))
        var packet = header.encode()
        packet.append(payload)
        try await sendRaw(data: packet)
    }

    public func readExact(count: Int) async throws -> Data {
        guard let conn = connection, isConnected else {
            throw TlsClientError.disconnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: count, maximumLength: count) { content, _, isComplete, error in
                if let err = error {
                    continuation.resume(throwing: err)
                    return
                }
                guard let data = content, data.count == count else {
                    if isComplete {
                        continuation.resume(throwing: TlsClientError.disconnected)
                    } else {
                        continuation.resume(throwing: TlsClientError.protocolViolation("Không đủ dữ liệu"))
                    }
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    public func readFrame() async throws -> (header: FrameHeader, payload: Data)? {
        let headerData = try await readExact(count: AirPulseWire.headerSize)
        guard let header = FrameHeader(from: headerData), header.isValid else {
            throw TlsClientError.protocolViolation("Header frame không hợp lệ")
        }

        if header.payloadLength == 0 {
            return (header, Data())
        }

        let payload = try await readExact(count: Int(header.payloadLength))
        return (header, payload)
    }

    public func disconnect() {
        isConnected = false
        connection?.cancel()
        connection = nil
    }
}
