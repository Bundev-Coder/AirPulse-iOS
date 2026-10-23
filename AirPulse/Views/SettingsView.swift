import SwiftUI

public struct SettingsView: View {
    @AppStorage("setting_fps") private var targetFps: Int = 60
    @AppStorage("setting_bitrate") private var targetBitrate: Int = 5000
    @AppStorage("setting_scale") private var scaleFactor: Double = 1.0
    @AppStorage("setting_clipboard") private var clipboardSync: Bool = true
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Chất Lượng Video")) {
                    Picker("Tốc độ khung hình (FPS)", selection: $targetFps) {
                        Text("30 FPS (Tiết kiệm pin)").tag(30)
                        Text("60 FPS (Mượt mà nhất)").tag(60)
                    }

                    Picker("Băng thông mục tiêu", selection: $targetBitrate) {
                        Text("2.5 Mbps (Tiết kiệm)").tag(2500)
                        Text("5.0 Mbps (Cân bằng)").tag(5000)
                        Text("8.0 Mbps (Sắc nét)").tag(8000)
                    }

                    Picker("Độ phân giải hiển thị", selection: $scaleFactor) {
                        Text("100% (Gốc)").tag(1.0)
                        Text("75% (Cân bằng)").tag(0.75)
                        Text("50% (Độ trễ cực thấp)").tag(0.5)
                    }
                }

                Section(header: Text("Tính Năng Nâng Cao")) {
                    Toggle("Đồng bộ Clipboard tự động", isOn: $clipboardSync)
                }

                Section(header: Text("Thông Tin Ứng Dụng")) {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("AirPulse v1.0.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Giao thức mạng")
                        Spacer()
                        Text("AirPulse v1.0 (TLS 1.3)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Mã hoá Video")
                        Spacer()
                        Text("H.264 VideoToolbox GPU")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Cài Đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}
