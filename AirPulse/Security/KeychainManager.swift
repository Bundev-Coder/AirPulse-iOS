import Foundation
import Security
import CryptoKit

// MARK: - Paired Host Model

public struct PairedHost: Identifiable, Codable, Hashable {
    public var id: String // Host UUID
    public var name: String
    public var lastKnownIp: String
    public var controlPort: UInt16
    public var certFingerprint: String
    public var deviceSecret: String // Hex or Base64 device key for HMAC
    public var pairedDate: Date
    public var lastSeenDate: Date?

    public init(id: String, name: String, lastKnownIp: String, controlPort: UInt16 = 7001, certFingerprint: String, deviceSecret: String) {
        self.id = id
        self.name = name
        self.lastKnownIp = lastKnownIp
        self.controlPort = controlPort
        self.certFingerprint = certFingerprint
        self.deviceSecret = deviceSecret
        self.pairedDate = Date()
        self.lastSeenDate = Date()
    }
}

// MARK: - Keychain & Local Storage Manager

public final class KeychainManager {
    public static let shared = KeychainManager()

    private let userDefaultsKeyHosts = "com.airpulse.paired_hosts"
    private let keychainService = "com.airpulse.device"
    private let keychainAccountClientKey = "client_master_identity"

    private init() {}

    // MARK: Client Identity

    public func getOrCreateClientIdentity() -> (clientId: String, deviceSecret: SymmetricKey) {
        if let data = loadFromKeychain(account: keychainAccountClientKey),
           let str = String(data: data, encoding: .utf8) {
            let parts = str.split(separator: ":")
            if parts.count == 2 {
                let id = String(parts[0])
                let keyData = Data(hexString: String(parts[1])) ?? Data()
                if keyData.count == 32 {
                    return (id, SymmetricKey(data: keyData))
                }
            }
        }

        // Generate new identity
        let newId = UUID().uuidString
        let newKey = SymmetricKey(size: .bits256)
        let keyHex = newKey.withUnsafeBytes { Data($0).hexString }
        let saveStr = "\(newId):\(keyHex)"
        if let data = saveStr.data(using: .utf8) {
            saveToKeychain(account: keychainAccountClientKey, data: data)
        }
        return (newId, newKey)
    }

    // MARK: Paired Hosts

    public func getPairedHosts() -> [PairedHost] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKeyHosts),
              let list = try? JSONDecoder().decode([PairedHost].self, from: data) else {
            return []
        }
        return list
    }

    public func savePairedHost(_ host: PairedHost) {
        var list = getPairedHosts().filter { $0.id != host.id }
        list.append(host)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKeyHosts)
        }
    }

    public func updateLastSeen(hostId: String, ip: String) {
        var list = getPairedHosts()
        if let idx = list.firstIndex(where: { $0.id == hostId }) {
            list[idx].lastKnownIp = ip
            list[idx].lastSeenDate = Date()
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: userDefaultsKeyHosts)
            }
        }
    }

    public func removePairedHost(id: String) {
        var list = getPairedHosts().filter { $0.id != id }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKeyHosts)
        }
    }

    // MARK: Low-level Keychain API

    private func saveToKeychain(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess ? (item as? Data) : nil
    }
}

// MARK: - Extensions

extension Data {
    public var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    public init?(hexString: String) {
        var data = Data()
        var hex = hexString.replacingOccurrences(of: " ", with: "")
        guard hex.count.isMultiple(of: 2) else { return nil }
        
        while !hex.isEmpty {
            let sub = String(hex.prefix(2))
            hex = String(hex.dropFirst(2))
            guard let byte = UInt8(sub, radix: 16) else { return nil }
            data.append(byte)
        }
        self = data
    }
}
