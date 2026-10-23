import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct SessionHubView: View {
    @ObservedObject public var session: AirPulseSession
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0 // 0 = Truyền File, 1 = Phím Tắt PC, 2 = Màn Hình
    @State private var urlToOpen: String = ""
    @State private var textToSend: String = ""
    @State private var showShutdownConfirm: Bool = false
    @State private var showRestartConfirm: Bool = false
    @State private var toastMessage: String?

    // File pickers
    @State private var isShowingDocumentPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    public init(session: AirPulseSession) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Navigation Segmented Bar
                segmentBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // Tab Content
                TabView(selection: $selectedTab) {
                    // Tab 0: Truyền File (File Transfer - Ưu tiên số 1)
                    fileTransferTab
                        .tag(0)

                    // Tab 1: Điều Khiển Nhanh (Quick Actions)
                    quickControlsTab
                        .tag(1)

                    // Tab 2: Màn Hình Máy Tính (Remote Desktop)
                    remoteScreenTab
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // Toast Overlay
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(22)
                    .shadow(radius: 8)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerRepresentable { url in
                session.fileTransferManager?.sendFile(url: url)
                showToast("Đang gửi tệp: \(url.lastPathComponent)")
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
        .onChange(of: selectedPhotos) { items in
            guard !items.isEmpty else { return }
            handleSelectedPhotos(items)
        }
        .alert("Xác nhận tắt máy", isPresented: $showShutdownConfirm) {
            Button("Hủy", role: .cancel) {}
            Button("Tắt máy tính PC", role: .destructive) {
                session.shutdownPc()
                showToast("Đã gửi lệnh tắt máy tính")
            }
        } message: {
            Text("Bạn có chắc chắn muốn tắt máy tính PC từ xa không?")
        }
        .alert("Xác nhận khởi động lại", isPresented: $showRestartConfirm) {
            Button("Hủy", role: .cancel) {}
            Button("Khởi động lại", role: .destructive) {
                session.restartPc()
                showToast("Đã gửi lệnh khởi động lại PC")
            }
        } message: {
            Text("Bạn có chắc chắn muốn khởi động lại máy tính PC không?")
        }
    }

    // MARK: - Header Bar

    private var topHeaderBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 9, height: 9)
                    .shadow(color: .green, radius: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.hostIp.isEmpty ? "PC Đã Kết Nối" : session.hostIp)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Đang kết nối • \(session.latencyMs)ms")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: {
                session.disconnect()
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Ngắt kết nối")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Segment Bar

    private var segmentBar: some View {
        HStack(spacing: 6) {
            segmentButton("📁 Truyền File", index: 0, icon: "arrow.up.arrow.down.circle.fill")
            segmentButton("⚡ Phím Tắt PC", index: 1, icon: "slider.horizontal.3")
            segmentButton("🖥️ Màn Hình", index: 2, icon: "display")
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private func segmentButton(_ title: String, index: Int, icon: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { selectedTab = index }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selectedTab == index ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color.blue : Color.clear)
            .cornerRadius(9)
        }
    }

    // MARK: - TAB 0: File Transfer (Chính)

    private var fileTransferTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: { isShowingPhotoPicker = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 26))
                            Text("Gửi Ảnh / Video")
                                .font(.system(size: 14, weight: .bold))
                            Text("Từ Thư viện iPhone")
                                .font(.system(size: 11))
                                .opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(14)
                        .shadow(color: .purple.opacity(0.3), radius: 6)
                    }

                    Button(action: { isShowingDocumentPicker = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 26))
                            Text("Gửi Tệp Tin")
                                .font(.system(size: 14, weight: .bold))
                            Text("PDF, Zip, Word...")
                                .font(.system(size: 11))
                                .opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(14)
                        .shadow(color: .cyan.opacity(0.3), radius: 6)
                    }
                }
                .padding(.horizontal, 16)

                // Quick Send Text / Clipboard
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gửi Văn Bản / Link sang PC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)

                    HStack(spacing: 8) {
                        TextField("Nhập nội dung muốn dán lên PC...", text: $textToSend)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        Button(action: sendQuickText) {
                            Text("Gửi")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(textToSend.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(textToSend.isEmpty)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .padding(.horizontal, 16)

                // Transfer History & Progress List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tiến trình truyền tải")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if let count = session.fileTransferManager?.transfers.count, count > 0 {
                            Text("\(count) tệp")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    if let manager = session.fileTransferManager, !manager.transfers.isEmpty {
                        ForEach(manager.transfers) { item in
                            transferCard(item)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 38))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("Chưa có tệp nào được truyền")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text("File gửi từ iPhone sẽ được tự động lưu vào thư mục Downloads\\AirPulse trên máy tính PC.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private func transferCard(_ item: TransferItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: item.direction == .upload ? "arrow.up.doc.fill" : "arrow.down.doc.fill")
                    .font(.system(size: 22))
                    .foregroundColor(item.status == .completed ? .green : .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formatBytes(item.fileSize))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        if item.status == .transferring {
                            Text("• \(formatSpeed(item.speedBytesPerSec))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cyan)
                        } else {
                            Text("• \(item.status.rawValue)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(item.status == .completed ? .green : (item.status == .failed ? .red : .gray))
                        }
                    }
                }

                Spacer()

                if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if item.status == .transferring {
                ProgressView(value: item.progress)
                    .tint(.cyan)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    // MARK: - TAB 1: Quick Controls (Âm lượng, Web, Tắt máy)

    private var quickControlsTab: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Section: Mở Web Trên Máy Tính
                webSection
                    .padding(.horizontal, 16)

                // Section: Âm lượng & Media
                mediaAndVolumeSection
                    .padding(.horizontal, 16)

                // Section: Nguồn & Hệ Thống
                systemPowerSection
                    .padding(.horizontal, 16)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var webSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mở Trang Web Trên Máy Tính", systemImage: "globe.asia.australia.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)

            HStack(spacing: 8) {
                TextField("Ví dụ: youtube.com hoặc link web...", text: $urlToOpen)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(11)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white)

                Button(action: openUrlAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Mở PC")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(urlToOpen.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(urlToOpen.isEmpty)
            }

            // Quick Web Shortcuts
            HStack(spacing: 8) {
                quickWebButton("YouTube", url: "https://youtube.com", icon: "play.rectangle.fill", color: .red)
                quickWebButton("Google", url: "https://google.com", icon: "magnifyingglass", color: .blue)
                quickWebButton("ChatGPT", url: "https://chatgpt.com", icon: "sparkles", color: .green)
                quickWebButton("Facebook", url: "https://facebook.com", icon: "person.2.fill", color: .cyan)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private func quickWebButton(_ title: String, url: String, icon: String, color: Color) -> some View {
        Button(action: {
            session.openUrlOnPc(url)
            showToast("Đang mở \(title) trên PC")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.25))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1))
        }
    }

    private var mediaAndVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Âm Lượng & Đa Phương Tiện", systemImage: "speaker.wave.3.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)

            // Volume Controls (3 Buttons)
            HStack(spacing: 10) {
                controlTileButton(title: "Giảm Âm", icon: "speaker.minus.fill", color: .blue) {
                    session.volumeDown()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                controlTileButton(title: "Tắt Tiếng", icon: "speaker.slash.fill", color: .orange) {
                    session.volumeMute()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                controlTileButton(title: "Tăng Âm", icon: "speaker.plus.fill", color: .blue) {
                    session.volumeUp()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }

            // Media Controls (Prev, Play/Pause, Next)
            HStack(spacing: 10) {
                controlTileButton(title: "Bài Trước", icon: "backward.fill", color: .indigo) {
                    session.mediaPrev()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                controlTileButton(title: "Play / Pause", icon: "playpause.fill", color: .purple) {
                    session.mediaPlayPause()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                controlTileButton(title: "Bài Tiếp", icon: "forward.fill", color: .indigo) {
                    session.mediaNext()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private var systemPowerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bật Tắt & Hệ Thống", systemImage: "power")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                systemButton(title: "Khóa Máy (Lock)", icon: "lock.fill", color: .blue) {
                    session.lockPc()
                    showToast("Đã khóa màn hình PC")
                }

                systemButton(title: "Chế Độ Ngủ (Sleep)", icon: "moon.fill", color: .indigo) {
                    session.sleepPc()
                    showToast("Đã đưa PC vào chế độ Sleep")
                }

                systemButton(title: "Dán Clipboard", icon: "doc.on.clipboard.fill", color: .teal) {
                    if let text = UIPasteboard.general.string, !text.isEmpty {
                        session.pasteTextToPc(text)
                        showToast("Đã dán văn bản từ iPhone vào PC")
                    } else {
                        showToast("Clipboard iPhone đang trống")
                    }
                }

                systemButton(title: "Khởi Động Lại", icon: "arrow.clockwise", color: .orange) {
                    showRestartConfirm = true
                }
            }

            // Big Shutdown Button
            Button(action: { showShutdownConfirm = true }) {
                HStack {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 18))
                    Text("Tắt Máy Tính PC")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.15))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private func controlTileButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.2))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.35), lineWidth: 1))
        }
    }

    private func systemButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .cornerRadius(10)
        }
    }

    // MARK: - TAB 2: Remote Desktop (Màn hình PC)

    private var remoteScreenTab: some View {
        RemoteDesktopView(session: session)
    }

    // MARK: - Helpers

    private func sendQuickText() {
        guard !textToSend.isEmpty else { return }
        session.pasteTextToPc(textToSend)
        showToast("Đã gửi văn bản sang PC")
        textToSend = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func openUrlAction() {
        guard !urlToOpen.isEmpty else { return }
        session.openUrlOnPc(urlToOpen)
        showToast("Đã mở link trên trình duyệt PC")
        urlToOpen = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let tempUrl = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try? data.write(to: tempUrl)
                    session.fileTransferManager?.sendFile(url: tempUrl)
                }
            }
            await MainActor.run {
                selectedPhotos.removeAll()
                showToast("Đang gửi \(items.count) ảnh sang PC")
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        return "\(formatBytes(Int64(bytesPerSec)))/s"
    }
}

// MARK: - Document Picker UIViewControllerRepresentable

private struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                onPick(first)
            }
        }
    }
}
