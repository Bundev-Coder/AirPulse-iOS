import Foundation
import UIKit
import Combine
import CoreMedia

public enum SessionState {
    case disconnected
    case connecting
    case authenticating
    case streaming
    case failed(String)
}

public final class AirPulseSession: ObservableObject, H264DecoderDelegate {
    @Published public var state: SessionState = .disconnected
    @Published public var latencyMs: Int = 0
    @Published public var currentFps: Int = 0
    @Published public var currentBitrateKbps: Int = 0
    @Published public var displays: [DisplayInfo] = []
    @Published public var activeDisplayIndex: Int32 = 0
    @Published public var isDirectTouchMode: Bool = false
    @Published public var isKeyboardVisible: Bool = false
    @Published public var incomingClipboardText: String?

    public weak var videoRendererView: VideoSampleLayerUIView?

    private let controlClient = TlsClient()
    private let videoClient = TlsClient()
    private let fileClient = TlsClient()
    private let decoder = H264Decoder()

    public var fileTransferManager: FileTransferManager?

    private var sessionId: String = ""
    public private(set) var hostIp: String = ""
    private var controlPort: UInt16 = 7001
    private var videoPort: UInt16 = 7002
    private var filePort: UInt16 = 7003
    private var certFingerprint: String = ""

    private var frameCounter: Int = 0
    private var lastFpsTimestamp = Date()
    private var isRunning: Bool = false
    private var tasks: [Task<Void, Never>] = []

    // Cursor position for Trackpad mode (0.0 to 1.0)
    public var cursorX: Float = 0.5
    public var cursorY: Float = 0.5

    public init() {
        decoder.delegate = self
    }

    // MARK: - Connect & Handshake

    public func connect(hostIp: String, controlPort: UInt16 = 7001, expectedFingerprint: String? = nil, pairingToken: Data? = nil, pin: String? = nil) async {
        await MainActor.run { self.state = .connecting }
        self.hostIp = hostIp
        self.controlPort = controlPort
        self.certFingerprint = expectedFingerprint ?? ""

        do {
            // 1. Connect Control Channel
            try await controlClient.connect(host: hostIp, port: controlPort, expectedFingerprint: expectedFingerprint)

            await MainActor.run { self.state = .authenticating }

            // 2. Send HELLO
            let (clientId, deviceSecret) = KeychainManager.shared.getOrCreateClientIdentity()
            let deviceName = UIDevice.current.name
            let hello = HelloMessage(clientId: clientId, deviceName: deviceName)
            try await controlClient.sendFrame(type: MessageType.hello, payload: hello.encode())

            // 3. Receive HELLO_ACK
            guard let ackFrame = try await controlClient.readFrame(),
                  ackFrame.header.messageType == MessageType.helloAck,
                  let ack = HelloAckMessage(from: ackFrame.payload) else {
                throw TlsClientError.protocolViolation("Không nhận được HELLO_ACK")
            }

            self.sessionId = ack.sessionId
            self.videoPort = UInt16(ack.videoPort)
            self.filePort = UInt16(ack.filePort)

            // 4. Pairing / Authentication
            let isAlreadyTrusted = KeychainManager.shared.getPairedHosts().contains { $0.id == ack.hostName || $0.lastKnownIp == hostIp }
            let shouldPair = (pairingToken != nil || pin != nil) || !isAlreadyTrusted

            if shouldPair {
                // New Pairing
                let token = pairingToken ?? PairingManager.shared.createPinToken(pin: pin ?? "")
                let method = pairingToken != nil ? "qr" : "pin"
                let req = PairingRequest(
                    method: method,
                    token: token,
                    deviceName: deviceName,
                    devicePublicKey: deviceSecret.withUnsafeBytes { Data($0) },
                    deviceId: clientId
                )
                try await controlClient.sendFrame(type: MessageType.pairingRequest, payload: req.encode())

                guard let respFrame = try await controlClient.readFrame(),
                      respFrame.header.messageType == MessageType.pairingResponse,
                      let resp = PairingResponse(from: respFrame.payload) else {
                    throw TlsClientError.protocolViolation("Không nhận được PAIRING_RESPONSE")
                }

                guard resp.accepted else {
                    throw TlsClientError.protocolViolation("Ghép đôi bị từ chối: \(resp.rejectReason)")
                }

                // Save to trusted Keychain
                let pairedHost = PairedHost(
                    id: ack.hostName,
                    name: ack.hostName,
                    lastKnownIp: hostIp,
                    controlPort: controlPort,
                    certFingerprint: self.certFingerprint,
                    deviceSecret: deviceSecret.withUnsafeBytes { Data($0).hexString }
                )
                KeychainManager.shared.savePairedHost(pairedHost)
            } else {
                // Existing trusted host — AUTH_CHALLENGE
                guard let challengeFrame = try await controlClient.readFrame(),
                      challengeFrame.header.messageType == MessageType.authChallenge,
                      let challenge = AuthChallenge(from: challengeFrame.payload) else {
                    throw TlsClientError.protocolViolation("Không nhận được AUTH_CHALLENGE")
                }

                let signed = PairingManager.shared.computeAuthResponse(
                    nonce: challenge.nonce,
                    timestampMs: challenge.timestampMs,
                    deviceKey: deviceSecret
                )
                let authResp = AuthResponse(signedNonce: signed, deviceId: clientId)
                try await controlClient.sendFrame(type: MessageType.authResponse, payload: authResp.encode())
            }

            // 5. Send SESSION_START
            let startMsg = SessionStartMessage(displayIndex: 0)
            try await controlClient.sendFrame(type: MessageType.sessionStart, payload: startMsg.encode())

            // 6. Receive DISPLAY_LIST
            if let dispFrame = try await controlClient.readFrame(),
               dispFrame.header.messageType == MessageType.displayList,
               let dispList = DisplayListMessage(from: dispFrame.payload) {
                await MainActor.run {
                    self.displays = dispList.displays
                }
            }

            // 7. Connect Secondary Channels (Video & File)
            try await videoClient.connect(host: hostIp, port: self.videoPort, expectedFingerprint: expectedFingerprint)
            try await fileClient.connect(host: hostIp, port: self.filePort, expectedFingerprint: expectedFingerprint)

            // Send 36-byte ASCII sessionId immediately on secondary channels
            var sessionBytes = sessionId.data(using: .ascii) ?? Data()
            while sessionBytes.count < 36 { sessionBytes.append(0x20) } // pad if needed
            sessionBytes = sessionBytes.prefix(36)

            try await videoClient.sendRaw(data: sessionBytes)
            try await fileClient.sendRaw(data: sessionBytes)

            // Attach FileTransferManager
            self.fileTransferManager = FileTransferManager(client: self.fileClient)
            self.fileTransferManager?.start()

            self.isRunning = true
            await MainActor.run { self.state = .streaming }

            // 8. Start Background loops
            let t1 = Task { await self.runVideoLoop() }
            let t2 = Task { await self.runControlLoop() }
            tasks.append(contentsOf: [t1, t2])

        } catch {
            await MainActor.run {
                self.state = .failed(error.localizedDescription)
            }
            disconnect()
        }
    }

    // MARK: - Video Receiver Loop

    private func runVideoLoop() async {
        while isRunning {
            do {
                guard let (header, payload) = try await videoClient.readFrame() else { break }
                guard header.messageType == 0x01 else { continue } // Video payload

                if payload.count > AirPulseWire.videoHeaderSize {
                    guard let vh = VideoFrameHeader(from: payload.prefix(AirPulseWire.videoHeaderSize)) else { continue }
                    let nalData = payload.dropFirst(AirPulseWire.videoHeaderSize)

                    decoder.decodeFrame(nalData: Data(nalData))

                    frameCounter += 1
                    let now = Date()
                    let elapsed = now.timeIntervalSince(lastFpsTimestamp)
                    if elapsed >= 1.0 {
                        let fps = Int(Double(frameCounter) / elapsed)
                        let kbps = Int(Double(payload.count * 8) / elapsed / 1000.0)
                        frameCounter = 0
                        lastFpsTimestamp = now
                        await MainActor.run {
                            self.currentFps = fps
                            self.currentBitrateKbps = kbps
                        }
                    }
                }
            } catch {
                break
            }
        }
    }

    // MARK: - Control Receiver Loop

    private func runControlLoop() async {
        while isRunning {
            do {
                guard let (header, payload) = try await controlClient.readFrame() else { break }

                switch header.messageType {
                case MessageType.ping:
                    let rttStart = Date()
                    let pong = PongMessage(from: payload)
                    let now = Date()
                    let rtt = Int(now.timeIntervalSince(rttStart) * 1000)
                    await MainActor.run { self.latencyMs = max(1, rtt) }
                    // Send Pong back
                    let pOut = ProtoWriter()
                    pOut.writeInt64(field: 1, value: pong.timestampMs)
                    pOut.writeInt64(field: 2, value: pong.timestampMs)
                    try await controlClient.sendFrame(type: MessageType.pong, payload: pOut.data)

                case MessageType.clipboardText:
                    if let clip = ClipboardTextMessage(from: payload) {
                        await MainActor.run {
                            self.incomingClipboardText = clip.text
                            UIPasteboard.general.string = clip.text
                        }
                    }

                case MessageType.disconnect:
                    await MainActor.run {
                        self.state = .disconnected
                    }
                    disconnect()
                    return

                default:
                    break
                }
            } catch {
                break
            }
        }
    }

    // MARK: - Input Controls

    public func sendMouseMove(normX: Float, normY: Float) {
        let clampedX = min(max(normX, 0.0), 1.0)
        let clampedY = min(max(normY, 0.0), 1.0)
        self.cursorX = clampedX
        self.cursorY = clampedY

        let event = MouseMoveEvent(normX: clampedX, normY: clampedY)
        Task {
            try? await controlClient.sendFrame(type: MessageType.mouseMove, payload: event.encode())
        }
    }

    public func sendTrackpadDelta(dx: Float, dy: Float, sensitivity: Float = 0.001) {
        let newX = cursorX + (dx * sensitivity)
        let newY = cursorY + (dy * sensitivity)
        sendMouseMove(normX: newX, normY: newY)
    }

    public func sendMouseButton(button: MouseButtonType, action: MouseButtonAction) {
        let event = MouseButtonEvent(button: button, action: action, normX: cursorX, normY: cursorY)
        Task {
            try? await controlClient.sendFrame(type: MessageType.mouseButton, payload: event.encode())
        }
    }

    public func sendMouseClick(button: MouseButtonType) {
        sendMouseButton(button: button, action: .down)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            self.sendMouseButton(button: button, action: .up)
        }
    }

    public func sendMouseScroll(deltaX: Float, deltaY: Float) {
        let event = MouseScrollEvent(deltaX: deltaX, deltaY: deltaY)
        Task {
            try? await controlClient.sendFrame(type: MessageType.mouseScroll, payload: event.encode())
        }
    }

    public func sendKeyEvent(vkCode: UInt32, keyDown: Bool, extended: Bool = false, modifiers: [UInt32] = []) {
        let event = KeyEvent(vkCode: vkCode, keyDown: keyDown, extended: extended, modifiers: modifiers)
        Task {
            try? await controlClient.sendFrame(type: MessageType.keyEvent, payload: event.encode())
        }
    }

    public func sendKeyPress(vkCode: UInt32, extended: Bool = false, modifiers: [UInt32] = []) {
        sendKeyEvent(vkCode: vkCode, keyDown: true, extended: extended, modifiers: modifiers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            self.sendKeyEvent(vkCode: vkCode, keyDown: false, extended: extended, modifiers: modifiers)
        }
    }

    public func sendTextInput(_ text: String) {
        let event = TextInputEvent(text: text)
        Task {
            try? await controlClient.sendFrame(type: MessageType.textInput, payload: event.encode())
        }
    }

    public func sendDisplaySelect(displayIndex: Int32) {
        self.activeDisplayIndex = displayIndex
        let event = DisplaySelectMessage(displayIndex: displayIndex)
        Task {
            try? await controlClient.sendFrame(type: MessageType.displaySelect, payload: event.encode())
        }
    }

    public func sendClipboardSync(_ text: String) {
        let msg = ClipboardTextMessage(text: text)
        Task {
            try? await controlClient.sendFrame(type: MessageType.clipboardText, payload: msg.encode())
        }
    }

    // MARK: - System & Quick Commands (Volume, Web, Media, Power)

    public func sendSystemCommand(_ command: String, param: String = "") {
        let msg = SystemCommandMessage(command: command, param: param)
        Task {
            try? await controlClient.sendFrame(type: MessageType.systemCommand, payload: msg.encode())
        }
    }

    public func volumeUp() { sendSystemCommand("volume_up") }
    public func volumeDown() { sendSystemCommand("volume_down") }
    public func volumeMute() { sendSystemCommand("volume_mute") }

    public func mediaPlayPause() { sendSystemCommand("media_play_pause") }
    public func mediaNext() { sendSystemCommand("media_next") }
    public func mediaPrev() { sendSystemCommand("media_prev") }

    public func openUrlOnPc(_ url: String) { sendSystemCommand("open_url", param: url) }
    public func lockPc() { sendSystemCommand("lock") }
    public func sleepPc() { sendSystemCommand("sleep") }
    public func shutdownPc() { sendSystemCommand("shutdown") }
    public func restartPc() { sendSystemCommand("restart") }
    public func pasteTextToPc(_ text: String) { sendSystemCommand("paste_text", param: text) }

    // MARK: - H264DecoderDelegate

    public func decoder(_ decoder: H264Decoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.videoRendererView?.enqueue(sampleBuffer)
        }
    }

    // MARK: - Disconnect

    public func disconnect() {
        isRunning = false
        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        controlClient.disconnect()
        videoClient.disconnect()
        fileClient.disconnect()
        fileTransferManager?.stop()

        DispatchQueue.main.async {
            self.state = .disconnected
            self.videoRendererView?.flush()
        }
    }
}

// MARK: - Pong message helper
fileprivate struct PongMessage {
    var timestampMs: Int64 = 0
    init(from data: Data) {
        let r = ProtoReader(data: data)
        while let (f, w) = r.nextField() {
            if f == 1 { timestampMs = r.readInt64() ?? 0 }
            else { r.skip(wireType: w) }
        }
    }
}
