import Foundation

// MARK: - Handshake Messages

public struct HelloMessage {
    public var clientVersion: String = "1.0.0"
    public var clientId: String = UUID().uuidString
    public var deviceName: String = "iPhone"
    public var caps: [String] = ["h264", "clipboard", "file", "multi_display"]
    public var publicKey: Data = Data()
    public var platform: String = "ios"

    public init(clientId: String, deviceName: String, publicKey: Data = Data()) {
        self.clientId = clientId
        self.deviceName = deviceName
        self.publicKey = publicKey
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: clientVersion)
        w.writeString(field: 2, value: clientId)
        w.writeString(field: 3, value: deviceName)
        for c in caps { w.writeString(field: 4, value: c) }
        w.writeBytes(field: 5, value: publicKey)
        w.writeString(field: 6, value: platform)
        return w.data
    }
}

public struct DisplayInfo: Identifiable, Hashable {
    public var id: Int32 { index }
    public var index: Int32 = 0
    public var name: String = ""
    public var width: Int32 = 1920
    public var height: Int32 = 1080
    public var scale: Float = 1.0
    public var isPrimary: Bool = false
    public var refreshHz: Float = 60.0

    public init(from r: ProtoReader) {
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: index = r.readInt32() ?? 0
            case 2: name = r.readString() ?? ""
            case 3: width = r.readInt32() ?? 0
            case 4: height = r.readInt32() ?? 0
            case 5: scale = r.readFloat() ?? 1.0
            case 6: isPrimary = r.readBool() ?? false
            case 7: refreshHz = r.readFloat() ?? 60.0
            default: r.skip(wireType: wire)
            }
        }
    }
}

public struct HelloAckMessage {
    public var sessionId: String = ""
    public var hostName: String = ""
    public var hostVersion: String = ""
    public var displays: [DisplayInfo] = []
    public var publicKey: Data = Data()
    public var certificateDer: Data = Data()
    public var controlPort: Int32 = 7001
    public var videoPort: Int32 = 7002
    public var filePort: Int32 = 7003

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: sessionId = r.readString() ?? ""
            case 2: hostName = r.readString() ?? ""
            case 3: hostVersion = r.readString() ?? ""
            case 4:
                if let sub = r.readBytes() {
                    displays.append(DisplayInfo(from: ProtoReader(data: sub)))
                }
            case 5: publicKey = r.readBytes() ?? Data()
            case 6: certificateDer = r.readBytes() ?? Data()
            case 7: controlPort = r.readInt32() ?? 7001
            case 8: videoPort = r.readInt32() ?? 7002
            case 9: filePort = r.readInt32() ?? 7003
            default: r.skip(wireType: wire)
            }
        }
    }
}

// MARK: - Pairing & Auth Messages

public struct PairingRequest {
    public var method: String // "qr" | "pin"
    public var token: Data
    public var deviceName: String
    public var devicePublicKey: Data
    public var deviceId: String

    public init(method: String, token: Data, deviceName: String, devicePublicKey: Data, deviceId: String) {
        self.method = method
        self.token = token
        self.deviceName = deviceName
        self.devicePublicKey = devicePublicKey
        self.deviceId = deviceId
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: method)
        w.writeBytes(field: 2, value: token)
        w.writeString(field: 3, value: deviceName)
        w.writeBytes(field: 4, value: devicePublicKey)
        w.writeString(field: 5, value: deviceId)
        return w.data
    }
}

public struct PairingResponse {
    public var accepted: Bool = false
    public var deviceId: String = ""
    public var rejectReason: String = ""
    public var requireConfirmation: String = ""

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: accepted = r.readBool() ?? false
            case 2: deviceId = r.readString() ?? ""
            case 3: rejectReason = r.readString() ?? ""
            case 4: requireConfirmation = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
    }
}

public struct AuthChallenge {
    public var nonce: Data = Data()
    public var timestampMs: Int64 = 0

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: nonce = r.readBytes() ?? Data()
            case 2: timestampMs = r.readInt64() ?? 0
            default: r.skip(wireType: wire)
            }
        }
    }
}

public struct AuthResponse {
    public var signedNonce: Data
    public var deviceId: String

    public init(signedNonce: Data, deviceId: String) {
        self.signedNonce = signedNonce
        self.deviceId = deviceId
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeBytes(field: 1, value: signedNonce)
        w.writeString(field: 2, value: deviceId)
        return w.data
    }
}

// MARK: - Session Messages

public struct QualitySettings {
    public var targetFps: Int32 = 60
    public var targetBitrateKbps: Int32 = 5000
    public var maxWidth: Int32 = 0
    public var maxHeight: Int32 = 0
    public var scaleFactor: Float = 1.0
    public var encoderPreset: String = "speed"

    public init(targetFps: Int32 = 60, targetBitrateKbps: Int32 = 5000, scaleFactor: Float = 1.0) {
        self.targetFps = targetFps
        self.targetBitrateKbps = targetBitrateKbps
        self.scaleFactor = scaleFactor
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeInt32(field: 1, value: targetFps)
        w.writeInt32(field: 2, value: targetBitrateKbps)
        w.writeInt32(field: 3, value: maxWidth)
        w.writeInt32(field: 4, value: maxHeight)
        w.writeFloat(field: 5, value: scaleFactor)
        w.writeString(field: 6, value: encoderPreset)
        return w.data
    }
}

public struct SessionStartMessage {
    public var displayIndex: Int32 = 0
    public var quality: QualitySettings = QualitySettings()
    public var enableClipboard: Bool = true

    public init(displayIndex: Int32 = 0, quality: QualitySettings = QualitySettings(), enableClipboard: Bool = true) {
        self.displayIndex = displayIndex
        self.quality = quality
        self.enableClipboard = enableClipboard
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeInt32(field: 1, value: displayIndex)
        w.writeMessage(field: 2, submessage: quality.encode())
        w.writeBool(field: 3, value: enableClipboard)
        return w.data
    }
}

// MARK: - Input Messages

public struct MouseMoveEvent {
    public var normX: Float
    public var normY: Float
    public var timestampUs: Int64

    public init(normX: Float, normY: Float) {
        self.normX = normX
        self.normY = normY
        self.timestampUs = Int64(Date().timeIntervalSince1970 * 1_000_000)
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeFloat(field: 1, value: normX)
        w.writeFloat(field: 2, value: normY)
        w.writeInt64(field: 3, value: timestampUs)
        return w.data
    }
}

public enum MouseButtonType: Int32 {
    case left = 0
    case right = 1
    case middle = 2
}

public enum MouseButtonAction: Int32 {
    case down = 0
    case up = 1
    case click = 2
    case doubleClick = 3
}

public struct MouseButtonEvent {
    public var button: MouseButtonType
    public var action: MouseButtonAction
    public var normX: Float
    public var normY: Float

    public init(button: MouseButtonType, action: MouseButtonAction, normX: Float, normY: Float) {
        self.button = button
        self.action = action
        self.normX = normX
        self.normY = normY
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeInt32(field: 1, value: button.rawValue)
        w.writeInt32(field: 2, value: action.rawValue)
        w.writeFloat(field: 3, value: normX)
        w.writeFloat(field: 4, value: normY)
        return w.data
    }
}

public struct MouseScrollEvent {
    public var deltaX: Float
    public var deltaY: Float

    public init(deltaX: Float, deltaY: Float) {
        self.deltaX = deltaX
        self.deltaY = deltaY
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeFloat(field: 1, value: deltaX)
        w.writeFloat(field: 2, value: deltaY)
        return w.data
    }
}

public struct KeyEvent {
    public var vkCode: UInt32
    public var keyDown: Bool
    public var extended: Bool
    public var modifiers: [UInt32]
    public var isUnicode: Bool
    public var unicodeChar: UInt32

    public init(vkCode: UInt32, keyDown: Bool, extended: Bool = false, modifiers: [UInt32] = []) {
        self.vkCode = vkCode
        self.keyDown = keyDown
        self.extended = extended
        self.modifiers = modifiers
        self.isUnicode = false
        self.unicodeChar = 0
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeUInt32(field: 1, value: vkCode)
        w.writeBool(field: 2, value: keyDown)
        w.writeBool(field: 3, value: extended)
        for m in modifiers { w.writeUInt32(field: 4, value: m) }
        w.writeBool(field: 5, value: isUnicode)
        w.writeUInt32(field: 6, value: unicodeChar)
        return w.data
    }
}

public struct TextInputEvent {
    public var text: String

    public init(text: String) {
        self.text = text
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: text)
        return w.data
    }
}

public struct ClipboardTextMessage {
    public var text: String
    public var sourceDeviceId: String
    public var timestampMs: Int64

    public init(text: String, sourceDeviceId: String = "ios") {
        self.text = text
        self.sourceDeviceId = sourceDeviceId
        self.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var t = "", s = ""
        var ts: Int64 = 0
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: t = r.readString() ?? ""
            case 2: s = r.readString() ?? ""
            case 3: ts = r.readInt64() ?? 0
            default: r.skip(wireType: wire)
            }
        }
        self.text = t
        self.sourceDeviceId = s
        self.timestampMs = ts
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: text)
        w.writeString(field: 2, value: sourceDeviceId)
        w.writeInt64(field: 3, value: timestampMs)
        return w.data
    }
}

// MARK: - Display Messages

public struct DisplayListMessage {
    public var displays: [DisplayInfo] = []

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        while let (field, wire) = r.nextField() {
            switch field {
            case 1:
                if let sub = r.readBytes() {
                    displays.append(DisplayInfo(from: ProtoReader(data: sub)))
                }
            default: r.skip(wireType: wire)
            }
        }
    }
}

public struct DisplaySelectMessage {
    public var displayIndex: Int32

    public init(displayIndex: Int32) {
        self.displayIndex = displayIndex
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeInt32(field: 1, value: displayIndex)
        return w.data
    }
}

// MARK: - File Transfer Messages

public struct FileSendRequest {
    public var fileId: String
    public var fileName: String
    public var fileSize: Int64
    public var sha256: Data
    public var chunkSize: Int32
    public var mimeType: String
    public var direction: String

    public init(fileId: String, fileName: String, fileSize: Int64, sha256: Data, chunkSize: Int32 = 262144, mimeType: String = "", direction: String = "ios_to_pc") {
        self.fileId = fileId
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256 = sha256
        self.chunkSize = chunkSize
        self.mimeType = mimeType
        self.direction = direction
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = "", name = "", mime = "", dir = ""
        var size: Int64 = 0, cSize: Int32 = 0
        var hash = Data()
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            case 2: name = r.readString() ?? ""
            case 3: size = r.readInt64() ?? 0
            case 4: hash = r.readBytes() ?? Data()
            case 5: cSize = r.readInt32() ?? 0
            case 6: mime = r.readString() ?? ""
            case 7: dir = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
        self.fileName = name
        self.fileSize = size
        self.sha256 = hash
        self.chunkSize = cSize
        self.mimeType = mime
        self.direction = dir
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        w.writeString(field: 2, value: fileName)
        w.writeInt64(field: 3, value: fileSize)
        w.writeBytes(field: 4, value: sha256)
        w.writeInt32(field: 5, value: chunkSize)
        w.writeString(field: 6, value: mimeType)
        w.writeString(field: 7, value: direction)
        return w.data
    }
}

public struct FileSendAccept {
    public var fileId: String
    public var resumeOffset: Int64

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = ""
        var off: Int64 = 0
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            case 2: off = r.readInt64() ?? 0
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
        self.resumeOffset = off
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        w.writeInt64(field: 2, value: resumeOffset)
        return w.data
    }
}

public struct FileChunk {
    public var fileId: String
    public var offset: Int64
    public var data: Data
    public var chunkSha256: Data

    public init(fileId: String, offset: Int64, data: Data, chunkSha256: Data) {
        self.fileId = fileId
        self.offset = offset
        self.data = data
        self.chunkSha256 = chunkSha256
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = ""
        var off: Int64 = 0
        var d = Data(), hash = Data()
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            case 2: off = r.readInt64() ?? 0
            case 3: d = r.readBytes() ?? Data()
            case 4: hash = r.readBytes() ?? Data()
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
        self.offset = off
        self.data = d
        self.chunkSha256 = hash
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        w.writeInt64(field: 2, value: offset)
        w.writeBytes(field: 3, value: data)
        w.writeBytes(field: 4, value: chunkSha256)
        return w.data
    }
}

public struct FileChunkAck {
    public var fileId: String
    public var offset: Int64
    public var ok: Bool
    public var error: String

    public init(fileId: String, offset: Int64, ok: Bool, error: String = "") {
        self.fileId = fileId
        self.offset = offset
        self.ok = ok
        self.error = error
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = "", err = ""
        var off: Int64 = 0
        var isOk = false
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            case 2: off = r.readInt64() ?? 0
            case 3: isOk = r.readBool() ?? false
            case 4: err = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
        self.offset = off
        self.ok = isOk
        self.error = err
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        w.writeInt64(field: 2, value: offset)
        w.writeBool(field: 3, value: ok)
        w.writeString(field: 4, value: error)
        return w.data
    }
}

public struct FileComplete {
    public var fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = ""
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        return w.data
    }
}

public struct FileCompleteAck {
    public var fileId: String
    public var sha256Verified: Bool
    public var savePath: String

    public init(fileId: String, sha256Verified: Bool, savePath: String = "") {
        self.fileId = fileId
        self.sha256Verified = sha256Verified
        self.savePath = savePath
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var fId = "", p = ""
        var v = false
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: fId = r.readString() ?? ""
            case 2: v = r.readBool() ?? false
            case 3: p = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
        self.fileId = fId
        self.sha256Verified = v
        self.savePath = p
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: fileId)
        w.writeBool(field: 2, value: sha256Verified)
        w.writeString(field: 3, value: savePath)
        return w.data
    }
}

// MARK: - System Command Message (Volume, Media, Open URL, Power)

public struct SystemCommandMessage {
    public var command: String
    public var param: String

    public init(command: String, param: String = "") {
        self.command = command
        self.param = param
    }

    public init?(from data: Data) {
        let r = ProtoReader(data: data)
        var cmd = ""
        var p = ""
        while let (field, wire) = r.nextField() {
            switch field {
            case 1: cmd = r.readString() ?? ""
            case 2: p = r.readString() ?? ""
            default: r.skip(wireType: wire)
            }
        }
        self.command = cmd
        self.param = p
    }

    public func encode() -> Data {
        let w = ProtoWriter()
        w.writeString(field: 1, value: command)
        w.writeString(field: 2, value: param)
        return w.data
    }
}
