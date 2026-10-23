import SwiftUI
import AVFoundation

public struct PairingView: View {
    @ObservedObject public var session: AirPulseSession
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 1 // 1 = PIN (Default, most reliable), 0 = QR
    @State private var targetHostIp: String = ""
    @State private var pinCode: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var cameraUnavailable: Bool = false
    @FocusState private var isPinFieldFocused: Bool

    public init(session: AirPulseSession, initialIp: String = "") {
        self.session = session
        self._targetHostIp = State(initialValue: initialIp)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()

                VStack(spacing: 20) {
                    // Custom Segmented Picker
                    HStack(spacing: 0) {
                        tabButton("Nhập mã PIN", index: 1, icon: "number.circle.fill")
                        tabButton("Quét mã QR", index: 0, icon: "qrcode.viewfinder")
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    if selectedTab == 0 {
                        // QR Code Scanner View
                        VStack(spacing: 16) {
                            Text("Hướng camera về phía mã QR trên màn hình PC")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            if cameraUnavailable {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.slash.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.orange)
                                    Text("Camera chưa được cấp quyền hoặc không khả dụng")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    Text("Vui lòng cấp quyền Camera trong Cài đặt iPhone hoặc chuyển sang tab 'Nhập mã PIN' bên trên để ghép đôi ngay.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                    Button("Chuyển sang Nhập mã PIN") {
                                        selectedTab = 1
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .padding(.top, 4)
                                }
                                .frame(width: 280, height: 280)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(20)
                            } else {
                                ZStack {
                                    QRCodeScannerRepresentable(
                                        onCodeScanned: { qrCode in
                                            handleScannedQr(qrCode)
                                        },
                                        onPermissionDenied: {
                                            cameraUnavailable = true
                                        }
                                    )
                                    .frame(width: 280, height: 280)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                    )

                                    // Scanning laser line animation
                                    ScannerLineAnimation()
                                }
                                .frame(width: 280, height: 280)
                                .shadow(color: .cyan.opacity(0.3), radius: 15)
                            }

                            if let err = errorMessage {
                                Text(err)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top, 10)
                    } else {
                        // PIN Input View
                        VStack(spacing: 24) {
                            Text("Nhập mã PIN 6 số hiển thị trên ứng dụng AirPulse PC")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            // Target IP field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Địa chỉ IP của PC")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                TextField("Ví dụ: 192.168.1.15", text: $targetHostIp)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 28)

                            // 6-digit boxes
                            HStack(spacing: 10) {
                                ForEach(0..<6) { index in
                                    digitBox(index)
                                }
                            }
                            .padding(.vertical, 8)
                            .onTapGesture {
                                isPinFieldFocused = true
                            }

                            // Hidden TextField for numeric keyboard
                            TextField("", text: $pinCode)
                                .keyboardType(.numberPad)
                                .focused($isPinFieldFocused)
                                .frame(width: 1, height: 1)
                                .opacity(0.01)
                                .onChange(of: pinCode) { val in
                                    let filtered = val.filter { $0.isNumber }
                                    if filtered.count > 6 {
                                        pinCode = String(filtered.prefix(6))
                                    } else if filtered != val {
                                        pinCode = filtered
                                    }
                                }

                            if let err = errorMessage {
                                Text(err)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                            }

                            // Connect Button
                            Button(action: connectWithPin) {
                                HStack {
                                    if isConnecting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Kết nối & Ghép đôi")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(pinCode.count == 6 && !targetHostIp.isEmpty ? Color.blue : Color.gray.opacity(0.4))
                                .cornerRadius(12)
                            }
                            .disabled(pinCode.count != 6 || targetHostIp.isEmpty || isConnecting)
                            .padding(.horizontal, 28)
                        }
                        .padding(.top, 10)
                    }

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Ghép Đôi Thiết Bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hủy") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .onAppear {
                if selectedTab == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPinFieldFocused = true
                    }
                }
            }
        }
    }

    private func tabButton(_ title: String, index: Int, icon: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = index
                errorMessage = nil
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(selectedTab == index ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedTab == index ? Color.blue : Color.clear)
            .cornerRadius(10)
        }
    }

    private func digitBox(_ index: Int) -> some View {
        let char: String
        if index < pinCode.count {
            let start = pinCode.index(pinCode.startIndex, offsetBy: index)
            char = String(pinCode[start])
        } else {
            char = ""
        }
        let isFocused = pinCode.count == index

        return Text(char)
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 44, height: 54)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? Color.cyan : Color.white.opacity(0.15), lineWidth: isFocused ? 2 : 1)
            )
    }

    private func handleScannedQr(_ raw: String) {
        guard let payload = PairingManager.shared.parseQrPayload(raw) else {
            errorMessage = "Mã QR không đúng định dạng AirPulse"
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()

        Task {
            await session.connect(
                hostIp: payload.hostIp,
                controlPort: payload.port,
                expectedFingerprint: payload.fingerprint,
                pairingToken: payload.tokenData
            )
        }
    }

    private func connectWithPin() {
        guard pinCode.count == 6, !targetHostIp.isEmpty else { return }
        isConnecting = true
        errorMessage = nil

        Task {
            await session.connect(
                hostIp: targetHostIp.trimmingCharacters(in: .whitespacesAndNewlines),
                controlPort: 7001,
                pin: pinCode
            )
            isConnecting = false
            if case .streaming = session.state {
                dismiss()
            } else if case .failed(let err) = session.state {
                errorMessage = err
            }
        }
    }
}

// MARK: - Animated Scanner Line

private struct ScannerLineAnimation: View {
    @State private var offset: CGFloat = -120

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, .cyan.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
            .frame(height: 3)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    offset = 120
                }
            }
    }
}

// MARK: - Camera QR Scanner UIViewControllerRepresentable

public struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    public let onCodeScanned: (String) -> Void
    public let onPermissionDenied: (() -> Void)?

    public func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onCodeScanned
        vc.onPermissionDenied = onPermissionDenied
        return vc
    }

    public func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

public final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    public var onCodeScanned: ((String) -> Void)?
    public var onPermissionDenied: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndSetupCamera()
    }

    private func checkPermissionAndSetupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.onPermissionDenied?()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
        @unknown default:
            break
        }
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            onPermissionDenied?()
            return
        }

        let session = AVCaptureSession()
        self.captureSession = session

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onPermissionDenied?()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onPermissionDenied?()
            return
        }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        // Safe assignment of metadata types only if supported
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringVal = first.stringValue else { return }

        hasScanned = true
        captureSession?.stopRunning()
        onCodeScanned?(stringVal)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}
