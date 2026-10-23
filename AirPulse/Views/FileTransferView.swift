import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

public struct FileTransferView: View {
    @ObservedObject public var session: AirPulseSession
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDocumentPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var shareUrl: URL?
    @State private var isShowingShareSheet = false

    public init(session: AirPulseSession) {
        self.session = session
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 16) {
                    // Send Buttons
                    HStack(spacing: 12) {
                        Button(action: { isShowingDocumentPicker = true }) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Gửi tệp (Files)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                        }

                        Button(action: { isShowingPhotoPicker = true }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Gửi ảnh / video")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Transfer List Header
                    HStack {
                        Text("Tiến trình truyền tải")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if let manager = session.fileTransferManager, !manager.transfers.isEmpty {
                            Text("\(manager.transfers.count) mục")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)

                    // Transfer List
                    if let manager = session.fileTransferManager, !manager.transfers.isEmpty {
                        List {
                            ForEach(manager.transfers) { item in
                                transferRow(item)
                                    .listRowBackground(Color.white.opacity(0.06))
                                    .listRowSeparatorTint(Color.white.opacity(0.1))
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Chưa có phiên truyền tải nào")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Text("Chọn nút phía trên để gửi file từ iPhone sang máy tính, hoặc chọn gửi file trên PC.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Truyền Tệp Hai Chiều")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerWrapper { url in
                    uploadFile(url: url)
                }
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .any(of: [.images, .videos]))
            .onChange(of: selectedPhotoItem) { item in
                guard let item = item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("photo_\(UUID().uuidString.prefix(6)).jpg")
                        try? data.write(to: tempUrl)
                        uploadFile(url: tempUrl)
                    }
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let u = shareUrl {
                    ActivityView(activityItems: [u])
                }
            }
        }
    }

    private func transferRow(_ item: TransferItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: item.direction == .upload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(item.direction == .upload ? .cyan : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formatBytes(item.transferredBytes) + " / " + formatBytes(item.fileSize))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        if item.status == .transferring && item.speedBytesPerSec > 0 {
                            Text("• \(formatSpeed(item.speedBytesPerSec))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                    }
                }

                Spacer()

                statusBadge(item)
            }

            // Progress bar
            ProgressView(value: item.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: item.status == .completed ? Color.green : Color.blue))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.status == .completed, let u = item.localUrl {
                self.shareUrl = u
                self.isShowingShareSheet = true
            }
        }
    }

    private func statusBadge(_ item: TransferItem) -> some View {
        Text(item.status.rawValue)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor(item.status).opacity(0.2))
            .foregroundColor(badgeColor(item.status))
            .cornerRadius(6)
    }

    private func badgeColor(_ status: TransferStatus) -> Color {
        switch status {
        case .completed: return .green
        case .transferring: return .blue
        case .pending: return .orange
        case .paused: return .yellow
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    private func uploadFile(url: URL) {
        guard let mgr = session.fileTransferManager else { return }
        Task {
            try? await mgr.sendFile(from: url)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024.0
        if kb > 1024.0 {
            return String(format: "%.1f MB/s", kb / 1024.0)
        }
        return String(format: "%.0f KB/s", kb)
    }
}

// MARK: - Document Picker UIViewControllerRepresentable

public struct DocumentPickerWrapper: UIViewControllerRepresentable {
    public let onPick: (URL) -> Void

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerWrapper
        init(_ parent: DocumentPickerWrapper) { self.parent = parent }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                parent.onPick(first)
            }
        }
    }
}

// MARK: - Share Sheet Wrapper

public struct ActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
