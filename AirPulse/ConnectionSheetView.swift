import SwiftUI

struct ConnectionSheetView: View {
    @ObservedObject var client = AirPulseClient.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var inputUrl: String = ""
    @State private var selectedMode: Int = 0 // 0 = LAN, 1 = WAN (Cloudflare)

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 5/255, green: 7/255, blue: 12/255).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Mode Picker
                        Picker("Chế Độ Kết Nối", selection: $selectedMode) {
                            Text("🏠 Mạng LAN (Cùng Wi-Fi)").tag(0)
                            Text("🌐 Từ Xa (Khác Mạng / 4G)").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 4)

                        // Mode Description Banner
                        if selectedMode == 0 {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "wifi")
                                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Chế Độ Mạng Nội Bộ (LAN)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Tốc độ siêu nhanh, không giới hạn dung lượng khi iPhone và PC dùng chung một mạng Wi-Fi.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(14)
                            .background(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.08))
                            .cornerRadius(16)
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Chế Độ Từ Xa Qua Internet (WAN)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Điều khiển tắt máy tính và gửi nhận file từ bất kỳ đâu qua 4G/5G hoặc mạng Wi-Fi ngoài.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(14)
                            .background(Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.08))
                            .cornerRadius(16)
                        }

                        // Input Box
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedMode == 0 ? "Địa chỉ IP Máy Tính (LAN):" : "Đường Dẫn Cloudflare Tunnel (WAN):")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))

                            TextField(selectedMode == 0 ? "http://172.20.10.2:8899" : "https://xxxx.trycloudflare.com", text: $inputUrl)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // Quick Presets
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gợi ý nhanh:")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))

                            HStack(spacing: 8) {
                                presetButton(title: "172.20.10.2:8899", val: "http://172.20.10.2:8899")
                                presetButton(title: "192.168.1.15:8899", val: "http://192.168.1.15:8899")
                            }
                        }

                        // Save & Connect Button
                        Button(action: {
                            var clean = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !clean.isEmpty {
                                if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
                                    clean = "http://" + clean
                                }
                                client.gatewayUrl = clean
                                client.connect()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Lưu & Kết Nối Ngay")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0, green: 245/255, blue: 212/255),
                                        Color(red: 139/255, green: 92/255, blue: 246/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Cấu Hình Kết Nối")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Đóng") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
            .onAppear {
                inputUrl = client.gatewayUrl
            }
        }
    }

    private func presetButton(title: String, val: String) -> some View {
        Button(action: { inputUrl = val }) {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
        }
    }
}
