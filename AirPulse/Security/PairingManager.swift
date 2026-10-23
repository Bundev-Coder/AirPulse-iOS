import Foundation
import CryptoKit

// MARK: - QR Code Parse Result

public struct QRPairingPayload {
    public let hostIp: String
    public let port: UInt16
    public let tokenData: Data
    public let fingerprint: String
}

// MARK: - Pairing Manager

public final class PairingManager {
    public static let shared = PairingManager()

    private init() {}

    /// Parses URL QR payload: airpulse://pair?ip=192.168.1.10&port=7001&token=a1b2c3...&fp=e3b0c442...
    public func parseQrPayload(_ rawString: String) -> QRPairingPayload? {
        guard let url = URL(string: rawString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "airpulse" && components.host == "pair" else {
            return nil
        }

        var ip: String?
        var port: UInt16 = 7001
        var tokenHex: String?
        var fp: String?

        for item in components.queryItems ?? [] {
            switch item.name {
            case "ip": ip = item.value
            case "port": if let p = item.value.flatMap(UInt16.init) { port = p }
            case "token": tokenHex = item.value
            case "fp": fp = item.value
            default: break
            }
        }

        var tokenData: Data? = nil
        if let rawToken = tokenHex {
            var base64 = rawToken.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            while base64.count % 4 != 0 { base64.append("=") }
            if let d = Data(base64Encoded: base64) {
                tokenData = d
            } else if let d = Data(hexString: rawToken) {
                tokenData = d
            } else {
                tokenData = rawToken.data(using: .utf8)
            }
        }

        guard let targetIp = ip, !targetIp.isEmpty,
              let validToken = tokenData,
              let certFp = fp, !certFp.isEmpty else {
            return nil
        }

        return QRPairingPayload(hostIp: targetIp, port: port, tokenData: validToken, fingerprint: certFp)
    }

    /// Generates token bytes for PIN-based pairing: SHA256(pinUtf8)
    public func createPinToken(pin: String) -> Data {
        let cleanPin = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pinData = cleanPin.data(using: .utf8) else { return Data() }
        let digest = SHA256.hash(data: pinData)
        return Data(digest)
    }

    /// Computes HMAC-SHA256 for AUTH_CHALLENGE response
    public func computeAuthResponse(nonce: Data, timestampMs: Int64, deviceKey: SymmetricKey) -> Data {
        var msgData = nonce
        var tsBE = timestampMs.bigEndian
        withUnsafeBytes(of: &tsBE) { msgData.append(contentsOf: $0) }
        
        let mac = HMAC<SHA256>.authenticationCode(for: msgData, using: deviceKey)
        return Data(mac)
    }
}
