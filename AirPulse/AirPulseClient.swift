import Foundation
import SwiftUI
import Combine
import AudioToolbox
import UIKit

class AirPulseClient: ObservableObject {
    static let shared = AirPulseClient()

    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var statusText: String = "Chưa kết nối"
    @Published var pingMs: Int = 0
    @Published var activePeers: Int = 0
    
    // Remote Power State
    @Published var isShutdownActive: Bool = false
    @Published var shutdownCountdown: Int = 15
    private var shutdownTimer: Timer?
    
    // Vault Files
    @Published var files: [VaultItem] = []
    
    // Screenshot Result
    @Published var latestScreenshot: UIImage? = nil
    @Published var showScreenshotSheet: Bool = false

    // MARK: - App Storage Settings
    @AppStorage("airpulse_gateway_url") var gatewayUrl: String = "http://172.20.10.2:8899"
    @AppStorage("airpulse_auth_token") var authToken: String = ""

    // MARK: - WebSocket Engine
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession = URLSession(configuration: .default)
    private var isIntentionalDisconnect: Bool = false
    private var pingTimer: Timer?

    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    init() {
        impactFeedback.prepare()
        lightImpact.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - URL Helpers
    var baseUrl: String {
        var clean = gatewayUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        if clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        return clean
    }

    var wsUrlString: String {
        var base = baseUrl
        if base.lowercased().hasPrefix("https://") {
            base = "wss://" + String(base.dropFirst(8))
        } else if base.lowercased().hasPrefix("http://") {
            base = "ws://" + String(base.dropFirst(7))
        }
        return "\(base)/ws"
    }

    var isWanMode: Bool {
        return baseUrl.contains("trycloudflare.com") || baseUrl.contains("ngrok") || baseUrl.contains("https://")
    }

    // MARK: - Connection Management
    func connect() {
        disconnect()
        isIntentionalDisconnect = false
        isConnecting = true
        statusText = "Đang kết nối: \(baseUrl)..."

        guard let wsUrl = URL(string: wsUrlString) else {
            statusText = "Địa chỉ URL không hợp lệ"
            isConnecting = false
            return
        }

        var request = URLRequest(url: wsUrl)
        request.timeoutInterval = 10
        if !authToken.isEmpty {
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        sendIdentify()
        receiveMessage()
        startPingTimer()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
            self.statusText = "Đã ngắt kết nối"
        }
    }

    private func sendIdentify() {
        let deviceName = UIDevice.current.name.isEmpty ? "iPhone Native" : UIDevice.current.name
        let msg = OutgoingWsMessage(type: "IDENTIFY", device: "\(deviceName) (iOS Native)")
        sendMessage(msg)
        
        // After sending, verify handshake
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.webSocketTask?.state == .running {
                self.isConnected = true
                self.isConnecting = false
                let modeStr = self.isWanMode ? "Cloudflare Internet" : "Wi-Fi LAN"
                self.statusText = "Đã kết nối (\(modeStr))"
                self.notificationFeedback.notificationOccurred(.success)
                self.fetchFiles()
            }
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            let startTime = Date()
            self.webSocketTask?.sendPing { error in
                if error == nil {
                    let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                    DispatchQueue.main.async {
                        self.pingMs = latency
                    }
                }
            }
        }
    }

    // MARK: - WebSocket Receive Loop
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingJson(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingJson(text)
                    }
                @unknown default:
                    break
                }
                // Continue loop
                self.receiveMessage()

            case .failure(let error):
                DispatchQueue.main.async {
                    if !self.isIntentionalDisconnect {
                        self.isConnected = false
                        self.isConnecting = false
                        self.statusText = "Mất kết nối (\(error.localizedDescription))"
                        // Auto-reconnect after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            if !self.isConnected && !self.isIntentionalDisconnect {
                                self.connect()
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleIncomingJson(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let msg = try JSONDecoder().decode(IncomingWsMessage.self, from: data)
            DispatchQueue.main.async {
                switch msg.type {
                case "PEER_STATUS":
                    if let count = msg.count {
                        self.activePeers = count
                    }

                case "FILE_RECEIVED":
                    self.notificationFeedback.notificationOccurred(.success)
                    AudioServicesPlaySystemSound(1057) // Native iOS Beep
                    self.fetchFiles()

                case "REMOTE_ACTION_EXECUTED":
                    if let action = msg.action {
                        if action == "shutdown_pc" {
                            self.startShutdownCountdown()
                        } else if action == "cancel_shutdown" {
                            self.stopShutdownCountdown()
                        }
                    }

                default:
                    break
                }
            }
        } catch {}
    }

    func sendMessage(_ msg: OutgoingWsMessage) {
        guard let data = try? JSONEncoder().encode(msg),
              let jsonStr = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(jsonStr)) { _ in }
    }

    // MARK: - Mouse Trackpad Actions
    func sendMouseMove(dx: Int, dy: Int) {
        let msg = OutgoingWsMessage(type: "MOUSE_MOVE", dx: dx, dy: dy)
        sendMessage(msg)
    }

    func sendMouseClick(button: String) {
        lightImpact.impactOccurred()
        let msg = OutgoingWsMessage(type: "MOUSE_CLICK", button: button)
        sendMessage(msg)
    }

    func sendMouseScroll(dy: Int) {
        let msg = OutgoingWsMessage(type: "MOUSE_SCROLL", dy: dy)
        sendMessage(msg)
    }

    // MARK: - Remote PC Commands
    func sendRemoteAction(_ action: String) {
        impactFeedback.impactOccurred()
        
        // Execute via REST for guaranteed delivery
        guard let url = URL(string: "\(baseUrl)/api/remote/action") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["action": action, "device": UIDevice.current.name]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            if action == "screenshot", let data = data {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchLatestScreenshot()
                }
            }
        }.resume()

        if action == "shutdown_pc" {
            startShutdownCountdown()
        } else if action == "cancel_shutdown" {
            stopShutdownCountdown()
        }
    }

    func launchUrl(_ urlString: String) {
        impactFeedback.impactOccurred()
        guard let url = URL(string: "\(baseUrl)/api/remote/open-url") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["url": urlString, "device": UIDevice.current.name]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Shutdown Countdown
    func startShutdownCountdown() {
        notificationFeedback.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1005)
        isShutdownActive = true
        shutdownCountdown = 15
        
        shutdownTimer?.invalidate()
        shutdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.shutdownCountdown > 0 {
                self.shutdownCountdown -= 1
            } else {
                self.shutdownTimer?.invalidate()
                self.shutdownTimer = nil
                self.isShutdownActive = false
            }
        }
    }

    func stopShutdownCountdown() {
        notificationFeedback.notificationOccurred(.success)
        shutdownTimer?.invalidate()
        shutdownTimer = nil
        isShutdownActive = false
    }

    // MARK: - File Transfer (Native Multipart Upload)
    func uploadFile(data: Data, filename: String, mimeType: String, progress: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseUrl)/api/files/upload") else {
            completion(false)
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        impactFeedback.impactOccurred()

        let task = URLSession.shared.uploadTask(with: request, from: body) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    self?.notificationFeedback.notificationOccurred(.success)
                    AudioServicesPlaySystemSound(1025)
                    self?.fetchFiles()
                    completion(true)
                } else {
                    self?.notificationFeedback.notificationOccurred(.error)
                    completion(false)
                }
            }
        }
        task.resume()
    }

    // MARK: - Vault Operations
    func fetchFiles() {
        guard let url = URL(string: "\(baseUrl)/api/files") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }
            struct FilesResponse: Codable {
                let files: [VaultItem]
            }
            if let decoded = try? JSONDecoder().decode(FilesResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.files = decoded.files
                }
            }
        }.resume()
    }

    func deleteFile(name: String) {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseUrl)/api/files/\(encoded)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.fetchFiles()
            }
        }.resume()
    }

    private func fetchLatestScreenshot() {
        fetchFiles()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let first = self.files.first(where: { $0.is_image }),
               let imgUrl = URL(string: "\(self.baseUrl)\(first.view_url)") {
                URLSession.shared.dataTask(with: imgUrl) { data, _, _ in
                    if let data = data, let img = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.latestScreenshot = img
                            self.showScreenshotSheet = true
                        }
                    }
                }.resume()
            }
        }
    }
}
