import Foundation
import SwiftUI

// MARK: - Vault Item
struct VaultItem: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    let size: Int64
    let size_formatted: String
    let timestamp: Double
    let is_image: Bool
    let is_video: Bool
    let download_url: String
    let view_url: String
}

// MARK: - Server Info
struct ServerInfo: Codable {
    let status: String
    let ip: String
    let port: Int
    let base_url: String
    let os: String
    let active_clients: Int
}

// MARK: - WebSocket Message
struct OutgoingWsMessage: Codable {
    let type: String
    var device: String? = nil
    var dx: Int? = nil
    var dy: Int? = nil
    var button: String? = nil
    var action: String? = nil
    var url: String? = nil
    var text: String? = nil
}

struct IncomingWsMessage: Codable {
    let type: String
    let action: String?
    let message: String?
    let device: String?
    let url: String?
    let text: String?
    let file: VaultItem?
    let count: Int?
    let devices: [String]?
}
