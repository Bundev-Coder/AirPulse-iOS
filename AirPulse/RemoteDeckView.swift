import SwiftUI

struct RemoteDeckView: View {
    @ObservedObject var client = AirPulseClient.shared
    @State private var urlInputText: String = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // SECTION 1: REMOTE POWER MANAGEMENT (CRITICAL USER REQUIREMENT)
                powerManagementSection

                // SECTION 2: WEB OPENER
                webOpenerSection

                // SECTION 3: HARDWARE COMMANDS GRID
                hardwareCommandsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 90)
        }
        .sheet(isPresented: $client.showScreenshotSheet) {
            screenshotViewerSheet
        }
    }

    // MARK: - Power Management Section
    private var powerManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "power.circle.fill")
                    .foregroundColor(Color(red: 255/255, green: 51/255, blue: 102/255))
                    .font(.system(size: 18))
                Text("Quản Lý Nguồn Máy Tính Từ Xa")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Button 1: Shutdown (15s)
                Button(action: { client.sendRemoteAction("shutdown_pc") }) {
                    VStack(spacing: 8) {
                        Image(systemName: "power")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 255/255, green: 51/255, blue: 102/255))
                        Text("TẮT MÁY PC (15s)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(Color(red: 255/255, green: 51/255, blue: 102/255))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.12))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.4), lineWidth: 1.5)
                    )
                }

                // Button 2: Cancel Shutdown
                Button(action: { client.sendRemoteAction("cancel_shutdown") }) {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.shield.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Text("HỦY TẮT MÁY")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.12))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.4), lineWidth: 1.5)
                    )
                }

                // Button 3: Restart
                Button(action: { client.sendRemoteAction("restart_pc") }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 245/255, green: 158/255, blue: 11/255))
                        Text("Khởi Động Lại")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                // Button 4: Sleep Mode
                Button(action: { client.sendRemoteAction("sleep_pc") }) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                        Text("Chế Độ Ngủ")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 20/255, green: 12/255, blue: 22/255).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(red: 255/255, green: 51/255, blue: 102/255).opacity(0.35), lineWidth: 1.2)
                )
        )
    }

    // MARK: - Web Opener Section
    private var webOpenerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(Color(red: 0, green: 245/255, blue: 212/255))
                    .font(.system(size: 18))
                Text("Mở Trang Web Bất Kỳ Trên Máy Tính")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {
                TextField("Nhập link (vd: youtube.com)...", text: $urlInputText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                Button(action: {
                    if !urlInputText.isEmpty {
                        client.launchUrl(urlInputText)
                        urlInputText = ""
                    }
                }) {
                    Text("Mở")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(red: 0, green: 245/255, blue: 212/255))
                        .cornerRadius(14)
                }
            }

            // Quick Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickChip(title: "▶️ YouTube", url: "https://youtube.com")
                    quickChip(title: "🤖 ChatGPT", url: "https://chatgpt.com")
                    quickChip(title: "🔍 Google", url: "https://google.com")
                    quickChip(title: "👥 Facebook", url: "https://facebook.com")
                    quickChip(title: "🎵 TikTok", url: "https://tiktok.com")
                    quickChip(title: "🐙 GitHub", url: "https://github.com")
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 12/255, green: 16/255, blue: 28/255).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(red: 0, green: 245/255, blue: 212/255).opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func quickChip(title: String, url: String) -> some View {
        Button(action: { client.launchUrl(url) }) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    // MARK: - Hardware Commands Grid
    private var hardwareCommandsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(red: 139/255, green: 92/255, blue: 246/255))
                    .font(.system(size: 18))
                Text("Lệnh Điều Khiển Phần Cứng")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                actionCard(icon: "lock.fill", title: "Khóa Máy", color: Color(red: 255/255, green: 51/255, blue: 102/255), action: "lock_pc")
                actionCard(icon: "camera.viewfinder", title: "Chụp PC", color: Color(red: 0, green: 245/255, blue: 212/255), action: "screenshot")
                actionCard(icon: "folder.fill", title: "Thư Mục", color: Color(red: 139/255, green: 92/255, blue: 246/255), action: "open_folder")
                actionCard(icon: "speaker.slash.fill", title: "Mute Loa", color: Color(red: 245/255, green: 158/255, blue: 11/255), action: "volume_mute")
                actionCard(icon: "speaker.wave.3.fill", title: "Tăng Âm", color: Color(red: 245/255, green: 158/255, blue: 11/255), action: "volume_up")
                actionCard(icon: "speaker.wave.1.fill", title: "Giảm Âm", color: Color(red: 245/255, green: 158/255, blue: 11/255), action: "volume_down")
                actionCard(icon: "function", title: "Calculator", color: Color(red: 59/255, green: 130/255, blue: 246/255), action: "open_calc")
                actionCard(icon: "note.text", title: "Notepad", color: Color(red: 16/255, green: 185/255, blue: 129/255), action: "open_notepad")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 12/255, green: 16/255, blue: 28/255).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func actionCard(icon: String, title: String, color: Color, action: String) -> some View {
        Button(action: { client.sendRemoteAction(action) }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
        }
    }

    // MARK: - Screenshot Viewer Sheet
    private var screenshotViewerSheet: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let img = client.latestScreenshot {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
            .navigationTitle("Ảnh Chụp Màn Hình PC")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Lưu Vào Ảnh") {
                    if let img = client.latestScreenshot {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    }
                },
                trailing: Button("Đóng") {
                    client.showScreenshotSheet = false
                }
            )
        }
    }
}
