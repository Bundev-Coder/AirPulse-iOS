import Foundation
import CryptoKit
import Photos
import UIKit
import Combine

public enum TransferDirection: String, Codable {
    case upload = "ios_to_pc"
    case download = "pc_to_ios"
}

public enum TransferStatus: String, Codable {
    case pending = "Đang chờ"
    case transferring = "Đang truyền"
    case paused = "Tạm dừng"
    case completed = "Hoàn tất"
    case failed = "Thất bại"
    case cancelled = "Đã hủy"
}

public final class TransferItem: Identifiable, ObservableObject {
    public let id: String // File UUID
    public let fileName: String
    public let fileSize: Int64
    public let direction: TransferDirection
    @Published public var transferredBytes: Int64 = 0
    @Published public var speedBytesPerSec: Double = 0
    @Published public var progress: Double = 0.0
    @Published public var status: TransferStatus = .pending
    @Published public var errorMessage: String?
    public var localUrl: URL?

    public init(
        id: String,
        fileName: String,
        fileSize: Int64,
        direction: TransferDirection,
        localUrl: URL? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.direction = direction
        self.localUrl = localUrl
    }
}

public final class FileTransferManager: ObservableObject {
    @Published public var transfers: [TransferItem] = []
    
    private let client: TlsClient
    private var isRunning: Bool = false
    private var readTask: Task<Void, Never>?
    
    private var activeInboundStreams: [String: (url: URL, handle: FileHandle, expectedHash: Data, receivedBytes: Int64, totalBytes: Int64, hasher: SHA256)] = [:]
    private var outboundAcks: [String: (acceptContinuation: CheckedContinuation<Int64, Error>?, chunkContinuation: CheckedContinuation<Bool, Error>?, completeContinuation: CheckedContinuation<Bool, Error>?)] = [:]

    public init(client: TlsClient) {
        self.client = client
    }

    public func start() {
        isRunning = true
        readTask = Task {
            await self.runFileReceiverLoop()
        }
    }

    public func stop() {
        isRunning = false
        readTask?.cancel()
        readTask = nil
    }

    // MARK: - Inbound Receiver Loop (PC -> iOS or Outbound Acks)

    private func runFileReceiverLoop() async {
        while isRunning {
            do {
                guard let (header, payload) = try await client.readFrame() else { break }

                switch header.messageType {
                case MessageType.fileSendRequest:
                    if let req = FileSendRequest(from: payload) {
                        await handleIncomingSendRequest(req)
                    }

                case MessageType.fileSendAccept:
                    if let accept = FileSendAccept(from: payload) {
                        outboundAcks[accept.fileId]?.acceptContinuation?.resume(returning: accept.resumeOffset)
                        outboundAcks[accept.fileId]?.acceptContinuation = nil
                    }

                case MessageType.fileSendReject:
                    if let rej = ProtoReader(data: payload).readString() {
                        let err = NSError(domain: "AirPulse", code: 403, userInfo: [NSLocalizedDescriptionKey: "Bị từ chối: \(rej)"])
                        // Cancel any pending outbound
                    }

                case MessageType.fileChunk:
                    if let chunk = FileChunk(from: payload) {
                        await handleIncomingChunk(chunk)
                    }

                case MessageType.fileChunkAck:
                    if let ack = FileChunkAck(from: payload) {
                        if ack.ok {
                            outboundAcks[ack.fileId]?.chunkContinuation?.resume(returning: true)
                        } else {
                            outboundAcks[ack.fileId]?.chunkContinuation?.resume(throwing: NSError(domain: "AirPulse", code: 500, userInfo: [NSLocalizedDescriptionKey: ack.error]))
                        }
                        outboundAcks[ack.fileId]?.chunkContinuation = nil
                    }

                case MessageType.fileComplete:
                    if let comp = FileComplete(from: payload) {
                        await handleIncomingComplete(comp)
                    }

                case MessageType.fileCompleteAck:
                    if let compAck = FileCompleteAck(from: payload) {
                        outboundAcks[compAck.fileId]?.completeContinuation?.resume(returning: compAck.sha256Verified)
                        outboundAcks[compAck.fileId]?.completeContinuation = nil
                    }

                default:
                    break
                }
            } catch {
                break
            }
        }
    }

    // MARK: - Incoming File Handling (PC -> iOS)

    private func handleIncomingSendRequest(_ req: FileSendRequest) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let saveUrl = docs.appendingPathComponent(req.fileName)

        do {
            if FileManager.default.fileExists(atPath: saveUrl.path) {
                try? FileManager.default.removeItem(at: saveUrl)
            }
            FileManager.default.createFile(atPath: saveUrl.path, contents: nil)
            let handle = try FileHandle(forWritingTo: saveUrl)

            activeInboundStreams[req.fileId] = (
                url: saveUrl,
                handle: handle,
                expectedHash: req.sha256,
                receivedBytes: 0,
                totalBytes: req.fileSize,
                hasher: SHA256()
            )

            let item = TransferItem(
                id: req.fileId,
                fileName: req.fileName,
                fileSize: req.fileSize,
                direction: .download,
                localUrl: saveUrl
            )
            item.status = .transferring

            await MainActor.run {
                self.transfers.insert(item, at: 0)
            }

            // Send FileSendAccept
            let accept = FileSendAccept(from: Data()) ?? FileSendAccept(from: Data())
            let w = ProtoWriter()
            w.writeString(field: 1, value: req.fileId)
            w.writeInt64(field: 2, value: 0)
            try await client.sendFrame(type: MessageType.fileSendAccept, payload: w.data)

        } catch {
            print("Lỗi tạo file nhận: \(error)")
        }
    }

    private func handleIncomingChunk(_ chunk: FileChunk) async {
        guard var inbound = activeInboundStreams[chunk.fileId] else { return }

        // Verify chunk hash
        let digest = SHA256.hash(data: chunk.data)
        let digestData = Data(digest)
        let isValid = chunk.chunkSha256.isEmpty || digestData == chunk.chunkSha256

        if isValid {
            try? inbound.handle.seek(toOffset: UInt64(chunk.offset))
            inbound.handle.write(chunk.data)
            inbound.hasher.update(data: chunk.data)
            inbound.receivedBytes += Int64(chunk.data.count)
            activeInboundStreams[chunk.fileId] = inbound

            await MainActor.run {
                if let item = self.transfers.first(where: { $0.id == chunk.fileId }) {
                    item.transferredBytes = inbound.receivedBytes
                    item.progress = inbound.totalBytes > 0 ? Double(inbound.receivedBytes) / Double(inbound.totalBytes) : 1.0
                }
            }
        }

        // Send Ack
        let ack = FileChunkAck(fileId: chunk.fileId, offset: chunk.offset, ok: isValid, error: isValid ? "" : "Hash chunk sai")
        try? await client.sendFrame(type: MessageType.fileChunkAck, payload: ack.encode())
    }

    private func handleIncomingComplete(_ complete: FileComplete) async {
        guard let inbound = activeInboundStreams.removeValue(forKey: complete.fileId) else { return }
        try? inbound.handle.close()

        let finalDigest = Data(inbound.hasher.finalize())
        let verified = inbound.expectedHash.isEmpty || finalDigest == inbound.expectedHash

        // If it's an image or video, optionally save to Photos
        if verified {
            let ext = inbound.url.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "heic", "mp4", "mov"].contains(ext) {
                saveToPhotoLibrary(url: inbound.url)
            }
        }

        let ack = FileCompleteAck(fileId: complete.fileId, sha256Verified: verified, savePath: inbound.url.path)
        try? await client.sendFrame(type: MessageType.fileCompleteAck, payload: ack.encode())

        await MainActor.run {
            if let item = self.transfers.first(where: { $0.id == complete.fileId }) {
                item.status = verified ? .completed : .failed
                item.progress = 1.0
                if !verified { item.errorMessage = "Sai mã SHA256" }
            }
        }
    }

    private func saveToPhotoLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                if ["mp4", "mov"].contains(url.pathExtension.lowercased()) {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            }, completionHandler: nil)
        }
    }

    // MARK: - Outgoing File Handling (iOS -> PC)

    public func sendFile(from localUrl: URL) async throws {
        let isAccessGranted = localUrl.startAccessingSecurityScopedResource()
        defer { if isAccessGranted { localUrl.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: localUrl)
        let fileName = localUrl.lastPathComponent
        let fileSize = Int64(fileData.count)
        let fileId = UUID().uuidString
        let totalHash = Data(SHA256.hash(data: fileData))

        let item = TransferItem(
            id: fileId,
            fileName: fileName,
            fileSize: fileSize,
            direction: .upload,
            localUrl: localUrl
        )
        item.status = .transferring

        await MainActor.run {
            self.transfers.insert(item, at: 0)
        }

        // 1. Send Request
        let req = FileSendRequest(
            fileId: fileId,
            fileName: fileName,
            fileSize: fileSize,
            sha256: totalHash,
            chunkSize: 262144, // 256KB
            direction: "ios_to_pc"
        )

        var resumeOffset: Int64 = 0
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
            self.outboundAcks[fileId] = (acceptContinuation: continuation, chunkContinuation: nil, completeContinuation: nil)
            Task {
                try await self.client.sendFrame(type: MessageType.fileSendRequest, payload: req.encode())
            }
        }

        // 2. Stream chunks
        let chunkSize = 262144
        var offset = Int(resumeOffset)
        let startTime = Date()

        while offset < fileData.count {
            let toRead = min(chunkSize, fileData.count - offset)
            let chunkData = fileData.subdata(in: offset..<(offset + toRead))
            let chunkHash = Data(SHA256.hash(data: chunkData))

            let chunkMsg = FileChunk(fileId: fileId, offset: Int64(offset), data: chunkData, chunkSha256: chunkHash)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                self.outboundAcks[fileId]?.chunkContinuation = continuation
                Task {
                    try await self.client.sendFrame(type: MessageType.fileChunk, payload: chunkMsg.encode())
                }
            }

            offset += toRead

            let elapsed = Date().timeIntervalSince(startTime)
            let speed = elapsed > 0.05 ? Double(offset) / elapsed : 0

            await MainActor.run {
                item.transferredBytes = Int64(offset)
                item.progress = fileSize > 0 ? Double(offset) / Double(fileSize) : 1.0
                item.speedBytesPerSec = speed
            }
        }

        // 3. Send Complete
        let comp = FileComplete(fileId: fileId)
        let verified = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            self.outboundAcks[fileId]?.completeContinuation = continuation
            Task {
                try await self.client.sendFrame(type: MessageType.fileComplete, payload: comp.encode())
            }
        }

        outboundAcks.removeValue(forKey: fileId)

        await MainActor.run {
            item.status = verified ? .completed : .failed
            item.progress = 1.0
            if !verified { item.errorMessage = "PC báo xác thực hash thất bại" }
        }
    }
}
